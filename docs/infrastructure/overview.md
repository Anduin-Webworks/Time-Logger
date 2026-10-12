# Infrastructure overview

TimeLogger is an in-client WoW addon. The runtime is the Retail WoW client; persistence is the WoW SavedVariables system; UI, timers, event delivery, locale, map, subscription, and clipboard capabilities come from WoW APIs.

No server, hosted database, network integration, worker, container, cloud resource, or monitoring agent is present in this repository. Infrastructure outside the addon is **Unknown**.

## Boundaries

- Addon package: Lua files, localization files, and two PNG assets.
- Runtime: Retail WoW client, using the interface versions in `TimeLogger.toc`.
- Persistence: `WTF\Account\<account>\SavedVariables\TimeLogger.lua`.
- External services: none identified from source.

