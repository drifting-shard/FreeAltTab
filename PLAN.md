# Space Window Switcher Plan

## Study Findings

| Area | Decision | Reason |
| --- | --- | --- |
| Shortcut | `Option-Tab` | Matches the requested AltTab-style trigger without colliding with `Command-Tab`. |
| Window source | SkyLight active Space window list | `CGSGetActiveSpace` + `CGSCopyWindowsWithOptionsAndTags` asks SkyLight for the active Space's windows directly. |
| Window filtering | SkyLight window IDs, layer `0`, visible bounds, non-helper PID | Avoids stale previous-Desktop results from visible-window merge or per-window Space inference. |
| Window ordering | Preserve CoreGraphics front-to-back order | Area sorting pins full-size windows arbitrarily, which makes Codex appear fixed at the top. |
| Focus/raise | Accessibility AX frontmost + window matching | Needed to raise a specific window instead of only activating the owning app. |
| UI | Nonactivating floating `NSPanel` overlay | The switcher must not activate the app or join all Spaces, because either can show stale lists on another Desktop. |
| UI shape | Fit-content translucent icon strip | Window choices should sit on one rounded frosted backdrop sized to the visible icon tiles. |
| Permissions | Accessibility prompt from menu only | Exact-window raise needs Accessibility, but the global shortcut must never re-open the system prompt. |
| Debugging | `/tmp/SpaceWindowSwitcher-debug.log` | Records frontmost app, source path, Space ID, and collected windows when Space behavior is wrong. |
| Install | User LaunchAgent + `~/Applications` app copy | Login startup should not depend on the mutable `build/` directory. |
| Sharing | Zip the signed `.app` bundle | Teammates can unzip, move to Applications, open once, and grant Accessibility. |

## Implementation Contract

1. Create a menu-bar/accessory macOS app.
2. Register global `Option-Tab` with Carbon `RegisterEventHotKey`.
3. On first `Option-Tab`:
   - read the active Space ID from SkyLight with `CGSGetActiveSpace`
   - use a fresh SkyLight connection for each invocation
   - ask SkyLight for ordered window IDs in that active Space
   - map those IDs onto CoreGraphics window metadata
   - fall back to per-window Space membership only if the direct active-Space window API is unavailable
   - fall back to on-screen CoreGraphics only if SkyLight is unavailable
   - preserve front-to-back order; use area only to pick the best duplicate helper surface
   - show a nonactivating floating switcher panel without calling `NSApp.activate`
   - move the panel to the active Space instead of joining every Space
   - rebuild the panel on every fresh Space load so stale SwiftUI rows cannot survive Space changes
   - render windows as compact icon-only horizontal boxes on a translucent rounded backdrop
   - size the panel from item count, capped for long window lists
   - preselect the next window when possible
4. While panel is visible:
   - `Option-Tab`, `Tab`, `Right`, `Down` move forward inside the same Space
   - if `Option-Tab` fires from a different active Space, reload the window list first
   - `Left`, `Up` move backward
   - `Return` activates selected
   - `Escape` cancels
   - releasing `Option` activates selected
5. Focus selected window:
   - activate owning app by PID as a fallback
   - set the AX app `frontmost` attribute when trusted
   - find an AX window with matching title
   - perform `kAXRaiseAction`
   - if Accessibility is not trusted, fail silently after activating the owning app
6. Keep implementation dependency-free: Swift, SwiftUI, AppKit, CoreGraphics, Carbon, Accessibility.
7. Fall back to `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` if SkyLight is unavailable.
8. Keep permission prompting explicit:
   - menu item `Request Accessibility Permission` may show the macOS prompt
   - `Option-Tab` and switcher navigation must not show the macOS prompt
9. Log one compact debug line per switcher open.
10. Provide local install targets:
   - `make install` copies app to `~/Applications`
   - `make autolaunch` registers a LaunchAgent for login startup
   - `make uninstall-autolaunch` removes the LaunchAgent
   - `make package` creates a teammate-shareable zip

## Verification

| Test | Expected |
| --- | --- |
| `make build` | Produces `build/SpaceWindowSwitcher.app`. |
| `make autolaunch` | App is copied to `~/Applications` and LaunchAgent is loaded. |
| `make package` | Produces `dist/SpaceWindowSwitcher.zip`. |
| Launch app | Menu bar icon appears. |
| Press `Option-Tab` | Overlay lists windows from current Desktop/Space only. |
| Press `Option-Tab` repeatedly | Selection advances. |
| Release `Option` | Selected window is focused/raised. |
| Switch Desktop and press `Option-Tab` | List reflects that Desktop, not all Spaces. |
| Press `Option-Tab` without Accessibility trust | No repeated permission prompt appears. |

## Known Limits

macOS does not expose a clean public “all windows by Space” API. This POC uses private SkyLight symbols through `dlopen`/`dlsym` for the active Space/window mapping, with public CoreGraphics as fallback. Exact window focus depends on Accessibility permission and matching AX windows by title.
