# ADR 0001: Use indexed SavedVariables storage

- Status: Implemented
- Evidence: `TimeLoggerStorage.lua`, changelog entry for v1.5.0

## Context

WoW addons cannot use an external database from this project. The addon needs to retain login/logout history, find the latest event for a character, derive sessions, and continue to work as the event log grows.

## Decision

Store events in `TimeLoggerDB` using numeric IDs, an ordered ID list, and per-character indexes. Cache derived sessions and invalidate that cache after event changes. Migrate the earlier flat event array into this shape on load.

## Consequences

Lookups for a character's latest event are direct through `last_by_character`, while chronological scans remain available through `event_order`. The data model is more complex than a flat array and requires migration, index rebuilding, and cache invalidation to remain correct. SavedVariables remains local and subject to WoW's save lifecycle.

