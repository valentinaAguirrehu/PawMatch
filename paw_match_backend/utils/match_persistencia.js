const { randomUUID } = require('crypto');
const pool = require('../db');
const { personalityColumns } = require('./entrevista_personalidad');

/**
 * Umbral de compatibilidad alta para notificar nuevas coincidencias (75%).
 */
const UMBRAL_NUEVA_COINCIDENCIA = 75.0;

let esquemaMatchListo = null;

/**
 * Prepara las columnas y tablas necesarias para:
 * 1. Etiqueta NUEVO durante 48 horas reales (`mascota.fecha_creacion`).
 * 2. Persistencia del primer Match del usuario (`personalidadusuario.id_mascota_match_inicial`).
 * 3. Registro de notificaciones de nuevas coincidencias compatibles (`notificacion_match_usuario`).
 */
function asegurarEsquemaMatch() {
  if (!esquemaMatchListo) {
    esquemaMatchListo = (async () => {
      // 1. Fecha real de creación en mascota (inmutable al editar la mascota)
      await pool.query(`
        ALTER TABLE mascota
          ADD COLUMN IF NOT EXISTS fecha_creacion TIMESTAMPTZ;
      `);
      // Inicializar mascotas antiguas con más de 48h de antigüedad para que no salgan como NUEVO
      await pool.query(`
        UPDATE mascota
        SET fecha_creacion = COALESCE(
          fecha_ingreso::timestamptz - INTERVAL '72 hours',
          CURRENT_TIMESTAMP - INTERVAL '72 hours'
        )
        WHERE fecha_creacion IS NULL;
      `);
      await pool.query(`
        ALTER TABLE mascota
          ALTER COLUMN fecha_creacion SET DEFAULT CURRENT_TIMESTAMP;
      `);

      // 2. Persistencia del Match Inicial en personalidadusuario
      await pool.query(`
        ALTER TABLE personalidadusuario
          ADD COLUMN IF NOT EXISTS id_mascota_match_inicial UUID REFERENCES mascota(id_mascota) ON DELETE SET NULL,
          ADD COLUMN IF NOT EXISTS porcentaje_match_inicial NUMERIC(5,2),
          ADD COLUMN IF NOT EXISTS fecha_match_inicial TIMESTAMPTZ;
      `);

      // 3. Tabla de notificaciones de nuevas mascotas compatibles
      await pool.query(`
        CREATE TABLE IF NOT EXISTS notificacion_match_usuario (
          id_notificacion UUID PRIMARY KEY,
          id_usuario UUID NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
          id_mascota UUID NOT NULL REFERENCES mascota(id_mascota) ON DELETE CASCADE,
          porcentaje_match NUMERIC(5,2) NOT NULL,
          leida BOOLEAN NOT NULL DEFAULT FALSE,
          mostrada_en_mascotas BOOLEAN NOT NULL DEFAULT FALSE,
          fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
          fecha_lectura TIMESTAMPTZ,
          CONSTRAINT notificacion_match_unica UNIQUE (id_usuario, id_mascota)
        );
      `);
    })().catch((err) => {
      esquemaMatchListo = null;
      console.error('Error preparando esquema de Match:', err.message);
      throw err;
    });
  }
  return esquemaMatchListo;
}

/**
 * Calcula el porcentaje real de compatibilidad (0 a 100, con 2 decimales)
 * utilizando exactamente la misma fórmula que `MatchService.calcular` en Flutter.
 */
function calcularPorcentajeCompatibilidad(usuarioRow, mascotaRow) {
  if (!usuarioRow || !mascotaRow) return null;
  let suma = 0;
  let rasgos = 0;

  for (const col of personalityColumns) {
    const valU = Number(usuarioRow[col]);
    const valM = Number(mascotaRow[col]);
    if (!Number.isInteger(valU) || valU < 1 || valU > 5) return null;
    if (!Number.isInteger(valM) || valM < 1 || valM > 5) return null;
    const distancia = Math.min(4, Math.max(0, Math.abs(valU - valM)));
    suma += 1 - (distancia / 4);
    rasgos++;
  }

  if (rasgos === 0) return null;
  const porcentaje = (suma / rasgos) * 100;
  return Math.min(100, Math.max(0, Math.round(porcentaje * 100) / 100));
}

/**
 * Sincroniza el Match inicial del usuario y sus notificaciones de nuevas coincidencias:
 * - Si el usuario aún no tiene `id_mascota_match_inicial`, busca la mascota disponible
 *   con mayor compatibilidad y la guarda permanentemente como su Match inicial.
 * - Si ya tiene `id_mascota_match_inicial`, lo conserva sin reemplazarlo nunca por nuevas mascotas.
 * - Detecta mascotas nuevas (<= 48h) con alta compatibilidad (>= 75%) distintas del Match inicial
 *   y registra la notificación una única vez por mascota y usuario.
 */
