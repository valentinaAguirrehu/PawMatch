const http = require('http');
const { Pool } = require('pg');
require('dotenv').config({ path: 'c:/Users/Valentina/Documents/Universidad/Construccion de trabajo/Paw match/PawMatch/paw_match_backend/.env' });

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

function request(method, path, headers = {}, body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path,
      method,
      headers: {
        ...headers,
      },
    };

    if (body && !headers['Content-Type']) {
      options.headers['Content-Type'] = 'application/json';
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        let json = null;
        try {
          json = JSON.parse(data);
        } catch (e) {
          json = data;
        }
        resolve({ status: res.statusCode, headers: res.headers, body: json });
      });
    });

    req.on('error', reject);

    if (body) {
      if (typeof body === 'string') {
        req.write(body);
      } else {
        req.write(JSON.stringify(body));
      }
    }
    req.end();
  });
}

async function runTests() {
  console.log('--- INICIO DE PRUEBAS DEL MÓDULO DE DENUNCIAS ---');

  // 1. Obtener ID de un administrador y de un usuario normal en la base de datos
  const adminRes = await pool.query("SELECT id_usuario, correo, rol FROM usuario WHERE rol = 'administrador' LIMIT 1");
  const admin = adminRes.rows[0];
  console.log('Admin encontrado para pruebas:', admin?.correo, 'ID:', admin?.id_usuario);

  const userRes = await pool.query("SELECT id_usuario, correo, rol FROM usuario WHERE rol != 'administrador' LIMIT 1");
  const normalUser = userRes.rows[0];
  console.log('Usuario normal para pruebas:', normalUser?.correo, 'ID:', normalUser?.id_usuario);

  // PRUEBA 1: Registro sin teléfono
  console.log('\n[PRUEBA 1] Registro sin teléfono (debe fallar con 400):');
  const resSinTel = await request('POST', '/api/denuncias', {}, {
    nombre_reportante: 'Carlos Martinez',
    telefono_reportante: '   ',
    barrio_reportante: 'Barrio Pandiaco',
    tipo_reporte: 'Sospecha de maltrato animal',
    tipo_animal: 'Perro',
    ubicacion_animal: 'Calle 18 # 20-30',
    ciudad_caso: 'San Juan de Pasto',
    fecha_situacion: '2026-10-24',
    descripcion_caso: 'Animal encerrado sin comida',
    acepto_politica: true,
  });
  console.log('Status:', resSinTel.status, '| Respuesta:', resSinTel.body);
  if (resSinTel.status === 400 && (resSinTel.body.error || resSinTel.body.mensaje || '').includes('teléfono')) {
    console.log('-> PASÓ: Rechazó correctamente el teléfono vacío o en espacios.');
  } else {
    console.error('-> FALLÓ: No validó el teléfono.');
  }

  // PRUEBA 2: Registro con teléfono inválido (muy corto)
  console.log('\n[PRUEBA 2] Registro con teléfono de solo 4 dígitos (debe fallar con 400):');
  const resTelCorto = await request('POST', '/api/denuncias', {}, {
    nombre_reportante: 'Carlos Martinez',
    telefono_reportante: '1234',
    barrio_reportante: 'Barrio Pandiaco',
    tipo_reporte: 'Sospecha de maltrato animal',
    tipo_animal: 'Perro',
    ubicacion_animal: 'Calle 18 # 20-30',
    ciudad_caso: 'San Juan de Pasto',
    fecha_situacion: '2026-10-24',
    descripcion_caso: 'Animal encerrado sin comida',
    acepto_politica: true,
  });
  console.log('Status:', resTelCorto.status, '| Respuesta:', resTelCorto.body);
  if (resTelCorto.status === 400 && (resTelCorto.body.error || resTelCorto.body.mensaje || '').includes('teléfono')) {
    console.log('-> PASÓ: Rechazó correctamente el teléfono corto.');
  } else {
    console.error('-> FALLÓ: No validó longitud del teléfono.');
  }

  // PRUEBA 3: Registro sin aceptar tratamiento de datos
  console.log('\n[PRUEBA 3] Registro sin autorizar tratamiento de datos (debe fallar con 400):');
  const resSinPolitica = await request('POST', '/api/denuncias', {}, {
    nombre_reportante: 'Carlos Martinez',
    telefono_reportante: '3157894561',
    barrio_reportante: 'Barrio Pandiaco',
    tipo_reporte: 'Sospecha de maltrato animal',
    tipo_animal: 'Perro',
    ubicacion_animal: 'Calle 18 # 20-30',
    ciudad_caso: 'San Juan de Pasto',
    fecha_situacion: '2026-10-24',
    descripcion_caso: 'Animal encerrado sin comida',
    acepto_politica: false,
  });
  console.log('Status:', resSinPolitica.status, '| Respuesta:', resSinPolitica.body);
  if (resSinPolitica.status === 400 && (resSinPolitica.body.error || resSinPolitica.body.mensaje || '').includes('datos personales')) {
    console.log('-> PASÓ: Rechazó correctamente el envío sin aceptación de política.');
  } else {
    console.error('-> FALLÓ: No bloqueó el envío sin autorización.');
  }

  // PRUEBA 4: Registro exitoso con todos los campos nuevos y válidos
  console.log('\n[PRUEBA 4] Registro exitoso con calendario, único campo de observaciones y condiciones:');
  const resValido = await request('POST', '/api/denuncias', {}, {
    nombre_reportante: 'Lucía Benavides',
    telefono_reportante: '3206549870',
    ciudad_reportante: 'Pasto',
    barrio_reportante: 'Barrio Maridiaz',
    tipo_reporte: 'Sospecha de maltrato animal',
    tipo_animal: 'Perro',
    ciudad_caso: 'San Juan de Pasto',
    ubicacion_animal: 'Carrera 32 con Calle 19, casa esquinera',
    fecha_situacion: '2026-10-25', // Fecha seleccionada en el calendario
    peligro_inmediato: 'no',
    descripcion_caso: 'Perro en terraza pequeña sin techo adecuado ni agua constante.',
    caracteristicas_animal: 'Mestizo mediano, color café claro, pelaje corto.',
    heridas_visibles: 'Sin heridas visibles aparentes.',
    condiciones_alimentacion: 'Plato vacío de agua bajo el sol.',
    condiciones_lugar: 'Terraza expuesta a la lluvia y el frío.',
    comportamiento_animal: 'Se muestra temeroso pero no agresivo.',
    observaciones_adicionales: 'El animal ladra constantemente durante las noches.',
    acepto_politica: true,
  });
  console.log('Status:', resValido.status, '| Respuesta:', resValido.body);
  if (resValido.status === 201 && resValido.body.radicado) {
    console.log('-> PASÓ: Denuncia registrada exitosamente con radicado:', resValido.body.radicado);
  } else {
    console.error('-> FALLÓ: Registro de denuncia.');
    return;
  }

  const idDenuncia = resValido.body.id_denuncia;

  // PRUEBA 5: Verificación en Base de Datos de Ley 1581 de 2012 y campos de condición
  console.log('\n[PRUEBA 5] Verificación en Base de Datos de columnas Ley 1581 y condiciones:');
  const dbCheck = await pool.query(
    'SELECT id_denuncia, radicado, nombre_reportante, telefono_reportante, condiciones_alimentacion, comportamiento_animal, observaciones_adicionales, acepto_politica, version_politica, fecha_autorizacion, estado_correo FROM denuncia WHERE id_denuncia = $1',
    [idDenuncia]
  );
  const row = dbCheck.rows[0];
  console.log('Registro en DB:', row);
  if (
    row.condiciones_alimentacion === 'Plato vacío de agua bajo el sol.' &&
    row.comportamiento_animal === 'Se muestra temeroso pero no agresivo.' &&
    row.version_politica === 'v1.0' &&
    row.acepto_politica === true &&
    row.fecha_autorizacion != null
  ) {
    console.log('-> PASÓ: Base de datos almacena fielmente las condiciones y la constancia de Ley 1581.');
  } else {
    console.error('-> FALLÓ: No se guardaron correctamente los campos en BD.');
  }

  // PRUEBA 6: Verificación del correo electrónico y destinatario
  console.log('\n[PRUEBA 6] Verificación del estado del correo administrativo:');
  console.log('Destinatario administrativo en .env (GMAIL_USER):', process.env.GMAIL_USER);
  console.log('Estado del correo en DB:', row.estado_correo);
  if (row.estado_correo === 'enviado') {
    console.log('-> PASÓ: Correo enviado satisfactoriamente al administrador configurado.');
  } else {
    console.log('-> Estado de envío registrado:', row.estado_correo);
  }

  // PRUEBA 7: Seguridad de acceso a detalles - Usuario sin autorización
  console.log('\n[PRUEBA 7] Consulta de detalles sin autorización (debe dar 401 o 403):');
  const resNoAuth = await request('GET', `/api/denuncias/${idDenuncia}`);
  console.log('Sin credenciales - Status:', resNoAuth.status);
  const resUserNormal = await request('GET', `/api/denuncias/${idDenuncia}`, {
    'x-usuario-id': normalUser ? normalUser.id_usuario : '00000000-0000-0000-0000-000000000000',
  });
  console.log('Con usuario normal - Status:', resUserNormal.status);
  if ((resNoAuth.status === 401 || resNoAuth.status === 403) && (resUserNormal.status === 401 || resUserNormal.status === 403)) {
    console.log('-> PASÓ: Endpoints protegidos en el backend. Usuario no autorizado es rechazado.');
  } else {
    console.error('-> FALLÓ: Endpoint no protegido adecuadamente.');
  }

  // PRUEBA 8: Seguridad de acceso a detalles - Usuario Administrador
  console.log('\n[PRUEBA 8] Consulta de detalles por el Administrador autorizado (debe retornar 200 con detalle completo):');
  const resAdmin = await request('GET', `/api/denuncias/${idDenuncia}`, {
    'x-usuario-id': admin.id_usuario,
  });
  console.log('Con admin - Status:', resAdmin.status);
  if (resAdmin.status === 200 && resAdmin.body.radicado === row.radicado) {
    console.log('-> PASÓ: Administrador accede a todos los detalles de la denuncia correctamente.');
    console.log('Campos devueltos:', {
      radicado: resAdmin.body.radicado,
      reportante: resAdmin.body.nombre_reportante,
      telefono: resAdmin.body.telefono_reportante,
      condiciones_alimentacion: resAdmin.body.condiciones_alimentacion,
      version_politica: resAdmin.body.version_politica,
    });
  } else {
    console.error('-> FALLÓ: Administrador no pudo consultar la denuncia.');
  }

  console.log('\n--- FIN DE PRUEBAS ---');
  await pool.end();
}

runTests().catch((e) => {
  console.error('Error durante las pruebas:', e);
  process.exit(1);
});
