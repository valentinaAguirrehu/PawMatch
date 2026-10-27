const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { randomUUID } = require('crypto');
const pool = require('../db');
const { esAdministrador } = require('../utils/roles');
const {
  enviarCorreoAprobacionAdopcion,
  enviarCorreoRechazoAdopcion,
  enviarCorreoContratoAdopcion,
  enviarCorreoVerificacionSolicitud,
} = require('../utils/correo');

const router = express.Router();

// Iguala la tabla con Apadrinamiento: observaciones, lecturas y fecha de inicio.
const esquemaListo = (async () => {
  await pool.query(`
    ALTER TABLE solicitudadopcion
      ADD COLUMN IF NOT EXISTS observaciones TEXT,
      ADD COLUMN IF NOT EXISTS leido_admin BOOLEAN NOT NULL DEFAULT false,
      ADD COLUMN IF NOT EXISTS leido_usuario BOOLEAN NOT NULL DEFAULT true,
      ADD COLUMN IF NOT EXISTS fecha_inicio_adopcion DATE,
      ADD COLUMN IF NOT EXISTS fecha_actualizacion_estado TIMESTAMP,
      ADD COLUMN IF NOT EXISTS correo_contacto TEXT,
      ADD COLUMN IF NOT EXISTS contrato_adopcion_archivo TEXT,
      ADD COLUMN IF NOT EXISTS contrato_adopcion_estado TEXT,
      ADD COLUMN IF NOT EXISTS contrato_adopcion_subido_en TIMESTAMP,
      ADD COLUMN IF NOT EXISTS estado_correo TEXT DEFAULT 'pendiente',
      ADD COLUMN IF NOT EXISTS token_verificacion_correo TEXT,
      ADD COLUMN IF NOT EXISTS fecha_verificacion_correo TIMESTAMP,
      ADD COLUMN IF NOT EXISTS acepto_requisitos BOOLEAN DEFAULT true,
      ADD COLUMN IF NOT EXISTS fecha_aceptacion_requisitos TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  `);
  await pool.query(`
    UPDATE solicitudadopcion
    SET contrato_adopcion_estado = 'pendiente'
    WHERE estado = 'aprobada'
      AND (contrato_adopcion_archivo IS NULL OR btrim(contrato_adopcion_archivo) = '')
      AND (contrato_adopcion_estado IS NULL OR btrim(contrato_adopcion_estado) = '')
  `);
})().catch((err) => {
  console.error('No se pudo preparar la tabla solicitudadopcion:', err.message);
  throw err;
});

router.use(async (_req, res, next) => {
  try {
    await esquemaListo;
    next();
  } catch (_) {
    res.status(500).json({
      error: 'La tabla SolicitudAdopcion no coincide con el esquema esperado.',
    });
  }
});

const privateUploadsDir = path.join(__dirname, '..', 'private_uploads', 'documentos_adopcion');
fs.mkdirSync(privateUploadsDir, { recursive: true });

const contratosDir = path.join(__dirname, '..', 'private_uploads', 'contratos_adopcion');
fs.mkdirSync(contratosDir, { recursive: true });

const extensiones = new Set(['.jpg', '.jpeg', '.png', '.webp', '.pdf']);
const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const upload = multer({
  storage: multer.diskStorage({
    destination: privateUploadsDir,
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase();
      const safeExt = extensiones.has(ext) ? ext : '.jpg';
      const prefijo = file.fieldname === 'foto_cedula' ? 'cedula' : 'recibo';
      cb(null, `${prefijo}_${randomUUID()}${safeExt}`);
    },
  }),
  limits: { fileSize: 10 * 1024 * 1024, files: 2 },
  fileFilter: (_req, file, cb) => {
    const mimeOk = /^image\/(jpeg|jpg|png|webp)$/.test(file.mimetype) || file.mimetype === 'application/pdf';
    const ext = path.extname(file.originalname).toLowerCase();
    if (!mimeOk && !extensiones.has(ext)) {
      return cb(new Error('Solo se permiten documentos o imágenes en formato JPG, PNG, WEBP o PDF'));
    }
    cb(null, true);
  },
});

const uploadContrato = multer({
  storage: multer.diskStorage({
    destination: contratosDir,
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase();
      const permitidas = new Set(['.jpg', '.jpeg', '.png', '.pdf']);
      cb(null, `contrato_${randomUUID()}${permitidas.has(ext) ? ext : '.pdf'}`);
    },
  }),
  limits: { fileSize: 15 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.pdf'].includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Formato no permitido. Solo se aceptan archivos JPG, PNG o PDF'));
    }
  },
});

