import bcrypt from 'bcryptjs';
import {
  json, errorJson, cuerpo, bool, esAdmin, exigirUsuario, exigirAdmin, exigirSuper,
  cookieSesion, cookieVacia, abrirSesion, revocarSesion, revocarSesionesDeUsuario, revocarOtrasSesiones, guardarArchivo, borrarArchivo, leerArchivo,
  enviarCorreo, RASGOS, edadSql, unidadEdadSql,
} from './http.js';
import { interpretarPersonalidad } from './personalidad_ia.js';
import { turnoLuna } from './luna.js';
import * as correos from './correos.js';

const PREGUNTAS = [
  ['nivel_energia', 'Nivel de energía', '¿Qué tan activo/a te consideras en tu día a día?'],
  ['sociabilidad_personas', 'Sociabilidad con personas', '¿Qué tan cómodo/a te sientes rodeado/a de nuevas personas?'],
  ['sociabilidad_mascotas', 'Sociabilidad con mascotas', '¿Qué tan bien te llevas con otras mascotas o animales?'],
  ['independencia', 'Independencia', '¿Prefieres pasar tiempo a solas realizando tus actividades?'],
  ['nivel_juego', 'Nivel de juego', '¿Qué tanto disfrutas dedicar tiempo a actividades recreativas o juegos?'],
  ['carino', 'Cariño', '¿Qué tan expresivo/a y afectuoso/a te consideras?'],
  ['proteccion', 'Protección', '¿Te consideras una persona protectora y atenta con quienes te rodean?'],
  ['tolerancia_soledad', 'Tolerancia a la soledad', '¿Qué tan bien toleras pasar varias horas fuera de casa?'],
  ['adaptabilidad', 'Adaptabilidad', '¿Qué tan fácil te adaptas a cambios en tu rutina diaria?'],
];

const SELECT_MASCOTA = `
  SELECT m.id_mascota, m.nombre, m.especie, m.raza,
         ${edadSql('m')} AS edad, ${unidadEdadSql('m')} AS unidad_edad, m.sexo,
         m.tamano, m.descripcion, m.esterilizado, m.vacunas, m.fotos,
         m.estado_adopcion, m.estado_apadrinamiento, m.personalidad_definida,
         COALESCE(m.estado_salud, '["No presenta necesidades veterinarias pendientes."]') AS estado_salud,
         m.detalle_salud,
         substr(m.fecha_ingreso, 1, 10) AS fecha_ingreso,
         substr(m.fecha_nacimiento, 1, 10) AS fecha_nacimiento,
         m.fecha_actualizacion, m.fecha_creacion,
         CASE WHEN m.fecha_creacion IS NOT NULL
               AND (julianday('now') - julianday(m.fecha_creacion)) <= 2
               AND (julianday('now') - julianday(m.fecha_creacion)) >= -0.084
              THEN 1 ELSE 0 END AS es_nuevo,
         (SELECT s.id_usuario FROM solicitudadopcion s
           WHERE s.id_mascota = m.id_mascota AND s.estado = 'aprobada'
           ORDER BY s.fecha_actualizacion_estado IS NULL, s.fecha_actualizacion_estado DESC
           LIMIT 1) AS id_usuario_adoptante,
         CASE WHEN pm.id_mascota IS NULL THEN '{}' ELSE json_object(
           'nivel_energia', pm.nivel_energia,
           'sociabilidad_personas', pm.sociabilidad_personas,
           'sociabilidad_mascotas', pm.sociabilidad_mascotas,
           'independencia', pm.independencia,
           'nivel_juego', pm.nivel_juego,
           'carino', pm.carino,
           'proteccion', pm.proteccion,
           'tolerancia_soledad', pm.tolerancia_soledad,
           'adaptabilidad', pm.adaptabilidad
         ) END AS personalidad
  FROM mascota m
  LEFT JOIN personalidadmascota pm ON pm.id_mascota = m.id_mascota`;

export async function despachar(request, env, url) {
  const ruta = url.pathname;
  const metodo = request.method;
  if (ruta.startsWith('/uploads/')) return servirPublico(env, ruta);
  const archivo = ruta.match(/^\/api\/archivos\/(seguimientos_adopcion|cancelaciones_adopcion|cancelaciones_apadrinamiento|adopciones|apadrinamientos|contratos|denuncias)\/([^/]+)$/);
  if (archivo && metodo === 'GET') return archivoPrivado(request, env, archivo[1], archivo[2]);

  if (ruta === '/api/usuarios/registro' && metodo === 'POST') return registrar(request, env);
  if (ruta === '/api/usuarios/login' && metodo === 'POST') return iniciarSesion(request, env);
  if (ruta === '/api/usuarios/logout' && metodo === 'POST') return cerrarSesion(request, env);
  if (ruta === '/api/usuarios/sesion' && metodo === 'GET') return sesion(request, env);
  if (ruta === '/api/usuarios/olvide-contrasena' && metodo === 'POST') return olvide(request, env);
  if (ruta === '/api/usuarios/verificar-codigo-recuperacion' && metodo === 'POST') return verificarCodigo(request, env);
  if (ruta === '/api/usuarios/restablecer-contrasena' && metodo === 'POST') return restablecer(request, env);
  if (ruta === '/api/usuarios/foto' && metodo === 'POST') return subirFotoUsuario(request, env);
  if (ruta === '/api/usuarios/voces-asistente' && metodo === 'GET') return voces();
  if (ruta === '/api/usuarios/personalidad/preguntas' && metodo === 'GET') return preguntas(request, env);

  let match = ruta.match(/^\/api\/usuarios\/([^/]+)\/personalidad\/entrevista\/([^/]+)$/);
  if (match && metodo === 'DELETE') return borrarRespuestaEntrevista(request, env, match[1], match[2]);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)\/personalidad\/entrevista$/);
  if (match && metodo === 'GET') return entrevista(request, env, match[1]);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)\/personalidad\/interpretar$/);
  if (match && metodo === 'POST') return interpretar(request, env, match[1]);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)\/personalidad\/transcribir$/);
  if (match && metodo === 'POST') return transcribir(request, env, match[1]);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)\/personalidad$/);
  if (match && metodo === 'GET') return obtenerPersonalidad(env, match[1]);
  if (match && (metodo === 'POST' || metodo === 'PUT')) return guardarPersonalidad(request, env, match[1], metodo);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)\/match-sincronizar$/);
  if (match && metodo === 'GET') return sincronizarMatch(env, match[1]);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)\/match-reasignacion\/vista$/);
  if (match && metodo === 'PATCH') return marcarReasignacion(env, match[1]);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)\/notificaciones-match\/leer$/);
  if (match && metodo === 'PATCH') return leerNotificacionesMatch(request, env, match[1]);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)\/voz-asistente\/(probar|hablar)$/);
  if (match && metodo === 'POST') return hablar(request, env, match[1]);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)\/voz-asistente$/);
  if (match && metodo === 'GET') return obtenerVoz(env, match[1]);
  if (match && metodo === 'PUT') return guardarVoz(request, env, match[1]);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)\/contrasena$/);
  if (match && metodo === 'PUT') return cambiarClave(request, env, match[1]);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)\/correo$/);
  if (match && metodo === 'PATCH') return cambiarCorreo(request, env, match[1]);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)\/puede-eliminar$/);
  if (match && metodo === 'GET') return puedeEliminar(request, env, match[1]);
  match = ruta.match(/^\/api\/usuarios\/([^/]+)$/);
  if (match && metodo === 'GET') return perfil(env, match[1]);
  if (match && metodo === 'PUT') return actualizarPerfil(request, env, match[1]);
  if (match && metodo === 'DELETE') return eliminarCuenta(request, env, match[1]);

  if (ruta === '/api/admin/usuarios/roles' && metodo === 'GET') return rolesActivos(request, env);
  if (ruta === '/api/admin/usuarios/administradores' && metodo === 'POST') return crearAdmin(request, env);
  match = ruta.match(/^\/api\/admin\/usuarios\/administradores\/([^/]+)$/);
  if (match && metodo === 'PUT') return editarAdmin(request, env, match[1]);
  if (match && metodo === 'DELETE') return borrarAdmin(request, env, match[1]);
  match = ruta.match(/^\/api\/admin\/usuarios\/([^/]+)\/estado$/);
  if (match && metodo === 'PATCH') return estadoCuenta(request, env, match[1]);
  if (ruta === '/api/admin/usuarios' && metodo === 'GET') return listarUsuarios(request, env);

  if (ruta === '/api/mascotas/borradores' && metodo === 'GET') return listarBorradores(request, env);
  if (ruta === '/api/mascotas/borrador' && metodo === 'GET') return unBorrador(request, env);
  if (ruta === '/api/mascotas/borrador' && metodo === 'PUT') return guardarBorrador(request, env);
  if (ruta === '/api/mascotas/borrador' && metodo === 'DELETE') return borrarBorrador(request, env);
  match = ruta.match(/^\/api\/mascotas\/borradores\/([^/]+)$/);
  if (match && metodo === 'DELETE') return borrarBorrador(request, env, match[1]);
  if (ruta === '/api/mascotas/entrevista-luna' && metodo === 'POST') return luna(request, env);
  if (ruta === '/api/mascotas/entrevista-luna/borrador' && metodo === 'PUT') return guardarBorrador(request, env);
  if (ruta === '/api/mascotas/entrevista-luna/borrador' && metodo === 'DELETE') return borrarBorrador(request, env);
  if (ruta === '/api/mascotas/foto' && metodo === 'POST') return subirFoto(request, env, 'mascotas', true);
  if (ruta === '/api/mascotas' && metodo === 'GET') return listarMascotas(env, url);
  if (ruta === '/api/mascotas' && metodo === 'POST') return crearMascota(request, env);
  match = ruta.match(/^\/api\/mascotas\/([^/]+)$/);
  if (match && metodo === 'GET') return unaMascota(env, match[1]);
  if (match && metodo === 'PUT') return editarMascota(request, env, match[1]);
  if (match && metodo === 'DELETE') return borrarMascota(request, env, match[1]);

  if (ruta === '/api/fundacion' && metodo === 'GET') return fundacion(env);
  if (ruta === '/api/fundacion' && metodo === 'PUT') return guardarFundacion(request, env);
  if (ruta === '/api/fundacion/imagen' && metodo === 'POST') return subirFoto(request, env, 'fundacion', true);

  if (ruta === '/api/noticias/foto' && metodo === 'POST') return subirFoto(request, env, 'noticias', true);
  if (ruta === '/api/noticias' && metodo === 'GET') return listarNoticias(request, env);
  if (ruta === '/api/noticias' && metodo === 'POST') return crearNoticia(request, env);
  match = ruta.match(/^\/api\/noticias\/([^/]+)\/like$/);
  if (match && metodo === 'POST') return likeNoticia(request, env, match[1]);
  match = ruta.match(/^\/api\/noticias\/([^/]+)$/);
  if (match && metodo === 'GET') return unaNoticia(request, env, match[1]);
  if (match && metodo === 'PUT') return editarNoticia(request, env, match[1]);
  if (match && metodo === 'DELETE') return borrarNoticia(request, env, match[1]);

  if (ruta === '/api/adoption-requests/notificaciones/resumen' && metodo === 'GET') return resumenAdopcion(request, env);
  if (ruta === '/api/adoption-requests/notificaciones/marcar-admin' && metodo === 'PUT') return marcarLeido(request, env, 'solicitudadopcion', 'leido_admin', true);
  if (ruta === '/api/adoption-requests/notificaciones/marcar-usuario' && metodo === 'PUT') return marcarLeido(request, env, 'solicitudadopcion', 'leido_usuario', false);
  if (ruta === '/api/adoption-requests/verificar-correo' && metodo === 'GET') return verificarSolicitud(env, url, 'solicitudadopcion', 'id_solicitud_adopcion');
  if (ruta === '/api/adoption-requests' && metodo === 'GET') return listarAdopciones(request, env, url);
  if (ruta === '/api/adoption-requests' && metodo === 'POST') return crearAdopcion(request, env);
  match = ruta.match(/^\/api\/adoption-requests\/([^/]+)\/(id-card|utility-bill|contrato)$/);
  if (match && metodo === 'GET') return archivoSolicitud(request, env, 'solicitudadopcion', 'id_solicitud_adopcion', match[1], match[2]);
  match = ruta.match(/^\/api\/adoption-requests\/([^/]+)\/status$/);
  if (match && metodo === 'PUT') return estadoAdopcion(request, env, match[1]);
  match = ruta.match(/^\/api\/adoption-requests\/([^/]+)\/contrato$/);
  if (match && metodo === 'POST') return subirContrato(request, env, 'solicitudadopcion', 'id_solicitud_adopcion', 'contrato_adopcion_archivo', match[1]);
  if (match && metodo === 'DELETE') return quitarContrato(request, env, 'solicitudadopcion', 'id_solicitud_adopcion', 'contrato_adopcion_archivo', match[1]);
  match = ruta.match(/^\/api\/adoption-requests\/([^/]+)\/contrato\/eliminar$/);
  if (match && metodo === 'POST') return quitarContrato(request, env, 'solicitudadopcion', 'id_solicitud_adopcion', 'contrato_adopcion_archivo', match[1]);
  match = ruta.match(/^\/api\/adoption-requests\/([^/]+)\/reenviar-verificacion$/);
  if (match && metodo === 'POST') return reenviar(request, env, 'solicitudadopcion', 'id_solicitud_adopcion', match[1]);

  if (ruta === '/api/solicitudes-apadrinamiento/notificaciones/resumen' && metodo === 'GET') return resumenApadrinamiento(request, env);
  if (ruta === '/api/solicitudes-apadrinamiento/notificaciones/marcar-admin' && metodo === 'PUT') return marcarLeido(request, env, 'solicitudapadrinamiento', 'leido_admin', true);
  if (ruta === '/api/solicitudes-apadrinamiento/notificaciones/marcar-usuario' && metodo === 'PUT') return marcarLeido(request, env, 'solicitudapadrinamiento', 'leido_usuario', false);
  if (ruta === '/api/solicitudes-apadrinamiento/verificar-correo' && metodo === 'GET') return verificarSolicitud(env, url, 'solicitudapadrinamiento', 'id_solicitud_apadrinamiento');
  if (ruta === '/api/solicitudes-apadrinamiento' && metodo === 'GET') return listarApadrinamientos(request, env, url);
  if (ruta === '/api/solicitudes-apadrinamiento' && metodo === 'POST') return crearApadrinamiento(request, env);
  match = ruta.match(/^\/api\/solicitudes-apadrinamiento\/([^/]+)\/(documento|contrato)$/);
  if (match && metodo === 'GET') return archivoSolicitud(request, env, 'solicitudapadrinamiento', 'id_solicitud_apadrinamiento', match[1], match[2]);
  match = ruta.match(/^\/api\/solicitudes-apadrinamiento\/([^/]+)\/estado$/);
  if (match && metodo === 'PUT') return estadoApadrinamiento(request, env, match[1]);
  match = ruta.match(/^\/api\/solicitudes-apadrinamiento\/([^/]+)\/contrato$/);
  if (match && metodo === 'POST') return subirContrato(request, env, 'solicitudapadrinamiento', 'id_solicitud_apadrinamiento', 'contrato_apadrinamiento_archivo', match[1]);
  if (match && metodo === 'DELETE') return quitarContrato(request, env, 'solicitudapadrinamiento', 'id_solicitud_apadrinamiento', 'contrato_apadrinamiento_archivo', match[1]);
  match = ruta.match(/^\/api\/solicitudes-apadrinamiento\/([^/]+)\/contrato\/eliminar$/);
  if (match && metodo === 'POST') return quitarContrato(request, env, 'solicitudapadrinamiento', 'id_solicitud_apadrinamiento', 'contrato_apadrinamiento_archivo', match[1]);
  match = ruta.match(/^\/api\/solicitudes-apadrinamiento\/([^/]+)\/reenviar-verificacion$/);
  if (match && metodo === 'POST') return reenviar(request, env, 'solicitudapadrinamiento', 'id_solicitud_apadrinamiento', match[1]);

  if (ruta === '/api/seguimiento-adopcion/activos' && metodo === 'GET') return seguimientosActivos(request, env, 'adopcion');
  if (ruta === '/api/seguimiento-adopcion/calendario' && metodo === 'GET') return calendario(request, env, 'adopcion');
  if (ruta === '/api/seguimiento-adopcion' && metodo === 'POST') return crearSeguimiento(request, env, 'adopcion');
  match = ruta.match(/^\/api\/seguimiento-adopcion\/historial\/([^/]+)$/);
  if (match && metodo === 'GET') return historialSeguimiento(request, env, 'adopcion', match[1]);
  match = ruta.match(/^\/api\/seguimiento-adopcion\/([^/]+)\/cancelacion$/);
  if (match && metodo === 'GET') return verCancelacion(request, env, match[1]);
  match = ruta.match(/^\/api\/seguimiento-adopcion\/([^/]+)\/cancelar$/);
  if (match && metodo === 'POST') return cancelarAdopcion(request, env, match[1]);

  if (ruta === '/api/seguimiento-apadrinamiento/activos' && metodo === 'GET') return seguimientosActivos(request, env, 'apadrinamiento');
  if (ruta === '/api/seguimiento-apadrinamiento/calendario' && metodo === 'GET') return calendario(request, env, 'apadrinamiento');
  if (ruta === '/api/seguimiento-apadrinamiento' && metodo === 'POST') return crearSeguimiento(request, env, 'apadrinamiento');
  if (ruta === '/api/seguimiento-apadrinamiento/cancelar' && metodo === 'POST') return cancelarApadrinamiento(request, env);
  if (ruta === '/api/seguimiento-apadrinamiento/evaluar' && metodo === 'POST') return evaluarCiclo(request, env);
  match = ruta.match(/^\/api\/seguimiento-apadrinamiento\/historial\/([^/]+)$/);
  if (match && metodo === 'GET') return historialSeguimiento(request, env, 'apadrinamiento', match[1]);
  match = ruta.match(/^\/api\/seguimiento-apadrinamiento\/padrino\/([^/]+)\/resumen$/);
  if (match && metodo === 'GET') return resumenPadrino(env, match[1]);
  match = ruta.match(/^\/api\/seguimiento-apadrinamiento\/reporte-visto\/([^/]+)$/);
  if (match && metodo === 'PUT') return reporteVisto(request, env, match[1]);
  match = ruta.match(/^\/api\/seguimiento-apadrinamiento\/([^/]+)\/finalizar$/);
  if (match && metodo === 'POST') return finalizarApadrinamiento(request, env, match[1]);

  if (ruta === '/api/denuncias/conteo-pendientes' && metodo === 'GET') return conteoDenuncias(request, env);
  if (ruta === '/api/denuncias' && metodo === 'GET') return listarDenuncias(request, env, url);
  if (ruta === '/api/denuncias' && metodo === 'POST') return crearDenuncia(request, env);
  match = ruta.match(/^\/api\/denuncias\/([^/]+)\/archivos\/([^/]+)$/);
  if (match && metodo === 'GET') return archivoDenuncia(request, env, match[1], match[2]);
  match = ruta.match(/^\/api\/denuncias\/([^/]+)\/estado$/);
  if (match && metodo === 'PUT') return estadoDenuncia(request, env, match[1]);
  match = ruta.match(/^\/api\/denuncias\/([^/]+)\/reintentar-correo$/);
  if (match && metodo === 'POST') return reintentarDenuncia(request, env, match[1]);
  match = ruta.match(/^\/api\/denuncias\/([^/]+)$/);
  if (match && metodo === 'GET') return unaDenuncia(request, env, match[1]);

  return json({ error: 'Ruta no encontrada' }, 404);
}

