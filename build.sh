#!/bin/zsh
# Build Eject All.app and install to /Applications
set -e
cd "$(dirname "$0")"
APP="Eject All.app"
BUILD="$(mktemp -d)"   # build outside iCloud so no Finder/fileprovider xattrs break codesign
mkdir -p "$BUILD/$APP/Contents/MacOS"
swiftc -O -o "$BUILD/$APP/Contents/MacOS/EjectAll" main.swift 2>&1 | grep -E 'error' || true
cp Info.plist "$BUILD/$APP/Contents/"
codesign -s - --force "$BUILD/$APP"
pkill -x EjectAll || true
rm -rf "/Applications/$APP"; cp -R "$BUILD/$APP" /Applications/
rm -rf "$BUILD" "$APP"
open "/Applications/$APP"
