#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
master="$project_root/assets/branding/hamster_care_app_icon_master.png"
ios_dir="$project_root/ios/Runner/Assets.xcassets/AppIcon.appiconset"
android_res="$project_root/android/app/src/main/res"
web_dir="$project_root/web"
store_dir="$project_root/store_assets/icons"

if [[ ! -f "$master" ]]; then
  echo "App icon master not found: $master" >&2
  exit 1
fi

mkdir -p "$store_dir"

resize_icon() {
  local size="$1"
  local output="$2"

  /usr/bin/sips \
    --setProperty format png \
    --resampleHeightWidth "$size" "$size" \
    "$master" \
    --out "$output" \
    >/dev/null
}

resize_icon 1024 "$ios_dir/Icon-App-1024x1024@1x.png"
resize_icon 20 "$ios_dir/Icon-App-20x20@1x.png"
resize_icon 40 "$ios_dir/Icon-App-20x20@2x.png"
resize_icon 60 "$ios_dir/Icon-App-20x20@3x.png"
resize_icon 29 "$ios_dir/Icon-App-29x29@1x.png"
resize_icon 58 "$ios_dir/Icon-App-29x29@2x.png"
resize_icon 87 "$ios_dir/Icon-App-29x29@3x.png"
resize_icon 40 "$ios_dir/Icon-App-40x40@1x.png"
resize_icon 80 "$ios_dir/Icon-App-40x40@2x.png"
resize_icon 120 "$ios_dir/Icon-App-40x40@3x.png"
resize_icon 120 "$ios_dir/Icon-App-60x60@2x.png"
resize_icon 180 "$ios_dir/Icon-App-60x60@3x.png"
resize_icon 76 "$ios_dir/Icon-App-76x76@1x.png"
resize_icon 152 "$ios_dir/Icon-App-76x76@2x.png"
resize_icon 167 "$ios_dir/Icon-App-83.5x83.5@2x.png"

resize_icon 48 "$android_res/mipmap-mdpi/ic_launcher.png"
resize_icon 72 "$android_res/mipmap-hdpi/ic_launcher.png"
resize_icon 96 "$android_res/mipmap-xhdpi/ic_launcher.png"
resize_icon 144 "$android_res/mipmap-xxhdpi/ic_launcher.png"
resize_icon 192 "$android_res/mipmap-xxxhdpi/ic_launcher.png"

resize_icon 32 "$web_dir/favicon.png"
resize_icon 192 "$web_dir/icons/Icon-192.png"
resize_icon 512 "$web_dir/icons/Icon-512.png"
resize_icon 192 "$web_dir/icons/Icon-maskable-192.png"
resize_icon 512 "$web_dir/icons/Icon-maskable-512.png"

resize_icon 1024 "$store_dir/app_store_icon_1024.png"
resize_icon 512 "$store_dir/google_play_icon_512.png"

echo "Generated iOS, Android, Web, and store app icons from: $master"
