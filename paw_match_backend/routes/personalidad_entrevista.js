const express = require('express');
const multer = require('multer');
const pool = require('../db');
const {
  MODELO,
  preguntaPorClave,
  preguntaConcordada,
  preguntasPublicas,
  contextoSeguro,
  construirMensajes,
  extraerJson,
  textoDeMensaje,
  validarInterpretacion,
  asegurarTablas,
  guardarBorrador,
  listarBorradores,
  eliminarBorrador,
} = require('../utils/entrevista_personalidad');

const router = express.Router();
const MODELO_TRANSCRIPCION = process.env.OPENAI_TRANSCRIBE_MODEL || 'whisper-1';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 },
});

function sesionPropia(req) {
  const sesion = req.header('x-usuario-id');
  return Boolean(sesion && sesion === req.params.id);
}

function apiKey() {
  let key = process.env.OPENAI_API_KEY;
  if (!key || !String(key).trim()) {
    const path = require('path');
    require('dotenv').config({
      path: path.join(__dirname, '..', '.env'),
      override: true,
    });
    key = process.env.OPENAI_API_KEY;
  }
  if (!key || !String(key).trim()) return null;
  return String(key).trim();
}

function recibirAudio(req, res, next) {
  upload.single('audio')(req, res, (error) => {
    if (!error) return next();
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        error: 'El audio es demasiado largo. Responde en menos de un minuto o escribe.',
      });
    }
    return res.status(400).json({
      error: 'No pude leer el audio. Prueba de nuevo o escribe tu respuesta.',
    });
  });
}

function archivoAudio(buffer, nombre, tipo) {
  try {
    const { File } = require('node:buffer');
    if (typeof File === 'function') {
      return new File([buffer], nombre, { type: tipo });
    }
  } catch (_) {
    // Node 18 acepta Blob con nombre en FormData.
  }
  return new Blob([buffer], { type: tipo });
}

async function completar(messages) {
  const intentos = [
    { temperature: 0, response_format: { type: 'json_object' } },
    { response_format: { type: 'json_object' } },
    {},
  ];
  let ultimo = null;

  for (const extra of intentos) {
    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ model: MODELO, messages, ...extra }),
      signal: AbortSignal.timeout(40000),
    });
    if (resp.ok) return resp;

    const texto = await resp.text();
    ultimo = { status: resp.status, texto };
    const recuperable = resp.status === 400
      && /temperature|response_format|json_object|unsupported|unknown parameter/i.test(texto);
    if (!recuperable) break;
  }

  const error = new Error('OpenAI');
  error.estado = ultimo?.status || 502;
  error.detalle = ultimo?.texto || '';
  throw error;
}

function responderFalloModelo(res, error) {
  if (error.name === 'TimeoutError' || error.name === 'AbortError') {
    return res.status(504).json({
      error: 'El asistente tardó demasiado. Inténtalo de nuevo.',
    });
  }

  let detalle = '';
  try {
    detalle = JSON.parse(error.detalle || '{}')?.error?.message || '';
  } catch (_) {
    detalle = String(error.detalle || '').slice(0, 300);
  }
  console.error('OpenAI HTTP', error.estado || '', detalle.slice(0, 300));

  if (error.estado === 401) {
    return res.status(502).json({
      error: 'La clave del asistente fue rechazada. Revisa OPENAI_API_KEY en el servidor.',
    });
  }
  if (error.estado === 404 || /model/i.test(detalle)) {
    return res.status(502).json({
      error: 'El modelo gpt-6-luna no está disponible en esta cuenta de OpenAI.',
    });
  }
  if (error.estado === 429) {
    return res.status(503).json({
      error: 'El asistente está ocupado. Espera un momento e inténtalo de nuevo.',
    });
  }
  return res.status(502).json({
    error: 'No se pudo contactar al asistente. Revisa tu conexión.',
  });
}

async function generoDeUsuario(id) {
  const resultado = await pool.query(
    'SELECT genero FROM usuario WHERE id_usuario = $1',
    [id],
  );
  return resultado.rows[0]?.genero || '';
}

router.get('/personalidad/preguntas', async (req, res) => {
  const id = req.header('x-usuario-id');
  if (!id) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }
  try {
    const genero = await generoDeUsuario(id);
    res.json({ preguntas: preguntasPublicas(genero) });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: 'No se pudieron cargar las preguntas' });
  }
});