async function registrar(request, env) {
  const body = await cuerpo(request);
  const { nombres, apellidos, correo, telefono, contrasena, fecha_nacimiento, genero } = body;
  if (!nombres || !apellidos || !correo || !contrasena) return json({ error: 'Faltan campos obligatorios' }, 400);
  const pass = String(contrasena);
  if (pass.length < 8 || !/[A-Z]/.test(pass) || !/[a-z]/.test(pass) || !/[0-9]/.test(pass) || !/[@#$%&*]/.test(pass)) {
    return json({ error: 'La contraseña debe tener mínimo 8 caracteres, al menos una mayúscula (A-Z), una minúscula (a-z), un número (0-9) y un carácter especial (@, #, $, %, &, *).' }, 400);
  }
  if (genero !== 'Hombre' && genero !== 'Mujer') return json({ error: 'Selecciona si eres Hombre o Mujer' }, 400);
  const existe = await env.DB.prepare('SELECT id_usuario FROM usuario WHERE correo = ?').bind(correo).first();
  if (existe) return json({ error: 'Ese correo ya está registrado' }, 409);
  const creado = await env.DB.prepare(
    `INSERT INTO usuario (nombres, apellidos, correo, telefono, fecha_nacimiento, genero, contrasena_hash, rol)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'usuario')
     RETURNING id_usuario, nombres, apellidos, correo, telefono, fecha_nacimiento, genero, rol, fecha_registro`
  ).bind(nombres, apellidos, correo, telefono || null, fecha_nacimiento || null, genero, bcrypt.hashSync(pass, 10)).first();
  return json(creado, 201);
}

async function iniciarSesion(request, env) {
  const body = await cuerpo(request);
  if (!body.correo || !body.contrasena) return json({ error: 'Correo y contraseña son obligatorios' }, 400);
  const usuario = await env.DB.prepare(
    `SELECT id_usuario, nombres, apellidos, correo, telefono, documento_identidad, genero, rol, estado_cuenta, contrasena_hash
     FROM usuario WHERE correo = ?`
  ).bind(body.correo).first();
  if (!usuario || !bcrypt.compareSync(String(body.contrasena), usuario.contrasena_hash)) {
    return json({ error: 'Correo o contraseña incorrectos' }, 401);
  }
  if (usuario.estado_cuenta !== 'activo') return json({ error: 'Tu cuenta está inactiva. Comunícate con la Fundación.' }, 403);
  const recordar = body.recordar === true || body.recordar === 1 || body.recordar === 'true';
  const sesionAbierta = await abrirSesion(env, usuario.id_usuario, recordar);
  delete usuario.contrasena_hash;
  delete usuario.estado_cuenta;
  if (request.headers.get('X-Paw-Client') === 'native') usuario.sesion = sesionAbierta.token;
  return json(usuario, 200, { 'Set-Cookie': cookieSesion(sesionAbierta.token, request, sesionAbierta.segundos) });
}

async function cerrarSesion(request, env) {
  await revocarSesion(request, env);
  return json({ ok: true }, 200, { 'Set-Cookie': cookieVacia(request) });
}

async function sesion(request, env) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  const { contrasena_hash, estado_cuenta, bloqueado_apadrinar, ...publico } = acceso.usuario;
  return json(publico);
}

async function olvide(request, env) {
  const body = await cuerpo(request);
  const correo = String(body.correo || '').trim().toLowerCase();
  if (!correo.includes('@')) return json({ error: 'Ingresa un correo electrónico válido.' }, 400);
  if (!env.RESEND_API_KEY || !env.CORREO_DESDE) {
    return json({ error: 'El correo no está configurado en el servidor.', correo_enviado: false }, 503);
  }
  const generica = (enviado) => json({
    mensaje: enviado
      ? 'Si el correo está registrado, te enviamos un código de verificación.'
      : 'Si el correo está registrado, el código queda pendiente porque el envío no se completó.',
    correo_enviado: enviado,
  });
  const usuario = await env.DB.prepare(
    `SELECT id_usuario, nombres FROM usuario WHERE lower(trim(correo)) = ? AND estado_cuenta = 'activo'`
  ).bind(correo).first();
  if (!usuario) return generica(false);
  const codigo = String(Math.floor(1000 + Math.random() * 9000));
  const plantilla = correos.recuperacion({ nombre: usuario.nombres, codigo });
  const envio = await enviarCorreo(env, { para: correo, ...plantilla });
  if (!envio.enviado) return generica(false);
  await env.DB.prepare(
    `UPDATE usuario SET token_recuperacion = ?, token_recuperacion_expira = datetime('now', '+15 minutes') WHERE id_usuario = ?`
  ).bind(codigo, usuario.id_usuario).run();
  return generica(true);
}

async function verificarCodigo(request, env) {
  const body = await cuerpo(request);
  const ok = await codigoValido(env, body.correo, body.codigo);
  if (!ok) return json({ error: 'El código ingresado es incorrecto.' }, 400);
  return json({ ok: true });
}

async function restablecer(request, env) {
  const body = await cuerpo(request);
  const usuario = await codigoValido(env, body.correo, body.codigo);
  if (!usuario) return json({ error: 'El código ingresado es incorrecto.' }, 400);
  const pass = String(body.contrasena || '');
  if (pass.length < 8) return json({ error: 'La contraseña debe tener al menos 8 caracteres' }, 400);
  await env.DB.prepare(
    `UPDATE usuario SET contrasena_hash = ?, token_recuperacion = NULL, token_recuperacion_expira = NULL WHERE id_usuario = ?`
  ).bind(bcrypt.hashSync(pass, 10), usuario.id_usuario).run();
  await revocarSesionesDeUsuario(env, usuario.id_usuario);
  return json({ mensaje: 'Contraseña actualizada' });
}

async function codigoValido(env, correo, codigo) {
  const usuario = await env.DB.prepare(
    `SELECT id_usuario FROM usuario
     WHERE lower(trim(correo)) = lower(trim(?))
       AND token_recuperacion = ?
       AND token_recuperacion_expira >= datetime('now')`
  ).bind(correo || '', String(codigo || '')).first();
  return usuario;
}

async function perfil(env, id) {
  const fila = await env.DB.prepare(
    `SELECT id_usuario, nombres, apellidos, correo, telefono, direccion, documento_identidad, fecha_nacimiento, foto_perfil, genero, rol, voz_asistente
     FROM usuario WHERE id_usuario = ?`
  ).bind(id).first();
  if (!fila) return json({ error: 'Usuario no encontrado' }, 404);
  return json(fila);
}

async function actualizarPerfil(request, env, id) {
  const acceso = await exigirPropio(request, env, id);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  if (!body.nombres || !body.apellidos || !body.correo) return json({ error: 'Nombres, apellidos y correo son obligatorios' }, 400);
  const repetido = await env.DB.prepare('SELECT id_usuario FROM usuario WHERE correo = ? AND id_usuario <> ?').bind(body.correo, id).first();
  if (repetido) return json({ error: 'Ese correo ya está registrado' }, 409);
  const genero = body.genero === 'Hombre' || body.genero === 'Mujer' ? body.genero : null;
  const fila = await env.DB.prepare(
    `UPDATE usuario SET nombres = ?, apellidos = ?, correo = ?, telefono = ?, direccion = ?,
       documento_identidad = ?, fecha_nacimiento = ?, foto_perfil = ?,
       genero = COALESCE(?, genero)
     WHERE id_usuario = ?
     RETURNING id_usuario, nombres, apellidos, correo, telefono, direccion, documento_identidad, fecha_nacimiento, foto_perfil, genero`
  ).bind(body.nombres, body.apellidos, body.correo, body.telefono || null, body.direccion || null, body.documento_identidad || null, body.fecha_nacimiento || null, body.foto_perfil || null, genero, id).first();
  return json(fila);
}

async function cambiarClave(request, env, id) {
  const acceso = await exigirPropio(request, env, id);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  if (!body.contrasena || String(body.contrasena).length < 6) return json({ error: 'La contraseña debe tener al menos 6 caracteres' }, 400);
  const fila = await env.DB.prepare('UPDATE usuario SET contrasena_hash = ? WHERE id_usuario = ? RETURNING id_usuario').bind(bcrypt.hashSync(String(body.contrasena), 10), id).first();
  await revocarOtrasSesiones(request, env, id);
  if (!fila) return json({ error: 'Usuario no encontrado' }, 404);
  return json({ mensaje: 'Contraseña actualizada' });
}

async function cambiarCorreo(request, env, id) {
  const acceso = await exigirPropio(request, env, id);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  const correo = String(body.correo || '').trim().toLowerCase();
  if (!correo.includes('@') || !correo.includes('.')) return json({ error: 'Debes proporcionar un correo electrónico válido' }, 400);
  const repetido = await env.DB.prepare('SELECT id_usuario FROM usuario WHERE lower(correo) = ? AND id_usuario <> ?').bind(correo, id).first();
  if (repetido) return json({ error: 'Ese correo ya está registrado en otra cuenta' }, 409);
  const fila = await env.DB.prepare('UPDATE usuario SET correo = ? WHERE id_usuario = ? RETURNING id_usuario, correo, nombres, apellidos').bind(correo, id).first();
  return json({ mensaje: 'Correo actualizado exitosamente', usuario: fila });
}

async function puedeEliminar(request, env, id) {
  const acceso = await exigirPropio(request, env, id);
  if (acceso.error) return acceso.error;
  if (esAdmin(acceso.usuario.rol)) return json({ error: 'Los administradores y el superadministrador no pueden eliminar su cuenta desde el perfil' }, 403);
  const bloqueo = await asociaciones(env, id);
  if (bloqueo) return json({ puede: false, error: bloqueo });
  return json({ puede: true });
}

async function eliminarCuenta(request, env, id) {
  const revision = await puedeEliminar(request, env, id);
  if (revision.status !== 200) return revision;
  const datos = await revision.json();
  if (datos.puede === false) return json({ error: datos.error }, 409);
  await env.DB.batch([
    env.DB.prepare(`DELETE FROM seguimientoadopcion WHERE id_solicitud_adopcion IN (SELECT id_solicitud_adopcion FROM solicitudadopcion WHERE id_usuario = ? AND lower(trim(estado)) = 'rechazada')`).bind(id),
    env.DB.prepare(`DELETE FROM seguimientoapadrinamiento WHERE id_solicitud_apadrinamiento IN (SELECT id_solicitud_apadrinamiento FROM solicitudapadrinamiento WHERE id_usuario = ? AND lower(trim(estado)) = 'rechazada')`).bind(id),
    env.DB.prepare(`DELETE FROM solicitudadopcion WHERE id_usuario = ? AND lower(trim(estado)) = 'rechazada'`).bind(id),
    env.DB.prepare(`DELETE FROM solicitudapadrinamiento WHERE id_usuario = ? AND lower(trim(estado)) = 'rechazada'`).bind(id),
    env.DB.prepare('DELETE FROM notificacion_match_usuario WHERE id_usuario = ?').bind(id),
    env.DB.prepare('DELETE FROM respuestausuario WHERE id_usuario = ?').bind(id),
    env.DB.prepare('DELETE FROM valoracion_usuario WHERE id_usuario = ?').bind(id),
    env.DB.prepare('DELETE FROM personalidadusuario WHERE id_usuario = ?').bind(id),
    env.DB.prepare(`DELETE FROM usuario WHERE id_usuario = ? AND lower(trim(rol)) = 'usuario'`).bind(id),
  ]);
  return json({ ok: true });
}

async function asociaciones(env, id) {
  const filas = await env.DB.prepare(
    `SELECT 'adopción' AS tipo, lower(trim(estado)) AS estado, COUNT(*) AS total
     FROM solicitudadopcion WHERE id_usuario = ? AND lower(trim(estado)) <> 'rechazada' GROUP BY 2
     UNION ALL
     SELECT 'apadrinamiento', lower(trim(estado)), COUNT(*)
     FROM solicitudapadrinamiento WHERE id_usuario = ? AND lower(trim(estado)) <> 'rechazada' GROUP BY 2`
  ).bind(id, id).all();
  if (!filas.results.length) return null;
  return `No puedes eliminar tu cuenta porque tienes solicitudes o procesos activos. La cuenta debe permanecer mientras exista una adopción o un apadrinamiento realizado, o una solicitud en proceso.`;
}

