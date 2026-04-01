# TimeLogger

Retail addon that records **login** and **logout** times, exports **raw events** and **derived sessions** as CSV or JSON, and can **prune** old data while keeping a backup snapshot.

## Files

| File | Purpose |
|------|---------|
| `TimeLogger.toc` | Metadata, SavedVariables, optional icon / CurseForge ID |
| `TimeLogger.lua` | Logging, heartbeat recovery, export UI |
| `TimeLoggerLogo.png` | Optional; referenced by `IconTexture` in the TOC |

## Commands

- `/timelogger` or `/tlog` — opens the export window (events and sessions, CSV/JSON, copy, prune).

## Raw events

On **`PLAYER_LOGIN`**, a row is appended: `unix`, `utc` (ISO UTC), `event = login`, `character`, `realm`.

On **`PLAYER_LOGOUT`**, the same shape with `event = logout`.

Optional field **`recovery`** — `true` only on a **synthetic logout** inserted after a crash or any case where a real logout was never saved (see below).

Data lives in **`TimeLoggerDB`** (SavedVariables).

## Crash recovery (`temp_logout`)

If the client exits without firing **`PLAYER_LOGOUT`** (crash, force quit, etc.), the last row in `events` can be a **`login`** with no matching **`logout`**.

The addon stores **`TimeLoggerDB.temp_logout`**: the same shape as a logout row, updated:

- once **immediately** after each successful `PLAYER_LOGIN` (while in world), and  
- every **5 minutes** while you remain logged in.

On the **next** `PLAYER_LOGIN`, if the **last** stored event is still **`login`**, the addon **appends a synthetic `logout`** using the last **`temp_logout`** snapshot, marked with **`recovery = true`**.

**Limitation:** Saved variables are usually **written on logout or `/reload`**, not continuously. If the client dies before a save that included a recent `temp_logout`, recovery may not run; you can still see **login → login** with no logout. When recovery does apply, the logout time can be up to **~5 minutes** after the real exit (or sooner thanks to the immediate update on login).

On a **clean** `PLAYER_LOGOUT`, the heartbeat ticker stops and **`temp_logout` is cleared**.

## Sessions (derived)

Sessions are **computed** from the event list (sorted by `unix`), per character (`realm|name`):

| Status | Meaning |
|--------|---------|
| `closed` | Normal `login` then `logout` |
| `no_logout` | Another `login` for that character before a `logout` (e.g. crash; next login closes the prior session) |
| `open` | `login` with no `logout` yet (still in game, or exporting before logout) |

Export from the window: **Sessions CSV** / **Sessions JSON**.

**Sessions CSV columns:** `session_id`, `start_unix`, `start_utc`, `end_unix`, `end_utc`, `duration_sec`, `character`, `realm`, `status`

## Prune

At the bottom of the window: keep events from the last **N** days, then **Prune** (with a confirmation dialog).

Before removing old rows, the addon copies the **full current** `events` array into **`TimeLoggerDB.events_backup`** and sets **`TimeLoggerDB.events_backup_time`** (Unix time of the backup).

## Export formats

### Events CSV

Header:

`unix,utc_iso,event,character,realm,recovery`

`recovery` is `1` if the row is a recovered synthetic logout, else `0`.

### Events JSON

Array of objects; **`recovery`** is only present when `true`.

## Saved data location

`WTF\Account\<account>\SavedVariables\TimeLogger.lua`

Relevant keys under **`TimeLoggerDB`**: `events`, optional `events_backup`, `events_backup_time`, `temp_logout`.
