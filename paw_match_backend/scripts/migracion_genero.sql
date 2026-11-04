-- Género del usuario. Lo elige al registrarse y define el trato
-- (masculino o femenino) de las preguntas de personalidad.
ALTER TABLE usuario
  ADD COLUMN IF NOT EXISTS genero varchar(10);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'usuario_genero_check'
  ) THEN
    ALTER TABLE usuario
      ADD CONSTRAINT usuario_genero_check
      CHECK (genero IS NULL OR genero IN ('Hombre', 'Mujer'));
  END IF;
END $$;
