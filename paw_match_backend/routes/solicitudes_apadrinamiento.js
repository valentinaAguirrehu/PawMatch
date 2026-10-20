const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { randomUUID } = require('crypto');
const pool = require('../db');
const { enviarCorreoAprobacionApadrinamiento } = require('../utils/correo');

const router = express.Router();

// Carpeta privada para documentos de identidad (NO servida públicamente)
const privateUploadsDir = path.join(__dirname, '..', 'private_uploads', 'documentos_apadrinamiento');
fs.mkdirSync(privateUploadsDir, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: privateUploadsDir,
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
      cb(null, `doc_${randomUUID()}${ext}`);
    },
  }),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB máximo
});

/**
 * Valida la identidad del usuario en PostgreSQL.
 * Comprueba que el usuario exista y tenga la cuenta activa.
 */
async function autenticarUsuario(req) {
  const userId = req.header('x-usuario-id') || req.query.usuario_id;
  if (!userId) return null;

  try {
    const res = await pool.query(
      'SELECT id_usuario, rol, estado_cuenta, nombres, apellidos, correo FROM usuario WHERE id_usuario = $1',
      [userId]
    );
    if (res.rows.length === 0) return null;
    const u = res.rows[0];
    if (u.estado_cuenta !== 'activo') return null;
    return u;
  } catch (err) {
    console.error('Error autenticando usuario:', err);
    return null;
  }
}

/**
 * Middleware para exigir que el solicitante sea un administrador activo.
 */
async function requireAdmin(req, res, next) {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión con una cuenta activa' });
  }
  if (usuario.rol !== 'administrador') {
    return res.status(403).json({ error: 'Solo un administrador puede realizar esta acción' });
  }
  req.usuarioActual = usuario;
  next();
}

/**
 * POST /api/solicitudes-apadrinamiento
 * Crear nueva solicitud de apadrinamiento con documento adjunto.
 */
router.post('/', upload.single('documento'), async (req, res) => {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    // Si se subió un archivo pero no está autenticado, lo eliminamos por seguridad
    if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    return res.status(401).json({ error: 'Debes iniciar sesión para apadrinar' });
  }

  const { id_mascota, monto_aporte, frecuencia_aporte, informacion_adicional, acuerdo_responsabilidad } = req.body;

  if (!id_mascota) {
    if (req.file) fs.unlinkSync(req.file.path);
    return res.status(400).json({ error: 'Debes seleccionar una mascota' });
  }

  const motivacion = (informacion_adicional || '').trim();
  if (!motivacion) {
    if (req.file) fs.unlinkSync(req.file.path);
    return res.status(400).json({ error: 'Debes responder por qué quieres apadrinar a esta mascota' });
  }

  if (motivacion.length > 500) {
    if (req.file) fs.unlinkSync(req.file.path);
    return res.status(400).json({ error: 'La motivación no puede exceder los 500 caracteres' });
  }

  const acuerdoAceptado = acuerdo_responsabilidad === true || acuerdo_responsabilidad === 'true';
  if (!acuerdoAceptado) {
    if (req.file) fs.unlinkSync(req.file.path);
    return res.status(400).json({ error: 'Debes aceptar el acuerdo de responsabilidad' });
  }

  if (!req.file) {
    return res.status(400).json({ error: 'Debes adjuntar la fotografía de tu documento de identidad' });
  }

  try {
    // Verificar que la mascota existe
    const petCheck = await pool.query(
      'SELECT id_mascota, nombre, estado_adopcion FROM mascota WHERE id_mascota = $1',
      [id_mascota]
    );
    if (petCheck.rows.length === 0) {
      if (req.file) fs.unlinkSync(req.file.path);
      return res.status(404).json({ error: 'La mascota seleccionada no existe' });
    }
    if (petCheck.rows[0].estado_adopcion === 'adoptado') {
      if (req.file) fs.unlinkSync(req.file.path);
      return res.status(409).json({
        error: 'Esta mascota ya fue adoptada y no se puede apadrinar',
      });
    }

    // Verificar si ya tiene una solicitud pendiente o aprobada para esta mascota
    const existe = await pool.query(
      `SELECT id_solicitud_apadrinamiento, estado
       FROM solicitudapadrinamiento
       WHERE id_usuario = $1 AND id_mascota = $2 AND estado IN ('pendiente', 'aprobada')`,
      [usuario.id_usuario, id_mascota]
    );

    if (existe.rows.length > 0) {
      if (req.file) fs.unlinkSync(req.file.path);
      const est = existe.rows[0].estado;
      return res.status(409).json({
        error: est === 'aprobada'
          ? 'Ya eres padrino de esta mascota'
          : 'Ya tienes una solicitud pendiente para esta mascota',
      });
    }

    const monto = monto_aporte ? parseInt(monto_aporte, 10) : null;
    const frecuencia = (frecuencia_aporte || 'mensual').trim();
    const archivoDoc = req.file.filename;

    const insercion = await pool.query(
      `INSERT INTO solicitudapadrinamiento (
        id_usuario,
        id_mascota,
        monto_aporte,
        frecuencia_aporte,
        informacion_adicional,
        documento_identidad_archivo,
        acuerdo_responsabilidad,
        fecha_acuerdo_responsabilidad,
        estado,
        leido_admin,
        leido_usuario
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), 'pendiente', false, true)
      RETURNING *`,
      [usuario.id_usuario, id_mascota, monto, frecuencia, motivacion, archivoDoc, true]
    );

    res.status(201).json({
      mensaje: 'Solicitud de apadrinamiento enviada exitosamente',
      solicitud: insercion.rows[0],
    });
  } catch (err) {
    if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    console.error('Error creando solicitud de apadrinamiento:', err);
    res.status(500).json({ error: 'Error interno al registrar la solicitud' });
  }
});

