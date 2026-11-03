const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { randomUUID } = require('crypto');
const pool = require('../db');
const { enviarCorreoNuevaDenunciaAdmin } = require('../utils/correo');

const router = express.Router();

// Carpeta privada para almacenar evidencias fotográficas y en video (NO servida públicamente)
const denunciasUploadsDir = path.join(__dirname, '..', 'private_uploads', 'denuncias');
fs.mkdirSync(denunciasUploadsDir, { recursive: true });

// Inicialización de tablas en PostgreSQL
async function inicializarTablas() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS denuncia (
        id_denuncia UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        radicado VARCHAR(30) UNIQUE NOT NULL,
        id_usuario UUID REFERENCES usuario(id_usuario) ON DELETE SET NULL,
        es_anonimo BOOLEAN DEFAULT false,
        nombre_reportante VARCHAR(200),
        documento_reportante VARCHAR(50),
        correo_reportante VARCHAR(150),
        telefono_reportante VARCHAR(50),
        ciudad_reportante VARCHAR(100),
        barrio_reportante VARCHAR(100),
        tipo_reporte VARCHAR(100) NOT NULL,
        tipo_animal VARCHAR(50) NOT NULL,
        ubicacion_animal TEXT NOT NULL,
        ciudad_caso VARCHAR(100) NOT NULL,
        fecha_situacion VARCHAR(150) NOT NULL,
        peligro_inmediato VARCHAR(20) NOT NULL DEFAULT 'no',
        descripcion_caso TEXT NOT NULL,
        caracteristicas_animal TEXT,
        estado_salud TEXT,
        heridas_visibles TEXT,
        dificultad_movilidad TEXT,
        condiciones_lugar TEXT,
        observaciones_adicionales TEXT,
        acepto_politica BOOLEAN DEFAULT true,
        estado VARCHAR(50) DEFAULT 'recibido',
        leido_admin BOOLEAN DEFAULT false,
        observaciones_internas TEXT,
        acciones_realizadas TEXT,
        estado_correo VARCHAR(50) DEFAULT 'pendiente',
        error_correo TEXT,
        fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS denuncia_archivo (
        id_archivo UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        id_denuncia UUID NOT NULL REFERENCES denuncia(id_denuncia) ON DELETE CASCADE,
        nombre_original VARCHAR(255) NOT NULL,
        nombre_guardado VARCHAR(255) NOT NULL,
        ruta_archivo TEXT NOT NULL,
        tipo_mime VARCHAR(100),
        tamano_bytes BIGINT,
        es_video BOOLEAN DEFAULT false,
        fecha_subida TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS denuncia_historial (
        id_historial UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        id_denuncia UUID NOT NULL REFERENCES denuncia(id_denuncia) ON DELETE CASCADE,
        id_usuario_admin UUID REFERENCES usuario(id_usuario) ON DELETE SET NULL,
        nombre_admin VARCHAR(150),
        estado_anterior VARCHAR(50),
        estado_nuevo VARCHAR(50),
        observacion TEXT,
        fecha TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('[DENUNCIAS] Tablas de denuncias listas en PostgreSQL');
  } catch (err) {
    console.error('[DENUNCIAS ERROR] Error preparando tablas:', err.message);
  }
}
inicializarTablas();

// Configuración de Multer para archivos de evidencias (fotos y videos)
const storage = multer.diskStorage({
  destination: denunciasUploadsDir,
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `evidencia_${Date.now()}_${randomUUID().substring(0, 8)}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 25 * 1024 * 1024, // 25 MB máximo por archivo
    files: 10, // Hasta 10 archivos por denuncia
  },
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const formatosValidos = [
      '.jpg', '.jpeg', '.png', '.webp', // Imágenes
      '.mp4', '.mov', '.avi', '.mkv', '.3gp', '.webm', // Videos
    ];
    if (formatosValidos.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error(`Formato '${ext}' no permitido. Solo imágenes (JPG, PNG, WEBP) o videos (MP4, MOV, WEBM)`));
    }
  },
});

// Middleware de verificación de rol administrador
async function requireAdmin(req, res, next) {
  const userId = req.header('x-usuario-id') || req.query.adminId;
  if (!userId) {
    return res.status(401).json({ error: 'Debes iniciar sesión como administrador' });
  }

  try {
    const result = await pool.query(
      "SELECT id_usuario, nombres, apellidos, rol, estado_cuenta FROM usuario WHERE id_usuario = $1",
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Usuario no encontrado' });
    }

    const usuario = result.rows[0];
    if (usuario.rol !== 'administrador' || usuario.estado_cuenta !== 'activo') {
      return res.status(403).json({ error: 'Acceso restringido solo para personal autorizado de la Fundación Maritza Arévalo' });
    }

    req.admin = usuario;
    next();
  } catch (error) {
    console.error('[DENUNCIAS ERROR] Error validando admin:', error);
    res.status(500).json({ error: 'Error validando permisos de administrador' });
  }
}

// Genera un radicado único y amigable (ej: DEN-2026-A8K2F)
function generarRadicado() {
  const anio = new Date().getFullYear();
  const caracteres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let codigo = '';
  for (let i = 0; i < 5; i++) {
    codigo += caracteres.charAt(Math.floor(Math.random() * caracteres.length));
  }
  return `DEN-${anio}-${codigo}`;
}

// Obtiene ÚNICAMENTE el correo del superadministrador registrado en la base de datos (rol = 'superadmin')
async function obtenerCorreosSuperAdmin() {
  try {
    const res = await pool.query(
      "SELECT correo FROM Usuario WHERE rol::text = 'superadmin' AND (estado_cuenta IS NULL OR estado_cuenta = 'activo') ORDER BY fecha_registro ASC"
    );
    const correos = res.rows
      .map((r) => (r.correo || '').trim())
      .filter((c) => c && c.includes('@'));
    if (correos.length > 0) {
      return correos;
    }
    console.warn('[DENUNCIAS] No se encontraron cuentas activas con rol superadmin en la base de datos');
  } catch (error) {
    console.error('[DENUNCIAS] Error consultando correo del superadministrador:', error.message);
  }
  return [];
}

// ============================================================================
// 1. POST /api/denuncias: Envío de nueva denuncia (Público / Ciudadano)
// ============================================================================
router.post('/', (req, res, next) => {
  upload.array('archivos', 10)(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({ error: 'Uno o varios archivos superan el tamaño máximo de 25MB' });
      }
      if (err.code === 'LIMIT_FILE_COUNT') {
        return res.status(400).json({ error: 'Solo se permite adjuntar hasta 10 archivos de evidencias' });
      }
      return res.status(400).json({ error: `Error en la carga de archivos: ${err.message}` });
    } else if (err) {
      return res.status(400).json({ error: err.message });
    }
    next();
  });
}, async (req, res) => {
  const client = await pool.connect();
  try {
    const {
      nombre_reportante,
      telefono_reportante,
      barrio_reportante,
      ciudad_reportante,
      tipo_reporte,
      tipo_animal,
      ubicacion_animal,
      ciudad_caso,
      fecha_situacion,
      peligro_inmediato,
      descripcion_caso,
      caracteristicas_animal,
      estado_salud,
      heridas_visibles,
      condiciones_alimentacion,
      condiciones_lugar,
      comportamiento_animal,
      dificultad_movilidad,
      observaciones_adicionales,
      acepto_politica,
    } = req.body;

    // Validación obligatoria de la persona reportante (no se admite anonimato)
    if (!nombre_reportante || !nombre_reportante.trim()) {
      return res.status(400).json({ error: 'El nombre completo de la persona que reporta es obligatorio' });
    }

    if (!telefono_reportante || !telefono_reportante.trim()) {
      return res.status(400).json({ error: 'El número de teléfono de contacto es obligatorio' });
    }

    const telLimpio = telefono_reportante.trim().replace(/[\s\-\(\)\+]/g, '');
    if (telLimpio.length < 7 || telLimpio.length > 15 || !/^\d+$/.test(telLimpio)) {
      return res.status(400).json({ error: 'Ingresa un número de teléfono válido (mínimo 7 dígitos numéricos)' });
    }

    if (!barrio_reportante || !barrio_reportante.trim()) {
      return res.status(400).json({ error: 'La dirección o barrio donde localizar al reportante es obligatoria para el seguimiento' });
    }

    // Validación de campos del caso
    if (!tipo_reporte || !tipo_reporte.trim()) {
      return res.status(400).json({ error: 'Debes seleccionar el tipo de situación o reporte' });
    }
    if (!tipo_animal || !tipo_animal.trim()) {
      return res.status(400).json({ error: 'Debes indicar el tipo de animal' });
    }
    if (!ubicacion_animal || !ubicacion_animal.trim()) {
      return res.status(400).json({ error: 'La ubicación o punto de referencia del animal es obligatoria' });
    }
    if (!ciudad_caso || !ciudad_caso.trim()) {
      return res.status(400).json({ error: 'La ciudad o municipio del caso es obligatoria' });
    }
    if (!fecha_situacion || !fecha_situacion.trim()) {
      return res.status(400).json({ error: 'Debes seleccionar la fecha del incidente en el calendario' });
    }
    if (!descripcion_caso || !descripcion_caso.trim()) {
      return res.status(400).json({ error: 'Por favor describe lo sucedido con el mayor detalle posible' });
    }

    const aceptoPoliticaBool = String(acepto_politica).toLowerCase() === 'true';
    if (!aceptoPoliticaBool) {
      return res.status(400).json({ error: 'Debes autorizar el tratamiento de datos personales para registrar la denuncia' });
    }

    // Detectar si el usuario que reporta tiene sesión iniciada
    let idUsuarioSesion = null;
    const headerUserId = req.header('x-usuario-id');
    if (headerUserId) {
      try {
        const u = await pool.query('SELECT id_usuario FROM usuario WHERE id_usuario = $1', [headerUserId]);
        if (u.rows.length > 0) idUsuarioSesion = headerUserId;
      } catch (_) {}
    }

    // Generar radicado único
    let radicado = generarRadicado();
    let intentos = 0;
    while (intentos < 5) {
      const existeRadicado = await client.query('SELECT 1 FROM denuncia WHERE radicado = $1', [radicado]);
      if (existeRadicado.rows.length === 0) break;
      radicado = generarRadicado();
      intentos++;
    }

    await client.query('BEGIN');

    // Insertar denuncia completa
    const insertDenunciaQuery = `
      INSERT INTO denuncia (
        radicado, id_usuario, es_anonimo,
        nombre_reportante, telefono_reportante, ciudad_reportante, barrio_reportante,
        tipo_reporte, tipo_animal, ubicacion_animal, ciudad_caso,
        fecha_situacion, peligro_inmediato, descripcion_caso,
        caracteristicas_animal, estado_salud, heridas_visibles,
        condiciones_alimentacion, condiciones_lugar, comportamiento_animal, dificultad_movilidad,
        observaciones_adicionales, acepto_politica, version_politica, fecha_autorizacion,
        estado, leido_admin, estado_correo
      ) VALUES (
        $1, $2, false,
        $3, $4, $5, $6,
        $7, $8, $9, $10,
        $11, $12, $13,
        $14, $15, $16,
        $17, $18, $19, $20,
        $21, true, 'v1.0', CURRENT_TIMESTAMP,
        'recibido', false, 'pendiente'
      ) RETURNING id_denuncia, radicado, fecha_creacion, estado;
    `;

    const valores = [
      radicado,
      idUsuarioSesion,
      nombre_reportante.trim(),
      telefono_reportante.trim(),
      (ciudad_reportante || 'San Juan de Pasto').trim(),
      barrio_reportante.trim(),
      tipo_reporte.trim(),
      tipo_animal.trim(),
      ubicacion_animal.trim(),
      ciudad_caso.trim(),
      fecha_situacion.trim(),
      (peligro_inmediato || 'no').trim().toLowerCase(),
      descripcion_caso.trim(),
      (caracteristicas_animal || '').trim(),
      (estado_salud || '').trim(),
      (heridas_visibles || '').trim(),
      (condiciones_alimentacion || '').trim(),
      (condiciones_lugar || '').trim(),
      (comportamiento_animal || '').trim(),
      (dificultad_movilidad || '').trim(),
      (observaciones_adicionales || '').trim(),
    ];

    const resDenuncia = await client.query(insertDenunciaQuery, valores);
    const nuevaDenuncia = resDenuncia.rows[0];

    // Guardar archivos de evidencias
    const archivos = req.files || [];
    for (const f of archivos) {
      const ext = path.extname(f.originalname).toLowerCase();
      const esVideo = ['.mp4', '.mov', '.avi', '.mkv', '.3gp', '.webm'].includes(ext);

      await client.query(`
        INSERT INTO denuncia_archivo (
          id_denuncia, nombre_original, nombre_guardado, ruta_archivo, tipo_mime, tamano_bytes, es_video
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)
      `, [
        nuevaDenuncia.id_denuncia,
        f.originalname,
        f.filename,
        f.path,
        f.mimetype,
        f.size,
        esVideo,
      ]);
    }

    // Registrar en historial de seguimiento
    await client.query(`
      INSERT INTO denuncia_historial (
        id_denuncia, estado_anterior, estado_nuevo, observacion
      ) VALUES ($1, NULL, 'recibido', 'Denuncia recibida y radicada en la plataforma')
    `, [nuevaDenuncia.id_denuncia]);

    await client.query('COMMIT');

    // Despacho asíncrono y seguro de correo electrónico al administrador
    (async () => {
      try {
        const correosSuperAdmin = await obtenerCorreosSuperAdmin();
        const backendHost = process.env.APP_URL || process.env.BACKEND_URL || `http://localhost:${process.env.PORT || 3000}`;
        const urlPanel = `${backendHost}/#denuncia-${nuevaDenuncia.radicado}`;

        const resultadoEnvio = await enviarCorreoNuevaDenunciaAdmin({
          destinatarios: correosSuperAdmin,
          denuncia: {
            radicado: nuevaDenuncia.radicado,
            tipo_reporte,
            tipo_animal,
            ubicacion_animal,
            ciudad_caso,
            peligro_inmediato,
            descripcion_caso,
            fecha_creacion: nuevaDenuncia.fecha_creacion,
          },
          urlPanel,
        });

        const estadoCorreo = resultadoEnvio.enviado ? 'enviado' : 'fallido';
        const errorCorreo = resultadoEnvio.error ? String(resultadoEnvio.error).substring(0, 500) : null;

        await pool.query(
          'UPDATE denuncia SET estado_correo = $1, error_correo = $2 WHERE id_denuncia = $3',
          [estadoCorreo, errorCorreo, nuevaDenuncia.id_denuncia]
        );
      } catch (errCorreo) {
        console.error('[DENUNCIAS ERROR] Falló notificación por correo:', errCorreo.message);
        await pool.query(
          'UPDATE denuncia SET estado_correo = $1, error_correo = $2 WHERE id_denuncia = $3',
          ['fallido', errCorreo.message.substring(0, 500), nuevaDenuncia.id_denuncia]
        ).catch(() => {});
      }
    })();

    res.status(201).json({
      ok: true,
      mensaje: '¡Gracias por ayudarnos a proteger a los animales! Tu reporte ha sido recibido correctamente.',
      radicado: nuevaDenuncia.radicado,
      id_denuncia: nuevaDenuncia.id_denuncia,
      fecha_creacion: nuevaDenuncia.fecha_creacion,
      estado: nuevaDenuncia.estado,
      total_archivos: archivos.length,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[DENUNCIAS ERROR] Error registrando denuncia:', err);

    // Si falló la transacción, eliminar archivos que Multer haya escrito en disco
    if (req.files && req.files.length > 0) {
      req.files.forEach(f => {
        try { fs.unlinkSync(f.path); } catch (_) {}
      });
    }

    res.status(500).json({ error: 'No se pudo guardar la denuncia. Por favor intenta de nuevo.' });
  } finally {
    client.release();
  }
});

