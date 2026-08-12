# screenie App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate the approved Screen Pal artwork and install it as screenie's native macOS app icon.

**Architecture:** Keep one generated 1024×1024 alpha PNG as the largest AppIcon raster, derive the remaining standard macOS sizes with `sips`, and let Xcode's asset compiler package the catalog. Configure only the existing target's AppIcon build setting; runtime code remains unchanged.

**Tech Stack:** Built-in image generation, PNG alpha, Xcode asset catalogs, `sips`, Swift/XCTest, macOS 26.

---

### Task 1: Add an icon bundle regression check

**Files:**
- Modify: `ScreenSageTests/ScreenSageTests.swift`

- [ ] **Step 1: Add the failing bundle metadata test**

```swift
func testAppUsesScreenieAppIcon() {
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleIconName") as? String, "AppIcon")
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:ScreenSageTests/ScreenSageTests/testAppUsesScreenieAppIcon
```

Expected: FAIL because the target does not yet compile an `AppIcon` catalog.

### Task 2: Generate and integrate the Screen Pal assets

**Files:**
- Create: `ScreenSage/Assets.xcassets/Contents.json`
- Create: `ScreenSage/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `ScreenSage/Assets.xcassets/AppIcon.appiconset/icon_16x16.png`
- Create: `ScreenSage/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png`
- Create: `ScreenSage/Assets.xcassets/AppIcon.appiconset/icon_32x32.png`
- Create: `ScreenSage/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png`
- Create: `ScreenSage/Assets.xcassets/AppIcon.appiconset/icon_128x128.png`
- Create: `ScreenSage/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png`
- Create: `ScreenSage/Assets.xcassets/AppIcon.appiconset/icon_256x256.png`
- Create: `ScreenSage/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png`
- Create: `ScreenSage/Assets.xcassets/AppIcon.appiconset/icon_512x512.png`
- Create: `ScreenSage/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png`
- Modify: `ScreenSage.xcodeproj/project.pbxproj`

- [ ] **Step 1: Generate the approved 1024 px master**

Use the built-in image generator with this prompt:

```text
Use case: logo-brand
Asset type: macOS app icon, 1024 by 1024 pixels
Primary request: Create a playful, polished cartoon icon for the macOS app screenie.
Scene/backdrop: Outside the icon tile, use a perfectly flat solid #00ff00 chroma-key background with no variation.
Subject: One cyan-to-indigo-purple rounded-square tile containing a centered friendly white computer-screen/window mascot. Give the mascot a thick dark navy outline, two oversized navy oval eyes, a simple smiling mouth, a slight counterclockwise tilt, and one small white four-point sparkle near the upper-right corner.
Style/medium: Chunky premium cartoon illustration, soft dimensional shading, smooth clean edges, friendly and curious rather than surveillance-themed.
Composition/framing: Centered, symmetrical overall, generous 14 percent safe margin, readable at 16–32 px, no clipped outline or sparkle.
Constraints: No text, letters, Apple logo, camera, extra characters, scenery, tiny details, watermark, or green anywhere in the icon subject. No cast shadow outside the rounded-square tile.
```

- [ ] **Step 2: Remove only the chroma-key corners and validate alpha**

```bash
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input tmp/imagegen/screenie-icon-chroma.png \
  --out ScreenSage/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill
sips -g pixelWidth -g pixelHeight -g hasAlpha ScreenSage/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png
```

Expected: 1024×1024 with an alpha channel and transparent outer corners.

- [ ] **Step 3: Derive the remaining standard macOS rasters**

```bash
sips -z 16 16 icon_512x512@2x.png --out icon_16x16.png
sips -z 32 32 icon_512x512@2x.png --out icon_16x16@2x.png
cp icon_16x16@2x.png icon_32x32.png
sips -z 64 64 icon_512x512@2x.png --out icon_32x32@2x.png
sips -z 128 128 icon_512x512@2x.png --out icon_128x128.png
sips -z 256 256 icon_512x512@2x.png --out icon_128x128@2x.png
cp icon_128x128@2x.png icon_256x256.png
sips -z 512 512 icon_512x512@2x.png --out icon_256x256@2x.png
cp icon_256x256@2x.png icon_512x512.png
```

Run these commands from `ScreenSage/Assets.xcassets/AppIcon.appiconset`.

- [ ] **Step 4: Add standard asset-catalog metadata**

`ScreenSage/Assets.xcassets/Contents.json`:

```json
{
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`ScreenSage/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 5: Configure both target build configurations**

Add this build setting to the ScreenSage target's Debug and Release configurations in `ScreenSage.xcodeproj/project.pbxproj`:

```text
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
```

- [ ] **Step 6: Run the focused test and verify it passes**

Run the Task 1 command again.

Expected: PASS and no asset-catalog warnings.

### Task 3: Verify and install

**Files:**
- Verify: `/Applications/screenie.app`

- [ ] **Step 1: Run full automated verification**

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

Expected: all tests pass and `git diff --check` prints nothing.

- [ ] **Step 2: Build and install the signed Release app**

```bash
./scripts/install.sh
```

Expected: `BUILD SUCCEEDED`, one running `screenie` process, and `/Applications/screenie.app` replaced.

- [ ] **Step 3: Inspect the installed icon**

Use Finder or Quick Look to inspect `/Applications/screenie.app` at large size, then inspect screenie's menu-bar/system presentation. Confirm the mascot, outline, smile, gradient, sparkle, transparency, and small-size legibility.

- [ ] **Step 4: Commit the implementation**

```bash
git add ScreenSage/Assets.xcassets ScreenSage.xcodeproj/project.pbxproj ScreenSageTests/ScreenSageTests.swift
git commit -m "feat: add screenie app icon"
```
