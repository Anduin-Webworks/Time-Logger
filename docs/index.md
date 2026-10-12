# TimeLogger documentation

TimeLogger is a Retail World of Warcraft addon that records character login/logout events, derives playable sessions, and presents the history for filtering and CSV/JSON export.

This documentation supplements the project [README](../README.md). The README remains the introduction and quick-start summary; these pages explain the behavior and implementation discovered in the source tree.

## Start here

- [User guide](user-guide/getting-started.md) — install, open, filter, export, and manage data in-game.
- [Concepts](concepts/session-model.md) — how events become sessions and how crash recovery affects the result.
- [Developer setup](development/getting-started.md) — local tooling and the limits of local validation.
- [Architecture](development/architecture.md) — runtime components and data flow.
- [Code structure](development/code-structure.md) — where to investigate and change behavior.
- [Data model](development/data-model.md) — SavedVariables schema, indexes, sessions, backups, and playtime.
- [Reference](reference/commands.md) — slash commands, configuration, and export formats.

## Documentation status

Facts in these pages were derived from `TimeLogger.toc`, the Lua sources, localization files, `.vscode/settings.json`, `.gitignore`, `README.md`, and `CHANGELOG.md` as present in this checkout. Items that cannot be established from those files are labeled **Unknown** or **Needs verification**.

## Documentation inventory

| Area | Page | Audience | Status |
|---|---|---|---|
| Concepts | [Session model](concepts/session-model.md) | Users, developers | Verified from storage/session code |
| User guide | [Getting started](user-guide/getting-started.md) | Users | Verified from README and UI code |
| User guide | [Recovery and data management](user-guide/recovery-and-data-management.md) | Users | Verified from recovery, prune, and restore code |
| Development | [Getting started](development/getting-started.md) | Contributors | Tooling facts verified; runtime setup partly needs verification |
| Development | [Architecture](development/architecture.md) | Developers | Verified from module boundaries and call flow |
| Development | [Code structure](development/code-structure.md) | Developers | Verified from repository tree |
| Development | [Data model](development/data-model.md) | Developers | Verified from `TimeLoggerStorage.lua` |
| Development | [Workflows](development/workflows.md) | Developers | Runtime workflows verified; release workflow partly unknown |
| Development | [Contributing](development/contributing.md) | Contributors | Repository policy facts are limited |
| Development | [ADR: indexed SavedVariables](development/decisions/0001-indexed-savedvariables.md) | Developers | Evidence-supported decision |
| Infrastructure | [Overview](infrastructure/overview.md) | Maintainers | Verified boundaries; hosted infrastructure is not present |
| Infrastructure | [Deployment](infrastructure/deployment.md) | Maintainers | Installation verified; release automation unknown |
| Infrastructure | [Database](infrastructure/database.md) | Maintainers | SavedVariables behavior verified |
| Infrastructure | [Backups](infrastructure/backups.md) | Users, maintainers | In-addon backup verified; external backup unknown |
| Infrastructure | [Monitoring](infrastructure/monitoring.md) | Maintainers | No monitoring service found; in-game signals documented |
| Reference | [Commands](reference/commands.md) | Users, developers | Verified from slash handler |
| Reference | [Configuration](reference/configuration.md) | Users, developers | Verified from UI and storage defaults |
| Reference | [Data formats](reference/data-formats.md) | Developers, users | Verified from serializers |

