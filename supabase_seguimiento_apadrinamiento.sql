-- ==============================================================================
-- MÓDULO DE SEGUIMIENTO DE APADRINAMIENTO - PAWMATCH
-- Base de Datos: PostgreSQL / Supabase
-- ==============================================================================

-- 1. EXTENSIÓN PARA UUIDs
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. MODIFICACIONES / CREACIÓN DE LA TABLA: seguimientoapadrinamiento
CREATE TABLE IF NOT EXISTS seguimientoapadrinamiento (
  id_seguimiento_apadrinacion UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_solicitud_apadrinamiento UUID NOT NULL REFERENCES solicitudapadrinamiento(id_solicitud_apadrinamiento) ON DELETE CASCADE,
  id_administrador UUID NOT NULL REFERENCES usuario(id_usuario),
  fecha_seguimiento DATE NOT NULL DEFAULT CURRENT_DATE,
  cumplimiento BOOLEAN NOT NULL DEFAULT true,
  observaciones TEXT,
  proximo_seguimiento DATE,
  calificacion SMALLINT NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
  correo_alerta_enviado BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- Si la tabla ya existía, garantizar las columnas y restricciones nuevas
ALTER TABLE seguimientoapadrinamiento 
  ALTER COLUMN id_seguimiento_apadrinacion SET DEFAULT gen_random_uuid();

ALTER TABLE seguimientoapadrinamiento
  ADD COLUMN IF NOT EXISTS calificacion SMALLINT CHECK (calificacion BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS correo_alerta_enviado BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW();

-- 3. MODIFICACIONES EN solicitudapadrinamiento
ALTER TABLE solicitudapadrinamiento
  ADD COLUMN IF NOT EXISTS estado_apadrinamiento VARCHAR(20) DEFAULT 'activa' 
    CHECK (estado_apadrinamiento IN ('activa', 'cancelada', 'finalizada')),
  ADD COLUMN IF NOT EXISTS motivo_cancelacion TEXT,
  ADD COLUMN IF NOT EXISTS fecha_cancelacion TIMESTAMP WITHOUT TIME ZONE;

-- Sincronizar estado inicial
UPDATE solicitudapadrinamiento
SET estado_apadrinamiento = CASE 
  WHEN estado = 'cancelada' THEN 'cancelada'
  WHEN estado = 'aprobada' THEN 'activa'
  ELSE 'activa'
END
WHERE estado_apadrinamiento IS NULL;

-- 4. MODIFICACIONES EN usuario
ALTER TABLE usuario
  ADD COLUMN IF NOT EXISTS bloqueado_apadrinar BOOLEAN DEFAULT false;

-- ==============================================================================
-- 5. FUNCIÓN: fn_promedio_calificacion_padrino
-- Calcula el promedio de estrellas del padrino considerando todos sus seguimientos
-- ==============================================================================
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

-- ==============================================================================
-- 6. VISTA: vista_resumen_padrinos
-- Resumen para perfil y listado con promedio de calificación y total de seguimientos
-- ==============================================================================
CREATE OR REPLACE VIEW vista_resumen_padrinos AS
SELECT 
  u.id_usuario,
  u.nombres,
  u.apellidos,
  u.correo,
  COALESCE(u.bloqueado_apadrinar, false) AS bloqueado_apadrinar,
  COALESCE(ROUND(AVG(seg.calificacion)::numeric, 1), 0.0) AS calificacion_promedio,
  COUNT(seg.id_seguimiento_apadrinacion) AS total_seguimientos,
  COUNT(CASE WHEN seg.cumplimiento = false OR seg.calificacion <= 2 THEN 1 END) AS total_incumplimientos
FROM usuario u
LEFT JOIN solicitudapadrinamiento sa ON sa.id_usuario = u.id_usuario
LEFT JOIN seguimientoapadrinamiento seg ON seg.id_solicitud_apadrinamiento = sa.id_solicitud_apadrinamiento
GROUP BY u.id_usuario, u.nombres, u.apellidos, u.correo, u.bloqueado_apadrinar;

-- ==============================================================================
-- 7. FUNCIÓN: fn_verificar_tres_incumplimientos
-- Detecta si los últimos 3 seguimientos consecutivos fueron incumplimientos
-- (Regla: calificación <= 2 o cumplimiento = false)
-- ==============================================================================
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

    -- Condición de incumplimiento: calificación <= 2 o cumplimiento = false
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

-- ==============================================================================
-- 8. FUNCIÓN PARA CANCELACIÓN DE APADRINAMIENTO Y BLOQUEO DE USUARIO
-- ==============================================================================
CREATE OR REPLACE FUNCTION fn_cancelar_apadrinamiento_por_incumplimiento(
  p_id_solicitud UUID,
  p_motivo TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_id_usuario UUID;
BEGIN
  -- 1. Actualizar solicitud de apadrinamiento
  UPDATE solicitudapadrinamiento
  SET estado = 'cancelada',
      estado_apadrinamiento = 'cancelada',
      motivo_cancelacion = p_motivo,
      fecha_cancelacion = NOW(),
      observaciones = p_motivo,
      leido_usuario = false,
      fecha_actualizacion_estado = NOW()
  WHERE id_solicitud_apadrinamiento = p_id_solicitud
  RETURNING id_usuario INTO v_id_usuario;

  IF v_id_usuario IS NULL THEN
    RETURN jsonb_build_object('exito', false, 'error', 'Solicitud no encontrada');
  END IF;

  -- 2. Bloquear al usuario para realizar nuevos apadrinamientos
  UPDATE usuario
  SET bloqueado_apadrinar = true
  WHERE id_usuario = v_id_usuario;

  RETURN jsonb_build_object(
    'exito', true,
    'mensaje', 'Apadrinamiento cancelado y usuario bloqueado para futuros apadrinamientos',
    'id_solicitud', p_id_solicitud,
    'id_usuario', v_id_usuario
  );
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- 9. SUPABASE EDGE FUNCTION / WEBHOOK (Deno / TypeScript con Resend)
-- Código de ejemplo para la Edge Function `supabase/functions/alerta-incumplimiento/index.ts`:
-- ==============================================================================
/*
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

serve(async (req) => {
  try {
    const { email, nombrePadrino, nombreMascota } = await req.json();

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: "PawMatch <alertas@fundacionmaritzaarevalo.org>",
        to: [email],
        subject: `Alerta: Seguimiento de apadrinamiento de ${nombreMascota}`,
        html: `
          <h2>Aviso de Incumplimiento de Apadrinamiento</h2>
          <p>Hola <strong>${nombrePadrino}</strong>,</p>
          <p>Se han registrado 3 seguimientos consecutivos con reporte de incumplimiento en el apadrinamiento de <strong>${nombreMascota}</strong>.</p>
          <p>Te recordamos que tu apadrinamiento está en riesgo de ser cancelado y tu cuenta podría ser inhabilitada.</p>
          <p>Por favor ingresa a PawMatch o contáctanos a la brevedad.</p>
        `,
      }),
    });

    const data = await res.json();
    return new Response(JSON.stringify(data), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
*/
