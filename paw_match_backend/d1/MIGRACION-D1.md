# Migración de PawMatch a Cloudflare D1

Estos archivos preparan la migración. No se ejecutaron y la base PostgreSQL no fue modificada.

Archivos:

- `migrations/0001_initial_schema.sql`: esquema D1. Wrangler lo aplica en orden.
- `seeds/seed_pruebas.sql`: datos ficticios. No forma parte de las migraciones.
- `worker/`: API que usa el binding `DB`.
- `README.md`: comandos locales, de producción y de prueba.

## Qué cambia antes de ejecutar

El esquema conserva los nombres de tablas y columnas. Lo que no puede copiarse tal cual es el dialecto de PostgreSQL y el acceso con el paquete `pg`.

### Tipos

| PostgreSQL | D1 |
|---|---|
| `uuid` y `gen_random_uuid()` | `TEXT`. El valor predeterminado usa `randomblob`. |
| `boolean` | `INTEGER`: 0 o 1. |
| `jsonb` y `json` | `TEXT` con JSON dentro. |
| `timestamptz`, `timestamp`, `date` | `TEXT`. `CURRENT_TIMESTAMP` y `CURRENT_DATE` siguen disponibles. |
| `numeric` | `REAL` |
| `smallint`, `bigint` | `INTEGER` |
| `ENUM` (`rol_usuario`, `estado_cuenta`, `estado_solicitud`, `estado_adopcion`, `estado_apadrinamiento`) | `TEXT` con `CHECK` |
| `varchar(n)` | `TEXT`. SQLite no impone el largo. |

### Funciones que hay que pasar al Worker

D1 no ejecuta PL/pgSQL. Estas tres funciones existen hoy en PostgreSQL y el backend las llama:

- `fn_verificar_tres_incumplimientos`: la usan las rutas de seguimiento de apadrinamiento. Hay que reemplazar cada `SELECT ... FROM fn_verificar_tres_incumplimientos(?)` por la misma consulta de los últimos tres seguimientos, escrita en JavaScript.
- `fn_promedio_calificacion_padrino`: promedio de `seguimientoapadrinamiento.calificacion`. Se reemplaza con `SELECT ROUND(AVG(calificacion), 1)`.
- `registrar_evaluacion`: transacción que evalúa un ciclo, actualiza la solicitud, puede bloquear al usuario y crea una notificación. En D1 se escribe como `env.DB.batch([...])`.

La vista `vista_resumen_padrinos` quedó en `migrations/0001_initial_schema.sql`, con la sintaxis de SQLite.

### Consultas del backend que no sirven en D1

Hay que revisar cada archivo de `paw_match_backend/routes` y `utils` antes de apagar PostgreSQL:

- `$1`, `$2` pasan a `?`.
- `ILIKE` pasa a `LIKE` con `COLLATE NOCASE`, o a `lower(columna) LIKE lower(?)`.
- `NOW()` pasa a `CURRENT_TIMESTAMP`.
- `INTERVAL '15 minutes'`, `INTERVAL '48 hours'` y `AGE(...)` pasan a `datetime('now', '+15 minutes')` y comparaciones equivalentes.
- `to_char(...)` y `AT TIME ZONE` se formatean en JavaScript, o con `strftime`.
- `columna::text`, `::int`, `::jsonb`, `::date` y `::boolean` se eliminan. Los valores ya son texto o número.
- `DISTINCT ON` se reemplaza con una subconsulta que toma el último registro por solicitud.
- `FOR UPDATE` no existe. Las decisiones de adopción y cancelación deben hacerse con `batch` y una condición en el `UPDATE`.
- `json_build_object`, `jsonb_array_length` y `'[]'::jsonb` pasan a `json_object`, `json_array_length` y el texto `'[]'`.
- `COUNT(*)::int` pasa a `COUNT(*)`.
- `ON CONFLICT` sí existe y puede conservarse.
- `RETURNING` sí existe en D1.

El cálculo de edad en `utils/edad_mascota.js` usa `AGE` y `EXTRACT`. Hay que calcular años y meses en JavaScript a partir de `fecha_nacimiento`.

Los booleanos que hoy llegan como `true` o `false` llegarán como `0` o `1`. Cualquier comparación `=== true` en Node debe aceptar también `1`.

### Tabla de borradores

El volcado de PostgreSQL contiene `borrador_registro_mascota_luna`. Al arrancar, `utils/entrevista_mascota_admin.js` elimina esa tabla y crea `borrador_mascota_formulario_ia`. El esquema de D1 incluye solo la tabla que el código usa ahora, con sus columnas `foto`, `origen_registro`, `estado_adopcion` y `estado_apadrinamiento`.

### Conexión

Hoy `db.js` crea un `Pool` de `pg` con `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` y `DB_PASSWORD`.

En Cloudflare no hay ese pool. El Worker recibe la base por el binding `env.DB`:

```js
await env.DB.prepare('SELECT id_usuario FROM usuario WHERE correo = ?').bind(correo).first();
```

Las contraseñas de PostgreSQL no se copian al Worker ni a Flutter. El secreto de sesión se guarda con Wrangler y no aparece en el código.

