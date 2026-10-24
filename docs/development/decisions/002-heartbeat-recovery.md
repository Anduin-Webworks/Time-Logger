# ADR 002: Recover missing logouts with a heartbeat snapshot

- Status: Accepted by existing implementation
- Evidence: `TimeLogger.lua`, `TimeLoggerStorage.lua`, v2.6.0 changelog

## Context

The addon receives `PLAYER_LOGOUT` for clean exits but cannot rely on a single exact event for every force quit or disconnect. It needs a bounded approximation of the last known active time.

## Decision

Persist a logout-shaped `temp_logout` snapshot immediately at login and periodically at a configurable 1–10 minute interval. On the next login, if the previous event is an unmatched login, create a synthetic logout from the last valid snapshot and mark it as recovered.

## Consequences

Recovery can restore a useful end time without claiming exact disconnect detection. The recovered time can be stale by up to the heartbeat interval, and a crash before SavedVariables is written can lose the latest snapshot. Clean logout clears the temporary snapshot.
