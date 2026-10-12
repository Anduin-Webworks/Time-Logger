# Getting started

## Install

Copy the project directory to `Interface\AddOns\TimeLogger` in a Retail WoW installation. The manifest declares interface versions `120007` and `120100`; whether another client version accepts the addon is **Needs verification**.

Log in with the addon enabled. `PLAYER_LOGIN` and `PLAYER_LOGOUT` are recorded automatically.

## Open the window

Use `/timelogger`, `/tlog`, or `/tl` with no argument. The optional minimap button also toggles the window.

The window starts in the sessions view. Each table column has a substring filter; multiple filters are combined with AND logic and are case-insensitive.

## Export

Use **Sessions CSV** or **Sessions JSON**. If filters are active, only matching rows are exported. The export opens in a selectable popup. **Copy to clipboard** uses `C_ChatInfo.CopyStringToClipboard` when available; otherwise the popup selects all text so it can be copied manually.

The exact field names are in [Data formats](../reference/data-formats.md).

## Minimap button

- Left-click toggles the window.
- Dragging changes its orbit position and saves the angle.
- Ctrl + right-click reloads the UI.
- The **Minimap button** checkbox controls visibility and is enabled by default.

