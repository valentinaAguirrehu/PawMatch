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
          ADD COLUMN IF NOT EXISTS fecha_match_inicial TIMESTAMPTZ,
          ADD COLUMN IF NOT EXISTS aviso_reasignacion_pendiente BOOLEAN NOT NULL DEFAULT FALSE,
          ADD COLUMN IF NOT EXISTS nombre_match_anterior TEXT,
          ADD COLUMN IF NOT EXISTS id_aviso_reasignacion TEXT;
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

function estaAdoptada(mascota) {
  return String(mascota?.estado_adopcion || '').trim().toLowerCase() === 'adoptado';
}

/**
 * La mascota no adoptada (disponible o apadrinada) con mayor compatibilidad.
 * En empate gana el nombre, para que la elección no cambie entre consultas.
 */
function elegirMejorMascotaDisponible(perfil, mascotas, excluirId) {
  let mejor = null;
  let mejorPorcentaje = -1;

  for (const mascota of mascotas) {
    if (excluirId && mascota.id_mascota === excluirId) continue;
    if (estaAdoptada(mascota)) continue;
    const pct = calcularPorcentajeCompatibilidad(perfil, mascota);
    if (pct == null) continue;
    const nombre = String(mascota.nombre || '');
    const mejorNombre = mejor ? String(mejor.nombre || '') : '';
    const empate = pct === mejorPorcentaje && nombre.localeCompare(mejorNombre, 'es') < 0;
    if (pct > mejorPorcentaje || empate) {
      mejorPorcentaje = pct;
      mejor = mascota;
    }
  }

  if (!mejor) return null;
  return { id: mejor.id_mascota, porcentaje: mejorPorcentaje };
}

/**
 * Sincroniza el Match Ideal del usuario y sus notificaciones de nuevas coincidencias:
 * - Si aún no tiene Match Ideal, guarda la mascota no adoptada con mayor compatibilidad.
 * - Ese Match se conserva hasta que la mascota es adoptada, por él o por otra persona.
 * - Si fue adoptada, se reemplaza por la no adoptada de mayor compatibilidad y queda
 *   un aviso pendiente para contárselo al usuario.
 * - Detecta mascotas nuevas (<= 48h) con alta compatibilidad (>= 75%) distintas del Match
 *   y registra la notificación una única vez por mascota y usuario.
 */
async function sincronizarMatchDeUsuario(idUsuario, client = pool) {
  await asegurarEsquemaMatch();

  const resPerfil = await client.query(
    `SELECT id_perfil_usuario, id_usuario, ${personalityColumns.join(', ')},
            id_mascota_match_inicial, porcentaje_match_inicial, fecha_match_inicial,
            aviso_reasignacion_pendiente, nombre_match_anterior, id_aviso_reasignacion
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
      aviso_reasignacion: null,
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
  let avisoPendiente = perfil.aviso_reasignacion_pendiente === true;
  let nombreMatchAnterior = perfil.nombre_match_anterior;
  let idAvisoReasignacion = perfil.id_aviso_reasignacion;

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

  // 1. Sin Match Ideal: se guarda el mejor entre disponibles y apadrinados.
  //    Si el Match Ideal ya fue adoptado, se reemplaza por el siguiente mejor
  //    y se deja el aviso hasta que la persona lo lea.
  if (!idMatchInicial) {
    const mejor = elegirMejorMascotaDisponible(perfil, resMascotas.rows);
    if (mejor) {
      idMatchInicial = mejor.id;
      porcentajeInicial = mejor.porcentaje;
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
    let mascotaInicial = resMascotas.rows.find((m) => m.id_mascota === idMatchInicial);
    if (!mascotaInicial) {
      const suelta = await client.query(
        `SELECT id_mascota, nombre, estado_adopcion
         FROM mascota
         WHERE id_mascota = $1`,
        [idMatchInicial],
      );
      mascotaInicial = suelta.rows[0] || null;
    }

    if (mascotaInicial && estaAdoptada(mascotaInicial)) {
      const mejor = elegirMejorMascotaDisponible(
        perfil,
        resMascotas.rows,
        idMatchInicial,
      );
      const nombreAdoptado = String(mascotaInicial.nombre || '').trim();
      if (mejor && nombreAdoptado) {
        const nombreAviso = avisoPendiente && nombreMatchAnterior
          ? nombreMatchAnterior
          : nombreAdoptado;
        const idAviso = avisoPendiente && idAvisoReasignacion
          ? idAvisoReasignacion
          : randomUUID();
        const upd = await client.query(
          `UPDATE personalidadusuario
           SET id_mascota_match_inicial = $1,
               porcentaje_match_inicial = $2,
               fecha_match_inicial = CURRENT_TIMESTAMP,
               aviso_reasignacion_pendiente = TRUE,
               nombre_match_anterior = $3,
               id_aviso_reasignacion = $4
           WHERE id_usuario = $5
             AND id_mascota_match_inicial = $6
           RETURNING id_mascota_match_inicial, porcentaje_match_inicial, fecha_match_inicial,
                     aviso_reasignacion_pendiente, nombre_match_anterior, id_aviso_reasignacion`,
          [mejor.id, mejor.porcentaje, nombreAviso, idAviso, idUsuario, idMatchInicial],
        );
        const fila = upd.rows[0] || (await client.query(
          `SELECT id_mascota_match_inicial, porcentaje_match_inicial, fecha_match_inicial,
                  aviso_reasignacion_pendiente, nombre_match_anterior, id_aviso_reasignacion
           FROM personalidadusuario
           WHERE id_usuario = $1`,
          [idUsuario],
        )).rows[0];
        if (fila) {
          idMatchInicial = fila.id_mascota_match_inicial;
          porcentajeInicial = fila.porcentaje_match_inicial != null
            ? Number(fila.porcentaje_match_inicial)
            : null;
          fechaMatchInicial = fila.fecha_match_inicial;
          avisoPendiente = fila.aviso_reasignacion_pendiente === true;
          nombreMatchAnterior = fila.nombre_match_anterior;
          idAvisoReasignacion = fila.id_aviso_reasignacion;
        }
      }
    } else if (mascotaInicial && resMascotas.rows.some((m) => m.id_mascota === idMatchInicial)) {
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
      if (estaAdoptada(m)) continue;
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

  const avisoReasignacion = avisoPendiente && nombreMatchAnterior && idAvisoReasignacion
    ? {
        id: idAvisoReasignacion,
        nombre_anterior: nombreMatchAnterior,
      }
    : null;

  return {
    tiene_personalidad: true,
    id_mascota_match_inicial: idMatchInicial,
    porcentaje_match_inicial: porcentajeInicial,
    fecha_match_inicial: fechaMatchInicial,
    aviso_reasignacion: avisoReasignacion,
    notificaciones,
    no_leidas: noLeidas,
  };
}

async function marcarAvisoReasignacionVisto(idUsuario, idAviso, client = pool) {
  await asegurarEsquemaMatch();
  await client.query(
    `UPDATE personalidadusuario
     SET aviso_reasignacion_pendiente = FALSE
     WHERE id_usuario = $1
       AND aviso_reasignacion_pendiente = TRUE
       AND ($2::text IS NULL OR id_aviso_reasignacion = $2)`,
    [idUsuario, idAviso || null],
  );
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
  if (estaAdoptada(mascota)) return;

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
  marcarAvisoReasignacionVisto,
  procesarNuevaMascotaParaUsuarios,
};

