const express = require('express');
const bcrypt = require('bcrypt');
const pool = require('../db');
const { esAdministrador, esSuperAdmin } = require('../utils/roles');

const router = express.Router();

// Columnas que se devuelven (nunca contrasena_hash ni tokens)
const COLUMNAS =
  'id_usuario, nombres, apellidos, correo, telefono, documento_identidad, foto_perfil, rol, estado_cuenta, fecha_registro';

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
    if (!esAdministrador(r.rows[0].rol) || r.rows[0].estado_cuenta !== 'activo') {
      return res.status(403).json({ error: 'Solo el administrador puede hacer esto' });
    }
    req.idAdmin = idUsuario;
    req.rolAdmin = r.rows[0].rol;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Usuario no válido' });
  }
}

router.use(soloAdmin);

function soloSuperAdmin(req, res, next) {
  if (!esSuperAdmin(req.rolAdmin)) {
    return res.status(403).json({ error: 'Solo el superadministrador puede hacer esto' });
  }
  next();
}

function leerAdministrador(body) {
  const limpiar = (v) => (typeof v === 'string' ? v.trim() : '');
  return {
    nombres: limpiar(body.nombres),
    apellidos: limpiar(body.apellidos),
    correo: limpiar(body.correo),
    telefono: limpiar(body.telefono) || null,
    contrasena: typeof body.contrasena === 'string' ? body.contrasena : '',
  };
}

function validarAdministrador(datos, { contrasenaObligatoria }) {
  if (!datos.nombres || !datos.apellidos || !datos.correo) {
    return 'Faltan campos obligatorios';
  }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(datos.correo)) {
    return 'El correo no es válido';
  }
  if (contrasenaObligatoria && !datos.contrasena) {
    return 'Faltan campos obligatorios';
  }
  if (datos.contrasena && datos.contrasena.length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres';
  }
  return null;
}

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
    filtro = `AND (u.nombres ILIKE $2 OR u.apellidos ILIKE $2 OR u.correo ILIKE $2)`;
  }

  const columnas = COLUMNAS.split(',')
    .map((columna) => `u.${columna.trim()}`)
    .join(', ');

  try {
    const r = await pool.query(
      `SELECT ${columnas},
              v.comentarios AS motivo_inactivacion,
              v.fecha_valoracion AS fecha_inactivacion,
              NULLIF(TRIM(CONCAT(admin.nombres, ' ', COALESCE(admin.apellidos, ''))), '')
                AS administrador_inactivacion
       FROM Usuario u
       LEFT JOIN LATERAL (
         SELECT comentarios, fecha_valoracion, id_administrador
         FROM valoracion_usuario
         WHERE id_usuario = u.id_usuario
         ORDER BY fecha_valoracion DESC
         LIMIT 1
       ) v ON TRUE
       LEFT JOIN Usuario admin ON admin.id_usuario = v.id_administrador
       WHERE u.rol = $1 ${filtro}
       ORDER BY u.fecha_registro DESC`,
      params
    );
    res.json(r.rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Error al consultar los usuarios' });
  }
});

