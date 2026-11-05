const VOZ_DEFECTO = 'marin';

/** Voces de la API de audio de OpenAI. marin y cedar piden gpt-4o-mini-tts. */
const VOCES = [
  { id: 'marin', nombre: 'Marin', detalle: 'Cálida y clara' },
  { id: 'coral', nombre: 'Coral', detalle: 'Amable y cercana' },
  { id: 'nova', nombre: 'Nova', detalle: 'Brillante' },
  { id: 'shimmer', nombre: 'Shimmer', detalle: 'Suave' },
  { id: 'sage', nombre: 'Sage', detalle: 'Serena' },
  { id: 'alloy', nombre: 'Alloy', detalle: 'Neutra' },
  { id: 'echo', nombre: 'Echo', detalle: 'Nítida' },
  { id: 'ash', nombre: 'Ash', detalle: 'Serena y baja' },
  { id: 'ballad', nombre: 'Ballad', detalle: 'Expresiva' },
  { id: 'fable', nombre: 'Fable', detalle: 'Narrativa' },
  { id: 'onyx', nombre: 'Onyx', detalle: 'Grave' },
  { id: 'verse', nombre: 'Verse', detalle: 'Versátil' },
  { id: 'cedar', nombre: 'Cedar', detalle: 'Firme' },
];

const IDS = new Set(VOCES.map((v) => v.id));
const TEXTO_MUESTRA =
  'Hola, soy el asistente de Paw Match. Así se escucha esta voz.';

function vozValida(valor) {
  return IDS.has(String(valor || '').trim().toLowerCase());
}

function normalizarVoz(valor) {
  const voz = String(valor || '').trim().toLowerCase();
  return vozValida(voz) ? voz : VOZ_DEFECTO;
}

async function asegurarVozAsistente(pool) {
  await pool.query(
    `ALTER TABLE usuario
       ADD COLUMN IF NOT EXISTS voz_asistente varchar(20) DEFAULT 'marin'`,
  );
}

function apiKey() {
  const key = process.env.OPENAI_API_KEY;
  if (!key || !String(key).trim()) return null;
  return String(key).trim();
}

/**
 * Llama a la API de texto a voz de OpenAI con la voz elegida por el usuario.
 * Devuelve el mp3 en un Buffer.
 */
async function sintetizar({ texto, voz, velocidad = 1 }) {
  const key = apiKey();
  if (!key) {
    const error = new Error('Falta OPENAI_API_KEY');
    error.estado = 503;
    throw error;
  }

  const entrada = String(texto || '').trim().slice(0, 4000);
  if (!entrada) {
    const error = new Error('Texto vacío');
    error.estado = 400;
    throw error;
  }

  const rapidez = Math.min(4, Math.max(0.25, Number(velocidad) || 1));
  const modelo = process.env.OPENAI_TTS_MODEL || 'gpt-4o-mini-tts';
  const cuerpo = {
    model: modelo,
    voice: normalizarVoz(voz),
    input: entrada,
    speed: rapidez,
    response_format: 'mp3',
  };
  if (modelo.includes('gpt-4o')) {
    cuerpo.instructions =
      'Habla en español latinoamericano, con un tono claro y cálido. No traduzcas los nombres.';
  }

  const resp = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(cuerpo),
    signal: AbortSignal.timeout(45000),
  });

  if (!resp.ok) {
    const error = new Error('OpenAI TTS');
    error.estado = resp.status;
    error.detalle = await resp.text();
    throw error;
  }

  return Buffer.from(await resp.arrayBuffer());
}

module.exports = {
  VOCES,
  VOZ_DEFECTO,
  TEXTO_MUESTRA,
  vozValida,
  normalizarVoz,
  asegurarVozAsistente,
  sintetizar,
};
