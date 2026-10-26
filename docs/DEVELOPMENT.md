# Desarrollo

## Requisitos

- Xcode 26+ con el runtime de iOS Simulator 18.0+ instalado (`xcodebuild -downloadPlatform iOS` si no lo tienes).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.
- Para publicar versiones: [GitHub CLI](https://cli.github.com) (`gh`) autenticado y `jq`.
- Para ejecutar en un dispositivo desde Xcode: un Apple ID añadido en Xcode → Settings → Accounts. Generar el `.ipa` no lo necesita (ver más abajo).

El proyecto `.xcodeproj` **no se versiona**: se genera a partir de `project.yml`. Cualquier cambio de targets, capacidades o ajustes de build se hace editando `project.yml`, nunca a mano en Xcode.

## Abrir el proyecto

```bash
xcodegen generate
open PennyNote.xcodeproj
```

Selecciona el esquema `PennyNote` y un simulador de iPhone, y ejecuta con Cmd+R. Para ejecutar en un dispositivo, elige tu equipo de firma en los targets `PennyNote` y `PennyNoteWidgetExtension`.

Vuelve a ejecutar `xcodegen generate` cada vez que `project.yml` cambie (por ejemplo, tras un `git pull`).

## Tests

Los tests (Swift Testing, target `PennyNoteTests`) cubren la lógica pura: cálculo del total mensual, estadísticas de gasto y datos del widget. Se ejecutan con Cmd+U en Xcode o desde terminal:

```bash
xcodebuild test -project PennyNote.xcodeproj -scheme PennyNote -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Generar un .ipa

```bash
./scripts/build-ipa.sh
```

Automatiza `xcodegen generate` + `xcodebuild archive` sin firma de Apple y empaqueta el `.ipa` en `build/export/PennyNote.ipa`.

No firma con un Apple ID ni necesita perfiles de aprovisionamiento: la firma la pone AltServer al instalar. Así no se gastan App IDs desde Xcode, que con un Apple ID gratuito están limitados a 10 cada 7 días. El script solo hace una firma ad hoc para incrustar los entitlements (el App Group `group.com.pennynote.app`), que AltServer necesita para dar de alta el grupo al refirmar.

### Instalar el .ipa a mano

Con el iPhone conectado (USB o misma Wi-Fi que el Mac), arrastra `PennyNote.ipa` sobre el icono de **AltServer** en la barra de menús → **Install App** → elige el iPhone. AltServer lo firma con el Apple ID configurado y lo instala.

## Publicar una versión

`altstore-source.json` es la source de AltStore: la lista de versiones que AltStore consulta para instalar PennyNote y avisar de actualizaciones. Para publicar una versión nueva:

```bash
./scripts/release.sh 1.2.0 "Qué cambia en esta versión"
```

El script:

1. Sube `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` en `project.yml`.
2. Genera el `.ipa` y comprueba que lleva esa versión.
3. Añade la versión a `altstore-source.json`.
4. Hace commit y tag `v1.2.0`, sube el tag, crea la Release de GitHub con el `.ipa` y, al final, sube `main`, para que la source nunca apunte a un `.ipa` que aún no existe.

Hay que lanzarlo desde `main` sin cambios pendientes. Con `--dry-run` hace los tres primeros pasos sin commit, push ni Release, para revisar el resultado antes. Si falla antes del commit, restaura `project.yml` y la source.

La versión debe seguir el formato `X.Y.Z` y ser mayor que la anterior: AltStore solo ofrece la actualización si la versión sube.