// ============================================================================
// 2. GET /api/denuncias/conteo-pendientes: Conteo para badge de notificaciones
// ============================================================================
router.get('/conteo-pendientes', requireAdmin, async (_req, res) => {
  try {
    const rNoLeidas = await pool.query(
      "SELECT COUNT(*)::int AS total FROM denuncia WHERE leido_admin = false"
    );
    const rPendientes = await pool.query(
      "SELECT COUNT(*)::int AS total FROM denuncia WHERE estado IN ('recibido', 'en_revision', 'en_gestion')"
    );
    const rTotal = await pool.query("SELECT COUNT(*)::int AS total FROM denuncia");

    res.json({
      no_leidas: rNoLeidas.rows[0].total,
      pendientes: rPendientes.rows[0].total,
      total: rTotal.rows[0].total,
    });
  } catch (err) {
    console.error('[DENUNCIAS ERROR] Error obteniendo conteos:', err);
    res.status(500).json({ error: 'Error al consultar conteo de denuncias' });
  }
});

// ============================================================================
// 3. GET /api/denuncias: Listado para el panel administrativo
// ============================================================================
router.get('/', requireAdmin, async (req, res) => {
  try {
    const { estado, q } = req.query;
    const condiciones = [];
    const params = [];

    if (estado && estado !== 'todos') {
      params.push(estado.toLowerCase());
      condiciones.push(`d.estado = $${params.length}`);
    }

    if (q && q.trim()) {
      params.push(`%${q.trim()}%`);
      const pIdx = params.length;
      condiciones.push(`(
        d.radicado ILIKE $${pIdx} OR
        d.nombre_reportante ILIKE $${pIdx} OR
        d.ciudad_caso ILIKE $${pIdx} OR
        d.tipo_reporte ILIKE $${pIdx} OR
        d.tipo_animal ILIKE $${pIdx}
      )`);
    }

    const whereClause = condiciones.length > 0 ? `WHERE ${condiciones.join(' AND ')}` : '';

    const query = `
      SELECT
        d.id_denuncia,
        d.radicado,
        d.es_anonimo,
        d.nombre_reportante,
        d.correo_reportante,
        d.telefono_reportante,
        d.tipo_reporte,
        d.tipo_animal,
        d.ciudad_caso,
        d.ubicacion_animal,
        d.peligro_inmediato,
        d.descripcion_caso,
        d.estado,
        d.leido_admin,
        d.estado_correo,
        d.fecha_creacion,
        d.fecha_actualizacion,
        COALESCE((SELECT COUNT(*)::int FROM denuncia_archivo da WHERE da.id_denuncia = d.id_denuncia), 0) AS total_archivos
      FROM denuncia d
      ${whereClause}
      ORDER BY d.fecha_creacion DESC
    `;

    const r = await pool.query(query, params);
    res.json(r.rows);
  } catch (err) {
    console.error('[DENUNCIAS ERROR] Error listando denuncias:', err);
    res.status(500).json({ error: 'Error al consultar las denuncias' });
  }
});

