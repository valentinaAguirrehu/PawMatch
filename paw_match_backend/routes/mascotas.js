const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { randomUUID } = require('crypto');
const pool = require('../db');
const { esAdministrador } = require('../utils/roles');
const { quitarFondo } = require('../utils/quitarFondo');
const { sqlEdad, sqlUnidadEdad, leerFechaNacimiento } = require('../utils/edad_mascota');
const {
  asegurarEsquemaMatch,
  procesarNuevaMascotaParaUsuarios,
} = require('../utils/match_persistencia');
const {
  asegurarTablaBorradorMascota,
  obtenerLimitesColumnasMascota,
  normalizarFicha,
  guardarBorradorMascotaEnBd,
  obtenerBorradorMascotaDeBd,
  listarBorradoresMascotaDeBd,
  eliminarBorradorMascotaDeBd,
  procesarTurnoEntrevistaMascota,
} = require('../utils/entrevista_mascota_admin');

const router = express.Router();
const uploadDirectory = path.join(__dirname, '..', 'uploads', 'mascotas');
fs.mkdirSync(uploadDirectory, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: uploadDirectory,
    filename: (_req, file, callback) => {
      callback(null, `${randomUUID()}${path.extname(file.originalname).toLowerCase()}`);
    },
  }),
});

const personalityColumns = [
  'nivel_energia', 'sociabilidad_personas', 'sociabilidad_mascotas',
  'independencia', 'nivel_juego', 'carino', 'proteccion',
  'tolerancia_soledad', 'adaptabilidad',
];

// La edad puede estar en meses o años. Sin esta columna, el listado falla.
// personalidad_definida queda en true para las mascotas que ya tenían evaluación.
// Los rasgos de un cachorro en desarrollo se guardan en NULL.
const esquemaListo = (async () => {
  await pool.query(`
    ALTER TABLE mascota
      ADD COLUMN IF NOT EXISTS unidad_edad VARCHAR(10) NOT NULL DEFAULT 'anos',
      ADD COLUMN IF NOT EXISTS estado_salud TEXT NOT NULL DEFAULT '["No presenta necesidades veterinarias pendientes."]',
      ADD COLUMN IF NOT EXISTS detalle_salud TEXT,
      ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      ADD COLUMN IF NOT EXISTS personalidad_definida BOOLEAN NOT NULL DEFAULT TRUE,
      ADD COLUMN IF NOT EXISTS fecha_nacimiento DATE;
  `);
  await pool.query(`
    ALTER TABLE personalidadmascota
      ALTER COLUMN nivel_energia DROP NOT NULL,
      ALTER COLUMN sociabilidad_personas DROP NOT NULL,
      ALTER COLUMN sociabilidad_mascotas DROP NOT NULL,
      ALTER COLUMN independencia DROP NOT NULL,
      ALTER COLUMN nivel_juego DROP NOT NULL,
      ALTER COLUMN carino DROP NOT NULL,
      ALTER COLUMN proteccion DROP NOT NULL,
      ALTER COLUMN tolerancia_soledad DROP NOT NULL,
      ALTER COLUMN adaptabilidad DROP NOT NULL;
  `);
  await asegurarEsquemaMatch();
  await asegurarTablaBorradorMascota();
})().catch((err) => {
  console.error('No se pudo preparar la tabla mascota:', err.message);
  throw err;
});

router.use(async (_req, res, next) => {
  try {
    await esquemaListo;
    next();
  } catch (_) {
    res.status(500).json({ error: 'La tabla mascota no coincide con el esquema esperado.' });
  }
});

async function requireAdmin(req, res, next) {
  const userId = req.header('x-usuario-id');
  if (!userId) return res.status(401).json({ error: 'Debes iniciar sesión' });
  try {
    const result = await pool.query(
      'SELECT rol FROM usuario WHERE id_usuario = $1',
      [userId],
    );
    if (result.rows.length === 0 || !esAdministrador(result.rows[0].rol)) {
      return res.status(403).json({ error: 'Solo un administrador puede gestionar mascotas' });
    }
    req.adminId = userId;
    next();
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo validar el administrador' });
  }
}

