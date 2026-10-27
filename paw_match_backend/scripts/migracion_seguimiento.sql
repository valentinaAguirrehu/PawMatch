-- Migración para el Módulo de Seguimiento de Apadrinamiento
-- PawMatch - PostgreSQL / Supabase

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Modificaciones a seguimientoapadrinamiento
ALTER TABLE seguimientoapadrinamiento 
  ALTER COLUMN id_seguimiento_apadrinacion SET DEFAULT gen_random_uuid();

ALTER TABLE seguimientoapadrinamiento
  ADD COLUMN IF NOT EXISTS calificacion SMALLINT CHECK (calificacion >= 1 AND calificacion <= 5),
  ADD COLUMN IF NOT EXISTS correo_alerta_enviado BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW();

-- 2. Modificaciones a solicitudapadrinamiento
ALTER TABLE solicitudapadrinamiento
  ADD COLUMN IF NOT EXISTS estado_apadrinamiento VARCHAR(20) DEFAULT 'activa',
  ADD COLUMN IF NOT EXISTS motivo_cancelacion TEXT,
  ADD COLUMN IF NOT EXISTS fecha_cancelacion TIMESTAMP WITHOUT TIME ZONE;

-- 3. Modificaciones a usuario
ALTER TABLE usuario
  ADD COLUMN IF NOT EXISTS bloqueado_apadrinar BOOLEAN DEFAULT FALSE;

-- Sincronizar estado inicial de estado_apadrinamiento según estado
UPDATE solicitudapadrinamiento
SET estado_apadrinamiento = CASE 
  WHEN estado = 'cancelada' THEN 'cancelada'
  WHEN estado = 'aprobada' THEN 'activa'
  ELSE 'activa'
END
WHERE estado_apadrinamiento IS NULL OR estado_apadrinamiento = 'activa';

-- 4. Función para obtener promedio de calificación de un padrino
CREATE OR REPLACE FUNCTION fn_promedio_calificacion_padrino(p_id_usuario UUID)
RETURNS NUMERIC AS $$
DECLARE
  v_promedio NUMERIC;
BEGIN
  SELECT ROUND(AVG(s.calificacion)::numeric, 1)
  INTO v_promedio
  FROM seguimientoapadrinamiento s
  JOIN solicitudapadrinamiento sa ON s.id_solicitud_apadrinamiento = sa.id_solicitud_apadrinamiento
  WHERE sa.id_usuario = p_id_usuario
    AND s.calificacion IS NOT NULL;

  RETURN COALESCE(v_promedio, 0.0);
END;
$$ LANGUAGE plpgsql;

-- 5. Vista de resumen de padrinos y calificaciones
CREATE OR REPLACE VIEW vista_resumen_padrinos AS
SELECT 
  u.id_usuario,
  u.nombres,
  u.apellidos,
  u.correo,
  COALESCE(u.bloqueado_apadrinar, FALSE) AS bloqueado_apadrinar,
  COALESCE(ROUND(AVG(seg.calificacion)::numeric, 1), 0.0) AS calificacion_promedio,
  COUNT(seg.id_seguimiento_apadrinacion) AS total_seguimientos,
  COUNT(CASE WHEN seg.cumplimiento = false OR seg.calificacion <= 2 THEN 1 END) AS total_incumplimientos
FROM usuario u
LEFT JOIN solicitudapadrinamiento sa ON sa.id_usuario = u.id_usuario
LEFT JOIN seguimientoapadrinamiento seg ON seg.id_solicitud_apadrinamiento = sa.id_solicitud_apadrinamiento
GROUP BY u.id_usuario, u.nombres, u.apellidos, u.correo, u.bloqueado_apadrinar;

-- 6. Función para verificar 3 incumplimientos consecutivos
CREATE OR REPLACE FUNCTION fn_verificar_tres_incumplimientos(p_id_solicitud UUID)
RETURNS TABLE (
  tiene_tres_incumplimientos BOOLEAN,
  ultimo_correo_enviado BOOLEAN,
  ultimo_id_seguimiento UUID
) AS $$
DECLARE
  v_total INT := 0;
  v_fallas INT := 0;
  v_ultimo_correo BOOLEAN := FALSE;
  v_ultimo_id UUID := NULL;
  r RECORD;
BEGIN
  FOR r IN (
    SELECT 
      id_seguimiento_apadrinacion,
      cumplimiento,
      calificacion,
      correo_alerta_enviado
    FROM seguimientoapadrinamiento
    WHERE id_solicitud_apadrinamiento = p_id_solicitud
    ORDER BY fecha_seguimiento DESC, created_at DESC
    LIMIT 3
  ) LOOP
    v_total := v_total + 1;
    IF v_total = 1 THEN
      v_ultimo_correo := COALESCE(r.correo_alerta_enviado, FALSE);
      v_ultimo_id := r.id_seguimiento_apadrinacion;
    END IF;

    IF (r.cumplimiento = FALSE OR (r.calificacion IS NOT NULL AND r.calificacion <= 2)) THEN
      v_fallas := v_fallas + 1;
    END IF;
  END LOOP;

  IF v_total >= 3 AND v_fallas >= 3 THEN
    RETURN QUERY SELECT TRUE, v_ultimo_correo, v_ultimo_id;
  ELSE
    RETURN QUERY SELECT FALSE, v_ultimo_correo, v_ultimo_id;
  END IF;
END;
$$ LANGUAGE plpgsql;
