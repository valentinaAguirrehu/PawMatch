# Guía final de conexión a Cloudflare

Fecha de esta revisión: 2026-11-11.

Esta guía deja PawMatch preparado para conectarlo. No crea la base remota, no crea el bucket remoto, no aplica migraciones remotas, no escribe secretos y no publica el Worker ni Flutter Web.

Express y PostgreSQL siguen intactos como respaldo.

## 1. Recursos Cloudflare que ya existen

En esta máquina Wrangler no tiene sesión:

```text
npx wrangler whoami
You are not authenticated. Please run `wrangler login`.
```

Comando ejecutado en `paw_match_backend/d1/worker` con Wrangler 4.160.1. Por eso no se pudo listar D1 ni R2 de la cuenta. No se asume que estén vacíos.

Lo que sí existe en el proyecto, solo para desarrollo local:

- Worker con nombre `pawmatch-api` y entrada `src/index.js`.
- Binding local `DB` hacia la base local `pawmatch`.
- Binding local `ARCHIVOS` hacia el bucket local `pawmatch-archivos`.
- Migraciones en `paw_match_backend/d1/migrations/`: `0001_initial_schema.sql` y `0002_sesiones.sql`.
- Secreto local `SESION_SECRETO` en `.dev.vars`. Ese archivo está en `.gitignore`. No contiene `RESEND_API_KEY`, `CORREO_DESDE`, `CORREO_RESPUESTA` ni `OPENAI_API_KEY`.

El identificador `00000000-0000-0000-0000-000000000000` de `wrangler.toml` es solo local. No es una base de producción y no debe copiarse a `[env.production]`.

## 2. Recursos que todavía debes crear

Después de iniciar sesión, y solo con tu autorización expresa:

1. Una base D1 de producción llamada `pawmatch`, si `wrangler d1 list` no muestra ya una base con ese nombre.
2. Un bucket R2 llamado `pawmatch-archivos`, si `wrangler r2 bucket list` no muestra ya ese bucket.
3. El bloque `[env.production]` con el `database_id` real, el binding `DB`, el binding `ARCHIVOS` y `CORS_ORIGINS` del dominio HTTPS real.
4. Los secretos de producción con `wrangler secret put`.
5. Un dominio HTTPS propio. No hay ninguno guardado en el proyecto.
6. Un dominio verificado en Resend para el remitente. `angiebenavides1809@gmail.com` no puede ser el `From` mientras el dominio sea `gmail.com`.

Si al listar aparece una base o un bucket con datos, detente. No ejecutes `create`, `migrations apply --remote` ni borres objetos.

## 3. IDs y nombres reales obtenidos

| Recurso | Valor real |
| --- | --- |
| Cuenta Cloudflare | No consultada: Wrangler no está autenticado |
| D1 remota | Pendiente. No hay `database_id` de producción |
| Nombre previsto de la base | `pawmatch` |
| Binding D1 | `DB` |
| R2 remoto | Pendiente. No se confirmó ningún bucket en la cuenta |
| Nombre previsto del bucket | `pawmatch-archivos` |
| Binding R2 | `ARCHIVOS` |
| Worker | `pawmatch-api` |
| Dominio HTTPS | Falta. Hay que indicarlo antes de CORS y de las rutas |

## 4. Migraciones aplicadas y pendientes

Archivos listos, sin cambios en esta fase:

- `0001_initial_schema.sql`: tablas de la aplicación, incluidas adopciones y apadrinamientos.
- `0002_sesiones.sql`: tabla `sesion` (hash de la sesión, usuario, expiración, revocación) e índices `idx_sesion_usuario` e `idx_sesion_expira`.

Estado local: estas dos migraciones ya estaban aplicadas en la base local de pruebas. Esa base tiene solicitudes ficticias y no se copia a producción.

Estado remoto: no comprobado. `wrangler d1 migrations list --remote` no se ejecutó porque no hay sesión ni `database_id` real.

No se ejecutó el seed. No se migraron datos de PostgreSQL.

Cuando la base remota exista y esté vacía, el comando de aplicación está en la sección 9. Si ya tiene tablas o filas, no lo ejecutes.

