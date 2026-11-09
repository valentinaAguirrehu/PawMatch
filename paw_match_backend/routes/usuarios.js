const express = require('express');
const bcrypt = require('bcrypt');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { randomUUID } = require('crypto');
const pool = require('../db');
const {
  personalityColumns,
  validarRespuestasGuardado,
  listarBorradores,
  insertarRespuestas,
  borrarBorradoresUsuario,
  coincidenConBorradores,
} = require('../utils/entrevista_personalidad');
const {
  asegurarEsquemaMatch,
  sincronizarMatchDeUsuario,
  marcarAvisoReasignacionVisto,
} = require('../utils/match_persistencia');
const { generoValido } = require('../utils/genero_usuario');
const {
  VOCES,
  VOZ_DEFECTO,
  TEXTO_MUESTRA,
  vozValida,
  normalizarVoz,
  sintetizar,
} = require('../utils/voz_asistente');
const { esAdministrador } = require('../utils/roles');
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
  const { nombres, apellidos, correo, telefono, contrasena, fecha_nacimiento, genero } = req.body;

  if (!nombres || !apellidos || !correo || !contrasena) {
    return res.status(400).json({ error: 'Faltan campos obligatorios' });
  }
  const passStr = String(contrasena);
  if (
    passStr.length < 8 ||
    !/[A-Z]/.test(passStr) ||
    !/[a-z]/.test(passStr) ||
    !/[0-9]/.test(passStr) ||
    !/[@#$%&*]/.test(passStr)
  ) {
    return res.status(400).json({
      error:
        'La contraseña debe tener mínimo 8 caracteres, al menos una mayúscula (A-Z), una minúscula (a-z), un número (0-9) y un carácter especial (@, #, $, %, &, *).',
    });
  }
  if (!generoValido(genero)) {
    return res.status(400).json({ error: 'Selecciona si eres Hombre o Mujer' });
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
      `INSERT INTO Usuario (nombres, apellidos, correo, telefono, fecha_nacimiento, genero, contrasena_hash, rol)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'usuario')
       RETURNING id_usuario, nombres, apellidos, correo, telefono, fecha_nacimiento, genero, rol, fecha_registro`,
      [nombres, apellidos, correo, telefono, fecha_nacimiento || null, genero, contrasena_hash]
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
      `SELECT id_usuario, nombres, apellidos, correo, telefono, documento_identidad, genero, rol, estado_cuenta, contrasena_hash
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
         documento_identidad, fecha_nacimiento, foto_perfil, genero
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
    await asegurarEsquemaMatch();
    const resultado = await pool.query(
      `SELECT id_perfil_usuario, id_usuario, ${personalityColumns.join(', ')},
              id_mascota_match_inicial, porcentaje_match_inicial, fecha_match_inicial,
              fecha_actualizacion
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

function responderErrorPersonalidad(res, error) {
  if (error.code === '23505') {
    return res.status(409).json({ error: 'Ya registraste tu personalidad' });
  }
  if (error.code === '23503') {
    return res.status(404).json({ error: 'Usuario no encontrado' });
  }
  console.error(error);
  return res.status(500).json({ error: 'No se pudo guardar la personalidad' });
}

// POST /api/usuarios/:id/personalidad — un registro por usuario.
// Con `respuestas`, solo confirma lo que el asistente ya interpretó.
// Al guardar el cuestionario por primera vez, asigna y persiste su Match inicial.
router.post('/:id/personalidad', async (req, res) => {
  const sesion = req.header('x-usuario-id');
  if (!sesion || sesion !== req.params.id) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }

  const cuerpo = req.body && typeof req.body === 'object' ? req.body : {};
  const valores = personalityValues(cuerpo);
  if (!valores) {
    return res.status(400).json({ error: 'Cada rasgo debe ser un número del 1 al 5' });
  }

  const entrevista = validarRespuestasGuardado(cuerpo);
  if (entrevista.error) {
    return res.status(400).json({ error: entrevista.error });
  }

  await asegurarEsquemaMatch();

  const sqlInsert = `INSERT INTO personalidadusuario
       (id_usuario, ${personalityColumns.join(', ')}, fecha_actualizacion)
       VALUES ($1, ${personalityColumns.map((_, i) => `$${i + 2}`).join(', ')}, CURRENT_TIMESTAMP)
       RETURNING id_perfil_usuario, id_usuario, ${personalityColumns.join(', ')}, fecha_actualizacion`;
  const params = [req.params.id, ...valores];

  if (!entrevista.filas) {
    try {
      const resultado = await pool.query(sqlInsert, params);
      await sincronizarMatchDeUsuario(req.params.id).catch((err) => {
        console.error('Error sincronizando Match inicial:', err.message);
      });
      return res.status(201).json(resultado.rows[0]);
    } catch (error) {
      return responderErrorPersonalidad(res, error);
    }
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const borradores = await listarBorradores(client, req.params.id);
    if (!coincidenConBorradores(entrevista.filas, borradores)) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        error: 'Las respuestas no coinciden con la entrevista. Vuelve a enviar la pregunta que cambió.',
      });
    }
    const resultado = await client.query(sqlInsert, params);
    await insertarRespuestas(
      client,
      resultado.rows[0].id_perfil_usuario,
      req.params.id,
      borradores,
    );
    await borrarBorradoresUsuario(client, req.params.id);
    await sincronizarMatchDeUsuario(req.params.id, client);
    await client.query('COMMIT');
    return res.status(201).json(resultado.rows[0]);
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) { /* la transacción ya estaba cerrada */ }
    return responderErrorPersonalidad(res, error);
  } finally {
    client.release();
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
    await asegurarEsquemaMatch();
    const resultado = await pool.query(
      `UPDATE personalidadusuario
       SET ${personalityColumns.map((column, i) => `${column} = $${i + 1}`).join(', ')},
           fecha_actualizacion = CURRENT_TIMESTAMP
       WHERE id_usuario = $${personalityColumns.length + 1}
       RETURNING id_perfil_usuario, id_usuario, ${personalityColumns.join(', ')},
                 id_mascota_match_inicial, porcentaje_match_inicial, fecha_match_inicial,
                 fecha_actualizacion`,
      [...valores, req.params.id],
    );
    if (resultado.rows.length === 0) {
      return res.status(404).json({ error: 'Aún no registras tu personalidad' });
    }
    await sincronizarMatchDeUsuario(req.params.id).catch(() => {});
    res.json(resultado.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo actualizar la personalidad' });
  }
});

