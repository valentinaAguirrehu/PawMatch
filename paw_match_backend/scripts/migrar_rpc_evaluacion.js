const pool = require('../db');

async function migrar() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    console.log('Iniciando migración atómica de evaluación y notificaciones...');

    // 1. Columnas fecha_vista_usuario y eliminar_despues_de en solicitudapadrinamiento
    await client.query(`
      ALTER TABLE solicitudapadrinamiento
        ADD COLUMN IF NOT EXISTS fecha_vista_usuario timestamptz,
        ADD COLUMN IF NOT EXISTS eliminar_despues_de timestamptz;
    `);
    console.log('✓ Columnas fecha_vista_usuario y eliminar_despues_de agregadas o existentes.');

    // 2. Tabla notificaciones si no existe
    await client.query(`
      CREATE TABLE IF NOT EXISTS notificaciones (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        id_usuario uuid REFERENCES usuario(id_usuario) ON DELETE CASCADE,
        id_solicitud_apadrinamiento uuid REFERENCES solicitudapadrinamiento(id_solicitud_apadrinamiento) ON DELETE CASCADE,
        tipo text,
        titulo text,
        mensaje text,
        leida boolean DEFAULT false,
        fecha timestamptz DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('✓ Tabla notificaciones verificada o creada.');

    // 3. Función RPC registrar_evaluacion atómica
    await client.query(`
      CREATE OR REPLACE FUNCTION registrar_evaluacion(
        p_id_solicitud uuid,
        p_id_admin uuid,
        p_decision text,
        p_nota text DEFAULT NULL,
        p_calificacion int DEFAULT NULL,
        p_observaciones text DEFAULT NULL,
        p_proximo date DEFAULT NULL
      )
      RETURNS json
      LANGUAGE plpgsql
      AS $$
      DECLARE
        v_solicitud record;
        v_padrino record;
        v_mascota record;
        v_admin record;
        v_titulo text;
        v_mensaje text;
        v_nuevo_seg record;
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

        -- Obtener usuario padrino
        SELECT * INTO v_padrino
        FROM usuario
        WHERE id_usuario = v_solicitud.id_usuario;

        -- Obtener mascota
        SELECT * INTO v_mascota
        FROM mascota
        WHERE id_mascota = v_solicitud.id_mascota;

        -- Obtener admin
        SELECT * INTO v_admin
        FROM usuario
        WHERE id_usuario = p_id_admin;

        -- Si se proporciona un nuevo seguimiento, registrarlo
        IF p_calificacion IS NOT NULL THEN
          INSERT INTO seguimientoapadrinamiento (
            id_solicitud_apadrinamiento,
            id_administrador,
            fecha_seguimiento,
            cumplimiento,
            observaciones,
            proximo_seguimiento,
            calificacion,
            correo_alerta_enviado,
            created_at
          ) VALUES (
            p_id_solicitud,
            p_id_admin,
            CURRENT_DATE,
            (p_calificacion >= 3),
            COALESCE(p_observaciones, ''),
            p_proximo,
            p_calificacion,
            false,
            NOW()
          )
          RETURNING * INTO v_nuevo_seg;
        END IF;

        -- Aplicar decisión
        IF p_decision = 'continuar' THEN
          UPDATE solicitudapadrinamiento
          SET decision_admin = 'continuar',
              nota_decision = p_nota,
              id_admin_decision = p_id_admin,
              fecha_decision = CURRENT_DATE,
              leido_usuario = false,
              fecha_actualizacion_estado = CURRENT_TIMESTAMP
          WHERE id_solicitud_apadrinamiento = p_id_solicitud;

          v_titulo := 'Evaluación de apadrinamiento';
          v_mensaje := 'La fundación ha evaluado tu apadrinamiento de ' || COALESCE(v_mascota.nombre, 'tu mascota') || ' y ha decidido que continúa activo.';
          IF p_nota IS NOT NULL AND trim(p_nota) <> '' THEN
            v_mensaje := v_mensaje || ' Nota: ' || trim(p_nota);
          END IF;

        ELSE -- cancelar
          UPDATE solicitudapadrinamiento
          SET estado = 'cancelada',
              estado_apadrinamiento = 'cancelada',
              decision_admin = 'cancelar',
              nota_decision = p_nota,
              id_admin_decision = p_id_admin,
              fecha_decision = CURRENT_DATE,
              motivo_cancelacion = p_nota,
              fecha_cancelacion = CURRENT_TIMESTAMP,
              observaciones = p_nota,
              leido_usuario = false,
              fecha_actualizacion_estado = CURRENT_TIMESTAMP
          WHERE id_solicitud_apadrinamiento = p_id_solicitud;

          -- Bloquear usuario para volver a apadrinar
          UPDATE usuario
          SET bloqueado_apadrinar = true
          WHERE id_usuario = v_solicitud.id_usuario;

          v_titulo := 'Apadrinamiento cancelado';
          v_mensaje := 'Tu apadrinamiento de ' || COALESCE(v_mascota.nombre, 'la mascota') || ' ha sido cancelado por la fundación.';
          IF p_nota IS NOT NULL AND trim(p_nota) <> '' THEN
            v_mensaje := v_mensaje || ' Motivo: ' || trim(p_nota);
          END IF;
        END IF;

        -- Crear notificación al usuario
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
          'evaluacion_apadrinamiento',
          v_titulo,
          v_mensaje,
          false,
          CURRENT_TIMESTAMP
        );

        RETURN json_build_object(
          'ok', true,
          'decision', p_decision,
          'id_solicitud_apadrinamiento', p_id_solicitud,
          'mensaje', CASE WHEN p_decision = 'continuar' THEN 'Apadrinamiento continúa activo' ELSE 'Apadrinamiento cancelado' END
        );
      END;
      $$;
    `);
    console.log('✓ Función RPC registrar_evaluacion creada exitosamente.');

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