function subirContrato(req, res, next) {
  uploadContrato.single('contrato')(req, res, (err) => {
    if (!err) return next();
    if (req.file?.path && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    const mensaje = err.code === 'LIMIT_FILE_SIZE'
      ? 'El contrato debe pesar máximo 15 MB'
      : (err.message || 'No se pudo subir el contrato');
    return res.status(400).json({ error: mensaje });
  });
}

function subirArchivos(req, res, next) {
  upload.fields([
    { name: 'foto_cedula', maxCount: 1 },
    { name: 'foto_servicios_publicos', maxCount: 1 },
  ])(req, res, (err) => {
    if (!err) return next();
    borrarSubidos(req.files);
    const mensaje = err.code === 'LIMIT_FILE_SIZE'
      ? 'Cada imagen debe pesar máximo 10 MB'
      : (err.message || 'No se pudieron subir las imágenes');
    return res.status(400).json({ error: mensaje });
  });
}

function borrarSubidos(files) {
  if (!files) return;
  for (const lista of Object.values(files)) {
    for (const archivo of lista || []) {
      if (archivo?.path && fs.existsSync(archivo.path)) {
        fs.unlinkSync(archivo.path);
      }
    }
  }
}

function esUuid(valor) {
  return typeof valor === 'string' && uuidRe.test(valor);
}

function leerBool(valor) {
  if (valor === true || valor === false) return valor;
  if (typeof valor !== 'string') return null;
  const texto = valor.trim().toLowerCase();
  if (['true', '1', 'si', 'sí', 'yes'].includes(texto)) return true;
  if (['false', '0', 'no'].includes(texto)) return false;
  return null;
}

function archivoEnCarpeta(carpeta, nombre) {
  if (typeof nombre !== 'string' || !nombre.trim()) return null;
  const base = path.basename(nombre.trim());
  if (base !== nombre.trim()) return null;
  const full = path.resolve(carpeta, base);
  const root = path.resolve(carpeta);
  const rootConSep = root.endsWith(path.sep) ? root : `${root}${path.sep}`;
  if (full !== root && !full.startsWith(rootConSep)) return null;
  return full;
}

function archivoPrivado(nombre) {
  return archivoEnCarpeta(privateUploadsDir, nombre);
}

function archivoContrato(nombre) {
  return archivoEnCarpeta(contratosDir, nombre);
}

async function whatsappFundacion() {
  let numero = '573136177747';
  try {
    const fundRes = await pool.query('SELECT telefono FROM informacionfundacion LIMIT 1');
    if (fundRes.rows.length > 0 && fundRes.rows[0].telefono) {
      const limpio = String(fundRes.rows[0].telefono).replace(/\D/g, '');
      if (limpio) numero = limpio;
    }
  } catch (_) {}
  return numero;
}

function errorDb(res, err, fallback) {
  console.error(fallback, err);
  if (err.code === '42P01' || err.code === '42703') {
    return res.status(500).json({
      error: 'La tabla SolicitudAdopcion no coincide con el esquema esperado.',
    });
  }
  return res.status(500).json({ error: fallback });
}

async function autenticarUsuario(req) {
  const userId = (req.header('x-usuario-id') || req.query.usuario_id || '').toString().trim();
  if (!esUuid(userId)) return null;

  try {
    const res = await pool.query(
      `SELECT id_usuario, rol, estado_cuenta, nombres, apellidos, correo
       FROM usuario WHERE id_usuario = $1`,
      [userId]
    );
    if (res.rows.length === 0) return null;
    const usuario = res.rows[0];
    if (usuario.estado_cuenta !== 'activo') return null;
    return usuario;
  } catch (err) {
    console.error('Error autenticando usuario:', err);
    return null;
  }
}

async function requireAdmin(req, res, next) {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión con una cuenta activa' });
  }
  if (!esAdministrador(usuario.rol)) {
    return res.status(403).json({ error: 'Solo un administrador puede realizar esta acción' });
  }
  req.usuarioActual = usuario;
  next();
}

const selectSolicitud = `
  SELECT
    s.id_solicitud_adopcion,
    s.id_usuario,
    s.id_mascota,
    s.tipo_vivienda,
    s.tiene_patio,
    s.tiene_ninos,
    s.tiene_mascotas,
    s.otras_mascotas,
    s.tiempo_disponible,
    s.experiencia_previa,
    s.informacion_adicional,
    (s.foto_cedula IS NOT NULL AND btrim(s.foto_cedula) <> '') AS tiene_foto_cedula,
    (s.foto_servicios_publicos IS NOT NULL AND btrim(s.foto_servicios_publicos) <> '') AS tiene_foto_recibo,
    to_char(s.fecha_solicitud, 'YYYY-MM-DD HH24:MI:SS') AS fecha_solicitud,
    s.estado,
    s.observaciones,
    to_char(s.fecha_actualizacion_estado, 'YYYY-MM-DD HH24:MI:SS') AS fecha_actualizacion_estado,
    to_char(s.fecha_inicio_adopcion, 'YYYY-MM-DD') AS fecha_inicio_adopcion,
    s.leido_admin,
    s.leido_usuario,
    s.contrato_adopcion_archivo,
    COALESCE(s.contrato_adopcion_estado, '') AS contrato_adopcion_estado,
    to_char(s.contrato_adopcion_subido_en, 'YYYY-MM-DD HH24:MI:SS') AS contrato_adopcion_subido_en,
    COALESCE(s.estado_correo, 'pendiente') AS estado_correo,
    to_char(s.fecha_verificacion_correo, 'YYYY-MM-DD HH24:MI:SS') AS fecha_verificacion_correo,
    COALESCE(s.acepto_requisitos, true) AS acepto_requisitos,
    to_char(s.fecha_aceptacion_requisitos, 'YYYY-MM-DD HH24:MI:SS') AS fecha_aceptacion_requisitos,
    s.id_administrador_revisor,
    COALESCE(u.nombres, '') AS solicitante_nombres,
    COALESCE(u.apellidos, '') AS solicitante_apellidos,
    COALESCE(NULLIF(btrim(s.correo_contacto), ''), u.correo, '') AS solicitante_correo,
    COALESCE(u.telefono, '') AS solicitante_telefono,
    COALESCE(u.direccion, '') AS solicitante_direccion,
    COALESCE(u.documento_identidad, '') AS solicitante_cedula,
    COALESCE(m.nombre, '') AS mascota_nombre,
    COALESCE(m.especie, '') AS mascota_especie,
    COALESCE(m.raza, '') AS mascota_raza,
    m.edad AS mascota_edad,
    COALESCE(m.fotos, '') AS mascota_fotos,
    COALESCE(m.estado_adopcion::text, '') AS mascota_estado_adopcion
  FROM solicitudadopcion s
  INNER JOIN usuario u ON u.id_usuario = s.id_usuario
  INNER JOIN mascota m ON m.id_mascota = s.id_mascota
`;

