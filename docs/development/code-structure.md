# Code structure

```text
Time-Logger/
├── TimeLogger.toc
├── TimeLogger.lua
├── TimeLoggerStorage.lua
├── TimeLoggerContext.lua
├── TimeLoggerTableView.lua
├── TimeLoggerMinimap.lua
├── TimeLoggerLocale.lua
├── Locales/
│   ├── enUS.lua
│   └── LocaleData.lua
├── README.md
├── CHANGELOG.md
├── LICENSE
└── .vscode/settings.json
```

## Investigation guide

| Change | Start here | Then inspect |
|---|---|---|
| Login/logout behavior | `TimeLogger.lua` event handler | `TimeLoggerContext.lua`, `TimeLoggerStorage.lua` |
| Crash recovery | `RecoverOrphanLogout`, heartbeat helpers | `temp_logout` storage fields and session derivation |
| Session status or pairing | `TimeLoggerStorage:BuildSessions` | locale status formatters and exports |
| SavedVariables schema | `TimeLoggerStorage:EnsureDB` | migration, indexes, backup methods |
| Table columns or filtering | `GetSessionColumns`, `RefreshTableView` | `TimeLoggerTableView.lua` |
| CSV/JSON output | session serializer functions in `TimeLogger.lua` | [data formats](../reference/data-formats.md) |
| Minimap behavior | `TimeLoggerMinimap.lua` | `TimeLoggerDB.minimap` |
| Text or locale fallback | `TimeLoggerLocale.lua` | `Locales/enUS.lua`, `Locales/LocaleData.lua` |
| Addon load order or version | `TimeLogger.toc` | WoW client interface compatibility |

## Common change locations

`TimeLogger.lua` is intentionally broad and is the first place to inspect for user-visible workflows. Keep persistence mechanics in `TimeLoggerStorage.lua` and metadata collection in `TimeLoggerContext.lua`; otherwise future changes become harder to test and reason about.