// GET /api/usuarios/:id/match-sincronizar
// Devuelve el Match inicial persistido del usuario y las notificaciones de nuevas coincidencias.
router.get('/:id/match-sincronizar', async (req, res) => {
  try {
    const datos = await sincronizarMatchDeUsuario(req.params.id);
    res.set('Cache-Control', 'no-store');
    res.json(datos);
  } catch (error) {
    console.error('Error en /match-sincronizar:', error);
    res.status(500).json({ error: 'No se pudo sincronizar el Match del usuario' });
  }
});

// PATCH /api/usuarios/:id/match-reasignacion/vista
// La persona ya leyó el aviso de que su Match Ideal fue adoptado y se le asignó otro.
router.patch('/:id/match-reasignacion/vista', async (req, res) => {
  try {
    const idAviso = req.body?.id_aviso;
    await marcarAvisoReasignacionVisto(req.params.id, idAviso);
    res.json({ ok: true });
  } catch (error) {
    console.error('Error en /match-reasignacion/vista:', error);
    res.status(500).json({ error: 'No se pudo cerrar el aviso de reasignación' });
  }
});

// PATCH /api/usuarios/:id/notificaciones-match/leer
// Marca como leídas y/o mostradas las notificaciones de nuevas mascotas compatibles.
router.patch('/:id/notificaciones-match/leer', async (req, res) => {
  try {
    await asegurarEsquemaMatch();
    const { id_mascota: idMascota, id_notificacion: idNotificacion, solo_mostrada: soloMostrada } = req.body || {};

    if (idNotificacion) {
      await pool.query(
        `UPDATE notificacion_match_usuario
         SET mostrada_en_mascotas = TRUE,
             leida = CASE WHEN $3::boolean THEN leida ELSE TRUE END,
             fecha_lectura = COALESCE(fecha_lectura, CURRENT_TIMESTAMP)
         WHERE id_usuario = $1 AND id_notificacion = $2`,
        [req.params.id, idNotificacion, soloMostrada === true],
      );
    } else if (idMascota) {
      await pool.query(
        `UPDATE notificacion_match_usuario
         SET mostrada_en_mascotas = TRUE,
             leida = CASE WHEN $3::boolean THEN leida ELSE TRUE END,
             fecha_lectura = COALESCE(fecha_lectura, CURRENT_TIMESTAMP)
         WHERE id_usuario = $1 AND id_mascota = $2`,
        [req.params.id, idMascota, soloMostrada === true],
      );
    } else {
      await pool.query(
        `UPDATE notificacion_match_usuario
         SET mostrada_en_mascotas = TRUE,
             leida = TRUE,
             fecha_lectura = COALESCE(fecha_lectura, CURRENT_TIMESTAMP)
         WHERE id_usuario = $1`,
        [req.params.id],
      );
    }

    res.json({ ok: true });
  } catch (error) {
    console.error('Error al marcar notificación de Match:', error);
    res.status(500).json({ error: 'No se pudo actualizar la notificación de Match' });
  }
});