## 5. Secretos que debes configurar

No los escribas en el repositorio, en `.dev.vars` de producción, en el README ni en el chat. Introducelos solo con Wrangler, desde `paw_match_backend/d1/worker`, después de `npx wrangler login`.

Obligatorio antes de publicar:

```powershell
npx wrangler secret put SESION_SECRETO --env production
```

Usa una cadena aleatoria de al menos 32 caracteres, distinta de la de desarrollo. Wrangler la pide en la terminal y no la muestra en el archivo.

Correo, solo si vas a enviar correos:

```powershell
npx wrangler secret put RESEND_API_KEY --env production
npx wrangler secret put CORREO_DESDE --env production
npx wrangler secret put CORREO_RESPUESTA --env production
```

- `RESEND_API_KEY`: la clave que generas en el panel de Resend. No la pegues aquí.
- `CORREO_DESDE`: una dirección de un dominio que tú verifiques en Resend, por ejemplo `noreply@tu-dominio`. No uses `angiebenavides1809@gmail.com` en este secreto.
- `CORREO_RESPUESTA`: `angiebenavides1809@gmail.com`. El Worker la envía como `reply_to` solo si el secreto existe. Las respuestas llegan a esa bandeja; el remitente visible sigue siendo el dominio verificado.

Luna, solo si vas a activarla:

```powershell
npx wrangler secret put OPENAI_API_KEY --env production
```

Sin esa clave, Luna responde que el servicio no está configurado. No se simula una respuesta del modelo.

`CORS_ORIGINS` no es un secreto. Es una variable pública del entorno de producción y lleva el origen HTTPS exacto, por ejemplo `https://tudominio.com`. Hoy el valor de `[vars]` es solo local: `http://localhost:8080,http://127.0.0.1:8080`. No lo uses en producción.

Estado actual: ninguno de estos secretos está configurado en Cloudflare, porque no hay sesión de Wrangler.

## 6. Configuración del correo y estado de verificación

Resend no permite usar una cuenta `@gmail.com` como `From`. El dominio `gmail.com` no es tuyo: no puedes publicar sus registros SPF y DKIM. Resend rechaza un remitente de un dominio no verificado.

La dirección `onboarding@resend.dev` solo entrega al correo de la cuenta de Resend. No sirve para producción.

Configuración que sí permite enviar y recibir respuestas en Gmail:

1. Verifica en Resend un dominio que controles.
2. Publica en el DNS de ese dominio los registros que Resend muestre. No inventes los valores.
3. Guarda `CORREO_DESDE` con una dirección de ese dominio.
4. Guarda `CORREO_RESPUESTA` con `angiebenavides1809@gmail.com`.
5. El código ya añade `reply_to` cuando ese secreto existe (`paw_match_backend/d1/worker/src/http.js`). Si faltan `RESEND_API_KEY` o `CORREO_DESDE`, `enviarCorreo` responde `enviado: false` y `motivo: sin_configurar`. Si Resend rechaza el mensaje, responde `enviado: false` y `motivo: rechazado`. Solo `enviado: true` significa que Resend aceptó el envío.

Plantillas HTML que ya usa el Worker, sin cambio de diseño: recuperación de contraseña, verificación, adopción, apadrinamiento, aprobación, rechazo, contrato e incumplimiento. Están en `paw_match_backend/d1/worker/src/correos.js`.

El panel ya no afirma que el correo salió si Resend no lo aceptó:

- Adopción: el aviso de aprobación o rechazo agrega “El correo fue aceptado por el servicio de envío” solo cuando `correo_enviado` es `true`. Si no, dice que no se envió y quedó pendiente.
- Apadrinamiento: el mismo criterio en aceptar y rechazar, tanto en la lista como en el detalle.
- El Worker no marca `correo_alerta_enviado` si Resend no aceptó. Un cambio de estado repetido no vuelve a enviar el mismo correo.
- Estado de verificación de `angiebenavides1809@gmail.com` en Resend: no comprobado. No hay clave de Resend en el entorno local ni remoto.

## 7. Dominio y rutas que debes configurar