async function listarUsuarios(request, env) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const url = new URL(request.url);
  const rol = url.searchParams.get('rol') || 'usuario';
  if (!['usuario', 'administrador'].includes(rol)) return json({ error: 'Rol no válido' }, 400);
  const q = url.searchParams.get('q');
  const condicion = rol === 'administrador' ? `u.rol IN ('administrador', 'superadmin')` : `u.rol = 'usuario'`;
  const filtro = q ? `AND (u.nombres LIKE ? COLLATE NOCASE OR u.apellidos LIKE ? COLLATE NOCASE OR u.correo LIKE ? COLLATE NOCASE)` : '';
  const params = q ? [`%${q}%`, `%${q}%`, `%${q}%`] : [];
  const consulta = env.DB.prepare(
    `SELECT u.id_usuario, u.nombres, u.apellidos, u.correo, u.telefono, u.documento_identidad, u.foto_perfil, u.rol, u.estado_cuenta, u.fecha_registro,
            v.comentarios AS motivo_inactivacion, v.fecha_valoracion AS fecha_inactivacion,
            trim(admin.nombres || ' ' || COALESCE(admin.apellidos, '')) AS administrador_inactivacion
     FROM usuario u
     LEFT JOIN valoracion_usuario v ON v.id_valoracion = (
       SELECT id_valoracion FROM valoracion_usuario WHERE id_usuario = u.id_usuario ORDER BY fecha_valoracion DESC LIMIT 1
     )
     LEFT JOIN usuario admin ON admin.id_usuario = v.id_administrador
     WHERE ${condicion} ${filtro}
     ORDER BY u.fecha_registro DESC`
  );
  const filas = await (params.length ? consulta.bind(...params) : consulta).all();
  return json(filas.results);
}

async function rolesActivos(request, env) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const filas = await env.DB.prepare(
    `SELECT DISTINCT id_usuario, 'adoptante' AS tipo FROM solicitudadopcion
     WHERE estado = 'aprobada' AND trim(COALESCE(contrato_adopcion_archivo, '')) <> ''
     UNION
     SELECT DISTINCT id_usuario, 'apadrinante' FROM solicitudapadrinamiento
     WHERE estado = 'aprobada' AND trim(COALESCE(contrato_apadrinamiento_archivo, '')) <> ''`
  ).all();
  const adoptantes = [];
  const apadrinantes = [];
  for (const fila of filas.results) {
    if (fila.tipo === 'adoptante') adoptantes.push(fila.id_usuario);
    else apadrinantes.push(fila.id_usuario);
  }
  return json({ adoptantes, apadrinantes });
}

async function estadoCuenta(request, env, id) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  if (!['activo', 'inactivo'].includes(body.estado_cuenta)) return json({ error: 'Estado no válido (activo o inactivo)' }, 400);
  const motivo = String(body.comentarios || '').trim();
  if (body.estado_cuenta === 'inactivo' && !motivo) return json({ error: 'Explica por qué inactivas la cuenta' }, 400);
  const actual = await env.DB.prepare('SELECT rol FROM usuario WHERE id_usuario = ?').bind(id).first();
  if (!actual) return json({ error: 'Usuario no encontrado' }, 404);
  if (actual.rol !== 'usuario') return json({ error: 'No se puede cambiar el estado de un administrador' }, 403);
  const usuario = await env.DB.prepare(
    `UPDATE usuario SET estado_cuenta = ? WHERE id_usuario = ?
     RETURNING id_usuario, nombres, apellidos, correo, telefono, documento_identidad, foto_perfil, rol, estado_cuenta, fecha_registro`
  ).bind(body.estado_cuenta, id).first();
  if (body.estado_cuenta === 'inactivo') {
    await env.DB.prepare('INSERT INTO valoracion_usuario (id_usuario, id_administrador, comentarios) VALUES (?, ?, ?)').bind(id, acceso.usuario.id_usuario, motivo).run();
    usuario.motivo_inactivacion = motivo;
  }
  return json(usuario);
}

async function crearAdmin(request, env) {
  const acceso = await exigirSuper(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  if (!body.nombres || !body.apellidos || !body.correo || !body.contrasena) return json({ error: 'Faltan campos obligatorios' }, 400);
  if (String(body.contrasena).length < 8) return json({ error: 'La contraseña debe tener al menos 8 caracteres' }, 400);
  const existe = await env.DB.prepare('SELECT 1 AS ok FROM usuario WHERE lower(correo) = lower(?)').bind(body.correo).first();
  if (existe) return json({ error: 'Ese correo ya está registrado' }, 409);
  const fila = await env.DB.prepare(
    `INSERT INTO usuario (nombres, apellidos, correo, telefono, contrasena_hash, rol)
     VALUES (?, ?, ?, ?, ?, 'administrador')
     RETURNING id_usuario, nombres, apellidos, correo, telefono, documento_identidad, foto_perfil, rol, estado_cuenta, fecha_registro`
  ).bind(String(body.nombres).trim(), String(body.apellidos).trim(), String(body.correo).trim(), body.telefono || null, bcrypt.hashSync(String(body.contrasena), 10)).first();
  return json(fila, 201);
}

async function editarAdmin(request, env, id) {
  const acceso = await exigirSuper(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  const actual = await env.DB.prepare(`SELECT rol FROM usuario WHERE id_usuario = ?`).bind(id).first();
  if (!actual || actual.rol !== 'administrador') return json({ error: 'Administrador no encontrado' }, 404);
  const repetido = await env.DB.prepare('SELECT 1 AS ok FROM usuario WHERE lower(correo) = lower(?) AND id_usuario <> ?').bind(body.correo, id).first();
  if (repetido) return json({ error: 'Ese correo ya está registrado' }, 409);
  if (body.contrasena) {
    return json(await env.DB.prepare(
      `UPDATE usuario SET nombres = ?, apellidos = ?, correo = ?, telefono = ?, contrasena_hash = ?
       WHERE id_usuario = ? AND rol = 'administrador'
       RETURNING id_usuario, nombres, apellidos, correo, telefono, documento_identidad, foto_perfil, rol, estado_cuenta, fecha_registro`
    ).bind(body.nombres, body.apellidos, body.correo, body.telefono || null, bcrypt.hashSync(String(body.contrasena), 10), id).first());
  }
  return json(await env.DB.prepare(
    `UPDATE usuario SET nombres = ?, apellidos = ?, correo = ?, telefono = ?
     WHERE id_usuario = ? AND rol = 'administrador'
     RETURNING id_usuario, nombres, apellidos, correo, telefono, documento_identidad, foto_perfil, rol, estado_cuenta, fecha_registro`
  ).bind(body.nombres, body.apellidos, body.correo, body.telefono || null, id).first());
}

async function borrarAdmin(request, env, id) {
  const acceso = await exigirSuper(request, env);
  if (acceso.error) return acceso.error;
  if (id === acceso.usuario.id_usuario) return json({ error: 'No puedes eliminar tu propia cuenta' }, 403);
  const fila = await env.DB.prepare(`DELETE FROM usuario WHERE id_usuario = ? AND rol = 'administrador' RETURNING id_usuario`).bind(id).first();
  if (!fila) return json({ error: 'Administrador no encontrado' }, 404);
  return json({ ok: true });
}

async function listarMascotas(env, url) {
  const estado = url.searchParams.get('estado');
  const consulta = estado
    ? env.DB.prepare(`${SELECT_MASCOTA} WHERE m.estado_adopcion = ? ORDER BY m.fecha_ingreso DESC, m.nombre`).bind(estado)
    : env.DB.prepare(`${SELECT_MASCOTA} ORDER BY m.fecha_ingreso DESC, m.nombre`);
  const filas = await consulta.all();
  return json(filas.results.map(normalizarMascota));
}

async function unaMascota(env, id) {
  const fila = await env.DB.prepare(`${SELECT_MASCOTA} WHERE m.id_mascota = ?`).bind(id).first();
  if (!fila) return json({ error: 'Mascota no encontrada' }, 404);
  return json(normalizarMascota(fila));
}

function normalizarMascota(fila) {
  if (typeof fila.personalidad === 'string') {
    try { fila.personalidad = JSON.parse(fila.personalidad); } catch { fila.personalidad = {}; }
  }
  if (typeof fila.estado_salud === 'string') {
    try { fila.estado_salud = JSON.parse(fila.estado_salud); } catch { /* texto plano */ }
  }
  fila.esterilizado = fila.esterilizado === 1;
  fila.vacunas = fila.vacunas === 1;
  fila.personalidad_definida = fila.personalidad_definida === 1;
  fila.es_nuevo = fila.es_nuevo === 1;
  return fila;
}

async function crearMascota(request, env) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  if (!body.nombre || !body.especie) return json({ error: 'Nombre y especie son obligatorios' }, 400);
  const id = crypto.randomUUID();
  await env.DB.prepare(
    `INSERT INTO mascota (
      id_mascota, nombre, especie, raza, edad, sexo, tamano, descripcion, esterilizado, vacunas, fotos,
      estado_adopcion, estado_apadrinamiento, id_administrador, unidad_edad, estado_salud, detalle_salud,
      fecha_nacimiento, personalidad_definida
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, 'disponible'), COALESCE(?, 'disponible'), ?, COALESCE(?, 'anos'), ?, ?, ?, ?)`
  ).bind(
    id, body.nombre, body.especie, body.raza || null, body.edad || null, body.sexo || null, body.tamano || null,
    body.descripcion || null, bool(body.esterilizado) ?? 0, bool(body.vacunas) ?? 0, body.fotos || null,
    body.estado_adopcion || null, body.estado_apadrinamiento || null, acceso.usuario.id_usuario,
    body.unidad_edad || null, typeof body.estado_salud === 'string' ? body.estado_salud : JSON.stringify(body.estado_salud || ['No presenta necesidades veterinarias pendientes.']),
    body.detalle_salud || null, body.fecha_nacimiento || null, bool(body.personalidad_definida) ?? 1
  ).run();
  await guardarRasgos(env, 'personalidadmascota', 'id_mascota', id, body.personalidad);
  return unaMascota(env, id);
}

async function editarMascota(request, env, id) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  const actual = await env.DB.prepare('SELECT id_mascota FROM mascota WHERE id_mascota = ?').bind(id).first();
  if (!actual) return json({ error: 'Mascota no encontrada' }, 404);
  await env.DB.prepare(
    `UPDATE mascota SET nombre = ?, especie = ?, raza = ?, edad = ?, sexo = ?, tamano = ?, descripcion = ?,
      esterilizado = ?, vacunas = ?, fotos = COALESCE(?, fotos), estado_adopcion = COALESCE(?, estado_adopcion),
      estado_apadrinamiento = COALESCE(?, estado_apadrinamiento), unidad_edad = COALESCE(?, unidad_edad),
      estado_salud = COALESCE(?, estado_salud), detalle_salud = ?, fecha_nacimiento = COALESCE(?, fecha_nacimiento),
      fecha_actualizacion = CURRENT_TIMESTAMP
     WHERE id_mascota = ?`
  ).bind(
    body.nombre, body.especie, body.raza || null, body.edad || null, body.sexo || null, body.tamano || null,
    body.descripcion || null, bool(body.esterilizado) ?? 0, bool(body.vacunas) ?? 0, body.fotos || null,
    body.estado_adopcion || null, body.estado_apadrinamiento || null, body.unidad_edad || null,
    body.estado_salud ? JSON.stringify(body.estado_salud) : null, body.detalle_salud || null, body.fecha_nacimiento || null, id
  ).run();
  if (body.personalidad) await guardarRasgos(env, 'personalidadmascota', 'id_mascota', id, body.personalidad);
  return unaMascota(env, id);
}

async function borrarMascota(request, env, id) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const actual = await env.DB.prepare('SELECT fotos FROM mascota WHERE id_mascota = ?').bind(id).first();
  if (!actual) return json({ error: 'Mascota no encontrada' }, 404);
  const fila = await env.DB.prepare('DELETE FROM mascota WHERE id_mascota = ? RETURNING id_mascota').bind(id).first();
  if (!fila) return json({ error: 'Mascota no encontrada' }, 404);
  for (const ruta of rutasDeFotos(actual.fotos)) await borrarArchivo(env, ruta);
  return json({ mensaje: 'Mascota eliminada' });
}

function rutasDeFotos(fotos) {
  if (!fotos) return [];
  if (Array.isArray(fotos)) return fotos.filter((ruta) => typeof ruta === 'string' && ruta.startsWith('/uploads/'));
  const texto = String(fotos);
  try {
    const parsed = JSON.parse(texto);
    if (Array.isArray(parsed)) return rutasDeFotos(parsed);
  } catch { /* una sola ruta */ }
  return texto.startsWith('/uploads/') ? [texto] : [];
}

async function guardarRasgos(env, tabla, columna, id, rasgos) {
  if (!rasgos || typeof rasgos === 'string') {
    try { rasgos = JSON.parse(rasgos); } catch { return; }
  }
  const valores = RASGOS.map((rasgo) => Number(rasgos[rasgo]));
  if (valores.some((valor) => !Number.isInteger(valor))) return;
  const existente = await env.DB.prepare(`SELECT 1 AS ok FROM ${tabla} WHERE ${columna} = ?`).bind(id).first();
  if (existente) {
    await env.DB.prepare(
      `UPDATE ${tabla} SET ${RASGOS.map((rasgo) => `${rasgo} = ?`).join(', ')}, fecha_actualizacion = CURRENT_TIMESTAMP WHERE ${columna} = ?`
    ).bind(...valores, id).run();
  } else {
    await env.DB.prepare(
      `INSERT INTO ${tabla} (${columna}, ${RASGOS.join(', ')}) VALUES (${['?'].concat(RASGOS.map(() => '?')).join(', ')})`
    ).bind(id, ...valores).run();
  }
}

async function listarBorradores(request, env) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const filas = await env.DB.prepare('SELECT * FROM borrador_mascota_formulario_ia ORDER BY fecha_actualizacion DESC').all();
  return json(filas.results);
}

async function unBorrador(request, env) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const fila = await env.DB.prepare('SELECT * FROM borrador_mascota_formulario_ia WHERE id_administrador = ?').bind(acceso.usuario.id_usuario).first();
  return json({ ok: true, borrador: fila || null });
}

async function guardarBorrador(request, env) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  const ficha = body.ficha || body;
  const personalidad = JSON.stringify(ficha.personalidad || {});
  const salud = JSON.stringify(ficha.estado_salud || []);
  const historial = JSON.stringify(body.historial || []);
  await env.DB.prepare(
    `INSERT INTO borrador_mascota_formulario_ia (
      id_administrador, nombre, especie, sexo, edad, unidad_edad, fecha_nacimiento, raza, tamano,
      personalidad, estado_salud, vacunas, esterilizado, detalle_salud, descripcion, paso_actual, historial_chat, foto
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT (id_administrador) DO UPDATE SET
      nombre = excluded.nombre, especie = excluded.especie, sexo = excluded.sexo, edad = excluded.edad,
      personalidad = excluded.personalidad, estado_salud = excluded.estado_salud, historial_chat = excluded.historial_chat,
      paso_actual = excluded.paso_actual, foto = excluded.foto, fecha_actualizacion = CURRENT_TIMESTAMP`
  ).bind(
    acceso.usuario.id_usuario, ficha.nombre || null, ficha.especie || null, ficha.sexo || null, ficha.edad || null,
    ficha.unidad_edad || null, ficha.fecha_nacimiento || null, ficha.raza || null, ficha.tamano || null,
    personalidad, salud, bool(ficha.vacunas), bool(ficha.esterilizado), ficha.detalle_salud || null,
    ficha.descripcion || null, body.paso_actual || 'nombre', historial, body.foto || ficha.foto || null
  ).run();
  return json({ ok: true, ficha, guardado_en_bd: true });
}

