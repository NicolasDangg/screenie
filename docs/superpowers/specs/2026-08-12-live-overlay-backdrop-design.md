# Live Overlay Backdrop Design

## Problem

The floating overlay uses SwiftUI `glassEffect`, which anchors glass behind the hosted view. When ScreenSage loses focus, that surface can retain the previously sampled app instead of following the windows currently behind the panel.

## Design

Replace only the overlay backdrop with `NSVisualEffectView`. Configure it with `.behindWindow` so AppKit blends with the desktop or app behind the panel, `.hudWindow` because this is a floating HUD, and `.active` so the backdrop remains live when ScreenSage is not focused.

Keep the clear nonopaque `NSPanel`, existing rounded clipping, dimensions, controls, drag behavior, and animations unchanged. Do not stack SwiftUI `glassEffect` over the AppKit material.

## Verification

Unit-test the visual effect configuration. Then keep the overlay visible while switching between visually different apps and confirm its background updates without focusing ScreenSage.
