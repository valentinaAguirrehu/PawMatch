// Quita el fondo de una foto ya guardada y la deja como PNG transparente.
//   npm install @imgly/background-removal-node
// Si algo falla (o QUITAR_FONDO=false en el .env), devuelve la ruta original:
// la mascota se guarda igual, solo que con la foto tal cual.
const fs = require('fs/promises');
const path = require('path');

const TIPOS = { '.png': 'image/png', '.webp': 'image/webp' };

async function quitarFondo(rutaArchivo) {
  if (process.env.QUITAR_FONDO === 'false') return rutaArchivo;
  try {
    const { removeBackground } = require('@imgly/background-removal-node');
    const original = await fs.readFile(rutaArchivo);
    const tipo = TIPOS[path.extname(rutaArchivo).toLowerCase()] || 'image/jpeg';

    const resultado = await removeBackground(new Blob([original], { type: tipo }));
    const png = Buffer.from(await resultado.arrayBuffer());

    const nueva = rutaArchivo.replace(/\.[^.]+$/, '') + '-sin-fondo.png';
    await fs.writeFile(nueva, png);
    await fs.unlink(rutaArchivo).catch(() => {}); // borra la original
    return nueva;
  } catch (error) {
    console.error('No se pudo quitar el fondo:', error.message);
    return rutaArchivo;
  }
}

module.exports = { quitarFondo };