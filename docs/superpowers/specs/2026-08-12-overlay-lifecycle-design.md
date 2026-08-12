# screenie Overlay Lifecycle Design

## Goal

Make screenie launch quietly at login, toggle with Option–Space, remain absent from the Dock, and restore the overlay's last hidden position.

## Launch behavior

- Register the signed main application as a login item with Apple's native `SMAppService.mainApp` API.
- Registration is attempted only when the service is not already registered. Failure is nonfatal because screenie remains usable through a normal launch.
- App launch creates the menu-bar item and global shortcut but does not present the overlay.
- Keep `LSUIElement = YES`; screenie remains a menu-bar-only agent without a Dock or Command–Tab icon.

## Global shortcut

- Register Space with Carbon's `optionKey` modifier only.
- Remove the Command modifier from the existing Command–Option–Space shortcut.
- Preserve the current toggle semantics, fade animation, and new-conversation behavior.

## Overlay position

- Save only the panel's x/y origin to `UserDefaults` when the overlay hides. Do not persist width, collapsed height, or expanded height.
- On the first presentation in a process, restore that origin if the resulting panel frame intersects a currently visible display.
- If no saved origin exists, or the saved position belongs to a disconnected display, use the existing centered-above-bottom position on the display under the pointer.
- Later toggles in the same process retain the panel's in-memory frame as they do today.

## Verification

- Add focused checks for the Option-only shortcut configuration, menu-bar-only bundle setting, quiet startup behavior, and saved-position decoding.
- Run the full test suite and build/install `/Applications/screenie.app`.
- Verify one running process, valid signing, login-item registration status, no Dock presentation, initial hidden state, and position restoration after hide/show.
