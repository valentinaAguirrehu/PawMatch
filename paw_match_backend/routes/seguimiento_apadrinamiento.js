const express = require('express');
const router = express.Router();
const pool = require('../db');
const { esAdministrador } = require('../utils/roles');
const { enviarCorreoAlertaIncumplimientoApadrinamiento } = require('../utils/correo');

/**
 * Autentica usuario desde header x-usuario-id.
 */
async function autenticarUsuario(req) {
  const userId = req.header('x-usuario-id') || req.query.usuario_id;
  if (!userId) return null;

  try {
    const res = await pool.query(
      'SELECT id_usuario, rol, estado_cuenta, nombres, apellidos, correo, bloqueado_apadrinar FROM usuario WHERE id_usuario = $1',
      [userId]
    );
    if (res.rows.length === 0) return null;
    const u = res.rows[0];
    if (u.estado_cuenta !== 'activo') return null;
    return u;
  } catch (err) {
    console.error('Error autenticando usuario:', err);
    return null;
  }
}

/**
 * Middleware para requerir rol administrador o superadmin.
 */
async function requireAdmin(req, res, next) {
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión con una cuenta activa' });
  }
  if (!esAdministrador(usuario.rol)) {
    return res.status(403).json({ error: 'Acceso restringido solo para administradores' });
  }
  req.usuarioActual = usuario;
  next();
}

/**
 * GET /api/seguimiento-apadrinamiento/activos
 * Lista todos los apadrinamientos activos con información de la mascota, padrino,
 * calificación promedio, último seguimiento, próximo seguimiento y estado de incumplimientos.
 */
router.get('/activos', requireAdmin, async (_req, res) => {
  try {
    const query = `
      SELECT 
        sa.id_solicitud_apadrinamiento,
        sa.estado,
        COALESCE(sa.estado_apadrinamiento, 'activa') AS estado_apadrinamiento,
        sa.monto_aporte,
        sa.frecuencia_aporte,
        sa.tipo_aporte,
        sa.detalle_especie,
        sa.fecha_inicio_apadrinamiento,
        sa.fecha_solicitud,
        sa.contrato_apadrinamiento_archivo,
        m.id_mascota,
        m.nombre AS mascota_nombre,
        m.fotos AS mascota_fotos,
        m.especie AS mascota_especie,
        m.raza AS mascota_raza,
        m.edad AS mascota_edad,
        m.unidad_edad AS mascota_unidad_edad,
        u.id_usuario,
        u.nombres AS usuario_nombres,
        u.apellidos AS usuario_apellidos,
        u.correo AS usuario_correo,
        u.telefono AS usuario_telefono,
        u.foto_perfil AS usuario_foto,
        COALESCE(u.bloqueado_apadrinar, false) AS usuario_bloqueado,
        COALESCE(vr.calificacion_promedio, 0.0) AS calificacion_promedio,
        COALESCE(vr.total_seguimientos, 0) AS total_seguimientos,
        ult.fecha_seguimiento AS ultimo_seguimiento_fecha,
        ult.calificacion AS ultimo_seguimiento_calificacion,
        ult.cumplimiento AS ultimo_seguimiento_cumplimiento,
        ult.observaciones AS ultimo_seguimiento_observaciones,
        ult.proximo_seguimiento AS proximo_seguimiento_fecha,
        inc.tiene_tres_incumplimientos,
        inc.ultimo_correo_enviado
      FROM solicitudapadrinamiento sa
      JOIN mascota m ON sa.id_mascota = m.id_mascota
      JOIN usuario u ON sa.id_usuario = u.id_usuario
      LEFT JOIN vista_resumen_padrinos vr ON vr.id_usuario = u.id_usuario
      LEFT JOIN LATERAL (
        SELECT 
          s.fecha_seguimiento,
          s.calificacion,
          s.cumplimiento,
          s.observaciones,
          s.proximo_seguimiento
        FROM seguimientoapadrinamiento s
        WHERE s.id_solicitud_apadrinamiento = sa.id_solicitud_apadrinamiento
        ORDER BY s.fecha_seguimiento DESC, s.created_at DESC
        LIMIT 1
      ) ult ON true
      LEFT JOIN LATERAL (
        SELECT 
          COALESCE(tiene_tres_incumplimientos, false) AS tiene_tres_incumplimientos,
          COALESCE(ultimo_correo_enviado, false) AS ultimo_correo_enviado
        FROM fn_verificar_tres_incumplimientos(sa.id_solicitud_apadrinamiento)
      ) inc ON true
      WHERE sa.estado = 'aprobada'
        AND sa.contrato_apadrinamiento_archivo IS NOT NULL
        AND COALESCE(sa.estado_apadrinamiento, 'activa') = 'activa'
      ORDER BY m.nombre ASC
    `;

    const resultado = await pool.query(query);
    res.json(resultado.rows);
  } catch (error) {
    console.error('Error al listar apadrinamientos activos para seguimiento:', error);
    res.status(500).json({ error: 'Error interno del servidor al consultar apadrinamientos activos' });
  }
});

