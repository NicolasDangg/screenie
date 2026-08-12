# Permission Status Settings Design

## Goal

Show macOS privacy permission status inside ScreenSage Settings and open the matching System Settings pane in one click.

## Permissions

- Screen Recording: required for the submitted screenshot.
- Accessibility: optional; shown for transparency but not used by the current app.
- Input Monitoring: optional; shown for transparency because the global shortcut uses Carbon and does not require it.

## Interface

Add a Permissions section to the existing form. Each row shows the permission name, Required or Optional, an icon plus Enabled or Disabled status, and an Open Settings button. Using both text and icons keeps the state understandable without relying on color.

## Behavior

Read status with `CGPreflightScreenCaptureAccess()`, `AXIsProcessTrusted()`, and `CGPreflightListenEventAccess()`. Open the corresponding Privacy & Security pane through `NSWorkspace`. Refresh when Settings appears and whenever the app becomes active again after visiting System Settings.

ScreenSage cannot toggle these protected permissions itself. The buttons only navigate to the correct pane.

## Testing

Unit-test the permission metadata and Settings URLs. Verify all existing tests, then inspect the Settings window manually.
