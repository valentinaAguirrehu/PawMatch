-- Foto editable de la sección Protección animal en la bienvenida.
-- No modifica las migraciones anteriores.

ALTER TABLE informacionfundacion ADD COLUMN IF NOT EXISTS imagen_denuncias TEXT;
