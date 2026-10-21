const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { randomUUID } = require('crypto');
const pool = require('../db');
const {
  enviarCorreoAprobacionApadrinamiento,
  enviarCorreoRechazoApadrinamiento,
} = require('../utils/correo');

const router = express.Router();

// Carpeta privada para documentos de identidad (NO servida públicamente)
const privateUploadsDir = path.join(__dirname, '..', 'private_uploads', 'documentos_apadrinamiento');
fs.mkdirSync(privateUploadsDir, { recursive: true });

// Carpeta privada para contratos de apadrinamiento (NO servida públicamente)
const contratosDir = path.join(__dirname, '..', 'private_uploads', 'contratos_apadrinamiento');
fs.mkdirSync(contratosDir, { recursive: true });

// Garantiza las columnas contrato_apadrinamiento_archivo, veces_rechazada y correo_contacto en PostgreSQL
pool.query(`
  ALTER TABLE solicitudapadrinamiento
    ADD COLUMN IF NOT EXISTS contrato_apadrinamiento_archivo TEXT,
    ADD COLUMN IF NOT EXISTS veces_rechazada INTEGER DEFAULT 1,
    ADD COLUMN IF NOT EXISTS correo_contacto TEXT
`).catch(err => console.error('Error preparando tabla solicitudapadrinamiento:', err.message));

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

