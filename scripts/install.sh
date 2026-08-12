#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
derived_data="$repo_dir/DerivedData"
product="$derived_data/Build/Products/Release/ScreenSage.app"
installed_app="/Applications/ScreenSage.app"

xcodebuild \
    -project "$repo_dir/ScreenSage.xcodeproj" \
    -scheme ScreenSage \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$derived_data" \
    build

codesign --force --sign "Apple Development: nicolasdang57@gmail.com (CR2SL8U7ZY)" "$product"
pkill -x ScreenSage 2>/dev/null || true
rm -rf "$installed_app"
ditto "$product" "$installed_app"
open "$installed_app"
