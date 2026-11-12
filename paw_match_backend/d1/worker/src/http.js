export function json(data, status = 200, extra = {}) {
  const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...extra };
  return new Response(JSON.stringify(data), { status, headers });
}

export function cors(request, env, response) {
  const headers = new Headers(response.headers);
  const origen = request.headers.get('Origin');
  const permitidos = String(env.CORS_ORIGINS || env.CORS_ORIGIN || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  if (origenPermitido(origen, permitidos)) {
    headers.set('Access-Control-Allow-Origin', origen);
  }
  headers.set('Access-Control-Allow-Credentials', 'true');
  headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Paw-Client');
  headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  headers.set('Vary', 'Origin');
  return new Response(response.body, { status: response.status, headers });
}

export function errorJson(error, mensaje) {
  console.error(error);
  return json({ error: mensaje }, 500);
}

export async function cuerpo(request) {
  const tipo = request.headers.get('Content-Type') || '';
  if (tipo.includes('application/json')) return request.json().catch(() => ({}));
  if (tipo.includes('multipart/form-data')) return request.formData();
  return {};
}

export function bool(valor) {
  if (valor === true || valor === 1 || valor === '1' || valor === 'true') return 1;
  if (valor === false || valor === 0 || valor === '0' || valor === 'false') return 0;
  return null;
}

export function esAdmin(rol) {
  const valor = String(rol || '').trim().toLowerCase();
  return valor === 'administrador' || valor === 'superadmin';
}

export function esSuper(rol) {
  return String(rol || '').trim().toLowerCase() === 'superadmin';
}

const COOKIE = 'paw_sesion';
const DOCE_HORAS = 60 * 60 * 12;
const TREINTA_DIAS = 60 * 60 * 24 * 30;

export async function firmar(payload, env) {
  const clave = await importarClave(env);
  const cuerpoToken = base64url(JSON.stringify(payload));
  const firma = await crypto.subtle.sign('HMAC', clave, new TextEncoder().encode(cuerpoToken));
  return `${cuerpoToken}.${base64url(new Uint8Array(firma))}`;
}

export async function usuarioDeRequest(request, env) {
  const payload = await payloadDeRequest(request, env);
  if (!payload?.sub || !payload.sid) return null;
  const fila = await env.DB.prepare(
    `SELECT expira, revocada FROM sesion WHERE hash_sesion = ? AND id_usuario = ?`
  ).bind(await hashSid(payload.sid), payload.sub).first();
  if (!fila || fila.revocada === 1) return null;
  if (!Number.isFinite(Date.parse(fila.expira)) || Date.parse(fila.expira) <= Date.now()) return null;
  const usuario = await env.DB.prepare(
    `SELECT id_usuario, nombres, apellidos, correo, telefono, rol, estado_cuenta, bloqueado_apadrinar, genero, voz_asistente
     FROM usuario WHERE id_usuario = ?`
  ).bind(payload.sub).first();
  if (!usuario || usuario.estado_cuenta !== 'activo') return null;
  return usuario;
}

export async function abrirSesion(env, idUsuario, recordar) {
  const segundos = recordar ? TREINTA_DIAS : DOCE_HORAS;
  const sid = crypto.randomUUID();
  const expira = new Date(Date.now() + segundos * 1000).toISOString();
  await env.DB.prepare('DELETE FROM sesion WHERE id_usuario = ? AND expira <= ?').bind(idUsuario, new Date().toISOString()).run();
  await env.DB.prepare(
    'INSERT INTO sesion (hash_sesion, id_usuario, expira, revocada) VALUES (?, ?, ?, 0)'
  ).bind(await hashSid(sid), idUsuario, expira).run();
  const token = await firmar({ sub: idUsuario, sid, exp: Math.floor(Date.now() / 1000) + segundos }, env);
  return { token, segundos };
}

export async function revocarSesion(request, env) {
  const payload = await payloadDeRequest(request, env);
  if (!payload?.sid) return;
  await env.DB.prepare('UPDATE sesion SET revocada = 1 WHERE hash_sesion = ?').bind(await hashSid(payload.sid)).run();
}

export async function revocarSesionesDeUsuario(env, idUsuario) {
  await env.DB.prepare('UPDATE sesion SET revocada = 1 WHERE id_usuario = ?').bind(idUsuario).run();
}

export async function revocarOtrasSesiones(request, env, idUsuario) {
  const payload = await payloadDeRequest(request, env);
  if (!payload?.sid) return revocarSesionesDeUsuario(env, idUsuario);
  await env.DB.prepare(
    'UPDATE sesion SET revocada = 1 WHERE id_usuario = ? AND hash_sesion <> ?'
  ).bind(idUsuario, await hashSid(payload.sid)).run();
}

export async function exigirUsuario(request, env) {
  const usuario = await usuarioDeRequest(request, env);
  if (!usuario) return { error: json({ error: 'Debes iniciar sesión' }, 401) };
  return { usuario };
}

export async function exigirAdmin(request, env) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso;
  if (!esAdmin(acceso.usuario.rol)) {
    return { error: json({ error: 'Solo un administrador puede realizar esta acción' }, 403) };
  }
  return acceso;
}

