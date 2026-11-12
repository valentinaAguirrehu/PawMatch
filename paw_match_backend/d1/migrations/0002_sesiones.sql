-- Sesiones revocables. Se guarda el hash del identificador, no el token.
-- No modifica 0001_initial_schema.sql.

CREATE TABLE sesion (
  hash_sesion TEXT PRIMARY KEY,
  id_usuario TEXT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
  expira TEXT NOT NULL,
  revocada INTEGER NOT NULL DEFAULT 0 CHECK (revocada IN (0, 1)),
  creada TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sesion_usuario ON sesion (id_usuario);
CREATE INDEX idx_sesion_expira ON sesion (expira);
