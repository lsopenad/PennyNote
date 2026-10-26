# PennyNote

Clon personal de [SyncSpend](https://apps.apple.com/sg/app/syncspend/id6759112033): registro rápido de gastos, sin login, con Notion como backend y widgets de pantalla de inicio/bloqueo. Detalles de arquitectura completos en `/Users/lsopenad/.claude/plans/reflective-floating-jellyfish.md`.

## Requisitos

- Xcode 26+ con el runtime de iOS Simulator 18.0+ instalado (`xcodebuild -downloadPlatform iOS` si no lo tienes).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) instalado: `brew install xcodegen`.
- Tu Apple ID añadido en Xcode → Settings → Accounts (necesario para que la firma automática funcione, tanto para correr en Simulator/dispositivo como para exportar el `.ipa`).

El proyecto `.xcodeproj` **no se versiona**: se genera a partir de `project.yml`. Cualquier cambio de targets, capacidades o ajustes de build se hace editando `project.yml`, nunca a mano en Xcode.

## Abrir el proyecto

```bash
xcodegen generate
open PennyNote.xcodeproj
```

Selecciona el esquema `PennyNote` y un simulador de iPhone, y ejecuta con Cmd+R. La primera vez que compiles el widget te pedirá elegir un equipo de firma para el target `PennyNoteWidgetExtension`; usa tu Apple ID personal igual que en el target principal.

Vuelve a correr `xcodegen generate` cada vez que hagas `git pull` y `project.yml` haya cambiado.

## Tests

Los tests (Swift Testing, target `PennyNoteTests`) cubren la lógica pura: mapeo con Notion, cálculo del total mensual y parseo del ID de página. Se ejecutan con Cmd+U en Xcode o desde terminal:

```bash
xcodebuild test -project PennyNote.xcodeproj -scheme PennyNote -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Configurar Notion (dentro de la app)

1. Crea una integración en [notion.so/my-integrations](https://www.notion.so/my-integrations) y copia el token.
2. Pégalo en Ajustes → Notion.
3. Comparte con esa integración la página de Notion donde quieras que viva la base de datos de gastos, y pega su URL en "URL o ID de la página padre".
4. Pulsa "Conectar con Notion" (crea la base de datos una vez) y luego "Sincronizar ahora".

## Generar un .ipa para cada release

`scripts/build-ipa.sh` automatiza `xcodegen generate` + `xcodebuild archive` sin firma de Apple y empaqueta el `.ipa`:

```bash
./scripts/build-ipa.sh
```

El `.ipa` queda en `build/export/PennyNote.ipa`. Repite este comando cada vez que quieras sacar una nueva versión para instalar.

No firma con tu Apple ID ni necesita perfiles de aprovisionamiento: la firma la pone AltServer al instalar (ver abajo). Así no se gastan App IDs desde Xcode, que con un Apple ID gratuito están limitados a 10 cada 7 días. El script solo hace una firma ad hoc para incrustar los entitlements (el App Group `group.com.pennynote.app`), que AltServer necesita para dar de alta el grupo al refirmar.

## Publicar una versión (source de AltStore)

`altstore-source.json` es una source de AltStore: la lista de versiones de PennyNote que AltStore consulta para instalarla y avisar de actualizaciones. Para publicar una versión nueva:

```bash
./scripts/release.sh 1.2.0 "Qué cambia en esta versión"
```

El script sube `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` en `project.yml`, genera el `.ipa`, añade la versión a `altstore-source.json`, hace commit, tag `v1.2.0` y push, y crea la Release de GitHub con el `.ipa`. Hay que lanzarlo desde `main` sin cambios pendientes y con `gh` autenticado. Con `--dry-run` hace todo menos el commit, el push y la Release, para revisar el resultado antes.

La versión debe seguir el formato `X.Y.Z` y ser mayor que la anterior: AltStore solo ofrece la actualización si la versión sube.

## Instalar con AltStore Classic

[AltStore Classic](https://altstore.io) usa tu Apple ID gratuito para firmar; la firma caduca a los 7 días y hay que refrescarla (AltServer lo hace solo si el Mac y el iPhone comparten Wi-Fi de vez en cuando).

**Una sola vez:**
1. Instala **AltServer** en el Mac (altstore.io → AltStore Classic → descarga de escritorio). Es una app de menú (icono en la barra de menús).
2. Conecta el iPhone por cable y confía en el ordenador si te lo pide.
3. Desde el icono de AltServer en la barra de menús → **Install AltStore** → elige tu iPhone → introduce tu Apple ID (si tienes verificación en dos pasos, puede pedirte una [contraseña de aplicación](https://appleid.apple.com) en vez de la normal).
4. En el iPhone: Ajustes → General → VPN y gestión de dispositivos → confía en el certificado de tu Apple ID. Ya tienes la app **AltStore** en la pantalla de inicio.

**Instalar desde la source (recomendado):** en la app AltStore del iPhone → Sources → `+` → pega
`https://raw.githubusercontent.com/lsopenad/PennyNote/main/altstore-source.json`. PennyNote aparece en Browse para instalarla, y en My Apps cuando haya una versión nueva. AltStore Classic sigue necesitando AltServer abierto en el Mac y en la misma Wi-Fi para instalar y refrescar la firma.

**Cada vez que quieras instalar/actualizar PennyNote a mano, sin la source:**
1. Genera el `.ipa`: `./scripts/build-ipa.sh` (queda en `build/export/PennyNote.ipa`).
2. Con el iPhone conectado (USB o misma Wi-Fi que el Mac), arrastra `PennyNote.ipa` sobre el icono de **AltServer** en la barra de menús → **Install App** → elige tu iPhone. AltServer lo firma con tu Apple ID y lo instala sin pasar por AirDrop ni Ficheros.
3. Tras instalar, añade el widget desde "Editar pantalla de inicio" y desde la personalización de la pantalla de bloqueo (paso manual en el propio iPhone, no viene con el `.ipa`).

**Mantenimiento:** dejar el Mac con AltServer abierto y el iPhone en la misma Wi-Fi de vez en cuando hace que se refresque solo antes de los 7 días; si caduca, basta con repetir el paso 2 de "cada vez que quieras instalar".
