"""Ordinary rendering through current intent and one bounded device transaction."""

import copy
import errno

from portable_device_writer import output_lock, write_managed
from portable_intent import Intents
from portable_policy import check_deadline
import portable_record_io as records
from portable_records import key
from portable_render import Render


class Renderer:
    def __init__(self, store):
        self.store = store
        self.intents = Intents(store)

    def render(self, display, record, synthetic, intake_at):
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
                target = self.store.resolve(tty, incoming.get("producer"), deadline, targets_only=True)
                context["target"] = target
                if display.background is not None:
                    self.intents.publish_unlocked(target, incoming, synthetic, intake_at, deadline)

        def prepare(fd, deadline):
            target, revision = context["target"], context["revision"]
            if not self.store.policy.matches(revision, deadline):
                raise OSError(errno.ESTALE, "Visual suspension revision changed")
            self.intents.validate_context_unlocked(target, incoming, synthetic, intake_at, deadline)
            if display.background is not None:
                self.intents.publish_unlocked(target, incoming, synthetic, intake_at, deadline)
            obsolete = self.store.ordinary_ownership(target, revision, fd, deadline)
            rendered = copy.copy(display)
            legacy = any(effect["kind"] == "globalRestriction" for _, effect in obsolete)
            if display.background is not None or obsolete:
                rendered.background = self.intents.ordinary_background_unlocked(target, deadline) or "reset"
            data = (b"\x1b]104\a\x1b]110\a" if legacy else b"") + rendered.encode(synthetic=synthetic)
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
