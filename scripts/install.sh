#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
derived_data="$repo_dir/DerivedData"
product="$derived_data/Build/Products/Release/screenie.app"
installed_app="/Applications/screenie.app"

xcodebuild \
    -project "$repo_dir/ScreenSage.xcodeproj" \
    -scheme ScreenSage \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$derived_data" \
    build

pkill -x screenie 2>/dev/null || true
pkill -x ScreenSage 2>/dev/null || true
rm -rf "$installed_app"
rm -rf /Applications/ScreenSage.app
ditto "$product" "$installed_app"
open "$installed_app"