/**
 * GET /api/seguimiento-apadrinamiento/historial/:idSolicitud
 * Consulta el historial cronológico de seguimientos de una solicitud de apadrinamiento.
 */
router.get('/historial/:idSolicitud', async (req, res) => {
  const { idSolicitud } = req.params;
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión para consultar el historial' });
  }

  try {
    // Si no es admin, verificar que sea el padrino dueño de la solicitud
    if (!esAdministrador(usuario.rol)) {
      const duenoCheck = await pool.query(
        'SELECT id_usuario FROM solicitudapadrinamiento WHERE id_solicitud_apadrinamiento = $1',
        [idSolicitud]
      );
      if (duenoCheck.rows.length === 0 || duenoCheck.rows[0].id_usuario !== usuario.id_usuario) {
        return res.status(403).json({ error: 'No tienes autorización para ver este historial' });
      }
    }

    const query = `
      SELECT 
        s.id_seguimiento_apadrinacion,
        s.id_solicitud_apadrinamiento,
        s.id_administrador,
        s.fecha_seguimiento,
        s.cumplimiento,
        s.observaciones,
        s.proximo_seguimiento,
        s.calificacion,
        s.correo_alerta_enviado,
        s.created_at,
        u.nombres AS admin_nombres,
        u.apellidos AS admin_apellidos
      FROM seguimientoapadrinamiento s
      LEFT JOIN usuario u ON s.id_administrador = u.id_usuario
      WHERE s.id_solicitud_apadrinamiento = $1
      ORDER BY s.fecha_seguimiento DESC, s.created_at DESC
    `;

    const resultado = await pool.query(query, [idSolicitud]);
    res.json(resultado.rows);
  } catch (error) {
    console.error('Error al consultar historial de seguimiento:', error);
    res.status(500).json({ error: 'Error al obtener el historial de seguimientos' });
  }
});

/**
 * POST /api/seguimiento-apadrinamiento
 * Registrar un nuevo seguimiento de apadrinamiento por parte del administrador.
 */
