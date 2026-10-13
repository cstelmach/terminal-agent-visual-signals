"""Ordinary rendering through current intent and one bounded device transaction."""

import copy
import errno

from portable_device_writer import output_lock, write_managed
from portable_intent import Intents
from portable_policy import check_deadline
import portable_record_io as records
from portable_records import _text, key
from portable_render import Render


class Renderer:
    def __init__(self, store):
        self.store = store
        self.intents = Intents(store)

    def render(self, display, record, synthetic, intake_at):
        return self._execute(display, record, synthetic, intake_at)

    def forced_reset(self, record, intake_at, title):
        try:
            _text(title, 512, nonempty=False)
        except ValueError as error:
            raise OSError(errno.EINVAL, "Invalid reset title") from error
        fields = [""] * 23
        fields[0], fields[18], fields[19], fields[22] = "reset", "1", title, "0"
        display = Render(("\0".join(fields) + "\0").encode())
        return self._execute(display, dict(record, background="reset"), True, intake_at, forced=True)

    def _execute(self, display, record, synthetic, intake_at, forced=False):
        if not isinstance(display, Render):
            raise OSError(errno.EINVAL, "Invalid finite render")
        incoming = dict(record)
        if display.background is not None:
            incoming["background"] = display.background
        tty = incoming["tty"]
        lock_path = self.store.directory / ("writer-" + key(tty) + ".lock")
        context = {}

        def before_open(deadline):
            context["revision"] = self.store.policy.capture(deadline)
            with output_lock(lock_path, deadline):
                producer = incoming.get("producer")
                current = self.store._lookup(producer["pid"], deadline) if producer is not None else None
                orphan = forced and (current is None or current["generation"] != producer)
                target = self.store.cached_target(tty, deadline) if orphan else self.store.resolve(
                    tty, producer, deadline, targets_only=True)
                context["target"] = target
                if forced:
                    self.intents.publish_forced_reset_unlocked(target, incoming, intake_at, deadline)
                elif display.background is not None:
                    self.intents.publish_unlocked(target, incoming, synthetic, intake_at, deadline)

        def prepare(fd, deadline):
            target, revision = context["target"], context["revision"]
            if not self.store.policy.matches(revision, deadline):
                raise OSError(errno.ESTALE, "Visual suspension revision changed")
            if forced:
                self.intents.publish_forced_reset_unlocked(target, incoming, intake_at, deadline)
            else:
                self.intents.validate_context_unlocked(target, incoming, synthetic, intake_at, deadline)
            if not forced and display.background is not None:
                self.intents.publish_unlocked(target, incoming, synthetic, intake_at, deadline)
            obsolete = self.store.ordinary_ownership(target, revision, fd, deadline)
            rendered = copy.copy(display)
            legacy = any(effect["kind"] == "globalRestriction" for _, effect in obsolete)
            if display.background is not None or obsolete:
                rendered.background = self.intents.ordinary_background_unlocked(target, deadline) or "reset"
            prefix = b"\x1b]104\a\x1b]110\a" if legacy else b"\x1b]104\a" if forced else b""
            data = prefix + rendered.encode(synthetic=synthetic)
            if (not self.store.policy.matches(revision, deadline)
                    or self.store.status(target, deadline, fd) != "valid"):
                raise OSError(errno.ESTALE, "Visual target changed")
            context["obsolete"] = obsolete
            check_deadline(deadline)
            return data or None

        def after_write(fd, deadline):
            # Failed output retains restoration work. Cooperating writers still share this lock.
            for path, old in context["obsolete"]:
                try:
                    current = records.read(self.store.directory, path, "effect", self.store.clock(), deadline)
                except ValueError as error:
                    raise OSError(errno.EINVAL, "Effect completion unavailable") from error
                if current != old:
                    raise OSError(errno.ESTALE, "Effect changed during output")
                cancelled = dict(old, active=False)
                records.write(self.store.directory, path, cancelled, "effect", self.store.clock(), deadline)
            check_deadline(deadline)

        return write_managed(tty, lock_path, before_open, prepare, after_write=after_write)
