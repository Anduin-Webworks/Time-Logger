# Developer getting started

## Required environment

The repository contains Lua 5.1 VS Code settings and references the `ketho.wow-api` annotation library. The addon itself runs inside Retail WoW and depends on WoW globals such as `CreateFrame`, `C_Timer`, `GetServerTime`, `C_Map`, and `C_ChatInfo`.

No package manager manifest, dependency lockfile, build script, test runner, CI workflow, or standalone runtime harness is present in this checkout. Lua syntax checking and in-game behavior validation therefore require contributor tooling outside the repository or a WoW client. **Needs verification:** the project's preferred packaging/release tool and maintainer workflow.

## Local loop

1. Edit the Lua or localization files.
2. Copy or link the addon directory into the WoW `Interface\AddOns` directory.
3. Reload the UI or restart the client.
4. Exercise the relevant event, UI, export, recovery, migration, or restore behavior in-game.
5. Inspect chat output and the SavedVariables file after WoW saves it.

The source does not provide automated tests, so static inspection alone does not validate WoW API behavior.

## Where to begin

- User-visible behavior and event flow: `TimeLogger.lua`.
- Persistence, migration, indexes, sessions, pruning, and restore: `TimeLoggerStorage.lua`.
- Captured metadata: `TimeLoggerContext.lua`.
- Table filtering and virtualization: `TimeLoggerTableView.lua`.
- Launcher behavior: `TimeLoggerMinimap.lua`.
- String loading and formatting: `TimeLoggerLocale.lua`, `Locales/enUS.lua`, and `Locales/LocaleData.lua`.