Falta el dominio. No se inventó uno. Cuando lo tengas, sustitúyelo en todos estos puntos. Ejemplo de forma, no de valor: `https://pawmatch.tudominio.com`.

En el mismo origen HTTPS:

- Flutter Web en `/`.
- Worker en `/api/*`.
- Archivos públicos del Worker en `/uploads/*`.

Flutter Web ya consume `/api` en el mismo origen (`lib/services/api_service.dart`). No hace falta un `API_BASE` de `workers.dev` si la página y `/api` comparten dominio. La cookie `paw_sesion` es `HttpOnly`, `SameSite=Lax`, `Path=/api` y `Secure` solo cuando la petición es HTTPS. Si la web y la API están en orígenes distintos, el navegador no envía esa cookie.

Rutas públicas de archivos, sin sesión: `/uploads/mascotas/`, `/uploads/noticias/`, `/uploads/fundacion/` y `/uploads/usuarios/`. Cualquier otra carpeta de `/uploads` responde 404 “Archivo no disponible”.

Rutas privadas, con sesión de dueño o administrador: cédulas, recibos, contratos, documentos de apadrinamiento, seguimientos, cancelaciones y denuncias, por `/api/archivos/...` y por las rutas específicas de adopción, apadrinamiento y denuncia. No actives acceso público del bucket R2.

CORS de producción: el origen exacto de Pages, con `https`, sin barra final. El Worker también acepta `localhost` y `127.0.0.1` para desarrollo; eso no sustituye el dominio real.

## 8. Pasos exactos en el panel de Cloudflare

Hazlos en este orden, después de tener cuenta y dominio.

1. Entra a https://dash.cloudflare.com e inicia sesión.
2. Workers & Pages → D1 → Create. Nombre: `pawmatch`. Copia el Database ID que muestra el panel. Si ya existe, ábrela y revisa si tiene tablas antes de migrar. No importes el SQL de prueba.
3. R2 → Create bucket. Nombre: `pawmatch-archivos`. Deja el acceso público desactivado. No borres objetos si el bucket ya existe.
4. Workers & Pages → el Worker `pawmatch-api`, cuando exista tras el deploy. Settings → Variables and Secrets. No pegues secretos en `[vars]`. Los secretos se cargan con los comandos de la sección 5. En Variables de texto, `CORS_ORIGINS` = `https://TU-DOMINIO` cuando el dominio sea real.
5. Websites → Add a site, o el dominio que ya tengas. Activa el certificado HTTPS. No uses “Flexible” si el origen también puede servir HTTP: usa Full o Full (strict) cuando el certificado del origen sea válido. Pages ya termina TLS en Cloudflare.
6. Workers & Pages → Create → Pages → sube `build/web` o conecta el repositorio. El proyecto de Pages sirve Flutter Web.
7. En el dominio, Workers Routes:
   - `TU-DOMINIO/api*` → Worker `pawmatch-api`
   - `TU-DOMINIO/uploads*` → Worker `pawmatch-api`
   El resto del dominio queda en Pages.
8. Resend → Domains → Add domain. Copia los registros DNS al dominio de Cloudflare. Espera a que Resend marque el dominio como verificado. Después guarda `CORREO_DESDE` y `CORREO_RESPUESTA`.

No pulses Deploy hasta decidirlo. Los pasos 2 y 3 crean recursos vacíos; si prefieres crearlos por terminal, usa la sección 9 y no los dupliques.

## 9. Comandos exactos para conectar y desplegar

Todos los comandos de Wrangler se ejecutan en PowerShell, en esta carpeta:

`D:\Angie\Documentos\Estudio\UCC\Tercer Semestre\PawMatch\PawMatch\paw_match_backend\d1\worker`

Los de Flutter, en la raíz del proyecto:

`D:\Angie\Documentos\Estudio\UCC\Tercer Semestre\PawMatch\PawMatch`

### 9.1. Entrar y comprobar la cuenta

```powershell
cd "D:\Angie\Documentos\Estudio\UCC\Tercer Semestre\PawMatch\PawMatch\paw_match_backend\d1\worker"
npx wrangler login
npx wrangler whoami
npx wrangler d1 list
npx wrangler r2 bucket list
```

