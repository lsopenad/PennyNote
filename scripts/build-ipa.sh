#!/usr/bin/env bash
# Genera un .ipa de PennyNote sin firma de Apple, para instalarlo con AltStore/AltServer,
# que lo vuelve a firmar con tu Apple ID. No necesita perfiles de aprovisionamiento ni
# registrar App IDs desde Xcode (el Apple ID gratuito solo permite 10 cada 7 días).
# Uso: ./scripts/build-ipa.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

SCHEME="PennyNote"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/PennyNote.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_ENTITLEMENTS="Generated/PennyNote.entitlements"
WIDGET_ENTITLEMENTS="Generated/PennyNoteWidgetExtension.entitlements"

echo "==> Regenerando el proyecto Xcode con xcodegen"
xcodegen generate

echo "==> Limpiando builds anteriores"
rm -rf "$BUILD_DIR"

echo "==> Creando el archive (Release, sin firma)"
xcodebuild archive \
  -project PennyNote.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO

APP_PATH="$ARCHIVE_PATH/Products/Applications/PennyNote.app"
WIDGET_PATH="$APP_PATH/PlugIns/PennyNoteWidgetExtension.appex"
if [ ! -d "$APP_PATH" ] || [ ! -d "$WIDGET_PATH" ]; then
  echo "El archive no contiene la app o la extensión del widget. Revisa el log de xcodebuild anterior." >&2
  exit 1
fi

# Firma ad hoc solo para incrustar los entitlements: AltServer los lee para dar de alta el
# App Group en tu cuenta al refirmar. Sin ellos la app no podría abrir el almacén compartido.
# Primero la extensión y luego la app, porque la firma de la app cubre su contenido.
echo "==> Incrustando entitlements (firma ad hoc)"
codesign --force --sign - --timestamp=none --entitlements "$WIDGET_ENTITLEMENTS" "$WIDGET_PATH"
codesign --force --sign - --timestamp=none --entitlements "$APP_ENTITLEMENTS" "$APP_PATH"

echo "==> Empaquetando el .ipa"
mkdir -p "$EXPORT_PATH/Payload"
cp -R "$APP_PATH" "$EXPORT_PATH/Payload/"
IPA_PATH="$EXPORT_PATH/PennyNote.ipa"
(cd "$EXPORT_PATH" && zip -qry PennyNote.ipa Payload)
rm -rf "$EXPORT_PATH/Payload"

echo ""
echo "IPA listo en: $IPA_PATH"
echo "Instálalo arrastrándolo sobre el icono de AltServer en la barra de menús → Install App."