/**
 * POST /api/adoption-requests
 * Crea una solicitud con las respuestas del formulario y las dos fotos.
 */
router.post('/', subirArchivos, async (req, res) => {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    borrarSubidos(req.files);
    return res.status(401).json({ error: 'Debes iniciar sesión para solicitar una adopción' });
  }

  let guardada = false;
  try {
    const idMascota = (req.body.id_mascota || '').trim();
    const tipoVivienda = (req.body.tipo_vivienda || '').trim();
    const tiempoDisponible = (req.body.tiempo_disponible || '').trim();
    const informacion = (req.body.informacion_adicional || '').trim();
    const tienePatio = leerBool(req.body.tiene_patio);
    const tieneNinos = leerBool(req.body.tiene_ninos);
    const tieneMascotas = leerBool(req.body.tiene_mascotas);
    const experiencia = leerBool(req.body.experiencia_previa);
    const otrasMascotas = (req.body.otras_mascotas || '').trim();
    const cedula = req.files?.foto_cedula?.[0];
    const recibo = req.files?.foto_servicios_publicos?.[0];

    if (!esUuid(idMascota)) {
      return res.status(400).json({ error: 'Debes seleccionar una mascota' });
    }
    if (!tipoVivienda || tipoVivienda.length > 50) {
      return res.status(400).json({ error: 'Indica un tipo de vivienda válido' });
    }
    if (tienePatio === null || tieneNinos === null || tieneMascotas === null || experiencia === null) {
      return res.status(400).json({ error: 'Responde todas las preguntas del formulario' });
    }
    if (!tiempoDisponible || tiempoDisponible.length > 50) {
      return res.status(400).json({ error: 'Indica cuánto tiempo puedes dedicarle a la mascota' });
    }
    if (informacion.length < 20) {
      return res.status(400).json({
        error: 'Cuéntanos un poco más sobre por qué quieres adoptar (mínimo 20 caracteres)',
      });
    }
    if (informacion.length > 2000) {
      return res.status(400).json({ error: 'La información adicional no puede exceder los 2000 caracteres' });
    }
    if (tieneMascotas && (!otrasMascotas || otrasMascotas.length > 200)) {
      return res.status(400).json({
        error: 'Describe las otras mascotas del hogar (máximo 200 caracteres)',
      });
    }
    if (!cedula || !recibo) {
      return res.status(400).json({
        error: 'Debes adjuntar la foto de la cédula y la del recibo de servicio público',
      });
    }

    const correoIngresado = (req.body.correo_contacto || '').trim();
    const correoFinal = correoIngresado || (usuario.correo || '').trim();
    if (!correoFinal || !correoFinal.includes('@') || !correoFinal.includes('.')) {
      return res.status(400).json({
        error: 'Debes proporcionar un correo electrónico válido para recibir la respuesta',
      });
    }

    const petCheck = await pool.query(
      'SELECT id_mascota, nombre, estado_adopcion FROM mascota WHERE id_mascota = $1',
      [idMascota]
    );
    if (petCheck.rows.length === 0) {
      return res.status(404).json({ error: 'La mascota seleccionada no existe' });
    }
    const mascota = petCheck.rows[0];
    if (mascota.estado_adopcion === 'adoptado') {
      return res.status(409).json({ error: 'Esta mascota ya fue adoptada' });
    }
    if (mascota.estado_adopcion === 'en_proceso') {
      return res.status(409).json({ error: 'Esta mascota ya tiene un proceso de adopción en curso' });
    }

    const existe = await pool.query(
      `SELECT id_solicitud_adopcion, estado
       FROM solicitudadopcion
       WHERE id_usuario = $1 AND id_mascota = $2 AND estado IN ('pendiente', 'aprobada')`,
      [usuario.id_usuario, idMascota]
    );
    if (existe.rows.length > 0) {
      const est = existe.rows[0].estado;
      return res.status(409).json({
        error: est === 'aprobada'
          ? 'Ya tienes una adopción aprobada para esta mascota'
          : 'Ya tienes una solicitud pendiente para esta mascota',
      });
    }

    const tokenVerificacion = randomUUID();
    const insercion = await pool.query(
      `INSERT INTO solicitudadopcion (
        id_usuario, id_mascota, tipo_vivienda, tiene_patio, tiene_ninos,
        tiene_mascotas, otras_mascotas, tiempo_disponible, experiencia_previa,
        informacion_adicional, foto_cedula, foto_servicios_publicos, estado,
        leido_admin, leido_usuario, correo_contacto, estado_correo,
        token_verificacion_correo, acepto_requisitos
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'pendiente', false, true, $13, 'pendiente', $14, true)
      RETURNING id_solicitud_adopcion`,
      [
        usuario.id_usuario,
        idMascota,
        tipoVivienda,
        tienePatio,
        tieneNinos,
        tieneMascotas,
        tieneMascotas ? otrasMascotas : null,
        tiempoDisponible,
        experiencia,
        informacion,
        cedula.filename,
        recibo.filename,
        correoFinal,
        tokenVerificacion,
      ]
    );

    guardada = true;

    // Enviar correo de verificación en segundo plano
    enviarCorreoVerificacionSolicitud({
      destinatario: correoFinal,
      nombreUsuario: `${usuario.nombres || ''} ${usuario.apellidos || ''}`.trim() || 'Adoptante',
      nombreMascota: mascota.nombre,
      token: tokenVerificacion,
      tipo: 'adopcion',
    }).catch((err) => console.warn('[CORREO] No se pudo enviar verificación de adopción:', err.message));

    return res.status(201).json({
      mensaje: 'Solicitud de adopción enviada exitosamente',
      id_solicitud_adopcion: insercion.rows[0].id_solicitud_adopcion,
    });
  } catch (err) {
    return errorDb(res, err, 'Error interno al registrar la solicitud');
  } finally {
    if (!guardada) borrarSubidos(req.files);
  }
});

