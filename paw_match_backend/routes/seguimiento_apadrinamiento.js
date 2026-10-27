const express = require('express');
const router = express.Router();
const pool = require('../db');
const { esAdministrador } = require('../utils/roles');
const { 
  enviarCorreoAlertaIncumplimientoApadrinamiento,
  enviarCorreoDecisionApadrinamiento 
} = require('../utils/correo');

/**
 * Autentica usuario desde header x-usuario-id o query param.
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
 * Función auxiliar para calcular ciclo actual, seguimientos en ciclo,
 * evaluación pendiente y promedio del ciclo actual.
 */
function calcularEstadoCiclos(seguimientos, evaluaciones) {
  const total = seguimientos.length;
  if (total === 0) {
    return {
      cicloActual: 1,
      seguimientosEnCiclo: 0,
      evaluacionPendiente: false,
      promedioCicloActual: 0.0,
      totalSeguimientos: 0,
    };
  }

  // Encontrar el ciclo más alto registrado en seguimientos
  let maxCiclo = 1;
  for (const s of seguimientos) {
    const c = s.ciclo || Math.ceil((s.numero_seguimiento || 1) / 3);
    if (c > maxCiclo) maxCiclo = c;
  }

  const seguimientosEnMax = seguimientos.filter(
    s => (s.ciclo || Math.ceil((s.numero_seguimiento || 1) / 3)) === maxCiclo
  );

  const califsEnMax = seguimientosEnMax.map(s => parseInt(s.calificacion, 10)).filter(n => !isNaN(n));
  const promedioMax = califsEnMax.length > 0
    ? califsEnMax.reduce((a, b) => a + b, 0) / califsEnMax.length
    : 0.0;

  const evaluacionMax = evaluaciones.find(e => parseInt(e.ciclo, 10) === maxCiclo);
  const estaEvaluado = !!evaluacionMax;

  if (seguimientosEnMax.length >= 3 && estaEvaluado) {
    // El ciclo se cerró formalmente: pasa al siguiente ciclo en 0/3
    return {
      cicloActual: maxCiclo + 1,
      seguimientosEnCiclo: 0,
      evaluacionPendiente: false,
      promedioCicloActual: 0.0,
      totalSeguimientos: total,
    };
  } else if (seguimientosEnMax.length >= 3 && !estaEvaluado) {
    // El ciclo completó 3/3 pero aún no se ha evaluado: evaluación pendiente
    return {
      cicloActual: maxCiclo,
      seguimientosEnCiclo: 3,
      evaluacionPendiente: true,
      promedioCicloActual: Math.round(promedioMax * 100) / 100,
      totalSeguimientos: total,
    };
  } else {
    // Ciclo en progreso (1/3 o 2/3)
    return {
      cicloActual: maxCiclo,
      seguimientosEnCiclo: seguimientosEnMax.length,
      evaluacionPendiente: false,
      promedioCicloActual: Math.round(promedioMax * 100) / 100,
      totalSeguimientos: total,
    };
  }
}