// ============================================================================
// 4. GET /api/denuncias/:id: Detalle completo de la denuncia
// ============================================================================
router.get('/:id', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    const rDenuncia = await pool.query('SELECT * FROM denuncia WHERE id_denuncia = $1', [id]);
    if (rDenuncia.rows.length === 0) {
      return res.status(404).json({ error: 'Denuncia no encontrada' });
    }

    const denuncia = rDenuncia.rows[0];

    // Marcar como leída por el administrador automáticamente al abrirla
    if (!denuncia.leido_admin) {
      await pool.query('UPDATE denuncia SET leido_admin = true WHERE id_denuncia = $1', [id]);
      denuncia.leido_admin = true;
    }

    // Consultar archivos adjuntos
    const rArchivos = await pool.query(
      `SELECT id_archivo, id_denuncia, nombre_original, nombre_guardado, tipo_mime, tamano_bytes, es_video, fecha_subida
       FROM denuncia_archivo WHERE id_denuncia = $1 ORDER BY fecha_subida ASC`,
      [id]
    );

    // Consultar historial de seguimiento
    const rHistorial = await pool.query(
      `SELECT id_historial, estado_anterior, estado_nuevo, observacion, nombre_admin, fecha
       FROM denuncia_historial WHERE id_denuncia = $1 ORDER BY fecha DESC`,
      [id]
    );

    res.json({
      ...denuncia,
      archivos: rArchivos.rows,
      historial: rHistorial.rows,
    });
  } catch (err) {
    console.error('[DENUNCIAS ERROR] Error consultando detalle:', err);
    res.status(500).json({ error: 'Error al consultar el detalle de la denuncia' });
  }
});