/**
 * GET /api/adoption-requests
 * Admin: todas las solicitudes. Usuario: solo las suyas.
 * Query: mine=true, pet_id, status=pendiente|aprobada|rechazada
 */
router.get('/', async (req, res) => {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }

  const esAdmin = esAdministrador(usuario.rol);
  const soloMias = req.query.mine === 'true' || req.query.mis_solicitudes === 'true' || !esAdmin;
  const estados = { pendiente: 'pendiente', aprobada: 'aprobada', rechazada: 'rechazada', cancelada: 'cancelada' };
  const estado = estados[(req.query.status || req.query.estado || '').toString().toLowerCase()];
  const petId = (req.query.pet_id || req.query.mascota_id || '').toString().trim();

  try {
    const params = [];
    const filtros = [];

    if (soloMias) {
      params.push(usuario.id_usuario);
      filtros.push(`s.id_usuario = $${params.length}`);
    }
    if (petId) {
      if (!esUuid(petId)) {
        return res.status(400).json({ error: 'La mascota indicada no es válida' });
      }
      params.push(petId);
      filtros.push(`s.id_mascota = $${params.length}`);
    }
    if (estado && !soloMias) {
      params.push(estado);
      filtros.push(`s.estado = $${params.length}`);
    }

    const where = filtros.length ? ` WHERE ${filtros.join(' AND ')}` : '';
    const resultado = await pool.query(
      `${selectSolicitud}${where} ORDER BY s.fecha_solicitud DESC`,
      params
    );
    res.set('Cache-Control', 'no-store');
    return res.json(resultado.rows);
  } catch (err) {
    return errorDb(res, err, 'No se pudieron consultar las solicitudes');
  }
});

/**
 * GET /api/adoption-requests/notificaciones/resumen
 * Conteos de solicitudes nuevas (admin) y respuestas sin leer (usuario).
 */
router.get('/notificaciones/resumen', async (req, res) => {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }

  try {
    let totalAdmin = 0;
    if (esAdministrador(usuario.rol)) {
      const adminCount = await pool.query(
        "SELECT COUNT(*)::int AS total FROM solicitudadopcion WHERE leido_admin = false AND estado = 'pendiente'"
      );
      totalAdmin = adminCount.rows[0].total || 0;
    }

    const userCount = await pool.query(
      "SELECT COUNT(*)::int AS total FROM solicitudadopcion WHERE id_usuario = $1 AND leido_usuario = false AND estado IN ('aprobada', 'rechazada')",
      [usuario.id_usuario]
    );

    res.set('Cache-Control', 'no-store');
    return res.json({
      totalAdmin,
      totalUsuario: userCount.rows[0].total || 0,
    });
  } catch (err) {
    return errorDb(res, err, 'Error consultando notificaciones');
  }
});

/**
 * PUT /api/adoption-requests/notificaciones/marcar-admin
 * El administrador ya vio las solicitudes pendientes.
 */
router.put('/notificaciones/marcar-admin', requireAdmin, async (req, res) => {
  try {
    await pool.query('UPDATE solicitudadopcion SET leido_admin = true WHERE leido_admin = false');
    return res.json({ ok: true });
  } catch (err) {
    return errorDb(res, err, 'Error al marcar notificaciones');
  }
});