export async function exigirSuper(request, env) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso;
  if (!esSuper(acceso.usuario.rol)) {
    return { error: json({ error: 'Solo el superadministrador puede hacer esto' }, 403) };
  }
  return acceso;
}

export function cookieSesion(token, request, segundos = DOCE_HORAS) {
  return `${COOKIE}=${token}; HttpOnly${marcaSegura(request)}; SameSite=Lax; Path=/api; Max-Age=${segundos}`;
}

export function cookieVacia(request) {
  return `${COOKIE}=; HttpOnly${marcaSegura(request)}; SameSite=Lax; Path=/api; Max-Age=0`;
}

function marcaSegura(request) {
  try {
    return new URL(request.url).protocol === 'https:' ? '; Secure' : '';
  } catch {
    return '';
  }
}

function origenPermitido(origen, permitidos) {
  if (!origen) return false;
  if (permitidos.includes(origen)) return true;
  try {
    const url = new URL(origen);
    return url.protocol === 'http:' && (url.hostname === 'localhost' || url.hostname === '127.0.0.1');
  } catch {
    return false;
  }
}

export const DURACION_SESION = DOCE_HORAS;

async function payloadDeRequest(request, env) {
  const bearer = (request.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
  const token = bearer || leerCookie(request);
  if (!token) return null;
  return verificar(token, env);
}

async function hashSid(sid) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(String(sid)));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

async function verificar(token, env) {
  const [cuerpoToken, firma] = String(token).split('.');
  if (!cuerpoToken || !firma) return null;
  const esperada = base64url(new Uint8Array(
    await crypto.subtle.sign('HMAC', await importarClave(env), new TextEncoder().encode(cuerpoToken))
  ));
  if (!igual(firma, esperada)) return null;
  const payload = JSON.parse(new TextDecoder().decode(base64urlDecode(cuerpoToken)));
  if (!payload.exp || payload.exp < Math.floor(Date.now() / 1000)) return null;
  return payload;
}

async function importarClave(env) {
  if (!env.SESION_SECRETO || env.SESION_SECRETO.length < 32) {
    throw new Error('SESION_SECRETO ausente o demasiado corto');
  }
  return crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(env.SESION_SECRETO),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
}

function leerCookie(request) {
  const cookie = request.headers.get('Cookie') || '';
  const par = cookie.split(';').map((parte) => parte.trim()).find((parte) => parte.startsWith(`${COOKIE}=`));
  return par ? par.slice(COOKIE.length + 1) : '';
}

