const express = require('express');
const bcrypt = require('bcrypt');
const pool = require('../db');

const router = express.Router();

// Columnas que se devuelven (nunca contrasena_hash ni tokens)
const COLUMNAS =
  'id_usuario, nombres, apellidos, correo, telefono, rol, estado_cuenta, fecha_registro';

// ---------------------------------------------------------------
// Middleware: solo un administrador activo puede usar estas rutas.
// La app envía el id del usuario logueado en el header "x-usuario-id".
// ---------------------------------------------------------------
async function soloAdmin(req, res, next) {
  const idUsuario = req.header('x-usuario-id');
  if (!idUsuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }
  try {
    const r = await pool.query(
      'SELECT rol, estado_cuenta FROM Usuario WHERE id_usuario = $1',
      [idUsuario]
    );
    if (r.rows.length === 0) {
      return res.status(401).json({ error: 'Usuario no válido' });
    }
    if (r.rows[0].rol !== 'administrador' || r.rows[0].estado_cuenta !== 'activo') {
      return res.status(403).json({ error: 'Solo el administrador puede hacer esto' });
    }
    req.idAdmin = idUsuario;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Usuario no válido' });
  }
}

router.use(soloAdmin);

// ---------------------------------------------------------------
// GET /api/admin/usuarios?rol=usuario|administrador&q=texto
// Lista las cuentas (por defecto, los usuarios adoptantes/padrinos).
// ---------------------------------------------------------------
router.get('/', async (req, res) => {
  const rol = req.query.rol || 'usuario';
  if (!['usuario', 'administrador'].includes(rol)) {
    return res.status(400).json({ error: 'Rol no válido' });
  }

  const params = [rol];
  let filtro = '';
  if (req.query.q) {
    params.push(`%${req.query.q}%`);
    filtro = `AND (nombres ILIKE $2 OR apellidos ILIKE $2 OR correo ILIKE $2)`;
  }

  try {
    const r = await pool.query(
      `SELECT ${COLUMNAS} FROM Usuario
       WHERE rol = $1 ${filtro}
       ORDER BY fecha_registro DESC`,
      params
    );
    res.json(r.rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Error al consultar los usuarios' });
  }
});

// ---------------------------------------------------------------
// PATCH /api/admin/usuarios/:id/estado   { "estado_cuenta": "activo" | "inactivo" }
// Activa o desactiva el ingreso de un usuario. No aplica a administradores
// (así nadie se puede dejar fuera del sistema por accidente).
// ---------------------------------------------------------------
router.patch('/:id/estado', async (req, res) => {
  const { estado_cuenta } = req.body;
  if (!['activo', 'inactivo'].includes(estado_cuenta)) {
    return res.status(400).json({ error: 'Estado no válido (activo o inactivo)' });
  }

  try {
    const actual = await pool.query('SELECT rol FROM Usuario WHERE id_usuario = $1', [
      req.params.id,
    ]);
    if (actual.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    if (actual.rows[0].rol !== 'usuario') {
      return res
        .status(403)
        .json({ error: 'No se puede cambiar el estado de un administrador' });
    }

    const r = await pool.query(
      `UPDATE Usuario SET estado_cuenta = $1 WHERE id_usuario = $2
       RETURNING ${COLUMNAS}`,
      [estado_cuenta, req.params.id]
    );
    res.json(r.rows[0]);
  } catch (e) {
    if (e.code === '22P02') return res.status(404).json({ error: 'Usuario no encontrado' });
    console.error(e);
    res.status(500).json({ error: 'Error al actualizar el usuario' });
  }
});

// ---------------------------------------------------------------
// POST /api/admin/usuarios/administradores
// Crea una cuenta con rol administrador. Es la ÚNICA forma de crear
// administradores (el registro público siempre crea usuarios normales).
// ---------------------------------------------------------------
router.post('/administradores', async (req, res) => {
  const limpiar = (v) => (typeof v === 'string' ? v.trim() : '');
  const nombres = limpiar(req.body.nombres);
  const apellidos = limpiar(req.body.apellidos);
  const correo = limpiar(req.body.correo);
  const telefono = limpiar(req.body.telefono) || null;
  const contrasena = typeof req.body.contrasena === 'string' ? req.body.contrasena : '';

  if (!nombres || !apellidos || !correo || !contrasena) {
    return res.status(400).json({ error: 'Faltan campos obligatorios' });
  }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(correo)) {
    return res.status(400).json({ error: 'El correo no es válido' });
  }
  if (contrasena.length < 8) {
    return res.status(400).json({ error: 'La contraseña debe tener al menos 8 caracteres' });
  }

  try {
    const existe = await pool.query(
      'SELECT 1 FROM Usuario WHERE LOWER(correo) = LOWER($1)',
      [correo]
    );
    if (existe.rows.length > 0) {
      return res.status(409).json({ error: 'Ese correo ya está registrado' });
    }

    const hash = await bcrypt.hash(contrasena, 10);
    const r = await pool.query(
      `INSERT INTO Usuario (nombres, apellidos, correo, telefono, contrasena_hash, rol)
       VALUES ($1, $2, $3, $4, $5, 'administrador')
       RETURNING ${COLUMNAS}`,
      [nombres, apellidos, correo, telefono, hash]
    );
    res.status(201).json(r.rows[0]);
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: 'Ese correo ya está registrado' });
    console.error(e);
    res.status(500).json({ error: 'Error al crear el administrador' });
  }
});

module.exports = router;