router.post('/', requireAdmin, async (req, res) => {
  const admin = req.usuarioActual;
  const {
    id_solicitud_apadrinamiento,
    calificacion,
    cumplimiento,
    observaciones,
    proximo_seguimiento,
  } = req.body;

  if (!id_solicitud_apadrinamiento) {
    return res.status(400).json({ error: 'El id de la solicitud de apadrinamiento es obligatorio' });
  }

  const califNum = parseInt(calificacion, 10);
  if (isNaN(califNum) || califNum < 1 || califNum > 5) {
    return res.status(400).json({ error: 'La calificación en estrellas es obligatoria y debe ser entre 1 y 5' });
  }

  // Cumplimiento calculado automáticamente a partir de las estrellas:
  // calificacion >= 3 -> cumplimiento = true
  // calificacion <= 2 -> cumplimiento = false
  const cumpleBool = califNum >= 3;

  try {
    // 1. Verificar solicitud
    const solRes = await pool.query(
      `SELECT sa.id_solicitud_apadrinamiento, sa.id_usuario, sa.id_mascota,
              u.nombres, u.apellidos, u.correo,
              m.nombre AS mascota_nombre
       FROM solicitudapadrinamiento sa
       JOIN usuario u ON sa.id_usuario = u.id_usuario
       JOIN mascota m ON sa.id_mascota = m.id_mascota
       WHERE sa.id_solicitud_apadrinamiento = $1`,
      [id_solicitud_apadrinamiento]
    );

    if (solRes.rows.length === 0) {
      return res.status(404).json({ error: 'La solicitud de apadrinamiento no existe' });
    }

    const solData = solRes.rows[0];

    // 2. Insertar nuevo seguimiento
    const insertRes = await pool.query(
      `INSERT INTO seguimientoapadrinamiento (
        id_solicitud_apadrinamiento,
        id_administrador,
        fecha_seguimiento,
        cumplimiento,
        observaciones,
        proximo_seguimiento,
        calificacion,
        correo_alerta_enviado,
        created_at
      ) VALUES ($1, $2, CURRENT_DATE, $3, $4, $5, $6, false, NOW())
      RETURNING *`,
      [
        id_solicitud_apadrinamiento,
        admin.id_usuario,
        cumpleBool,
        observaciones ? observaciones.trim() : '',
        proximo_seguimiento || null,
        califNum,
      ]
    );

    const nuevoSeguimiento = insertRes.rows[0];

    // 3. Notificar al usuario marcando leido_usuario = false en la solicitud
    await pool.query(
      'UPDATE solicitudapadrinamiento SET leido_usuario = false, fecha_actualizacion_estado = NOW() WHERE id_solicitud_apadrinamiento = $1',
      [id_solicitud_apadrinamiento]
    );

    // 4. Evaluar regla de 3 incumplimientos consecutivos (calificacion <= 2)
    const checkIncumplimiento = await pool.query(
      'SELECT tiene_tres_incumplimientos, ultimo_correo_enviado FROM fn_verificar_tres_incumplimientos($1)',
      [id_solicitud_apadrinamiento]
    );

    let alertaEnviada = false;
    const tieneTres = checkIncumplimiento.rows[0]?.tiene_tres_incumplimientos === true;
    const yaEnviado = checkIncumplimiento.rows[0]?.ultimo_correo_enviado === true;

    if (tieneTres && !yaEnviado) {
      const nombreCompleto = `${solData.nombres || ''} ${solData.apellidos || ''}`.trim() || 'Padrino';
      try {
        await enviarCorreoAlertaIncumplimientoApadrinamiento({
          destinatario: solData.correo,
          nombrePadrino: nombreCompleto,
          nombreMascota: solData.mascota_nombre,
          consecutivos: 3,
        });

        await pool.query(
          'UPDATE seguimientoapadrinamiento SET correo_alerta_enviado = true WHERE id_seguimiento_apadrinacion = $1',
          [nuevoSeguimiento.id_seguimiento_apadrinacion]
        );
        alertaEnviada = true;
      } catch (mailErr) {
        console.error('Error enviando correo de alerta de incumplimiento:', mailErr);
      }
    }

    res.status(201).json({
      mensaje: 'Seguimiento registrado exitosamente',
      seguimiento: nuevoSeguimiento,
      tieneTresIncumplimientos: tieneTres,
      correoAlertaEnviado: alertaEnviada || yaEnviado,
    });
  } catch (error) {
    console.error('Error al registrar seguimiento de apadrinamiento:', error);
    res.status(500).json({ error: 'Error interno al guardar el seguimiento' });
  }
});

/**
 * GET /api/seguimiento-apadrinamiento/calendario
 * Retorna solo los apadrinamientos cuyo seguimiento MÁS RECIENTE tiene un proximo_seguimiento pendiente.
 * No incluye apadrinamientos cancelados o finalizados, ni fechas viejas de seguimientos ya reemplazados.
 */