function leerPersonalidad(body) {
  const definida = body.personalidad_definida !== false;
  if (!definida) {
    return { definida: false, valores: personalityColumns.map(() => null) };
  }
  const personalidad = body.personalidad && typeof body.personalidad === 'object'
    ? body.personalidad
    : {};
  const valores = [];
  for (const column of personalityColumns) {
    const value = Number(personalidad[column]);
    if (!Number.isInteger(value) || value < 1 || value > 5) {
      return { error: 'Completa la evaluación de personalidad (1 a 5).' };
    }
    valores.push(value);
  }
  return { definida: true, valores };
}

function procesarEstadoSaludYProcedimientos(estadoSaludInput, vacunasInput, esterilizadoInput) {
  let estados = [];
  if (Array.isArray(estadoSaludInput)) {
    estados = estadoSaludInput.map((e) => String(e).trim()).filter(Boolean);
  } else if (typeof estadoSaludInput === 'string') {
    const s = estadoSaludInput.trim();
    if (s.startsWith('[') && s.endsWith(']')) {
      try {
        const parsed = JSON.parse(s);
        if (Array.isArray(parsed)) estados = parsed.map((e) => String(e).trim()).filter(Boolean);
      } catch (_) {
        estados = [s];
      }
    } else if (s.length > 0) {
      estados = [s];
    }
  }

  if (estados.length === 0) {
    estados = ['No presenta necesidades veterinarias pendientes.'];
  }

  const tieneVacunasAlDia = estados.some((e) =>
    e.toLowerCase().includes('vacunación al día') || e.toLowerCase().includes('vacunacion al dia'),
  );
  const tieneEsterilizacionRealizada = estados.some((e) =>
    e.toLowerCase().includes('esterilización realizada') || e.toLowerCase().includes('esterilizacion realizada'),
  );

  const vacunasFinal = tieneVacunasAlDia || (vacunasInput === true && !estados.some((e) => e.toLowerCase().includes('requiere vacunación')));
  const esterilizadoFinal = tieneEsterilizacionRealizada || (esterilizadoInput === true && !estados.some((e) => e.toLowerCase().includes('requiere esterilización')));

  return {
    estadoSaludDb: JSON.stringify(estados),
    vacunas: vacunasFinal,
    esterilizado: esterilizadoFinal,
  };
}