async function borrarBorrador(request, env, id) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  if (id) await env.DB.prepare('DELETE FROM borrador_mascota_formulario_ia WHERE id_borrador = ? OR id_administrador = ?').bind(id, acceso.usuario.id_usuario).run();
  else await env.DB.prepare('DELETE FROM borrador_mascota_formulario_ia WHERE id_administrador = ?').bind(acceso.usuario.id_usuario).run();
  return json({ ok: true, mensaje: 'Borrador eliminado correctamente' });
}

async function luna(request, env) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  const turno = await turnoLuna(env, {
    ficha: body.ficha || {},
    historial: body.historial || [],
    mensaje: body.mensaje || '',
    genero: acceso.usuario.genero,
    reiniciar: body.reiniciar === true || body.reiniciar === 1 || body.reiniciar === 'true',
  });
  if (turno.status !== 200) return json(turno.body, turno.status);
  const encabezados = new Headers(request.headers);
  encabezados.set('Content-Type', 'application/json');
  await guardarBorrador(new Request(request.url, {
    method: 'PUT',
    headers: encabezados,
    body: JSON.stringify({ ...turno.body.ficha, historial: turno.body.historial_guardado, paso_actual: turno.body.paso_actual }),
  }), env);
  return json(turno.body);
}

async function fundacion(env) {
  const fila = await env.DB.prepare('SELECT * FROM informacionfundacion LIMIT 1').first();
  if (!fila) return json({ error: 'Sin información de la fundación' }, 404);
  try { fila.redes_sociales = JSON.parse(fila.redes_sociales || '{}'); } catch { fila.redes_sociales = {}; }
  return json(fila);
}

async function guardarFundacion(request, env) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  if (!String(body.nombre || '').trim()) return json({ error: 'El nombre de la fundación es obligatorio' }, 400);
  const campos = ['nombre', 'descripcion', 'mision', 'vision', 'direccion', 'ciudad', 'telefono', 'correo', 'logo', 'imagen_principal', 'imagen_fondo', 'rescatista_nombre', 'rescatista_texto', 'rescatista_foto', 'mapa_url', 'ayuda_adopta_titulo', 'ayuda_adopta_texto', 'ayuda_apadrina_titulo', 'ayuda_apadrina_texto', 'contacto_texto'];
  const valores = campos.map((campo) => {
    const valor = body[campo];
    if (valor == null) return null;
    const texto = String(valor).trim();
    return texto || null;
  });
  const redes = {};
  for (const red of ['facebook', 'instagram', 'tiktok']) {
    const enlace = body.redes_sociales?.[red];
    if (!enlace) continue;
    if (!/^https?:\/\//i.test(enlace)) return json({ error: `El enlace de ${red} debe empezar con http:// o https://` }, 400);
    redes[red] = String(enlace).trim();
  }
  const fila = await env.DB.prepare(
    `UPDATE informacionfundacion SET ${campos.map((campo) => `${campo} = ?`).join(', ')}, redes_sociales = ?
     WHERE id_fundacion = (SELECT id_fundacion FROM informacionfundacion LIMIT 1)
     RETURNING *`
  ).bind(...valores, JSON.stringify(redes)).first();
  if (!fila) return json({ error: 'Sin información de la fundación' }, 404);
  fila.redes_sociales = redes;
  return json(fila);
}

function selectNoticia(conUsuario) {
  return `SELECT n.id_noticia, n.titulo, n.contenido, n.imagen, n.lugar,
      substr(n.fecha, 1, 10) AS fecha, n.fecha_creacion, n.id_administrador,
      (SELECT COUNT(*) FROM noticia_like nl WHERE nl.id_noticia = n.id_noticia) AS total_likes,
      ${conUsuario ? 'EXISTS(SELECT 1 FROM noticia_like nl WHERE nl.id_noticia = n.id_noticia AND nl.id_usuario = ?)' : '0'} AS dio_like
    FROM noticia n`;
}

async function listarNoticias(request, env) {
  const acceso = await exigirUsuario(request, env);
  const usuario = acceso.usuario;
  const consulta = usuario
    ? env.DB.prepare(`${selectNoticia(true)} ORDER BY n.fecha DESC, n.fecha_creacion DESC`).bind(usuario.id_usuario)
    : env.DB.prepare(`${selectNoticia(false)} ORDER BY n.fecha DESC, n.fecha_creacion DESC`);
  const filas = await consulta.all();
  return json(filas.results.map((fila) => ({ ...fila, dio_like: fila.dio_like === 1 })));
}

async function unaNoticia(request, env, id) {
  const acceso = await exigirUsuario(request, env);
  const fila = acceso.usuario
    ? await env.DB.prepare(`${selectNoticia(true)} WHERE n.id_noticia = ?`).bind(acceso.usuario.id_usuario, id).first()
    : await env.DB.prepare(`${selectNoticia(false)} WHERE n.id_noticia = ?`).bind(id).first();
  if (!fila) return json({ error: 'Noticia no encontrada' }, 404);
  fila.dio_like = fila.dio_like === 1;
  return json(fila);
}

async function crearNoticia(request, env) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  if (!String(body.titulo || '').trim()) return json({ error: 'El título es obligatorio' }, 400);
  if (!String(body.contenido || '').trim()) return json({ error: 'El contenido es obligatorio' }, 400);
  const id = crypto.randomUUID();
  await env.DB.prepare(
    `INSERT INTO noticia (id_noticia, titulo, contenido, imagen, fecha, lugar, id_administrador)
     VALUES (?, ?, ?, ?, COALESCE(?, CURRENT_DATE), ?, ?)`
  ).bind(id, body.titulo.trim(), body.contenido.trim(), body.imagen || null, body.fecha || null, body.lugar || 'Fundación Maritza Arévalo', acceso.usuario.id_usuario).run();
  return unaNoticia(request, env, id);
}

async function editarNoticia(request, env, id) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  const fila = await env.DB.prepare(
    `UPDATE noticia SET titulo = ?, contenido = ?, imagen = ?, fecha = COALESCE(?, fecha), lugar = COALESCE(?, lugar)
     WHERE id_noticia = ? RETURNING id_noticia`
  ).bind(body.titulo, body.contenido, body.imagen || null, body.fecha || null, body.lugar || null, id).first();
  if (!fila) return json({ error: 'Noticia no encontrada' }, 404);
  return unaNoticia(request, env, id);
}

async function borrarNoticia(request, env, id) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const fila = await env.DB.prepare('DELETE FROM noticia WHERE id_noticia = ? RETURNING id_noticia').bind(id).first();
  if (!fila) return json({ error: 'Noticia no encontrada' }, 404);
  return json({ mensaje: 'Noticia eliminada exitosamente' });
}

async function likeNoticia(request, env, id) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return json({ error: 'Debes iniciar sesión para dar Me gusta' }, 401);
  const existe = await env.DB.prepare('SELECT 1 AS ok FROM noticia_like WHERE id_noticia = ? AND id_usuario = ?').bind(id, acceso.usuario.id_usuario).first();
  if (existe) await env.DB.prepare('DELETE FROM noticia_like WHERE id_noticia = ? AND id_usuario = ?').bind(id, acceso.usuario.id_usuario).run();
  else await env.DB.prepare('INSERT INTO noticia_like (id_noticia, id_usuario) VALUES (?, ?)').bind(id, acceso.usuario.id_usuario).run();
  const total = await env.DB.prepare('SELECT COUNT(*) AS total_likes FROM noticia_like WHERE id_noticia = ?').bind(id).first();
  return json({ dio_like: !existe, total_likes: total.total_likes });
}

async function crearAdopcion(request, env) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  const form = await request.formData();
  const idMascota = String(form.get('id_mascota') || '').trim();
  const tipoVivienda = String(form.get('tipo_vivienda') || '').trim();
  const tiempo = String(form.get('tiempo_disponible') || '').trim();
  const informacion = String(form.get('informacion_adicional') || '').trim();
  const tienePatio = bool(form.get('tiene_patio'));
  const tieneNinos = bool(form.get('tiene_ninos'));
  const tieneMascotas = bool(form.get('tiene_mascotas'));
  const experiencia = bool(form.get('experiencia_previa'));
  if (!idMascota) return json({ error: 'Debes seleccionar una mascota' }, 400);
  if (!tipoVivienda || tienePatio === null || tieneNinos === null || tieneMascotas === null || experiencia === null || !tiempo) {
    return json({ error: 'Responde todas las preguntas del formulario' }, 400);
  }
  if (informacion.length < 20) return json({ error: 'Cuéntanos un poco más sobre por qué quieres adoptar (mínimo 20 caracteres)' }, 400);
  const cedula = form.get('foto_cedula');
  const recibo = form.get('foto_servicios_publicos');
  if (!(cedula instanceof File) || !(recibo instanceof File)) return json({ error: 'Debes adjuntar la foto de la cédula y la del recibo de servicio público' }, 400);
  const mascota = await env.DB.prepare('SELECT id_mascota, nombre, estado_adopcion FROM mascota WHERE id_mascota = ?').bind(idMascota).first();
  if (!mascota) return json({ error: 'La mascota seleccionada no existe' }, 404);
  if (mascota.estado_adopcion === 'adoptado') return json({ error: 'Esta mascota ya fue adoptada' }, 409);
  if (mascota.estado_adopcion === 'en_proceso') return json({ error: 'Esta mascota ya tiene un proceso de adopción en curso' }, 409);
  const existe = await env.DB.prepare(
    `SELECT estado FROM solicitudadopcion WHERE id_usuario = ? AND id_mascota = ? AND estado IN ('pendiente', 'aprobada')`
  ).bind(acceso.usuario.id_usuario, idMascota).first();
  if (existe) return json({ error: existe.estado === 'aprobada' ? 'Ya tienes una adopción aprobada para esta mascota' : 'Ya tienes una solicitud pendiente para esta mascota' }, 409);
  const fotoCedula = await guardarArchivo(env, 'adopciones', cedula);
  const fotoRecibo = await guardarArchivo(env, 'adopciones', recibo);
  const token = crypto.randomUUID();
  const correo = String(form.get('correo_contacto') || acceso.usuario.correo).trim();
  const creada = await env.DB.prepare(
    `INSERT INTO solicitudadopcion (
      id_usuario, id_mascota, tipo_vivienda, tiene_patio, tiene_ninos, tiene_mascotas, otras_mascotas,
      tiempo_disponible, experiencia_previa, informacion_adicional, foto_cedula, foto_servicios_publicos,
      estado, leido_admin, leido_usuario, correo_contacto, estado_correo, token_verificacion_correo, acepto_requisitos
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pendiente', 0, 1, ?, 'pendiente', ?, 1)
    RETURNING id_solicitud_adopcion`
  ).bind(
    acceso.usuario.id_usuario, idMascota, tipoVivienda, tienePatio, tieneNinos, tieneMascotas,
    tieneMascotas ? form.get('otras_mascotas') : null, tiempo, experiencia, informacion,
    fotoCedula.ruta, fotoRecibo.ruta, correo, token
  ).first();
  const plantilla = correos.verificacionSolicitud({
    nombre: `${acceso.usuario.nombres || ''} ${acceso.usuario.apellidos || ''}`.trim() || 'Usuario',
    mascota: mascota.nombre,
    token,
    tipo: 'adopcion',
    origen: new URL(request.url).origin,
  });
  const envio = await enviarCorreo(env, { para: correo, ...plantilla });
  return json({
    mensaje: 'Solicitud de adopción enviada exitosamente',
    id_solicitud_adopcion: creada.id_solicitud_adopcion,
    correo_enviado: envio.enviado,
  }, 201);
}

function verdad(valor) {
  return valor === true || valor === 1 || valor === '1' || valor === 'true';
}

function presentarAdopcion(fila) {
  const correoContacto = fila.correo_contacto && String(fila.correo_contacto).trim();
  return {
    ...fila,
    tiene_patio: fila.tiene_patio == null ? null : verdad(fila.tiene_patio),
    tiene_ninos: fila.tiene_ninos == null ? null : verdad(fila.tiene_ninos),
    tiene_mascotas: fila.tiene_mascotas == null ? null : verdad(fila.tiene_mascotas),
    experiencia_previa: fila.experiencia_previa == null ? null : verdad(fila.experiencia_previa),
    tiene_foto_cedula: !!(fila.foto_cedula && String(fila.foto_cedula).trim()),
    tiene_foto_recibo: !!(fila.foto_servicios_publicos && String(fila.foto_servicios_publicos).trim()),
    leido_admin: verdad(fila.leido_admin),
    leido_usuario: verdad(fila.leido_usuario),
    acepto_requisitos: fila.acepto_requisitos == null ? true : verdad(fila.acepto_requisitos),
    solicitante_nombres: fila.nombres || '',
    solicitante_apellidos: fila.apellidos || '',
    solicitante_correo: correoContacto || fila.correo_usuario || '',
    solicitante_telefono: fila.telefono || '',
    solicitante_direccion: fila.direccion || '',
    solicitante_cedula: fila.documento_identidad || '',
  };
}

function presentarApadrinamiento(fila) {
  const correoContacto = fila.correo_contacto && String(fila.correo_contacto).trim();
  return {
    ...fila,
    acuerdo_responsabilidad: verdad(fila.acuerdo_responsabilidad),
    leido_admin: verdad(fila.leido_admin),
    leido_usuario: verdad(fila.leido_usuario),
    acepto_requisitos: fila.acepto_requisitos == null ? true : verdad(fila.acepto_requisitos),
    solicitante_nombres: fila.nombres || '',
    solicitante_apellidos: fila.apellidos || '',
    solicitante_correo: correoContacto || fila.correo_usuario || '',
    solicitante_telefono: fila.telefono || '',
    solicitante_direccion: fila.direccion || '',
    solicitante_cedula: fila.documento_identidad || '',
  };
}

async function listarAdopciones(request, env, url) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  const propias = url.searchParams.get('mine') === 'true' || !esAdmin(acceso.usuario.rol);
  const estado = url.searchParams.get('status');
  const mascota = url.searchParams.get('pet_id');
  const filtros = [];
  const params = [];
  if (propias) { filtros.push('s.id_usuario = ?'); params.push(acceso.usuario.id_usuario); }
  if (estado) { filtros.push('s.estado = ?'); params.push(estado); }
  if (mascota) { filtros.push('s.id_mascota = ?'); params.push(mascota); }
  const where = filtros.length ? `WHERE ${filtros.join(' AND ')}` : '';
  const filas = await env.DB.prepare(
    `SELECT s.*, u.nombres, u.apellidos, u.correo AS correo_usuario, u.telefono, u.direccion, u.documento_identidad,
            m.nombre AS mascota_nombre, m.especie AS mascota_especie, m.raza AS mascota_raza, m.edad AS mascota_edad,
            m.fotos AS mascota_fotos, m.estado_adopcion AS mascota_estado_adopcion
     FROM solicitudadopcion s
     JOIN usuario u ON u.id_usuario = s.id_usuario
     JOIN mascota m ON m.id_mascota = s.id_mascota
     ${where}
     ORDER BY s.fecha_solicitud DESC`
  ).bind(...params).all();
  return json((filas.results || []).map(presentarAdopcion));
}