function sesionPropia(req) {
  const sesion = req.header('x-usuario-id');
  return Boolean(sesion && sesion === req.params.id);
}

router.get('/voces-asistente', (_req, res) => {
  res.json({ defecto: VOZ_DEFECTO, voces: VOCES });
});

router.get('/:id/voz-asistente', async (req, res) => {
  if (!sesionPropia(req)) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }
  try {
    const resultado = await pool.query(
      'SELECT voz_asistente FROM usuario WHERE id_usuario = $1',
      [req.params.id],
    );
    if (resultado.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json({ voz: normalizarVoz(resultado.rows[0].voz_asistente) });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo leer la voz del asistente' });
  }
});

router.put('/:id/voz-asistente', async (req, res) => {
  if (!sesionPropia(req)) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }
  const voz = String(req.body?.voz || '').trim().toLowerCase();
  if (!vozValida(voz)) {
    return res.status(400).json({ error: 'Esa voz no está disponible' });
  }
  try {
    const resultado = await pool.query(
      `UPDATE usuario SET voz_asistente = $1
       WHERE id_usuario = $2
       RETURNING voz_asistente`,
      [voz, req.params.id],
    );
    if (resultado.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json({ voz: resultado.rows[0].voz_asistente });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo guardar la voz del asistente' });
  }
});

async function responderAudio(req, res, { texto, voz, velocidad }) {
  if (!sesionPropia(req)) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }
  try {
    const audio = await sintetizar({
      texto,
      voz: normalizarVoz(voz),
      velocidad,
    });
    res.set('Content-Type', 'audio/mpeg');
    res.set('Cache-Control', 'no-store');
    res.send(audio);
  } catch (error) {
    const estado = error.estado || 502;
    console.error('TTS:', error.detalle || error.message);
    if (res.headersSent) return;
    res.status(estado === 503 ? 503 : 502).json({
      error: estado === 503
        ? 'El asistente de voz no está configurado en el servidor.'
        : 'No se pudo generar la voz. Intenta de nuevo.',
    });
  }
}

router.post('/:id/voz-asistente/probar', async (req, res) => {
  const pedida = String(req.body?.voz || '').trim().toLowerCase();
  if (pedida && !vozValida(pedida)) {
    return res.status(400).json({ error: 'Esa voz no está disponible' });
  }
  return responderAudio(req, res, {
    texto: TEXTO_MUESTRA,
    voz: pedida || VOZ_DEFECTO,
    velocidad: 1,
  });
});

