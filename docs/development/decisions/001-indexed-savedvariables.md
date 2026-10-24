# ADR 001: Use an indexed SavedVariables event store

- Status: Accepted by existing implementation
- Evidence: `TimeLoggerStorage.lua`, schema version 2/3 changelog entries

## Context

The addon needs to retain login/logout history locally and derive sessions for multiple characters. WoW addons do not have access to an external database through this project.

## Decision

Store events in a numeric-ID map with chronological `event_order` and per-character indexes. Cache derived sessions and invalidate the cache when event data changes. Migrate legacy flat event arrays during initialization.

## Consequences

Reads for a character and its latest event avoid scanning the entire event map. The data is still local SavedVariables and remains subject to WoW’s persistence timing. Schema changes require in-code migration or compatibility logic. Rebuilding indexes is required after pruning and restore.
