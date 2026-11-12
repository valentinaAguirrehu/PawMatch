import * as correos from './src/correos.js';

const base = 'http://127.0.0.1:8787';
const clave = 'Prueba#2026';
const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64',
);
const resultados = [];

function encabezados(token, json = true) {
  const headers = { 'X-Paw-Client': 'native' };
  if (json) headers['Content-Type'] = 'application/json';
  if (token) headers.Authorization = `Bearer ${token}`;
  return headers;
}

async function llamar(ruta, opciones = {}, intento = 0) {
  try {
    const respuesta = await fetch(`${base}${ruta}`, {
      method: opciones.method || 'GET',
      headers: opciones.form ? encabezados(opciones.token, false) : encabezados(opciones.token, opciones.body != null),
      body: opciones.form || (opciones.body == null ? undefined : JSON.stringify(opciones.body)),
    });
    const texto = await respuesta.text();
    let data = null;
    try { data = texto ? JSON.parse(texto) : null; } catch { data = texto; }
    return { status: respuesta.status, data, headers: respuesta.headers };
  } catch (error) {
    if (intento < 5) {
      await new Promise((resolver) => setTimeout(resolver, 1000));
      return llamar(ruta, opciones, intento + 1);
    }
    throw error;
  }
}

function archivo(nombre) {
  return new File([png], nombre, { type: 'image/png' });
}

function anotar(nombre, ok, detalle) {
  resultados.push({ nombre, ok, detalle });
  console.log(`${ok ? 'OK' : 'FALLO'} ${nombre}${detalle ? ` — ${detalle}` : ''}`);
}

async function entrar(correo, recordar = false) {
  const respuesta = await llamar('/api/usuarios/login', {
    method: 'POST',
    body: { correo, contrasena: clave, recordar },
  });
  return respuesta;
}

const plantillaDenuncia = correos.denunciaAdmin({ radicado: 'PM-PRUEBA' });
const revelaCaso = /telefono|descripcion|reportante|barrio/i.test(`${plantillaDenuncia.texto}\n${plantillaDenuncia.html}`);
anotar(
  'plantilla de denuncia no revela el caso (simulado, no es un envío real)',
  plantillaDenuncia.asunto.includes('Nueva denuncia') && plantillaDenuncia.texto.includes('no se incluyen') && !revelaCaso,
  plantillaDenuncia.asunto,
);

const marca = Date.now();
const correoNuevo = `fase3.${marca}@example.com`;

