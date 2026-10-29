const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { randomUUID } = require('crypto');
const router = express.Router();
const pool = require('../db');
const { esAdministrador } = require('../utils/roles');

const fotosDir = path.join(__dirname, '..', 'uploads', 'seguimientos_adopcion');
const fotosCancelacionDir = path.join(__dirname, '..', 'uploads', 'cancelaciones_adopcion');
fs.mkdirSync(fotosDir, { recursive: true });
fs.mkdirSync(fotosCancelacionDir, { recursive: true });

const MOTIVOS_CANCELACION = [
  'Incumplimiento del contrato de adopción',
  'Problemas de comportamiento del adoptante',
  'Negligencia o falta de cuidado básico',
  'Abandono o desinterés por parte del adoptante',
  'Presunto maltrato animal',
  'Cambio imprevisto en la situación familiar o económica',
  'Otro',
];

const extensionesImagen = new Set([
  '.jpg', '.jpeg', '.jfif', '.png', '.gif', '.webp', '.bmp',
  '.tif', '.tiff', '.heic', '.heif', '.avif', '.svg', '.ico',
]);

function extensionImagen(file) {
  const ext = path.extname(file.originalname || '').toLowerCase();
  if (extensionesImagen.has(ext)) return ext;
  const mime = (file.mimetype || '').toLowerCase();
  if (mime === 'image/png') return '.png';
  if (mime === 'image/gif') return '.gif';
  if (mime === 'image/webp') return '.webp';
  if (mime === 'image/bmp' || mime === 'image/x-ms-bmp') return '.bmp';
  if (mime === 'image/heic' || mime === 'image/heif') return '.heic';
  if (mime === 'image/tiff' || mime === 'image/tif') return '.tiff';
  if (mime === 'image/avif') return '.avif';
  if (mime === 'image/svg+xml') return '.svg';
  return '.jpg';
}

function esArchivoImagen(file) {
  const mime = (file.mimetype || '').toLowerCase();
  const ext = path.extname(file.originalname || '').toLowerCase();
  if (mime.startsWith('image/')) return true;
  if (extensionesImagen.has(ext)) return true;
  // En el navegador la foto a veces llega sin tipo (application/octet-stream).
  return !mime || mime === 'application/octet-stream';
}

const uploadCancelacion = multer({
  storage: multer.diskStorage({
    destination: fotosCancelacionDir,
    filename: (_req, file, callback) => {
      callback(null, `${randomUUID()}${extensionImagen(file)}`);
    },
  }),
  limits: { fileSize: 15 * 1024 * 1024 },
  fileFilter: (_req, file, callback) => {
    if (esArchivoImagen(file)) callback(null, true);
    else callback(new Error('Las fotos de la cancelación deben ser imágenes'));
  },
});

const uploadFotos = multer({
  storage: multer.diskStorage({
    destination: fotosDir,
    filename: (_req, file, callback) => {
      callback(null, `${randomUUID()}${extensionImagen(file)}`);
    },
  }),
  limits: { fileSize: 15 * 1024 * 1024 },
  fileFilter: (_req, file, callback) => {
    if (esArchivoImagen(file)) callback(null, true);
    else callback(new Error('Las fotos del seguimiento deben ser imágenes'));
  },
});

