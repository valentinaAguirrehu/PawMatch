const GENEROS = ['Hombre', 'Mujer'];

function generoValido(valor) {
  return GENEROS.includes(valor);
}

async function asegurarGeneroUsuario(pool) {
  await pool.query(
    'ALTER TABLE usuario ADD COLUMN IF NOT EXISTS genero varchar(10)',
  );
  await pool.query(`
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
  `);
}

module.exports = {
  GENEROS,
  generoValido,
  asegurarGeneroUsuario,
};