async function estadoAdopcion(request, env, id) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  if (!['aprobada', 'rechazada', 'cancelada', 'pendiente'].includes(body.estado)) return json({ error: 'Estado no válido' }, 400);
  const previa = await datosPersona(env, 'adopcion', id);
  if (!previa) return json({ error: 'Solicitud no encontrada' }, 404);
  const fila = await env.DB.prepare(
    `UPDATE solicitudadopcion
     SET estado = ?, fecha_actualizacion_estado = CURRENT_TIMESTAMP, id_administrador_revisor = ?,
         observaciones = COALESCE(?, observaciones),
         fecha_inicio_adopcion = CASE WHEN ? = 'aprobada' THEN CURRENT_DATE ELSE fecha_inicio_adopcion END,
         leido_usuario = 0
     WHERE id_solicitud_adopcion = ?
     RETURNING *`
  ).bind(body.estado, acceso.usuario.id_usuario, body.observaciones || null, body.estado, id).first();
  if (!fila) return json({ error: 'Solicitud no encontrada' }, 404);
  if (body.estado === 'aprobada') {
    await env.DB.prepare(`UPDATE mascota SET estado_adopcion = 'adoptado' WHERE id_mascota = ?`).bind(fila.id_mascota).run();
  }
  if (body.estado === 'pendiente') {
    await env.DB.prepare(`UPDATE mascota SET estado_adopcion = 'en_proceso' WHERE id_mascota = ?`).bind(fila.id_mascota).run();
  }
  let correoEnviado = false;
  if (previa.estado !== body.estado && (body.estado === 'aprobada' || body.estado === 'rechazada')) {
    const whatsapp = await whatsappFundacion(env);
    const comun = {
      nombre: previa.nombre,
      mascota: previa.mascota,
      observaciones: body.observaciones || null,
      whatsapp,
    };
    const plantilla = body.estado === 'aprobada'
      ? correos.aprobacionAdopcion({ ...comun, fecha: fila.fecha_inicio_adopcion })
      : correos.rechazoAdopcion(comun);
    const envio = await enviarCorreo(env, { para: previa.correo, ...plantilla });
    correoEnviado = envio.enviado === true;
  }
  return json({ ...fila, correo_enviado: correoEnviado });
}

async function crearApadrinamiento(request, env) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  if (acceso.usuario.bloqueado_apadrinar === 1) {
    return json({ error: 'Tu cuenta se encuentra bloqueada para apadrinar debido al registro reiterado de incumplimientos en seguimientos previos. Comunícate con la fundación si requieres asistencia.' }, 403);
  }
  const form = await request.formData();
  const idMascota = String(form.get('id_mascota') || '');
  const motivacion = String(form.get('informacion_adicional') || '').trim();
  if (!idMascota) return json({ error: 'Debes seleccionar una mascota' }, 400);
  if (!motivacion) return json({ error: 'Debes responder por qué quieres apadrinar a esta mascota' }, 400);
  if (motivacion.length > 500) return json({ error: 'La motivación no puede exceder los 500 caracteres' }, 400);
  if (!(form.get('acuerdo_responsabilidad') === 'true' || form.get('acuerdo_responsabilidad') === '1')) {
    return json({ error: 'Debes aceptar el acuerdo de responsabilidad' }, 400);
  }
  const documento = form.get('documento');
  if (!(documento instanceof File)) return json({ error: 'Debes adjuntar la fotografía de tu documento de identidad' }, 400);
  const mascota = await env.DB.prepare('SELECT id_mascota, nombre, estado_adopcion FROM mascota WHERE id_mascota = ?').bind(idMascota).first();
  if (!mascota) return json({ error: 'La mascota seleccionada no existe' }, 404);
  if (mascota.estado_adopcion === 'adoptado') return json({ error: 'Esta mascota ya fue adoptada y no se puede apadrinar' }, 409);
  const existe = await env.DB.prepare(
    `SELECT estado FROM solicitudapadrinamiento WHERE id_usuario = ? AND id_mascota = ? AND estado IN ('pendiente', 'aprobada')`
  ).bind(acceso.usuario.id_usuario, idMascota).first();
  if (existe) return json({ error: existe.estado === 'aprobada' ? 'Ya eres padrino de esta mascota' : 'Ya tienes una solicitud pendiente para esta mascota' }, 409);
  const archivo = await guardarArchivo(env, 'apadrinamientos', documento);
  const token = crypto.randomUUID();
  const creada = await env.DB.prepare(
    `INSERT INTO solicitudapadrinamiento (
      id_usuario, id_mascota, monto_aporte, frecuencia_aporte, informacion_adicional, documento_identidad_archivo,
      acuerdo_responsabilidad, fecha_acuerdo_responsabilidad, estado, leido_admin, leido_usuario, correo_contacto,
      tipo_aporte, detalle_especie, estado_correo, token_verificacion_correo, acepto_requisitos
    ) VALUES (?, ?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP, 'pendiente', 0, 1, ?, ?, ?, 'pendiente', ?, 1)
    RETURNING id_solicitud_apadrinamiento`
  ).bind(
    acceso.usuario.id_usuario, idMascota, form.get('monto_aporte') || null, form.get('frecuencia_aporte') || 'mensual',
    motivacion, archivo.ruta, String(form.get('correo_contacto') || acceso.usuario.correo),
    form.get('tipo_aporte') || 'Aporte monetario.', form.get('detalle_especie') || null, token
  ).first();
  const correo = String(form.get('correo_contacto') || acceso.usuario.correo).trim();
  const plantilla = correos.verificacionSolicitud({
    nombre: `${acceso.usuario.nombres || ''} ${acceso.usuario.apellidos || ''}`.trim() || 'Usuario',
    mascota: mascota.nombre,
    token,
    tipo: 'apadrinamiento',
    origen: new URL(request.url).origin,
  });
  const envio = await enviarCorreo(env, { para: correo, ...plantilla });
  return json({
    mensaje: 'Solicitud de apadrinamiento enviada',
    id_solicitud_apadrinamiento: creada.id_solicitud_apadrinamiento,
    correo_enviado: envio.enviado,
  }, 201);
}

async function listarApadrinamientos(request, env, url) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  const pidePropias = url.searchParams.get('mine') === 'true' || url.searchParams.get('mis_solicitudes') === 'true';
  const propias = pidePropias || !esAdmin(acceso.usuario.rol);
  const mascota = url.searchParams.get('mascota_id') || url.searchParams.get('pet_id');
  const filtros = [];
  const params = [];
  if (propias) { filtros.push('s.id_usuario = ?'); params.push(acceso.usuario.id_usuario); }
  if (mascota) { filtros.push('s.id_mascota = ?'); params.push(mascota); }
  const where = filtros.length ? `WHERE ${filtros.join(' AND ')}` : '';
  const filas = await env.DB.prepare(
    `SELECT s.*, u.nombres, u.apellidos, u.correo AS correo_usuario, u.telefono, u.direccion, u.documento_identidad,
            m.nombre AS mascota_nombre, m.fotos AS mascota_fotos
     FROM solicitudapadrinamiento s
     JOIN usuario u ON u.id_usuario = s.id_usuario
     JOIN mascota m ON m.id_mascota = s.id_mascota
     ${where}
     ORDER BY s.fecha_solicitud DESC`
  ).bind(...params).all();
  return json((filas.results || []).map(presentarApadrinamiento));
}

async function estadoApadrinamiento(request, env, id) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  const previa = await datosPersona(env, 'apadrinamiento', id);
  if (!previa) return json({ error: 'Solicitud no encontrada' }, 404);
  const fila = await env.DB.prepare(
    `UPDATE solicitudapadrinamiento
     SET estado = ?, observaciones = COALESCE(?, observaciones), fecha_actualizacion_estado = CURRENT_TIMESTAMP,
         id_admin_decision = ?, decision_admin = ?, leido_usuario = 0,
         fecha_inicio_apadrinamiento = CASE WHEN ? = 'aprobada' THEN CURRENT_DATE ELSE fecha_inicio_apadrinamiento END
     WHERE id_solicitud_apadrinamiento = ?
     RETURNING *`
  ).bind(body.estado, body.observaciones || null, acceso.usuario.id_usuario, body.estado, body.estado, id).first();
  if (!fila) return json({ error: 'Solicitud no encontrada' }, 404);
  if (body.estado === 'aprobada') await env.DB.prepare(`UPDATE mascota SET estado_apadrinamiento = 'apadrinado' WHERE id_mascota = ?`).bind(fila.id_mascota).run();
  let correoEnviado = false;
  if (previa.estado !== body.estado && (body.estado === 'aprobada' || body.estado === 'rechazada')) {
    const whatsapp = await whatsappFundacion(env);
    const comun = {
      nombre: previa.nombre,
      mascota: previa.mascota,
      observaciones: body.observaciones || null,
      whatsapp,
    };
    const plantilla = body.estado === 'aprobada'
      ? correos.aprobacionApadrinamiento({ ...comun, fecha: fila.fecha_inicio_apadrinamiento })
      : correos.rechazoApadrinamiento(comun);
    const envio = await enviarCorreo(env, { para: previa.correo, ...plantilla });
    correoEnviado = envio.enviado === true;
  }
  return json({ ...fila, correo_enviado: correoEnviado });
}

async function seguimientosActivos(request, env, tipo) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  if (tipo === 'adopcion') {
    const filas = await env.DB.prepare(
      `SELECT s.id_solicitud_adopcion, s.estado, COALESCE(s.estado_seguimiento, 'activa') AS estado_seguimiento,
              s.fecha_inicio_adopcion, s.contrato_adopcion_archivo, m.id_mascota, m.nombre AS mascota_nombre,
              m.fotos AS mascota_fotos, m.especie AS mascota_especie, m.raza AS mascota_raza, m.edad AS mascota_edad,
              m.unidad_edad AS mascota_unidad_edad, u.id_usuario, u.nombres AS usuario_nombres, u.apellidos AS usuario_apellidos,
              u.correo AS usuario_correo, u.telefono AS usuario_telefono, COALESCE(u.documento_identidad, '') AS usuario_cedula,
              COALESCE(u.direccion, '') AS usuario_direccion,
              COALESCE((SELECT ROUND(AVG(seg.calificacion), 1) FROM seguimientoadopcion seg WHERE seg.id_solicitud_adopcion = s.id_solicitud_adopcion), 0) AS calificacion_promedio,
              (SELECT COUNT(*) FROM seguimientoadopcion seg WHERE seg.id_solicitud_adopcion = s.id_solicitud_adopcion) AS total_seguimientos,
              (SELECT seg.fecha_seguimiento FROM seguimientoadopcion seg WHERE seg.id_solicitud_adopcion = s.id_solicitud_adopcion ORDER BY seg.fecha_seguimiento DESC LIMIT 1) AS ultimo_seguimiento_fecha,
              (SELECT seg.calificacion FROM seguimientoadopcion seg WHERE seg.id_solicitud_adopcion = s.id_solicitud_adopcion ORDER BY seg.fecha_seguimiento DESC LIMIT 1) AS ultimo_seguimiento_calificacion,
              (SELECT seg.proxima_fecha_seguimiento FROM seguimientoadopcion seg WHERE seg.id_solicitud_adopcion = s.id_solicitud_adopcion ORDER BY seg.fecha_seguimiento DESC LIMIT 1) AS proximo_seguimiento_fecha
       FROM solicitudadopcion s
       JOIN mascota m ON m.id_mascota = s.id_mascota
       JOIN usuario u ON u.id_usuario = s.id_usuario
       WHERE s.estado = 'aprobada'
       ORDER BY s.fecha_solicitud DESC`
    ).all();
    return json(filas.results);
  }
  const filas = await env.DB.prepare(
    `SELECT s.*, u.nombres AS usuario_nombres, u.apellidos AS usuario_apellidos, u.correo AS usuario_correo,
            m.nombre AS mascota_nombre, m.fotos AS mascota_fotos
     FROM solicitudapadrinamiento s
     JOIN usuario u ON u.id_usuario = s.id_usuario
     JOIN mascota m ON m.id_mascota = s.id_mascota
     WHERE s.estado = 'aprobada'
     ORDER BY s.fecha_solicitud DESC`
  ).all();
  return json(filas.results.map((fila) => ({ ...fila, id: fila.id_solicitud_apadrinamiento })));
}

async function historialSeguimiento(request, env, tipo, idSolicitud) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  const tabla = tipo === 'adopcion' ? 'seguimientoadopcion' : 'seguimientoapadrinamiento';
  const columna = tipo === 'adopcion' ? 'id_solicitud_adopcion' : 'id_solicitud_apadrinamiento';
  const filas = await env.DB.prepare(`SELECT * FROM ${tabla} WHERE ${columna} = ? ORDER BY fecha_seguimiento DESC`).bind(idSolicitud).all();
  if (tipo === 'apadrinamiento') {
    for (const fila of filas.results) {
      const aportes = await env.DB.prepare('SELECT * FROM seguimiento_aporte WHERE id_seguimiento_apadrinacion = ?').bind(fila.id_seguimiento_apadrinacion).all();
      fila.aportes = aportes.results;
    }
  }
  return json(filas.results);
}

async function crearSeguimiento(request, env, tipo) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const { datos: body, form } = await campos(request);
  if (tipo === 'adopcion') {
    const fotoEstado = await guardarSiArchivo(env, form, 'foto_estado', 'seguimientos_adopcion');
    const fotoEntorno = await guardarSiArchivo(env, form, 'foto_entorno', 'seguimientos_adopcion');
    const fila = await env.DB.prepare(
      `INSERT INTO seguimientoadopcion (
        id_solicitud_adopcion, id_administrador, fecha_seguimiento, observaciones, proxima_fecha_seguimiento,
        calificacion, cumplimiento, numero_seguimiento, ciclo, peso_saludable, condicion_sanitaria, entorno_apto,
        comportamiento, compromiso_veterinario, disposicion_adoptante, foto_estado, foto_entorno
      ) VALUES (?, ?, COALESCE(?, CURRENT_DATE), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      RETURNING *`
    ).bind(
      body.id_solicitud_adopcion, acceso.usuario.id_usuario, body.fecha_seguimiento || null, body.observaciones || null,
      body.proxima_fecha_seguimiento || null, body.calificacion || null, bool(body.cumplimiento) ?? 1,
      body.numero_seguimiento || null, body.ciclo || null, body.peso_saludable || null, body.condicion_sanitaria || null,
      body.entorno_apto || null, body.comportamiento || null, body.compromiso_veterinario || null,
      body.disposicion_adoptante || null, fotoEstado || body.foto_estado || null, fotoEntorno || body.foto_entorno || null
    ).first();
    return json(fila, 201);
  }
  const previos = await env.DB.prepare('SELECT numero_seguimiento, ciclo FROM seguimientoapadrinamiento WHERE id_solicitud_apadrinamiento = ?').bind(body.id_solicitud_apadrinamiento).all();
  const numero = (previos.results?.length || 0) + 1;
  const ciclo = Math.ceil(numero / 3);
  const evaluado = await env.DB.prepare('SELECT 1 AS ok FROM evaluacion_ciclo WHERE id_solicitud_apadrinamiento = ? AND ciclo = ?').bind(body.id_solicitud_apadrinamiento, ciclo - 1).first();
  if (numero > 1 && (numero - 1) % 3 === 0 && !evaluado) {
    return json({ error: 'Primero debes evaluar al padrino para cerrar el ciclo actual antes de registrar un nuevo seguimiento' }, 400);
  }
  const fila = await env.DB.prepare(
    `INSERT INTO seguimientoapadrinamiento (
      id_solicitud_apadrinamiento, id_administrador, fecha_seguimiento, cumplimiento, observaciones,
      proximo_seguimiento, calificacion, numero_seguimiento, ciclo
    ) VALUES (?, ?, COALESCE(?, CURRENT_DATE), ?, ?, ?, ?, ?, ?)
    RETURNING *`
  ).bind(
    body.id_solicitud_apadrinamiento, acceso.usuario.id_usuario, body.fecha_seguimiento || null, bool(body.cumplimiento),
    body.observaciones || null, body.proximo_seguimiento || null, body.calificacion || null,
    numero, ciclo
  ).first();
  const aportes = [];
  if (Array.isArray(body.aportes)) {
    for (const aporte of body.aportes) {
      if (!aporte?.tipo) continue;
      const guardado = await env.DB.prepare(
        `INSERT INTO seguimiento_aporte (id_seguimiento_apadrinacion, tipo, comprometido, recibido, medio, monto_recibido, referencia, detalle_recibido, observacion)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING *`
      ).bind(
        fila.id_seguimiento_apadrinacion, aporte.tipo, aporte.comprometido || null, bool(aporte.recibido) ?? 0,
        aporte.medio || null, aporte.monto_recibido || null, aporte.referencia || null, aporte.detalle_recibido || null, aporte.observacion || null
      ).first();
      aportes.push(guardado);
    }
  }
  const incumplimiento = await tresIncumplimientos(env, body.id_solicitud_apadrinamiento);
  let correoAlertaEnviado = false;
  if (incumplimiento.tiene_tres_incumplimientos === 1 && incumplimiento.ultimo_correo_enviado !== 1) {
    const persona = await datosPersona(env, 'apadrinamiento', body.id_solicitud_apadrinamiento);
    const plantilla = correos.alertaIncumplimiento({
      nombre: persona?.nombre || 'Padrino',
      mascota: persona?.mascota || 'la mascota',
    });
    const envio = await enviarCorreo(env, { para: persona?.correo_cuenta, ...plantilla });
    if (envio.enviado && incumplimiento.ultimo_id_seguimiento) {
      await env.DB.prepare(
        'UPDATE seguimientoapadrinamiento SET correo_alerta_enviado = 1 WHERE id_seguimiento_apadrinacion = ?'
      ).bind(incumplimiento.ultimo_id_seguimiento).run();
      correoAlertaEnviado = true;
    }
  }
  return json({ ...fila, aportes, incumplimiento, correo_alerta_enviado: correoAlertaEnviado }, 201);
}

