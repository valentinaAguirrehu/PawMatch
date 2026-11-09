require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER || 'postgres',
  password: String(process.env.DB_PASSWORD ?? ''),
});

pool.on('connect', () => console.log('Conectado a PostgreSQL'));
pool.on('error', (err) => console.error('Error en el pool de Postgres', err));
pool.query('SELECT 1').catch(err => console.error('Error conectando a PostgreSQL:', err.message));
module.exports = pool;