const uploadContrato = multer({
  storage: multer.diskStorage({
    destination: contratosDir,
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase() || '.pdf';
      cb(null, `contrato_${randomUUID()}${ext}`);
    },
  }),
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.pdf'].includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Formato no permitido. Solo se aceptan archivos JPG, PNG o PDF'));
    }
  },
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB máximo
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

  const { id_mascota, monto_aporte, frecuencia_aporte, informacion_adicional, acuerdo_responsabilidad, correo_contacto } = req.body;

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
    const correoFinal = (correo_contacto || usuario.correo || '').trim();

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
        leido_usuario,
        correo_contacto
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), 'pendiente', false, true, $8)
      RETURNING *`,
      [usuario.id_usuario, id_mascota, monto, frecuencia, motivacion, archivoDoc, true, correoFinal]
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
      "SELECT COUNT(*)::int AS total FROM solicitudapadrinamiento WHERE id_usuario = $1 AND leido_usuario = false AND estado IN ('aprobada', 'rechazada', 'cancelada')",
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
        s.contrato_apadrinamiento_archivo,
        s.acuerdo_responsabilidad,
        to_char(s.fecha_acuerdo_responsabilidad, 'YYYY-MM-DD HH24:MI:SS') AS fecha_acuerdo_responsabilidad,
        to_char(s.fecha_inicio_apadrinamiento, 'YYYY-MM-DD') AS fecha_inicio_apadrinamiento,
        s.leido_admin,
        s.leido_usuario,
        GREATEST(
          COALESCE(s.veces_rechazada, 1),
          (
            SELECT COUNT(*)::int
            FROM solicitudapadrinamiento sr
            WHERE sr.id_usuario = s.id_usuario
              AND sr.id_mascota = s.id_mascota
              AND sr.estado = 'rechazada'
          )
        ) AS veces_rechazada,
        u.nombres AS solicitante_nombres,
        u.apellidos AS solicitante_apellidos,
        COALESCE(s.correo_contacto, u.correo) AS solicitante_correo,
        s.correo_contacto,
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
   * POST /api/solicitudes-apadrinamiento/:id/contrato
   * El administrador sube el contrato de apadrinamiento firmado.
   */
  router.post('/:id/contrato', requireAdmin, uploadContrato.single('contrato'), async (req, res) => {
    if (!req.file) {
      return res.status(400).json({ error: 'Debes adjuntar el archivo del contrato' });
    }

    try {
      const solicitudRes = await pool.query(
        `SELECT s.id_solicitud_apadrinamiento, s.estado, s.contrato_apadrinamiento_archivo
         FROM solicitudapadrinamiento s
         WHERE s.id_solicitud_apadrinamiento = $1`,
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

      // Si ya existía un contrato anterior, lo reemplazamos
      if (sol.contrato_apadrinamiento_archivo) {
        const viejo = path.join(contratosDir, sol.contrato_apadrinamiento_archivo);
        if (fs.existsSync(viejo)) fs.unlinkSync(viejo);
      }

      const updateRes = await pool.query(
        `UPDATE solicitudapadrinamiento
         SET contrato_apadrinamiento_archivo = $1,
             leido_usuario = false
         WHERE id_solicitud_apadrinamiento = $2
         RETURNING *`,
        [req.file.filename, req.params.id]
      );

      res.json({
        mensaje: 'Contrato de apadrinamiento subido exitosamente',
        contrato_archivo: req.file.filename,
        solicitud: updateRes.rows[0],
      });
    } catch (err) {
      if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      console.error('Error al subir contrato:', err);
      res.status(500).json({ error: 'Error al subir el contrato' });
    }
  });

  /**
   * GET /api/solicitudes-apadrinamiento/:id/contrato
   * Descarga o visualización segura del contrato de apadrinamiento.
   */
  router.get('/:id/contrato', async (req, res) => {
    const usuario = await autenticarUsuario(req);
    if (!usuario) {
      return res.status(401).json({ error: 'Debes iniciar sesión para consultar este contrato' });
    }

    try {
      const solicitudRes = await pool.query(
        `SELECT id_solicitud_apadrinamiento, id_usuario, contrato_apadrinamiento_archivo
         FROM solicitudapadrinamiento
         WHERE id_solicitud_apadrinamiento = $1`,
        [req.params.id]
      );

      if (solicitudRes.rows.length === 0) {
        return res.status(404).json({ error: 'Solicitud no encontrada' });
      }

      const sol = solicitudRes.rows[0];
      const esDuenio = sol.id_usuario === usuario.id_usuario;
      const esAdmin = usuario.rol === 'administrador';

      if (!esAdmin && !esDuenio) {
        return res.status(403).json({ error: 'No tienes autorización para ver este contrato' });
      }

      if (!sol.contrato_apadrinamiento_archivo) {
        return res.status(404).json({ error: 'Aún no se ha subido el contrato de apadrinamiento' });
      }

      const filePath = path.join(contratosDir, sol.contrato_apadrinamiento_archivo);
      if (!fs.existsSync(filePath)) {
        return res.status(404).json({ error: 'El archivo físico del contrato no fue encontrado' });
      }

      res.sendFile(filePath);
    } catch (err) {
      console.error('Error al servir contrato:', err);
      res.status(500).json({ error: 'Error consultando el contrato' });
    }
  });

  /**
   * DELETE /api/solicitudes-apadrinamiento/:id/contrato
   * POST   /api/solicitudes-apadrinamiento/:id/contrato/eliminar
   * El administrador elimina el contrato de apadrinamiento.
   */
  const eliminarContratoHandler = async (req, res) => {
    try {
      const solicitudRes = await pool.query(
        `SELECT id_solicitud_apadrinamiento, contrato_apadrinamiento_archivo
         FROM solicitudapadrinamiento
         WHERE id_solicitud_apadrinamiento = $1`,
        [req.params.id]
      );

      if (solicitudRes.rows.length === 0) {
        return res.status(404).json({ error: 'Solicitud no encontrada' });
      }

      const sol = solicitudRes.rows[0];
      if (sol.contrato_apadrinamiento_archivo) {
        const filePath = path.join(contratosDir, sol.contrato_apadrinamiento_archivo);
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
        }
      }

      const updateRes = await pool.query(
        `UPDATE solicitudapadrinamiento
         SET contrato_apadrinamiento_archivo = NULL,
             leido_usuario = false
         WHERE id_solicitud_apadrinamiento = $1
         RETURNING *`,
        [req.params.id]
      );

      res.json({
        ok: true,
        mensaje: 'Contrato de apadrinamiento eliminado exitosamente',
        solicitud: updateRes.rows[0],
      });
    } catch (err) {
      console.error('Error al eliminar contrato:', err);
      res.status(500).json({ error: 'Error al eliminar el contrato' });
    }
  };

  router.delete('/:id/contrato', requireAdmin, eliminarContratoHandler);
  router.post('/:id/contrato/eliminar', requireAdmin, eliminarContratoHandler);

  /**
   * PUT /api/solicitudes-apadrinamiento/:id/estado
   * Aprobación, rechazo o cancelación de la solicitud por parte del administrador.
   */
  router.put('/:id/estado', requireAdmin, async (req, res) => {
    const { estado, fecha_inicio_apadrinamiento, observaciones } = req.body;

    if (!['aprobada', 'rechazada', 'cancelada'].includes(estado)) {
      return res.status(400).json({ error: "El estado debe ser 'aprobada', 'rechazada' o 'cancelada'" });
    }

    if (estado === 'cancelada') {
      const motivo = (observaciones || '').toString().trim();
      if (!motivo) {
        return res.status(400).json({ error: 'Debes indicar el motivo de la cancelación' });
      }
    }

    try {
      // Verificar solicitud actual
      const actualRes = await pool.query(
        `SELECT s.id_solicitud_apadrinamiento, s.estado, s.id_usuario, s.id_mascota,
                s.correo_contacto,
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
      let updateSql = `
        UPDATE solicitudapadrinamiento
        SET estado = $1,
            fecha_actualizacion_estado = NOW(),
            fecha_inicio_apadrinamiento = COALESCE($2, fecha_inicio_apadrinamiento),
            observaciones = $3,
            leido_usuario = false
      `;
      if (estado === 'rechazada') {
        updateSql += `, veces_rechazada = COALESCE(veces_rechazada, 0) + 1`;
      }
      updateSql += ` WHERE id_solicitud_apadrinamiento = $4 RETURNING *`;

      const updateRes = await pool.query(
        updateSql,
        [estado, fechaInicioFinal, observaciones || null, req.params.id]
      );

      // Obtener teléfono/whatsapp oficial de la fundación
      let whatsappFundacion = '573136177747';
      try {
        const fundRes = await pool.query('SELECT telefono FROM informacionfundacion LIMIT 1');
        if (fundRes.rows.length > 0 && fundRes.rows[0].telefono) {
          whatsappFundacion = fundRes.rows[0].telefono.replace(/\D/g, '');
        }
      } catch (_) {}

      // Correo del destinatario (prioriza el correo confirmado en la solicitud si existe)
      const correoDestino = (sol.correo_contacto && sol.correo_contacto.trim().length > 0)
        ? sol.correo_contacto.trim()
        : sol.correo;
      const nombreUsuario = `${sol.nombres} ${sol.apellidos}`.trim() || 'Estimado/a Padrino';

      // Si se aprueba, marcar mascota como apadrinada y notificar por correo
      if (estado === 'aprobada') {
        await pool.query(
          "UPDATE mascota SET estado_apadrinamiento = 'apadrinado' WHERE id_mascota = $1",
          [sol.id_mascota]
        );

        // Enviar correo de aprobación
        if (correoDestino) {
          enviarCorreoAprobacionApadrinamiento({
            destinatario: correoDestino,
            nombreUsuario,
            nombreMascota: sol.nombre_mascota,
            fechaInicio: fechaInicioFinal,
            whatsappFundacion,
            observaciones: observaciones || null,
          }).catch(err => console.error('Error al enviar correo de aprobación:', err));
        }
      } else if (estado === 'rechazada') {
        // Enviar correo de rechazo informando la decisión y motivo
        if (correoDestino) {
          enviarCorreoRechazoApadrinamiento({
            destinatario: correoDestino,
            nombreUsuario,
            nombreMascota: sol.nombre_mascota,
            whatsappFundacion,
            observaciones: observaciones || null,
          }).catch(err => console.error('Error al enviar correo de rechazo:', err));
        }
      } else if (estado === 'cancelada') {
        // Al cancelar, verificar si la mascota todavía tiene alguna otra solicitud aprobada
        const otrasAprobadas = await pool.query(
          `SELECT id_solicitud_apadrinamiento FROM solicitudapadrinamiento
           WHERE id_mascota = $1 AND estado = 'aprobada' AND id_solicitud_apadrinamiento <> $2`,
          [sol.id_mascota, req.params.id]
        );
        if (otrasAprobadas.rows.length === 0) {
          // No tiene otros padrinos activos, vuelve a estar disponible para apadrinar
          await pool.query(
            "UPDATE mascota SET estado_apadrinamiento = 'disponible' WHERE id_mascota = $1",
            [sol.id_mascota]
          );
        }
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
