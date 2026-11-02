# Desarrollo

## Requisitos

- Xcode 27+ con el runtime de iOS Simulator 18.0+ instalado (`xcodebuild -downloadPlatform iOS` si no lo tienes).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.
- Para publicar versiones: [GitHub CLI](https://cli.github.com) (`gh`) autenticado y `jq`.
- Para ejecutar en un dispositivo desde Xcode: un Apple ID añadido en Xcode → Settings → Accounts. Generar el `.ipa` no lo necesita (ver más abajo).

El proyecto `.xcodeproj` **no se versiona**: se genera a partir de `project.yml`. Cualquier cambio de targets, capacidades o ajustes de build se hace editando `project.yml`, nunca a mano en Xcode. La única excepción es su `Package.resolved` (ver [Dependencias](#dependencias)).

## Supabase

La app guarda los datos en un proyecto de [Supabase](https://supabase.com) (el plan gratuito sobra). El esquema está en `supabase/migrations` y la configuración del cliente en `Config/Supabase.xcconfig`, que **no se versiona**.

### Crear el proyecto

1. Crea un proyecto en [supabase.com/dashboard](https://supabase.com/dashboard).
2. **Authentication → Sign In / Providers → Email**: deja activado *Enable Email provider* y desactiva *Confirm email* y *Secure password change* (los dos enviarían correos). Opcional: *Minimum password length* a 8, lo mismo que pide la app.
3. Aplica el esquema. Con la [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started):
   ```bash
   supabase link --project-ref <ref-del-proyecto>
   supabase db push
   ```
   Si la CLI pide `supabase/config.toml`, ejecuta antes `supabase init` (no toca las migraciones). O pega el contenido de `supabase/migrations/*.sql`, en orden, en el **SQL Editor** del panel.

### Sin correo: contraseñas olvidadas

La app no envía ningún email (el correo de serie de Supabase solo llega a los miembros de la organización y uno propio requiere SMTP), así que no hay «He olvidado la contraseña». Si alguien la olvida, ponle una temporal desde el **SQL Editor** y pásasela por otro medio; después la cambia en **Ajustes → Cambiar contraseña**:

```sql
update auth.users
set encrypted_password = extensions.crypt('contraseña-temporal', extensions.gen_salt('bf')),
    updated_at = now()
where email = 'persona@ejemplo.com';
```

Comprueba que dice `UPDATE 1`; `UPDATE 0` es que el email no coincide (la app los guarda en minúsculas). Si además sospechas que otra persona tenía acceso a la cuenta, cierra todas sus sesiones (los accesos ya emitidos caducan en una hora como máximo):

```sql
delete from auth.sessions
where user_id = (select id from auth.users where email = 'persona@ejemplo.com');
```

### Configurar la app

```bash
cp Config/Supabase.example.xcconfig Config/Supabase.xcconfig
```

Rellena `SUPABASE_URL` y `SUPABASE_ANON_KEY` con los valores de **Project Settings → API** (la anon key o la publishable key, nunca la `service_role`/secret). En un `.xcconfig` la URL se escribe `https:/$()/<ref>.supabase.co`, porque `//` empieza un comentario. Después, `xcodegen generate`.

Sin ese fichero la app compila pero solo muestra un aviso, y `scripts/build-ipa.sh` se niega a generar el `.ipa`.

La anon key acaba dentro del `.ipa` publicado: es pública por diseño. Lo que protege los datos es RLS (cada usuario solo lee y escribe sus filas). Cualquiera que la extraiga podría crear cuentas en el proyecto.

### Cómo se sincroniza

- SwiftData sigue siendo la fuente local: la app funciona sin conexión y sincroniza al abrirse, tras cada cambio (con 2 s de margen), al tirar hacia abajo en la lista y desde Ajustes.
- Gana la última modificación (`updated_at`, la pone el móvil); un trigger del servidor descarta una versión más antigua que la guardada. Para pedir solo lo cambiado se usa `server_updated_at`, que pone el servidor.
- Los borrados son lógicos (`is_deleted`) para que lleguen a los demás dispositivos.
- Sin sesión no hay datos en el iPhone: se bajan de la cuenta al iniciar sesión (y una cuenta nueva recibe las categorías de serie). Al cerrar sesión se sube lo pendiente y se borran los datos del iPhone.
- Un proyecto gratuito se pausa tras una semana sin uso; se reactiva desde el panel y no pierde datos.

## Abrir el proyecto

```bash
xcodegen generate
open PennyNote.xcodeproj
```

Selecciona el esquema `PennyNote` y un simulador de iPhone, y ejecuta con Cmd+R. Para ejecutar en un dispositivo, elige tu equipo de firma en los targets `PennyNote` y `PennyNoteWidgetExtension`.

Vuelve a ejecutar `xcodegen generate` cada vez que `project.yml` cambie (por ejemplo, tras un `git pull`).

### Dependencias

Los paquetes de Swift Package Manager se declaran en `project.yml` con un rango (`from:`), pero las versiones exactas, también las de sus dependencias, las fija `PennyNote.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, que sí se versiona: `xcodegen generate` no lo toca y Xcode usa esas versiones aunque haya otras más nuevas dentro del rango. Así todos los clones y el `.ipa` compilan con lo mismo.

Para actualizar una dependencia o cambiar su rango en `project.yml`:

1. `xcodegen generate` y, en Xcode, **File → Packages → Update to Latest Package Versions** (o **Resolve Package Versions** si solo has cambiado el rango).
2. Compila y pasa los tests.
3. Haz commit del `Package.resolved` junto con el cambio de `project.yml`.

`scripts/build-ipa.sh` compila con `-onlyUsePackageVersionsFromResolvedFile`: si el `Package.resolved` no cuadra con `project.yml`, falla en vez de resolver otras versiones.

### Datos de prueba (solo Debug)

Para capturas y mediciones, la app puede abrir con datos inventados sin tocar los de verdad. Con el argumento de lanzamiento `-DebugSeed YES` (en el esquema, *Run → Arguments*, o con `simctl`):

```bash
xcrun simctl launch --terminate-running-process booted com.pennynote.app -DebugSeed YES
```

- Usa un almacén propio en el App Group (`DebugSeed.store`), que se borra y se vuelve a rellenar en cada arranque: unos seis meses de gastos, siempre los mismos salvo por la fecha de hoy.
- `-DebugSeedExpenses 10000` cambia eso por ese número de gastos del día a día repartidos en dos años, más los fijos de cada mes.
- Entra con una sesión ficticia, sin cliente de Supabase: no sincroniza y Ajustes no muestra las secciones de bloqueo ni de cuenta. La moneda se guarda aparte y vuelve a la de la región en cada arranque; el widget sigue mostrando la de la instalación real, pero sí pinta los gastos de prueba hasta que la app vuelve a abrirse sin el argumento.
- En Release no existe: `DebugSeed.isActive` es siempre falso.

## Tests

Los tests (Swift Testing, target `PennyNoteTests`) cubren la lógica pura: cálculo del total mensual, estadísticas de gasto, datos del widget y la sincronización (contra un servidor falso en memoria). Se ejecutan con Cmd+U en Xcode o desde terminal:

```bash
xcodebuild test -project PennyNote.xcodeproj -scheme PennyNote -destination 'platform=iOS Simulator,name=iPhone 17'
```

O con `./scripts/test.sh`, que antes regenera el proyecto con `xcodegen generate`. Para otro simulador:
`PENNYNOTE_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro' ./scripts/test.sh`.

### Mediciones de rendimiento

`PennyNoteTests/PerformanceBenchmarks.swift` mide las rutas calientes (lista, Estadísticas, widget, sincronización y exportación) con 1k, 10k y 50k gastos de `DebugSeed`. No se ejecuta con el resto de tests: solo con la variable `PENNYNOTE_BENCHMARKS=1`, y tarda unos dos minutos.

```bash
TEST_RUNNER_PENNYNOTE_BENCHMARKS=1 xcodebuild test -project PennyNote.xcodeproj -scheme PennyNote -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PennyNoteTests/PerformanceBenchmarks | grep BENCH
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

1. Pasa los tests con `scripts/test.sh`; si alguno falla, se para sin tocar nada.
2. Sube `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` en `project.yml`.
3. Genera el `.ipa` y comprueba que lleva esa versión.
4. Añade la versión a `altstore-source.json`.
5. Hace commit y tag `v1.2.0`, sube el tag, crea la Release de GitHub con el `.ipa` y, al final, sube `main`, para que la source nunca apunte a un `.ipa` que aún no existe.

Hay que lanzarlo desde `main` sin cambios pendientes. Con `--dry-run` hace los cuatro primeros pasos sin commit, push ni Release, para revisar el resultado antes. Si falla antes del commit, restaura `project.yml` y la source.

La versión debe seguir el formato `X.Y.Z` y ser mayor que la anterior: AltStore solo ofrece la actualización si la versión sube.

**Antes de publicar una versión que añade migraciones** en `supabase/migrations`, aplícalas en el proyecto de Supabase (`supabase db push` o el SQL Editor, ver arriba). La app consulta esas tablas en cada sincronización: si falta una, la sincronización falla entera hasta que se aplica.