router.get('/calendario', requireAdmin, async (_req, res) => {
  try {
    const query = `
      WITH UltimoSeguimiento AS (
        SELECT DISTINCT ON (s.id_solicitud_apadrinamiento)
          s.id_seguimiento_apadrinacion,
          s.id_solicitud_apadrinamiento,
          s.fecha_seguimiento,
          s.proximo_seguimiento,
          s.cumplimiento,
          s.calificacion,
          s.observaciones
        FROM seguimientoapadrinamiento s
        ORDER BY s.id_solicitud_apadrinamiento, s.fecha_seguimiento DESC, s.created_at DESC
      )
      SELECT 
        u_seg.id_seguimiento_apadrinacion,
        u_seg.fecha_seguimiento AS fecha_ultimo_seguimiento,
        u_seg.proximo_seguimiento,
        u_seg.cumplimiento AS ultimo_cumplimiento,
        u_seg.calificacion AS ultima_calificacion,
        u_seg.observaciones AS ultimas_observaciones,
        (u_seg.proximo_seguimiento < CURRENT_DATE) AS es_vencido,
        sa.id_solicitud_apadrinamiento,
        sa.monto_aporte,
        sa.frecuencia_aporte,
        sa.tipo_aporte,
        m.id_mascota,
        m.nombre AS mascota_nombre,
        m.fotos AS mascota_fotos,
        m.especie AS mascota_especie,
        m.raza AS mascota_raza,
        m.edad AS mascota_edad,
        m.unidad_edad AS mascota_unidad_edad,
        u.id_usuario,
        u.nombres AS usuario_nombres,
        u.apellidos AS usuario_apellidos,
        u.correo AS usuario_correo,
        u.telefono AS usuario_telefono,
        COALESCE(vr.calificacion_promedio, 0.0) AS calificacion_promedio,
        inc.tiene_tres_incumplimientos
      FROM UltimoSeguimiento u_seg
      JOIN solicitudapadrinamiento sa ON u_seg.id_solicitud_apadrinamiento = sa.id_solicitud_apadrinamiento
      JOIN mascota m ON sa.id_mascota = m.id_mascota
      JOIN usuario u ON sa.id_usuario = u.id_usuario
      LEFT JOIN vista_resumen_padrinos vr ON vr.id_usuario = u.id_usuario
      LEFT JOIN LATERAL (
        SELECT COALESCE(tiene_tres_incumplimientos, false) AS tiene_tres_incumplimientos
        FROM fn_verificar_tres_incumplimientos(sa.id_solicitud_apadrinamiento)
      ) inc ON true
      WHERE sa.estado = 'aprobada'
        AND COALESCE(sa.estado_apadrinamiento, 'activa') = 'activa'
        AND u_seg.proximo_seguimiento IS NOT NULL
      ORDER BY u_seg.proximo_seguimiento ASC, m.nombre ASC
    `;

    const resultado = await pool.query(query);
    res.json(resultado.rows);
  } catch (error) {
    console.error('Error al consultar calendario de seguimientos:', error);
    res.status(500).json({ error: 'Error al consultar calendario de próximos seguimientos' });
  }
});

/**
 * POST /api/seguimiento-apadrinamiento/cancelar
 * Cancelar un apadrinamiento con motivo obligatorio y bloquear al usuario para futuros apadrinamientos.
 */
