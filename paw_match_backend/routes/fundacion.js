const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { randomUUID } = require('crypto');
const pool = require('../db');

const router = express.Router();

const uploadDirectory = path.join(__dirname, '..', 'uploads', 'fundacion');
fs.mkdirSync(uploadDirectory, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: uploadDirectory,
    filename: (_req, file, callback) => {
      callback(null, `${randomUUID()}${path.extname(file.originalname).toLowerCase()}`);
    },
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
});

// Columnas de texto que se editan desde el apartado del administrador.
// `redes_sociales` va aparte porque se guarda como JSON.
const campos = [
  'nombre', 'descripcion', 'mision', 'vision', 'direccion', 'ciudad',
  'telefono', 'correo', 'logo', 'imagen_principal', 'imagen_fondo',
  'rescatista_nombre', 'rescatista_texto', 'rescatista_foto',
  'mapa_url', 'ayuda_adopta_titulo', 'ayuda_adopta_texto',
  'ayuda_apadrina_titulo', 'ayuda_apadrina_texto', 'contacto_texto',
];

// Eliminada la URL de YouTube a petición del usuario.
const redesPermitidas = ['facebook', 'instagram', 'tiktok'];

// Valores iniciales por defecto.
const valoresIniciales = {
  nombre: 'Fundación Maritza Arévalo',
  descripcion:
    'La Fundación Maritza Arévalo ha asumido un papel importante frente al abandono y '
    + 'maltrato de perros en San Juan de Pasto. Rescata perros en condiciones de '
    + 'vulnerabilidad, les brinda atención, recuperación y un espacio seguro mientras '
    + 'se gestiona su proceso de adopción o apadrinamiento.',
  mision:
    'Rescatar perros en condiciones de vulnerabilidad, brindarles atención, '
    + 'recuperación y un espacio seguro mientras encuentran un hogar responsable '
    + 'a través de la adopción o el apadrinamiento.',
  vision: 'Aquí va la visión oficial de la Fundación (texto pendiente).',
  direccion: 'Pasto, Nariño',
  ciudad: 'San Juan de Pasto, Nariño',
  telefono: '573136177747',
  correo: null,
  logo: 'assets/images/logo.png',
  imagen_principal: 'assets/fundacion/Maritzanimada.jpg',
  imagen_fondo: null,
  rescatista_nombre: 'Maritza Arévalo',
  rescatista_texto:
    'Maritza Arévalo acompaña la labor de la Fundación en San Juan de Pasto: '
    + 'rescatar perros en condiciones de vulnerabilidad, brindarles atención y '
    + 'ayudarlos a encontrar un hogar responsable.',
  rescatista_foto: 'assets/fundacion/maitza.jpeg',
  mapa_url: null,
  ayuda_adopta_titulo: 'Adopta',
  ayuda_adopta_texto: 'Encuentra un compañero que encaje contigo y dale un hogar lleno de cariño.',
  ayuda_apadrina_titulo: 'Apadrina',
  ayuda_apadrina_texto: 'Contribuye a su cuidado mientras esperan encontrar una familia permanente.',
  contacto_texto: 'Para coordinar una donación, contáctanos por WhatsApp.',
  redes_sociales: JSON.stringify({
    facebook: 'https://www.facebook.com/maritzaarevalogatos',
    instagram: 'https://www.instagram.com/fundacion_maritza_arevalo/',
  }),
};

// Agrega las columnas nuevas (si faltan) y crea la fila de la fundación la
// primera vez. Se ejecuta una sola vez al arrancar el servidor.
const listo = (async () => {
  await pool.query(`
    ALTER TABLE informacionfundacion
      ADD COLUMN IF NOT EXISTS ciudad VARCHAR(150),
      ADD COLUMN IF NOT EXISTS imagen_principal VARCHAR(255),
      ADD COLUMN IF NOT EXISTS imagen_fondo VARCHAR(255),
      ADD COLUMN IF NOT EXISTS rescatista_nombre VARCHAR(150),
      ADD COLUMN IF NOT EXISTS rescatista_texto TEXT,
      ADD COLUMN IF NOT EXISTS rescatista_foto VARCHAR(255),
      ADD COLUMN IF NOT EXISTS mapa_url TEXT,
      ADD COLUMN IF NOT EXISTS ayuda_adopta_titulo VARCHAR(100),
      ADD COLUMN IF NOT EXISTS ayuda_adopta_texto TEXT,
      ADD COLUMN IF NOT EXISTS ayuda_apadrina_titulo VARCHAR(100),
      ADD COLUMN IF NOT EXISTS ayuda_apadrina_texto TEXT,
      ADD COLUMN IF NOT EXISTS contacto_texto TEXT
  `);
  // Varias redes en JSON no caben en 255 caracteres.
  await pool.query('ALTER TABLE informacionfundacion ALTER COLUMN redes_sociales TYPE TEXT');

  // Limpiar imagen_fondo si apunta a un asset inexistente
  await pool.query("UPDATE informacionfundacion SET imagen_fondo = NULL WHERE imagen_fondo = 'assets/fundacion/bebe.jpg'");

  const existe = await pool.query('SELECT 1 FROM informacionfundacion LIMIT 1');
  if (existe.rows.length === 0) {
    const columnas = [...campos, 'redes_sociales'];
    await pool.query(
      `INSERT INTO informacionfundacion (id_fundacion, ${columnas.join(', ')})
       VALUES (gen_random_uuid(), ${columnas.map((_, i) => `$${i + 1}`).join(', ')})`,
      columnas.map((c) => valoresIniciales[c]),
    );
  }
})().catch((error) => {
  console.error('No se pudo preparar la tabla informacionfundacion:', error.message);
  throw error;
});
listo.catch(() => {});

