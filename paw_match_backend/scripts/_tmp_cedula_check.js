const pool = require('../db');

(async () => {
  const cols = await pool.query(`
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_name = 'usuario'
      AND (
        column_name ILIKE '%doc%'
        OR column_name ILIKE '%ced%'
        OR column_name ILIKE '%ident%'
      )
    ORDER BY column_name
  `);
  console.log('COLUMNAS', JSON.stringify(cols.rows));

  const users = await pool.query(`
    SELECT u.id_usuario, u.nombres, u.apellidos, u.correo,
           u.documento_identidad IS NULL AS doc_null,
           length(btrim(COALESCE(u.documento_identidad, ''))) AS doc_len
    FROM usuario u
    WHERE lower(u.correo) LIKE '%angiefer%'
       OR lower(u.nombres) LIKE '%angie%'
  `);
  console.log('USUARIOS', JSON.stringify(users.rows));

  const sols = await pool.query(`
    SELECT m.nombre,
           sa.fecha_inicio_apadrinamiento,
           length(btrim(COALESCE(u.documento_identidad, ''))) AS doc_len,
           u.nombres, u.correo
    FROM solicitudapadrinamiento sa
    JOIN mascota m ON m.id_mascota = sa.id_mascota
    JOIN usuario u ON u.id_usuario = sa.id_usuario
    WHERE lower(m.nombre) = 'chispi'
       OR lower(u.correo) LIKE '%angiefer%'
  `);
  console.log('SOLICITUDES', JSON.stringify(sols.rows));

  const admin = await pool.query(`
    SELECT id_usuario, rol
    FROM usuario
    WHERE rol IN ('admin', 'administrador', 'superadmin')
      AND estado_cuenta = 'activo'
    LIMIT 1
  `);
  console.log('ADMIN', JSON.stringify(admin.rows));
  await pool.end();
})().catch((err) => {
  console.error('ERR', err.message);
  process.exit(1);
});
