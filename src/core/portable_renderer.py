"""Ordinary rendering through current intent and one bounded device transaction."""

import copy
import errno
import os
import stat

from portable_device_writer import output_lock, write_managed
from portable_intent import Intents
from portable_policy import check_deadline
from portable_ownership import _binding
import portable_record_io as records
from portable_records import _text, generation_schema, key, target_path
from portable_render import Render


class Renderer:
    def __init__(self, store):
        self.store = store
        self.intents = Intents(store)

    def render(self, display, record, synthetic, intake_at):
        return self._execute(display, record, synthetic, intake_at)

    def background(self, record, synthetic, intake_at):
        fields = [""]*23
        fields[0], fields[18], fields[22] = record["background"], "0", "0"
        display = Render(("\0".join(fields)+"\0").encode())
        return self._execute(display, record, synthetic, intake_at, ordinary_only=True)

    def register(self, tty, producer):
        return self._no_output(tty, producer, "register")

    def current(self, tty, producer):
        return self._no_output(tty, producer, "current")

    def check_context(self, record, intake_at):
        return self._no_output(record["tty"], record.get("producer"), "check", (dict(record), intake_at))

    def _no_output(self, tty, producer, operation, context=None):
        lock_path = self.store.directory / ("writer-"+key(tty)+".lock")
        target = {}

        def before_open(deadline):
            with output_lock(lock_path, deadline):
                target["binding"] = self.store.resolve(tty, producer, deadline, targets_only=True, identity_hints=True)

        def prepare(fd, deadline):
            binding = target["binding"]
            aliases, _ = self.store._current(binding, deadline, fd, targets_only=True, identity_hints=True)
            if operation == "check":
                record, intake_at = context
                self.intents.validate_context_unlocked(binding, record, True, intake_at, deadline)
            else:
                path = target_path(self.store.directory, binding, "target.json")
                cached = records.read(self.store.directory, path, "target", self.store.clock(), deadline)
                if cached is None:
                    records.write(self.store.directory, path, {"schema": generation_schema(binding["ttyOwner"]), "target": binding},
                                  "target", self.store.clock(), deadline)
                elif _binding(cached["target"]) != _binding(binding):
                    raise OSError(errno.ESTALE, "Cached target changed")
                aliases, _ = self.store._current(binding, deadline, fd, targets_only=True, identity_hints=True)
                if operation == "current":
                    for alias in aliases:
                        for filename, kinds in (("effect.json", {"globalRestriction", "selectiveBackground"}),
                                                ("preview.json", {"preview"}), ("focus.json", {"focus"})):
                            effect = records.read(self.store.directory, target_path(self.store.directory, alias, filename),
                                                  "effect", self.store.clock(), deadline)
                            if effect is not None and (_binding(effect["target"]) != _binding(alias) or effect["kind"] not in kinds):
                                raise OSError(errno.EINVAL, "Current effect unavailable")
                    if self.store.policy.restricted(deadline, unavailable_disabled=True):
                        raise OSError(errno.EBUSY, "Native visual rule owns output")
            if self.store.status(binding, deadline, fd) != "valid":
                raise OSError(errno.ESTALE, "No-output target changed")
            check_deadline(deadline)
            return None

        return write_managed(tty, lock_path, before_open, prepare)

    def forced_reset(self, record, intake_at, title):
        try:
            _text(title, 512, nonempty=False)
        except ValueError as error:
            raise OSError(errno.EINVAL, "Invalid reset title") from error
        fields = [""] * 23
        fields[0], fields[18], fields[19], fields[22] = "reset", "1", title, "0"
        display = Render(("\0".join(fields) + "\0").encode())
        return self._execute(display, dict(record, background="reset"), True, intake_at, forced=True)

    def reconcile(self, tty, reset_legacy=True, clear_selective=False):
        if type(reset_legacy) is not bool or type(clear_selective) is not bool:
            raise OSError(errno.EINVAL, "Invalid reconcile flags")
        lock_path = self.store.directory / ("writer-" + key(tty) + ".lock")
        context = {}

        def before_open(deadline):
            with output_lock(lock_path, deadline):
                context["target"] = self.store.cached_target(tty, deadline)

        def prepare(fd, deadline):
            target = context["target"]
            # Reconcile has no frozen style: recovery queued before open must govern this operation.
            revision = self.store.policy.capture(deadline)
            self.store._current(target, deadline, fd)
            if self.store.policy.restricted(deadline):
                raise OSError(errno.EBUSY, "Native visual rule owns output")
            self._invalidate_pending(tty, deadline)
            effects, obsolete, suspended = self.store.reconcile_ownership(
                target, revision, fd, deadline, clear_selective)
            matching_preview = any(effect["active"] and effect["kind"] == "preview"
                and effect.get("revision") == dict(zip(("device", "inode"), revision.identity))
                for _, effect in effects)
            legacy = any(effect["kind"] == "globalRestriction" for _, effect in obsolete)
            if suspended and not matching_preview:
                if not obsolete:
                    return None
                data = b"\x1b]104\a\x1b]110\a\x1b]111\a" if legacy else b"\x1b]111\x1b\\"
            else:
                if not suspended:
                    legacy = reset_legacy or any(effect["kind"] == "globalRestriction" for _, effect in effects)
                background = self.intents.ordinary_background_unlocked(target, deadline) or "reset"
                data = b"\x1b]104\a\x1b]110\a" if legacy else b""
                data += (b"\x1b]111\x1b\\" if background == "reset"
                         else ("\x1b]11;" + background + "\x1b\\").encode("ascii"))
            if (not self.store.policy.matches(revision, deadline)
                    or self.store.status(target, deadline, fd) != "valid"):
                raise OSError(errno.ESTALE, "Reconcile target changed")
            context["obsolete"] = obsolete
            check_deadline(deadline)
            return data

        return write_managed(tty, lock_path, before_open, prepare,
            after_write=lambda fd, deadline: self._complete_effects(context["obsolete"], deadline))

    def _invalidate_pending(self, tty, deadline):
        runtime = self.store.directory.parent
        path = runtime / "pending" / (tty.replace("/", "_") + ".osc")
        with records.parent_directory(runtime, path, deadline) as (parent, _):
            if parent is None:
                return
            try:
                info = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
            except FileNotFoundError:
                check_deadline(deadline)
                return
            if not stat.S_ISREG(info.st_mode):
                raise OSError(errno.EINVAL, "Pending output unavailable")
            check_deadline(deadline)
            os.unlink(path.name, dir_fd=parent)
            check_deadline(deadline)

    def _complete_effects(self, obsolete, deadline):
        # Failed output retains restoration work. Cooperating writers still share this lock.
        for path, old in obsolete:
            with records.parent_directory(self.store.directory, path, deadline) as (parent, _):
                if parent is None:
                    raise OSError(errno.ESTALE, "Effect completion unavailable")
                try:
                    current = records.read_record(path.name, "effect", self.store.clock(), deadline, dir_fd=parent)
                except ValueError as error:
                    raise OSError(errno.EINVAL, "Effect completion unavailable") from error
                if current != old:
                    raise OSError(errno.ESTALE, "Effect changed during output")
                if old["kind"] == "globalRestriction":
                    cached = records.read_record("target.json", "target", self.store.clock(), deadline, dir_fd=parent)
                    if cached is None:
                        records.write(self.store.directory, path.with_name("target.json"),
                                      {"schema": old["schema"], "target": old["target"]}, "target", self.store.clock(), deadline)
                    elif cached["target"] != old["target"]:
                        raise OSError(errno.ESTALE, "Completed effect binding changed")
                    check_deadline(deadline)
                    os.unlink(path.name, dir_fd=parent)
                else:
                    records.write(self.store.directory, path, dict(old, active=False),
                                  "effect", self.store.clock(), deadline)
                check_deadline(deadline)
        check_deadline(deadline)

    def _execute(self, display, record, synthetic, intake_at, forced=False, ordinary_only=False):
        if not isinstance(display, Render):
            raise OSError(errno.EINVAL, "Invalid finite render")
        incoming = dict(record)
        if display.background is not None:
            incoming["background"] = display.background
        tty = incoming["tty"]
        lock_path = self.store.directory / ("writer-" + key(tty) + ".lock")
        context = {}

        def before_open(deadline):
            context["revision"] = None if ordinary_only else self.store.policy.capture(deadline)
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
            if revision is not None and not self.store.policy.matches(revision, deadline):
                return None
            if forced:
                self.intents.publish_forced_reset_unlocked(target, incoming, intake_at, deadline)
            elif not ordinary_only:
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
            if ordinary_only and self.store.policy.restricted(deadline, unavailable_disabled=True):
                raise OSError(errno.EBUSY, "Native visual rule owns output")
            if ((revision is not None and not self.store.policy.matches(revision, deadline))
                    or self.store.status(target, deadline, fd) != "valid"):
                raise OSError(errno.ESTALE, "Visual target changed")
            context["obsolete"] = obsolete
            check_deadline(deadline)
            return data or None

        def after_write(fd, deadline):
            self._complete_effects(context["obsolete"], deadline)

        return write_managed(tty, lock_path, before_open, prepare, after_write=after_write)
