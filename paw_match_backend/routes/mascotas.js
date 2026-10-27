const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { randomUUID } = require('crypto');
const pool = require('../db');
const { quitarFondo } = require('../utils/quitarFondo');

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
const esquemaListo = pool.query(`
  ALTER TABLE mascota
    ADD COLUMN IF NOT EXISTS unidad_edad VARCHAR(10) NOT NULL DEFAULT 'anos',
    ADD COLUMN IF NOT EXISTS estado_salud TEXT NOT NULL DEFAULT '["No presenta necesidades veterinarias pendientes."]',
    ADD COLUMN IF NOT EXISTS detalle_salud TEXT,
    ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
`).catch((err) => {
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
      "SELECT id_usuario FROM usuario WHERE id_usuario = $1 AND LOWER(rol) IN ('administrador', 'superadmin')",
      [userId],
    );
    if (result.rows.length === 0) {
      return res.status(403).json({ error: 'Solo un administrador puede gestionar mascotas' });
    }
    req.adminId = userId;
    next();
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo validar el administrador' });
  }
}

function personalityValues(personality = {}) {
  return personalityColumns.map((column) => {
    const value = Number(personality[column]);
    return Number.isInteger(value) && value >= 1 && value <= 5 ? value : 3;
  });
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

// fecha_ingreso va como texto 'YYYY-MM-DD' para evitar desfases de zona horaria
const petSelect = `
  SELECT m.id_mascota, m.nombre, m.especie, m.raza, m.edad, m.unidad_edad, m.sexo,
         m.tamano, m.descripcion, m.esterilizado, m.vacunas, m.fotos,
         m.estado_adopcion, m.estado_apadrinamiento,
         COALESCE(m.estado_salud, '["No presenta necesidades veterinarias pendientes."]') AS estado_salud,
         m.detalle_salud,
         to_char(m.fecha_ingreso, 'YYYY-MM-DD') AS fecha_ingreso,
         to_char(m.fecha_actualizacion, 'YYYY-MM-DD HH24:MI') AS fecha_actualizacion,
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

router.post('/foto', requireAdmin, upload.single('foto'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No se recibió ninguna foto' });

  // Quita el fondo (queda un PNG transparente). Si falla, se conserva la foto original.
  const rutaFinal = await quitarFondo(req.file.path);

  res.status(201).json({ ruta: `/uploads/mascotas/${path.basename(rutaFinal)}` });
});

router.post('/', requireAdmin, async (req, res) => {
  const {
    nombre, especie, raza, edad, unidad_edad: unidadEdad = 'anos', sexo, tamano, descripcion, esterilizado,
    vacunas, fotos, estado_adopcion: estadoAdopcion = 'disponible',
    estado_apadrinamiento: estadoApadrinamiento = 'disponible',
    estado_salud: estadoSalud,
    detalle_salud: detalleSalud = null,
    personalidad,
  } = req.body;
  if (!nombre || !especie) return res.status(400).json({ error: 'Nombre y especie son obligatorios' });

  const { estadoSaludDb, vacunas: vacunasFinal, esterilizado: esterilizadoFinal } =
    procesarEstadoSaludYProcedimientos(estadoSalud, vacunas, esterilizado);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const pet = await client.query(
      `INSERT INTO mascota
       (id_mascota, nombre, especie, raza, edad, unidad_edad, sexo, tamano, descripcion,
        esterilizado, vacunas, fotos, fecha_ingreso, fecha_actualizacion, estado_adopcion,
        estado_apadrinamiento, estado_salud, detalle_salud, id_administrador)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, CURRENT_DATE, CURRENT_TIMESTAMP,
               $13, $14, $15, $16, $17) RETURNING id_mascota`,
      [randomUUID(), nombre, especie, raza || null, edad || null, unidadEdad || 'anos', sexo || null,
        tamano || null, descripcion || null, esterilizadoFinal, vacunasFinal,
        fotos || null, estadoAdopcion, estadoApadrinamiento,
        estadoSaludDb, detalleSalud || null, req.adminId],
    );
    const idMascota = pet.rows[0].id_mascota;
    await client.query(
      `INSERT INTO personalidadmascota
       (id_perfil_mascota, id_mascota, ${personalityColumns.join(', ')}, fecha_actualizacion)
       VALUES ($1, $2, ${personalityColumns.map((_, i) => `$${i + 3}`).join(', ')}, CURRENT_TIMESTAMP)`,
      [randomUUID(), idMascota, ...personalityValues(personalidad)],
    );
    const result = await client.query(`${petSelect} WHERE m.id_mascota = $1`, [idMascota]);
    await client.query('COMMIT');
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
    nombre, especie, raza, edad, unidad_edad: unidadEdad = 'anos', sexo, tamano, descripcion, esterilizado,
    vacunas, fotos, estado_adopcion: estadoAdopcion, estado_apadrinamiento: estadoApadrinamiento,
    estado_salud: estadoSalud,
    detalle_salud: detalleSalud = null,
    personalidad,
  } = req.body;

  const { estadoSaludDb, vacunas: vacunasFinal, esterilizado: esterilizadoFinal } =
    procesarEstadoSaludYProcedimientos(estadoSalud, vacunas, esterilizado);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const pet = await client.query(
      `UPDATE mascota SET nombre = $1, especie = $2, raza = $3, edad = $4, unidad_edad = $5, sexo = $6,
       tamano = $7, descripcion = $8, esterilizado = $9, vacunas = $10, fotos = $11,
       estado_adopcion = $12, estado_apadrinamiento = $13,
       estado_salud = $14, detalle_salud = $15, fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_mascota = $16
       RETURNING id_mascota`,
      [nombre, especie, raza || null, edad || null, unidadEdad || 'anos', sexo || null, tamano || null,
        descripcion || null, esterilizadoFinal, vacunasFinal, fotos || null,
        estadoAdopcion, estadoApadrinamiento,
        estadoSaludDb, detalleSalud || null, req.params.id],
    );
    if (pet.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Mascota no encontrada' });
    }
    await client.query(
      `UPDATE personalidadmascota SET ${personalityColumns.map((column, i) => `${column} = $${i + 1}`).join(', ')},
       fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_mascota = $${personalityColumns.length + 1}`,
      [...personalityValues(personalidad), req.params.id],
    );
    const result = await client.query(`${petSelect} WHERE m.id_mascota = $1`, [req.params.id]);
    await client.query('COMMIT');
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