function base64url(valor) {
  const bytes = typeof valor === 'string' ? new TextEncoder().encode(valor) : valor;
  let texto = '';
  for (const byte of bytes) texto += String.fromCharCode(byte);
  return btoa(texto).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function base64urlDecode(texto) {
  const normal = texto.replaceAll('-', '+').replaceAll('_', '/');
  const relleno = normal + '='.repeat((4 - (normal.length % 4)) % 4);
  const binario = atob(relleno);
  return Uint8Array.from(binario, (caracter) => caracter.charCodeAt(0));
}

function igual(a, b) {
  if (a.length !== b.length) return false;
  let diferencia = 0;
  for (let i = 0; i < a.length; i += 1) diferencia |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diferencia === 0;
}

const LIMITE_POR_CARPETA = {
  mascotas: 10 * 1024 * 1024,
  noticias: 8 * 1024 * 1024,
  fundacion: 5 * 1024 * 1024,
  usuarios: 8 * 1024 * 1024,
  seguimientos_adopcion: 15 * 1024 * 1024,
  cancelaciones_adopcion: 15 * 1024 * 1024,
  cancelaciones_apadrinamiento: 15 * 1024 * 1024,
  adopciones: 10 * 1024 * 1024,
  apadrinamientos: 10 * 1024 * 1024,
  contratos: 15 * 1024 * 1024,
  denuncias: 25 * 1024 * 1024,
};
const EXTENSIONES_IMAGEN = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp']);
const EXTENSIONES_DOCUMENTO = new Set(['.jpg', '.jpeg', '.png', '.webp', '.pdf']);
const EXTENSIONES_DENUNCIA = new Set(['.jpg', '.jpeg', '.png', '.webp', '.mp4', '.mov', '.avi', '.mkv', '.3gp', '.webm']);

export class ErrorSolicitud extends Error {
  constructor(mensaje, status = 400) {
    super(mensaje);
    this.status = status;
  }
}

export async function guardarArchivo(env, carpeta, archivo) {
  if (!env.ARCHIVOS) throw new Error('Falta el binding R2 ARCHIVOS');
  const extension = (String(archivo.name || '').match(/\.[a-z0-9]+$/i) || [''])[0].toLowerCase();
  const permitidas = carpeta === 'denuncias'
    ? EXTENSIONES_DENUNCIA
    : (carpeta === 'adopciones' || carpeta === 'apadrinamientos' || carpeta === 'contratos')
      ? EXTENSIONES_DOCUMENTO
      : EXTENSIONES_IMAGEN;
  if (!permitidas.has(extension)) {
    throw new ErrorSolicitud('El formato del archivo no está permitido.');
  }
  if (Number(archivo.size || 0) === 0) {
    throw new ErrorSolicitud('El archivo está vacío.');
  }
  const mime = String(archivo.type || '').toLowerCase().split(';')[0].trim();
  const mimePermitido = carpeta === 'denuncias'
    ? /^(image\/(jpeg|jpg|png|webp)|video\/(mp4|quicktime|webm|x-msvideo|x-matroska|3gpp))$/.test(mime)
    : (carpeta === 'adopciones' || carpeta === 'apadrinamientos' || carpeta === 'contratos')
      ? /^(image\/(jpeg|jpg|png|webp)|application\/pdf)$/.test(mime)
      : /^(image\/(jpeg|jpg|png|webp|gif|bmp))$/.test(mime);
  if (!mimePermitido) {
    throw new ErrorSolicitud('El tipo del archivo no está permitido.');
  }
  const limite = LIMITE_POR_CARPETA[carpeta] || 8 * 1024 * 1024;
  if (Number(archivo.size || 0) > limite) {
    throw new ErrorSolicitud(`El archivo supera el máximo de ${Math.round(limite / (1024 * 1024))} MB.`);
  }
  const nombre = `${crypto.randomUUID()}${extension}`;
  const clave = `uploads/${carpeta}/${nombre}`;
  await env.ARCHIVOS.put(clave, await archivo.arrayBuffer(), {
    httpMetadata: { contentType: archivo.type || 'application/octet-stream' },
  });
  return { nombre, ruta: `/${clave}` };
}

export async function borrarArchivo(env, ruta) {
  if (!env.ARCHIVOS || !ruta) return;
  await env.ARCHIVOS.delete(String(ruta).replace(/^\//, ''));
}

export async function leerArchivo(env, ruta) {
  if (!env.ARCHIVOS) return null;
  const clave = String(ruta || '').replace(/^\//, '');
  const objeto = await env.ARCHIVOS.get(clave);
  if (!objeto) return null;
  return new Response(objeto.body, {
    headers: {
      'Content-Type': objeto.httpMetadata?.contentType || 'application/octet-stream',
      'Cache-Control': 'private, max-age=3600',
    },
  });
}

export async function enviarCorreo(env, { para, asunto, texto, html }) {
  if (!env.RESEND_API_KEY || !env.CORREO_DESDE) {
    return { enviado: false, motivo: 'sin_configurar' };
  }
  if (!para || !String(para).includes('@')) {
    return { enviado: false, motivo: 'sin_destinatario' };
  }
  let respuesta;
  try {
    respuesta = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: env.CORREO_DESDE,
        to: para,
        subject: asunto,
        text: texto,
        ...(html ? { html } : {}),
        ...(env.CORREO_RESPUESTA ? { reply_to: env.CORREO_RESPUESTA } : {}),
      }),
    });
  } catch {
    return { enviado: false, motivo: 'rechazado' };
  }
  if (!respuesta.ok) return { enviado: false, motivo: 'rechazado' };
  return { enviado: true, motivo: 'enviado' };
}

export const RASGOS = [
  'nivel_energia', 'sociabilidad_personas', 'sociabilidad_mascotas', 'independencia',
  'nivel_juego', 'carino', 'proteccion', 'tolerancia_soledad', 'adaptabilidad',
];

export function edadSql(alias = 'm') {
  const fecha = `${alias}.fecha_nacimiento`;
  return `CASE
    WHEN ${fecha} IS NULL OR ${fecha} = '' THEN ${alias}.edad
    WHEN CAST((julianday('now') - julianday(${fecha})) / 365.25 AS INTEGER) < 1
      THEN CAST((julianday('now') - julianday(${fecha})) / 30.44 AS INTEGER)
    ELSE CAST((julianday('now') - julianday(${fecha})) / 365.25 AS INTEGER)
  END`;
}

export function unidadEdadSql(alias = 'm') {
  const fecha = `${alias}.fecha_nacimiento`;
  return `CASE
    WHEN ${fecha} IS NULL OR ${fecha} = '' THEN ${alias}.unidad_edad
    WHEN CAST((julianday('now') - julianday(${fecha})) / 365.25 AS INTEGER) < 1 THEN 'meses'
    ELSE 'anos'
  END`;
}
