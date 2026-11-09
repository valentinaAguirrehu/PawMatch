const pool = require('../db');

async function migrar() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    console.log('Iniciando migración para ciclos, aportes y evaluaciones...');

    // 1. Columnas en seguimientoapadrinamiento: numero_seguimiento y ciclo
    await client.query(`
      ALTER TABLE seguimientoapadrinamiento
        ADD COLUMN IF NOT EXISTS numero_seguimiento integer,
        ADD COLUMN IF NOT EXISTS ciclo integer;
    `);
    console.log('✓ Columnas numero_seguimiento y ciclo aseguradas en seguimientoapadrinamiento.');

    // Calcular numero_seguimiento y ciclo para filas existentes que no lo tengan
    await client.query(`
      WITH calculados AS (
        SELECT 
          id_seguimiento_apadrinacion,
          ROW_NUMBER() OVER (
            PARTITION BY id_solicitud_apadrinamiento 
            ORDER BY fecha_seguimiento ASC, created_at ASC
          ) AS num
        FROM seguimientoapadrinamiento
      )
      UPDATE seguimientoapadrinamiento s
      SET numero_seguimiento = c.num,
          ciclo = CEIL(c.num::float / 3)
      FROM calculados c
      WHERE s.id_seguimiento_apadrinacion = c.id_seguimiento_apadrinacion
        AND (s.numero_seguimiento IS NULL OR s.ciclo IS NULL);
    `);
    console.log('✓ Consecutivos y ciclos calculados para seguimientos existentes.');

    // 2. Columnas de aportes comprometidos en solicitudapadrinamiento
    await client.query(`
      ALTER TABLE solicitudapadrinamiento
        ADD COLUMN IF NOT EXISTS aporta_monetario boolean DEFAULT false,
        ADD COLUMN IF NOT EXISTS monto_comprometido numeric,
        ADD COLUMN IF NOT EXISTS periodicidad text,
        ADD COLUMN IF NOT EXISTS aporta_especie boolean DEFAULT false,
        ADD COLUMN IF NOT EXISTS aporta_otro boolean DEFAULT false,
        ADD COLUMN IF NOT EXISTS detalle_otro text;
    `);
    console.log('✓ Columnas de aportes comprometidos aseguradas en solicitudapadrinamiento.');

    // Sincronizar datos históricos de aportes en solicitudapadrinamiento
    await client.query(`
      UPDATE solicitudapadrinamiento
      SET 
        aporta_monetario = CASE 
          WHEN monto_aporte IS NOT NULL AND monto_aporte > 0 THEN true 
          WHEN tipo_aporte ILIKE '%monetario%' THEN true 
          ELSE COALESCE(aporta_monetario, false) 
        END,
        monto_comprometido = CASE 
          WHEN monto_aporte IS NOT NULL AND monto_aporte > 0 THEN monto_aporte 
          ELSE monto_comprometido 
        END,
        periodicidad = COALESCE(periodicidad, frecuencia_aporte, 'mensual'),
        aporta_especie = CASE 
          WHEN (detalle_especie IS NOT NULL AND trim(detalle_especie) <> '') THEN true 
          WHEN tipo_aporte ILIKE '%especie%' THEN true 
          ELSE COALESCE(aporta_especie, false) 
        END,
        aporta_otro = CASE 
          WHEN (detalle_otro IS NOT NULL AND trim(detalle_otro) <> '') THEN true 
          WHEN tipo_aporte ILIKE '%otro%' THEN true 
          ELSE COALESCE(aporta_otro, false) 
        END
      WHERE aporta_monetario IS NULL OR aporta_especie IS NULL OR aporta_otro IS NULL;
    `);
    console.log('✓ Sincronización de aportes históricos realizada.');

    // 3. Tabla evaluacion_ciclo
    await client.query(`
      CREATE TABLE IF NOT EXISTS evaluacion_ciclo (
        id_evaluacion uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        id_solicitud_apadrinamiento uuid NOT NULL REFERENCES solicitudapadrinamiento(id_solicitud_apadrinamiento) ON DELETE CASCADE,
        ciclo integer NOT NULL,
        promedio numeric(3,2) NOT NULL,
        puntuacion text NOT NULL, -- 'buen', 'regular', 'mal'
        decision text NOT NULL, -- 'continuar', 'cancelar'
        nota text,
        id_administrador uuid REFERENCES usuario(id_usuario),
        fecha_decision date NOT NULL DEFAULT CURRENT_DATE,
        visto_por_usuario boolean DEFAULT false,
        fecha_vista_usuario timestamptz,
        created_at timestamptz DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT uq_solicitud_ciclo UNIQUE (id_solicitud_apadrinamiento, ciclo)
      );
    `);
    console.log('✓ Tabla evaluacion_ciclo creada o existente.');

    // 4. Tabla seguimiento_aporte
    await client.query(`
      CREATE TABLE IF NOT EXISTS seguimiento_aporte (
        id_aporte uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        id_seguimiento_apadrinacion uuid NOT NULL REFERENCES seguimientoapadrinamiento(id_seguimiento_apadrinacion) ON DELETE CASCADE,
        tipo text NOT NULL, -- 'monetario', 'especie', 'otro'
        comprometido text,
        recibido boolean NOT NULL DEFAULT true,
        medio text, -- 'efectivo', 'transferencia', 'consignación', 'otro'
        monto_recibido numeric,
        referencia text,
        detalle_recibido text,
        observacion text,
        created_at timestamptz DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('✓ Tabla seguimiento_aporte creada o existente.');

    // 5. Función RPC registrar_evaluacion con soporte para ciclos, bloqueo opcional y aportes
    await client.query(`
      CREATE OR REPLACE FUNCTION registrar_evaluacion(
        p_id_solicitud uuid,
        p_id_admin uuid,
        p_decision text,
        p_nota text DEFAULT NULL,
        p_bloquear_usuario boolean DEFAULT false,
        p_ciclo int DEFAULT NULL
      )
      RETURNS json
      LANGUAGE plpgsql
      AS $$
      DECLARE
        v_solicitud record;
        v_padrino record;
        v_mascota record;
        v_admin record;
        v_ciclo_a_evaluar int;
        v_promedio numeric(3,2);
        v_puntuacion text;
        v_titulo text;
        v_mensaje text;
        v_eval_id uuid;
      BEGIN
        -- Validar decisión
        IF p_decision NOT IN ('continuar', 'cancelar') THEN
          RAISE EXCEPTION 'La decisión debe ser "continuar" o "cancelar"';
        END IF;

        -- Obtener solicitud
        SELECT * INTO v_solicitud
        FROM solicitudapadrinamiento
        WHERE id_solicitud_apadrinamiento = p_id_solicitud;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'La solicitud de apadrinamiento no existe';
        END IF;

        SELECT * INTO v_padrino FROM usuario WHERE id_usuario = v_solicitud.id_usuario;
        SELECT * INTO v_mascota FROM mascota WHERE id_mascota = v_solicitud.id_mascota;
        SELECT * INTO v_admin FROM usuario WHERE id_usuario = p_id_admin;

        -- Determinar ciclo a evaluar
        IF p_ciclo IS NOT NULL THEN
          v_ciclo_a_evaluar := p_ciclo;
        ELSE
          -- Obtener el ciclo más alto pendiente de evaluación
          SELECT COALESCE(MAX(ciclo), 1) INTO v_ciclo_a_evaluar
          FROM seguimientoapadrinamiento
          WHERE id_solicitud_apadrinamiento = p_id_solicitud;
        END IF;

        -- Calcular promedio del ciclo
        SELECT COALESCE(ROUND(AVG(calificacion), 2), 0.0)
        INTO v_promedio
        FROM seguimientoapadrinamiento
        WHERE id_solicitud_apadrinamiento = p_id_solicitud
          AND ciclo = v_ciclo_a_evaluar;

        -- Clasificación
        IF v_promedio >= 4.0 THEN
          v_puntuacion := 'buen';
        ELSIF v_promedio >= 3.0 THEN
          v_puntuacion := 'regular';
        ELSE
          v_puntuacion := 'mal';
        END IF;

        -- Guardar en evaluacion_ciclo (UPSERT por ciclo)
        INSERT INTO evaluacion_ciclo (
          id_solicitud_apadrinamiento,
          ciclo,
          promedio,
          puntuacion,
          decision,
          nota,
          id_administrador,
          fecha_decision,
          visto_por_usuario
        ) VALUES (
          p_id_solicitud,
          v_ciclo_a_evaluar,
          v_promedio,
          v_puntuacion,
          p_decision,
          p_nota,
          p_id_admin,
          CURRENT_DATE,
          false
        )
        ON CONFLICT (id_solicitud_apadrinamiento, ciclo)
        DO UPDATE SET
          promedio = EXCLUDED.promedio,
          puntuacion = EXCLUDED.puntuacion,
          decision = EXCLUDED.decision,
          nota = EXCLUDED.nota,
          id_administrador = EXCLUDED.id_administrador,
          fecha_decision = CURRENT_DATE,
          visto_por_usuario = false
        RETURNING id_evaluacion INTO v_eval_id;

        -- Mantener columnas de compatibilidad en solicitudapadrinamiento
        UPDATE solicitudapadrinamiento
        SET decision_admin = p_decision,
            nota_decision = p_nota,
            id_admin_decision = p_id_admin,
            fecha_decision = CURRENT_DATE,
            leido_usuario = false,
            fecha_actualizacion_estado = CURRENT_TIMESTAMP
        WHERE id_solicitud_apadrinamiento = p_id_solicitud;

        -- Si se cancela
        IF p_decision = 'cancelar' THEN
          UPDATE solicitudapadrinamiento
          SET estado = 'cancelada',
              estado_apadrinamiento = 'cancelada',
              motivo_cancelacion = p_nota,
              fecha_cancelacion = CURRENT_TIMESTAMP,
              observaciones = p_nota,
              leido_usuario = false,
              fecha_actualizacion_estado = CURRENT_TIMESTAMP
          WHERE id_solicitud_apadrinamiento = p_id_solicitud;

          -- Bloquear usuario solo si p_bloquear_usuario es true
          IF p_bloquear_usuario = true THEN
            UPDATE usuario
            SET bloqueado_apadrinar = true
            WHERE id_usuario = v_solicitud.id_usuario;
          END IF;

          v_titulo := 'Apadrinamiento cancelado';
          v_mensaje := 'Tu apadrinamiento de ' || COALESCE(v_mascota.nombre, 'la mascota') || ' ha sido cancelado en el Ciclo ' || v_ciclo_a_evaluar || '.';
          IF p_nota IS NOT NULL AND trim(p_nota) <> '' THEN
            v_mensaje := v_mensaje || ' Motivo: ' || trim(p_nota);
          END IF;
        ELSE
          v_titulo := 'Evaluación del Ciclo ' || v_ciclo_a_evaluar;
          v_mensaje := '¡Tu evaluación del Ciclo ' || v_ciclo_a_evaluar || ' de apadrinamiento de ' || COALESCE(v_mascota.nombre, 'tu mascota') || ' está lista! Tu apadrinamiento continúa activo.';
          IF p_nota IS NOT NULL AND trim(p_nota) <> '' THEN
            v_mensaje := v_mensaje || ' Nota: ' || trim(p_nota);
          END IF;
        END IF;

        -- Crear notificación
        INSERT INTO notificaciones (
          id_usuario,
          id_solicitud_apadrinamiento,
          tipo,
          titulo,
          mensaje,
          leida,
          fecha
        ) VALUES (
          v_solicitud.id_usuario,
          p_id_solicitud,
          'evaluacion_ciclo',
          v_titulo,
          v_mensaje,
          false,
          CURRENT_TIMESTAMP
        );

        RETURN json_build_object(
          'ok', true,
          'id_evaluacion', v_eval_id,
          'ciclo', v_ciclo_a_evaluar,
          'promedio', v_promedio,
          'puntuacion', v_puntuacion,
          'decision', p_decision,
          'id_solicitud_apadrinamiento', p_id_solicitud,
          'mensaje', CASE WHEN p_decision = 'continuar' THEN 'Ciclo ' || v_ciclo_a_evaluar || ' evaluado: apadrinamiento continúa activo.' ELSE 'Apadrinamiento cancelado en Ciclo ' || v_ciclo_a_evaluar || '.' END
        );
      END;
      $$;
    `);
    console.log('✓ Función registrar_evaluacion actualizada con soporte para ciclos y bloqueo opcional.');

    await client.query('COMMIT');
    console.log('Migración completada con éxito.');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error durante la migración:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

migrar();
