# TimeLogger

TimeLogger is a Retail WoW addon that records character logins and logouts, derives playable sessions, and provides an in-game table for browsing, filtering, and exporting that history.

Current release: **2.6.3**

## Features

- Records `PLAYER_LOGIN` and `PLAYER_LOGOUT` events automatically.
- Recovers sessions after a crash or force quit by writing configurable heartbeat snapshots.
- Stores events in an indexed SavedVariables database and derives cached sessions from them.
- Shows a virtualized, spreadsheet-style sessions table with per-column filters.
- Exports the current session list, or only the rows matching active filters, as CSV or JSON.
- Captures patch, expansion, location, weekday, and local date/time with events.
- Shows current-session duration and playtime totals for the current character and all characters.
- Provides optional, draggable minimap access.
- Prunes old events with a pre-prune backup and can restore that backup later.
- Includes localized UI text for the supported WoW client locales.

## Installation and use

Install the addon in `Interface\AddOns\TimeLogger`, then log in. Events are recorded automatically.

Open the window with any of these commands:

| Command | Action |
|---------|--------|
| `/timelogger` | Open the TimeLogger window |
| `/tlog` | Open the TimeLogger window |
| `/tl` | Open the window, or show command help when an argument is supplied |
| `/tl sub <days>` | Set the stored subscription expiration to the specified number of days from now; zero is allowed |

The optional minimap button toggles the window. It is enabled by default and can be disabled with the **Minimap button** checkbox.

## Export window

The window displays derived sessions rather than raw login/logout events. Its main controls are:

- **Sessions CSV** and **Sessions JSON** — open a selectable export popup.
- **Copy to clipboard** — uses the WoW clipboard API when available.
- **Select all** — selects the export text for manual copying when clipboard access is unavailable.
- **Minimap button** — show or hide the launcher.
- **Prune** — remove events older than a selected number of days after confirmation.
- **Restore backup** — replace the current event list with the available `events_backup` after confirmation.
- **Crash recovery heartbeat** — choose an interval from 1 to 10 minutes, in one-minute steps. The default is 5 minutes, and changing it restarts the active ticker immediately.

The table has filter boxes below its headers. Filters combine with AND logic. If filters are active when an export button is used, only the matching visible sessions are exported.

## Crash recovery

After login, TimeLogger maintains a last-known-alive snapshot immediately and updates it at the configured heartbeat interval. If the previous saved event is a login without a matching logout, the next login creates a synthetic logout from that snapshot and marks it with `recovery = true`.

Recovery depends on the latest heartbeat having been written to SavedVariables. WoW normally persists SavedVariables on logout or `/reload`, so a crash before that save can prevent recovery. A recovered logout can also be as old as the selected heartbeat interval. On a clean logout, the ticker stops and the temporary snapshot is cleared.

## Sessions

Sessions are built chronologically per character from the event log and cached until events change.

| Status | Meaning |
|--------|---------|
| `closed` | Normal login followed by logout |
| `no_logout` | Another login occurred before a logout was recorded |
| `open` | Login has no logout yet |
| `recovered` | Closed by a synthetic crash-recovery logout |

The table shows session start/end times, duration, patch, expansion, login/logout locations, weekday, character, realm, and status. Subscription status is still retained in event data and exports, but is not shown as a table column in the current release.

## Recorded event data

Each event contains the following fields when available:

| Field | Description |
|-------|-------------|
| `unix` | Synchronized Unix timestamp |
| `utc` | ISO 8601 UTC instant with a `Z` suffix |
| `local_dt` | Local date/time in `YYYY-MM-DD HH:MM:SS` format |
| `event` | `login` or `logout` |
| `character` / `realm` | Character identity |
| `patch` | Game version from `GetBuildInfo()` |
| `expansion` | Current expansion name |
| `location` | Zone and subzone when available |
| `weekday` | ISO weekday, where Monday is 1 and Sunday is 7 |
| `subscription` | `subscribed`, `not_subscribed`, `trial`, `veteran`, or `unknown` |
| `subActive` | Whether the TimeLogger subscription-expiration value was active at that event |
| `recovery` | `true` only for synthetic recovery logouts |

Login location may be enriched shortly after login once the world has loaded. Older records may not contain fields introduced after they were created.

## Storage, pruning, and restore

Data is stored locally in the WoW SavedVariables file:

`WTF\Account\<account>\SavedVariables\TimeLogger.lua`

The current storage schema is v3. It uses numeric event IDs, chronological ordering, per-character indexes, cached sessions, playtime totals, minimap settings, and the `events_backup` snapshot.

When pruning, TimeLogger copies the complete current event list to `events_backup` first. The backup is refreshed when it is missing or more than one hour old. The **Restore backup** button replaces the current event list with that snapshot, rebuilds indexes and sessions, and refreshes the table.

Legacy flat event arrays are migrated automatically when the database is first loaded.

## Export formats

Exports use stable English field names and raw values for spreadsheet and scripting compatibility. The in-game table localizes labels and display values.

The current UI exports sessions only:

### Sessions CSV

`session_id,start_unix,start_utc,start_local_dt,end_unix,end_utc,end_local_dt,duration_sec,patch,expansion,start_location,end_location,weekday,subscription,subActive,character,realm,status`

### Sessions JSON

An array of objects with matching fields. The JSON character field is named `char` for historical compatibility.

Raw login/logout events remain in SavedVariables and use the corresponding event fields described above.

## Minimap button

- **Left-click** — toggle the TimeLogger window.
- **Drag** — reposition the button around the minimap; the angle is saved per account.
- **Ctrl + right-click** — reload the UI.

The addon uses `TimeLoggerButton.png` for the launcher icon and falls back to a pocket-watch icon if necessary.

## Localization

Supported locales are `deDE`, `enUS`/`enGB`, `esES`, `esMX`, `frFR`, `itIT`, `koKR`, `ptBR`, `ruRU`, `zhCN`, and `zhTW`.

## Project structure

| File / folder | Purpose |
|---------------|---------|
| `TimeLogger.toc` | Addon manifest, version, and SavedVariables declaration |
| `TimeLogger.lua` | Event handlers, UI, exports, slash commands, and heartbeat control |
| `TimeLoggerStorage.lua` | Indexed event database, session derivation, pruning, and backup restore |
| `TimeLoggerContext.lua` | Patch, expansion, location, weekday, subscription, and local-time capture |
| `TimeLoggerTableView.lua` | Virtualized table and column filtering |
| `TimeLoggerMinimap.lua` | Draggable minimap launcher |
| `TimeLoggerLocale.lua` | Localization loader and formatters |
| `Locales/enUS.lua` | Base English strings |
| `Locales/LocaleData.lua` | Other locale overlays |

## Requirements

- Retail WoW, using one of the interface versions listed in `TimeLogger.toc`.
