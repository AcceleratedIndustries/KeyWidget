#!/bin/bash
# Build a distributable .dmg of KeyWidget for friends-and-family UAT.
#
# Output: dist/KeyWidget-<version>-<build>.dmg
#
# Signing: uses "Developer ID Application" if found (notarization-ready),
# otherwise falls back to ad-hoc signing. Ad-hoc DMGs run fine but show a
# Gatekeeper warning on first launch — see docs/DISTRIBUTION.md.

set -euo pipefail

cd "$(dirname "$0")/.."

ROOT="$PWD"
BUILD_DIR="$ROOT/build"
SYMROOT="$BUILD_DIR/sym"
OBJROOT="$BUILD_DIR/obj"
STAGE="$BUILD_DIR/dmg-stage"
DIST="$ROOT/dist"

PROJECT="KeyWidget.xcodeproj"
TARGET="KeyWidget"
APP_NAME="KeyWidget.app"

# Keychain profile created via `xcrun notarytool store-credentials`.
# Set NOTARIZE=0 to skip notarization (e.g. quick local rebuilds).
NOTARY_PROFILE="${NOTARY_PROFILE:-KeyWidget-notary}"
NOTARIZE="${NOTARIZE:-1}"

VERSION=$(awk '/CFBundleShortVersionString/{gsub(/[":]/,"",$2); print $2; exit}' project.yml)
BUILD_NUM=$(awk '/CFBundleVersion/{gsub(/[":]/,"",$2); print $2; exit}' project.yml)
DMG_NAME="KeyWidget-${VERSION}-build${BUILD_NUM}.dmg"
DMG_PATH="$DIST/$DMG_NAME"
VOL_NAME="KeyWidget ${VERSION}"

echo "==> KeyWidget $VERSION (build $BUILD_NUM)"

# 1. Regenerate project from project.yml so build reflects latest config.
echo "==> Regenerating Xcode project"
./bin/gen >/dev/null

