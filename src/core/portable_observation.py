"""Typed observation publication without painting or creating output authority."""

import json
import time

from portable_context import validate_context
from portable_device_writer import output_lock
from portable_policy import check_deadline
import portable_record_io as records
from portable_records import StaleRecordError, decode, key


def publish_observation(store, context, tty, state):
    deadline = time.monotonic_ns() + 100_000_000
    validate_context(context, store.clock())
    record = {"schema": context["schema"], "tty": tty, "provider": context["provider"],
              "verifiedAgent": context["verifiedAgent"], "state": state,
              "deliveryID": context["deliveryID"], "observedAt": context["observedAt"]}
    for field in ("device", "producer", "event", "responseID"):
        if context.get(field) is not None:
            record[field] = context[field]
    record = decode(json.dumps(record, allow_nan=False).encode(), "observation", store.clock())
    path = store.directory / ("observation-"+key(tty)+".json")
    with output_lock(store.directory / ("writer-"+key(tty)+".lock"), deadline):
        current = records.read_latest(store.directory, path, "observation", store.clock(), deadline,
                                      recover_invalid=True)
        if current is not None and record["observedAt"] < current["observedAt"]:
            raise StaleRecordError("Observation delivery superseded")
        records.write(store.directory, path, record, "observation", store.clock(), deadline)
        check_deadline(deadline)