### Sesión

El Worker cubre usuarios, perfiles, mascotas, adopciones, apadrinamientos, seguimientos, evaluaciones, noticias, fundación, denuncias y archivos. La identidad sale de la cookie `paw_sesion`. En celular, el cliente nativo pide el token y lo reenvía como `Authorization`; Flutter Web no lo recibe en el JSON.

Estas piezas no pueden copiarse igual dentro de un Worker:

- Las funciones PL/pgSQL quedaron reescritas en JavaScript: los tres incumplimientos, el promedio del padrino y la evaluación de ciclo.
- `LATERAL`, `DISTINCT ON`, `FOR UPDATE`, `ILIKE`, `to_char`, `INTERVAL` y `AGE` se reemplazaron por SQL de SQLite.
- Nodemailer no corre en Workers. El correo sale por Resend si existen `RESEND_API_KEY` y `CORREO_DESDE`. Sin esas variables el dato se guarda y el correo no se envía.
- Quitar el fondo con `@imgly/background-removal-node` no corre en Workers. La foto se guarda tal como se subió.
- La entrevista Luna llama a OpenAI con una instrucción breve. El guion largo de `entrevista_mascota_admin.js` no está copiado palabra por palabra.
- Las fotos viven en el bucket R2 `ARCHIVOS`, no en el disco `uploads`.

El registro valida las mismas reglas que `routes/usuarios.js` y guarda bcrypt con costo 10. La respuesta no incluye `contrasena_hash`.

El login comprueba el hash y que `estado_cuenta` sea `activo`. La sesión viaja en la cookie `paw_sesion`: `HttpOnly`, `Secure`, `SameSite=Lax` y `Path=/api`. El navegador no permite leerla desde JavaScript, así que Flutter Web no puede guardarla en `localStorage` ni en `shared_preferences`.

Express y PostgreSQL siguen en el repositorio. El corte se hace al publicar el Worker y apuntar Flutter a esa API. No se ha ejecutado nada contra D1 ni contra la base original.

## Importar el esquema

1. Instala Wrangler e inicia sesión: `npx wrangler login`.
2. Desde `paw_match_backend/d1/worker`, crea la base:

```powershell
npx wrangler d1 create pawmatch
```

3. Copia el `database_id` que devuelve el comando y reemplaza `REEMPLAZAR_DESPUES_DE_CREAR_LA_BASE` en `wrangler.toml`.
4. Crea el esquema en una base local primero:

```powershell
npx wrangler d1 migrations apply pawmatch --local
npx wrangler d1 execute pawmatch --local --file=../seeds/seed_pruebas.sql
```

5. La migración remota se aplica después de sustituir el `database_id` de producción: `npx wrangler d1 migrations apply pawmatch --env production --remote`. El seed de prueba no se carga en producción.
6. Crea el bucket de archivos y los secretos. No los escribas en el repositorio:

```powershell
npx wrangler r2 bucket create pawmatch-archivos
npx wrangler secret put SESION_SECRETO
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put RESEND_API_KEY
npx wrangler secret put CORREO_DESDE
```

`SESION_SECRETO` debe tener al menos 32 caracteres. `OPENAI_API_KEY` habilita Luna y la voz. `RESEND_API_KEY` y `CORREO_DESDE` habilitan el correo. Sin ellos esas funciones responden, pero no generan audio ni envían mensajes.

7. En `worker`, instala la dependencia y publica:

```powershell
npm install
npx wrangler deploy
```

La migración y el seed se prueban solo en la base local. La base remota no se ha creado ni modificado.

## Binding

En `wrangler.toml` el binding de la base se llama `DB` y el de archivos `ARCHIVOS`. `CORS_ORIGINS` es la lista de orígenes de Flutter Web, separados por coma. Con cookies no se puede usar `*`.

En Cloudflare Pages, publica el build de Flutter y enruta `/api/*` y `/uploads/*` al Worker. Así la web usa el mismo origen y la cookie viaja sola.

## Cuentas de prueba

Ambas usan la contraseña `Prueba#2026`:

- `admin.prueba@example.com`, rol `administrador`
- `adoptante.prueba@example.com`, rol `usuario`

También hay dos mascotas, una solicitud de adopción pendiente, una de apadrinamiento pendiente, las nueve preguntas de personalidad y una noticia. No contienen datos personales.

## Conectar Flutter Web

`ApiService.baseUrl` ya no apunta a `localhost:3000`. En web usa `/api`, el mismo origen de Pages. En celular usa `http://127.0.0.1:8787/api` para `wrangler dev`. Otro destino se pasa con `--dart-define=API_BASE=https://pawmatch-api.<tu-subdominio>.workers.dev/api`.

`lib/services/cliente_http.dart` envía la cookie en web y, solo en celular, guarda el token en memoria y lo manda como `Authorization`. El login quita `sesion` del JSON antes de guardarlo. No pongas `SESION_SECRETO` ni contraseñas en Dart.

Agrega el dominio de Pages a `CORS_ORIGINS` antes de publicar.
