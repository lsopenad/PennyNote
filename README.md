# PennyNote

Clon personal de [SyncSpend](https://apps.apple.com/sg/app/syncspend/id6759112033): registro rápido de gastos, sin login, con Notion como backend y widgets de pantalla de inicio/bloqueo. Detalles de arquitectura completos en `/Users/lsopenad/.claude/plans/reflective-floating-jellyfish.md`.

## Requisitos

- Xcode 26+ con el runtime de iOS Simulator 17.4+ instalado (`xcodebuild -downloadPlatform iOS` si no lo tienes).
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

## Configurar Notion (dentro de la app)

1. Crea una integración en [notion.so/my-integrations](https://www.notion.so/my-integrations) y copia el token.
2. Pégalo en Ajustes → Notion.
3. Comparte con esa integración la página de Notion donde quieras que viva la base de datos de gastos, y pega su URL en "URL o ID de la página padre".
4. Pulsa "Conectar con Notion" (crea la base de datos una vez) y luego "Sincronizar ahora".

## Generar un .ipa para cada release

`scripts/build-ipa.sh` automatiza `xcodegen generate` + `xcodebuild archive` + `xcodebuild -exportArchive`, firmando con tu Apple ID (firma automática, sin cuenta de pago):

```bash
./scripts/build-ipa.sh
```

El `.ipa` queda en `build/export/PennyNote.ipa`. Repite este comando cada vez que quieras sacar una nueva versión para instalar.

Si `xcodebuild` se queja de que hay varios equipos de firma disponibles, añade tu Team ID a `scripts/ExportOptions.plist`:

```xml
<key>teamID</key>
<string>TU_TEAM_ID</string>
```

(lo encuentras en Xcode → Settings → Accounts → tu Apple ID → "Team ID", o en developer.apple.com/account).

## Instalar con AltStore PAL

Al estar en la UE, [AltStore PAL](https://altstore.io) instala la app sin el límite de 7 días de las firmas de cuenta gratuita:

1. Instala AltStore PAL en tu iPhone (marketplace notarizado por Apple para la UE).
2. Copia el `.ipa` generado a tu iPhone (AirDrop, Mail, iCloud Drive, etc.) o ábrelo directamente desde el Mac con AltStore PAL conectado.
3. Ábrelo con AltStore PAL e inicia sesión con tu Apple ID cuando te lo pida — AltStore vuelve a firmar el `.ipa` con un certificado propio antes de instalarlo, así que no hace falta que el `.ipa` ya esté firmado de forma especial.
4. Tras instalar, añade el widget desde "Editar pantalla de inicio" y desde la personalización de la pantalla de bloqueo (esto no se puede hacer desde el `.ipa`, es un paso manual en el propio iPhone).
