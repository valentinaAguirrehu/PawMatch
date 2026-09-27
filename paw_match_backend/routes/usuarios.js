const express = require('express');
const bcrypt = require('bcrypt');
const pool = require('../db');

const router = express.Router();

// POST /api/usuarios/registro
router.post('/registro', async (req, res) => {
  const { nombres, apellidos, correo, telefono, contrasena } = req.body;

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
      `INSERT INTO Usuario (nombres, apellidos, correo, telefono, contrasena_hash, rol)
       VALUES ($1, $2, $3, $4, $5, 'usuario')
       RETURNING id_usuario, nombres, apellidos, correo, rol, fecha_registro`,
      [nombres, apellidos, correo, telefono, contrasena_hash]
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

module.exports = router;