// ============================================================================
// 5. GET /api/denuncias/:id/archivos/:idArchivo: Descarga o streaming seguro
// ============================================================================
router.get('/:id/archivos/:idArchivo', requireAdmin, async (req, res) => {
  try {
    const { id, idArchivo } = req.params;

    const r = await pool.query(
      'SELECT ruta_archivo, nombre_original, tipo_mime FROM denuncia_archivo WHERE id_archivo = $1 AND id_denuncia = $2',
      [idArchivo, id]
    );

    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Archivo no encontrado en el caso' });
    }

    const archivo = r.rows[0];
    const rutaAbsoluta = path.resolve(archivo.ruta_archivo);
    if (!fs.existsSync(rutaAbsoluta)) {
      return res.status(404).json({ error: 'El archivo físico no fue encontrado en el servidor' });
    }

    let mimeType = archivo.tipo_mime;
    const ext = path.extname(archivo.nombre_original || '').toLowerCase();
    if (ext === '.mp4') mimeType = 'video/mp4';
    else if (ext === '.webm') mimeType = 'video/webm';
    else if (ext === '.mov') mimeType = 'video/quicktime';
    else if (ext === '.jpg' || ext === '.jpeg') mimeType = 'image/jpeg';
    else if (ext === '.png') mimeType = 'image/png';
    else if (ext === '.webp') mimeType = 'image/webp';

    if (mimeType) {
      res.setHeader('Content-Type', mimeType);
    }
    res.setHeader('Accept-Ranges', 'bytes');
    res.sendFile(rutaAbsoluta);
  } catch (err) {
    console.error('[DENUNCIAS ERROR] Error sirviendo archivo:', err);
    res.status(500).json({ error: 'Error al obtener archivo de evidencia' });
  }
});