const web = await fetch(`${base}/api/usuarios/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ correo: 'admin.prueba@example.com', contrasena: clave, recordar: true }),
});
const webBody = await web.json();
const cookie = web.headers.get('set-cookie') || '';
anotar('login web sin token en JSON', web.status === 200 && !webBody.sesion && !webBody.contrasena_hash, `status ${web.status}`);
anotar('recordar sesión usa 30 días', cookie.includes('Max-Age=2592000') && cookie.includes('HttpOnly'), 'cookie HttpOnly con vigencia de 30 días');

const primera = await entrar('admin.prueba@example.com', false);
const tokenA = primera.data?.sesion;
anotar('login nativo', primera.status === 200 && typeof tokenA === 'string' && !primera.data.contrasena_hash, `status ${primera.status}`);
const sesionA = await llamar('/api/usuarios/sesion', { token: tokenA });
anotar('sesión activa', sesionA.status === 200 && sesionA.data?.correo === 'admin.prueba@example.com', `status ${sesionA.status}`);

const segunda = await entrar('admin.prueba@example.com', false);
const tokenB = segunda.data?.sesion;
anotar('segunda sesión distinta', segunda.status === 200 && tokenB && tokenB !== tokenA, `status ${segunda.status}`);

const logout = await llamar('/api/usuarios/logout', { method: 'POST', token: tokenA });
anotar('logout', logout.status === 200, `status ${logout.status}`);
const revocada = await llamar('/api/usuarios/sesion', { token: tokenA });
anotar('sesión revocada responde 401', revocada.status === 401, `status ${revocada.status}`);
const otra = await llamar('/api/usuarios/sesion', { token: tokenB });
anotar('la otra sesión sigue activa', otra.status === 200, `status ${otra.status}`);

const { execSync } = await import('node:child_process');
execSync(
  `npx wrangler d1 execute pawmatch --local --command "UPDATE sesion SET expira = '2000-01-01T00:00:00.000Z' WHERE id_usuario = '${primera.data.id_usuario}' AND revocada = 0"`,
  { stdio: 'pipe', shell: true },
);
await new Promise((resolver) => setTimeout(resolver, 1500));
const vencida = await llamar('/api/usuarios/sesion', { token: tokenB });
anotar('sesión expirada responde 401', vencida.status === 401, `status ${vencida.status}`);

const admin = await entrar('admin.prueba@example.com', false);
const tokenAdmin = admin.data?.sesion;
anotar('nuevo login después de expirar', admin.status === 200 && tokenAdmin, `status ${admin.status}`);

const registro = await llamar('/api/usuarios/registro', {
  method: 'POST',
  body: {
    nombres: 'Fase',
    apellidos: 'Tres',
    correo: correoNuevo,
    telefono: '3000000000',
    contrasena: clave,
    fecha_nacimiento: '2000-01-01',
    genero: 'Hombre',
  },
});
anotar('registro', registro.status === 201, `status ${registro.status} ${registro.data?.error || ''}`);
const usuario = await entrar(correoNuevo, true);
const tokenUsuario = usuario.data?.sesion;
anotar('login del usuario nuevo', usuario.status === 200 && tokenUsuario && !usuario.data.contrasena_hash, `status ${usuario.status}`);
const correoAjeno = `fase3.ajeno.${marca}@example.com`;
const registroAjeno = await llamar('/api/usuarios/registro', {
  method: 'POST',
  body: {
    nombres: 'Ajeno',
    apellidos: 'Prueba',
    correo: correoAjeno,
    telefono: '3000000001',
    contrasena: clave,
    fecha_nacimiento: '2000-01-01',
    genero: 'Mujer',
  },
});
const ajeno = await entrar(correoAjeno, false);
const tokenAjeno = ajeno.data?.sesion;
anotar('otro usuario para probar accesos ajenos', registroAjeno.status === 201 && ajeno.status === 200 && tokenAjeno, `status ${registroAjeno.status}/${ajeno.status}`);

const mascotas = await llamar('/api/mascotas');
anotar('listar mascotas', mascotas.status === 200 && Array.isArray(mascotas.data), `status ${mascotas.status}`);
const perfil = await llamar(`/api/usuarios/${usuario.data.id_usuario}`, { token: tokenUsuario });
anotar('perfil', perfil.status === 200 && perfil.data?.correo === correoNuevo, `status ${perfil.status}`);
const personalidad = await llamar(`/api/usuarios/${usuario.data.id_usuario}/personalidad`, { token: tokenUsuario });
anotar('personalidad', personalidad.status === 200, `status ${personalidad.status}`);

const noticias = await llamar('/api/noticias', { token: tokenUsuario });
const idNoticia = Array.isArray(noticias.data) ? noticias.data[0]?.id_noticia : noticias.data?.noticias?.[0]?.id_noticia;
const like = idNoticia
  ? await llamar(`/api/noticias/${idNoticia}/like`, { method: 'POST', token: tokenUsuario })
  : { status: 0, data: { error: 'sin noticias' } };
anotar('me gusta de noticia', like.status === 200, `status ${like.status}`);
anotar('listar noticias', noticias.status === 200, `status ${noticias.status}`);

const resumen = await llamar('/api/adoption-requests/notificaciones/resumen', { token: tokenUsuario });
anotar('resumen de adopciones', resumen.status === 200, `status ${resumen.status}`);

const creadaAdopcion = await llamar('/api/mascotas', {
  method: 'POST',
  token: tokenAdmin,
  body: { nombre: `Nube ${marca}`, especie: 'Perro', sexo: 'Hembra', edad: 2, tamano: 'Mediano', unidad_edad: 'anos' },
});
const creadaPadrino = await llamar('/api/mascotas', {
  method: 'POST',
  token: tokenAdmin,
  body: { nombre: `Sol ${marca}`, especie: 'Gato', sexo: 'Macho', edad: 1, tamano: 'Pequeño', unidad_edad: 'anos' },
});
anotar('crear mascotas de prueba', creadaAdopcion.status === 200 && creadaPadrino.status === 200, `${creadaAdopcion.status}/${creadaPadrino.status}`);

const formAdopcion = new FormData();
formAdopcion.set('id_mascota', creadaAdopcion.data.id_mascota);
formAdopcion.set('tipo_vivienda', 'Casa');
formAdopcion.set('tiene_patio', '1');
formAdopcion.set('tiene_ninos', '0');
formAdopcion.set('tiene_mascotas', '0');
formAdopcion.set('experiencia_previa', '1');
formAdopcion.set('tiempo_disponible', 'Varias horas al día');
formAdopcion.set('informacion_adicional', 'Quiero adoptar y cuidar a esta mascota en casa.');
formAdopcion.set('foto_cedula', archivo('cedula.png'));
formAdopcion.set('foto_servicios_publicos', archivo('recibo.png'));
const adopcion = await llamar('/api/adoption-requests', { method: 'POST', token: tokenUsuario, form: formAdopcion });
anotar('solicitud de adopción', adopcion.status === 201 && adopcion.data?.correo_enviado === false, `status ${adopcion.status} correo ${adopcion.data?.correo_enviado}`);

const aprobarUsuario = await llamar(`/api/adoption-requests/${adopcion.data?.id_solicitud_adopcion}/status`, {
  method: 'PUT',
  token: tokenUsuario,
  body: { estado: 'aprobada' },
});
anotar('usuario no aprueba adopciones', aprobarUsuario.status === 403, `status ${aprobarUsuario.status}`);
const aprobarAdmin = await llamar(`/api/adoption-requests/${adopcion.data?.id_solicitud_adopcion}/status`, {
  method: 'PUT',
  token: tokenAdmin,
  body: { estado: 'aprobada' },
});
anotar('administrador aprueba adopción', aprobarAdmin.status === 200, `status ${aprobarAdmin.status}`);
anotar('aprobación sin Resend no dice que el correo salió (simulado)', aprobarAdmin.data?.correo_enviado === false, `correo ${aprobarAdmin.data?.correo_enviado}`);
const repetirAprobacion = await llamar(`/api/adoption-requests/${adopcion.data?.id_solicitud_adopcion}/status`, {
  method: 'PUT',
  token: tokenAdmin,
  body: { estado: 'aprobada' },
});
anotar('repetir la aprobación no vuelve a marcar el correo como enviado', repetirAprobacion.status === 200 && repetirAprobacion.data?.correo_enviado === false, `correo ${repetirAprobacion.data?.correo_enviado}`);

const formSeguimiento = new FormData();
formSeguimiento.set('id_solicitud_adopcion', adopcion.data.id_solicitud_adopcion);
formSeguimiento.set('observaciones', 'La mascota está bien.');
formSeguimiento.set('calificacion', '5');
formSeguimiento.set('cumplimiento', '1');
formSeguimiento.set('foto_estado', archivo('estado.png'));
const seguimiento = await llamar('/api/seguimiento-adopcion', { method: 'POST', token: tokenAdmin, form: formSeguimiento });
anotar('seguimiento de adopción', seguimiento.status === 201, `status ${seguimiento.status} ${seguimiento.data?.error || ''}`);
const rutaSeguimiento = seguimiento.data?.foto_estado;
const seguimientoPublico = rutaSeguimiento ? await fetch(`${base}${rutaSeguimiento}`) : { status: 0 };
const seguimientoAnonimo = rutaSeguimiento ? await fetch(`${base}/api/archivos/${rutaSeguimiento.replace(/^\/uploads\//, '')}`) : { status: 0 };
const seguimientoAdmin = rutaSeguimiento ? await llamar(`/api/archivos/${rutaSeguimiento.replace(/^\/uploads\//, '')}`, { token: tokenAdmin }) : { status: 0 };
const seguimientoAjeno = rutaSeguimiento ? await llamar(`/api/archivos/${rutaSeguimiento.replace(/^\/uploads\//, '')}`, { token: tokenAjeno }) : { status: 0 };
const seguimientoDueno = rutaSeguimiento ? await llamar(`/api/archivos/${rutaSeguimiento.replace(/^\/uploads\//, '')}`, { token: tokenUsuario }) : { status: 0 };
anotar('la URL pública antigua del seguimiento no sirve el archivo', seguimientoPublico.status === 404, `status ${seguimientoPublico.status}`);
anotar('seguimiento privado exige sesión', seguimientoAnonimo.status === 401, `status ${seguimientoAnonimo.status}`);
anotar('el administrador ve la foto de seguimiento', seguimientoAdmin.status === 200, `status ${seguimientoAdmin.status}`);
anotar('el dueño ve su foto de seguimiento', seguimientoDueno.status === 200, `status ${seguimientoDueno.status}`);
anotar('otro usuario no ve la foto de seguimiento', seguimientoAjeno.status === 403, `status ${seguimientoAjeno.status}`);
const activos = await llamar('/api/seguimiento-adopcion/activos', { token: tokenAdmin });
const estaActiva = Array.isArray(activos.data) && activos.data.some((fila) => fila.id_solicitud_adopcion === adopcion.data.id_solicitud_adopcion);
anotar('adopciones activas', activos.status === 200 && estaActiva, `status ${activos.status}`);

const formPadrino = new FormData();
formPadrino.set('id_mascota', creadaPadrino.data.id_mascota);
formPadrino.set('informacion_adicional', 'Quiero ayudar con alimento y cuidados.');
formPadrino.set('acuerdo_responsabilidad', 'true');
formPadrino.set('documento', archivo('documento.png'));
const padrino = await llamar('/api/solicitudes-apadrinamiento', { method: 'POST', token: tokenUsuario, form: formPadrino });
anotar('solicitud de apadrinamiento', padrino.status === 201, `status ${padrino.status} ${padrino.data?.error || ''}`);
const aprobarPadrino = await llamar(`/api/solicitudes-apadrinamiento/${padrino.data?.id_solicitud_apadrinamiento}/estado`, {
  method: 'PUT',
  token: tokenAdmin,
  body: { estado: 'aprobada' },
});
anotar('aprobar apadrinamiento', aprobarPadrino.status === 200, `status ${aprobarPadrino.status}`);
anotar('aprobación de apadrinamiento sin Resend no dice que el correo salió (simulado)', aprobarPadrino.data?.correo_enviado === false, `correo ${aprobarPadrino.data?.correo_enviado}`);
let ultimoSeguimiento = null;
for (let numero = 1; numero <= 3; numero += 1) {
  ultimoSeguimiento = await llamar('/api/seguimiento-apadrinamiento', {
    method: 'POST',
    token: tokenAdmin,
    body: {
      id_solicitud_apadrinamiento: padrino.data?.id_solicitud_apadrinamiento,
      cumplimiento: 0,
      calificacion: 1,
      observaciones: `Incumplimiento de prueba ${numero}`,
    },
  });
}
anotar('tres incumplimientos no marcan el correo como enviado sin Resend (simulado)', ultimoSeguimiento.status === 201 && ultimoSeguimiento.data?.correo_alerta_enviado === false, `status ${ultimoSeguimiento.status} correo ${ultimoSeguimiento.data?.correo_alerta_enviado}`);
const marcaAlerta = execSync(
  `npx wrangler d1 execute pawmatch --local --command "SELECT correo_alerta_enviado AS marca FROM seguimientoapadrinamiento WHERE id_seguimiento_apadrinacion = '${ultimoSeguimiento.data?.id_seguimiento_apadrinacion}'" --json`,
  { encoding: 'utf8', shell: true },
);
anotar('el fallo de Resend no deja la alerta como enviada', /"marca"\s*:\s*0/.test(marcaAlerta), 'marca local 0');

const formDenuncia = new FormData();
formDenuncia.set('nombre_reportante', 'Persona Prueba');
formDenuncia.set('telefono_reportante', '3001112233');
formDenuncia.set('tipo_reporte', 'Maltrato');
formDenuncia.set('tipo_animal', 'Perro');
formDenuncia.set('descripcion_caso', 'Reporte de prueba local, sin datos reales.');
formDenuncia.set('acepto_politica', '1');
formDenuncia.set('archivos', archivo('prueba-denuncia.png'));
const denuncia = await llamar('/api/denuncias', { method: 'POST', form: formDenuncia });
anotar('denuncia', denuncia.status === 201, `status ${denuncia.status} ${denuncia.data?.error || ''}`);
anotar('denuncia sin Resend no dice que avisó al administrador (simulado)', denuncia.data?.correo_enviado === false, `correo ${denuncia.data?.correo_enviado}`);
const conteo = await llamar('/api/denuncias/conteo-pendientes', { token: tokenAdmin });
anotar('conteo de denuncias', conteo.status === 200 && Number(conteo.data?.no_leidas) >= 1, JSON.stringify(conteo.data));

const foto = new FormData();
foto.set('foto', archivo('mascota.png'));
const subida = await llamar('/api/mascotas/foto', { method: 'POST', token: tokenAdmin, form: foto });
const rutaFoto = subida.data?.ruta;
const publica = rutaFoto ? await fetch(`${base}${rutaFoto}`) : { status: 0 };
anotar('foto pública de mascota', subida.status === 201 && publica.status === 200, `status ${subida.status}/${publica.status}`);
const fotoMala = new FormData();
fotoMala.set('foto', new File([png], 'archivo.exe', { type: 'application/octet-stream' }));
const extensionMala = await llamar('/api/mascotas/foto', { method: 'POST', token: tokenAdmin, form: fotoMala });
anotar('rechaza un archivo con extensión no permitida', extensionMala.status === 400, `status ${extensionMala.status}`);
const mascotaFoto = await llamar('/api/mascotas', {
  method: 'POST',
  token: tokenAdmin,
  body: { nombre: `Foto ${marca}`, especie: 'Perro', fotos: rutaFoto },
});
const borrada = await llamar(`/api/mascotas/${mascotaFoto.data?.id_mascota}`, { method: 'DELETE', token: tokenAdmin });
const despues = rutaFoto ? await fetch(`${base}${rutaFoto}`) : { status: 0 };
anotar('eliminar mascota borra la foto en R2', borrada.status === 200 && despues.status === 404, `delete ${borrada.status} lectura ${despues.status}`);

const listas = await llamar('/api/adoption-requests', { token: tokenAdmin });
const solicitud = Array.isArray(listas.data) ? listas.data.find((fila) => fila.id_solicitud_adopcion === adopcion.data.id_solicitud_adopcion) : null;
const cedulaPublica = solicitud?.foto_cedula ? await fetch(`${base}${solicitud.foto_cedula}`) : { status: 0 };
const cedulaPrivada = await llamar(`/api/adoption-requests/${adopcion.data.id_solicitud_adopcion}/id-card`, { token: tokenUsuario });
anotar('cédula no es pública', cedulaPublica.status === 404, `status ${cedulaPublica.status}`);
anotar('cédula visible para el dueño', cedulaPrivada.status === 200, `status ${cedulaPrivada.status}`);

const formContrato = new FormData();
formContrato.set('contrato', archivo('contrato.png'));
const contrato = await llamar(`/api/adoption-requests/${adopcion.data.id_solicitud_adopcion}/contrato`, {
  method: 'POST',
  token: tokenAdmin,
  form: formContrato,
});
const rutaContrato = contrato.data?.contrato_adopcion_archivo;
const contratoPublico = rutaContrato ? await fetch(`${base}${rutaContrato}`) : { status: 0 };
const contratoPrivado = await llamar(`/api/adoption-requests/${adopcion.data.id_solicitud_adopcion}/contrato`, { token: tokenAdmin });
const quitar = await llamar(`/api/adoption-requests/${adopcion.data.id_solicitud_adopcion}/contrato`, { method: 'DELETE', token: tokenAdmin });
const contratoBorrado = await llamar(`/api/adoption-requests/${adopcion.data.id_solicitud_adopcion}/contrato`, { token: tokenAdmin });
anotar('contrato privado y eliminado de R2', contrato.status === 200 && contratoPublico.status === 404 && contratoPrivado.status === 200 && quitar.status === 200 && contratoBorrado.status === 404, `alta ${contrato.status} público ${contratoPublico.status} privado ${contratoPrivado.status} delete ${quitar.status} luego ${contratoBorrado.status}`);
anotar('el contrato no anuncia envío si Resend no está configurado (simulado)', contrato.data?.correo_enviado === false, `correo ${contrato.data?.correo_enviado}`);

const denunciaPublica = await fetch(`${base}/uploads/denuncias/no-existe.png`);
anotar('denuncias no tienen ruta pública', denunciaPublica.status === 404, `status ${denunciaPublica.status}`);
const detalleDenuncia = await llamar(`/api/denuncias/${denuncia.data?.id_denuncia}`, { token: tokenAdmin });
const archivoDenuncia = Array.isArray(detalleDenuncia.data?.archivos) ? detalleDenuncia.data.archivos[0] : null;
const rutaDenuncia = archivoDenuncia?.ruta_archivo;
const denunciaUsuario = rutaDenuncia ? await llamar(`/api/archivos/${rutaDenuncia.replace(/^\/uploads\//, '')}`, { token: tokenUsuario }) : { status: 0 };
const denunciaRutaAntigua = rutaDenuncia ? await fetch(`${base}${rutaDenuncia}`) : { status: 0 };
const denunciaAdmin = rutaDenuncia ? await llamar(`/api/archivos/${rutaDenuncia.replace(/^\/uploads\//, '')}`, { token: tokenAdmin }) : { status: 0 };
anotar('un usuario normal no abre el archivo de una denuncia', denunciaUsuario.status === 403, `status ${denunciaUsuario.status}`);
anotar('la URL pública antigua de la denuncia no sirve el archivo', denunciaRutaAntigua.status === 404, `status ${denunciaRutaAntigua.status}`);
anotar('el administrador abre el archivo de la denuncia', denunciaAdmin.status === 200, `status ${denunciaAdmin.status}`);
const reintento = await llamar(`/api/denuncias/${denuncia.data?.id_denuncia}/reintentar-correo`, { method: 'POST', token: tokenAdmin });
anotar('reintentar la denuncia sin Resend responde 503 (simulado, no es un envío real)', reintento.status === 503 && reintento.data?.correo_enviado === false, `status ${reintento.status}`);
const formCancelacion = new FormData();
formCancelacion.set('motivo', 'Cambio de planes');
formCancelacion.set('observacion', 'La persona ya no puede cuidar a la mascota en casa.');
formCancelacion.set('foto_1', archivo('cancelacion.png'));
const cancelacion = await llamar(`/api/seguimiento-adopcion/${adopcion.data.id_solicitud_adopcion}/cancelar`, {
  method: 'POST',
  token: tokenAdmin,
  form: formCancelacion,
});
const rutaCancelacion = cancelacion.data?.foto_1;
const cancelacionPublica = rutaCancelacion ? await fetch(`${base}${rutaCancelacion}`) : { status: 0 };
const cancelacionAjena = rutaCancelacion ? await llamar(`/api/archivos/${rutaCancelacion.replace(/^\/uploads\//, '')}`, { token: tokenAjeno }) : { status: 0 };
const cancelacionAdmin = rutaCancelacion ? await llamar(`/api/archivos/${rutaCancelacion.replace(/^\/uploads\//, '')}`, { token: tokenAdmin }) : { status: 0 };
anotar('cancelación de adopción privada', cancelacion.status === 201 && cancelacionPublica.status === 404 && cancelacionAdmin.status === 200 && cancelacionAjena.status === 403, `alta ${cancelacion.status} público ${cancelacionPublica.status} admin ${cancelacionAdmin.status} ajeno ${cancelacionAjena.status}`);
const formFinal = new FormData();
formFinal.set('motivo', 'Incumplimiento del acuerdo de apadrinamiento');
formFinal.set('observacion', 'No entregó los aportes acordados durante el seguimiento.');
formFinal.set('fecha_cancelacion', '2026-11-10');
formFinal.set('foto', archivo('evidencia-padrino.png'));
const finalizado = await llamar(`/api/seguimiento-apadrinamiento/${padrino.data.id_solicitud_apadrinamiento}/finalizar`, {
  method: 'POST',
  token: tokenAdmin,
  form: formFinal,
});
const rutaFinal = finalizado.data?.foto_cancelacion;
const finalPublico = rutaFinal ? await fetch(`${base}${rutaFinal}`) : { status: 0 };
const finalAjeno = rutaFinal ? await llamar(`/api/archivos/${rutaFinal.replace(/^\/uploads\//, '')}`, { token: tokenAjeno }) : { status: 0 };
const finalAdmin = rutaFinal ? await llamar(`/api/archivos/${rutaFinal.replace(/^\/uploads\//, '')}`, { token: tokenAdmin }) : { status: 0 };
anotar('cancelación de apadrinamiento privada', finalizado.status === 201 && finalPublico.status === 404 && finalAdmin.status === 200 && finalAjeno.status === 403, `alta ${finalizado.status} público ${finalPublico.status} admin ${finalAdmin.status} ajeno ${finalAjeno.status}`);

const olvide = await llamar('/api/usuarios/olvide-contrasena', {
  method: 'POST',
  body: { correo: correoNuevo },
});
anotar('recuperación sin Resend responde 503', olvide.status === 503 && olvide.data?.correo_enviado === false, `status ${olvide.status}`);

const textoInterpretar = `respuesta unica ${marca} que no debe guardarse`;
const interpretar = await llamar(`/api/usuarios/${usuario.data.id_usuario}/personalidad/interpretar`, {
  method: 'POST',
  token: tokenUsuario,
  body: { clave: 'nivel_energia', respuesta: textoInterpretar, puntuacion: 9 },
});
const borrador = await llamar(`/api/usuarios/${usuario.data.id_usuario}/personalidad/entrevista`, { token: tokenUsuario });
const guardoCliente = Array.isArray(borrador.data?.respuestas) && borrador.data.respuestas.some((fila) => fila.respuesta_original === textoInterpretar || fila.puntuacion === 9);
anotar('interpretar sin OpenAI responde 503 y no guarda la nota del cliente', interpretar.status === 503 && !guardoCliente, `status ${interpretar.status}`);

const lunaVacia = await llamar('/api/mascotas/entrevista-luna', {
  method: 'POST',
  token: tokenAdmin,
  body: { mensaje: '', reiniciar: true, ficha: {}, historial: [] },
});
anotar('Luna saluda sin OpenAI', lunaVacia.status === 200 && lunaVacia.data?.entrevista_completada === false && Array.isArray(lunaVacia.data?.campos_faltantes) && lunaVacia.data.campos_faltantes.length > 0 && /peludito/i.test(lunaVacia.data.mensaje || ''), `status ${lunaVacia.status}`);
const lunaMensaje = await llamar('/api/mascotas/entrevista-luna', {
  method: 'POST',
  token: tokenAdmin,
  body: { mensaje: 'Se llama Nube y es una perrita', ficha: {}, historial: [] },
});
anotar('Luna con mensaje y sin OpenAI responde 503', lunaMensaje.status === 503 && lunaMensaje.data?.entrevista_completada !== true, `status ${lunaMensaje.status}`);

const inactivar = await llamar(`/api/admin/usuarios/${usuario.data.id_usuario}/estado`, {
  method: 'PATCH',
  token: tokenAdmin,
  body: { estado_cuenta: 'inactivo', comentarios: 'Cuenta creada solo para la prueba local.' },
});
anotar('inactivar usuario', inactivar.status === 200, `status ${inactivar.status}`);
const sesionInactiva = await llamar('/api/usuarios/sesion', { token: tokenUsuario });
anotar('cuenta inactiva ya no entra', sesionInactiva.status === 401, `status ${sesionInactiva.status}`);

const fallos = resultados.filter((item) => !item.ok);
console.log(`\n${resultados.length - fallos.length}/${resultados.length} pruebas pasaron.`);
if (fallos.length) process.exit(1);