router.post('/cancelar', requireAdmin, async (req, res) => {
  const { id_solicitud_apadrinamiento, motivo } = req.body;

  if (!id_solicitud_apadrinamiento) {
    return res.status(400).json({ error: 'El id de la solicitud de apadrinamiento es obligatorio' });
  }

  const motivoLimpio = (motivo || '').trim();
  if (!motivoLimpio) {
    return res.status(400).json({ error: 'El motivo de la cancelación es obligatorio' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Obtener la solicitud
    const solCheck = await client.query(
      `SELECT sa.id_solicitud_apadrinamiento, sa.id_usuario, sa.id_mascota, sa.estado,
              u.correo, u.nombres, u.apellidos, m.nombre AS mascota_nombre
       FROM solicitudapadrinamiento sa
       JOIN usuario u ON sa.id_usuario = u.id_usuario
       JOIN mascota m ON sa.id_mascota = m.id_mascota
       WHERE sa.id_solicitud_apadrinamiento = $1`,
      [id_solicitud_apadrinamiento]
    );

    if (solCheck.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'La solicitud de apadrinamiento no existe' });
    }

    const sol = solCheck.rows[0];

    // 2. Actualizar estado_apadrinamiento y solicitud
    await client.query(
      `UPDATE solicitudapadrinamiento
       SET estado = 'cancelada',
           estado_apadrinamiento = 'cancelada',
           motivo_cancelacion = $1,
           fecha_cancelacion = NOW(),
           observaciones = $1,
           leido_usuario = false,
           fecha_actualizacion_estado = NOW()
       WHERE id_solicitud_apadrinamiento = $2`,
      [motivoLimpio, id_solicitud_apadrinamiento]
    );

    // 3. Bloquear usuario para volver a apadrinar
    await client.query(
      'UPDATE usuario SET bloqueado_apadrinar = true WHERE id_usuario = $1',
      [sol.id_usuario]
    );

    await client.query('COMMIT');

    res.json({
      mensaje: 'Apadrinamiento cancelado exitosamente y usuario inhabilitado para apadrinar',
      id_solicitud_apadrinamiento,
      usuario_bloqueado: true,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error al cancelar apadrinamiento por incumplimiento:', error);
    res.status(500).json({ error: 'Error al cancelar el apadrinamiento' });
  } finally {
    client.release();
  }
});

/**
 * GET /api/seguimiento-apadrinamiento/padrino/:idUsuario/resumen
 * Retorna las estadísticas del padrino (promedio estrellas, alertas, estado bloqueado).
 */
router.get('/padrino/:idUsuario/resumen', async (req, res) => {
  const { idUsuario } = req.params;
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }

  try {
    const resumenRes = await pool.query(
      `SELECT 
        u.id_usuario,
        u.nombres,
        u.apellidos,
        COALESCE(u.bloqueado_apadrinar, false) AS bloqueado_apadrinar,
        COALESCE(vr.calificacion_promedio, 0.0) AS calificacion_promedio,
        COALESCE(vr.total_seguimientos, 0) AS total_seguimientos
       FROM usuario u
       LEFT JOIN vista_resumen_padrinos vr ON vr.id_usuario = u.id_usuario
       WHERE u.id_usuario = $1`,
      [idUsuario]
    );

    if (resumenRes.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    const fila = resumenRes.rows[0];

    // Verificar si alguna de sus solicitudes activas tiene alerta de incumplimiento
    const alertaRes = await pool.query(
      `SELECT 
        sa.id_solicitud_apadrinamiento,
        m.nombre AS mascota_nombre,
        inc.tiene_tres_incumplimientos,
        inc.ultimo_correo_enviado
       FROM solicitudapadrinamiento sa
       JOIN mascota m ON sa.id_mascota = m.id_mascota
       LEFT JOIN LATERAL (
         SELECT 
           COALESCE(tiene_tres_incumplimientos, false) AS tiene_tres_incumplimientos,
           COALESCE(ultimo_correo_enviado, false) AS ultimo_correo_enviado
         FROM fn_verificar_tres_incumplimientos(sa.id_solicitud_apadrinamiento)
       ) inc ON true
       WHERE sa.id_usuario = $1
         AND sa.estado = 'aprobada'
         AND COALESCE(sa.estado_apadrinamiento, 'activa') = 'activa'`,
      [idUsuario]
    );

    const solicitudesConAlerta = alertaRes.rows.filter(
      r => r.tiene_tres_incumplimientos || r.ultimo_correo_enviado
    );

    res.json({
      id_usuario: fila.id_usuario,
      nombres: fila.nombres,
      apellidos: fila.apellidos,
      bloqueado_apadrinar: fila.bloqueado_apadrinar,
      calificacion_promedio: parseFloat(fila.calificacion_promedio) || 0.0,
      total_seguimientos: parseInt(fila.total_seguimientos, 10) || 0,
      tiene_alerta: solicitudesConAlerta.length > 0,
      solicitudes_con_alerta: solicitudesConAlerta,
    });
  } catch (error) {
    console.error('Error al obtener resumen de padrino:', error);
    res.status(500).json({ error: 'Error al consultar resumen del padrino' });
  }
});

module.exports = router;
