export const MODELO = 'gpt-6-luna';

export async function completar(env, messages) {
  const modelo = env.OPENAI_CHAT_MODEL || MODELO;
  const intentos = [
    { temperature: 0, response_format: { type: 'json_object' } },
    { response_format: { type: 'json_object' } },
    {},
  ];
  let ultimo = null;
  for (const extra of intentos) {
    let respuesta;
    try {
      respuesta = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.OPENAI_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ model: modelo, messages, ...extra }),
        signal: AbortSignal.timeout(40000),
      });
    } catch (error) {
      if (error?.name === 'TimeoutError' || error?.name === 'AbortError') {
        return { ok: false, status: 504, texto: '' };
      }
      throw error;
    }
    if (respuesta.ok) return { ok: true, respuesta };
    const texto = await respuesta.text();
    ultimo = { status: respuesta.status, texto };
    const recuperable = respuesta.status === 400
      && /temperature|response_format|json_object|unsupported|unknown parameter/i.test(texto);
    if (!recuperable) break;
  }
  return { ok: false, status: ultimo?.status || 502, texto: ultimo?.texto || '' };
}

export function errorOpenAI(fallo, contexto) {
  let detalle = '';
  try {
    detalle = JSON.parse(fallo.texto || '{}')?.error?.message || '';
  } catch {
    detalle = String(fallo.texto || '').slice(0, 300);
  }
  console.error('OpenAI HTTP', fallo.status || '');
  if (fallo.status === 401) {
    return { status: 502, body: { error: 'La clave del asistente fue rechazada. Revisa OPENAI_API_KEY en el servidor.' } };
  }
  if (fallo.status === 404 || /model/i.test(detalle)) {
    return { status: 502, body: { error: 'El modelo gpt-6-luna no está disponible en esta cuenta de OpenAI.' } };
  }
  if (fallo.status === 504) {
    return { status: 504, body: { error: 'El asistente tardó demasiado. Inténtalo de nuevo.' } };
  }
  if (fallo.status === 429) {
    return { status: 503, body: { error: 'El asistente está ocupado. Espera un momento e inténtalo de nuevo.' } };
  }
  if (contexto === 'luna') {
    return { status: 502, body: { error: 'No se pudo guardar o procesar la respuesta en este momento. Por favor reintenta.' } };
  }
  return { status: 502, body: { error: 'No se pudo contactar al asistente. Revisa tu conexión.' } };
}
