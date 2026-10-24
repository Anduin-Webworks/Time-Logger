# Using TimeLogger

## Installation

Copy the addon directory into `Interface\AddOns\TimeLogger`, enable it in the Retail WoW addon list, and log in. Login and logout recording is automatic.

## Open the window

Use `/timelogger`, `/tlog`, or `/tl` without an argument. The optional minimap button also toggles the window with a left click. The button is enabled by default and can be hidden with the **Minimap button** checkbox.

## Browse and export

The window displays derived sessions in a virtualized table. Type into the filter fields below the column headers; filters combine with AND logic. **Sessions CSV** and **Sessions JSON** open a selectable export popup containing the current filtered rows. Copying uses the WoW clipboard API when available and otherwise selects the text for manual copying.

The table is session-only in the current release. Subscription fields remain in stored data and exports, but there is no visible Subscription Active table column.

## Crash recovery

The **Crash recovery heartbeat** control stores an interval from 1 to 10 minutes, in one-minute steps; the default is 5 minutes. While logged in, TimeLogger writes a last-known-alive snapshot immediately and updates it at that interval. If the next login finds a previous login without a logout, it creates a synthetic logout from the latest valid snapshot and marks the event and derived session as recovered.

Recovery is limited by WoW SavedVariables persistence. If the client terminates before the latest snapshot is saved, that snapshot may not be available. A recovered end time can be as old as the selected interval.

## Cleanup and restore

Enter at least one day in the data-cleanup field and choose **Prune**. After confirmation, the current event list is copied to `events_backup` when the backup is missing or more than one hour old, then events older than the cutoff are removed.

**Restore backup** replaces the current events with the available snapshot after confirmation. It rebuilds indexes and invalidates derived sessions. This is a local recovery mechanism, not an independent external backup.

## Minimap button

- Left click: toggle the TimeLogger window.
- Drag: move the icon around the minimap; the angle is stored per account.
- Ctrl + right click: reload the UI.

## Limitations

The repository does not establish compatibility beyond the Retail interface versions declared in `TimeLogger.toc`. Live behavior of WoW APIs, clipboard support, SavedVariables write timing, and third-party distribution are **Needs verification** in a running client.