// fecha_ingreso va como texto 'YYYY-MM-DD' para evitar desfases de zona horaria.
// fecha_creacion se conserva intacta desde el registro para calcular exactamente las 48 horas de «NUEVO».
const petSelect = `
  SELECT m.id_mascota, m.nombre, m.especie, m.raza,
         ${sqlEdad('m')} AS edad, ${sqlUnidadEdad('m')} AS unidad_edad, m.sexo,
         m.tamano, m.descripcion, m.esterilizado, m.vacunas, m.fotos,
         m.estado_adopcion, m.estado_apadrinamiento, m.personalidad_definida,
         COALESCE(m.estado_salud, '["No presenta necesidades veterinarias pendientes."]') AS estado_salud,
         m.detalle_salud,
         to_char(m.fecha_ingreso, 'YYYY-MM-DD') AS fecha_ingreso,
         to_char(m.fecha_nacimiento, 'YYYY-MM-DD') AS fecha_nacimiento,
         to_char(m.fecha_actualizacion, 'YYYY-MM-DD HH24:MI') AS fecha_actualizacion,
         to_char(m.fecha_creacion AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS fecha_creacion,
         (m.fecha_creacion IS NOT NULL
          AND (CURRENT_TIMESTAMP - m.fecha_creacion) <= INTERVAL '48 hours'
          AND (CURRENT_TIMESTAMP - m.fecha_creacion) >= INTERVAL '-2 hours') AS es_nuevo,
         (SELECT s.id_usuario
            FROM solicitudadopcion s
           WHERE s.id_mascota = m.id_mascota
             AND s.estado = 'aprobada'
           ORDER BY s.fecha_actualizacion_estado DESC NULLS LAST
           LIMIT 1) AS id_usuario_adoptante,
         CASE WHEN pm.id_mascota IS NULL THEN '{}'::json ELSE json_build_object(
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

router.get('/', async (req, res) => {
  try {
    const values = [];
    let query = `${petSelect} ORDER BY m.fecha_ingreso DESC, m.nombre`;
    if (req.query.estado) {
      values.push(req.query.estado);
      query = `${petSelect} WHERE m.estado_adopcion = $1 ORDER BY m.fecha_ingreso DESC, m.nombre`;
    }
    const result = await pool.query(query, values);
    res.set('Cache-Control', 'no-store');
    res.json(result.rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudieron cargar las mascotas' });
  }
});

router.get('/borradores', requireAdmin, async (req, res) => {
  try {
    const borradores = await listarBorradoresMascotaDeBd(req.adminId);
    res.set('Cache-Control', 'no-store');
    res.json(borradores);
  } catch (error) {
    console.error('Error listando borradores:', error.message || error);
    res.status(500).json({ error: 'No se pudieron cargar los borradores.' });
  }
});

router.get('/borrador', requireAdmin, async (req, res) => {
  try {
    const borrador = await obtenerBorradorMascotaDeBd(req.adminId);
    res.set('Cache-Control', 'no-store');
    res.json({ ok: true, borrador });
  } catch (error) {
    console.error('Error obteniendo borrador:', error.message || error);
    res.status(500).json({ error: 'No se pudo cargar el borrador.' });
  }
});

router.put('/borrador', requireAdmin, async (req, res) => {
  try {
    const limites = await obtenerLimitesColumnasMascota();
    const existente = await obtenerBorradorMascotaDeBd(req.adminId);
    const fichaNormalizada = normalizarFicha(
      req.body || {},
      existente?.ficha || {},
      limites,
    );
    await guardarBorradorMascotaEnBd(
      req.adminId,
      fichaNormalizada,
      req.body?.paso_actual || existente?.paso_actual || 'manual',
      Array.isArray(req.body?.historial) ? req.body.historial : (existente?.historial || []),
      req.body?.origen_registro || existente?.origen_registro || 'manual',
      req.body?.foto || existente?.foto || null,
    );
    res.json({ ok: true, ficha: fichaNormalizada, guardado_en_bd: true });
  } catch (error) {
    console.error('Error guardando borrador:', error.message || error);
    res.status(500).json({ error: 'No se pudo guardar el borrador en la base de datos.' });
  }
});

router.delete('/borradores/:id', requireAdmin, async (req, res) => {
  try {
    const nombre = req.query.nombre || req.body?.nombre;
    await eliminarBorradorMascotaDeBd(req.params.id, req.adminId, nombre);
    res.json({ ok: true, mensaje: 'Borrador eliminado correctamente' });
  } catch (error) {
    console.error('Error eliminando borrador:', error.message || error);
    res.status(500).json({ error: 'No se pudo eliminar el borrador.' });
  }
});

router.delete('/borrador', requireAdmin, async (req, res) => {
  try {
    const nombre = req.query.nombre || req.body?.nombre;
    await eliminarBorradorMascotaDeBd(req.adminId, null, nombre);
    res.json({ ok: true, mensaje: 'Borrador eliminado correctamente' });
  } catch (error) {
    console.error('Error eliminando borrador:', error.message || error);
    res.status(500).json({ error: 'No se pudo eliminar el borrador.' });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const result = await pool.query(`${petSelect} WHERE m.id_mascota = $1`, [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Mascota no encontrada' });
    res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo cargar la mascota' });
  }
});

router.post('/entrevista-luna', requireAdmin, async (req, res) => {
  try {
    const resultado = await procesarTurnoEntrevistaMascota({
      idAdmin: req.adminId,
      ficha: req.body?.ficha || {},
      historial: Array.isArray(req.body?.historial) ? req.body.historial : [],
      mensaje: req.body?.mensaje || '',
      reiniciar: req.body?.reiniciar === true,
    });
    res.json(resultado);
  } catch (error) {
    console.error('Error en entrevista asistente de Paw Match:', error.message || error);
    if (error.estado === 503) {
      return res.status(503).json({
        error: 'El asistente de Paw Match está ocupado en este momento. Inténtalo de nuevo.',
      });
    }
    res.status(502).json({
      error: 'No se pudo guardar o procesar la respuesta en este momento. Por favor reintenta.',
    });
  }
});

router.put('/entrevista-luna/borrador', requireAdmin, async (req, res) => {
  try {
    const limites = await obtenerLimitesColumnasMascota();
    const existente = await obtenerBorradorMascotaDeBd(req.adminId);
    const fichaNormalizada = normalizarFicha(
      req.body?.ficha || {},
      existente?.ficha || {},
      limites,
    );
    await guardarBorradorMascotaEnBd(
      req.adminId,
      fichaNormalizada,
      req.body?.paso_actual || existente?.pasoActual || 'revision',
      Array.isArray(req.body?.historial)
        ? req.body.historial
        : existente?.historial || [],
    );
    res.json({ ok: true, ficha: fichaNormalizada, guardado_en_bd: true });
  } catch (error) {
    console.error('Error guardando borrador de mascota:', error.message || error);
    res.status(500).json({
      error: 'No se pudo guardar el avance en la base de datos. Inténtalo de nuevo.',
    });
  }
});

router.delete('/entrevista-luna/borrador', requireAdmin, async (req, res) => {
  try {
    await eliminarBorradorMascotaDeBd(req.adminId);
    res.json({ ok: true });
  } catch (error) {
    console.error('Error eliminando borrador de mascota:', error.message || error);
    res.status(500).json({ error: 'No se pudo limpiar el borrador.' });
  }
});

router.post('/foto', requireAdmin, upload.single('foto'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No se recibió ninguna foto' });

  // Quita el fondo (queda un PNG transparente). Si falla, se conserva la foto original.
  const rutaFinal = await quitarFondo(req.file.path);

  res.status(201).json({ ruta: `/uploads/mascotas/${path.basename(rutaFinal)}` });
});

router.post('/', requireAdmin, async (req, res) => {
  const {
    nombre, especie, raza, sexo, tamano, descripcion, esterilizado,
    vacunas, fotos, estado_adopcion: estadoAdopcion = 'disponible',
    estado_apadrinamiento: estadoApadrinamiento = 'disponible',
    estado_salud: estadoSalud,
    detalle_salud: detalleSalud = null,
  } = req.body;
  if (!nombre || !especie) return res.status(400).json({ error: 'Nombre y especie son obligatorios' });
  const fechaLeida = leerFechaNacimiento(req.body.fecha_nacimiento);
  if (fechaLeida.error) return res.status(400).json({ error: fechaLeida.error });
  const personalidadLeida = leerPersonalidad(req.body);
  if (personalidadLeida.error) {
    return res.status(400).json({ error: personalidadLeida.error });
  }

  const { estadoSaludDb, vacunas: vacunasFinal, esterilizado: esterilizadoFinal } =
    procesarEstadoSaludYProcedimientos(estadoSalud, vacunas, esterilizado);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const pet = await client.query(
      `INSERT INTO mascota
       (id_mascota, nombre, especie, raza, edad, unidad_edad, sexo, tamano, descripcion,
        esterilizado, vacunas, fotos, fecha_ingreso, fecha_creacion, fecha_actualizacion, estado_adopcion,
        estado_apadrinamiento, estado_salud, detalle_salud, id_administrador,
        personalidad_definida, fecha_nacimiento)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, CURRENT_DATE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
               $13, $14, $15, $16, $17, $18, $19) RETURNING id_mascota`,
      [randomUUID(), nombre, especie, raza || null, fechaLeida.edad, fechaLeida.unidad, sexo || null,
        tamano || null, descripcion || null, esterilizadoFinal, vacunasFinal,
        fotos || null, estadoAdopcion, estadoApadrinamiento,
        estadoSaludDb, detalleSalud || null, req.adminId, personalidadLeida.definida,
        fechaLeida.fecha],
    );
    const idMascota = pet.rows[0].id_mascota;
    await client.query(
      `INSERT INTO personalidadmascota
       (id_perfil_mascota, id_mascota, ${personalityColumns.join(', ')}, fecha_actualizacion)
       VALUES ($1, $2, ${personalityColumns.map((_, i) => `$${i + 3}`).join(', ')}, CURRENT_TIMESTAMP)`,
      [randomUUID(), idMascota, ...personalidadLeida.valores],
    );
    const result = await client.query(`${petSelect} WHERE m.id_mascota = $1`, [idMascota]);
    // Eliminación transaccional del borrador: garantiza que no quede como borrador y como mascota definitiva
    await client.query(
      'DELETE FROM borrador_mascota_formulario_ia WHERE id_administrador::text = $1::text OR LOWER(nombre) = LOWER($2)',
      [String(req.adminId), String(nombre).trim()],
    ).catch(() => {});
    await client.query('DROP TABLE IF EXISTS borrador_registro_mascota_luna CASCADE').catch(() => {});
    await client.query('DROP TABLE IF EXISTS borrador_mascota_ia CASCADE').catch(() => {});
    await client.query('COMMIT');
    procesarNuevaMascotaParaUsuarios(idMascota).catch((err) => {
      console.error('Error evaluando nueva mascota para Match:', err.message);
    });
    res.status(201).json(result.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error(error);
    res.status(500).json({ error: 'No se pudo crear la mascota' });
  } finally {
    client.release();
  }
});

router.put('/:id', requireAdmin, async (req, res) => {
  const {
    nombre, especie, raza, sexo, tamano, descripcion, esterilizado,
    vacunas, fotos, estado_adopcion: estadoAdopcion, estado_apadrinamiento: estadoApadrinamiento,
    estado_salud: estadoSalud,
    detalle_salud: detalleSalud = null,
  } = req.body;
  const fechaLeida = leerFechaNacimiento(req.body.fecha_nacimiento, { obligatoria: false });
  if (fechaLeida.error) return res.status(400).json({ error: fechaLeida.error });
  const personalidadLeida = leerPersonalidad(req.body);
  if (personalidadLeida.error) {
    return res.status(400).json({ error: personalidadLeida.error });
  }

  const { estadoSaludDb, vacunas: vacunasFinal, esterilizado: esterilizadoFinal } =
    procesarEstadoSaludYProcedimientos(estadoSalud, vacunas, esterilizado);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // IMPORTANTE: No se modifica fecha_creacion en UPDATE para no reiniciar las 48h de «NUEVO».
    const pet = await client.query(
      `UPDATE mascota SET nombre = $1, especie = $2, raza = $3,
       edad = COALESCE($4, edad), unidad_edad = COALESCE($5, unidad_edad), sexo = $6,
       tamano = $7, descripcion = $8, esterilizado = $9, vacunas = $10, fotos = $11,
       estado_adopcion = $12, estado_apadrinamiento = $13,
       estado_salud = $14, detalle_salud = $15, personalidad_definida = $16,
       fecha_nacimiento = COALESCE($17::date, fecha_nacimiento),
       fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_mascota = $18
       RETURNING id_mascota`,
      [nombre, especie, raza || null, fechaLeida.edad, fechaLeida.unidad, sexo || null, tamano || null,
        descripcion || null, esterilizadoFinal, vacunasFinal, fotos || null,
        estadoAdopcion, estadoApadrinamiento,
        estadoSaludDb, detalleSalud || null, personalidadLeida.definida, fechaLeida.fecha,
        req.params.id],
    );
    if (pet.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Mascota no encontrada' });
    }
    const personalidadActualizada = await client.query(
      `UPDATE personalidadmascota SET ${personalityColumns.map((column, i) => `${column} = $${i + 1}`).join(', ')},
       fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_mascota = $${personalityColumns.length + 1}`,
      [...personalidadLeida.valores, req.params.id],
    );
    if (personalidadActualizada.rowCount === 0) {
      await client.query(
        `INSERT INTO personalidadmascota
         (id_perfil_mascota, id_mascota, ${personalityColumns.join(', ')}, fecha_actualizacion)
         VALUES ($1, $2, ${personalityColumns.map((_, i) => `$${i + 3}`).join(', ')}, CURRENT_TIMESTAMP)`,
        [randomUUID(), req.params.id, ...personalidadLeida.valores],
      );
    }
    const result = await client.query(`${petSelect} WHERE m.id_mascota = $1`, [req.params.id]);
    await client.query('COMMIT');
    if (personalidadLeida.definida) {
      procesarNuevaMascotaParaUsuarios(req.params.id).catch((err) => {
        console.error('Error evaluando mascota actualizada para Match:', err.message);
      });
    }
    res.json(result.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error(error);
    res.status(500).json({ error: 'No se pudo actualizar la mascota' });
  } finally {
    client.release();
  }
});

router.delete('/:id', requireAdmin, async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM mascota WHERE id_mascota = $1 RETURNING id_mascota', [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Mascota no encontrada' });
    res.json({ ok: true });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo eliminar la mascota' });
  }
});

module.exports = router;
