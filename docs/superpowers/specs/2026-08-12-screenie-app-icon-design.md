# screenie App Icon Design

## Goal

Give screenie a playful, cartoony macOS app icon that remains recognizable in Finder, the Dock, Settings, and small system surfaces.

## Approved direction: Screen Pal

The icon is a friendly screen/window mascot centered on a cyan-to-indigo-purple rounded-square background.

- White screen-shaped face with a thick, dark navy outline.
- Two oversized navy eyes and a simple smiling mouth.
- Slight counterclockwise tilt for energy without reducing legibility.
- One small white four-point sparkle near the upper-right corner.
- Soft dimensional shading, chunky shapes, and polished cartoon rendering.
- No text, letters, photographic elements, extra characters, or detailed scenery.

The character should feel curious and helpful, not like surveillance software. Facial details must remain distinct at 16–32 px.

## Asset and integration

- Generate one square 1024×1024 master image.
- Keep important artwork inside generous safe margins so macOS masking cannot clip the face or sparkle.
- Produce the standard macOS AppIcon raster sizes from the approved master.
- Add the icon through an Xcode asset catalog named `AppIcon` and set the app target to use it.
- Preserve the existing product name, bundle identifier, signing identity, and permission behavior.

## Verification

- Build and install `/Applications/screenie.app` with `scripts/install.sh`.
- Confirm the built app contains the compiled AppIcon asset.
- Visually inspect the installed icon at large size and in at least one small system presentation.
- Run the existing test suite and `git diff --check`; the icon must not change runtime behavior.
