# Desarrollo

## Requisitos

- Xcode 26+ con el runtime de iOS Simulator 18.0+ instalado (`xcodebuild -downloadPlatform iOS` si no lo tienes).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.
- Para publicar versiones: [GitHub CLI](https://cli.github.com) (`gh`) autenticado y `jq`.
- Para ejecutar en un dispositivo desde Xcode: un Apple ID añadido en Xcode → Settings → Accounts. Generar el `.ipa` no lo necesita (ver más abajo).

El proyecto `.xcodeproj` **no se versiona**: se genera a partir de `project.yml`. Cualquier cambio de targets, capacidades o ajustes de build se hace editando `project.yml`, nunca a mano en Xcode.

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

## Tests

Los tests (Swift Testing, target `PennyNoteTests`) cubren la lógica pura: cálculo del total mensual, estadísticas de gasto, datos del widget y la sincronización (contra un servidor falso en memoria). Se ejecutan con Cmd+U en Xcode o desde terminal:

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
