#!/usr/bin/env bash
# Publica una versión nueva de PennyNote para la source de AltStore:
#   1. Sube MARKETING_VERSION y CURRENT_PROJECT_VERSION en project.yml.
#   2. Genera el .ipa con scripts/build-ipa.sh.
#   3. Añade la versión a altstore-source.json.
#   4. Hace commit y tag vX.Y.Z, sube el tag, crea la Release de GitHub con el .ipa y
#      solo entonces sube main, para que la source nunca apunte a un .ipa que aún no existe.
#
# Uso: ./scripts/release.sh <versión> ["notas de la versión"] [--dry-run]
#   --dry-run  hace los pasos 1-3 sin commit, push ni Release, para revisar el resultado.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

REPO="lsopenad/PennyNote"
SOURCE_JSON="altstore-source.json"
IPA_PATH="build/export/PennyNote.ipa"
MIN_OS_VERSION="18.0"

DRY_RUN=false
POSITIONAL=()
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then DRY_RUN=true; else POSITIONAL+=("$arg"); fi
done

VERSION="${POSITIONAL[0]:-}"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Uso: ./scripts/release.sh <versión X.Y.Z> [\"notas\"] [--dry-run]" >&2
  exit 1
fi
NOTES="${POSITIONAL[1]:-Versión $VERSION}"
TAG="v$VERSION"

for tool in xcodegen gh jq; do
  command -v "$tool" >/dev/null || { echo "Falta la herramienta '$tool'." >&2; exit 1; }
done

# AltStore solo ofrece la actualización si la versión sube respecto a la última publicada.
LAST_VERSION=$(jq -r '.apps[0].versions[0].version // empty' "$SOURCE_JSON")
if [ -n "$LAST_VERSION" ]; then
  HIGHEST=$(printf '%s\n%s\n' "$LAST_VERSION" "$VERSION" | sort -V | tail -1)
  if [ "$VERSION" = "$LAST_VERSION" ] || [ "$HIGHEST" != "$VERSION" ]; then
    echo "La versión $VERSION debe ser mayor que la última publicada ($LAST_VERSION)." >&2
    exit 1
  fi
fi

if [ "$DRY_RUN" = false ]; then
  [ "$(git branch --show-current)" = "main" ] || { echo "Las releases se publican desde main." >&2; exit 1; }
  [ -z "$(git status --porcelain)" ] || { echo "Hay cambios sin commitear; haz commit o descártalos antes." >&2; exit 1; }
  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "La versión $TAG ya existe." >&2
    exit 1
  fi
fi

# Si algo falla antes del commit se restauran project.yml y la source, para poder relanzar
# el script sin tener que deshacer cambios a mano. En dry-run se conservan a propósito.
BACKUP_DIR=$(mktemp -d)
cp project.yml "$SOURCE_JSON" "$BACKUP_DIR/"
COMMITTED=false
restore_on_failure() {
  local status=$?
  if [ "$status" -ne 0 ] && [ "$COMMITTED" = false ]; then
    cp "$BACKUP_DIR/project.yml" "$BACKUP_DIR/$SOURCE_JSON" .
    echo "Fallo antes del commit: se han restaurado project.yml y $SOURCE_JSON." >&2
  fi
  rm -rf "$BACKUP_DIR"
}
trap restore_on_failure EXIT

echo "==> Actualizando la versión en project.yml"
CURRENT_BUILD=$(sed -n 's/^ *CURRENT_PROJECT_VERSION: "\([0-9]*\)"$/\1/p' project.yml | head -1)
if ! [[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]]; then
  echo "No se encuentra CURRENT_PROJECT_VERSION en project.yml con el formato \"N\"." >&2
  exit 1
fi
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i '' \
  -e "s/^\( *MARKETING_VERSION: \)\".*\"$/\1\"$VERSION\"/" \
  -e "s/^\( *CURRENT_PROJECT_VERSION: \)\".*\"$/\1\"$NEW_BUILD\"/" \
  project.yml

./scripts/build-ipa.sh

# AltStore rechaza la instalación si la versión del .ipa no coincide con la de la source.
IPA_VERSION=$(unzip -p "$IPA_PATH" "Payload/PennyNote.app/Info.plist" | plutil -extract CFBundleShortVersionString raw -)
if [ "$IPA_VERSION" != "$VERSION" ]; then
  echo "El .ipa tiene la versión $IPA_VERSION en vez de $VERSION." >&2
  exit 1
fi

echo "==> Añadiendo $TAG a $SOURCE_JSON"
DOWNLOAD_URL="https://github.com/$REPO/releases/download/$TAG/PennyNote.ipa"
SIZE=$(stat -f%z "$IPA_PATH")
DATE=$(date +%Y-%m-%d)
# La versión nueva va la primera: AltStore toma la primera de "versions" como la actual.
# Los campos sueltos de la app (version, downloadURL…) son para clientes que no leen "versions".
jq --arg version "$VERSION" --arg build "$NEW_BUILD" --arg date "$DATE" --arg notes "$NOTES" \
   --arg url "$DOWNLOAD_URL" --argjson size "$SIZE" --arg minOS "$MIN_OS_VERSION" '
  .apps[0].versions = [{
    version: $version, buildVersion: $build, date: $date, localizedDescription: $notes,
    downloadURL: $url, size: $size, minOSVersion: $minOS
  }] + .apps[0].versions
  | .apps[0] += {version: $version, versionDate: $date, versionDescription: $notes, downloadURL: $url, size: $size}
' "$SOURCE_JSON" > "$SOURCE_JSON.tmp"
mv "$SOURCE_JSON.tmp" "$SOURCE_JSON"

if [ "$DRY_RUN" = true ]; then
  echo ""
  echo "Dry run: project.yml y $SOURCE_JSON modificados, .ipa en $IPA_PATH. No se ha hecho commit, push ni Release."
  exit 0
fi

echo "==> Commit y tag"
git add project.yml "$SOURCE_JSON"
git commit -m "chore(release): versión $VERSION"
COMMITTED=true
git tag "$TAG"

# Primero el tag y la Release; main (y con ello la source que lee AltStore) se sube al final.
echo "==> Creando la Release $TAG en GitHub"
git push origin "$TAG"
gh release create "$TAG" "$IPA_PATH" --repo "$REPO" --verify-tag --title "PennyNote $VERSION" --notes "$NOTES"

echo "==> Publicando la source"
git push origin main

echo ""
echo "Publicada $TAG. AltStore la verá en la source:"
echo "https://raw.githubusercontent.com/$REPO/main/$SOURCE_JSON"
