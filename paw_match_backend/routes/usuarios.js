const express = require('express');
const bcrypt = require('bcrypt');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { randomUUID } = require('crypto');
const pool = require('../db');

const uploadDirectory = path.join(__dirname, '..', 'uploads', 'usuarios');
fs.mkdirSync(uploadDirectory, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: uploadDirectory,
    filename: (_req, file, callback) => {
      callback(null, `${randomUUID()}${path.extname(file.originalname).toLowerCase()}`);
    },
  }),
});

const router = express.Router();

// POST /api/usuarios/registro
router.post('/registro', async (req, res) => {
  const { nombres, apellidos, correo, telefono, contrasena, fecha_nacimiento } = req.body;

  if (!nombres || !apellidos || !correo || !contrasena) {
    return res.status(400).json({ error: 'Faltan campos obligatorios' });
  }

  try {
    const existe = await pool.query(
      'SELECT id_usuario FROM Usuario WHERE correo = $1',
      [correo]
    );

    if (existe.rows.length > 0) {
      return res.status(409).json({ error: 'Ese correo ya está registrado' });
    }

    const contrasena_hash = await bcrypt.hash(contrasena, 10);

    const resultado = await pool.query(
      `INSERT INTO Usuario (nombres, apellidos, correo, telefono, fecha_nacimiento, contrasena_hash, rol)
       VALUES ($1, $2, $3, $4, $5, $6, 'usuario')
       RETURNING id_usuario, nombres, apellidos, correo, telefono, fecha_nacimiento, rol, fecha_registro`,
      [nombres, apellidos, correo, telefono, fecha_nacimiento || null, contrasena_hash]
    );

    res.status(201).json(resultado.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al registrar el usuario' });
  }
});

// POST /api/usuarios/login
router.post('/login', async (req, res) => {
  const { correo, contrasena } = req.body;

  if (!correo || !contrasena) {
    return res.status(400).json({ error: 'Correo y contraseña son obligatorios' });
  }

  try {
    const resultado = await pool.query(
      `SELECT id_usuario, nombres, apellidos, correo, rol, contrasena_hash
       FROM Usuario WHERE correo = $1`,
      [correo]
    );

    if (resultado.rows.length === 0) {
      return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
    }

    const usuario = resultado.rows[0];
    const coincide = await bcrypt.compare(contrasena, usuario.contrasena_hash);

    if (!coincide) {
      return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
    }

    delete usuario.contrasena_hash;
    res.status(200).json(usuario);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al iniciar sesión' });
  }
});

const perfilSelect = `
  SELECT id_usuario, nombres, apellidos, correo, telefono, direccion,
         documento_identidad, fecha_nacimiento, foto_perfil
  FROM usuario
`;

router.post('/foto', upload.single('foto'), async (req, res) => {
  if (!req.header('x-usuario-id')) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }
  if (!req.file) return res.status(400).json({ error: 'No se recibió la foto' });
  res.status(201).json({ ruta: `/uploads/usuarios/${req.file.filename}` });
});

router.get('/:id', async (req, res) => {
  try {
    const resultado = await pool.query(`${perfilSelect} WHERE id_usuario = $1`, [req.params.id]);
    if (resultado.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json(resultado.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo cargar el perfil' });
  }
});

router.put('/:id', async (req, res) => {
  const { nombres, apellidos, correo, telefono, direccion, documento_identidad, fecha_nacimiento, foto_perfil } = req.body;

  if (!nombres || !apellidos || !correo) {
    return res.status(400).json({ error: 'Nombres, apellidos y correo son obligatorios' });
  }

  try {
    const repetido = await pool.query(
      'SELECT id_usuario FROM usuario WHERE correo = $1 AND id_usuario <> $2',
      [correo, req.params.id]
    );
    if (repetido.rows.length > 0) {
      return res.status(409).json({ error: 'Ese correo ya está registrado' });
    }

    const resultado = await pool.query(
      `UPDATE usuario
       SET nombres = $1, apellidos = $2, correo = $3, telefono = $4,
           direccion = $5, documento_identidad = $6, fecha_nacimiento = $7, foto_perfil = $8
       WHERE id_usuario = $9
       RETURNING id_usuario, nombres, apellidos, correo, telefono, direccion,
                 documento_identidad, fecha_nacimiento, foto_perfil`,
      [
        nombres,
        apellidos,
        correo,
        telefono || null,
        direccion || null,
        documento_identidad || null,
        fecha_nacimiento || null,
        foto_perfil || null,
        req.params.id,
      ]
    );

    if (resultado.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json(resultado.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo guardar el perfil' });
  }
});

module.exports = router;