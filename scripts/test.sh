#!/usr/bin/env bash
# Pasa los tests de PennyNote (target PennyNoteTests) en el simulador. Lo usa scripts/release.sh
# antes de publicar una versión: si algo falla, no se publica.
# Uso: ./scripts/test.sh
#   PENNYNOTE_TEST_DESTINATION cambia el simulador (por defecto, iPhone 17 con el iOS más reciente).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

DESTINATION="${PENNYNOTE_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

echo "==> Regenerando el proyecto Xcode con xcodegen"
xcodegen generate

# -onlyUsePackageVersionsFromResolvedFile: los tests se compilan con las mismas versiones que el .ipa.
echo "==> Pasando los tests ($DESTINATION)"
xcodebuild test \
  -project PennyNote.xcodeproj \
  -scheme PennyNote \
  -onlyUsePackageVersionsFromResolvedFile \
  -destination "$DESTINATION"
