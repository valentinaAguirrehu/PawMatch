const base = 'http://127.0.0.1:8787';
const clave = 'Prueba#2026';
const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64',
);
const resultados = [];

function anotar(nombre, ok, detalle) {
  resultados.push({ nombre, ok });
  console.log(`${ok ? 'OK' : 'FALLO'} ${nombre}${detalle ? ` — ${detalle}` : ''}`);
}

async function llamar(ruta, opciones = {}) {
  const headers = { 'X-Paw-Client': 'native' };
  if (opciones.token) headers.Authorization = `Bearer ${opciones.token}`;
  if (!opciones.form && opciones.body != null) headers['Content-Type'] = 'application/json';
  const respuesta = await fetch(`${base}${ruta}`, {
    method: opciones.method || 'GET',
    headers,
    body: opciones.form || (opciones.body == null ? undefined : JSON.stringify(opciones.body)),
  });
  const texto = await respuesta.text();
  let data = null;
  try { data = texto ? JSON.parse(texto) : null; } catch { data = null; }
  return { status: respuesta.status, data };
}

const admin = await llamar('/api/usuarios/login', {
  method: 'POST',
  body: { correo: 'admin.prueba@example.com', contrasena: clave },
});
const token = admin.data?.sesion;
anotar('login para pruebas de archivo', admin.status === 200 && token, `status ${admin.status}`);

const permitida = new FormData();
permitida.set('foto', new File([png], 'dentro.png', { type: 'image/png' }));
const ok = await llamar('/api/mascotas/foto', { method: 'POST', token, form: permitida });
const publica = ok.data?.ruta ? await fetch(`${base}${ok.data.ruta}`) : { status: 0 };
anotar('archivo permitido dentro del límite', ok.status === 201 && publica.status === 200, `status ${ok.status}/${publica.status}`);

const prohibida = new FormData();
prohibida.set('foto', new File([png], 'archivo.exe', { type: 'application/octet-stream' }));
const extension = await llamar('/api/mascotas/foto', { method: 'POST', token, form: prohibida });
anotar('extensión prohibida', extension.status === 400 && !extension.data?.ruta, `status ${extension.status}`);

const mime = new FormData();
mime.set('foto', new File([png], 'falso.png', { type: 'text/html' }));
const tipo = await llamar('/api/mascotas/foto', { method: 'POST', token, form: mime });
anotar('MIME incorrecto', tipo.status === 400 && !tipo.data?.ruta, `status ${tipo.status}`);

const vacio = new FormData();
vacio.set('foto', new File([], 'vacio.png', { type: 'image/png' }));
const vacia = await llamar('/api/mascotas/foto', { method: 'POST', token, form: vacio });
anotar('archivo vacío', vacia.status === 400 && !vacia.data?.ruta, `status ${vacia.status}`);

const grande = new FormData();
grande.set('foto', new File([Buffer.alloc(10 * 1024 * 1024 + 1)], 'grande.png', { type: 'image/png' }));
const exceso = await llamar('/api/mascotas/foto', { method: 'POST', token, form: grande });
anotar('archivo por encima de 10 MB', exceso.status === 400 && !exceso.data?.ruta, `status ${exceso.status}`);

const marca = Date.now();
const correo = `archivos.${marca}@example.com`;
await llamar('/api/usuarios/registro', {
  method: 'POST',
  body: {
    nombres: 'Archivo', apellidos: 'Prueba', correo, telefono: '3000000099',
    contrasena: clave, fecha_nacimiento: '2000-01-01', genero: 'Mujer',
  },
});
const usuario = await llamar('/api/usuarios/login', { method: 'POST', body: { correo, contrasena: clave } });
const mascota = await llamar('/api/mascotas', {
  method: 'POST', token, body: { nombre: `Archivo ${marca}`, especie: 'Perro' },
});
const form = new FormData();
form.set('id_mascota', mascota.data.id_mascota);
form.set('tipo_vivienda', 'Casa');
form.set('tiene_patio', '1');
form.set('tiene_ninos', '0');
form.set('tiene_mascotas', '0');
form.set('experiencia_previa', '1');
form.set('tiempo_disponible', 'Varias horas al día');
form.set('informacion_adicional', 'Quiero adoptar y cuidar a esta mascota en casa.');
form.set('foto_cedula', new File([png], 'cedula.png', { type: 'image/png' }));
form.set('foto_servicios_publicos', new File([png], 'recibo.png', { type: 'image/png' }));
const adopcion = await llamar('/api/adoption-requests', { method: 'POST', token: usuario.data.sesion, form });
await llamar(`/api/adoption-requests/${adopcion.data.id_solicitud_adopcion}/status`, {
  method: 'PUT', token, body: { estado: 'aprobada' },
});
const primero = new FormData();
primero.set('contrato', new File([png], 'contrato-a.png', { type: 'image/png' }));
const alta = await llamar(`/api/adoption-requests/${adopcion.data.id_solicitud_adopcion}/contrato`, {
  method: 'POST', token, form: primero,
});
const rutaVieja = alta.data?.contrato_adopcion_archivo;
const segundo = new FormData();
segundo.set('contrato', new File([png], 'contrato-b.png', { type: 'image/png' }));
const reemplazo = await llamar(`/api/adoption-requests/${adopcion.data.id_solicitud_adopcion}/contrato`, {
  method: 'POST', token, form: segundo,
});
const rutaNueva = reemplazo.data?.contrato_adopcion_archivo;
const viejoPublico = await fetch(`${base}${rutaVieja}`);
const viejoPrivado = await llamar(`/api/adoption-requests/${adopcion.data.id_solicitud_adopcion}/contrato`, { token });
const fallo = new FormData();
fallo.set('contrato', new File([], 'contrato-vacio.png', { type: 'image/png' }));
const rechazo = await llamar(`/api/adoption-requests/${adopcion.data.id_solicitud_adopcion}/contrato`, {
  method: 'POST', token, form: fallo,
});
const sigue = await llamar(`/api/adoption-requests/${adopcion.data.id_solicitud_adopcion}/contrato`, { token });
anotar(
  'reemplazar contrato borra el anterior y un rechazo no lo quita',
  alta.status === 200 && reemplazo.status === 200 && rutaNueva && rutaNueva !== rutaVieja
    && viejoPublico.status === 404 && viejoPrivado.status === 200
    && rechazo.status === 400 && sigue.status === 200,
  `alta ${alta.status} reemplazo ${reemplazo.status} público ${viejoPublico.status} rechazo ${rechazo.status} sigue ${sigue.status}`,
);
anotar('el reemplazo no dice que envió correo sin Resend', reemplazo.data?.correo_enviado === false, `correo ${reemplazo.data?.correo_enviado}`);

await llamar(`/api/admin/usuarios/${usuario.data.id_usuario}/estado`, {
  method: 'PATCH', token, body: { estado_cuenta: 'inactivo', comentarios: 'Cuenta de prueba de archivos.' },
});

const fallos = resultados.filter((item) => !item.ok);
console.log(`\n${resultados.length - fallos.length}/${resultados.length} pruebas de archivo pasaron.`);
if (fallos.length) process.exit(1);