const esquemaListo = (async () => {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS seguimientoadopcion (
      id_seguimiento_adopcion UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      id_solicitud_adopcion UUID NOT NULL REFERENCES solicitudadopcion(id_solicitud_adopcion) ON DELETE CASCADE,
      id_administrador UUID NOT NULL REFERENCES usuario(id_usuario),
      fecha_seguimiento DATE NOT NULL DEFAULT CURRENT_DATE,
      observaciones TEXT,
      proxima_fecha_seguimiento DATE,
      peso_saludable SMALLINT,
      condicion_sanitaria SMALLINT,
      entorno_apto SMALLINT,
      comportamiento SMALLINT,
      compromiso_veterinario SMALLINT,
      disposicion_adoptante SMALLINT,
      foto_estado TEXT,
      foto_entorno TEXT,
      calificacion SMALLINT NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
      cumplimiento BOOLEAN NOT NULL DEFAULT true,
      numero_seguimiento INTEGER NOT NULL,
      ciclo INTEGER NOT NULL,
      created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS evaluacion_ciclo_adopcion (
      id_evaluacion UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      id_solicitud_adopcion UUID NOT NULL REFERENCES solicitudadopcion(id_solicitud_adopcion) ON DELETE CASCADE,
      ciclo INTEGER NOT NULL,
      promedio NUMERIC(3,2) NOT NULL,
      puntuacion TEXT NOT NULL,
      decision TEXT NOT NULL,
      nota TEXT,
      id_administrador UUID REFERENCES usuario(id_usuario),
      fecha_decision DATE NOT NULL DEFAULT CURRENT_DATE,
      created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT uq_solicitud_ciclo_adopcion UNIQUE (id_solicitud_adopcion, ciclo)
    )
  `);
  await pool.query(`
    ALTER TABLE solicitudadopcion
      ADD COLUMN IF NOT EXISTS estado_seguimiento VARCHAR(20) DEFAULT 'activa'
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cancelacion_adopcion (
      id_cancelacion UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      id_solicitud_adopcion UUID NOT NULL UNIQUE REFERENCES solicitudadopcion(id_solicitud_adopcion) ON DELETE CASCADE,
      id_mascota UUID NOT NULL REFERENCES mascota(id_mascota),
      id_usuario UUID NOT NULL REFERENCES usuario(id_usuario),
      id_administrador UUID NOT NULL REFERENCES usuario(id_usuario),
      fecha_cancelacion DATE NOT NULL DEFAULT CURRENT_DATE,
      motivo TEXT NOT NULL,
      observacion TEXT NOT NULL,
      foto_1 TEXT,
      foto_2 TEXT,
      inhabilitar_cuenta BOOLEAN NOT NULL DEFAULT false,
      created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
    )
  `);
  // La tabla original no trae las puntuaciones ni las fotos del formulario nuevo.
  await pool.query(`
    ALTER TABLE seguimientoadopcion
      ADD COLUMN IF NOT EXISTS calificacion SMALLINT,
      ADD COLUMN IF NOT EXISTS cumplimiento BOOLEAN DEFAULT true,
      ADD COLUMN IF NOT EXISTS numero_seguimiento INTEGER,
      ADD COLUMN IF NOT EXISTS ciclo INTEGER DEFAULT 1,
      ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
      ADD COLUMN IF NOT EXISTS proxima_fecha_seguimiento DATE,
      ADD COLUMN IF NOT EXISTS peso_saludable SMALLINT,
      ADD COLUMN IF NOT EXISTS condicion_sanitaria SMALLINT,
      ADD COLUMN IF NOT EXISTS entorno_apto SMALLINT,
      ADD COLUMN IF NOT EXISTS comportamiento SMALLINT,
      ADD COLUMN IF NOT EXISTS compromiso_veterinario SMALLINT,
      ADD COLUMN IF NOT EXISTS disposicion_adoptante SMALLINT,
      ADD COLUMN IF NOT EXISTS foto_estado TEXT,
      ADD COLUMN IF NOT EXISTS foto_entorno TEXT
  `);
  await pool.query(`
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'seguimientoadopcion' AND column_name = 'proximo_seguimiento'
      ) THEN
        UPDATE seguimientoadopcion
        SET proxima_fecha_seguimiento = COALESCE(proxima_fecha_seguimiento, proximo_seguimiento)
        WHERE proxima_fecha_seguimiento IS NULL;
      END IF;
    END $$;
  `);
  await pool.query(`
    ALTER TABLE seguimientoadopcion
      DROP COLUMN IF EXISTS medio_contacto,
      DROP COLUMN IF EXISTS estado_mascota,
      DROP COLUMN IF EXISTS adaptacion_hogar,
      DROP COLUMN IF EXISTS proximo_seguimiento,
      DROP COLUMN IF EXISTS estado_bienestar_mascota,
      DROP COLUMN IF EXISTS cumplimiento_compromisos
  `);
  await pool.query(`
    WITH calculados AS (
      SELECT
        id_seguimiento_adopcion,
        ROW_NUMBER() OVER (
          PARTITION BY id_solicitud_adopcion
          ORDER BY fecha_seguimiento ASC, id_seguimiento_adopcion
        ) AS num
      FROM seguimientoadopcion
    )
    UPDATE seguimientoadopcion s
    SET numero_seguimiento = c.num,
        ciclo = 1,
        created_at = COALESCE(s.created_at, s.fecha_seguimiento::timestamp)
    FROM calculados c
    WHERE s.id_seguimiento_adopcion = c.id_seguimiento_adopcion
      AND (s.numero_seguimiento IS NULL OR s.ciclo IS NULL)
  `);
})().catch((err) => {
  console.error('No se pudo preparar el seguimiento de adopción:', err.message);
  throw err;
});

router.use(async (_req, res, next) => {
  try {
    await esquemaListo;
    next();
  } catch (err) {
    res.status(500).json({ error: 'No se pudo preparar el módulo de seguimiento de adopción' });
  }
});

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

async function requireAdmin(req, res, next) {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión con una cuenta activa' });
  }
  if (!esAdministrador(usuario.rol)) {
    return res.status(403).json({ error: 'Acceso restringido solo para administradores' });
  }
  req.usuarioActual = usuario;
  next();
}

router.get('/activos', requireAdmin, async (_req, res) => {
  try {
    const query = `
      SELECT
        sa.id_solicitud_adopcion,
        sa.estado,
        COALESCE(sa.estado_seguimiento, 'activa') AS estado_seguimiento,
        sa.fecha_inicio_adopcion,
        sa.contrato_adopcion_archivo,
        m.id_mascota,
        m.nombre AS mascota_nombre,
        m.fotos AS mascota_fotos,
        m.especie AS mascota_especie,
        m.raza AS mascota_raza,
        m.edad AS mascota_edad,
        m.unidad_edad AS mascota_unidad_edad,
        u.id_usuario,
        u.nombres AS usuario_nombres,
        u.apellidos AS usuario_apellidos,
        u.correo AS usuario_correo,
        u.telefono AS usuario_telefono,
        COALESCE(u.documento_identidad, '') AS usuario_cedula,
        COALESCE(u.direccion, '') AS usuario_direccion,
        COALESCE(prom.calificacion_promedio, 0.0) AS calificacion_promedio,
        ult.fecha_seguimiento AS ultimo_seguimiento_fecha,
        ult.calificacion AS ultimo_seguimiento_calificacion,
        ult.cumplimiento AS ultimo_seguimiento_cumplimiento,
        ult.observaciones AS ultimo_seguimiento_observaciones,
        ult.proxima_fecha_seguimiento AS proximo_seguimiento_fecha,
        seg_list.seguimientos_resumen
      FROM solicitudadopcion sa
      JOIN mascota m ON sa.id_mascota = m.id_mascota
      JOIN usuario u ON sa.id_usuario = u.id_usuario
      LEFT JOIN LATERAL (
        SELECT COALESCE(ROUND(AVG(s.calificacion)::numeric, 1), 0.0) AS calificacion_promedio
        FROM seguimientoadopcion s
        WHERE s.id_solicitud_adopcion = sa.id_solicitud_adopcion
      ) prom ON true
      LEFT JOIN LATERAL (
        SELECT
          s.fecha_seguimiento,
          s.calificacion,
          s.cumplimiento,
          s.observaciones,
          s.proxima_fecha_seguimiento
        FROM seguimientoadopcion s
        WHERE s.id_solicitud_adopcion = sa.id_solicitud_adopcion
        ORDER BY s.fecha_seguimiento DESC, s.created_at DESC
        LIMIT 1
      ) ult ON true
      LEFT JOIN LATERAL (
        SELECT COALESCE(
          json_agg(
            json_build_object(
              'id_seguimiento_adopcion', s.id_seguimiento_adopcion,
              'numero_seguimiento', s.numero_seguimiento,
              'calificacion', s.calificacion,
              'cumplimiento', s.cumplimiento,
              'fecha_seguimiento', s.fecha_seguimiento
            ) ORDER BY s.numero_seguimiento ASC
          ),
          '[]'::json
        ) AS seguimientos_resumen
        FROM seguimientoadopcion s
        WHERE s.id_solicitud_adopcion = sa.id_solicitud_adopcion
      ) seg_list ON true
      WHERE sa.contrato_adopcion_archivo IS NOT NULL
        AND btrim(sa.contrato_adopcion_archivo) <> ''
        AND (
          (
            sa.estado = 'aprobada'
            AND lower(btrim(m.estado_adopcion::text)) = 'adoptado'
            AND COALESCE(sa.estado_seguimiento, 'activa') = 'activa'
          )
          OR COALESCE(sa.estado_seguimiento, '') = 'cancelada'
        )
      ORDER BY m.nombre ASC
    `;

    const resultado = await pool.query(query);
    const filas = resultado.rows.map((row) => {
      const seguimientos = Array.isArray(row.seguimientos_resumen) ? row.seguimientos_resumen : [];
      return {
        ...row,
        total_seguimientos: seguimientos.length,
      };
    });
    res.json(filas);
  } catch (error) {
    console.error('Error al listar adopciones activas para seguimiento:', error);
    res.status(500).json({ error: 'Error interno del servidor al consultar adopciones en seguimiento' });
  }
});

router.get('/historial/:idSolicitud', requireAdmin, async (req, res) => {
  try {
    const { idSolicitud } = req.params;
    const resultado = await pool.query(
      `SELECT
         s.*,
         u.nombres AS admin_nombres,
         u.apellidos AS admin_apellidos
       FROM seguimientoadopcion s
       LEFT JOIN usuario u ON u.id_usuario = s.id_administrador
       WHERE s.id_solicitud_adopcion = $1
       ORDER BY s.numero_seguimiento ASC, s.fecha_seguimiento ASC`,
      [idSolicitud]
    );
    res.json(resultado.rows);
  } catch (error) {
    console.error('Error al consultar historial de adopción:', error);
    res.status(500).json({ error: 'Error al cargar el historial de seguimientos' });
  }
});

function puntaje(valor, etiqueta) {
  const n = parseInt(valor, 10);
  if (Number.isNaN(n) || n < 1 || n > 5) {
    return { error: `${etiqueta} debe calificarse de 1 a 5` };
  }
  return { valor: n };
}

function borrarFotos(files) {
  const listas = files ? Object.values(files).flat() : [];
  for (const file of listas) fs.unlink(file.path, () => {});
}

router.post('/', requireAdmin, (req, res, next) => {
  uploadFotos.fields([
    { name: 'foto_estado', maxCount: 1 },
    { name: 'foto_entorno', maxCount: 1 },
  ])(req, res, (err) => {
    if (err) {
      const mensaje = err.code === 'LIMIT_FILE_SIZE'
        ? 'Cada foto debe pesar máximo 15 MB'
        : (err.message || 'No se pudieron subir las fotos');
      return res.status(400).json({ error: mensaje });
    }
    next();
  });
}, async (req, res) => {
  const admin = req.usuarioActual;
  const {
    id_solicitud_adopcion,
    calificacion,
    observaciones,
    proxima_fecha_seguimiento,
    fecha_seguimiento,
    peso_saludable,
    condicion_sanitaria,
    entorno_apto,
    comportamiento,
    compromiso_veterinario,
    disposicion_adoptante,
  } = req.body;

  const fotoEstado = req.files?.foto_estado?.[0];
  const fotoEntorno = req.files?.foto_entorno?.[0];
  const fallar = (status, error) => {
    borrarFotos(req.files);
    return res.status(status).json({ error });
  };

  if (!id_solicitud_adopcion) {
    return fallar(400, 'El id de la solicitud de adopción es obligatorio');
  }
  const califNum = parseInt(calificacion, 10);
  if (Number.isNaN(califNum) || califNum < 1 || califNum > 5) {
    return fallar(400, 'La calificación del adoptante es obligatoria y debe ser entre 1 y 5');
  }
  const preguntas = [
    puntaje(peso_saludable, 'El peso y el pelaje'),
    puntaje(condicion_sanitaria, 'La condición sanitaria'),
    puntaje(entorno_apto, 'El espacio donde vive'),
    puntaje(comportamiento, 'El comportamiento del perrito'),
    puntaje(compromiso_veterinario, 'El compromiso veterinario'),
    puntaje(disposicion_adoptante, 'La disposición del adoptante'),
  ];
  const invalida = preguntas.find((p) => p.error);
  if (invalida) return fallar(400, invalida.error);
  const notas = (observaciones || '').trim();
  if (notas.length < 3) {
    return fallar(400, 'Indica si hay señales de alerta o escribe que no hay acuerdos pendientes');
  }
  if (!proxima_fecha_seguimiento) {
    return fallar(400, 'La fecha del próximo seguimiento es obligatoria');
  }
  if (!fotoEstado) {
    return fallar(400, 'La foto del estado general del perrito es obligatoria');
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const solRes = await client.query(
      `SELECT sa.id_solicitud_adopcion, sa.estado, COALESCE(sa.estado_seguimiento, 'activa') AS estado_seguimiento
       FROM solicitudadopcion sa
       WHERE sa.id_solicitud_adopcion = $1`,
      [id_solicitud_adopcion]
    );
    if (solRes.rows.length === 0) {
      await client.query('ROLLBACK');
      borrarFotos(req.files);
      return res.status(404).json({ error: 'La solicitud de adopción no existe' });
    }
    if (
      solRes.rows[0].estado !== 'aprobada'
      || solRes.rows[0].estado_seguimiento === 'finalizada'
      || solRes.rows[0].estado_seguimiento === 'cancelada'
    ) {
      await client.query('ROLLBACK');
      borrarFotos(req.files);
      return res.status(400).json({ error: 'Esta adopción no admite nuevos seguimientos' });
    }

    const prevSegRes = await client.query(
      `SELECT numero_seguimiento
       FROM seguimientoadopcion
       WHERE id_solicitud_adopcion = $1
       ORDER BY numero_seguimiento ASC`,
      [id_solicitud_adopcion]
    );

    const nuevoNumero = prevSegRes.rows.length + 1;
    const insertRes = await client.query(
      `INSERT INTO seguimientoadopcion (
        id_solicitud_adopcion,
        id_administrador,
        fecha_seguimiento,
        observaciones,
        proxima_fecha_seguimiento,
        peso_saludable,
        condicion_sanitaria,
        entorno_apto,
        comportamiento,
        compromiso_veterinario,
        disposicion_adoptante,
        foto_estado,
        foto_entorno,
        calificacion,
        cumplimiento,
        numero_seguimiento,
        ciclo,
        created_at
      ) VALUES ($1, $2, COALESCE($3::date, CURRENT_DATE), $4, $5::date, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, NOW())
      RETURNING *`,
      [
        id_solicitud_adopcion,
        admin.id_usuario,
        fecha_seguimiento || null,
        notas,
        proxima_fecha_seguimiento,
        preguntas[0].valor,
        preguntas[1].valor,
        preguntas[2].valor,
        preguntas[3].valor,
        preguntas[4].valor,
        preguntas[5].valor,
        `/uploads/seguimientos_adopcion/${fotoEstado.filename}`,
        fotoEntorno ? `/uploads/seguimientos_adopcion/${fotoEntorno.filename}` : null,
        califNum,
        califNum >= 3,
        nuevoNumero,
        1,
      ]
    );

    await client.query('COMMIT');
    res.status(201).json({
      mensaje: `Seguimiento ${nuevoNumero} registrado exitosamente`,
      seguimiento: insertRes.rows[0],
      numero_seguimiento: nuevoNumero,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    borrarFotos(req.files);
    console.error('Error al registrar seguimiento de adopción:', error);
    res.status(500).json({ error: error.message || 'Error interno al guardar el seguimiento' });
  } finally {
    client.release();
  }
});

router.get('/calendario', requireAdmin, async (_req, res) => {
  try {
    const query = `
      WITH UltimoSeguimiento AS (
        SELECT DISTINCT ON (s.id_solicitud_adopcion)
          s.id_seguimiento_adopcion,
          s.id_solicitud_adopcion,
          s.fecha_seguimiento,
          s.proxima_fecha_seguimiento AS proximo_seguimiento,
          s.cumplimiento,
          s.calificacion,
          s.observaciones
        FROM seguimientoadopcion s
        ORDER BY s.id_solicitud_adopcion, s.fecha_seguimiento DESC, s.created_at DESC
      )
      SELECT
        u_seg.id_seguimiento_adopcion,
        u_seg.id_solicitud_adopcion,
        u_seg.fecha_seguimiento AS fecha_ultimo_seguimiento,
        u_seg.proximo_seguimiento,
        u_seg.cumplimiento AS ultimo_cumplimiento,
        u_seg.calificacion AS ultima_calificacion,
        u_seg.observaciones AS ultimas_observaciones,
        (u_seg.proximo_seguimiento < CURRENT_DATE) AS es_vencido,
        m.id_mascota,
        m.nombre AS mascota_nombre,
        m.fotos AS mascota_fotos,
        m.especie AS mascota_especie,
        m.raza AS mascota_raza,
        m.edad AS mascota_edad,
        m.unidad_edad AS mascota_unidad_edad,
        u.id_usuario,
        u.nombres AS usuario_nombres,
        u.apellidos AS usuario_apellidos,
        u.correo AS usuario_correo,
        u.telefono AS usuario_telefono,
        COALESCE(prom.calificacion_promedio, 0.0) AS calificacion_promedio
      FROM UltimoSeguimiento u_seg
      JOIN solicitudadopcion sa ON u_seg.id_solicitud_adopcion = sa.id_solicitud_adopcion
      JOIN mascota m ON sa.id_mascota = m.id_mascota
      JOIN usuario u ON sa.id_usuario = u.id_usuario
      LEFT JOIN LATERAL (
        SELECT COALESCE(ROUND(AVG(s.calificacion)::numeric, 1), 0.0) AS calificacion_promedio
        FROM seguimientoadopcion s
        WHERE s.id_solicitud_adopcion = sa.id_solicitud_adopcion
      ) prom ON true
      WHERE sa.estado = 'aprobada'
        AND COALESCE(sa.estado_seguimiento, 'activa') = 'activa'
        AND u_seg.proximo_seguimiento IS NOT NULL
      ORDER BY u_seg.proximo_seguimiento ASC, m.nombre ASC
    `;
    const resultado = await pool.query(query);
    res.json(resultado.rows);
  } catch (error) {
    console.error('Error al consultar calendario de adopciones:', error);
    res.status(500).json({ error: 'Error al consultar el calendario de próximos seguimientos' });
  }
});

function hoyISO() {
  const ahora = new Date();
  const mes = String(ahora.getMonth() + 1).padStart(2, '0');
  const dia = String(ahora.getDate()).padStart(2, '0');
  return `${ahora.getFullYear()}-${mes}-${dia}`;
}

function fechaCancelacionValida(valor) {
  const texto = String(valor || '').trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(texto)) return null;
  const [anio, mes, dia] = texto.split('-').map(Number);
  const fecha = new Date(Date.UTC(anio, mes - 1, dia));
  if (
    fecha.getUTCFullYear() !== anio
    || fecha.getUTCMonth() !== mes - 1
    || fecha.getUTCDate() !== dia
  ) {
    return null;
  }
  if (texto > hoyISO()) return null;
  return texto;
}

router.get('/:idSolicitud/cancelacion', requireAdmin, async (req, res) => {
  try {
    const resultado = await pool.query(
      `SELECT
         c.fecha_cancelacion,
         c.motivo,
         c.observacion,
         c.foto_1,
         c.foto_2,
         c.inhabilitar_cuenta,
         u.nombres AS admin_nombres,
         u.apellidos AS admin_apellidos
       FROM cancelacion_adopcion c
       LEFT JOIN usuario u ON u.id_usuario = c.id_administrador
       WHERE c.id_solicitud_adopcion = $1`,
      [req.params.idSolicitud]
    );
    if (resultado.rows.length === 0) {
      return res.status(404).json({ error: 'No hay un motivo de cancelación para esta adopción' });
    }
    res.json(resultado.rows[0]);
  } catch (error) {
    console.error('Error al consultar la cancelación:', error);
    res.status(500).json({ error: 'Error al cargar el motivo de la cancelación' });
  }
});

router.post('/:idSolicitud/cancelar', requireAdmin, (req, res, next) => {
  uploadCancelacion.fields([
    { name: 'foto_1', maxCount: 1 },
    { name: 'foto_2', maxCount: 1 },
  ])(req, res, (err) => {
    if (err) {
      const mensaje = err.code === 'LIMIT_FILE_SIZE'
        ? 'Cada foto debe pesar máximo 15 MB'
        : (err.message || 'No se pudieron subir las fotos');
      return res.status(400).json({ error: mensaje });
    }
    next();
  });
}, async (req, res) => {
  const admin = req.usuarioActual;
  const { idSolicitud } = req.params;
  const motivo = String(req.body.motivo || '').trim();
  const observacion = String(req.body.observacion || '').trim();
  const fecha = fechaCancelacionValida(req.body.fecha_cancelacion);
  const inhabilitar = String(req.body.inhabilitar_cuenta || '').toLowerCase() === 'true';
  const foto1 = req.files?.foto_1?.[0];
  const foto2 = req.files?.foto_2?.[0];
  const fallar = (status, error) => {
    borrarFotos(req.files);
    return res.status(status).json({ error });
  };

  if (!MOTIVOS_CANCELACION.includes(motivo)) {
    return fallar(400, 'Selecciona un motivo de la lista');
  }
  if (observacion.length < 10) {
    return fallar(400, 'Explica el motivo de la cancelación con más detalle');
  }
  if (!fecha) {
    return fallar(400, 'La fecha de cancelación no es válida');
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const solRes = await client.query(
      `SELECT
         sa.id_solicitud_adopcion,
         sa.estado,
         COALESCE(sa.estado_seguimiento, 'activa') AS estado_seguimiento,
         sa.id_usuario,
         sa.id_mascota,
         m.nombre AS mascota_nombre,
         lower(btrim(m.estado_adopcion::text)) AS estado_adopcion,
         u.rol AS rol_adoptante
       FROM solicitudadopcion sa
       JOIN mascota m ON m.id_mascota = sa.id_mascota
       JOIN usuario u ON u.id_usuario = sa.id_usuario
       WHERE sa.id_solicitud_adopcion = $1
       FOR UPDATE OF sa, m`,
      [idSolicitud]
    );
    if (solRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return fallar(404, 'La solicitud de adopción no existe');
    }
    const sol = solRes.rows[0];
    if (sol.estado_seguimiento === 'cancelada' || sol.estado === 'cancelada') {
      await client.query('ROLLBACK');
      return fallar(409, 'Esta adopción ya fue cancelada');
    }
    if (sol.estado !== 'aprobada' || sol.estado_adopcion !== 'adoptado') {
      await client.query('ROLLBACK');
      return fallar(400, 'Solo se puede cancelar una adopción activa');
    }
    if (inhabilitar && sol.rol_adoptante !== 'usuario') {
      await client.query('ROLLBACK');
      return fallar(403, 'No se puede inhabilitar la cuenta de un administrador');
    }

    await client.query(
      `INSERT INTO cancelacion_adopcion (
         id_solicitud_adopcion,
         id_mascota,
         id_usuario,
         id_administrador,
         fecha_cancelacion,
         motivo,
         observacion,
         foto_1,
         foto_2,
         inhabilitar_cuenta
       ) VALUES ($1, $2, $3, $4, $5::date, $6, $7, $8, $9, $10)`,
      [
        sol.id_solicitud_adopcion,
        sol.id_mascota,
        sol.id_usuario,
        admin.id_usuario,
        fecha,
        motivo,
        observacion,
        foto1 ? `/uploads/cancelaciones_adopcion/${foto1.filename}` : null,
        foto2 ? `/uploads/cancelaciones_adopcion/${foto2.filename}` : null,
        inhabilitar,
      ]
    );
    await client.query(
      `UPDATE solicitudadopcion
       SET estado = 'cancelada',
           estado_seguimiento = 'cancelada',
           fecha_actualizacion_estado = NOW()
       WHERE id_solicitud_adopcion = $1`,
      [sol.id_solicitud_adopcion]
    );
    await client.query(
      `UPDATE mascota SET estado_adopcion = 'disponible' WHERE id_mascota = $1`,
      [sol.id_mascota]
    );
    if (inhabilitar) {
      await client.query(
        `UPDATE usuario SET estado_cuenta = 'inactivo' WHERE id_usuario = $1 AND rol = 'usuario'`,
        [sol.id_usuario]
      );
      await client.query(
        `INSERT INTO valoracion_usuario (id_usuario, id_administrador, comentarios)
         VALUES ($1, $2, $3)`,
        [
          sol.id_usuario,
          admin.id_usuario,
          `Cuenta inhabilitada al cancelar la adopción de ${sol.mascota_nombre}. Motivo: ${motivo}. ${observacion}`,
        ]
      );
    }

    await client.query('COMMIT');
    res.status(201).json({
      mensaje: `Adopción cancelada. ${sol.mascota_nombre} vuelve a estar disponible.`,
      inhabilitada: inhabilitar,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    borrarFotos(req.files);
    console.error('Error al cancelar la adopción:', error);
    res.status(500).json({ error: error.message || 'Error interno al cancelar la adopción' });
  } finally {
    client.release();
  }
});

module.exports = router;