/**
 * PUT /api/adoption-requests/notificaciones/marcar-usuario
 * El usuario ya vio las respuestas de sus solicitudes.
 */
router.put('/notificaciones/marcar-usuario', async (req, res) => {
  const usuario = await autenticarUsuario(req);
  if (!usuario) return res.status(401).json({ error: 'No autorizado' });

  try {
    await pool.query(
      'UPDATE solicitudadopcion SET leido_usuario = true WHERE id_usuario = $1 AND leido_usuario = false',
      [usuario.id_usuario]
    );
    return res.json({ ok: true });
  } catch (err) {
    return errorDb(res, err, 'Error al marcar notificaciones');
  }
});

function _htmlRespuestaVerificacion({ exito, titulo, mensaje }) {
  const colorBorde = exito ? '#10b981' : '#ef4444';
  const colorFondo = exito ? '#f0fdf4' : '#fef2f2';
  const colorTitulo = exito ? '#065f46' : '#991b1b';
  const colorTexto = exito ? '#047857' : '#b91c1c';
  const icono = exito ? '✅' : '⚠️';

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${titulo} - Paw Match</title>
  <style>
    body {
      font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif;
      background: #fdf2f8;
      margin: 0;
      padding: 30px 15px;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 80vh;
    }
    .card {
      max-width: 520px;
      width: 100%;
      background: #ffffff;
      border-radius: 24px;
      padding: 36px 28px;
      box-shadow: 0 10px 25px rgba(236, 72, 153, 0.12);
      border: 1px solid #fbcfe8;
      text-align: center;
    }
    .badge {
      display: inline-block;
      font-size: 48px;
      margin-bottom: 16px;
    }
    h1 {
      color: ${colorTitulo};
      font-size: 22px;
      margin: 0 0 14px 0;
      font-weight: 800;
    }
    p {
      color: #374151;
      font-size: 15px;
      line-height: 1.5;
      margin: 0 0 24px 0;
    }
    .box {
      background: ${colorFondo};
      border: 1px solid ${colorBorde};
      border-radius: 14px;
      padding: 16px;
      margin-bottom: 24px;
      color: ${colorTexto};
      font-size: 14px;
      line-height: 1.45;
    }
    .btn {
      display: inline-block;
      background: linear-gradient(135deg, #ec4899 0%, #db2777 100%);
      color: #ffffff;
      padding: 14px 30px;
      border-radius: 16px;
      text-decoration: none;
      font-weight: 700;
      font-size: 15px;
      box-shadow: 0 4px 12px rgba(236, 72, 153, 0.35);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">${icono}</div>
    <h1>${titulo}</h1>
    <div class="box">${mensaje}</div>
    <a href="/" class="btn">🐾 Ir a Paw Match</a>
  </div>
</body>
</html>`;
}

/**
 * GET /api/adoption-requests/verificar-correo
 * Verifica el correo cuando el usuario hace clic en el enlace del email.
 */
router.get('/verificar-correo', async (req, res) => {
  const token = (req.query.token || '').toString().trim();
  if (!token) {
    return res.status(400).send(_htmlRespuestaVerificacion({
      exito: false,
      titulo: 'Enlace inválido',
      mensaje: 'El enlace de verificación no contiene un token válido.',
    }));
  }

  try {
    const busqueda = await pool.query(
      `SELECT s.id_solicitud_adopcion, s.correo_contacto, s.id_usuario, m.nombre AS mascota_nombre, s.estado_correo
       FROM solicitudadopcion s
       JOIN mascota m ON m.id_mascota = s.id_mascota
       WHERE s.token_verificacion_correo = $1`,
      [token]
    );

    if (busqueda.rows.length === 0) {
      return res.status(404).send(_htmlRespuestaVerificacion({
        exito: false,
        titulo: 'Enlace no encontrado o expirado',
        mensaje: 'Este enlace de verificación ya no está disponible o ya fue utilizado.',
      }));
    }

    const sol = busqueda.rows[0];

    // Actualizar a confirmado
    await pool.query(
      `UPDATE solicitudadopcion
       SET estado_correo = 'confirmado', fecha_verificacion_correo = NOW()
       WHERE id_solicitud_adopcion = $1`,
      [sol.id_solicitud_adopcion]
    );

    // Actualizar usuario
    await pool.query(
      `UPDATE usuario SET correo_verificado = true WHERE id_usuario = $1`,
      [sol.id_usuario]
    ).catch(() => {});

    return res.send(_htmlRespuestaVerificacion({
      exito: true,
      titulo: '¡Correo confirmado exitosamente! 🎉',
      mensaje: `Tu correo <strong>${sol.correo_contacto}</strong> ha sido verificado con éxito para tu solicitud de adopción de <strong>${sol.mascota_nombre}</strong>. El estado en Paw Match se ha actualizado a <strong>«Correo confirmado»</strong>.`,
    }));
  } catch (err) {
    console.error('Error al verificar correo:', err);
    return res.status(500).send(_htmlRespuestaVerificacion({
      exito: false,
      titulo: 'Error de servidor',
      mensaje: 'Ocurrió un error inesperado al procesar la verificación.',
    }));
  }
});

/**
 * POST /api/adoption-requests/:id/reenviar-verificacion
 * Reenvía el correo de verificación para una solicitud de adopción.
 */
router.post('/:id/reenviar-verificacion', async (req, res) => {
  const usuario = await autenticarUsuario(req);
  if (!usuario) return res.status(401).json({ error: 'Debes iniciar sesión' });

  try {
    const r = await pool.query(
      `SELECT s.id_solicitud_adopcion, s.correo_contacto, s.id_usuario, s.estado_correo, s.token_verificacion_correo,
              m.nombre AS mascota_nombre, u.nombres, u.apellidos
       FROM solicitudadopcion s
       JOIN mascota m ON m.id_mascota = s.id_mascota
       JOIN usuario u ON u.id_usuario = s.id_usuario
       WHERE s.id_solicitud_adopcion = $1`,
      [req.params.id]
    );

    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const sol = r.rows[0];
    if (usuario.rol !== 'administrador' && sol.id_usuario !== usuario.id_usuario) {
      return res.status(403).json({ error: 'No tienes permiso para esta solicitud' });
    }

    let token = sol.token_verificacion_correo;
    if (!token) {
      token = randomUUID();
      await pool.query(
        'UPDATE solicitudadopcion SET token_verificacion_correo = $1 WHERE id_solicitud_adopcion = $2',
        [token, sol.id_solicitud_adopcion]
      );
    }

    const destinatario = sol.correo_contacto || usuario.correo;
    const nombreCompleto = `${sol.nombres || ''} ${sol.apellidos || ''}`.trim() || 'Adoptante';

    await enviarCorreoVerificacionSolicitud({
      destinatario,
      nombreUsuario: nombreCompleto,
      nombreMascota: sol.mascota_nombre,
      token,
      tipo: 'adopcion',
    });

    return res.json({
      mensaje: `Correo de verificación reenviado a ${destinatario}`,
    });
  } catch (err) {
    console.error('Error reenviando correo de verificación:', err);
    return res.status(500).json({ error: 'No se pudo reenviar el correo de verificación' });
  }
});

async function servirAdjunto(req, res, columna) {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión para consultar este documento' });
  }
  if (!esUuid(req.params.id)) {
    return res.status(400).json({ error: 'Solicitud inválida' });
  }

  try {
    const solicitudRes = await pool.query(
      `SELECT id_usuario, ${columna} AS archivo
       FROM solicitudadopcion
       WHERE id_solicitud_adopcion = $1`,
      [req.params.id]
    );
    if (solicitudRes.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const sol = solicitudRes.rows[0];
    const esDuenio = sol.id_usuario === usuario.id_usuario;
    const esAdmin = esAdministrador(usuario.rol);
    if (!esAdmin && !esDuenio) {
      return res.status(403).json({ error: 'No tienes autorización para ver este documento' });
    }
    if (!sol.archivo) {
      return res.status(404).json({ error: 'No hay archivo adjunto para esta solicitud' });
    }

    const filePath = archivoPrivado(sol.archivo);
    if (!filePath || !fs.existsSync(filePath)) {
      return res.status(404).json({ error: 'El archivo no fue encontrado' });
    }

    res.set('Cache-Control', 'private, no-store');
    return res.sendFile(filePath);
  } catch (err) {
    return errorDb(res, err, 'Error consultando el documento');
  }
}

router.get('/:id/id-card', (req, res) => servirAdjunto(req, res, 'foto_cedula'));
router.get('/:id/utility-bill', (req, res) => servirAdjunto(req, res, 'foto_servicios_publicos'));

/**
 * PUT /api/adoption-requests/:id/status
 * El administrador aprueba o rechaza la solicitud.
 */
function fechaIso(valor) {
  if (typeof valor !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(valor.trim())) return null;
  const texto = valor.trim();
  const fecha = new Date(`${texto}T00:00:00`);
  return Number.isNaN(fecha.getTime()) ? null : texto;
}

router.put('/:id/status', requireAdmin, async (req, res) => {
  const estado = (req.body.estado || req.body.status || '').toString().trim();
  if (!['aprobada', 'rechazada'].includes(estado)) {
    return res.status(400).json({ error: "El estado debe ser 'aprobada' o 'rechazada'" });
  }
  if (!esUuid(req.params.id)) {
    return res.status(400).json({ error: 'Solicitud inválida' });
  }

  const observaciones = (req.body.observaciones || '').toString().trim().slice(0, 500);
  let fechaInicio = null;
  if (estado === 'aprobada') {
    fechaInicio = fechaIso(req.body.fecha_inicio_adopcion || '')
      || new Date().toISOString().split('T')[0];
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const actualRes = await client.query(
      `SELECT s.id_solicitud_adopcion, s.estado, s.id_usuario, s.id_mascota,
              s.correo_contacto,
              u.nombres, u.apellidos, u.correo,
              m.nombre AS nombre_mascota, m.estado_adopcion
       FROM solicitudadopcion s
       JOIN usuario u ON u.id_usuario = s.id_usuario
       JOIN mascota m ON m.id_mascota = s.id_mascota
       WHERE s.id_solicitud_adopcion = $1
       FOR UPDATE OF s, m`,
      [req.params.id]
    );

    if (actualRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const sol = actualRes.rows[0];
    if (sol.estado !== 'pendiente') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Esta solicitud ya fue revisada' });
    }

    if (estado === 'aprobada') {
      if (sol.estado_adopcion === 'adoptado') {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Esta mascota ya figura como adoptada' });
      }
      const otra = await client.query(
        `SELECT id_solicitud_adopcion
         FROM solicitudadopcion
         WHERE id_mascota = $1 AND estado = 'aprobada' AND id_solicitud_adopcion <> $2
         LIMIT 1`,
        [sol.id_mascota, req.params.id]
      );
      if (otra.rows.length > 0) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Esta mascota ya tiene una adopción aprobada' });
      }
    }

    const updateRes = await client.query(
      `UPDATE solicitudadopcion
       SET estado = $1,
           fecha_actualizacion_estado = NOW(),
           id_administrador_revisor = $2,
           observaciones = $3,
           fecha_inicio_adopcion = $4,
           leido_usuario = false,
           contrato_adopcion_estado = CASE
             WHEN $1 = 'aprobada' THEN 'pendiente'
             ELSE contrato_adopcion_estado
           END
       WHERE id_solicitud_adopcion = $5
       RETURNING id_solicitud_adopcion, estado, observaciones,
                 to_char(fecha_inicio_adopcion, 'YYYY-MM-DD') AS fecha_inicio_adopcion`,
      [
        estado,
        req.usuarioActual.id_usuario,
        observaciones || null,
        fechaInicio,
        req.params.id,
      ]
    );

    if (estado === 'aprobada') {
      await client.query(
        `UPDATE mascota SET estado_adopcion = 'adoptado' WHERE id_mascota = $1`,
        [sol.id_mascota]
      );
    } else {
      const quedan = await client.query(
        `SELECT 1 FROM solicitudadopcion
         WHERE id_mascota = $1 AND estado IN ('pendiente', 'aprobada')
         LIMIT 1`,
        [sol.id_mascota]
      );
      if (quedan.rows.length === 0) {
        await client.query(
          `UPDATE mascota SET estado_adopcion = 'disponible'
           WHERE id_mascota = $1 AND estado_adopcion = 'en_proceso'`,
          [sol.id_mascota]
        );
      }
    }

    await client.query('COMMIT');

    const correoDestino = (sol.correo_contacto && String(sol.correo_contacto).trim().length > 0)
      ? String(sol.correo_contacto).trim()
      : String(sol.correo || '').trim();
    const nombreUsuario = `${sol.nombres || ''} ${sol.apellidos || ''}`.trim() || 'Estimado/a adoptante';

    const numeroWhatsapp = await whatsappFundacion();

    if (correoDestino) {
      const datosCorreo = {
        destinatario: correoDestino,
        nombreUsuario,
        nombreMascota: sol.nombre_mascota,
        whatsappFundacion: numeroWhatsapp,
        observaciones: observaciones || null,
      };

      if (estado === 'aprobada') {
        enviarCorreoAprobacionAdopcion({
          ...datosCorreo,
          fechaInicio,
        }).catch((err) => console.error('Error al enviar correo de aprobación de adopción:', err));
      } else if (estado === 'rechazada') {
        enviarCorreoRechazoAdopcion(datosCorreo)
          .catch((err) => console.error('Error al enviar correo de rechazo de adopción:', err));
      }
    }

    return res.json({
      mensaje: estado === 'aprobada'
        ? 'Solicitud aprobada. Quedó pendiente subir el contrato de adopción y se notificó al adoptante.'
        : 'Solicitud rechazada. Se notificó por correo al adoptante.',
      solicitud: updateRes.rows[0],
    });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {}
    return errorDb(res, err, 'Error interno al actualizar la solicitud');
  } finally {
    client.release();
  }
});

/**
 * POST /api/adoption-requests/:id/contrato
 * El administrador sube el contrato de adopción firmado.
 */
router.post('/:id/contrato', requireAdmin, subirContrato, async (req, res) => {
  if (!esUuid(req.params.id)) {
    if (req.file?.path && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    return res.status(400).json({ error: 'Solicitud inválida' });
  }
  if (!req.file) {
    return res.status(400).json({ error: 'Debes adjuntar el archivo del contrato' });
  }

  try {
    const solicitudRes = await pool.query(
      `SELECT s.id_solicitud_adopcion, s.estado, s.contrato_adopcion_archivo,
              s.correo_contacto,
              u.nombres, u.apellidos, u.correo,
              m.nombre AS nombre_mascota
       FROM solicitudadopcion s
       JOIN usuario u ON u.id_usuario = s.id_usuario
       JOIN mascota m ON m.id_mascota = s.id_mascota
       WHERE s.id_solicitud_adopcion = $1`,
      [req.params.id]
    );

    if (solicitudRes.rows.length === 0) {
      if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const sol = solicitudRes.rows[0];
    if (sol.estado !== 'aprobada') {
      if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ error: 'Solo se puede subir el contrato a solicitudes aprobadas' });
    }

    if (sol.contrato_adopcion_archivo) {
      const viejo = archivoContrato(sol.contrato_adopcion_archivo);
      if (viejo && fs.existsSync(viejo)) fs.unlinkSync(viejo);
    }

    const updateRes = await pool.query(
      `UPDATE solicitudadopcion
       SET contrato_adopcion_archivo = $1,
           contrato_adopcion_estado = 'disponible',
           contrato_adopcion_subido_en = NOW(),
           leido_usuario = false
       WHERE id_solicitud_adopcion = $2
       RETURNING contrato_adopcion_archivo,
                 contrato_adopcion_estado,
                 to_char(contrato_adopcion_subido_en, 'YYYY-MM-DD HH24:MI:SS') AS contrato_adopcion_subido_en`,
      [req.file.filename, req.params.id]
    );

    const correoDestino = (sol.correo_contacto && String(sol.correo_contacto).trim().length > 0)
      ? String(sol.correo_contacto).trim()
      : String(sol.correo || '').trim();
    const nombreUsuario = `${sol.nombres || ''} ${sol.apellidos || ''}`.trim() || 'Estimado/a adoptante';

    if (correoDestino) {
      const numeroWhatsapp = await whatsappFundacion();
      enviarCorreoContratoAdopcion({
        destinatario: correoDestino,
        nombreUsuario,
        nombreMascota: sol.nombre_mascota,
        whatsappFundacion: numeroWhatsapp,
      }).catch((err) => console.error('Error al enviar correo de contrato de adopción:', err));
    }

    return res.json({
      mensaje: 'Contrato de adopción subido. El adoptante ya puede verlo y descargarlo.',
      contrato_archivo: req.file.filename,
      contrato_estado: 'disponible',
      solicitud: updateRes.rows[0],
    });
  } catch (err) {
    if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    return errorDb(res, err, 'Error al subir el contrato');
  }
});

/**
 * GET /api/adoption-requests/:id/contrato
 * El adoptante o un administrador consulta el contrato.
 */
router.get('/:id/contrato', async (req, res) => {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión para consultar este contrato' });
  }
  if (!esUuid(req.params.id)) {
    return res.status(400).json({ error: 'Solicitud inválida' });
  }

  try {
    const solicitudRes = await pool.query(
      `SELECT id_usuario, contrato_adopcion_archivo
       FROM solicitudadopcion
       WHERE id_solicitud_adopcion = $1`,
      [req.params.id]
    );
    if (solicitudRes.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const sol = solicitudRes.rows[0];
    const esDuenio = sol.id_usuario === usuario.id_usuario;
    const esAdmin = esAdministrador(usuario.rol);
    if (!esAdmin && !esDuenio) {
      return res.status(403).json({ error: 'No tienes autorización para ver este contrato' });
    }
    if (!sol.contrato_adopcion_archivo) {
      return res.status(404).json({ error: 'Aún no se ha subido el contrato de adopción' });
    }

    const filePath = archivoContrato(sol.contrato_adopcion_archivo);
    if (!filePath || !fs.existsSync(filePath)) {
      return res.status(404).json({ error: 'El archivo físico del contrato no fue encontrado' });
    }

    res.set('Cache-Control', 'private, no-store');
    return res.sendFile(filePath);
  } catch (err) {
    return errorDb(res, err, 'Error consultando el contrato');
  }
});

/**
 * DELETE /api/adoption-requests/:id/contrato
 * POST   /api/adoption-requests/:id/contrato/eliminar
 * El administrador retira el contrato. La adopción vuelve a quedar pendiente de contrato.
 */
const eliminarContratoHandler = async (req, res) => {
  if (!esUuid(req.params.id)) {
    return res.status(400).json({ error: 'Solicitud inválida' });
  }

  try {
    const solicitudRes = await pool.query(
      `SELECT id_solicitud_adopcion, contrato_adopcion_archivo
       FROM solicitudadopcion
       WHERE id_solicitud_adopcion = $1`,
      [req.params.id]
    );
    if (solicitudRes.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const sol = solicitudRes.rows[0];
    if (sol.contrato_adopcion_archivo) {
      const filePath = archivoContrato(sol.contrato_adopcion_archivo);
      if (filePath && fs.existsSync(filePath)) fs.unlinkSync(filePath);
    }

    const updateRes = await pool.query(
      `UPDATE solicitudadopcion
       SET contrato_adopcion_archivo = NULL,
           contrato_adopcion_estado = CASE
             WHEN estado = 'aprobada' THEN 'pendiente'
             ELSE NULL
           END,
           contrato_adopcion_subido_en = NULL,
           leido_usuario = false
       WHERE id_solicitud_adopcion = $1
       RETURNING contrato_adopcion_estado`,
      [req.params.id]
    );

    return res.json({
      ok: true,
      mensaje: 'Contrato de adopción eliminado. El adoptante verá de nuevo el estado pendiente.',
      solicitud: updateRes.rows[0],
    });
  } catch (err) {
    return errorDb(res, err, 'Error al eliminar el contrato');
  }
};

router.delete('/:id/contrato', requireAdmin, eliminarContratoHandler);
router.post('/:id/contrato/eliminar', requireAdmin, eliminarContratoHandler);

module.exports = router;