// ============================================================================
// 6. PUT /api/denuncias/:id/estado: Actualizar estado y notas del administrador
// ============================================================================
router.put('/:id/estado', requireAdmin, async (req, res) => {
  const client = await pool.connect();
  try {
    const { id } = req.params;
    const { estado, observaciones_internas, acciones_realizadas } = req.body;

    const estadosValidos = ['recibido', 'en_revision', 'en_gestion', 'derivado', 'atendido', 'cerrado'];
    if (estado && !estadosValidos.includes(estado.toLowerCase())) {
      return res.status(400).json({ error: `Estado no válido. Opciones: ${estadosValidos.join(', ')}` });
    }

    await client.query('BEGIN');

    const actual = await client.query('SELECT estado FROM denuncia WHERE id_denuncia = $1', [id]);
    if (actual.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Denuncia no encontrada' });
    }

    const estadoAnterior = actual.rows[0].estado;
    const nuevoEstado = estado ? estado.toLowerCase() : estadoAnterior;

    const rUpdate = await client.query(`
      UPDATE denuncia
      SET
        estado = $1,
        observaciones_internas = COALESCE($2, observaciones_internas),
        acciones_realizadas = COALESCE($3, acciones_realizadas),
        fecha_actualizacion = CURRENT_TIMESTAMP
      WHERE id_denuncia = $4
      RETURNING *
    `, [nuevoEstado, observaciones_internas, acciones_realizadas, id]);

    // Registrar en el historial si cambió de estado o se añadieron observaciones
    const nombreAdmin = `${req.admin.nombres || ''} ${req.admin.apellidos || ''}`.trim() || 'Administrador';
    const observacionHistorial = nuevoEstado !== estadoAnterior
      ? `Estado cambiado de '${estadoAnterior}' a '${nuevoEstado}'. ${observaciones_internas || ''}`.trim()
      : `Actualización de gestión: ${acciones_realizadas || observaciones_internas || 'Sin detalles'}`.trim();

    await client.query(`
      INSERT INTO denuncia_historial (
        id_denuncia, id_usuario_admin, nombre_admin, estado_anterior, estado_nuevo, observacion
      ) VALUES ($1, $2, $3, $4, $5, $6)
    `, [id, req.admin.id_usuario, nombreAdmin, estadoAnterior, nuevoEstado, observacionHistorial]);

    await client.query('COMMIT');

    res.json({
      ok: true,
      mensaje: 'Denuncia actualizada correctamente',
      denuncia: rUpdate.rows[0],
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[DENUNCIAS ERROR] Error actualizando estado:', err);
    res.status(500).json({ error: 'Error al actualizar la denuncia' });
  } finally {
    client.release();
  }
});

// ============================================================================
// 7. POST /api/denuncias/:id/reintentar-correo: Reintento de notificación
// ============================================================================
router.post('/:id/reintentar-correo', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query('SELECT * FROM denuncia WHERE id_denuncia = $1', [id]);
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Denuncia no encontrada' });
    }

    const denuncia = r.rows[0];
    const correosAdmin = await obtenerCorreosAdministradores();
    const backendHost = process.env.APP_URL || process.env.BACKEND_URL || `http://localhost:${process.env.PORT || 3000}`;
    const urlPanel = `${backendHost}/#denuncia-${denuncia.radicado}`;

    const resEnvio = await enviarCorreoNuevaDenunciaAdmin({
      destinatarios: correosAdmin,
      denuncia,
      urlPanel,
    });

    const nuevoEstado = resEnvio.enviado ? 'enviado' : 'fallido';
    const nuevoError = resEnvio.error ? String(resEnvio.error).substring(0, 500) : null;

    await pool.query(
      'UPDATE denuncia SET estado_correo = $1, error_correo = $2 WHERE id_denuncia = $3',
      [nuevoEstado, nuevoError, id]
    );

    if (resEnvio.enviado) {
      res.json({ ok: true, mensaje: 'Notificación reenviada con éxito al administrador' });
    } else {
      res.status(500).json({ error: `No se pudo enviar el correo: ${resEnvio.error}` });
    }
  } catch (err) {
    console.error('[DENUNCIAS ERROR] Error reenviando correo:', err);
    res.status(500).json({ error: 'Error al reintentar el envío de correo' });
  }
});

module.exports = router;
