# CHANGELOG

## v2.6.3

### Bug Fixes

- Fixed the identification of the expansion almost always set to `Classic`.
- Fixed a rendering issue on the row headers.
- Fixed the `Local Time` fetching logic.
- Removed the Subscription status column.

## v2.6.0

### Backup restore and crash-recovery settings

- Added a confirmed **Restore backup** action for recovering events from `events_backup`
- Restoring a backup rebuilds event indexes and cached sessions before refreshing the table view
- Added a persisted crash-recovery heartbeat slider from **1 to 10 minutes** in one-minute steps
- Changing the heartbeat interval immediately restarts the active recovery ticker

## v2.5.0

### Correctness and maintainability

- JSON exports now escape all JSON control characters, producing valid output for tabs, backspaces, form feeds, and other control bytes
- Clipboard export now checks the clipboard API result and correctly falls back to manual selection when copying fails
- `/tl sub <days>` now rejects negative values while still allowing zero
- Export Sessions UI text now uses the localization system
- Removed the duplicate vertical-scroll handler assignment from the table view

## v2.4.0

### Export UI fixes

- Fixed **Sessions CSV** / **Sessions JSON** buttons not responding to clicks (custom buttons now register mouse input and attach labels correctly)
- Fixed popup **Copy to clipboard** and **Select all** buttons showing raw locale keys (`BTN_COPY_CLIPBOARD`, `BTN_SELECT_ALL`) instead of translated text
- Popup button labels now use the correct keys (`BTN_COPY`, `BTN_SELECT_ALL`) and refresh each time the export popup opens
- **Copy to clipboard** falls back to selecting all text when the WoW clipboard API is unavailable
- Added `BTN_SELECT_ALL` to `Locales/enUS.lua` and all locale overlays in `Locales/LocaleData.lua`

## v2.3.1

### Minimap button update

- **Ctrl + right-click** on the minimap icon reloads the UI (`ReloadUI`)
- Tooltip updated with the new shortcut (localized)
- Minimap orbit radius tuned to sit on the tracking ring (LibDBIcon-style placement)

## v2.3.0

### Minimap button

- Added a draggable **minimap icon** that toggles the export window (left-click)
- Added **Minimap button** checkbox in the export UI to show or hide the icon
- Minimap position and enabled state persist in `TimeLoggerDB.minimap`
- New module: `TimeLoggerMinimap.lua`

## v2.2.0

### Event context fields

- Each login/logout now records **patch version**, **expansion name**, **in-game location**, **weekday**, **subscription status**, and **local datetime**
- Login **location** is enriched shortly after login once zone data is available
- Session exports include login/logout locations and context from paired events
- Export window widened to fit additional columns
- New module: `TimeLoggerContext.lua`
- Storage schema bumped to **v3** (existing events kept; new fields empty on old rows)

### Subscription API note

- Uses `IsSubscribed()`, `IsTrialAccount()`, and `IsVeteranTrialAccount()` where available
- Game-time-only accounts (no recurring sub) may report as `not_subscribed`

## v2.1.0

### Localization

- Full localization framework
- Plans to add all native WoW client languages (11 locale codes, using translation tools)
- Export formats remain English/technical for compatibility with external tools
- New files: `TimeLoggerLocale.lua`, `Locales/enUS.lua`, `Locales/LocaleData.lua`

## v2.0.0

### Table view UI

- Replaced raw text export area with a **spreadsheet-style table** (virtual scrolling)
- **Per-column header filters** with debounced substring matching
- Gold / silver / black visual theme; active export mode highlighted
- Copy to clipboard respects active filters when exporting visible rows
- New module: `TimeLoggerTableView.lua` (self-contained, tweakable independently of the shell UI)

## v1.5.0

### Indexed storage

- Replaced flat `events[]` array with an **indexed database** in SavedVariables (schema v2)
- Numeric event IDs, chronological ordering, per-character indexes
- Cached session derivation; O(1) current-session lookup
- Automatic migration from legacy saves with chat notification
- New module: `TimeLoggerStorage.lua`

## v1.4.x and earlier

### Core addon

- Login/logout event logging to SavedVariables
- CSV and JSON export (events and derived sessions)
- Crash recovery via `temp_logout` heartbeat (5-minute interval)
- Prune with `events_backup` safety snapshot
- Playtime summary (current character and account totals)
- Slash commands: `/timelogger`, `/tlog`
