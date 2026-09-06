#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
cd "$root"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

xcodebuild \
  -project "WeatherCF.xcodeproj" \
  -scheme WeatherCF \
  -configuration Release \
  -derivedDataPath "$root/build" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM="" \
  build

built="$(find "$root/build/Build/Products/Release" -maxdepth 2 -name "Weather C+F.app" -print -quit)"
if [[ -z "$built" ]]; then
  echo "Build succeeded but the app bundle was not found." >&2
  exit 1
fi

strip_attrs() {
  xattr -cr "$1" >/dev/null 2>&1 || true
  find "$1" -name '._*' -delete >/dev/null 2>&1 || true
}

fix_and_sign() {
  local app="$1"
  plutil -replace CFBundleExecutable -string "Weather C+F" "$app/Contents/Info.plist" >/dev/null
  strip_attrs "$app"
  local appex="$app/Contents/PlugIns/WeatherCFWidget.appex"
  if [[ -d "$appex" ]]; then
    codesign --force --sign - --entitlements "$root/Sources/Widget/Widget.entitlements" --timestamp=none "$appex"
  fi
  codesign --force --sign - --entitlements "$root/WeatherCF.entitlements" --timestamp=none "$app"
}

register_widget() {
  local appex="$1/Contents/PlugIns/WeatherCFWidget.appex"
  if [[ -d "$appex" ]]; then
    pluginkit -a "$appex" >/dev/null 2>&1 || true
    pluginkit -e use -i com.weathercf.app.widget >/dev/null 2>&1 || true
  fi
}

app="$root/Weather C+F.app"
rm -rf "$app"
cp -R "$built" "$app"
fix_and_sign "$app"

for dest in "$HOME/Applications" "/Applications"; do
  mkdir -p "$dest"
  rm -rf "$dest/Weather C+F.app"
  if cp -R "$app" "$dest/Weather C+F.app" 2>/dev/null; then
    fix_and_sign "$dest/Weather C+F.app"
    register_widget "$dest/Weather C+F.app"
    echo "Installed to $dest/Weather C+F.app"
  fi
done

echo "Created $app"
