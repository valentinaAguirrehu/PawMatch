const pool = require('../db');
const { randomUUID } = require('crypto');

async function seed() {
  try {
    const existing = await pool.query('SELECT COUNT(*)::int AS count FROM noticia');
    if (existing.rows[0].count > 0) {
      console.log('Ya existen noticias en la base de datos.');
      pool.end();
      return;
    }

    await pool.query(
      `INSERT INTO noticia (id_noticia, titulo, contenido, imagen, fecha)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        randomUUID(),
        'Gran Jornada de Adopción y Vacunación este Fin de Semana',
        'La Fundación Maritza Arévalo invita a toda la comunidad a participar en nuestra gran jornada de adopción responsable. Tendremos peluditos listos para llenar tu hogar de amor, vacunación al día y charlas sobre tenencia responsable. ¡Te esperamos!',
        '/uploads/noticias/jornada_adopcion.jpg',
        '2026-10-20',
      ]
    );

    await pool.query(
      `INSERT INTO noticia (id_noticia, titulo, contenido, imagen, fecha)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        randomUUID(),
        'Final feliz: Nuevos rescatados encontraron su hogar para siempre',
        'Nos llena de orgullo y emoción compartirles que tras meses de recuperación y cuidados en nuestro refugio, varios de nuestros peluditos ya disfrutan del amor de una familia definitiva. ¡Gracias a todos los que apadrinan y hacen posible este milagro!',
        '/uploads/noticias/rescate_historias.jpg',
        '2026-10-18',
      ]
    );

    console.log('Noticias iniciales insertadas con éxito.');
  } catch (error) {
    console.error('Error insertando noticias:', error);
  } finally {
    pool.end();
  }
}

seed();
