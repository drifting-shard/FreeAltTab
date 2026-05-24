# SpaceWindowSwitcher

Current-Desktop window switcher for macOS.

## Install

```sh
cd /Users/amitsharma/Desktop/LiveNotepad/SpaceWindowSwitcher
make autolaunch
```

This installs the app to `~/Applications` and starts it on login.

## Permissions

Enable `SpaceWindowSwitcher` in:

- `System Settings -> Privacy & Security -> Accessibility`
- `System Settings -> Privacy & Security -> Input Monitoring`

Then restart:

```sh
pkill SpaceWindowSwitcher
open ~/Applications/SpaceWindowSwitcher.app
```

## Use

- `Command-Tab`: show/cycle current Desktop windows
- Release `Command`: activate selected window
- `Escape`: cancel
- `Return`: activate selected window

## Share

```sh
make package
```

Share `dist/SpaceWindowSwitcher.zip`.

## Remove Autostart

```sh
make uninstall-autolaunch
```