// ---------------------------------------------------------------
// GET /api/admin/usuarios/roles
// Solo los id de quienes ya tienen solicitud aceptada y contrato subido.
// No trae el formulario completo: eso congelaba la app al filtrar.
// ---------------------------------------------------------------
router.get('/roles', async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT DISTINCT id_usuario::text AS id_usuario, 'adoptante' AS tipo
       FROM solicitudadopcion
       WHERE estado = 'aprobada'
         AND COALESCE(btrim(contrato_adopcion_archivo), '') <> ''
       UNION
       SELECT DISTINCT id_usuario::text, 'apadrinante'
       FROM solicitudapadrinamiento
       WHERE estado = 'aprobada'
         AND COALESCE(btrim(contrato_apadrinamiento_archivo), '') <> ''`
    );
    const adoptantes = [];
    const apadrinantes = [];
    for (const fila of r.rows) {
      if (fila.tipo === 'adoptante') adoptantes.push(fila.id_usuario);
      else apadrinantes.push(fila.id_usuario);
    }
    res.json({ adoptantes, apadrinantes });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Error al consultar los roles' });
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

  const motivo =
    typeof req.body.comentarios === 'string' ? req.body.comentarios.trim() : '';
  if (estado_cuenta === 'inactivo' && !motivo) {
    return res.status(400).json({ error: 'Explica por qué inactivas la cuenta' });
  }

  const client = await pool.connect();
  let transaccion = false;
  try {
    const actual = await client.query('SELECT rol FROM Usuario WHERE id_usuario = $1', [
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

    await client.query('BEGIN');
    transaccion = true;
    const r = await client.query(
      `UPDATE Usuario SET estado_cuenta = $1 WHERE id_usuario = $2
       RETURNING ${COLUMNAS}`,
      [estado_cuenta, req.params.id]
    );
    let fechaInactivacion = null;
    let administrador = null;
    if (estado_cuenta === 'inactivo') {
      const insertada = await client.query(
        `INSERT INTO valoracion_usuario (id_usuario, id_administrador, comentarios)
         VALUES ($1, $2, $3)
         RETURNING fecha_valoracion`,
        [req.params.id, req.idAdmin, motivo]
      );
      const admin = await client.query(
        `SELECT NULLIF(TRIM(CONCAT(nombres, ' ', COALESCE(apellidos, ''))), '') AS nombre
         FROM Usuario WHERE id_usuario = $1`,
        [req.idAdmin]
      );
      fechaInactivacion = insertada.rows[0].fecha_valoracion;
      administrador = admin.rows[0]?.nombre ?? null;
    }
    await client.query('COMMIT');

    const usuario = r.rows[0];
    usuario.motivo_inactivacion = estado_cuenta === 'inactivo' ? motivo : null;
    usuario.fecha_inactivacion = fechaInactivacion;
    usuario.administrador_inactivacion = administrador;
    res.json(usuario);
  } catch (e) {
    if (transaccion) await client.query('ROLLBACK');
    if (e.code === '22P02') return res.status(404).json({ error: 'Usuario no encontrado' });
    console.error(e);
    res.status(500).json({ error: 'Error al actualizar el usuario' });
  } finally {
    client.release();
  }
});

// ---------------------------------------------------------------
// POST /api/admin/usuarios/administradores
// Crea una cuenta con rol administrador. Es la ÚNICA forma de crear
// administradores (el registro público siempre crea usuarios normales).
// ---------------------------------------------------------------
router.post('/administradores', soloSuperAdmin, async (req, res) => {
  const datos = leerAdministrador(req.body);
  const error = validarAdministrador(datos, { contrasenaObligatoria: true });
  if (error) return res.status(400).json({ error });

  try {
    const existe = await pool.query(
      'SELECT 1 FROM Usuario WHERE LOWER(correo) = LOWER($1)',
      [datos.correo]
    );
    if (existe.rows.length > 0) {
      return res.status(409).json({ error: 'Ese correo ya está registrado' });
    }

    const hash = await bcrypt.hash(datos.contrasena, 10);
    const r = await pool.query(
      `INSERT INTO Usuario (nombres, apellidos, correo, telefono, contrasena_hash, rol)
       VALUES ($1, $2, $3, $4, $5, 'administrador')
       RETURNING ${COLUMNAS}`,
      [datos.nombres, datos.apellidos, datos.correo, datos.telefono, hash]
    );
    res.status(201).json(r.rows[0]);
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: 'Ese correo ya está registrado' });
    console.error(e);
    res.status(500).json({ error: 'Error al crear el administrador' });
  }
});

// ---------------------------------------------------------------
// PUT /api/admin/usuarios/administradores/:id
// Edita nombre, correo, teléfono y, si se envía, la contraseña.
// ---------------------------------------------------------------
router.put('/administradores/:id', soloSuperAdmin, async (req, res) => {
  const datos = leerAdministrador(req.body);
  const error = validarAdministrador(datos, { contrasenaObligatoria: false });
  if (error) return res.status(400).json({ error });

  try {
    const actual = await pool.query(
      `SELECT rol FROM Usuario WHERE id_usuario = $1`,
      [req.params.id]
    );
    if (actual.rows.length === 0 || actual.rows[0].rol !== 'administrador') {
      return res.status(404).json({ error: 'Administrador no encontrado' });
    }

    const correo = await pool.query(
      `SELECT 1 FROM Usuario
       WHERE LOWER(correo) = LOWER($1) AND id_usuario <> $2`,
      [datos.correo, req.params.id]
    );
    if (correo.rows.length > 0) {
      return res.status(409).json({ error: 'Ese correo ya está registrado' });
    }

    const valores = [datos.nombres, datos.apellidos, datos.correo, datos.telefono, req.params.id];
    let contrasenaSql = '';
    if (datos.contrasena) {
      valores.push(await bcrypt.hash(datos.contrasena, 10));
      contrasenaSql = `, contrasena_hash = $${valores.length}`;
    }

    const r = await pool.query(
      `UPDATE Usuario
       SET nombres = $1, apellidos = $2, correo = $3, telefono = $4${contrasenaSql}
       WHERE id_usuario = $5 AND rol = 'administrador'
       RETURNING ${COLUMNAS}`,
      valores
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Administrador no encontrado' });
    }
    res.json(r.rows[0]);
  } catch (e) {
    if (e.code === '22P02') return res.status(404).json({ error: 'Administrador no encontrado' });
    if (e.code === '23505') return res.status(409).json({ error: 'Ese correo ya está registrado' });
    console.error(e);
    res.status(500).json({ error: 'Error al actualizar el administrador' });
  }
});

// ---------------------------------------------------------------
// DELETE /api/admin/usuarios/administradores/:id
// ---------------------------------------------------------------
router.delete('/administradores/:id', soloSuperAdmin, async (req, res) => {
  if (req.params.id === req.idAdmin) {
    return res.status(403).json({ error: 'No puedes eliminar tu propia cuenta' });
  }

  try {
    const r = await pool.query(
      `DELETE FROM Usuario
       WHERE id_usuario = $1 AND rol = 'administrador'
       RETURNING id_usuario`,
      [req.params.id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Administrador no encontrado' });
    }
    res.json({ ok: true });
  } catch (e) {
    if (e.code === '22P02') return res.status(404).json({ error: 'Administrador no encontrado' });
    if (e.code === '23503') {
      return res.status(409).json({
        error: 'No se puede eliminar porque este administrador tiene registros asociados',
      });
    }
    console.error(e);
    res.status(500).json({ error: 'Error al eliminar el administrador' });
  }
});

module.exports = router;