`wrangler login` abre el navegador. No pegues el token en el chat.

Si `d1 list` ya muestra `pawmatch`, no ejecutes `d1 create`. Anota el `uuid` y revisa tablas con una consulta de solo lectura:

```powershell
npx wrangler d1 execute pawmatch --remote --command "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"
```

Si hay tablas o filas que no esperas, detente y no apliques migraciones.

Si `r2 bucket list` ya muestra `pawmatch-archivos`, no lo vuelvas a crear y no borres objetos.

### 9.2. Crear solo lo que no exista

Solo con autorización, y solo si el listado anterior no los muestra:

```powershell
npx wrangler d1 create pawmatch
npx wrangler r2 bucket create pawmatch-archivos
```

Copia el `database_id` que imprime `d1 create`. Luego edita `wrangler.toml` y descomenta el bloque de producción con estos datos reales:

- `CORS_ORIGINS`: el `https://TU-DOMINIO` real, no el texto de ejemplo.
- `binding = "DB"`, `database_name = "pawmatch"`, `database_id` copiado del comando.
- `migrations_dir = "../migrations"`.
- `binding = "ARCHIVOS"`, `bucket_name = "pawmatch-archivos"`.

No pongas `00000000-0000-0000-0000-000000000000` en producción.

### 9.3. Migraciones remotas

Primero mira el estado:

```powershell
npx wrangler d1 migrations list pawmatch --env production --remote
```

Si la base está vacía y el `database_id` de producción ya está en el archivo:

```powershell
npx wrangler d1 migrations apply pawmatch --env production --remote
```

No ejecutes el seed. No copies la base local `.wrangler`.

Vuelve a listar:

```powershell
npx wrangler d1 migrations list pawmatch --env production --remote
npx wrangler d1 execute pawmatch --remote --command "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"
```

Debes ver, entre otras, `usuario`, `mascota`, `solicitudadopcion`, `solicitudapadrinamiento` y `sesion`.

### 9.4. Secretos

Ejecuta los `wrangler secret put` de la sección 5. Wrangler pregunta el valor en la terminal.

### 9.5. Publicar, solo cuando lo autorices

Sigue en la carpeta del Worker:

```powershell
npx wrangler deploy --env production
```

Luego, en la raíz de PawMatch:

```powershell
cd "D:\Angie\Documentos\Estudio\UCC\Tercer Semestre\PawMatch\PawMatch"
flutter build web --release --no-wasm-dry-run
```

Sube el contenido de `build\web` al proyecto de Pages desde el panel, o con el comando de Pages que te muestre Cloudflare cuando el proyecto exista. No se ejecutó ninguno de estos comandos de publicación.

No despliegues el entorno por defecto de `wrangler.toml`: ese entorno apunta a la base local ficticia.

## 10. Cómo comprobar D1, R2, el Worker y Flutter Web

Hazlo después del deploy, en el dominio HTTPS, no contra la base local.

1. `https://TU-DOMINIO/` carga Flutter Web.
2. `POST https://TU-DOMINIO/api/usuarios/login` con un usuario real de producción, no con `adoptante.prueba`. La respuesta web no debe incluir el token. La cookie `paw_sesion` debe verse `HttpOnly`, `Secure` y `SameSite=Lax`.
3. Cierra sesión y comprueba que la misma cookie deja de autorizar.
4. Crea un usuario de prueba controlado en producción, o entra con el administrador real. No importes las filas locales.
5. Sube una foto de mascota y ábrela por `/uploads/mascotas/...` sin cookie. Debe responder 200.
6. Sube un documento de adopción y pide esa ruta por `/uploads/adopciones/...` sin cookie. Debe responder 404. Con la cookie del dueño o del administrador, `/api/archivos/adopciones/...` debe responder 200.
7. Repite el criterio con apadrinamiento, contrato y denuncia.
8. Una segunda solicitud pendiente para la misma persona y la misma mascota debe responder 409.
9. Sin `OPENAI_API_KEY`, Luna no debe decir que consultó el modelo.
10. Sin Resend, aprobar o rechazar debe decir que el correo quedó pendiente.