async function tresIncumplimientos(env, idSolicitud) {
  const filas = await env.DB.prepare(
    `SELECT cumplimiento, calificacion, correo_alerta_enviado, id_seguimiento_apadrinacion
     FROM seguimientoapadrinamiento
     WHERE id_solicitud_apadrinamiento = ?
     ORDER BY fecha_seguimiento DESC, created_at DESC
     LIMIT 3`
  ).bind(idSolicitud).all();
  const lista = filas.results;
  const fallas = lista.filter((fila) => fila.cumplimiento === 0 || (fila.calificacion != null && fila.calificacion <= 2)).length;
  return {
    tiene_tres_incumplimientos: lista.length >= 3 && fallas >= 3 ? 1 : 0,
    ultimo_correo_enviado: lista[0]?.correo_alerta_enviado || 0,
    ultimo_id_seguimiento: lista[0]?.id_seguimiento_apadrinacion || null,
  };
}

async function calendario(request, env, tipo) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  if (tipo === 'adopcion') {
    const filas = await env.DB.prepare(
      `SELECT id_seguimiento_adopcion, id_solicitud_adopcion, fecha_seguimiento, proxima_fecha_seguimiento, calificacion
       FROM seguimientoadopcion ORDER BY COALESCE(proxima_fecha_seguimiento, fecha_seguimiento)`
    ).all();
    return json(filas.results);
  }
  const filas = await env.DB.prepare(
    `SELECT id_seguimiento_apadrinacion, id_solicitud_apadrinamiento, fecha_seguimiento, proximo_seguimiento, calificacion,
            CASE WHEN proximo_seguimiento < CURRENT_DATE THEN 1 ELSE 0 END AS es_vencido
     FROM seguimientoapadrinamiento ORDER BY COALESCE(proximo_seguimiento, fecha_seguimiento)`
  ).all();
  return json(filas.results);
}

async function cancelarAdopcion(request, env, idSolicitud) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const { datos: body, form } = await campos(request);
  if (!body.motivo || !body.observacion) return json({ error: 'Motivo y observación son obligatorios' }, 400);
  const foto1 = await guardarSiArchivo(env, form, 'foto_1', 'cancelaciones_adopcion');
  const foto2 = await guardarSiArchivo(env, form, 'foto_2', 'cancelaciones_adopcion');
  const solicitud = await env.DB.prepare('SELECT * FROM solicitudadopcion WHERE id_solicitud_adopcion = ?').bind(idSolicitud).first();
  if (!solicitud) return json({ error: 'Solicitud no encontrada' }, 404);
  const fila = await env.DB.prepare(
    `INSERT INTO cancelacion_adopcion (
      id_solicitud_adopcion, id_mascota, id_usuario, id_administrador, motivo, observacion, foto_1, foto_2, inhabilitar_cuenta
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    RETURNING *`
  ).bind(idSolicitud, solicitud.id_mascota, solicitud.id_usuario, acceso.usuario.id_usuario, body.motivo, body.observacion, foto1 || body.foto_1 || null, foto2 || body.foto_2 || null, bool(body.inhabilitar_cuenta) ?? 0).first();
  await env.DB.batch([
    env.DB.prepare(`UPDATE solicitudadopcion SET estado = 'cancelada', fecha_actualizacion_estado = CURRENT_TIMESTAMP, leido_usuario = 0 WHERE id_solicitud_adopcion = ?`).bind(idSolicitud),
    env.DB.prepare(`UPDATE mascota SET estado_adopcion = 'disponible' WHERE id_mascota = ?`).bind(solicitud.id_mascota),
  ]);
  if (bool(body.inhabilitar_cuenta) === 1) {
    await env.DB.prepare(`UPDATE usuario SET estado_cuenta = 'inactivo' WHERE id_usuario = ?`).bind(solicitud.id_usuario).run();
  }
  return json(fila, 201);
}

async function verCancelacion(request, env, idSolicitud) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const fila = await env.DB.prepare('SELECT * FROM cancelacion_adopcion WHERE id_solicitud_adopcion = ?').bind(idSolicitud).first();
  if (!fila) return json({ error: 'Cancelación no encontrada' }, 404);
  return json(fila);
}

async function cancelarApadrinamiento(request, env) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  const solicitud = await env.DB.prepare(
    `UPDATE solicitudapadrinamiento
     SET estado = 'cancelada', estado_apadrinamiento = 'cancelada', motivo_cancelacion = ?, fecha_cancelacion = CURRENT_TIMESTAMP,
         observaciones = ?, leido_usuario = 0, fecha_actualizacion_estado = CURRENT_TIMESTAMP
     WHERE id_solicitud_apadrinamiento = ?
     RETURNING id_usuario, id_mascota`
  ).bind(body.motivo || '', body.motivo || '', body.id_solicitud).first();
  if (!solicitud) return json({ error: 'Solicitud no encontrada' }, 404);
  if (body.bloquear) await env.DB.prepare('UPDATE usuario SET bloqueado_apadrinar = 1 WHERE id_usuario = ?').bind(solicitud.id_usuario).run();
  await env.DB.prepare(`UPDATE mascota SET estado_apadrinamiento = 'disponible' WHERE id_mascota = ?`).bind(solicitud.id_mascota).run();
  return json({ exito: true, id_solicitud: body.id_solicitud, id_usuario: solicitud.id_usuario });
}

async function evaluarCiclo(request, env) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  if (!['continuar', 'cancelar'].includes(body.decision)) return json({ error: 'La decisión debe ser continuar o cancelar' }, 400);
  const solicitud = await env.DB.prepare('SELECT * FROM solicitudapadrinamiento WHERE id_solicitud_apadrinamiento = ?').bind(body.id_solicitud).first();
  if (!solicitud) return json({ error: 'La solicitud de apadrinamiento no existe' }, 404);
  const ciclo = body.ciclo || (await env.DB.prepare('SELECT COALESCE(MAX(ciclo), 1) AS ciclo FROM seguimientoapadrinamiento WHERE id_solicitud_apadrinamiento = ?').bind(body.id_solicitud).first()).ciclo;
  const promedioFila = await env.DB.prepare(
    'SELECT COALESCE(ROUND(AVG(calificacion), 2), 0) AS promedio FROM seguimientoapadrinamiento WHERE id_solicitud_apadrinamiento = ? AND ciclo = ?'
  ).bind(body.id_solicitud, ciclo).first();
  const promedio = promedioFila.promedio;
  const puntuacion = promedio >= 4 ? 'buen' : promedio >= 3 ? 'regular' : 'mal';
  const evaluacionPrevia = await env.DB.prepare(
    'SELECT id_evaluacion FROM evaluacion_ciclo WHERE id_solicitud_apadrinamiento = ? AND ciclo = ?'
  ).bind(body.id_solicitud, ciclo).first();
  const evaluacion = await env.DB.prepare(
    `INSERT INTO evaluacion_ciclo (id_solicitud_apadrinamiento, ciclo, promedio, puntuacion, decision, nota, id_administrador, visto_por_usuario)
     VALUES (?, ?, ?, ?, ?, ?, ?, 0)
     ON CONFLICT (id_solicitud_apadrinamiento, ciclo) DO UPDATE SET
       promedio = excluded.promedio, puntuacion = excluded.puntuacion, decision = excluded.decision,
       nota = excluded.nota, id_administrador = excluded.id_administrador, fecha_decision = CURRENT_DATE, visto_por_usuario = 0
     RETURNING id_evaluacion`
  ).bind(body.id_solicitud, ciclo, promedio, puntuacion, body.decision, body.nota || null, acceso.usuario.id_usuario).first();
  await env.DB.prepare(
    `UPDATE solicitudapadrinamiento SET decision_admin = ?, nota_decision = ?, id_admin_decision = ?, fecha_decision = CURRENT_DATE, leido_usuario = 0, fecha_actualizacion_estado = CURRENT_TIMESTAMP
     WHERE id_solicitud_apadrinamiento = ?`
  ).bind(body.decision, body.nota || null, acceso.usuario.id_usuario, body.id_solicitud).run();
  if (body.decision === 'cancelar') await cancelarApadrinamiento(new Request(request.url, { method: 'POST', headers: request.headers, body: JSON.stringify({ id_solicitud: body.id_solicitud, motivo: body.nota, bloquear: body.bloquear }) }), env);
  const mascota = await env.DB.prepare('SELECT nombre FROM mascota WHERE id_mascota = ?').bind(solicitud.id_mascota).first();
  await env.DB.prepare(
    `INSERT INTO notificaciones (id_usuario, id_solicitud_apadrinamiento, tipo, titulo, mensaje, leida)
     VALUES (?, ?, 'evaluacion_ciclo', ?, ?, 0)`
  ).bind(solicitud.id_usuario, body.id_solicitud, `Evaluación del Ciclo ${ciclo}`, `La evaluación del ciclo ${ciclo} de ${mascota?.nombre || 'la mascota'} está lista.`).run();
  const persona = await datosPersona(env, 'apadrinamiento', body.id_solicitud);
  let correoEnviado = false;
  if (!evaluacionPrevia) {
    const plantilla = correos.decisionApadrinamiento({
      nombre: persona?.nombre || 'Padrino',
      mascota: mascota?.nombre || 'la mascota',
      decision: body.decision,
      nota: body.nota || null,
      admin: `${acceso.usuario.nombres || ''} ${acceso.usuario.apellidos || ''}`.trim(),
      ciclo,
    });
    const envio = await enviarCorreo(env, { para: persona?.correo_cuenta, ...plantilla });
    correoEnviado = envio.enviado === true;
  }
  return json({ ok: true, id_evaluacion: evaluacion.id_evaluacion, ciclo, promedio, puntuacion, decision: body.decision, correo_enviado: correoEnviado });
}

async function resumenPadrino(env, idUsuario) {
  const fila = await env.DB.prepare(
    `SELECT COALESCE(ROUND(AVG(s.calificacion), 1), 0) AS calificacion_promedio, COUNT(s.id_seguimiento_apadrinacion) AS total
     FROM seguimientoapadrinamiento s
     JOIN solicitudapadrinamiento sa ON sa.id_solicitud_apadrinamiento = s.id_solicitud_apadrinamiento
     WHERE sa.id_usuario = ? AND s.calificacion IS NOT NULL`
  ).bind(idUsuario).first();
  return json(fila);
}

async function reporteVisto(request, env, idEvaluacion) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  const fila = await env.DB.prepare(
    `UPDATE evaluacion_ciclo SET visto_por_usuario = 1, fecha_vista_usuario = CURRENT_TIMESTAMP WHERE id_evaluacion = ? RETURNING *`
  ).bind(idEvaluacion).first();
  if (!fila) return json({ error: 'Evaluación no encontrada' }, 404);
  return json(fila);
}

async function finalizarApadrinamiento(request, env, id) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const { datos: body, form } = await campos(request);
  const motivos = [
    'Incumplimiento del acuerdo de apadrinamiento',
    'Falta de los aportes acordados',
    'Pérdida de contacto con el padrino',
    'Desinterés por parte del padrino',
    'Cambio imprevisto en la situación del padrino',
    'Solicitud del padrino',
    'Otro',
  ];
  const motivo = String(body.motivo || '').trim();
  const observacion = String(body.observacion || '').trim();
  const fecha = String(body.fecha_cancelacion || '').trim();
  if (!motivos.includes(motivo)) return json({ error: 'Selecciona un motivo de la lista' }, 400);
  if (observacion.length < 10) return json({ error: 'Explica el motivo de la cancelación con más detalle' }, 400);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(fecha)) return json({ error: 'La fecha de cancelación no es válida' }, 400);
  const solicitud = await env.DB.prepare(
    `SELECT id_solicitud_apadrinamiento, estado, estado_apadrinamiento, id_mascota, foto_cancelacion
     FROM solicitudapadrinamiento WHERE id_solicitud_apadrinamiento = ?`
  ).bind(id).first();
  if (!solicitud) return json({ error: 'La solicitud de apadrinamiento no existe' }, 404);
  if (solicitud.estado === 'cancelada' || solicitud.estado_apadrinamiento === 'cancelada') {
    return json({ error: 'Este apadrinamiento ya fue cancelado' }, 409);
  }
  if (solicitud.estado !== 'aprobada') return json({ error: 'Solo se puede cancelar un apadrinamiento activo' }, 400);
  const foto = await guardarSiArchivo(env, form, 'foto', 'cancelaciones_apadrinamiento');
  const mascota = await env.DB.prepare('SELECT nombre FROM mascota WHERE id_mascota = ?').bind(solicitud.id_mascota).first();
  await env.DB.prepare(
    `UPDATE solicitudapadrinamiento
     SET estado = 'cancelada', estado_apadrinamiento = 'cancelada', motivo_cancelacion = ?, observacion_cancelacion = ?,
         foto_cancelacion = COALESCE(?, foto_cancelacion), fecha_cancelacion = ?, fecha_actualizacion_estado = CURRENT_TIMESTAMP,
         leido_usuario = 0, id_admin_decision = ?, decision_admin = 'cancelar', nota_decision = ?, fecha_decision = ?
     WHERE id_solicitud_apadrinamiento = ?`
  ).bind(motivo, observacion, foto, fecha, acceso.usuario.id_usuario, observacion, fecha, id).run();
  if (foto && solicitud.foto_cancelacion && solicitud.foto_cancelacion !== foto) await borrarArchivo(env, solicitud.foto_cancelacion);
  await env.DB.prepare(
    `UPDATE mascota SET estado_apadrinamiento = 'disponible'
     WHERE id_mascota = ? AND NOT EXISTS (
       SELECT 1 FROM solicitudapadrinamiento otra
       WHERE otra.id_mascota = ? AND otra.id_solicitud_apadrinamiento <> ?
         AND otra.estado = 'aprobada' AND COALESCE(otra.estado_apadrinamiento, 'activa') = 'activa'
     )`
  ).bind(solicitud.id_mascota, solicitud.id_mascota, id).run();
  return json({
    mensaje: `Apadrinamiento cancelado. ${mascota?.nombre || 'La mascota'} vuelve a estar disponible.`,
    foto_cancelacion: foto,
  }, 201);
}

async function resumenAdopcion(request, env) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  if (esAdmin(acceso.usuario.rol)) {
    const total = await env.DB.prepare(`SELECT COUNT(*) AS total FROM solicitudadopcion WHERE leido_admin = 0 AND estado = 'pendiente'`).first();
    return json({ total: total.total });
  }
  const total = await env.DB.prepare(`SELECT COUNT(*) AS total FROM solicitudadopcion WHERE id_usuario = ? AND leido_usuario = 0 AND estado IN ('aprobada', 'rechazada')`).bind(acceso.usuario.id_usuario).first();
  return json({ total: total.total });
}