# 2. Pick the signing identity we'll RE-sign with after the build.
#    We always build ad-hoc to avoid provisioning-profile requirements, then
#    re-sign with Developer ID when available. This keeps the build step
#    decoupled from the distribution signing style.
if security find-identity -p codesigning -v 2>/dev/null | grep -q "Developer ID Application"; then
  SIGN_IDENTITY=$(security find-identity -p codesigning -v | awk -F\" '/Developer ID Application/{print $2; exit}')
  echo "==> Will sign with: $SIGN_IDENTITY"
else
  echo "==> No Developer ID cert found — using ad-hoc signing"
  echo "    (recipients will need to right-click → Open on first launch)"
  SIGN_IDENTITY="-"
fi

# 3. Build Release unsigned. We sign ourselves in step 4 so we can apply
#    Developer ID or ad-hoc without Xcode demanding a provisioning profile
#    (sandbox + app-groups trigger that requirement under any signed build).
echo "==> Building Release (unsigned)"
rm -rf "$SYMROOT" "$OBJROOT"
mkdir -p "$BUILD_DIR"
xcodebuild \
  -project "$PROJECT" \
  -target "$TARGET" \
  -configuration Release \
  SYMROOT="$SYMROOT" \
  OBJROOT="$OBJROOT" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build \
  >"$BUILD_DIR/xcodebuild.log" 2>&1 || {
    echo "!! xcodebuild failed — see $BUILD_DIR/xcodebuild.log"
    tail -60 "$BUILD_DIR/xcodebuild.log"
    exit 1
  }

APP_SRC="$SYMROOT/Release/$APP_NAME"
if [[ ! -d "$APP_SRC" ]]; then
  echo "!! Build succeeded but $APP_SRC not found"
  exit 1
fi

# 4. Sign the bundle. Widget appex must be signed BEFORE the outer app.
#    Entitlements come from the source .entitlements files so sandbox,
#    app-groups, and hardened-runtime exceptions are applied correctly.
APP_ENTS="KeyWidgetApp/KeyWidget.entitlements"
WIDGET_ENTS="KeyWidgetWidget/KeyWidgetWidget.entitlements"
WIDGET_APPEX="$APP_SRC/Contents/PlugIns/KeyWidgetWidget.appex"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "==> Ad-hoc signing bundle"
  SIGN_FLAGS=(--force --sign -)
else
  echo "==> Signing with Developer ID (hardened runtime + timestamp)"
  SIGN_FLAGS=(--force --sign "$SIGN_IDENTITY" --options runtime --timestamp)
fi

if [[ -d "$WIDGET_APPEX" ]]; then
  codesign "${SIGN_FLAGS[@]}" --entitlements "$WIDGET_ENTS" "$WIDGET_APPEX"
fi
codesign "${SIGN_FLAGS[@]}" --entitlements "$APP_ENTS" "$APP_SRC"

# 5. Verify signature.
echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_SRC" 2>&1 | sed 's/^/    /'
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  echo "==> Gatekeeper assessment"
  spctl --assess --type execute --verbose=2 "$APP_SRC" 2>&1 | sed 's/^/    /' || \
    echo "    (spctl rejection is expected until the app is notarized — see docs/DISTRIBUTION.md)"
fi

# 6. Stage DMG contents.
echo "==> Staging DMG"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_SRC" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# 7. Unmount any stale volume from a previous run, then build DMG.
if [[ -d "/Volumes/$VOL_NAME" ]]; then
  echo "==> Detaching stale /Volumes/$VOL_NAME"
  hdiutil detach "/Volumes/$VOL_NAME" -quiet || true
fi

mkdir -p "$DIST"
rm -f "$DMG_PATH"

echo "==> Creating $DMG_NAME"
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH" \
  >/dev/null

# 8. Sign the DMG itself when we have a real identity (notarization requires it).
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  echo "==> Signing DMG"
  codesign --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

# 9. Notarize and staple. Apple validates the bundle, returns a ticket,
#    and we staple it so Gatekeeper accepts the DMG offline on the recipient.
if [[ "$SIGN_IDENTITY" != "-" && "$NOTARIZE" == "1" ]]; then
  echo "==> Submitting to Apple notary service (this can take a few minutes)"
  if xcrun notarytool submit "$DMG_PATH" \
       --keychain-profile "$NOTARY_PROFILE" \
       --wait \
       --output-format json \
       >"$BUILD_DIR/notarize.json" 2>&1; then
    cat "$BUILD_DIR/notarize.json" | sed 's/^/    /'
    STATUS=$(awk -F'"' '/"status"/{print $4; exit}' "$BUILD_DIR/notarize.json")
    if [[ "$STATUS" != "Accepted" ]]; then
      SUB_ID=$(awk -F'"' '/"id"/{print $4; exit}' "$BUILD_DIR/notarize.json")
      echo "!! Notarization status: $STATUS — fetching log"
      xcrun notarytool log "$SUB_ID" --keychain-profile "$NOTARY_PROFILE" 2>&1 | sed 's/^/    /'
      exit 1
    fi
    echo "==> Stapling ticket"
    xcrun stapler staple "$DMG_PATH" 2>&1 | sed 's/^/    /'
    echo "==> Verifying stapled DMG with Gatekeeper"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH" 2>&1 | sed 's/^/    /'
  else
    echo "!! notarytool submit failed — see $BUILD_DIR/notarize.json"
    cat "$BUILD_DIR/notarize.json" | sed 's/^/    /'
    exit 1
  fi
fi

SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo ""
echo "==> Done: $DMG_PATH ($SIZE)"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo ""
  echo "    This is an ad-hoc-signed DMG. Tell recipients:"
  echo "      1. Open the DMG, drag KeyWidget to Applications."
  echo "      2. First launch: right-click KeyWidget in Applications,"
  echo "         choose Open, then click Open in the dialog."
  echo "    See docs/DISTRIBUTION.md for details."
elif [[ "$NOTARIZE" != "1" ]]; then
  echo "    (Skipped notarization — set NOTARIZE=1 for a recipient-friendly build.)"
else
  echo "    Signed + notarized + stapled. Recipients can double-click and run."
fi
