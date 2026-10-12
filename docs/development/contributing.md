# Contributing

## Before changing behavior

Read the relevant source module and the [architecture](architecture.md), [data model](data-model.md), and [workflows](workflows.md) pages. Preserve the project's existing terminology and localization approach. User-visible changes should be reflected in `README.md` or the appropriate reference page, while version history belongs in `CHANGELOG.md`.

## Validation expectations

There is no repository test suite or CI configuration. Contributors should perform static review and in-game validation for any behavior that depends on WoW APIs, SavedVariables persistence, UI frames, timers, or locale loading.

At minimum, exercise the affected path in a Retail client and check the resulting SavedVariables data after a save/reload. Useful cases include clean login/logout, crash recovery, zero and negative slash-command values, filters plus export, prune confirmation, restore, minimap movement, and locale fallback.

## Pull requests

The checkout history shows feature branches and pull-request merge commits, but no written pull-request template or acceptance checklist is present. Exact review, branch naming, packaging, and upload expectations are **Unknown**; verify them with the project maintainers.

