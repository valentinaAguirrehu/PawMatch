# Base de datos D1 de PawMatch

El Worker de `worker/` habla con Cloudflare D1 por el binding `DB`. Las fotos van al bucket R2 `ARCHIVOS`. PostgreSQL y Express siguen en el repositorio y no se modifican con estos comandos.

## Estructura

```text
paw_match_backend/d1/
├── migrations/
│   ├── 0001_initial_schema.sql
│   └── 0002_sesiones.sql
├── seeds/
│   └── seed_pruebas.sql
├── worker/
│   ├── src/
│   ├── wrangler.toml
│   ├── package.json
│   └── .dev.vars.example
├── MIGRACION-D1.md
└── README.md
```

`migrations/` solo crea o cambia la estructura. `seeds/` carga datos ficticios y no se aplica al publicar. El backend está en `worker/src` y usa `env.DB`.

## Base y binding

| Dato | Valor |
|---|---|
| Nombre | `pawmatch` |
| Binding | `DB` |
| Migraciones | `../migrations`, relativo a `worker/wrangler.toml` |
| Archivos | binding `ARCHIVOS`, bucket `pawmatch-archivos` |
| Id local | `00000000-0000-0000-0000-000000000000`, solo para comandos `--local` |
| Id de producción | Hay que sustituirlo en `[env.production]` |

La base de producción todavía no tiene un `database_id` real. No ejecutes comandos remotos hasta reemplazarlo.

## Variables

Copia `worker/.dev.vars.example` a `worker/.dev.vars`. Ese archivo no se versiona.

- `SESION_SECRETO`: obligatorio, 32 caracteres o más. Firma la cookie `paw_sesion`. Cada sesión también queda en D1 (`0002_sesiones.sql`) como hash, no como token. Logout revoca esa fila.
- `OPENAI_API_KEY`: entrevista de personalidad y de Luna. Sin ella esas rutas responden 503 y no guardan una puntuación ni una ficha inventada. El saludo inicial de Luna no llama a OpenAI. El modelo por defecto es `gpt-6-luna`; se puede cambiar con `OPENAI_CHAT_MODEL`.
- `RESEND_API_KEY` y `CORREO_DESDE`: envío real por Resend, con texto y HTML. Sin ellas la recuperación responde 503 y no guarda el código. Aprobaciones, rechazos, contrato, alertas y denuncias responden `correo_enviado: false` y no dicen que el correo salió. La alerta de tres incumplimientos solo se marca como enviada si Resend acepta el mensaje.
- `CORS_ORIGINS`: orígenes de Flutter Web, separados por coma. En local está en `wrangler.toml`. En producción está en `[env.production.vars]` y hay que poner el dominio de Pages.

En producción los secretos se cargan con `npx wrangler secret put NOMBRE --env production`. No los escribas en migraciones, seeds ni en el repositorio.

## Migraciones locales

Desde `paw_match_backend/d1/worker`:

```powershell
npm install
npx wrangler d1 migrations apply pawmatch --local
npx wrangler d1 execute pawmatch --local --file=../seeds/seed_pruebas.sql
```

El seed usa `INSERT OR IGNORE`. Volver a ejecutarlo no pisa filas existentes. La contraseña de las dos cuentas de desarrollo es `Prueba#2026`:

- `admin.prueba@example.com`
- `adoptante.prueba@example.com`

## Pruebas locales

```powershell
npx wrangler d1 execute pawmatch --local --command "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name;"
npx wrangler dev
```

Con el Worker en marcha, la API queda en `http://127.0.0.1:8787`. Flutter Web usa `/api` cuando se publica en el mismo origen. En celular, sin `--dart-define`, apunta a `http://127.0.0.1:8787/api`.

## Producción

1. `npx wrangler login`
2. `npx wrangler d1 create pawmatch`
3. Copia el bloque comentado de `[env.production]` en `wrangler.toml` y pega el `database_id` real. No dejes el identificador local `00000000-0000-0000-0000-000000000000` en producción.
4. Escribe `CORS_ORIGINS` con el dominio real de Pages. El frontend desplegado usa `/api` en el mismo origen; no hace falta inventar la URL del Worker.
5. `npx wrangler r2 bucket create pawmatch-archivos`
6. Carga los secretos con `--env production`.
7. Aplica la migración remota solo cuando el id ya sea el real:

```powershell
npx wrangler d1 migrations apply pawmatch --env production --remote
```

8. El seed de prueba no se carga en producción.
9. Publica el Worker, sin hacerlo desde este repositorio de forma automática:

```powershell
npx wrangler deploy --env production
```

En el mismo dominio HTTPS de Pages, crea dos rutas de Cloudflare hacia el Worker `pawmatch-api`: `tudominio/api*` y `tudominio/uploads*`. No basta un rewrite interno de Pages ni apuntar Flutter a `workers.dev`: la cookie `paw_sesion` es `HttpOnly`, `Secure` en HTTPS, `SameSite=Lax` y `Path=/api`, así que el navegador solo la envía si `/api` y la página comparten origen. Las fotos de mascotas, noticias, fundación y perfil siguen en `/uploads`. Seguimientos, cancelaciones, documentos, contratos y denuncias se leen por `/api/archivos/...` con sesión.

No vuelvas a editar `0001_initial_schema.sql` después de aplicarla en una base real. El cambio siguiente va en `0002_....sql`.