function leerRedes(texto) {
  if (!texto) return {};
  try {
    const data = JSON.parse(texto);
    if (!data || typeof data !== 'object' || Array.isArray(data)) return {};
    delete data.youtube; // Eliminar youtube si existía previamente
    return data;
  } catch (_) {
    return {};
  }
}

function aRespuesta(fila) {
  return { ...fila, redes_sociales: leerRedes(fila.redes_sociales) };
}

async function requireAdmin(req, res, next) {
  const userId = req.header('x-usuario-id');
  if (!userId) return res.status(401).json({ error: 'Debes iniciar sesión' });
  try {
    const result = await pool.query(
      "SELECT id_usuario FROM usuario WHERE id_usuario = $1 AND LOWER(rol) IN ('administrador', 'superadmin')",
      [userId],
    );
    if (result.rows.length === 0) {
      return res.status(403).json({ error: 'Solo un administrador puede editar la fundación' });
    }
    next();
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo validar el administrador' });
  }
}

// GET /api/fundacion — información pública que muestra la página de bienvenida
router.get('/', async (_req, res) => {
  try {
    await listo;
    const r = await pool.query('SELECT * FROM informacionfundacion LIMIT 1');
    res.set('Cache-Control', 'no-store');
    if (r.rows.length === 0) return res.status(404).json({ error: 'Sin información de la fundación' });
    res.json(aRespuesta(r.rows[0]));
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo cargar la información de la fundación' });
  }
});

// PUT /api/fundacion — el administrador guarda los cambios.
// Un campo vacío se guarda como NULL (así se "elimina" de la bienvenida).
router.put('/', requireAdmin, async (req, res) => {
  const body = req.body || {};
  const nombre = typeof body.nombre === 'string' ? body.nombre.trim() : '';
  if (!nombre) return res.status(400).json({ error: 'El nombre de la fundación es obligatorio' });

  for (const c of campos) {
    const v = body[c];
    if (typeof v === 'string' && v.trim().length > 500) {
      return res.status(400).json({ error: `El texto del campo "${c}" no puede superar los 500 caracteres` });
    }
  }

  const valores = campos.map((c) => {
    const v = body[c];
    if (v === undefined || v === null) return null;
    const texto = String(v).trim();
    return texto.length === 0 ? null : texto;
  });

  const telefono = valores[campos.indexOf('telefono')];
  if (telefono && !/^\d{7,15}$/.test(telefono)) {
    return res.status(400).json({ error: 'El teléfono debe tener solo números (7 a 15 dígitos, con indicativo del país)' });
  }

  const redes = {};
  const redesBody = body.redes_sociales && typeof body.redes_sociales === 'object' ? body.redes_sociales : {};
  for (const red of redesPermitidas) {
    const url = typeof redesBody[red] === 'string' ? redesBody[red].trim() : '';
    if (!url) continue;
    if (!/^https?:\/\//i.test(url)) {
      return res.status(400).json({ error: `El enlace de ${red} debe empezar con http:// o https://` });
    }
    redes[red] = url;
  }

  try {
    await listo;
    const sets = campos.map((c, i) => `${c} = $${i + 1}`).join(', ');
    const r = await pool.query(
      `UPDATE informacionfundacion SET ${sets}, redes_sociales = $${campos.length + 1}
       WHERE id_fundacion = (SELECT id_fundacion FROM informacionfundacion LIMIT 1)
       RETURNING *`,
      [...valores, JSON.stringify(redes)],
    );
    if (r.rows.length === 0) return res.status(404).json({ error: 'Sin información de la fundación' });
    res.json(aRespuesta(r.rows[0]));
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo guardar la información de la fundación' });
  }
});

// POST /api/fundacion/imagen — sube una foto y devuelve su ruta
router.post('/imagen', requireAdmin, upload.single('foto'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No se recibió la imagen' });
  res.status(201).json({ ruta: `/uploads/fundacion/${req.file.filename}` });
});

module.exports = router;