Comprobaciones de esta fase, con resultado real:

| Prueba | Resultado |
| --- | --- |
| `npx wrangler whoami` | Ejecutada. No hay sesión |
| Listado remoto de D1 y R2 | No ejecutada |
| Migraciones remotas | No ejecutadas |
| Lectura y escritura remota de D1 | No ejecutada |
| Subida remota a R2 | No ejecutada |
| Login, logout y permisos en producción | No ejecutados |
| Login y flujos locales de la fase 8 | Ya verificados en local. No cuentan como producción |
| Aviso de correo en el código | Corregido. No se volvió a rechazar una solicitud para ver el aviso en el navegador |

## 11. Cómo comprobar el envío real de correos

1. En Resend, el dominio del remitente debe estar en estado verificado.
2. Los tres secretos `RESEND_API_KEY`, `CORREO_DESDE` y `CORREO_RESPUESTA` deben existir en el Worker de producción. Comprueba los nombres, no los valores:

```powershell
npx wrangler secret list --env production
```

3. Desde el panel, rechaza o aprueba una solicitud real. El aviso debe decir que el servicio aceptó el correo. En Resend → Emails debe aparecer el mensaje con estado entregado o aceptado.
4. Responde a ese mensaje. Debe llegar a `angiebenavides1809@gmail.com` por `Reply-To`.
5. Si el aviso dice que quedó pendiente, no busques el mensaje en Resend: no salió. Revisa que los secretos y el dominio verificado existan y vuelve a usar la acción de reenviar. No se guarda un envío exitoso falso.
6. Recuperación de contraseña: pide el enlace con un correo real de un usuario de producción y confirma que llega desde `CORREO_DESDE`.

No se hizo un envío real en esta fase.

## 12. Cómo regresar a Express y PostgreSQL

No se migraron filas de PostgreSQL. La base de respaldo sigue siendo la que usa `paw_match_backend/server.js`.

1. No ejecutes `wrangler deploy` otra vez. En Cloudflare, quita las rutas `TU-DOMINIO/api*` y `TU-DOMINIO/uploads*` del Worker, o desactiva el Worker, para que no siga recibiendo tráfico.
2. En `paw_match_backend`, arranca el respaldo:

```powershell
cd "D:\Angie\Documentos\Estudio\UCC\Tercer Semestre\PawMatch\PawMatch\paw_match_backend"
npm start
```

Escucha en el puerto 3000, o en `PORT` si está definido. Usa el `.env` local, que no se versiona. No copies ese archivo al repositorio.

3. Flutter Web de producción apunta a `/api` del mismo dominio. Para volver a Express hace falta que ese dominio, o un proxy, entregue `/api` y `/uploads` a Node, no al Worker. En local puedes seguir usando el Worker de `127.0.0.1:8787`; cambiar a Express es una decisión de despliegue, no un cambio de esquema.
4. Los archivos que Express guarda en `uploads` y `private_uploads` no están en el R2 remoto. Un respaldo no los mueve solo.
5. Las cuentas y solicitudes creadas solo en D1 de producción no aparecen en PostgreSQL. Por eso no se debe cargar tráfico real en D1 hasta aceptar el corte.

## Qué falta para publicar

1. Ejecutar `npx wrangler login` en la carpeta del Worker.
2. Confirmar con `d1 list` y `r2 bucket list` si los recursos ya existen.
3. Autorizar la creación y, si la base está vacía, `migrations apply --remote`.
4. Indicar el dominio HTTPS real y escribirlo en `CORS_ORIGINS` de producción.
5. Verificar un dominio propio en Resend. Guardar `CORREO_DESDE` de ese dominio y `CORREO_RESPUESTA=angiebenavides1809@gmail.com`.
6. Cargar `SESION_SECRETO` y, si vas a usar Luna, `OPENAI_API_KEY`.
7. Autorizar `npx wrangler deploy --env production` y la subida de `build\web` a Pages.
8. Configurar las dos rutas del Worker en el mismo dominio.
9. Probar login, archivos privados y un correo real antes de abrir el sitio al público.
