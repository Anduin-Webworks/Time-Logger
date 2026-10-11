# Runtime workflows

## Addon load and login

`ADDON_LOADED` ensures the database and initializes the minimap launcher. `PLAYER_LOGIN` first attempts orphan recovery, records a new login, writes an immediate heartbeat snapshot, starts the ticker, applies the event-based playtime fallback if needed, and schedules location enrichment and a WoW playtime request.

## Logout

`PLAYER_LOGOUT` stops the ticker, requests playtime, clears the temporary snapshot, and records a normal logout.

## Refresh and export

Opening the window creates the UI once, refreshes the session rows and totals, and shows the frame. Table filters are applied by the widget. Export functions read the filtered rows when filters are active, serialize sessions, and display the result in a selectable popup.

## Prune and restore

Both actions are confirmation-gated. Prune snapshots first when the one-hour backup policy says it should, removes old rows, and rebuilds derived state. Restore replaces events from the snapshot and rebuilds the same derived state.

## Release workflow

The repository contains a changelog and addon manifest version, but no release script, CI workflow, packaging configuration, or documented upload process. The authoritative release/upload workflow is **Unknown** and needs maintainer verification.