/**
 * GET /api/solicitudes-apadrinamiento/notificaciones/resumen
 * Retorna conteo de notificaciones pendientes para admin y usuario.
 */
router.get('/notificaciones/resumen', async (req, res) => {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }

  try {
    let totalAdmin = 0;
    if (usuario.rol === 'administrador') {
      const adminCount = await pool.query(
        "SELECT COUNT(*)::int AS total FROM solicitudapadrinamiento WHERE leido_admin = false AND estado = 'pendiente'"
      );
      totalAdmin = adminCount.rows[0].total || 0;
    }

    const userCount = await pool.query(
      "SELECT COUNT(*)::int AS total FROM solicitudapadrinamiento WHERE id_usuario = $1 AND leido_usuario = false AND estado IN ('aprobada', 'rechazada')",
      [usuario.id_usuario]
    );
    const totalUsuario = userCount.rows[0].total || 0;

    res.set('Cache-Control', 'no-store');
    res.json({ totalAdmin, totalUsuario });
  } catch (err) {
    console.error('Error obteniendo resumen notificaciones apadrinamiento:', err);
    res.status(500).json({ error: 'Error consultando notificaciones' });
  }
});

/**
 * PUT /api/solicitudes-apadrinamiento/notificaciones/marcar-admin
 * Marca como leídas las solicitudes pendientes por el admin.
 */
router.put('/notificaciones/marcar-admin', requireAdmin, async (req, res) => {
  try {
    await pool.query("UPDATE solicitudapadrinamiento SET leido_admin = true WHERE leido_admin = false");
    res.json({ ok: true });
  } catch (err) {
    console.error('Error al marcar notificaciones de admin:', err);
    res.status(500).json({ error: 'Error al marcar notificaciones' });
  }
});

/**
 * PUT /api/solicitudes-apadrinamiento/notificaciones/marcar-usuario
 * Marca como leídas las respuestas de solicitudes para el usuario logueado.
 */
