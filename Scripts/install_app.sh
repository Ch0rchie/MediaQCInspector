#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Media QC Inspector
# Install Latest Release Build
###############################################################################

APP_NAME="Media QC Inspector.app"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

echo "Searching for latest Release build..."

APP=$(find "$DERIVED_DATA" \
    -type d \
    -path "*/Build/Products/Release/*.app" \
    -name "*.app" \
    -print0 |
    xargs -0 ls -td |
    head -n 1)

if [[ -z "${APP:-}" ]]; then
    echo
    echo "❌ No Release build found."
    echo
    echo "Build the application in Release configuration first."
    exit 1
fi

echo
echo "Found:"
echo "  $APP"

DEST="/Applications/$APP_NAME"

echo
echo "Removing previous installation..."

rm -rf "$DEST"

echo
echo "Installing..."

cp -R "$APP" "$DEST"

echo
echo "Launching..."

open "$DEST"

echo
echo "✅ Installation complete."
