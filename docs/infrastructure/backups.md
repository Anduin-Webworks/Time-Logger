# Backups and restoration

The addon has one built-in backup mechanism: `events_backup` in `TimeLoggerDB`.

- It is refreshed before pruning when missing or more than one hour old.
- It contains a copy of the complete event list as it existed before that prune.
- Restore replaces current events, assigns fresh IDs, rebuilds indexes, and invalidates sessions.
- It is not a versioned backup history and is not an external file copy.

External backup, retention, off-device storage, and disaster recovery procedures are **Unknown**. Users who need durable protection should back up the WoW SavedVariables file outside the addon, subject to the user's own operational policy.