router.post('/:id/voz-asistente/hablar', async (req, res) => {
  const texto = String(req.body?.texto || '').trim();
  if (!texto) {
    return res.status(400).json({ error: 'Falta el texto para leer' });
  }
  const pedida = String(req.body?.voz || '').trim().toLowerCase();
  if (pedida && !vozValida(pedida)) {
    return res.status(400).json({ error: 'Esa voz no está disponible' });
  }
  let voz = pedida;
  if (!voz) {
    try {
      const resultado = await pool.query(
        'SELECT voz_asistente FROM usuario WHERE id_usuario = $1',
        [req.params.id],
      );
      voz = normalizarVoz(resultado.rows[0]?.voz_asistente);
    } catch (_) {
      voz = VOZ_DEFECTO;
    }
  }
  return responderAudio(req, res, {
    texto,
    voz,
    velocidad: req.body?.velocidad,
  });
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
  const {
    nombres, apellidos, correo, telefono, direccion,
    documento_identidad, fecha_nacimiento, foto_perfil, genero,
  } = req.body;

  if (!nombres || !apellidos || !correo) {
    return res.status(400).json({ error: 'Nombres, apellidos y correo son obligatorios' });
  }
  if (genero != null && String(genero).trim() !== '' && !generoValido(genero)) {
    return res.status(400).json({ error: 'Selecciona si eres Hombre o Mujer' });
  }

  try {
    const repetido = await pool.query(
      'SELECT id_usuario FROM usuario WHERE correo = $1 AND id_usuario <> $2',
      [correo, req.params.id]
    );
    if (repetido.rows.length > 0) {
      return res.status(409).json({ error: 'Ese correo ya está registrado' });
    }

    const guardaGenero = generoValido(genero);
    const resultado = await pool.query(
      `UPDATE usuario
       SET nombres = $1, apellidos = $2, correo = $3, telefono = $4,
           direccion = $5, documento_identidad = $6, fecha_nacimiento = $7, foto_perfil = $8,
           genero = CASE WHEN $9::boolean THEN $10 ELSE genero END
       WHERE id_usuario = $11
       RETURNING id_usuario, nombres, apellidos, correo, telefono, direccion,
                 documento_identidad, fecha_nacimiento, foto_perfil, genero`,
      [
        nombres,
        apellidos,
        correo,
        telefono || null,
        direccion || null,
        documento_identidad || null,
        fecha_nacimiento || null,
        foto_perfil || null,
        guardaGenero,
        guardaGenero ? genero : null,
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

const consultaAsociaciones = `
  SELECT 'adopción' AS tipo, lower(btrim(estado::text)) AS estado, COUNT(*)::int AS total
    FROM solicitudadopcion
   WHERE id_usuario = $1
     AND lower(btrim(estado::text)) <> 'rechazada'
   GROUP BY 2
  UNION ALL
  SELECT 'apadrinamiento', lower(btrim(estado::text)), COUNT(*)::int
    FROM solicitudapadrinamiento
   WHERE id_usuario = $1
     AND lower(btrim(estado::text)) <> 'rechazada'
   GROUP BY 2`;

function fraseAsociacion(fila) {
  const varias = fila.total > 1;
  const n = fila.total;
  if (fila.tipo === 'adopción') {
    if (fila.estado === 'pendiente') {
      return varias
        ? `${n} solicitudes de adopción en proceso`
        : 'una solicitud de adopción en proceso';
    }
    if (fila.estado === 'aprobada') {
      return varias ? `${n} adopciones realizadas` : 'una adopción realizada';
    }
    if (fila.estado === 'cancelada') {
      return varias ? `${n} adopciones canceladas` : 'una adopción cancelada';
    }
    return varias
      ? `${n} solicitudes de adopción asociadas a tu cuenta`
      : 'una solicitud de adopción asociada a tu cuenta';
  }
  if (fila.estado === 'pendiente') {
    return varias
      ? `${n} solicitudes de apadrinamiento en proceso`
      : 'una solicitud de apadrinamiento en proceso';
  }
  if (fila.estado === 'aprobada') {
    return varias ? `${n} apadrinamientos realizados` : 'un apadrinamiento realizado';
  }
  if (fila.estado === 'cancelada') {
    return varias ? `${n} apadrinamientos cancelados` : 'un apadrinamiento cancelado';
  }
  return varias
    ? `${n} solicitudes de apadrinamiento asociadas a tu cuenta`
    : 'una solicitud de apadrinamiento asociada a tu cuenta';
}

function mensajeBloqueoCuenta(filas) {
  const frases = filas.map(fraseAsociacion);
  const lista = frases.length === 1
    ? frases[0]
    : `${frases.slice(0, -1).join(', ')} y ${frases[frases.length - 1]}`;
  return `No puedes eliminar tu cuenta porque tienes ${lista}. `
    + 'La cuenta debe permanecer mientras exista una adopción o un apadrinamiento realizado, '
    + 'o una solicitud que todavía está en proceso.';
}

async function revisarEliminacionCuenta(idSesion, idCuenta) {
  if (!idSesion) {
    return { status: 401, body: { error: 'Debes iniciar sesión' } };
  }
  if (idSesion !== idCuenta) {
    return { status: 403, body: { error: 'Solo puedes eliminar tu propia cuenta' } };
  }

  const actual = await pool.query(
    'SELECT id_usuario, rol FROM usuario WHERE id_usuario = $1',
    [idCuenta]
  );
  if (actual.rows.length === 0) {
    return { status: 404, body: { error: 'Usuario no encontrado' } };
  }
  if (esAdministrador(actual.rows[0].rol)) {
    return {
      status: 403,
      body: {
        error: 'Los administradores y el superadministrador no pueden eliminar su cuenta desde el perfil',
      },
    };
  }

  const asociadas = await pool.query(consultaAsociaciones, [idCuenta]);
  if (asociadas.rows.length > 0) {
    return {
      status: 409,
      body: { puede: false, error: mensajeBloqueoCuenta(asociadas.rows) },
    };
  }
  return { status: 200, body: { puede: true } };
}

// GET /api/usuarios/:id/puede-eliminar
router.get('/:id/puede-eliminar', async (req, res) => {
  try {
    const revision = await revisarEliminacionCuenta(req.header('x-usuario-id'), req.params.id);
    if (revision.status === 409) {
      return res.json(revision.body);
    }
    if (revision.status !== 200) {
      return res.status(revision.status).json(revision.body);
    }
    res.json(revision.body);
  } catch (error) {
    if (error.code === '22P02') return res.status(404).json({ error: 'Usuario no encontrado' });
    console.error(error);
    res.status(500).json({ error: 'No se pudo revisar si la cuenta se puede eliminar' });
  }
});

// DELETE /api/usuarios/:id
// Solo una persona con rol usuario, y solo si no tiene adopciones ni
// apadrinamientos realizados o solicitudes en proceso.
router.delete('/:id', async (req, res) => {
  const client = await pool.connect();
  try {
    const revision = await revisarEliminacionCuenta(req.header('x-usuario-id'), req.params.id);
    if (revision.status !== 200) {
      return res.status(revision.status).json({ error: revision.body.error });
    }

    await client.query('BEGIN');
    await client.query(
      `DELETE FROM seguimientoadopcion
        WHERE id_solicitud_adopcion IN (
          SELECT id_solicitud_adopcion FROM solicitudadopcion
           WHERE id_usuario = $1 AND lower(btrim(estado::text)) = 'rechazada'
        )`,
      [req.params.id]
    );
    await client.query(
      `DELETE FROM seguimientoapadrinamiento
        WHERE id_solicitud_apadrinamiento IN (
          SELECT id_solicitud_apadrinamiento FROM solicitudapadrinamiento
           WHERE id_usuario = $1 AND lower(btrim(estado::text)) = 'rechazada'
        )`,
      [req.params.id]
    );
    await client.query(
      `DELETE FROM solicitudadopcion
        WHERE id_usuario = $1 AND lower(btrim(estado::text)) = 'rechazada'`,
      [req.params.id]
    );
    await client.query(
      `DELETE FROM solicitudapadrinamiento
        WHERE id_usuario = $1 AND lower(btrim(estado::text)) = 'rechazada'`,
      [req.params.id]
    );
    await client.query(
      `DELETE FROM match
        WHERE id_perfil_usuario IN (
          SELECT id_perfil_usuario FROM personalidadusuario WHERE id_usuario = $1
        )`,
      [req.params.id]
    );
    await client.query('DELETE FROM notificacion_match_usuario WHERE id_usuario = $1', [req.params.id]).catch(() => {});
    await client.query('DELETE FROM respuestausuario WHERE id_usuario = $1', [req.params.id]);
    await client.query('DELETE FROM valoracion_usuario WHERE id_usuario = $1', [req.params.id]);
    await client.query('DELETE FROM personalidadusuario WHERE id_usuario = $1', [req.params.id]);
    const borrado = await client.query(
      `DELETE FROM usuario
        WHERE id_usuario = $1 AND lower(btrim(rol::text)) = 'usuario'
        RETURNING id_usuario`,
      [req.params.id]
    );
    if (borrado.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    await client.query('COMMIT');
    res.json({ ok: true });
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    if (error.code === '22P02') return res.status(404).json({ error: 'Usuario no encontrado' });
    if (error.code === '23503') {
      return res.status(409).json({
        error: 'No puedes eliminar tu cuenta porque todavía tiene información asociada a una adopción o un apadrinamiento.',
      });
    }
    console.error(error);
    res.status(500).json({ error: 'No se pudo eliminar la cuenta' });
  } finally {
    client.release();
  }
});

module.exports = router;
