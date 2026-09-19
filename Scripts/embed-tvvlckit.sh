#!/bin/sh
set -eu

VLC_XC="$SRCROOT/Frameworks/TVVLCKit.xcframework"

if [ "$PLATFORM_NAME" = "appletvsimulator" ]; then
  SRC_FRAMEWORK="$VLC_XC/tvos-arm64_x86_64-simulator/TVVLCKit.framework"
else
  SRC_FRAMEWORK="$VLC_XC/tvos-arm64/TVVLCKit.framework"
fi

if [ ! -d "$SRC_FRAMEWORK" ]; then
  echo "error: TVVLCKit framework slice missing for $PLATFORM_NAME"
  exit 1
fi

DEST_DIR="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
DEST_FRAMEWORK="$DEST_DIR/TVVLCKit.framework"

mkdir -p "$DEST_DIR"
rm -rf "$DEST_FRAMEWORK"
/bin/cp -R "$SRC_FRAMEWORK" "$DEST_FRAMEWORK"

# TVVLCKit 3.6.0 is distributed as a dynamic framework. Device builds
# require the nested framework to be signed with the app identity.
if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none --preserve-metadata=identifier,entitlements "$DEST_FRAMEWORK"
fi

echo "GhostStreamTV: embedded TVVLCKit at $DEST_FRAMEWORK"