async function resumenApadrinamiento(request, env) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  if (esAdmin(acceso.usuario.rol)) {
    const total = await env.DB.prepare(`SELECT COUNT(*) AS total FROM solicitudapadrinamiento WHERE leido_admin = 0 AND estado = 'pendiente'`).first();
    return json({ total: total.total });
  }
  const total = await env.DB.prepare(`SELECT COUNT(*) AS total FROM solicitudapadrinamiento WHERE id_usuario = ? AND leido_usuario = 0 AND estado IN ('aprobada', 'rechazada', 'cancelada')`).bind(acceso.usuario.id_usuario).first();
  return json({ total: total.total });
}

async function marcarLeido(request, env, tabla, columna, admin) {
  const acceso = admin ? await exigirAdmin(request, env) : await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  if (admin) await env.DB.prepare(`UPDATE ${tabla} SET ${columna} = 1 WHERE ${columna} = 0`).run();
  else await env.DB.prepare(`UPDATE ${tabla} SET ${columna} = 1 WHERE id_usuario = ?`).bind(acceso.usuario.id_usuario).run();
  return json({ ok: true });
}

async function verificarSolicitud(env, url, tabla, idColumna) {
  const token = url.searchParams.get('token');
  const fila = await env.DB.prepare(
    `UPDATE ${tabla} SET estado_correo = 'confirmado', fecha_verificacion_correo = CURRENT_TIMESTAMP
     WHERE token_verificacion_correo = ? RETURNING ${idColumna}`
  ).bind(token).first();
  if (!fila) return json({ error: 'El enlace de verificación no es válido' }, 400);
  return json({ ok: true });
}

async function reenviar(request, env, tabla, idColumna, id) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  const fila = await env.DB.prepare(`SELECT correo_contacto, token_verificacion_correo FROM ${tabla} WHERE ${idColumna} = ?`).bind(id).first();
  if (!fila) return json({ error: 'Solicitud no encontrada' }, 404);
  const persona = await datosPersona(env, tabla === 'solicitudadopcion' ? 'adopcion' : 'apadrinamiento', id);
  const plantilla = correos.verificacionSolicitud({
    nombre: persona?.nombre || 'Usuario',
    mascota: persona?.mascota || 'la mascota',
    token: fila.token_verificacion_correo,
    tipo: tabla === 'solicitudadopcion' ? 'adopcion' : 'apadrinamiento',
    origen: new URL(request.url).origin,
  });
  const envio = await enviarCorreo(env, { para: fila.correo_contacto, ...plantilla });
  if (!envio.enviado) {
    const estado = envio.motivo === 'sin_configurar' ? 503 : 502;
    const error = envio.motivo === 'sin_configurar' ? 'El correo no está configurado en el servidor.' : 'No se pudo enviar el correo.';
    return json({ ok: false, correo_enviado: false, error }, estado);
  }
  return json({ ok: true, correo_enviado: true });
}

async function archivoSolicitud(request, env, tabla, idColumna, id, tipo) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  const columna = {
    'id-card': 'foto_cedula',
    'utility-bill': 'foto_servicios_publicos',
    documento: 'documento_identidad_archivo',
    contrato: tabla === 'solicitudadopcion' ? 'contrato_adopcion_archivo' : 'contrato_apadrinamiento_archivo',
  }[tipo];
  const fila = await env.DB.prepare(`SELECT id_usuario, ${columna} AS ruta FROM ${tabla} WHERE ${idColumna} = ?`).bind(id).first();
  if (!fila?.ruta) return json({ error: 'Archivo no encontrado' }, 404);
  if (fila.id_usuario !== acceso.usuario.id_usuario && !esAdmin(acceso.usuario.rol)) return json({ error: 'No puedes ver este archivo' }, 403);
  const archivo = await leerArchivo(env, fila.ruta);
  return archivo || json({ error: 'Archivo no encontrado' }, 404);
}

async function subirContrato(request, env, tabla, idColumna, columna, id) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const form = await request.formData();
  const archivo = form.get('contrato');
  if (!(archivo instanceof File)) return json({ error: 'No se recibió el contrato' }, 400);
  const previa = await env.DB.prepare(`SELECT ${columna} AS ruta FROM ${tabla} WHERE ${idColumna} = ?`).bind(id).first();
  if (!previa) return json({ error: 'Solicitud no encontrada' }, 404);
  const guardado = await guardarArchivo(env, 'contratos', archivo);
  const fila = await env.DB.prepare(`UPDATE ${tabla} SET ${columna} = ? WHERE ${idColumna} = ? RETURNING ${idColumna}, ${columna}`).bind(guardado.ruta, id).first();
  if (!fila) {
    await borrarArchivo(env, guardado.ruta);
    return json({ error: 'Solicitud no encontrada' }, 404);
  }
  if (previa.ruta && previa.ruta !== guardado.ruta) await borrarArchivo(env, previa.ruta);
  let correoEnviado = false;
  if (!previa.ruta && tabla === 'solicitudadopcion') {
    const persona = await datosPersona(env, 'adopcion', id);
    const whatsapp = await whatsappFundacion(env);
    const plantilla = correos.contratoAdopcion({
      nombre: persona?.nombre || 'Estimado/a adoptante',
      mascota: persona?.mascota || 'la mascota',
      whatsapp,
    });
    const envio = await enviarCorreo(env, { para: persona?.correo, ...plantilla });
    correoEnviado = envio.enviado === true;
  }
  return json({ ...fila, correo_enviado: correoEnviado });
}

async function quitarContrato(request, env, tabla, idColumna, columna, id) {
  const acceso = await exigirAdmin(request, env);
  if (acceso.error) return acceso.error;
  const actual = await env.DB.prepare(`SELECT ${columna} AS ruta FROM ${tabla} WHERE ${idColumna} = ?`).bind(id).first();
  if (!actual) return json({ error: 'Solicitud no encontrada' }, 404);
  await borrarArchivo(env, actual.ruta);
  await env.DB.prepare(`UPDATE ${tabla} SET ${columna} = NULL WHERE ${idColumna} = ?`).bind(id).run();
  return json({ ok: true });
}

async function campos(request) {
  const tipo = request.headers.get('Content-Type') || '';
  if (!tipo.includes('multipart/form-data')) return { datos: await cuerpo(request), form: null };
  const form = await request.formData();
  const datos = {};
  for (const [clave, valor] of form.entries()) {
    if (typeof valor === 'string') datos[clave] = valor;
  }
  return { datos, form };
}

async function guardarSiArchivo(env, form, campo, carpeta) {
  if (!form) return null;
  const archivo = form.get(campo);
  if (!(archivo instanceof File) || archivo.size === 0) return null;
  const guardado = await guardarArchivo(env, carpeta, archivo);
  return guardado.ruta;
}

async function crearDenuncia(request, env) {
  const form = await request.formData();
  const nombre = String(form.get('nombre_reportante') || '').trim();
  const telefono = String(form.get('telefono_reportante') || '').replace(/[\s\-()+]/g, '');
  if (!nombre) return json({ error: 'El nombre completo de la persona que reporta es obligatorio' }, 400);
  if (telefono.length < 7 || telefono.length > 15) return json({ error: 'Ingresa un número de teléfono válido (mínimo 7 dígitos numéricos)' }, 400);
  if (!String(form.get('tipo_reporte') || '').trim() || !String(form.get('tipo_animal') || '').trim() || !String(form.get('descripcion_caso') || '').trim()) {
    return json({ error: 'Completa el tipo de reporte, el animal y la descripción' }, 400);
  }
  const radicado = `PM-${Date.now()}`;
  const denuncia = await env.DB.prepare(
    `INSERT INTO denuncia (
      radicado, nombre_reportante, telefono_reportante, barrio_reportante, ciudad_reportante,
      tipo_reporte, tipo_animal, ubicacion_animal, ciudad_caso, fecha_situacion, peligro_inmediato,
      descripcion_caso, caracteristicas_animal, estado_salud, heridas_visibles, dificultad_movilidad,
      condiciones_lugar, observaciones_adicionales, acepto_politica
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    RETURNING id_denuncia, radicado, fecha_creacion, estado`
  ).bind(
    radicado, nombre, telefono, form.get('barrio_reportante') || null, form.get('ciudad_reportante') || null,
    form.get('tipo_reporte'), form.get('tipo_animal'), form.get('ubicacion_animal') || '', form.get('ciudad_caso') || '',
    form.get('fecha_situacion') || '', form.get('peligro_inmediato') || 'no', form.get('descripcion_caso'),
    form.get('caracteristicas_animal') || null, form.get('estado_salud') || null, form.get('heridas_visibles') || null,
    form.get('dificultad_movilidad') || null, form.get('condiciones_lugar') || null, form.get('observaciones_adicionales') || null,
    bool(form.get('acepto_politica')) ?? 1
  ).first();
  const archivos = form.getAll('archivos').filter((archivo) => archivo instanceof File);
  for (const archivo of archivos.slice(0, 10)) {
    const guardado = await guardarArchivo(env, 'denuncias', archivo);
    await env.DB.prepare(
      `INSERT INTO denuncia_archivo (id_denuncia, nombre_original, nombre_guardado, ruta_archivo, tipo_mime, tamano_bytes, es_video)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    ).bind(denuncia.id_denuncia, archivo.name, guardado.nombre, guardado.ruta, archivo.type || null, archivo.size || null, archivo.type?.startsWith('video/') ? 1 : 0).run();
  }
  const aviso = await avisarDenuncia(env, denuncia.radicado);
  return json({ ...denuncia, correo_enviado: aviso.enviado }, 201);
}

async function exigirDenuncias(request, env) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso;
  if (acceso.usuario.rol !== 'administrador') {
    return { error: json({ error: 'Acceso restringido solo para personal autorizado de la Fundación Maritza Arévalo' }, 403) };
  }
  return acceso;
}

async function listarDenuncias(request, env, url) {
  const acceso = await exigirDenuncias(request, env);
  if (acceso.error) return acceso.error;
  const q = url.searchParams.get('q');
  const filtro = q ? `WHERE radicado LIKE ? OR nombre_reportante LIKE ? OR ciudad_caso LIKE ? OR tipo_reporte LIKE ? OR tipo_animal LIKE ?` : '';
  const params = q ? Array(5).fill(`%${q}%`) : [];
  const filas = await env.DB.prepare(
    `SELECT d.*, (SELECT COUNT(*) FROM denuncia_archivo a WHERE a.id_denuncia = d.id_denuncia) AS total_archivos
     FROM denuncia d ${filtro} ORDER BY d.fecha_creacion DESC`
  ).bind(...params).all();
  return json(filas.results);
}

async function unaDenuncia(request, env, id) {
  const acceso = await exigirDenuncias(request, env);
  if (acceso.error) return acceso.error;
  const denuncia = await env.DB.prepare('SELECT * FROM denuncia WHERE id_denuncia = ?').bind(id).first();
  if (!denuncia) return json({ error: 'Denuncia no encontrada' }, 404);
  const archivos = await env.DB.prepare('SELECT id_archivo, id_denuncia, nombre_original, nombre_guardado, ruta_archivo, tipo_mime, tamano_bytes, es_video, fecha_subida FROM denuncia_archivo WHERE id_denuncia = ?').bind(id).all();
  const historial = await env.DB.prepare('SELECT * FROM denuncia_historial WHERE id_denuncia = ? ORDER BY fecha').bind(id).all();
  return json({ ...denuncia, archivos: archivos.results, historial: historial.results });
}

async function archivoDenuncia(request, env, idDenuncia, idArchivo) {
  const acceso = await exigirDenuncias(request, env);
  if (acceso.error) return acceso.error;
  const fila = await env.DB.prepare('SELECT ruta_archivo FROM denuncia_archivo WHERE id_denuncia = ? AND id_archivo = ?').bind(idDenuncia, idArchivo).first();
  if (!fila) return json({ error: 'Archivo no encontrado' }, 404);
  return (await leerArchivo(env, fila.ruta_archivo)) || json({ error: 'Archivo no encontrado' }, 404);
}

async function estadoDenuncia(request, env, id) {
  const acceso = await exigirDenuncias(request, env);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  const actual = await env.DB.prepare('SELECT estado FROM denuncia WHERE id_denuncia = ?').bind(id).first();
  if (!actual) return json({ error: 'Denuncia no encontrada' }, 404);
  const fila = await env.DB.prepare(
    `UPDATE denuncia SET estado = ?, observaciones_internas = COALESCE(?, observaciones_internas), acciones_realizadas = COALESCE(?, acciones_realizadas), leido_admin = 1, fecha_actualizacion = CURRENT_TIMESTAMP
     WHERE id_denuncia = ? RETURNING *`
  ).bind(body.estado, body.observaciones_internas || null, body.acciones_realizadas || null, id).first();
  await env.DB.prepare(
    `INSERT INTO denuncia_historial (id_denuncia, id_usuario_admin, nombre_admin, estado_anterior, estado_nuevo, observacion)
     VALUES (?, ?, ?, ?, ?, ?)`
  ).bind(id, acceso.usuario.id_usuario, `${acceso.usuario.nombres} ${acceso.usuario.apellidos}`, actual.estado, body.estado, body.observaciones_internas || null).run();
  return json(fila);
}

async function conteoDenuncias(request, env) {
  const acceso = await exigirDenuncias(request, env);
  if (acceso.error) return acceso.error;
  const noLeidas = await env.DB.prepare('SELECT COUNT(*) AS total FROM denuncia WHERE leido_admin = 0').first();
  const pendientes = await env.DB.prepare(`SELECT COUNT(*) AS total FROM denuncia WHERE estado IN ('recibido', 'en_revision', 'en_gestion')`).first();
  const total = await env.DB.prepare('SELECT COUNT(*) AS total FROM denuncia').first();
  return json({ no_leidas: noLeidas.total, pendientes: pendientes.total, total: total.total });
}

async function reintentarDenuncia(request, env, id) {
  const acceso = await exigirDenuncias(request, env);
  if (acceso.error) return acceso.error;
  const denuncia = await env.DB.prepare('SELECT radicado FROM denuncia WHERE id_denuncia = ?').bind(id).first();
  if (!denuncia) return json({ error: 'Denuncia no encontrada' }, 404);
  if (!env.RESEND_API_KEY || !env.CORREO_DESDE) {
    return json({ ok: false, correo_enviado: false, error: 'El correo no está configurado en el servidor.' }, 503);
  }
  const aviso = await avisarDenuncia(env, denuncia.radicado);
  if (aviso.motivo === 'sin_destinatario') {
    return json({ ok: false, correo_enviado: false, error: 'No hay un superadministrador activo para notificar.' });
  }
  if (!aviso.enviado) {
    return json({ ok: false, correo_enviado: false, error: 'No se pudo enviar el correo.' }, 502);
  }
  return json({ ok: true, correo_enviado: true, enviados: aviso.enviados });
}

async function subirFoto(request, env, carpeta, soloAdmin) {
  const acceso = soloAdmin ? await exigirAdmin(request, env) : await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  const form = await request.formData();
  const archivo = form.get('foto') || form.get('imagen');
  if (!(archivo instanceof File)) return json({ error: 'No se recibió ninguna imagen' }, 400);
  const guardado = await guardarArchivo(env, carpeta, archivo);
  return json({ ruta: guardado.ruta }, 201);
}

async function subirFotoUsuario(request, env) {
  return subirFoto(request, env, 'usuarios', false);
}

async function datosPersona(env, tipo, id) {
  const adopcion = tipo === 'adopcion';
  const tabla = adopcion ? 'solicitudadopcion' : 'solicitudapadrinamiento';
  const columna = adopcion ? 'id_solicitud_adopcion' : 'id_solicitud_apadrinamiento';
  const fila = await env.DB.prepare(
    `SELECT s.estado, s.correo_contacto, u.correo AS correo_cuenta, u.nombres, u.apellidos, m.nombre AS mascota
     FROM ${tabla} s
     JOIN usuario u ON u.id_usuario = s.id_usuario
     JOIN mascota m ON m.id_mascota = s.id_mascota
     WHERE s.${columna} = ?`
  ).bind(id).first();
  if (!fila) return null;
  const contacto = String(fila.correo_contacto || '').trim();
  return {
    estado: fila.estado,
    nombre: `${fila.nombres || ''} ${fila.apellidos || ''}`.trim() || (adopcion ? 'Estimado/a adoptante' : 'Estimado/a padrino'),
    mascota: fila.mascota,
    correo: contacto.includes('@') ? contacto : fila.correo_cuenta,
    correo_cuenta: fila.correo_cuenta,
  };
}

async function whatsappFundacion(env) {
  const fila = await env.DB.prepare('SELECT telefono FROM informacionfundacion LIMIT 1').first();
  const digitos = String(fila?.telefono || '').replace(/\D/g, '');
  return digitos || '573136177747';
}

async function avisarDenuncia(env, radicado) {
  const plantilla = correos.denunciaAdmin({ radicado });
  const admins = await env.DB.prepare(`SELECT correo FROM usuario WHERE rol = 'superadmin' AND estado_cuenta = 'activo'`).all();
  const destinos = (admins.results || []).map((fila) => fila.correo).filter((correo) => String(correo || '').includes('@'));
  if (!destinos.length) return { enviado: false, motivo: 'sin_destinatario', enviados: 0 };
  let enviados = 0;
  let motivo = 'rechazado';
  for (const para of destinos) {
    const envio = await enviarCorreo(env, { para, ...plantilla });
    if (envio.enviado) enviados += 1;
    else motivo = envio.motivo;
  }
  return { enviado: enviados > 0, motivo: enviados > 0 ? 'enviado' : motivo, enviados };
}

function nombreDeArchivo(nombre) {
  let limpio = nombre;
  try { limpio = decodeURIComponent(nombre); } catch { return null; }
  if (!limpio || limpio.includes('..') || limpio.includes('/') || limpio.includes('\\')) return null;
  return limpio;
}

async function duenoDeArchivo(env, carpeta, rutaArchivo) {
  if (carpeta === 'seguimientos_adopcion') {
    return env.DB.prepare(
      `SELECT sa.id_usuario AS id FROM seguimientoadopcion seg
       JOIN solicitudadopcion sa ON sa.id_solicitud_adopcion = seg.id_solicitud_adopcion
       WHERE seg.foto_estado = ? OR seg.foto_entorno = ?`
    ).bind(rutaArchivo, rutaArchivo).first();
  }
  if (carpeta === 'cancelaciones_adopcion') {
    return env.DB.prepare('SELECT id_usuario AS id FROM cancelacion_adopcion WHERE foto_1 = ? OR foto_2 = ?').bind(rutaArchivo, rutaArchivo).first();
  }
  if (carpeta === 'cancelaciones_apadrinamiento') {
    return env.DB.prepare('SELECT id_usuario AS id FROM solicitudapadrinamiento WHERE foto_cancelacion = ?').bind(rutaArchivo).first();
  }
  if (carpeta === 'adopciones') {
    return env.DB.prepare('SELECT id_usuario AS id FROM solicitudadopcion WHERE foto_cedula = ? OR foto_servicios_publicos = ?').bind(rutaArchivo, rutaArchivo).first();
  }
  if (carpeta === 'apadrinamientos') {
    return env.DB.prepare('SELECT id_usuario AS id FROM solicitudapadrinamiento WHERE documento_identidad_archivo = ?').bind(rutaArchivo).first();
  }
  if (carpeta === 'contratos') {
    const adopcion = await env.DB.prepare('SELECT id_usuario AS id FROM solicitudadopcion WHERE contrato_adopcion_archivo = ?').bind(rutaArchivo).first();
    if (adopcion) return adopcion;
    return env.DB.prepare('SELECT id_usuario AS id FROM solicitudapadrinamiento WHERE contrato_apadrinamiento_archivo = ?').bind(rutaArchivo).first();
  }
  if (carpeta === 'denuncias') {
    return env.DB.prepare('SELECT id_archivo FROM denuncia_archivo WHERE ruta_archivo = ?').bind(rutaArchivo).first();
  }
  return null;
}

async function archivoPrivado(request, env, carpeta, nombre) {
  const archivo = nombreDeArchivo(nombre);
  if (!archivo) return json({ error: 'Archivo no encontrado' }, 404);
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  if (carpeta === 'denuncias' && acceso.usuario.rol !== 'administrador') {
    return json({ error: 'Acceso restringido solo para personal autorizado de la Fundación Maritza Arévalo' }, 403);
  }
  const rutaArchivo = `/uploads/${carpeta}/${archivo}`;
  const dueno = await duenoDeArchivo(env, carpeta, rutaArchivo);
  if (!dueno) return json({ error: 'Archivo no encontrado' }, 404);
  const admin = carpeta === 'denuncias' ? acceso.usuario.rol === 'administrador' : esAdmin(acceso.usuario.rol);
  if (!admin && dueno.id !== acceso.usuario.id_usuario) {
    return json({ error: 'No puedes ver este archivo' }, 403);
  }
  const objeto = await leerArchivo(env, rutaArchivo);
  if (!objeto) return json({ error: 'Archivo no encontrado' }, 404);
  const headers = new Headers(objeto.headers);
  headers.set('Cache-Control', 'private, no-store');
  headers.set('X-Content-Type-Options', 'nosniff');
  return new Response(objeto.body, { status: 200, headers });
}

async function servirPublico(env, ruta) {
  const publica = /^\/uploads\/(mascotas|noticias|fundacion|usuarios)\//.test(ruta);
  if (!publica) return json({ error: 'Archivo no disponible' }, 404);
  return (await leerArchivo(env, ruta)) || json({ error: 'Archivo no encontrado' }, 404);
}

async function preguntas(request, env) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso.error;
  return json({
    preguntas: PREGUNTAS.map(([clave, titulo, pregunta], indice) => ({ orden: indice + 1, clave, titulo, pregunta })),
  });
}

async function entrevista(request, env, id) {
  const acceso = await exigirPropio(request, env, id);
  if (acceso.error) return acceso.error;
  const filas = await env.DB.prepare('SELECT * FROM borrador_entrevista_personalidad WHERE id_usuario = ?').bind(id).all();
  return json({
    respuestas: filas.results.map((fila) => ({
      pregunta_id: fila.clave_pregunta,
      respuesta_original: fila.respuesta_original,
      puntuacion: fila.puntuacion,
      justificacion: fila.justificacion,
      actualizado: fila.actualizado,
    })),
  });
}

async function borrarRespuestaEntrevista(request, env, id, clave) {
  const acceso = await exigirPropio(request, env, id);
  if (acceso.error) return acceso.error;
  await env.DB.prepare('DELETE FROM borrador_entrevista_personalidad WHERE id_usuario = ? AND clave_pregunta = ?').bind(id, clave).run();
  return json({ ok: true });
}

async function transcribir(request, env, id) {
  const acceso = await exigirPropio(request, env, id);
  if (acceso.error) return acceso.error;
  if (!env.OPENAI_API_KEY) {
    return json({ error: 'El asistente no está configurado. Falta OPENAI_API_KEY en el servidor.' }, 503);
  }
  const form = await request.formData();
  const audio = form.get('audio');
  if (!audio || typeof audio === 'string') {
    return json({ error: 'No recibí el audio. Prueba de nuevo o escribe.' }, 400);
  }
  const salida = new FormData();
  salida.append('file', audio, audio.name || 'respuesta.wav');
  salida.append('model', env.OPENAI_TRANSCRIBE_MODEL || 'whisper-1');
  salida.append('language', 'es');
  const resp = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${env.OPENAI_API_KEY}` },
    body: salida,
  });
  if (!resp.ok) return json({ error: 'No se pudo transcribir el audio' }, 502);
  const cuerpoAudio = await resp.json();
  const texto = String(cuerpoAudio.text || '').trim();
  if (!texto) {
    return json({ error: 'No se entendió el audio. Intenta otra vez o escribe tu respuesta.' }, 422);
  }
  return json({ texto });
}

