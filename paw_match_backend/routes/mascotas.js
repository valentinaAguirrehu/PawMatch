const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { randomUUID } = require('crypto');
const pool = require('../db');

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

async function requireAdmin(req, res, next) {
  const userId = req.header('x-usuario-id');
  if (!userId) return res.status(401).json({ error: 'Debes iniciar sesión' });
  try {
    const result = await pool.query(
      "SELECT id_usuario FROM usuario WHERE id_usuario = $1 AND rol = 'administrador'",
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

const petSelect = `
  SELECT m.id_mascota, m.nombre, m.especie, m.raza, m.edad, m.sexo,
         m.tamano, m.descripcion, m.esterilizado, m.vacunas, m.fotos,
         m.estado_adopcion, m.estado_apadrinamiento,
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

router.post('/foto', requireAdmin, upload.single('foto'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No se recibió ninguna foto' });
  res.status(201).json({ ruta: `/uploads/mascotas/${req.file.filename}` });
});

router.post('/', requireAdmin, async (req, res) => {
  const {
    nombre, especie, raza, edad, sexo, tamano, descripcion, esterilizado,
    vacunas, fotos, estado_adopcion: estadoAdopcion = 'disponible',
    estado_apadrinamiento: estadoApadrinamiento = 'disponible', personalidad,
  } = req.body;
  if (!nombre || !especie) return res.status(400).json({ error: 'Nombre y especie son obligatorios' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const pet = await client.query(
      `INSERT INTO mascota
       (id_mascota, nombre, especie, raza, edad, sexo, tamano, descripcion,
        esterilizado, vacunas, fotos, fecha_ingreso, estado_adopcion,
        estado_apadrinamiento, id_administrador)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, CURRENT_DATE,
               $12, $13, $14) RETURNING id_mascota`,
      [randomUUID(), nombre, especie, raza || null, edad || null, sexo || null,
        tamano || null, descripcion || null, esterilizado === true, vacunas === true,
        fotos || null, estadoAdopcion, estadoApadrinamiento, req.adminId],
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
    nombre, especie, raza, edad, sexo, tamano, descripcion, esterilizado,
    vacunas, fotos, estado_adopcion: estadoAdopcion, estado_apadrinamiento: estadoApadrinamiento,
    personalidad,
  } = req.body;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const pet = await client.query(
      `UPDATE mascota SET nombre = $1, especie = $2, raza = $3, edad = $4, sexo = $5,
       tamano = $6, descripcion = $7, esterilizado = $8, vacunas = $9, fotos = $10,
       estado_adopcion = $11, estado_apadrinamiento = $12 WHERE id_mascota = $13
       RETURNING id_mascota`,
      [nombre, especie, raza || null, edad || null, sexo || null, tamano || null,
        descripcion || null, esterilizado === true, vacunas === true, fotos || null,
        estadoAdopcion, estadoApadrinamiento, req.params.id],
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