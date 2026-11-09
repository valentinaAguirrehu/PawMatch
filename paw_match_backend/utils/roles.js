function citarIdentificador(nombre) {
  return `"${String(nombre).replace(/"/g, '""')}"`;
}

function normalizarRol(rol) {
  return String(rol || '').trim().toLowerCase();
}

function esAdministrador(rol) {
  const valor = normalizarRol(rol);
  return valor === 'administrador' || valor === 'superadmin';
}

function esSuperAdmin(rol) {
  return normalizarRol(rol) === 'superadmin';
}

/// Permite guardar el rol superadmin si la columna trae un check o un enum
/// que solo aceptaba usuario y administrador.
async function asegurarRolSuperAdmin(pool) {
  const columna = await pool.query(
    `SELECT n.nspname, t.typtype, t.typname
     FROM pg_attribute a
     JOIN pg_class c ON c.oid = a.attrelid
     JOIN pg_type t ON t.oid = a.atttypid
     JOIN pg_namespace n ON n.oid = t.typnamespace
     WHERE c.relname = 'usuario' AND a.attname = 'rol' AND a.attnum > 0
       AND NOT a.attisdropped
     LIMIT 1`
  );
  const tipo = columna.rows[0];
  if (tipo?.typtype === 'e') {
    await pool.query(
      `ALTER TYPE ${citarIdentificador(tipo.nspname)}.${citarIdentificador(tipo.typname)} ADD VALUE IF NOT EXISTS 'superadmin'`
    );
  }

  const restricciones = await pool.query(
    `SELECT con.conname
     FROM pg_constraint con
     JOIN pg_class rel ON rel.oid = con.conrelid
     WHERE rel.relname = 'usuario'
       AND con.contype = 'c'
       AND pg_get_constraintdef(con.oid) ILIKE '%rol%'`
  );
  for (const fila of restricciones.rows) {
    await pool.query(
      `ALTER TABLE usuario DROP CONSTRAINT ${citarIdentificador(fila.conname)}`
    );
  }
}

module.exports = { esAdministrador, esSuperAdmin, asegurarRolSuperAdmin };