async function interpretar(request, env, id) {
  const acceso = await exigirPropio(request, env, id);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  const resultado = await interpretarPersonalidad(env, {
    clave: body.clave || body.pregunta_id,
    respuesta: body.respuesta || body.mensaje || '',
    contexto: body.contexto,
    genero: acceso.usuario.genero,
  });
  if (resultado.status !== 200) return json(resultado.body, resultado.status);
  if (!resultado.body.necesita_aclaracion) {
    await env.DB.prepare(
      `INSERT INTO borrador_entrevista_personalidad (id_borrador, id_usuario, clave_pregunta, respuesta_original, puntuacion, justificacion)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT (id_usuario, clave_pregunta) DO UPDATE SET
         respuesta_original = excluded.respuesta_original, puntuacion = excluded.puntuacion,
         justificacion = excluded.justificacion, actualizado = CURRENT_TIMESTAMP`
    ).bind(
      crypto.randomUUID(), id, resultado.body.pregunta_id, resultado.body.respuesta_original,
      resultado.body.puntuacion, resultado.body.justificacion
    ).run();
  }
  return json(resultado.body);
}

async function obtenerPersonalidad(env, id) {
  const fila = await env.DB.prepare(`SELECT id_perfil_usuario, id_usuario, ${RASGOS.join(', ')}, id_mascota_match_inicial, porcentaje_match_inicial, fecha_match_inicial, fecha_actualizacion FROM personalidadusuario WHERE id_usuario = ?`).bind(id).first();
  if (!fila) return json({ existe: false });
  return json({ existe: true, ...fila });
}

async function guardarPersonalidad(request, env, id, metodo) {
  const acceso = await exigirPropio(request, env, id);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  const rasgos = body.personalidad || body;
  const valores = RASGOS.map((rasgo) => Number(rasgos[rasgo]));
  if (valores.some((valor) => !Number.isInteger(valor) || valor < 1 || valor > 5)) {
    return json({ error: 'Cada rasgo debe estar entre 1 y 5' }, 400);
  }
  const existente = await env.DB.prepare('SELECT id_perfil_usuario FROM personalidadusuario WHERE id_usuario = ?').bind(id).first();
  if (existente && metodo === 'POST') return json({ error: 'Ya registraste tu personalidad' }, 409);
  if (existente) {
    await env.DB.prepare(`UPDATE personalidadusuario SET ${RASGOS.map((rasgo) => `${rasgo} = ?`).join(', ')}, fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_usuario = ?`).bind(...valores, id).run();
  } else {
    await env.DB.prepare(`INSERT INTO personalidadusuario (id_usuario, ${RASGOS.join(', ')}) VALUES (?, ${RASGOS.map(() => '?').join(', ')})`).bind(id, ...valores).run();
  }
  return obtenerPersonalidad(env, id);
}

async function sincronizarMatch(env, id) {
  const perfil = await env.DB.prepare(`SELECT * FROM personalidadusuario WHERE id_usuario = ?`).bind(id).first();
  if (!perfil) return json({ existe: false });
  const mascotas = await env.DB.prepare(`SELECT m.nombre, m.estado_adopcion, pm.* FROM personalidadmascota pm JOIN mascota m ON m.id_mascota = pm.id_mascota`).all();
  let mejor = null;
  let porcentaje = -1;
  for (const mascota of mascotas.results) {
    if (String(mascota.estado_adopcion).toLowerCase() === 'adoptado') continue;
    const pct = compatibilidad(perfil, mascota);
    if (pct == null) continue;
    if (pct > porcentaje || (pct === porcentaje && String(mascota.nombre).localeCompare(mejor?.nombre || '', 'es') < 0)) {
      porcentaje = pct;
      mejor = mascota;
    }
  }
  if (!mejor) return json({ existe: true, match: null });
  await env.DB.prepare(
    `UPDATE personalidadusuario SET id_mascota_match_inicial = COALESCE(id_mascota_match_inicial, ?), porcentaje_match_inicial = COALESCE(porcentaje_match_inicial, ?), fecha_match_inicial = COALESCE(fecha_match_inicial, CURRENT_TIMESTAMP) WHERE id_usuario = ?`
  ).bind(mejor.id_mascota, porcentaje, id).run();
  if (porcentaje >= 75) {
    await env.DB.prepare(
      `INSERT INTO notificacion_match_usuario (id_notificacion, id_usuario, id_mascota, porcentaje_match)
       VALUES (?, ?, ?, ?) ON CONFLICT (id_usuario, id_mascota) DO NOTHING`
    ).bind(crypto.randomUUID(), id, mejor.id_mascota, porcentaje).run();
  }
  return json({ existe: true, id_mascota: mejor.id_mascota, nombre: mejor.nombre, porcentaje });
}

function compatibilidad(usuario, mascota) {
  let suma = 0;
  for (const rasgo of RASGOS) {
    const a = Number(usuario[rasgo]);
    const b = Number(mascota[rasgo]);
    if (!Number.isInteger(a) || !Number.isInteger(b)) return null;
    suma += 1 - (Math.min(4, Math.abs(a - b)) / 4);
  }
  return Math.round((suma / RASGOS.length) * 10000) / 100;
}

async function marcarReasignacion(env, id) {
  await env.DB.prepare('UPDATE personalidadusuario SET aviso_reasignacion_pendiente = 0 WHERE id_usuario = ?').bind(id).run();
  return json({ ok: true });
}

async function leerNotificacionesMatch(request, env, id) {
  const acceso = await exigirPropio(request, env, id);
  if (acceso.error) return acceso.error;
  await env.DB.prepare('UPDATE notificacion_match_usuario SET leida = 1, fecha_lectura = CURRENT_TIMESTAMP WHERE id_usuario = ?').bind(id).run();
  return json({ ok: true });
}

function voces() {
  return json({
    voces: ['marin', 'coral', 'nova', 'shimmer', 'sage', 'alloy', 'echo', 'ash', 'ballad', 'fable', 'onyx', 'verse', 'cedar'].map((id) => ({ id })),
  });
}

async function obtenerVoz(env, id) {
  const fila = await env.DB.prepare('SELECT voz_asistente FROM usuario WHERE id_usuario = ?').bind(id).first();
  return json({ voz: fila?.voz_asistente || 'marin' });
}

async function guardarVoz(request, env, id) {
  const acceso = await exigirPropio(request, env, id);
  if (acceso.error) return acceso.error;
  const body = await cuerpo(request);
  await env.DB.prepare('UPDATE usuario SET voz_asistente = ? WHERE id_usuario = ?').bind(body.voz || 'marin', id).run();
  return json({ voz: body.voz || 'marin' });
}

async function hablar(request, env, id) {
  const acceso = await exigirPropio(request, env, id);
  if (acceso.error) return acceso.error;
  if (!env.OPENAI_API_KEY) return json({ error: 'Falta OPENAI_API_KEY' }, 503);
  const body = await cuerpo(request);
  const voz = body.voz || acceso.usuario.voz_asistente || 'marin';
  const respuesta = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: { Authorization: `Bearer ${env.OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: env.OPENAI_TTS_MODEL || 'gpt-4o-mini-tts',
      voice: voz,
      input: String(body.texto || 'Hola, soy el asistente de Paw Match. Así se escucha esta voz.').slice(0, 4000),
      response_format: 'mp3',
    }),
  });
  if (!respuesta.ok) return json({ error: 'No se pudo generar la voz' }, 502);
  return new Response(respuesta.body, { headers: { 'Content-Type': 'audio/mpeg' } });
}

async function exigirPropio(request, env, id) {
  const acceso = await exigirUsuario(request, env);
  if (acceso.error) return acceso;
  if (acceso.usuario.id_usuario !== id && !esAdmin(acceso.usuario.rol)) {
    return { error: json({ error: 'Solo puedes modificar tu propia cuenta' }, 403) };
  }
  return acceso;
}