async function sincronizarMatchDeUsuario(idUsuario, client = pool) {
  await asegurarEsquemaMatch();

  const resPerfil = await client.query(
    `SELECT id_perfil_usuario, id_usuario, ${personalityColumns.join(', ')},
            id_mascota_match_inicial, porcentaje_match_inicial, fecha_match_inicial
     FROM personalidadusuario
     WHERE id_usuario = $1`,
    [idUsuario],
  );

  if (resPerfil.rows.length === 0) {
    return {
      tiene_personalidad: false,
      id_mascota_match_inicial: null,
      porcentaje_match_inicial: null,
      fecha_match_inicial: null,
      notificaciones: [],
      no_leidas: 0,
    };
  }

  const perfil = resPerfil.rows[0];
  let idMatchInicial = perfil.id_mascota_match_inicial;
  let porcentajeInicial = perfil.porcentaje_match_inicial != null
    ? Number(perfil.porcentaje_match_inicial)
    : null;
  let fechaMatchInicial = perfil.fecha_match_inicial;

  // Consultar mascotas disponibles con personalidad definida
  const resMascotas = await client.query(`
    SELECT m.id_mascota, m.nombre, m.estado_adopcion, m.personalidad_definida, m.fecha_creacion,
           (m.fecha_creacion IS NOT NULL
            AND (CURRENT_TIMESTAMP - m.fecha_creacion) <= INTERVAL '48 hours'
            AND (CURRENT_TIMESTAMP - m.fecha_creacion) >= INTERVAL '-2 hours') AS es_nuevo,
           ${personalityColumns.map((c) => `pm.${c}`).join(', ')}
    FROM mascota m
    INNER JOIN personalidadmascota pm ON pm.id_mascota = m.id_mascota
    WHERE m.personalidad_definida = TRUE
  `);

  // 1. Si aún no tiene Match inicial guardado, asignarle el mejor disponible en este momento
  if (!idMatchInicial) {
    let mejorMascotaId = null;
    let mejorPorcentaje = -1;

    for (const m of resMascotas.rows) {
      if (String(m.estado_adopcion || '').trim().toLowerCase() === 'adoptado') continue;
      const pct = calcularPorcentajeCompatibilidad(perfil, m);
      if (pct == null) continue;
      if (pct > mejorPorcentaje) {
        mejorPorcentaje = pct;
        mejorMascotaId = m.id_mascota;
      }
    }

    if (mejorMascotaId) {
      idMatchInicial = mejorMascotaId;
      porcentajeInicial = mejorPorcentaje;
      const upd = await client.query(
        `UPDATE personalidadusuario
         SET id_mascota_match_inicial = $1,
             porcentaje_match_inicial = $2,
             fecha_match_inicial = CURRENT_TIMESTAMP
         WHERE id_usuario = $3 AND id_mascota_match_inicial IS NULL
         RETURNING id_mascota_match_inicial, porcentaje_match_inicial, fecha_match_inicial`,
        [idMatchInicial, porcentajeInicial, idUsuario],
      );
      if (upd.rows.length > 0) {
        idMatchInicial = upd.rows[0].id_mascota_match_inicial;
        porcentajeInicial = Number(upd.rows[0].porcentaje_match_inicial);
        fechaMatchInicial = upd.rows[0].fecha_match_inicial;
      }
    }
  } else {
    // Si ya tiene Match inicial guardado, recalcular su porcentaje real si estaba en null
    const mascotaInicial = resMascotas.rows.find((m) => m.id_mascota === idMatchInicial);
    if (mascotaInicial) {
      const pctActual = calcularPorcentajeCompatibilidad(perfil, mascotaInicial);
      if (pctActual != null && porcentajeInicial == null) {
        porcentajeInicial = pctActual;
        await client.query(
          `UPDATE personalidadusuario SET porcentaje_match_inicial = $1 WHERE id_usuario = $2`,
          [porcentajeInicial, idUsuario],
        );
      }
    }
  }

  // 2. Detectar nuevas mascotas (es_nuevo = true) con compatibilidad alta (>= 75%)
  //    distintas del Match inicial para registrar notificación sin duplicados.
  if (idMatchInicial) {
    for (const m of resMascotas.rows) {
      if (!m.es_nuevo) continue;
      if (m.id_mascota === idMatchInicial) continue;
      if (String(m.estado_adopcion || '').trim().toLowerCase() === 'adoptado') continue;
      // Si la mascota fue creada después o es nueva, verificamos compatibilidad
      const pct = calcularPorcentajeCompatibilidad(perfil, m);
      if (pct != null && pct >= UMBRAL_NUEVA_COINCIDENCIA) {
        await client.query(
          `INSERT INTO notificacion_match_usuario
            (id_notificacion, id_usuario, id_mascota, porcentaje_match)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (id_usuario, id_mascota) DO NOTHING`,
          [randomUUID(), idUsuario, m.id_mascota, pct],
        );
      }
    }
  }

  // 3. Consultar las notificaciones de nuevas coincidencias de este usuario
  const resNotif = await client.query(
    `SELECT n.id_notificacion,
            n.id_mascota,
            n.porcentaje_match,
            n.leida,
            n.mostrada_en_mascotas,
            to_char(n.fecha_creacion AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS fecha_creacion,
            m.nombre AS nombre_mascota,
            m.fotos AS foto_mascota,
            m.especie AS especie_mascota,
            m.sexo AS sexo_mascota,
            m.tamano AS tamano_mascota
     FROM notificacion_match_usuario n
     INNER JOIN mascota m ON m.id_mascota = n.id_mascota
     WHERE n.id_usuario = $1
       AND m.estado_adopcion <> 'adoptado'
     ORDER BY n.fecha_creacion DESC`,
    [idUsuario],
  );

  const notificaciones = resNotif.rows.map((r) => ({
    id_notificacion: r.id_notificacion,
    id_mascota: r.id_mascota,
    porcentaje_match: Number(r.porcentaje_match),
    leida: r.leida === true,
    mostrada_en_mascotas: r.mostrada_en_mascotas === true,
    fecha_creacion: r.fecha_creacion,
    nombre_mascota: r.nombre_mascota,
    foto_mascota: r.foto_mascota,
    especie_mascota: r.especie_mascota,
    sexo_mascota: r.sexo_mascota,
    tamano_mascota: r.tamano_mascota,
  }));

  const noLeidas = notificaciones.filter((n) => !n.leida).length;

  return {
    tiene_personalidad: true,
    id_mascota_match_inicial: idMatchInicial,
    porcentaje_match_inicial: porcentajeInicial,
    fecha_match_inicial: fechaMatchInicial,
    notificaciones,
    no_leidas: noLeidas,
  };
}

