import { cors, json } from './http.js';
import { despachar } from './rutas.js';

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return cors(request, env, new Response(null, { status: 204 }));
    const url = new URL(request.url);
    try {
      if (url.pathname === '/' ) return new Response('API Paw Match funcionando');
      const respuesta = await despachar(request, env, url);
      return cors(request, env, respuesta);
    } catch (error) {
      if (error?.status >= 400 && error?.status < 500) {
        return cors(request, env, json({ error: error.message }, error.status));
      }
      console.error(error);
      const mensaje = String(error?.message || '').includes('SESION_SECRETO')
        ? 'La sesión no está configurada'
        : 'Error interno';
      return cors(request, env, json({ error: mensaje }, 500));
    }
  },
};
