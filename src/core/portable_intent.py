"""Retain typed ordinary intent under the caller's existing per-TTY output lock."""

import errno
import json

from portable_ownership import _binding
from portable_policy import check_deadline
from portable_process_identity import continuing_owner
import portable_record_io as records
from portable_records import _timestamp, decode, generation_key, key, target_path
from portable_render import normalized_background


def _delivery(record):
    return record["tty"], record.get("device"), record.get("producer"), record["deliveryID"]


class Intents:
    def __init__(self, store):
        self.store = store

    def _path(self, kind, tty):
        return self.store.directory / (kind + "-" + key(tty) + ".json")

    def _normalize(self, record, synthetic, intake_at, deadline):
        check_deadline(deadline)
        try:
            if type(synthetic) is not bool:
                raise ValueError("Invalid synthetic flag")
            result = decode(json.dumps(record, allow_nan=False).encode(), "intent", self.store.clock())
            _timestamp(intake_at, result["updatedAt"])
            result["background"] = normalized_background(result["background"])
        except (ValueError, TypeError, OverflowError, RecursionError) as error:
            raise OSError(errno.EINVAL, "Invalid intent context") from error
        check_deadline(deadline)
        return result

    def _require_producer(self, target, record, deadline):
        if self.store.status(target, deadline) != "valid":
            raise OSError(errno.ESTALE, "Intent target unavailable")
        producer = record.get("producer")
        if (record["tty"] != target["tty"] or record.get("device") != target["device"]
                or producer is None):
            raise OSError(errno.ESTALE, "Intent target unavailable")
        current = self.store._lookup(producer["pid"], deadline)
        if current is None or current["generation"] != producer or current["device"] != target["device"]:
            raise OSError(errno.ESTALE, "Intent producer unavailable")
        owner = continuing_owner(producer, target["device"], lambda pid: self.store._lookup(pid, deadline))
        if owner != target["ttyOwner"] or self.store.status(target, deadline) != "valid":
            raise OSError(errno.ESTALE, "Intent owner changed")
        check_deadline(deadline)

    def _observation(self, tty, synthetic, tolerate_invalid, deadline):
        try:
            return records.read(self.store.directory, self._path("observation", tty),
                                "observation", self.store.clock(), deadline)
        except OSError as error:
            if error.errno == errno.ETIMEDOUT or not tolerate_invalid:
                raise
        except ValueError as error:
            if not tolerate_invalid:
                raise OSError(errno.ESTALE if synthetic else errno.EINVAL, "Observation unavailable") from error
        check_deadline(deadline)
        return None

    def _latest(self, tty, synthetic, deadline):
        path = self._path("intent", tty)
        try:
            return records.read_latest(self.store.directory, path, "intent", self.store.clock(), deadline,
                                       recover_invalid=not synthetic)
        except ValueError as error:
            raise OSError(errno.EINVAL, "Latest intent unavailable") from error

    def _check_observation(self, observation, record, synthetic, intake_at, deadline):
        if observation is not None and observation["observedAt"] > intake_at:
            raise OSError(errno.ESTALE, "Intent delivery superseded")
        if synthetic and (observation is None or _delivery(observation) != _delivery(record)):
            raise OSError(errno.ESTALE, "Synthetic delivery unavailable")
        check_deadline(deadline)

    def validate_context_unlocked(self, target, record, synthetic, intake_at, deadline):
        normalized = self._normalize(record, synthetic, intake_at, deadline)
        observation = self._observation(record["tty"], synthetic, False, deadline)
        self._check_observation(observation, normalized, synthetic, intake_at, deadline)
        self._require_producer(target, normalized, deadline)

    def ordinary_background_unlocked(self, target, deadline):
        aliases, _ = self.store._current(target, deadline)
        latest = records.read(self.store.directory, self._path("intent", target["tty"]),
                              "intent", self.store.clock(), deadline)
        if (latest is None or latest["tty"] != target["tty"] or latest.get("device") != target["device"]
                or latest.get("producer") is None):
            return None
        for alias in aliases:
            bound = records.read(self.store.directory, target_path(self.store.directory, alias, "bound-intent.json"),
                                 "intent", self.store.clock(), deadline)
            if bound == latest:
                check_deadline(deadline)
                return normalized_background(latest["background"])
        try:
            self._require_producer(target, latest, deadline)
        except OSError as error:
            if error.errno != errno.ESTALE:
                raise
            return None
        if target.get("nativeSurface") is not None:
            path = self.store.directory / ("adoption-" + key(target["tty"]) + "-"
                                           + generation_key(latest["producer"]) + ".json")
            adoption = records.read(self.store.directory, path, "adoption", self.store.clock(), deadline)
            if (adoption is None or adoption["tty"] != target["tty"] or adoption["device"] != target["device"]
                    or adoption["producer"] != latest["producer"] or adoption["surface"] != target["nativeSurface"]
                    or latest["deliveryID"] not in {adoption.get("intentDeliveryID"), adoption.get("observationDeliveryID")}):
                return None
        check_deadline(deadline)
        return normalized_background(latest["background"])

    def publish_unlocked(self, target, record, synthetic, intake_at, deadline):
        normalized = self._normalize(record, synthetic, intake_at, deadline)
        self._require_producer(target, normalized, deadline)
        self.store._current(target, deadline, targets_only=True)
        observation = self._observation(record["tty"], synthetic, not synthetic, deadline)
        self._check_observation(observation, normalized, synthetic, intake_at, deadline)
        latest = self._latest(record["tty"], synthetic, deadline)
        if latest is not None:
            supersedes = (observation is not None and _delivery(observation) == _delivery(normalized)
                          and _delivery(latest) != _delivery(normalized))
            if not supersedes and normalized["updatedAt"] < latest["updatedAt"]:
                raise OSError(errno.ESTALE, "Ordinary intent superseded")
        self._require_producer(target, normalized, deadline)
        records.write(self.store.directory, self._path("intent", record["tty"]), normalized,
                      "intent", self.store.clock(), deadline)
        cached_path = target_path(self.store.directory, target, "target.json")
        bound_path = target_path(self.store.directory, target, "bound-intent.json")
        try:
            cached = records.read(self.store.directory, cached_path, "target", self.store.clock(), deadline)
            bound = records.read(self.store.directory, bound_path, "intent", self.store.clock(), deadline)
        except ValueError as error:
            raise OSError(errno.EINVAL, "Bound intent unavailable") from error
        if cached is not None and _binding(cached["target"]) != _binding(target):
            raise OSError(errno.ESTALE, "Bound target changed")
        if bound is not None and (cached is None or bound["tty"] != target["tty"]
                or bound.get("device") != target["device"] or bound.get("producer") is None):
            raise OSError(errno.EINVAL, "Bound intent unavailable")
        self._require_producer(target, normalized, deadline)
        latest = records.read(self.store.directory, self._path("intent", record["tty"]),
                              "intent", self.store.clock(), deadline)
        if latest != normalized:
            raise OSError(errno.ESTALE, "Intent changed before binding")
        if cached is None:
            records.write(self.store.directory, cached_path, {"schema": 1, "target": target},
                          "target", self.store.clock(), deadline)
        records.write(self.store.directory, bound_path, normalized, "intent", self.store.clock(), deadline)
        check_deadline(deadline)
        return normalized

    def publish_forced_reset_unlocked(self, target, record, intake_at, deadline):
        normalized = self._normalize(record, True, intake_at, deadline)
        if (normalized["background"] != "reset" or normalized["tty"] != target["tty"]
                or normalized.get("device") != target["device"]
                or self.store.status(target, deadline) != "valid"):
            raise OSError(errno.ESTALE, "Reset target unavailable")
        latest = self._latest(normalized["tty"], True, deadline)
        if latest is not None and _delivery(latest) != _delivery(normalized):
            raise OSError(errno.ESTALE, "Reset delivery superseded")
        producer = normalized.get("producer")
        current = self.store._lookup(producer["pid"], deadline) if producer is not None else None
        if (current is not None and current["generation"] == producer
                and current["device"] == target["device"]):
            return self.publish_unlocked(target, normalized, True, intake_at, deadline)
        # Orphan authority is the unchanged bound delivery and current target, not missing PID alone.
        if latest is None:
            raise OSError(errno.ESTALE, "Bound reset delivery unavailable")
        observation = self._observation(normalized["tty"], True, False, deadline)
        self._check_observation(observation, normalized, True, intake_at, deadline)
        aliases, _ = self.store._current(target, deadline)
        bound = [records.read(self.store.directory, target_path(self.store.directory, alias, "bound-intent.json"),
                              "intent", self.store.clock(), deadline) for alias in aliases]
        if latest not in bound or normalized["updatedAt"] < latest["updatedAt"]:
            raise OSError(errno.ESTALE, "Bound reset intent changed")
        if self.store.status(target, deadline) != "valid":
            raise OSError(errno.ESTALE, "Reset target changed")
        records.write(self.store.directory, self._path("intent", normalized["tty"]), normalized,
                      "intent", self.store.clock(), deadline)
        actual = self._latest(normalized["tty"], True, deadline)
        if actual != normalized or self.store.status(target, deadline) != "valid":
            raise OSError(errno.ESTALE, "Reset changed before binding")
        records.write(self.store.directory, target_path(self.store.directory, target, "bound-intent.json"),
                      normalized, "intent", self.store.clock(), deadline)
        check_deadline(deadline)
        return normalized