/**
 * GET /api/seguimiento-apadrinamiento/activos
 * Lista todos los apadrinamientos activos con información de la mascota, padrino,
 * aportes comprometidos, ciclo actual, evaluaciones previas y estado de incumplimientos.
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
        COALESCE(sa.aporta_monetario, false) AS aporta_monetario,
        sa.monto_comprometido,
        sa.periodicidad,
        COALESCE(sa.aporta_especie, false) AS aporta_especie,
        COALESCE(sa.aporta_otro, false) AS aporta_otro,
        sa.detalle_otro,
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
        sa.decision_admin,
        sa.nota_decision,
        sa.id_admin_decision,
        sa.fecha_decision,
        sa.motivo_cancelacion,
        sa.fecha_cancelacion,
        admin_dec.nombres AS admin_decision_nombres,
        admin_dec.apellidos AS admin_decision_apellidos,
        inc.tiene_tres_incumplimientos,
        inc.ultimo_correo_enviado,
        ev.evaluaciones_ciclos,
        seg_list.seguimientos_resumen
      FROM solicitudapadrinamiento sa
      JOIN mascota m ON sa.id_mascota = m.id_mascota
      JOIN usuario u ON sa.id_usuario = u.id_usuario
      LEFT JOIN usuario admin_dec ON sa.id_admin_decision = admin_dec.id_usuario
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
      LEFT JOIN LATERAL (
        SELECT COALESCE(
          json_agg(
            json_build_object(
              'id_evaluacion', ec.id_evaluacion,
              'ciclo', ec.ciclo,
              'promedio', ec.promedio,
              'puntuacion', ec.puntuacion,
              'decision', ec.decision,
              'nota', ec.nota,
              'fecha_decision', ec.fecha_decision,
              'visto_por_usuario', ec.visto_por_usuario,
              'admin_nombres', u_adm.nombres,
              'admin_apellidos', u_adm.apellidos
            ) ORDER BY ec.ciclo ASC
          ),
          '[]'::json
        ) AS evaluaciones_ciclos
        FROM evaluacion_ciclo ec
        LEFT JOIN usuario u_adm ON ec.id_administrador = u_adm.id_usuario
        WHERE ec.id_solicitud_apadrinamiento = sa.id_solicitud_apadrinamiento
      ) ev ON true
      LEFT JOIN LATERAL (
        SELECT COALESCE(
          json_agg(
            json_build_object(
              'id_seguimiento_apadrinacion', s.id_seguimiento_apadrinacion,
              'numero_seguimiento', s.numero_seguimiento,
              'ciclo', s.ciclo,
              'calificacion', s.calificacion,
              'cumplimiento', s.cumplimiento,
              'fecha_seguimiento', s.fecha_seguimiento
            ) ORDER BY s.numero_seguimiento ASC
          ),
          '[]'::json
        ) AS seguimientos_resumen
        FROM seguimientoapadrinamiento s
        WHERE s.id_solicitud_apadrinamiento = sa.id_solicitud_apadrinamiento
      ) seg_list ON true
      WHERE sa.estado = 'aprobada'
        AND sa.contrato_apadrinamiento_archivo IS NOT NULL
        AND COALESCE(sa.estado_apadrinamiento, 'activa') = 'activa'
      ORDER BY m.nombre ASC
    `;

    const resultado = await pool.query(query);

    // Enriquecer cada fila con el cálculo exacto de ciclo y evaluación pendiente
    const filas = resultado.rows.map(row => {
      const seguimientos = Array.isArray(row.seguimientos_resumen) ? row.seguimientos_resumen : [];
      const evaluaciones = Array.isArray(row.evaluaciones_ciclos) ? row.evaluaciones_ciclos : [];
      const stats = calcularEstadoCiclos(seguimientos, evaluaciones);

      return {
        ...row,
        ciclo_actual: stats.cicloActual,
        seguimientos_en_ciclo: stats.seguimientosEnCiclo,
        evaluacion_pendiente: stats.evaluacionPendiente,
        promedio_ciclo_actual: stats.promedioCicloActual,
        total_seguimientos: stats.totalSeguimientos,
      };
    });

    res.json(filas);
  } catch (error) {
    console.error('Error al listar apadrinamientos activos para seguimiento:', error);
    res.status(500).json({ error: 'Error interno del servidor al consultar apadrinamientos activos' });
  }
});

/**
 * GET /api/seguimiento-apadrinamiento/historial/:idSolicitud
 * Consulta el historial de seguimientos, aportes revisados y evaluaciones por ciclo.
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
        s.numero_seguimiento,
        s.ciclo,
        s.created_at,
        u.nombres AS admin_nombres,
        u.apellidos AS admin_apellidos,
        COALESCE(
          json_agg(
            json_build_object(
              'id_aporte', a.id_aporte,
              'tipo', a.tipo,
              'comprometido', a.comprometido,
              'recibido', a.recibido,
              'medio', a.medio,
              'monto_recibido', a.monto_recibido,
              'referencia', a.referencia,
              'detalle_recibido', a.detalle_recibido,
              'observacion', a.observacion
            )
          ) FILTER (WHERE a.id_aporte IS NOT NULL),
          '[]'::json
        ) AS aportes
      FROM seguimientoapadrinamiento s
      LEFT JOIN usuario u ON s.id_administrador = u.id_usuario
      LEFT JOIN seguimiento_aporte a ON a.id_seguimiento_apadrinacion = s.id_seguimiento_apadrinacion
      WHERE s.id_solicitud_apadrinamiento = $1
      GROUP BY s.id_seguimiento_apadrinacion, u.nombres, u.apellidos
      ORDER BY s.numero_seguimiento DESC, s.fecha_seguimiento DESC
    `;

    const resultado = await pool.query(query, [idSolicitud]);

    // Consultar evaluaciones de ciclos para esta solicitud
    const evQuery = `
      SELECT 
        ec.id_evaluacion,
        ec.ciclo,
        ec.promedio,
        ec.puntuacion,
        ec.decision,
        ec.nota,
        ec.fecha_decision,
        ec.visto_por_usuario,
        ec.fecha_vista_usuario,
        u.nombres AS admin_nombres,
        u.apellidos AS admin_apellidos
      FROM evaluacion_ciclo ec
      LEFT JOIN usuario u ON ec.id_administrador = u.id_usuario
      WHERE ec.id_solicitud_apadrinamiento = $1
      ORDER BY ec.ciclo ASC
    `;
    const evRes = await pool.query(evQuery, [idSolicitud]);

    // Consultar datos de la solicitud y aportes comprometidos
    const solQuery = `
      SELECT 
        sa.id_solicitud_apadrinamiento,
        sa.estado,
        sa.estado_apadrinamiento,
        sa.monto_aporte,
        sa.frecuencia_aporte,
        sa.tipo_aporte,
        sa.detalle_especie,
        sa.aporta_monetario,
        sa.monto_comprometido,
        sa.periodicidad,
        sa.aporta_especie,
        sa.aporta_otro,
        sa.detalle_otro,
        m.nombre AS mascota_nombre,
        m.especie AS mascota_especie,
        m.raza AS mascota_raza,
        m.edad AS mascota_edad,
        m.unidad_edad AS mascota_unidad_edad,
        u.nombres AS padrino_nombres,
        u.apellidos AS padrino_apellidos,
        u.correo AS padrino_correo,
        u.telefono AS padrino_telefono
      FROM solicitudapadrinamiento sa
      JOIN mascota m ON sa.id_mascota = m.id_mascota
      JOIN usuario u ON sa.id_usuario = u.id_usuario
      WHERE sa.id_solicitud_apadrinamiento = $1
    `;
    const solRes = await pool.query(solQuery, [idSolicitud]);

    res.json({
      seguimientos: resultado.rows,
      evaluaciones_ciclos: evRes.rows,
      solicitud: solRes.rows[0] || null,
    });
  } catch (error) {
    console.error('Error al consultar historial de seguimiento:', error);
    res.status(500).json({ error: 'Error al obtener el historial de seguimientos' });
  }
});

/**
 * POST /api/seguimiento-apadrinamiento
 * Registrar un nuevo seguimiento de apadrinamiento con aportes revisados y control de ciclo.
 */
