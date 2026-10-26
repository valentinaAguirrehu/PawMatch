require('dotenv').config({ path: 'c:/Users/Valentina/Documents/Universidad/Construccion de trabajo/Paw match/PawMatch/paw_match_backend/.env' });
const { enviarCorreoNuevaDenunciaAdmin } = require('../utils/correo');

async function testEmail() {
  console.log('Probando envío de correo administrativo...');
  console.log('GMAIL_USER en .env:', process.env.GMAIL_USER);
  const resultado = await enviarCorreoNuevaDenunciaAdmin({
    radicado: 'DEN-2026-TEST1',
    tipo_reporte: 'Sospecha de maltrato animal',
    tipo_animal: 'Perro',
    ciudad_caso: 'San Juan de Pasto',
    fecha_creacion: new Date().toISOString(),
  });
  console.log('Resultado del envío:', resultado);
}

testEmail().catch(console.error);
