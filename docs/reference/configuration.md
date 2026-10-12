# Configuration reference

## UI settings

| Setting | Default | Range/values | Storage |
|---|---:|---|---|
| Minimap button | enabled | enabled/disabled | `TimeLoggerDB.minimap.enabled` |
| Minimap angle | 220 degrees | changed by dragging | `TimeLoggerDB.minimap.angle` |
| Crash recovery heartbeat | 5 minutes | 1–10 minutes, one-minute steps | `TimeLoggerDB.heartbeatSec` |

The cleanup days value is entered for an individual prune action; it is not documented in source as a persisted setting.

## Other persisted values

- `TimeLoggerDB.subExpiresUnix` is set by `/tl sub <days>`.
- `TimeLoggerDB.played_totals` stores playtime totals keyed by realm and character.
- `TimeLoggerDB.events_backup` and `events_backup_time` implement the pre-prune snapshot.

The source does not use an environment-variable file or external configuration file. WoW client APIs determine locale, patch, expansion, location, subscription status, and clipboard availability.

