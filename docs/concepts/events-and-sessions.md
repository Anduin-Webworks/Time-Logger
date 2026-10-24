# Events and sessions

## Raw events

TimeLogger records two event types:

- `login`, captured from `PLAYER_LOGIN`.
- `logout`, captured from `PLAYER_LOGOUT` or synthesized by crash recovery.

Each event is stored with a synchronized Unix timestamp, UTC representation, local date/time, character and realm, patch, expansion, location, weekday, subscription status, the stored subscription-expiration flag, and optional recovery metadata. Older records can lack fields added in later releases.

## Derived sessions

A session is derived by scanning events in chronological `event_order`, separately for each character/realm pair. A login opens a session; the next matching logout closes it. The table and current exports show sessions, not raw events.

Session statuses are:

| Status | Meaning |
| --- | --- |
| `open` | A login has no matching logout yet. |
| `closed` | A normal logout closed the session. |
| `recovered` | A synthetic logout closed the session after a missing logout. |
| `no_logout` | A later login arrived while an earlier session was still open. |

The session cache is invalidated whenever events are inserted, updated, pruned, or restored. It is rebuilt lazily when the table needs it.

## Why both forms exist

Raw events preserve the durable history and context captured at each boundary. Sessions provide a convenient, paired view for players and exports. The two views should not be treated as interchangeable: an event can exist without forming a complete session, and session status records how pairing occurred.

## Time semantics

The addon uses `GetServerTime()` when available and falls back to Lua `time()`. UTC strings are generated independently of the player’s local timezone. `local_dt` is formatted in the client’s local environment. Weekday values use ISO numbering: Monday is 1 and Sunday is 7.