router.put('/notificaciones/marcar-usuario', async (req, res) => {
  const usuario = await autenticarUsuario(req);
  if (!usuario) return res.status(401).json({ error: 'No autorizado' });

  try {
    await pool.query(
      "UPDATE solicitudapadrinamiento SET leido_usuario = true WHERE id_usuario = $1 AND leido_usuario = false",
      [usuario.id_usuario]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error('Error al marcar notificaciones de usuario:', err);
    res.status(500).json({ error: 'Error al marcar notificaciones' });
  }
});

/**
 * GET /api/solicitudes-apadrinamiento
 * Lista solicitudes:
 * - Si es admin y no pide mis_solicitudes: lista todas (permite ?estado=pendiente|aprobada|rechazada).
 * - Si es usuario normal o pide mis_solicitudes: lista solo las del usuario logueado.
 */
router.get('/', async (req, res) => {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }

  const esAdmin = usuario.rol === 'administrador';
  const soloMias = req.query.mis_solicitudes === 'true' || !esAdmin;

  try {
    let query = `
      SELECT 
        s.id_solicitud_apadrinamiento,
        s.id_usuario,
        s.id_mascota,
        to_char(s.fecha_solicitud, 'YYYY-MM-DD HH24:MI:SS') AS fecha_solicitud,
        s.monto_aporte,
        s.frecuencia_aporte,
        s.informacion_adicional,
        s.estado,
        s.observaciones,
        to_char(s.fecha_actualizacion_estado, 'YYYY-MM-DD HH24:MI:SS') AS fecha_actualizacion_estado,
        s.documento_identidad_archivo,
        s.acuerdo_responsabilidad,
        to_char(s.fecha_acuerdo_responsabilidad, 'YYYY-MM-DD HH24:MI:SS') AS fecha_acuerdo_responsabilidad,
        to_char(s.fecha_inicio_apadrinamiento, 'YYYY-MM-DD') AS fecha_inicio_apadrinamiento,
        s.leido_admin,
        s.leido_usuario,
        u.nombres AS solicitante_nombres,
        u.apellidos AS solicitante_apellidos,
        u.correo AS solicitante_correo,
        u.telefono AS solicitante_telefono,
        u.direccion AS solicitante_direccion,
        u.documento_identidad AS solicitante_cedula,
        m.nombre AS mascota_nombre,
        m.especie AS mascota_especie,
        m.raza AS mascota_raza,
        m.edad AS mascota_edad,
        m.fotos AS mascota_fotos,
        m.estado_apadrinamiento AS mascota_estado_apadrinamiento
      FROM solicitudapadrinamiento s
      INNER JOIN usuario u ON u.id_usuario = s.id_usuario
      INNER JOIN mascota m ON m.id_mascota = s.id_mascota
    `;

    const params = [];

    if (soloMias) {
      params.push(usuario.id_usuario);
      query += ` WHERE s.id_usuario = $1`;
      if (req.query.mascota_id) {
        params.push(req.query.mascota_id);
        query += ` AND s.id_mascota = $2`;
      }
      query += ` ORDER BY s.fecha_solicitud DESC`;
    } else {
      if (req.query.estado) {
        params.push(req.query.estado);
        query += ` WHERE s.estado = $1`;
      }
      query += ` ORDER BY s.fecha_solicitud DESC`;
    }

    const resultado = await pool.query(query, params);
    res.set('Cache-Control', 'no-store');
    res.json(resultado.rows);
  } catch (err) {
    console.error('Error listando solicitudes de apadrinamiento:', err);
    res.status(500).json({ error: 'No se pudieron consultar las solicitudes' });
  }
});

/**
 * GET /api/solicitudes-apadrinamiento/:id/documento
 * Acceso SEGURO a la fotografía del documento de identidad.
 * Valida estrictamente en base de datos que el solicitante sea admin o el dueño.
 */
router.get('/:id/documento', async (req, res) => {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión para consultar este documento' });
  }

  try {
    const solicitudRes = await pool.query(
      `SELECT id_solicitud_apadrinamiento, id_usuario, documento_identidad_archivo
       FROM solicitudapadrinamiento
       WHERE id_solicitud_apadrinamiento = $1`,
      [req.params.id]
    );

    if (solicitudRes.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const sol = solicitudRes.rows[0];

    // Regla de seguridad: Solo admin o el dueño de la solicitud
    const esDuenio = sol.id_usuario === usuario.id_usuario;
    const esAdmin = usuario.rol === 'administrador';

    if (!esAdmin && !esDuenio) {
      return res.status(403).json({ error: 'No tienes autorización para ver este documento confidencial' });
    }

    if (!sol.documento_identidad_archivo) {
      return res.status(404).json({ error: 'No hay documento adjunto para esta solicitud' });
    }

    const filePath = path.join(privateUploadsDir, sol.documento_identidad_archivo);
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ error: 'El archivo físico del documento no fue encontrado' });
    }

    // Transmitir archivo de manera privada
    res.sendFile(filePath);
  } catch (err) {
    console.error('Error al servir documento:', err);
    res.status(500).json({ error: 'Error consultando el documento' });
  }
});

