# SpaceWindowSwitcher

Minimal native macOS POC for an AltTab-style current-Desktop window switcher.

```sh
cd /Users/amitsharma/Desktop/LiveNotepad/SpaceWindowSwitcher
make run
```

Shortcut: `Option-Tab`

Install for login startup:

```sh
make autolaunch
```

This copies the app to `~/Applications/SpaceWindowSwitcher.app` and registers `~/Library/LaunchAgents/local.spaceswitcher.SpaceWindowSwitcher.plist`.

Remove login startup:

```sh
make uninstall-autolaunch
```

Package for teammates:

```sh
make package
```

Share `dist/SpaceWindowSwitcher.zip`. Teammates should unzip it, move the app to Applications, open it once, and grant Accessibility permission from the menu bar item if exact window focusing is needed.

Behavior:
- Lists windows from the active Desktop/Space using SkyLight Space IDs plus CoreGraphics windows.
- Repeated `Option-Tab` cycles forward.
- Releasing `Option` activates selected.
- `Escape` cancels.
- `Return` activates selected.

Exact window focusing needs Accessibility permission. The shortcut never opens the permission prompt; use the menu bar item `Request Accessibility Permission` when you want to grant it.

SkyLight is a private macOS framework. This POC uses it because public CoreGraphics `.optionOnScreenOnly` can miss Electron windows such as Slack.
