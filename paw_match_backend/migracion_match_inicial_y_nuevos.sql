-- ============================================================================
-- MIGRACIÓN SQL: MEJORA DEL SISTEMA MATCH Y ETIQUETA "NUEVO" (48 HORAS)
-- Base de datos: PostgreSQL (Paw Match)
-- ============================================================================

-- 1. Agregar fecha de creación real a la tabla mascota para la etiqueta "NUEVO" (48 horas)
ALTER TABLE mascota
  ADD COLUMN IF NOT EXISTS fecha_creacion TIMESTAMPTZ;

-- A las mascotas existentes previas a esta migración se les asigna una fecha > 48 horas
-- para que las mascotas antiguas NO aparezcan con la etiqueta "NUEVO".
UPDATE mascota
SET fecha_creacion = CURRENT_TIMESTAMP - INTERVAL '72 hours'
WHERE fecha_creacion IS NULL;

-- Todas las nuevas mascotas registradas tendrán automáticamente la fecha/hora exacta de creación.
ALTER TABLE mascota
  ALTER COLUMN fecha_creacion SET DEFAULT CURRENT_TIMESTAMP;

-- 2. Persistir el Primer Match Inicial del usuario en personalidadusuario
ALTER TABLE personalidadusuario
  ADD COLUMN IF NOT EXISTS id_mascota_match_inicial UUID REFERENCES mascota(id_mascota) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS porcentaje_match_inicial NUMERIC(5,2),
  ADD COLUMN IF NOT EXISTS fecha_match_inicial TIMESTAMPTZ;

-- 3. Tabla para persistir notificaciones de nuevas mascotas altamente compatibles
-- Evita que se dupliquen o se repitan indefinidamente en cada visita.
CREATE TABLE IF NOT EXISTS notificacion_match_usuario (
  id_notificacion UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  id_usuario UUID NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
  id_mascota UUID NOT NULL REFERENCES mascota(id_mascota) ON DELETE CASCADE,
  porcentaje_compatibilidad NUMERIC(5,2) NOT NULL,
  leida BOOLEAN NOT NULL DEFAULT FALSE,
  mostrada_en_mascotas BOOLEAN NOT NULL DEFAULT FALSE,
  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (id_usuario, id_mascota)
);