/**
 * PUT /api/solicitudes-apadrinamiento/:id/estado
 * Aprobación o rechazo de la solicitud por parte del administrador.
 */
router.put('/:id/estado', requireAdmin, async (req, res) => {
  const { estado, fecha_inicio_apadrinamiento, observaciones } = req.body;

  if (!['aprobada', 'rechazada'].includes(estado)) {
    return res.status(400).json({ error: "El estado debe ser 'aprobada' o 'rechazada'" });
  }

  try {
    // Verificar solicitud actual
    const actualRes = await pool.query(
      `SELECT s.id_solicitud_apadrinamiento, s.estado, s.id_usuario, s.id_mascota,
              u.nombres, u.apellidos, u.correo,
              m.nombre AS nombre_mascota, m.estado_adopcion
       FROM solicitudapadrinamiento s
       JOIN usuario u ON u.id_usuario = s.id_usuario
       JOIN mascota m ON m.id_mascota = s.id_mascota
       WHERE s.id_solicitud_apadrinamiento = $1`,
      [req.params.id]
    );

    if (actualRes.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const sol = actualRes.rows[0];

    if (estado === 'aprobada' && sol.estado_adopcion === 'adoptado') {
      return res.status(409).json({
        error: 'Esta mascota ya fue adoptada y no se puede apadrinar',
      });
    }

    if (sol.estado === 'aprobada' && estado === 'aprobada') {
      return res.json({
        mensaje: 'La solicitud ya se encuentra aprobada',
        solicitud: sol,
      });
    }

    let fechaInicioFinal = null;
    if (estado === 'aprobada') {
      fechaInicioFinal = fecha_inicio_apadrinamiento || new Date().toISOString().split('T')[0];
    }

    // Actualizar solicitud
    const updateRes = await pool.query(
      `UPDATE solicitudapadrinamiento
       SET estado = $1,
           fecha_actualizacion_estado = NOW(),
           fecha_inicio_apadrinamiento = $2,
           observaciones = $3,
           leido_usuario = false
       WHERE id_solicitud_apadrinamiento = $4
       RETURNING *`,
      [estado, fechaInicioFinal, observaciones || null, req.params.id]
    );

    // Si se aprueba, marcar mascota como apadrinada
    if (estado === 'aprobada') {
      await pool.query(
        "UPDATE mascota SET estado_apadrinamiento = 'apadrinado' WHERE id_mascota = $1",
        [sol.id_mascota]
      );

      // Obtener teléfono/whatsapp oficial de la fundación
      let whatsappFundacion = '573136177747';
      try {
        const fundRes = await pool.query('SELECT telefono FROM informacionfundacion LIMIT 1');
        if (fundRes.rows.length > 0 && fundRes.rows[0].telefono) {
          whatsappFundacion = fundRes.rows[0].telefono.replace(/\D/g, '');
        }
      } catch (_) {}

      // Enviar correo de notificación (solo tras guardarse en BD y sin duplicar)
      enviarCorreoAprobacionApadrinamiento({
        destinatario: sol.correo,
        nombreUsuario: `${sol.nombres} ${sol.apellidos}`.trim(),
        nombreMascota: sol.nombre_mascota,
        fechaInicio: fechaInicioFinal,
        whatsappFundacion,
        observaciones: observaciones || null,
      }).catch(err => console.error('Error al enviar correo en background:', err));
    }

    res.json({
      mensaje: `Solicitud ${estado} exitosamente`,
      solicitud: updateRes.rows[0],
    });
  } catch (err) {
    console.error('Error actualizando estado de solicitud:', err);
    res.status(500).json({ error: 'Error interno al actualizar la solicitud' });
  }
});

module.exports = router;
