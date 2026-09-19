#!/bin/sh
set -eu

XCFRAMEWORK="${SRCROOT}/Frameworks/MobileVLCKit.xcframework"
DEST="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

if [ ! -d "${XCFRAMEWORK}" ]; then
  echo "error: MobileVLCKit.xcframework is missing. The bundled MobileVLCKit.xcframework is missing from Frameworks/."
  exit 1
fi

case "${PLATFORM_NAME}" in
  iphonesimulator)
    FRAMEWORK="${XCFRAMEWORK}/ios-arm64_i386_x86_64-simulator/MobileVLCKit.framework"
    ;;
  iphoneos)
    FRAMEWORK="${XCFRAMEWORK}/ios-arm64_armv7_armv7s/MobileVLCKit.framework"
    ;;
  *)
    echo "error: Unsupported platform for MobileVLCKit: ${PLATFORM_NAME}"
    exit 1
    ;;
esac

if [ ! -d "${FRAMEWORK}" ]; then
  echo "error: Expected MobileVLCKit framework slice not found: ${FRAMEWORK}"
  exit 1
fi

/bin/mkdir -p "${DEST}"
/bin/rm -rf "${DEST}/MobileVLCKit.framework"
/bin/cp -R "${FRAMEWORK}" "${DEST}/MobileVLCKit.framework"

if [ "${PLATFORM_NAME}" = "iphoneos" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --preserve-metadata=identifier,entitlements "${DEST}/MobileVLCKit.framework"
fi

echo "GhostStream: embedded MobileVLCKit.framework"
