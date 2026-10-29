const express = require('express');
const bcrypt = require('bcrypt');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { randomUUID } = require('crypto');
const pool = require('../db');
const { enviarCorreoRecuperacionContrasena } = require('../utils/correo');

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

const personalityColumns = [
  'nivel_energia', 'sociabilidad_personas', 'sociabilidad_mascotas',
  'independencia', 'nivel_juego', 'carino', 'proteccion',
  'tolerancia_soledad', 'adaptabilidad',
];

function personalityValues(personality = {}) {
  const values = [];
  for (const column of personalityColumns) {
    const value = Number(personality[column]);
    if (!Number.isInteger(value) || value < 1 || value > 5) return null;
    values.push(value);
  }
  return values;
}

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
      `SELECT id_usuario, nombres, apellidos, correo, telefono, documento_identidad, rol, estado_cuenta, contrasena_hash
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

    // NUEVO: una cuenta inactiva o suspendida no puede ingresar (RF02)
    if (usuario.estado_cuenta !== 'activo') {
      return res.status(403).json({
        error: 'Tu cuenta está inactiva. Comunícate con la Fundación.',
      });
    }

    delete usuario.contrasena_hash;
    delete usuario.estado_cuenta;
    res.status(200).json(usuario);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al iniciar sesión' });
  }
});

// POST /api/usuarios/olvide-contrasena
router.post('/olvide-contrasena', async (req, res) => {
  const { correo } = req.body;
  if (!correo || !correo.trim() || !correo.includes('@')) {
    return res.status(400).json({ error: 'Ingresa un correo electrónico válido.' });
  }

  const correoLimpio = correo.trim().toLowerCase();

  try {
    const resultado = await pool.query(
      'SELECT id_usuario, nombres, apellidos, correo, estado_cuenta FROM usuario WHERE LOWER(TRIM(correo)) = $1',
      [correoLimpio]
    );

    if (resultado.rows.length === 0) {
      return res.status(404).json({
        error: 'El correo electrónico no se encuentra registrado en el sistema.',
      });
    }

    const usuario = resultado.rows[0];

    if (usuario.estado_cuenta && usuario.estado_cuenta !== 'activo') {
      return res.status(403).json({
        error: 'Tu cuenta se encuentra inactiva. Comunícate con la fundación.',
      });
    }

    // Generar código numérico de 4 dígitos (1000 - 9999)
    const codigo = Math.floor(1000 + Math.random() * 9000).toString();

    // Guardar código y expiración (15 minutos) en la BD
    await pool.query(
      `UPDATE usuario
       SET token_recuperacion = $1,
           token_recuperacion_expira = NOW() + INTERVAL '15 minutes'
       WHERE id_usuario = $2`,
      [codigo, usuario.id_usuario]
    );

    // Enviar código por correo Gmail
    const envio = await enviarCorreoRecuperacionContrasena({
      destinatario: usuario.correo,
      nombreUsuario: usuario.nombres,
      codigo,
    });

    if (!envio.enviado && !envio.simulado) {
      console.error('Error al enviar correo de recuperación:', envio.error);
      return res.status(500).json({
        error: 'No se pudo enviar el correo de verificación. Intenta nuevamente.',
      });
    }

    res.json({
      mensaje: 'Te enviamos un código de verificación de 4 dígitos a tu correo.',
    });
  } catch (error) {
    console.error('Error en /olvide-contrasena:', error);
    res.status(500).json({ error: 'Error interno al procesar la solicitud.' });
  }
});

// POST /api/usuarios/verificar-codigo-recuperacion
router.post('/verificar-codigo-recuperacion', async (req, res) => {
  const { correo, codigo } = req.body;
  if (!correo || !codigo) {
    return res.status(400).json({ error: 'Correo y código son obligatorios.' });
  }

  const correoLimpio = correo.trim().toLowerCase();
  const codigoLimpio = codigo.trim();

  if (codigoLimpio.length !== 4) {
    return res.status(400).json({ error: 'El código debe tener 4 dígitos.' });
  }

  try {
    const resultado = await pool.query(
      `SELECT id_usuario, token_recuperacion, token_recuperacion_expira
       FROM usuario
       WHERE LOWER(TRIM(correo)) = $1`,
      [correoLimpio]
    );

    if (resultado.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado.' });
    }

    const usuario = resultado.rows[0];

    if (!usuario.token_recuperacion) {
      return res.status(400).json({
        error: 'No hay ninguna solicitud de recuperación activa para este correo.',
      });
    }

    if (usuario.token_recuperacion !== codigoLimpio) {
      return res.status(400).json({ error: 'El código ingresado es incorrecto.' });
    }

    if (new Date() > new Date(usuario.token_recuperacion_expira)) {
      return res.status(400).json({
        error: 'El código ha expirado. Por favor solicita uno nuevo.',
      });
    }

    res.json({
      valido: true,
      mensaje: 'Código verificado con éxito.',
    });
  } catch (error) {
    console.error('Error en /verificar-codigo-recuperacion:', error);
    res.status(500).json({ error: 'Error al verificar el código.' });
  }
});

// POST /api/usuarios/restablecer-contrasena
router.post('/restablecer-contrasena', async (req, res) => {
  const { correo, codigo, contrasena } = req.body;

  if (!correo || !codigo || !contrasena) {
    return res.status(400).json({ error: 'Todos los campos son obligatorios.' });
  }

  if (contrasena.length < 6) {
    return res.status(400).json({
      error: 'La nueva contraseña debe tener al menos 6 caracteres.',
    });
  }

  const correoLimpio = correo.trim().toLowerCase();
  const codigoLimpio = codigo.trim();

  try {
    const resultado = await pool.query(
      `SELECT id_usuario, token_recuperacion, token_recuperacion_expira
       FROM usuario
       WHERE LOWER(TRIM(correo)) = $1`,
      [correoLimpio]
    );

    if (resultado.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado.' });
    }

    const usuario = resultado.rows[0];

    if (!usuario.token_recuperacion || usuario.token_recuperacion !== codigoLimpio) {
      return res.status(400).json({ error: 'El código es inválido o ya fue utilizado.' });
    }

    if (new Date() > new Date(usuario.token_recuperacion_expira)) {
      return res.status(400).json({
        error: 'El código ha expirado. Solicita un nuevo código.',
      });
    }

    const contrasena_hash = await bcrypt.hash(contrasena, 10);

    await pool.query(
      `UPDATE usuario
       SET contrasena_hash = $1,
           token_recuperacion = NULL,
           token_recuperacion_expira = NULL
       WHERE id_usuario = $2`,
      [contrasena_hash, usuario.id_usuario]
    );

    res.json({ mensaje: 'Tu contraseña ha sido restablecida con éxito.' });
  } catch (error) {
    console.error('Error en /restablecer-contrasena:', error);
    res.status(500).json({ error: 'Error al restablecer la contraseña.' });
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

// GET /api/usuarios/:id/personalidad — existe y, si hay fila, las respuestas
router.get('/:id/personalidad', async (req, res) => {
  try {
    const resultado = await pool.query(
      `SELECT id_perfil_usuario, id_usuario, ${personalityColumns.join(', ')}, fecha_actualizacion
       FROM personalidadusuario WHERE id_usuario = $1`,
      [req.params.id],
    );
    res.set('Cache-Control', 'no-store');
    if (resultado.rows.length === 0) {
      return res.json({ existe: false });
    }
    res.json({ existe: true, ...resultado.rows[0] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo consultar la personalidad' });
  }
});

// POST /api/usuarios/:id/personalidad — un registro por usuario
router.post('/:id/personalidad', async (req, res) => {
  const sesion = req.header('x-usuario-id');
  if (!sesion || sesion !== req.params.id) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }

  const valores = personalityValues(req.body);
  if (!valores) {
    return res.status(400).json({ error: 'Cada rasgo debe ser un número del 1 al 5' });
  }

  try {
    const resultado = await pool.query(
      `INSERT INTO personalidadusuario
       (id_usuario, ${personalityColumns.join(', ')}, fecha_actualizacion)
       VALUES ($1, ${personalityColumns.map((_, i) => `$${i + 2}`).join(', ')}, CURRENT_TIMESTAMP)
       RETURNING id_perfil_usuario, id_usuario, ${personalityColumns.join(', ')}, fecha_actualizacion`,
      [req.params.id, ...valores],
    );
    res.status(201).json(resultado.rows[0]);
  } catch (error) {
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Ya registraste tu personalidad' });
    }
    if (error.code === '23503') {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    console.error(error);
    res.status(500).json({ error: 'No se pudo guardar la personalidad' });
  }
});

// PUT /api/usuarios/:id/personalidad — actualiza las respuestas del usuario
router.put('/:id/personalidad', async (req, res) => {
  const sesion = req.header('x-usuario-id');
  if (!sesion || sesion !== req.params.id) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }

  const valores = personalityValues(req.body);
  if (!valores) {
    return res.status(400).json({ error: 'Cada rasgo debe ser un número del 1 al 5' });
  }

  try {
    const resultado = await pool.query(
      `UPDATE personalidadusuario
       SET ${personalityColumns.map((column, i) => `${column} = $${i + 1}`).join(', ')},
           fecha_actualizacion = CURRENT_TIMESTAMP
       WHERE id_usuario = $${personalityColumns.length + 1}
       RETURNING id_perfil_usuario, id_usuario, ${personalityColumns.join(', ')}, fecha_actualizacion`,
      [...valores, req.params.id],
    );
    if (resultado.rows.length === 0) {
      return res.status(404).json({ error: 'Aún no registras tu personalidad' });
    }
    res.json(resultado.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo actualizar la personalidad' });
  }
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

router.put('/:id/contrasena', async (req, res) => {
  const { contrasena } = req.body;
  if (!contrasena || String(contrasena).length < 6) {
    return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
  }

  try {
    const contrasena_hash = await bcrypt.hash(contrasena, 10);
    const resultado = await pool.query(
      'UPDATE usuario SET contrasena_hash = $1 WHERE id_usuario = $2 RETURNING id_usuario',
      [contrasena_hash, req.params.id]
    );
    if (resultado.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json({ mensaje: 'Contraseña actualizada' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo actualizar la contraseña' });
  }
});

router.patch('/:id/correo', async (req, res) => {
  const { correo } = req.body;
  if (!correo || !correo.trim() || !correo.includes('@') || !correo.includes('.')) {
    return res.status(400).json({ error: 'Debes proporcionar un correo electrónico válido' });
  }

  const correoLimpio = correo.trim().toLowerCase();

  try {
    const repetido = await pool.query(
      'SELECT id_usuario FROM usuario WHERE LOWER(correo) = $1 AND id_usuario <> $2',
      [correoLimpio, req.params.id]
    );
    if (repetido.rows.length > 0) {
      return res.status(409).json({ error: 'Ese correo ya está registrado en otra cuenta' });
    }

    const resultado = await pool.query(
      'UPDATE usuario SET correo = $1 WHERE id_usuario = $2 RETURNING id_usuario, correo, nombres, apellidos',
      [correoLimpio, req.params.id]
    );

    if (resultado.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    res.json({ mensaje: 'Correo actualizado exitosamente', usuario: resultado.rows[0] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo actualizar el correo' });
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