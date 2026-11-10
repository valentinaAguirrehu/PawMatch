require('dotenv').config({ path: 'c:/Users/Valentina/Documents/Universidad/Construccion de trabajo/Paw match/PawMatch/paw_match_backend/.env' });
const pool = require('../db');

async function check() {
  try {
    const tables = await pool.query(`
      SELECT table_name FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name LIKE '%borrador%'
    `);
    console.log('Tablas borrador:', tables.rows);

    for (const t of tables.rows) {
      const count = await pool.query(`SELECT COUNT(*) FROM ${t.table_name}`);
      console.log(`Filas en ${t.table_name}:`, count.rows[0].count);
      const rows = await pool.query(`SELECT * FROM ${t.table_name} LIMIT 5`);
      console.log(`Detalle ${t.table_name}:`, JSON.stringify(rows.rows, null, 2));
    }

    const admins = await pool.query(`SELECT id_usuario, nombre, email, rol FROM usuario WHERE rol IN ('admin', 'superadmin', 'fundacion') OR rol IS NOT NULL`);
    console.log('Usuarios/admins:', admins.rows);
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await pool.end();
  }
}

check();

