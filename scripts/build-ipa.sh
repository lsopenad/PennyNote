#!/usr/bin/env bash
# Genera un .ipa de PennyNote listo para instalar con AltStore PAL.
# Uso: ./scripts/build-ipa.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

SCHEME="PennyNote"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/PennyNote.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS="scripts/ExportOptions.plist"

echo "==> Regenerando el proyecto Xcode con xcodegen"
xcodegen generate

echo "==> Limpiando builds anteriores"
rm -rf "$BUILD_DIR"

echo "==> Creando el archive (Release)"
xcodebuild archive \
  -project PennyNote.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic

echo "==> Exportando el .ipa"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

IPA_PATH=$(find "$EXPORT_PATH" -maxdepth 1 -name "*.ipa" | head -1)
if [ -z "$IPA_PATH" ]; then
  echo "No se ha generado ningún .ipa. Revisa el log de xcodebuild anterior." >&2
  exit 1
fi

echo ""
echo "IPA listo en: $IPA_PATH"
echo "Instálalo abriendo ese fichero con AltStore PAL en tu iPhone."