router.post('/', requireAdmin, async (req, res) => {
  const admin = req.usuarioActual;
  const {
    id_solicitud_apadrinamiento,
    calificacion,
    cumplimiento,
    observaciones,
    proximo_seguimiento,
    aportes, // Array opcional de aportes revisados [{ tipo, comprometido, recibido, medio, monto_recibido, referencia, detalle_recibido, observacion }]
  } = req.body;

  if (!id_solicitud_apadrinamiento) {
    return res.status(400).json({ error: 'El id de la solicitud de apadrinamiento es obligatorio' });
  }

  const califNum = parseInt(calificacion, 10);
  if (isNaN(califNum) || califNum < 1 || califNum > 5) {
    return res.status(400).json({ error: 'La calificación en estrellas es obligatoria y debe ser entre 1 y 5' });
  }

  // Cumplimiento calculado automáticamente a partir de las estrellas
  const cumpleBool = califNum >= 3;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Verificar solicitud
    const solRes = await client.query(
      `SELECT sa.id_solicitud_apadrinamiento, sa.id_usuario, sa.id_mascota, sa.estado, sa.estado_apadrinamiento,
              u.nombres, u.apellidos, u.correo,
              m.nombre AS mascota_nombre
       FROM solicitudapadrinamiento sa
       JOIN usuario u ON sa.id_usuario = u.id_usuario
       JOIN mascota m ON sa.id_mascota = m.id_mascota
       WHERE sa.id_solicitud_apadrinamiento = $1`,
      [id_solicitud_apadrinamiento]
    );

    if (solRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'La solicitud de apadrinamiento no existe' });
    }

    const solData = solRes.rows[0];

    // 2. Comprobar seguimientos existentes para determinar numero_seguimiento y ciclo
    const prevSegRes = await client.query(
      `SELECT numero_seguimiento, ciclo, calificacion 
       FROM seguimientoapadrinamiento 
       WHERE id_solicitud_apadrinamiento = $1 
       ORDER BY numero_seguimiento ASC`,
      [id_solicitud_apadrinamiento]
    );

    const prevSegs = prevSegRes.rows;
    const evRes = await client.query(
      `SELECT ciclo, decision FROM evaluacion_ciclo WHERE id_solicitud_apadrinamiento = $1`,
      [id_solicitud_apadrinamiento]
    );
    const evs = evRes.rows;

    const stats = calcularEstadoCiclos(prevSegs, evs);

    // REGLA CAMBIO 1: No permitir registrar nuevo seguimiento si el ciclo actual está en 3/3 y no tiene evaluación
    if (stats.evaluacionPendiente) {
      await client.query('ROLLBACK');
      return res.status(400).json({ 
        error: 'Primero debes evaluar al padrino para cerrar el ciclo actual antes de registrar un nuevo seguimiento' 
      });
    }

    const nuevoNumero = prevSegs.length + 1;
    const nuevoCiclo = Math.ceil(nuevoNumero / 3);

    // 3. Insertar nuevo seguimiento
    const insertRes = await client.query(
      `INSERT INTO seguimientoapadrinamiento (
        id_solicitud_apadrinamiento,
        id_administrador,
        fecha_seguimiento,
        cumplimiento,
        observaciones,
        proximo_seguimiento,
        calificacion,
        correo_alerta_enviado,
        numero_seguimiento,
        ciclo,
        created_at
      ) VALUES ($1, $2, CURRENT_DATE, $3, $4, $5, $6, false, $7, $8, NOW())
      RETURNING *`,
      [
        id_solicitud_apadrinamiento,
        admin.id_usuario,
        cumpleBool,
        observaciones ? observaciones.trim() : '',
        proximo_seguimiento || null,
        califNum,
        nuevoNumero,
        nuevoCiclo,
      ]
    );

    const nuevoSeguimiento = insertRes.rows[0];

    // 4. Insertar aportes revisados si fueron proporcionados
    if (Array.isArray(aportes) && aportes.length > 0) {
      for (const ap of aportes) {
        if (!ap.tipo) continue;
        const recibido = ap.recibido === true || ap.recibido === 'true';
        await client.query(
          `INSERT INTO seguimiento_aporte (
            id_seguimiento_apadrinacion,
            tipo,
            comprometido,
            recibido,
            medio,
            monto_recibido,
            referencia,
            detalle_recibido,
            observacion
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [
            nuevoSeguimiento.id_seguimiento_apadrinacion,
            ap.tipo,
            ap.comprometido || null,
            recibido,
            ap.medio || null,
            ap.monto_recibido ? parseFloat(ap.monto_recibido) : null,
            ap.referencia || null,
            ap.detalle_recibido || null,
            ap.observacion || null,
          ]
        );
      }
    }

    // 5. Notificar al usuario marcando leido_usuario = false en la solicitud
    await client.query(
      `UPDATE solicitudapadrinamiento 
       SET leido_usuario = false, 
           fecha_actualizacion_estado = NOW()
       WHERE id_solicitud_apadrinamiento = $1`,
      [id_solicitud_apadrinamiento]
    );

    // 6. Evaluar regla de 3 incumplimientos consecutivos (calificacion <= 2)
    const checkIncumplimiento = await client.query(
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

        await client.query(
          'UPDATE seguimientoapadrinamiento SET correo_alerta_enviado = true WHERE id_seguimiento_apadrinacion = $1',
          [nuevoSeguimiento.id_seguimiento_apadrinacion]
        );
        alertaEnviada = true;
      } catch (mailErr) {
        console.error('Error enviando correo de alerta de incumplimiento:', mailErr);
      }
    }

    await client.query('COMMIT');

    res.status(201).json({
      mensaje: 'Seguimiento registrado exitosamente',
      seguimiento: nuevoSeguimiento,
      tieneTresIncumplimientos: tieneTres,
      correoAlertaEnviado: alertaEnviada || yaEnviado,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error al registrar seguimiento de apadrinamiento:', error);
    res.status(500).json({ error: error.message || 'Error interno al guardar el seguimiento' });
  } finally {
    client.release();
  }
});

/**
 * GET /api/seguimiento-apadrinamiento/calendario
 * Retorna los apadrinamientos con un proximo_seguimiento pendiente.
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
 * Cancelar un apadrinamiento con motivo obligatorio y bloquear opcionalmente al usuario.
 */
router.post('/cancelar', requireAdmin, async (req, res) => {
  const { id_solicitud_apadrinamiento, motivo, bloquear_usuario } = req.body;

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

    // 3. Bloquear usuario para volver a apadrinar si se solicita (por defecto true)
    const bloquear = bloquear_usuario !== false && bloquear_usuario !== 'false';
    if (bloquear) {
      await client.query(
        'UPDATE usuario SET bloqueado_apadrinar = true WHERE id_usuario = $1',
        [sol.id_usuario]
      );
    }

    await client.query('COMMIT');

    res.json({
      mensaje: 'Apadrinamiento cancelado exitosamente',
      id_solicitud_apadrinamiento,
      usuario_bloqueado: bloquear,
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

/**
 * POST /api/seguimiento-apadrinamiento/evaluar
 * Decisión del administrador al evaluar el ciclo (continuar o cancelar).
 * Llama a la función RPC atómica registrar_evaluacion.
 */
router.post('/evaluar', requireAdmin, async (req, res) => {
  const admin = req.usuarioActual;
  const { id_solicitud_apadrinamiento, decision, nota, bloquear_usuario, ciclo } = req.body;

  if (!id_solicitud_apadrinamiento) {
    return res.status(400).json({ error: 'El id de la solicitud de apadrinamiento es obligatorio' });
  }

  if (!['continuar', 'cancelar'].includes(decision)) {
    return res.status(400).json({ error: 'La decisión debe ser "continuar" o "cancelar"' });
  }

  const notaLimpia = (nota || '').trim();

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const solCheck = await client.query(
      `SELECT sa.id_solicitud_apadrinamiento, sa.id_usuario, sa.id_mascota, sa.estado,
              u.correo, u.nombres, u.apellidos, m.nombre AS mascota_nombre,
              COALESCE(vr.calificacion_promedio, 0.0) AS calificacion_promedio
       FROM solicitudapadrinamiento sa
       JOIN usuario u ON sa.id_usuario = u.id_usuario
       JOIN mascota m ON sa.id_mascota = m.id_mascota
       LEFT JOIN vista_resumen_padrinos vr ON vr.id_usuario = u.id_usuario
       WHERE sa.id_solicitud_apadrinamiento = $1`,
      [id_solicitud_apadrinamiento]
    );

    if (solCheck.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'La solicitud de apadrinamiento no existe' });
    }

    const sol = solCheck.rows[0];

    // Determinar ciclo a evaluar si no fue enviado
    let cicloObjetivo = ciclo ? parseInt(ciclo, 10) : null;
    if (!cicloObjetivo) {
      const maxCicloRes = await client.query(
        'SELECT COALESCE(MAX(ciclo), 1) AS max_c FROM seguimientoapadrinamiento WHERE id_solicitud_apadrinamiento = $1',
        [id_solicitud_apadrinamiento]
      );
      cicloObjetivo = maxCicloRes.rows[0]?.max_c || 1;
    }

    // Calcular promedio del ciclo
    const avgRes = await client.query(
      'SELECT COALESCE(ROUND(AVG(calificacion), 2), 0.0) AS prom FROM seguimientoapadrinamiento WHERE id_solicitud_apadrinamiento = $1 AND ciclo = $2',
      [id_solicitud_apadrinamiento, cicloObjetivo]
    );
    const promCiclo = parseFloat(avgRes.rows[0]?.prom || 0.0);
    const esMalPadrino = promCiclo < 3.0;

    // Si se cancela o si es mal padrino, la nota es obligatoria
    if ((decision === 'cancelar' || esMalPadrino) && !notaLimpia) {
      await client.query('ROLLBACK');
      return res.status(400).json({ 
        error: decision === 'cancelar' 
          ? 'El motivo de la cancelación es obligatorio.' 
          : 'Para continuar el apadrinamiento de un padrino con promedio < 3, la nota explicativa es obligatoria.' 
      });
    }

    // Bloqueo de usuario: si la decisión es cancelar, se evalúa bloquear_usuario
    const bloquearBool = decision === 'cancelar' && (bloquear_usuario === true || bloquear_usuario === 'true');

    // Ejecutar la función RPC atómica registrar_evaluacion
    const rpcRes = await client.query(
      'SELECT registrar_evaluacion($1, $2, $3, $4, $5, $6) AS resultado;',
      [id_solicitud_apadrinamiento, admin.id_usuario, decision, notaLimpia || null, bloquearBool, cicloObjetivo]
    );

    const resultado = rpcRes.rows[0]?.resultado;

    await client.query('COMMIT');

    // Enviar notificación por correo
    const adminNombreCompleto = `${admin.nombres || ''} ${admin.apellidos || ''}`.trim() || 'Administrador';
    const padrinoNombreCompleto = `${sol.nombres || ''} ${sol.apellidos || ''}`.trim() || 'Padrino';

    try {
      await enviarCorreoDecisionApadrinamiento({
        destinatario: sol.correo,
        nombrePadrino: padrinoNombreCompleto,
        nombreMascota: sol.mascota_nombre,
        decision,
        nota: notaLimpia,
        adminNombre: adminNombreCompleto,
      });
    } catch (mailErr) {
      console.error('Error enviando correo de decisión de apadrinamiento:', mailErr);
    }

    res.json({
      mensaje: decision === 'continuar'
        ? `Se ha cerrado el Ciclo ${cicloObjetivo} y continuará el apadrinamiento.`
        : `Se ha cancelado el apadrinamiento en el Ciclo ${cicloObjetivo}.`,
      decision,
      ciclo: cicloObjetivo,
      resultado,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error al registrar evaluación de apadrinamiento:', error);
    res.status(500).json({ error: error.message || 'Error interno al registrar la evaluación' });
  } finally {
    client.release();
  }
});

/**
 * PUT /api/seguimiento-apadrinamiento/reporte-visto/:idEvaluacion
 * Marca una evaluación de ciclo como vista por el usuario padrino para apagar el punto de notificación.
 */
router.put('/reporte-visto/:idEvaluacion', async (req, res) => {
  const { idEvaluacion } = req.params;
  const usuario = await autenticarUsuario(req);
  if (!usuario) {
    return res.status(401).json({ error: 'Debes iniciar sesión' });
  }

  try {
    const updateRes = await pool.query(
      `UPDATE evaluacion_ciclo 
       SET visto_por_usuario = true, 
           fecha_vista_usuario = NOW() 
       WHERE id_evaluacion = $1 
       RETURNING *`,
      [idEvaluacion]
    );

    if (updateRes.rows.length === 0) {
      return res.status(404).json({ error: 'Evaluación no encontrada' });
    }

    res.json({ ok: true, evaluacion: updateRes.rows[0] });
  } catch (error) {
    console.error('Error marcando reporte como visto:', error);
    res.status(500).json({ error: 'Error al actualizar estado del reporte' });
  }
});

module.exports = router;
