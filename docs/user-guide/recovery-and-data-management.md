# Recovery and data management

## Crash recovery heartbeat

The **Crash recovery heartbeat** slider controls how often TimeLogger updates its last-known-alive snapshot. The verified range is 1–10 minutes in one-minute steps, with a default of 5 minutes. Changing it while the ticker is active restarts the ticker immediately.

On a later login, a valid snapshot can be converted into a synthetic logout. The resulting session is marked `recovered`.

## Pruning

Enter a number of days in the data-cleanup control and confirm. The addon first copies the complete current event list to `events_backup` when no backup exists or the existing backup is older than one hour, then removes events before the cutoff and rebuilds indexes and cached sessions.

Pruning cannot be undone from the current event list except through the available backup snapshot. The backup is an in-addon snapshot, not an external file.

## Restoring

**Restore backup** is available when `events_backup` contains rows. After confirmation it replaces the current event list with the snapshot, assigns fresh numeric IDs, rebuilds indexes, invalidates cached sessions, and refreshes the table and totals.

## Playtime totals

The UI shows a current-character total and an all-character total. WoW's `TIME_PLAYED_MSG` is used when available. On first login for a character without a saved total, the addon can fall back to summing event intervals, including the currently open interval.

