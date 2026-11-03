const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { randomUUID } = require('crypto');
const pool = require('../db');
const { esAdministrador } = require('../utils/roles');

const router = express.Router();
const uploadDirectory = path.join(__dirname, '..', 'uploads', 'noticias');
fs.mkdirSync(uploadDirectory, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: uploadDirectory,
    filename: (_req, file, callback) => {
      callback(null, `${randomUUID()}${path.extname(file.originalname).toLowerCase()}`);
    },
  }),
});

async function requireAdmin(req, res, next) {
  const userId = req.header('x-usuario-id');
  if (!userId) return res.status(401).json({ error: 'Debes iniciar sesión' });
  try {
    const result = await pool.query(
      'SELECT rol FROM usuario WHERE id_usuario = $1',
      [userId],
    );
    if (result.rows.length === 0 || !esAdministrador(result.rows[0].rol)) {
      return res.status(403).json({ error: 'Solo un administrador puede realizar esta acción' });
    }
    req.adminId = userId;
    next();
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'No se pudo validar el administrador' });
  }
}

// Consulta base con conteo de likes y validación de like del usuario actual
function selectNoticiaQuery(userId) {
  return `
    SELECT n.id_noticia,
           n.titulo,
           n.contenido,
           n.imagen,
           n.lugar,
           to_char(n.fecha, 'YYYY-MM-DD') AS fecha,
           to_char(n.fecha_creacion, 'YYYY-MM-DD"T"HH24:MI:SS') AS fecha_creacion,
           n.id_administrador,
           COALESCE((SELECT COUNT(*)::int FROM noticia_like nl WHERE nl.id_noticia = n.id_noticia), 0) AS total_likes,
           ${
             userId
               ? 'EXISTS(SELECT 1 FROM noticia_like nl WHERE nl.id_noticia = n.id_noticia AND nl.id_usuario = $1) AS dio_like'
               : 'false AS dio_like'
           }
    FROM noticia n
  `;
}

// Listar todas las noticias
router.get('/', async (req, res) => {
  const userId = req.header('x-usuario-id') || null;
  try {
    const query = `${selectNoticiaQuery(userId)} ORDER BY n.fecha DESC, n.fecha_creacion DESC`;
    const params = userId ? [userId] : [];
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando noticias:', error);
    res.status(500).json({ error: 'No se pudieron cargar las noticias' });
  }
});

// Obtener una noticia por ID
router.get('/:id', async (req, res) => {
  const userId = req.header('x-usuario-id') || null;
  try {
    const baseQuery = selectNoticiaQuery(userId);
    const query = `${baseQuery} WHERE n.id_noticia = ${userId ? '$2' : '$1'}`;
    const params = userId ? [userId, req.params.id] : [req.params.id];
    const result = await pool.query(query, params);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Noticia no encontrada' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error obteniendo noticia:', error);
    res.status(500).json({ error: 'No se pudo cargar la noticia' });
  }
});

// Subir foto para la noticia (solo admin)
router.post('/foto', requireAdmin, upload.single('foto'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No se recibió ninguna imagen' });
  res.status(201).json({ ruta: `/uploads/noticias/${path.basename(req.file.path)}` });
});

// Crear noticia (solo admin)
router.post('/', requireAdmin, async (req, res) => {
  const { titulo, contenido, imagen, fecha, lugar } = req.body;
  if (!titulo || !titulo.trim()) {
    return res.status(400).json({ error: 'El título es obligatorio' });
  }
  if (!contenido || !contenido.trim()) {
    return res.status(400).json({ error: 'El contenido es obligatorio' });
  }

  const idNoticia = randomUUID();
  try {
    await pool.query(
      `INSERT INTO noticia (id_noticia, titulo, contenido, imagen, fecha, lugar, id_administrador)
       VALUES ($1, $2, $3, $4, COALESCE($5::date, CURRENT_DATE), $6, $7)`,
      [
        idNoticia,
        titulo.trim(),
        contenido.trim(),
        imagen || null,
        fecha || null,
        lugar ? lugar.trim() : 'Fundación Maritza Arévalo',
        req.adminId,
      ],
    );

    const result = await pool.query(
      `${selectNoticiaQuery(req.adminId)} WHERE n.id_noticia = $2`,
      [req.adminId, idNoticia],
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creando noticia:', error);
    res.status(500).json({ error: 'No se pudo publicar la noticia' });
  }
});

// Modificar noticia (solo admin)
router.put('/:id', requireAdmin, async (req, res) => {
  const { titulo, contenido, imagen, fecha, lugar } = req.body;
  if (!titulo || !titulo.trim()) {
    return res.status(400).json({ error: 'El título es obligatorio' });
  }
  if (!contenido || !contenido.trim()) {
    return res.status(400).json({ error: 'El contenido es obligatorio' });
  }

  try {
    const updateResult = await pool.query(
      `UPDATE noticia
       SET titulo = $1,
           contenido = $2,
           imagen = $3,
           fecha = COALESCE($4::date, fecha),
           lugar = COALESCE($5, lugar)
       WHERE id_noticia = $6
       RETURNING id_noticia`,
      [
        titulo.trim(),
        contenido.trim(),
        imagen || null,
        fecha || null,
        lugar !== undefined ? (lugar ? lugar.trim() : '') : null,
        req.params.id,
      ],
    );

    if (updateResult.rows.length === 0) {
      return res.status(404).json({ error: 'Noticia no encontrada' });
    }

    const result = await pool.query(
      `${selectNoticiaQuery(req.adminId)} WHERE n.id_noticia = $2`,
      [req.adminId, req.params.id],
    );
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error actualizando noticia:', error);
    res.status(500).json({ error: 'No se pudo actualizar la noticia' });
  }
});

// Eliminar noticia (solo admin)
router.delete('/:id', requireAdmin, async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM noticia WHERE id_noticia = $1 RETURNING id_noticia',
      [req.params.id],
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Noticia no encontrada' });
    }
    res.json({ mensaje: 'Noticia eliminada exitosamente' });
  } catch (error) {
    console.error('Error eliminando noticia:', error);
    res.status(500).json({ error: 'No se pudo eliminar la noticia' });
  }
});

// Alternar "Me gusta" (usuarios y administradores autenticados)
router.post('/:id/like', async (req, res) => {
  const userId = req.header('x-usuario-id');
  if (!userId) {
    return res.status(401).json({ error: 'Debes iniciar sesión para dar Me gusta' });
  }

  try {
    const existe = await pool.query(
      'SELECT 1 FROM noticia_like WHERE id_noticia = $1 AND id_usuario = $2',
      [req.params.id, userId],
    );

    let dioLike = false;
    if (existe.rows.length > 0) {
      await pool.query(
        'DELETE FROM noticia_like WHERE id_noticia = $1 AND id_usuario = $2',
        [req.params.id, userId],
      );
      dioLike = false;
    } else {
      await pool.query(
        'INSERT INTO noticia_like (id_noticia, id_usuario) VALUES ($1, $2)',
        [req.params.id, userId],
      );
      dioLike = true;
    }

    const countResult = await pool.query(
      'SELECT COUNT(*)::int AS total_likes FROM noticia_like WHERE id_noticia = $1',
      [req.params.id],
    );
    const totalLikes = countResult.rows[0].total_likes;

    res.json({ dio_like: dioLike, total_likes: totalLikes });
  } catch (error) {
    console.error('Error en me gusta de noticia:', error);
    res.status(500).json({ error: 'No se pudo registrar tu reacción' });
  }
});

module.exports = router;
