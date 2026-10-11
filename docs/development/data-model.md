# Data model

The manifest declares one SavedVariables root: `TimeLoggerDB`. `TimeLoggerStorage.lua` treats it as schema version 3.

## Stored shape

```text
TimeLoggerDB
├── schema_version
├── next_event_id
├── event_order[]              -- IDs in chronological insertion order
├── events[id]                  -- event records
├── indexes
│   ├── by_character[realm|character] = [id, ...]
│   └── last_by_character[realm|character] = id
├── sessions[]                  -- derived cache; invalidated after event changes
├── played_totals[realm|character]
├── temp_logout                 -- last-known-alive snapshot
├── events_backup[]             -- pre-prune snapshot
├── events_backup_time
├── heartbeatSec
├── subExpiresUnix
└── minimap
    ├── enabled
    └── angle
```

The exact presence of optional keys depends on the user's history and client APIs. The source initializes missing tables and defaults lazily.

## Event record

The storage copy boundary preserves `unix`, `utc`, `event`, `character`, `realm`, `recovery`, `patch`, `expansion`, `location`, `weekday`, `subscription`, `subActive`, and `local_dt`, plus numeric `id` when copying a record. See [data formats](../reference/data-formats.md) for meanings.

## Indexes and cache lifecycle

`event_order` is the authoritative iteration order. Per-character indexes accelerate lookups for the latest event and a character's event list. Insert and update invalidate `sessions`; pruning and restore rebuild indexes and invalidate the cache. `BuildSessions(false)` reuses the cache when present.

## Migration

When an older or malformed database is detected, the storage module can migrate a legacy flat event array into numeric IDs, `event_order`, and per-character indexes. Existing events are retained where the source can read them; fields introduced later may be absent on older rows. The migration message is localized and printed when legacy rows are moved.