router.get('/:id/personalidad/entrevista', async (req, res) => {
  if (!sesionPropia(req)) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }
  try {
    const borradores = await listarBorradores(pool, req.params.id);
    res.json({
      respuestas: borradores.map((fila) => ({
        pregunta_id: fila.clave,
        respuesta_original: fila.texto,
        puntuacion: fila.puntuacion,
        justificacion: fila.justificacion,
        actualizado: fila.actualizado,
      })),
    });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: 'No se pudo recuperar el progreso de la entrevista' });
  }
});

router.delete('/:id/personalidad/entrevista/:clave', async (req, res) => {
  if (!sesionPropia(req)) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }
  if (!preguntaPorClave(req.params.clave)) {
    return res.status(400).json({ error: 'Pregunta desconocida' });
  }
  try {
    await eliminarBorrador(pool, req.params.id, req.params.clave);
    res.json({ eliminado: true });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: 'No se pudo corregir esa respuesta' });
  }
});

router.post('/:id/personalidad/interpretar', async (req, res) => {
  if (!sesionPropia(req)) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }
  if (!apiKey()) {
    return res.status(503).json({
      error: 'El asistente no está configurado. Falta OPENAI_API_KEY en el servidor.',
    });
  }

  const clave = String(req.body?.clave || req.body?.pregunta_id || '');
  const pregunta = preguntaPorClave(clave);
  if (!pregunta) {
    return res.status(400).json({ error: 'Pregunta desconocida' });
  }

  const respuesta = String(req.body?.respuesta || '').trim();
  if (respuesta.length < 2) {
    return res.status(400).json({ error: 'Cuéntame un poco más para poder interpretarlo.' });
  }
  if (respuesta.length > 2000) {
    return res.status(400).json({ error: 'La respuesta es demasiado larga. Resúmela un poco.' });
  }

  try {
    const genero = await generoDeUsuario(req.params.id);
    const mensajes = construirMensajes(
      preguntaConcordada(pregunta, genero),
      respuesta,
      contextoSeguro(req.body?.contexto),
    );
    const resp = await completar(mensajes);
    const cuerpo = await resp.json();
    const contenido = textoDeMensaje(cuerpo?.choices?.[0]?.message);
    let crudo;
    try {
      crudo = extraerJson(contenido);
    } catch (_) {
      return res.status(502).json({
        error: 'El asistente no devolvió una interpretación válida. Inténtalo de nuevo.',
      });
    }

    const validacion = validarInterpretacion(crudo, clave, respuesta);
    if (!validacion.ok) {
      return res.status(502).json({ error: validacion.error });
    }

    if (!validacion.datos.necesita_aclaracion) {
      await guardarBorrador(pool, req.params.id, validacion.datos);
    }
    res.json(validacion.datos);
  } catch (error) {
    if (error.code === '23503') {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    if (error.code) {
      console.error(error.message);
      return res.status(500).json({ error: 'No se pudo guardar la interpretación' });
    }
    return responderFalloModelo(res, error);
  }
});

router.post('/:id/personalidad/transcribir', recibirAudio, async (req, res) => {
  if (!sesionPropia(req)) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }
  if (!apiKey()) {
    return res.status(503).json({
      error: 'El asistente no está configurado. Falta OPENAI_API_KEY en el servidor.',
    });
  }
  if (!req.file || !req.file.buffer?.length) {
    return res.status(400).json({ error: 'No recibí el audio. Prueba de nuevo o escribe.' });
  }

  const nombre = /\.m4a$|\.mp4$|\.aac$/i.test(req.file.originalname || '')
    ? 'respuesta.m4a'
    : 'respuesta.wav';
  const tipo = req.file.mimetype || 'audio/wav';
  const form = new FormData();
  form.append('file', archivoAudio(req.file.buffer, nombre, tipo), nombre);
  form.append('model', MODELO_TRANSCRIPCION);
  form.append('language', 'es');

  try {
    const resp = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey()}` },
      body: form,
      signal: AbortSignal.timeout(40000),
    });
    if (!resp.ok) {
      const error = new Error('OpenAI');
      error.estado = resp.status;
      error.detalle = await resp.text();
      return responderFalloModelo(res, error);
    }
    const cuerpo = await resp.json();
    const texto = String(cuerpo?.text || '').trim();
    if (!texto) {
      return res.status(422).json({
        error: 'No se entendió el audio. Intenta otra vez o escribe tu respuesta.',
      });
    }
    res.json({ texto });
  } catch (error) {
    responderFalloModelo(res, error);
  }
});

asegurarTablas().catch((error) => {
  console.error('No se pudo preparar la entrevista de personalidad:', error.message);
});

module.exports = router;
