const pool = require('../db');

async function migrar() {
  try {
    console.log('Iniciando migración de columnas decision_admin...');
    await pool.query(`
      ALTER TABLE solicitudapadrinamiento
        ADD COLUMN IF NOT EXISTS decision_admin text,
        ADD COLUMN IF NOT EXISTS nota_decision text,
        ADD COLUMN IF NOT EXISTS id_admin_decision uuid,
        ADD COLUMN IF NOT EXISTS fecha_decision date;
    `);

    // Actualizar vista_resumen_padrinos si es necesario o verificar
    console.log('Columnas agregadas con éxito a solicitudapadrinamiento');
  } catch (error) {
    console.error('Error al migrar:', error);
  } finally {
    await pool.end();
  }
}

migrar();