/**
 * Cuando un administrador registra una nueva mascota compatible, evalúa todos los
 * usuarios con personalidad registrada:
 * - Si un usuario no tenía Match inicial aún, le asigna esta mascota como su Match inicial.
 * - Si el usuario ya tenía Match inicial y la nueva mascota tiene compatibilidad >= 75%,
 *   crea una notificación en `notificacion_match_usuario` (sin duplicar).
 */
async function procesarNuevaMascotaParaUsuarios(idMascota, client = pool) {
  await asegurarEsquemaMatch();

  const resMascota = await client.query(
    `SELECT m.id_mascota, m.nombre, m.estado_adopcion, m.personalidad_definida,
            (m.fecha_creacion IS NOT NULL
             AND (CURRENT_TIMESTAMP - m.fecha_creacion) <= INTERVAL '48 hours'
             AND (CURRENT_TIMESTAMP - m.fecha_creacion) >= INTERVAL '-2 hours') AS es_nuevo,
            ${personalityColumns.map((c) => `pm.${c}`).join(', ')}
     FROM mascota m
     INNER JOIN personalidadmascota pm ON pm.id_mascota = m.id_mascota
     WHERE m.id_mascota = $1`,
    [idMascota],
  );

  if (resMascota.rows.length === 0) return;
  const mascota = resMascota.rows[0];
  if (!mascota.personalidad_definida) return;
  if (String(mascota.estado_adopcion || '').trim().toLowerCase() === 'adoptado') return;

  const resUsuarios = await client.query(
    `SELECT id_usuario, id_mascota_match_inicial, ${personalityColumns.join(', ')}
     FROM personalidadusuario`,
  );

  for (const u of resUsuarios.rows) {
    const pct = calcularPorcentajeCompatibilidad(u, mascota);
    if (pct == null) continue;

    if (!u.id_mascota_match_inicial) {
      await client.query(
        `UPDATE personalidadusuario
         SET id_mascota_match_inicial = $1,
             porcentaje_match_inicial = $2,
             fecha_match_inicial = CURRENT_TIMESTAMP
         WHERE id_usuario = $3 AND id_mascota_match_inicial IS NULL`,
        [idMascota, pct, u.id_usuario],
      );
    } else if (u.id_mascota_match_inicial !== idMascota && mascota.es_nuevo && pct >= UMBRAL_NUEVA_COINCIDENCIA) {
      await client.query(
        `INSERT INTO notificacion_match_usuario
          (id_notificacion, id_usuario, id_mascota, porcentaje_match)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (id_usuario, id_mascota) DO NOTHING`,
        [randomUUID(), u.id_usuario, idMascota, pct],
      );
    }
  }
}

module.exports = {
  UMBRAL_NUEVA_COINCIDENCIA,
  asegurarEsquemaMatch,
  calcularPorcentajeCompatibilidad,
  sincronizarMatchDeUsuario,
  procesarNuevaMascotaParaUsuarios,
};

