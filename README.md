# TimeLogger

Retail WoW addon that records **login** and **logout** times, enriches each event with client context (patch, location, subscription, and more), and lets you **browse**, **filter**, and **export** your history from an in-game spreadsheet-style window.

## Features

- Automatic **login/logout** logging with crash recovery via heartbeat snapshots
- **Indexed storage** designed for thousands of rows without performance issues
- **Table view** with per-column header filters (Excel-style)
- **CSV/JSON export** for raw events and derived sessions (copy to clipboard)
- **Context capture** on each event: patch version, expansion, location, weekday, subscription status, local datetime
- **Localization** for all native WoW client languages
- **Minimap button** (optional) to toggle the window; draggable around the minimap
- **Prune** old events with automatic pre-prune backup

## Commands

| Command | Action |
|---------|--------|
| `/timelogger` | Open the export window |
| `/tlog` | Same as above |

The **minimap button** (when enabled) **toggles** the window open and closed. Slash commands always **open** it.

## Project structure

| File / folder | Purpose |
|---------------|---------|
| `TimeLogger.toc` | Addon manifest, version, SavedVariables |
| `TimeLogger.lua` | Event handlers, export UI shell, slash commands |
| `TimeLoggerStorage.lua` | Indexed event database (SavedVariables-backed) |
| `TimeLoggerContext.lua` | Captures patch, expansion, location, subscription, etc. |
| `TimeLoggerTableView.lua` | Reusable spreadsheet table with header filters |
| `TimeLoggerMinimap.lua` | Draggable minimap launcher |
| `TimeLoggerLocale.lua` | Localization loader and formatters |
| `Locales/enUS.lua` | Base English strings |
| `Locales/LocaleData.lua` | Translations for all other WoW locales |
| `TimeLoggerLogo.png` | Optional; used for addon icon and minimap button |

## Export window

The UI uses a gold / silver / black theme:

- **Header** — title, current session duration, mode buttons (Events/Sessions × CSV/JSON), minimap toggle, copy to clipboard
- **Table** — scrollable, filterable data grid (virtualized rows for performance)
- **Footer** — prune controls and per-character / account playtime summary

Filter boxes sit under each column header. Type to filter; multiple columns combine with AND logic. **Copy to clipboard** exports the current format; if filters are active, only visible rows are copied.

## Raw events

On **`PLAYER_LOGIN`** and **`PLAYER_LOGOUT`**, a row is appended to the indexed store.

### Core fields

| Field | Description |
|-------|-------------|
| `unix` | Server-local Unix timestamp |
| `utc` | ISO 8601 UTC instant (`…Z`) |
| `event` | `login` or `logout` |
| `character` | Character name |
| `realm` | Realm name |
| `recovery` | Optional; `true` only on synthetic crash-recovery logouts |

### Context fields (v2.2+)

| Field | Description |
|-------|-------------|
| `patch` | Game version from `GetBuildInfo()` (e.g. `12.0.1`) |
| `expansion` | Current expansion display name |
| `location` | Zone and subzone at login/logout (login location may update ~2s after login once the world loads) |
| `weekday` | ISO weekday from event time (1 = Monday … 7 = Sunday) |
| `subscription` | Account status code: `subscribed`, `not_subscribed`, `trial`, `veteran`, or `unknown` |
| `local_dt` | Local machine datetime (`YYYY-MM-DD HH:MM:SS`) |

**Subscription note:** WoW’s API exposes recurring subscription via `IsSubscribed()` and trial states separately. Accounts using **WoW Token game time only** (no recurring sub) typically appear as `not_subscribed`.

Older rows recorded before v2.2 leave context fields empty.

## Crash recovery (`temp_logout`)

If the client exits without **`PLAYER_LOGOUT`** (crash, force quit, etc.), the last stored event may be a **`login`** with no matching **`logout`**.

The addon maintains **`TimeLoggerDB.temp_logout`** — a logout-shaped snapshot updated:

- once **immediately** after each successful login, and  
- every **5 minutes** while you remain in game.

On the **next** login, if the last event is still **`login`**, a **synthetic logout** is inserted from the last heartbeat, with **`recovery = true`**.

**Limitation:** SavedVariables are written on logout or `/reload`, not continuously. If the client dies before a save that included a recent heartbeat, recovery may not run. When recovery does apply, the logout time can be up to **~5 minutes** after the real exit.

On a clean logout, the heartbeat ticker stops and **`temp_logout`** is cleared.

## Sessions (derived)

Sessions are **computed** from the event log (chronological, per character). They are cached and invalidated when events change.

| Status | Meaning |
|--------|---------|
| `closed` | Normal login then logout |
| `no_logout` | Another login before logout (e.g. crash) |
| `open` | Login with no logout yet |
| `recovered` | Closed by a synthetic recovery logout |

Session exports include login/logout locations, patch, expansion, weekday, subscription, and local datetimes from the paired events.

## Storage

Data persists in **`TimeLoggerDB`** (SavedVariables). There is no external database — WoW addons store Lua tables to disk on logout/reload.

**Schema v3** (current) uses:

- `events[id]` — event records keyed by numeric ID  
- `event_order[]` — chronological ID list  
- `indexes.by_character` / `indexes.last_by_character` — fast per-character lookups  
- `sessions` — optional cached derived sessions  
- `played_totals` — per-character playtime from the game client  
- `minimap` — `{ enabled, angle }` for the minimap button  
- `events_backup` / `events_backup_time` — pre-prune snapshot  

Legacy flat `events[]` arrays are migrated automatically on first load.

**On disk:** `WTF\Account\<account>\SavedVariables\TimeLogger.lua`

## Prune

At the bottom of the window: enter days, click **Prune**, confirm.

Events older than N days are removed. The full current list is copied to **`events_backup`** first (refreshed if the previous backup is over an hour old).

## Export formats

Technical English field names and raw stored values are used in exports so spreadsheets and scripts stay consistent. The in-game table localizes labels and display values.

### Events CSV

`unix,utc_iso,local_dt,weekday,event,character,realm,location,patch,expansion,subscription,recovery`

### Events JSON

Array of objects with the same fields; `recovery` is only included when `true`.

### Sessions CSV

`session_id,start_unix,start_utc,start_local_dt,end_unix,end_utc,end_local_dt,duration_sec,patch,expansion,start_location,end_location,weekday,subscription,character,realm,status`

### Sessions JSON

Array of objects with matching fields (`char` instead of `character` in JSON for historical compatibility).

## Localization

Supported locales: **deDE**, **enUS** (also **enGB**), **esES**, **esMX**, **frFR**, **itIT**, **koKR**, **ptBR**, **ruRU**, **zhCN**, **zhTW**.

UI strings, column headers, weekdays, subscription labels, and chat messages follow the WoW client language. To add or edit translations, update `Locales/enUS.lua` (base) and `Locales/LocaleData.lua` (overlays).

## Minimap button

Enabled by default. Uncheck **Minimap button** in the export window to hide it.

- **Left-click** — toggle the export window  
- **Drag** — reposition around the minimap (saved per account)  
- **Ctrl + right-click** — reload the UI (`/reload`)

Uses `TimeLoggerLogo.png` when present; otherwise a pocket-watch fallback icon.

## Requirements

- **Retail WoW** (Interface versions listed in `TimeLogger.toc`)
