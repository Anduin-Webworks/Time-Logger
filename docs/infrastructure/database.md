# Database and persistence

TimeLogger's “database” is a structured Lua table written by WoW as the `TimeLoggerDB` SavedVariables root. It is not a relational database and there are no migrations outside the Lua load-time migration logic.

The current schema version is 3. See the [data model](../development/data-model.md) for the stored shape and index lifecycle. SavedVariables are account-scoped by WoW; the source does not define a separate profile or character scope beyond the keys it stores.

WoW controls when SavedVariables are written, normally during logout or UI reload. This save lifecycle is an important constraint for crash recovery and for inspecting changes during development.

