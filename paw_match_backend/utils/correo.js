const nodemailer = require('nodemailer');

let testTransporter = null;

function escaparHtml(texto) {
  return String(texto ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

async function obtenerTransporter() {
  // 1. Soporte directo para Gmail con contraseña de aplicación de Google
  if (process.env.GMAIL_USER && process.env.GMAIL_PASS && process.env.GMAIL_USER.trim() && process.env.GMAIL_PASS.trim()) {
    return {
      transporter: nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: process.env.GMAIL_USER.trim(),
          pass: process.env.GMAIL_PASS.replace(/\s+/g, ''),
        },
      }),
      remitente: process.env.SMTP_FROM || process.env.GMAIL_USER.trim(),
      tipo: 'gmail',
    };
  }

  // 2. Soporte estándar SMTP (Outlook, Mailgun, Sendgrid, etc.)
  if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS && process.env.SMTP_HOST.trim()) {
    const port = Number(process.env.SMTP_PORT) || 587;
    return {
      transporter: nodemailer.createTransport({
        host: process.env.SMTP_HOST.trim(),
        port: port,
        secure: port === 465,
        auth: {
          user: process.env.SMTP_USER.trim(),
          pass: process.env.SMTP_PASS.trim(),
        },
      }),
      remitente: process.env.SMTP_FROM || process.env.SMTP_USER.trim(),
      tipo: 'smtp',
    };
  }

  // 3. Fallback inteligente: Ethereal Email para pruebas locales (genera URL web para ver el correo)
  try {
    if (!testTransporter) {
      console.log('[CORREO] No se detectaron credenciales en .env. Creando buzón de pruebas Ethereal...');
      const testAccount = await nodemailer.createTestAccount();
      testTransporter = {
        transporter: nodemailer.createTransport({
          host: testAccount.smtp.host,
          port: testAccount.smtp.port,
          secure: testAccount.smtp.secure,
          auth: {
            user: testAccount.user,
            pass: testAccount.pass,
          },
        }),
        remitente: `"Paw Match Notificaciones" <${testAccount.user}>`,
        tipo: 'ethereal',
      };
      console.log(`[CORREO] Cuenta de prueba lista: ${testAccount.user}`);
    }
    return testTransporter;
  } catch (err) {
    console.warn('[CORREO] No se pudo crear cuenta de prueba Ethereal:', err.message);
    return null;
  }
}

/**
 * Notifica al usuario que su solicitud de apadrinamiento ha sido aprobada.
 */
async function enviarCorreoAprobacionApadrinamiento({
  destinatario,
  nombreUsuario,
  nombreMascota,
  fechaInicio,
  whatsappFundacion = '573136177747',
  observaciones,
}) {
  const nombre = escaparHtml(nombreUsuario);
  const mascota = escaparHtml(nombreMascota);
  const inicio = escaparHtml(fechaInicio || 'Inmediata');
  const nota = observaciones ? escaparHtml(observaciones) : '';

  const asunto = `¡Tu solicitud para apadrinar a ${nombreMascota} ha sido aprobada! 🎉 - Paw Match`;

  const textoPlano = `
Hola ${nombreUsuario},

¡Tenemos excelentes noticias! Tu solicitud para apadrinar a ${nombreMascota} ha sido APROBADA por la Fundación Maritza Arévalo.

Detalles del apadrinamiento:
- Mascota apadrinada: ${nombreMascota}
- Fecha oficial de inicio: ${fechaInicio || 'Inmediata'}
${observaciones ? `- Observaciones de la fundación: ${observaciones}\n` : ''}

IMPORTANTE:
Para continuar con el proceso y formalizar tu apadrinamiento, debes ponerte en contacto directamente con la Fundación Maritza Arévalo para coordinar los últimos requerimientos y compromisos.

Canales de contacto oficial:
- WhatsApp oficial: +${whatsappFundacion} (enlace: https://wa.me/${whatsappFundacion})
- App Paw Match: Inicia sesión para consultar el estado y la información oficial de tu apadrinamiento.

¡Gracias por tu amor, compromiso y apoyo para con nuestros perritos rescatados!

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match
`;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 22px; border: 1px solid #ffccd5; border-radius: 14px; background-color: #fffafb;">
      <div style="text-align: center; margin-bottom: 22px;">
        <h1 style="color: #e91e63; margin-bottom: 6px; font-size: 24px;">¡Solicitud de Apadrinamiento Aprobada! 🎉</h1>
        <p style="color: #666; font-size: 15px; margin: 0;">Fundación Maritza Arévalo • Paw Match</p>
      </div>
      
      <div style="background-color: #ffffff; padding: 24px; border-radius: 12px; border: 1px solid #f2e2e6; box-shadow: 0 2px 6px rgba(0,0,0,0.03);">
        <p style="font-size: 16px; color: #333; margin-top: 0;">Hola <strong>${nombre}</strong>,</p>
        <p style="font-size: 15px; color: #444; line-height: 1.5;">
          Nos complace informarte que tu solicitud para apadrinar a <strong>${mascota}</strong> ha sido <span style="color: #2e7d32; font-weight: bold; background-color: #e8f5e9; padding: 2px 8px; border-radius: 4px;">APROBADA</span> exitosamente.
        </p>
        
        <div style="background-color: #fce4ec; padding: 14px 18px; border-radius: 10px; margin: 20px 0;">
          <p style="margin: 4px 0; color: #880e4f; font-size: 15px;"><strong>🐾 Mascota apadrinada:</strong> ${mascota}</p>
          <p style="margin: 4px 0; color: #880e4f; font-size: 15px;"><strong>📅 Fecha oficial de inicio:</strong> ${inicio}</p>
          ${nota ? `<p style="margin: 8px 0 4px 0; color: #0d47a1; font-size: 14px; background-color: #e3f2fd; padding: 8px 12px; border-radius: 6px;"><strong>📝 Observaciones de la fundación:</strong> ${nota}</p>` : ''}
        </div>

        <div style="background-color: #fff3e0; border-left: 4px solid #ff9800; padding: 12px 16px; border-radius: 6px; margin: 18px 0;">
          <p style="margin: 0; color: #e65100; font-size: 14px; line-height: 1.5;">
            <strong>⚠️ Paso indispensable:</strong> Debes contactarte directamente con la fundación para revisar y acordar los <strong>últimos requerimientos y compromisos oficiales</strong> para el cuidado de la mascota.
          </p>
        </div>

        <p style="font-size: 14px; color: #555; line-height: 1.5;">
          Puedes coordinar todos los detalles de inmediato escribiéndonos por WhatsApp o consultando tu solicitud en la aplicación <strong>Paw Match</strong>.
        </p>
        
        <div style="text-align: center; margin-top: 25px; margin-bottom: 12px;">
          <a href="https://wa.me/${whatsappFundacion}?text=${encodeURIComponent(`Hola Fundación Maritza Arévalo, mi solicitud para apadrinar a ${nombreMascota} fue aprobada en Paw Match y quiero coordinar los últimos detalles.`)}" 
             style="background-color: #25d366; color: white; padding: 14px 28px; text-decoration: none; font-weight: bold; border-radius: 25px; display: inline-block; font-size: 15px; box-shadow: 0 4px 10px rgba(37,211,102,0.3);">
            💬 Contactar por WhatsApp a la Fundación
          </a>
        </div>
      </div>
      
      <p style="text-align: center; font-size: 12px; color: #999; margin-top: 20px;">
        Este es un correo automático generado por Paw Match para la Fundación Maritza Arévalo (San Juan de Pasto).
      </p>
    </div>
  `;

  return enviarEmailGenerico({
    destinatario,
    asunto,
    textoPlano,
    html,
    tipoNotificacion: `Aprobación apadrinamiento (${nombreMascota})`,
  });
}

/**
 * Notifica al usuario que su solicitud de apadrinamiento fue rechazada.
 */
async function enviarCorreoRechazoApadrinamiento({
  destinatario,
  nombreUsuario,
  nombreMascota,
  whatsappFundacion = '573136177747',
  observaciones,
}) {
  const nombre = escaparHtml(nombreUsuario);
  const mascota = escaparHtml(nombreMascota);
  const nota = observaciones ? escaparHtml(observaciones) : '';

  const asunto = `Información sobre tu solicitud de apadrinamiento para ${nombreMascota} - Paw Match`;

  const textoPlano = `
Hola ${nombreUsuario},

Agradecemos profundamente tu interés y el amor que demostraste al postularte para apadrinar a ${nombreMascota} en la Fundación Maritza Arévalo.

Queremos informarte que, tras evaluar las solicitudes recibidas y los requerimientos del refugio, en esta ocasión tu solicitud no ha podido ser aprobada.

${observaciones ? `Motivo u observaciones de la fundación:\n${observaciones}\n\n` : ''}
¡No te desanimes! Aún hay muchos otros peluditos en Paw Match que esperan por un padrino o una familia. Te invitamos a ingresar a la aplicación para conocer a otros compañeros que necesitan de tu apoyo.

Si tienes dudas o deseas más detalles, puedes escribirnos por WhatsApp:
- WhatsApp oficial: +${whatsappFundacion} (enlace: https://wa.me/${whatsappFundacion})

¡Gracias por tu empatía y compromiso con el bienestar animal!

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match
`;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 22px; border: 1px solid #ffd1d9; border-radius: 14px; background-color: #fffafb;">
      <div style="text-align: center; margin-bottom: 22px;">
        <h2 style="color: #c2185b; margin-bottom: 6px; font-size: 22px;">Respuesta a tu Solicitud de Apadrinamiento</h2>
        <p style="color: #666; font-size: 15px; margin: 0;">Fundación Maritza Arévalo • Paw Match</p>
      </div>

      <div style="background-color: #ffffff; padding: 24px; border-radius: 12px; border: 1px solid #f2e2e6; box-shadow: 0 2px 6px rgba(0,0,0,0.03);">
        <p style="font-size: 16px; color: #333; margin-top: 0;">Hola <strong>${nombre}</strong>,</p>
        <p style="font-size: 15px; color: #444; line-height: 1.5;">
          Agradecemos de corazón tu interés y la noble intención de querer apoyar a <strong>${mascota}</strong> a través de nuestro programa de apadrinamiento.
        </p>
        <p style="font-size: 15px; color: #444; line-height: 1.5;">
          Queremos informarte que, tras evaluar cuidadosamente las solicitudes recibidas y las necesidades de la fundación, en esta ocasión tu solicitud <span style="color: #c62828; font-weight: bold; background-color: #ffebee; padding: 2px 8px; border-radius: 4px;">NO HA SIDO APROBADA</span>.
        </p>

        ${nota ? `
        <div style="background-color: #fff8e1; border-left: 4px solid #ffb300; padding: 14px 16px; border-radius: 6px; margin: 18px 0;">
          <p style="margin: 0 0 6px 0; color: #f57f17; font-weight: bold; font-size: 14px;">Motivo / Observaciones de la Fundación:</p>
          <p style="margin: 0; color: #5d4037; font-size: 14px; line-height: 1.45;">${nota}</p>
        </div>
        ` : ''}

        <div style="background-color: #fce4ec; padding: 14px 18px; border-radius: 10px; margin: 18px 0;">
          <p style="margin: 0; color: #880e4f; font-size: 14px; line-height: 1.5;">
            🐾 <strong>¡Tu ayuda sigue siendo muy valiosa!</strong> En la Fundación aún tenemos muchos otros perritos rescatados esperando por un padrino solidario o una segunda oportunidad. Te animamos a seguir explorando la app <strong>Paw Match</strong>.
          </p>
        </div>

        <p style="font-size: 14px; color: #555; line-height: 1.5;">
          Si deseas conocer más información o tienes alguna consulta, puedes escribirnos con confianza a nuestra línea de atención:
        </p>

        <div style="text-align: center; margin-top: 22px; margin-bottom: 10px;">
          <a href="https://wa.me/${whatsappFundacion}" 
             style="background-color: #25d366; color: white; padding: 13px 26px; text-decoration: none; font-weight: bold; border-radius: 25px; display: inline-block; font-size: 14px;">
            💬 Contactar por WhatsApp a la Fundación
          </a>
        </div>
      </div>

      <p style="text-align: center; font-size: 12px; color: #999; margin-top: 20px;">
        Este es un correo informativo generado por Paw Match para la Fundación Maritza Arévalo (San Juan de Pasto).
      </p>
    </div>
  `;

  return enviarEmailGenerico({
    destinatario,
    asunto,
    textoPlano,
    html,
    tipoNotificacion: `Rechazo apadrinamiento (${nombreMascota})`,
  });
}

/**
 * Función centralizada y segura para el despacho de correos.
 */
async function enviarEmailGenerico({ destinatario, asunto, textoPlano, html, tipoNotificacion }) {
  if (!destinatario || !destinatario.includes('@')) {
    console.warn(`[CORREO ERROR] Destinatario no válido: '${destinatario}'`);
    return { enviado: false, error: 'Correo no válido' };
  }

  const transportInfo = await obtenerTransporter();

  if (transportInfo && transportInfo.transporter) {
    try {
      const remitente = transportInfo.remitente || `"Fundación Maritza Arévalo - Paw Match" <no-reply@pawmatch.com>`;
      const info = await transportInfo.transporter.sendMail({
        from: remitente.includes('<') ? remitente : `"Fundación Maritza Arévalo - Paw Match" <${remitente}>`,
        to: destinatario,
        subject: asunto,
        text: textoPlano,
        html: html,
      });

      console.log(`[CORREO ENVIADO] (${tipoNotificacion}) a ${destinatario} [Servicio: ${transportInfo.tipo}]`);

      // Si fue Ethereal, mostrar URL de previsualización web en terminal
      if (transportInfo.tipo === 'ethereal') {
        const urlPreview = nodemailer.getTestMessageUrl(info);
        console.log(`[CORREO VISTA PREVIA WEB]: ${urlPreview}`);
      }

      return { enviado: true, messageId: info.messageId };
    } catch (error) {
      console.error(`[CORREO ERROR] Falló envío a ${destinatario}:`, error.message);
      return { enviado: false, error: error.message };
    }
  } else {
    console.log(`[CORREO SIMULADO] Destinatario: ${destinatario}`);
    console.log(`  Asunto: ${asunto}`);
    console.log('  (Configura GMAIL_USER y GMAIL_PASS en .env para envíos reales)');
    return { enviado: true, simulado: true };
  }
}

/**
 * Notifica al usuario que su solicitud de adopción ha sido aprobada.
 * Misma estructura que el correo de aprobación de apadrinamiento.
 */
async function enviarCorreoAprobacionAdopcion({
  destinatario,
  nombreUsuario,
  nombreMascota,
  fechaInicio,
  whatsappFundacion = '573136177747',
  observaciones,
}) {
  const nombre = escaparHtml(nombreUsuario);
  const mascota = escaparHtml(nombreMascota);
  const inicio = escaparHtml(fechaInicio || 'Inmediata');
  const nota = observaciones ? escaparHtml(observaciones) : '';

  const asunto = `¡Tu solicitud para adoptar a ${nombreMascota} ha sido aprobada! 🎉 - Paw Match`;

  const textoPlano = `
Hola ${nombreUsuario},

¡Tenemos excelentes noticias! Tu solicitud para adoptar a ${nombreMascota} ha sido APROBADA por la Fundación Maritza Arévalo.

Detalles de la adopción:
- Mascota adoptada: ${nombreMascota}
- Fecha oficial de inicio: ${fechaInicio || 'Inmediata'}
${observaciones ? `- Observaciones de la fundación: ${observaciones}\n` : ''}

ESTADO DEL CONTRATO:
Tu adopción quedó aprobada, pero el contrato oficial aún no está cargado. En Mis adopciones verás el estado "Pendiente subir contrato de adopción". Cuando el administrador lo suba, te avisaremos por correo y en la app para que puedas verlo y descargarlo.

IMPORTANTE:
Para continuar con el proceso y coordinar la entrega, debes ponerte en contacto directamente con la Fundación Maritza Arévalo para revisar los últimos requerimientos.

Canales de contacto oficial:
- WhatsApp oficial: +${whatsappFundacion} (enlace: https://wa.me/${whatsappFundacion})
- App Paw Match: Inicia sesión y abre Mis adopciones para consultar el estado y las observaciones.

¡Gracias por abrir tu hogar a uno de nuestros perritos rescatados!

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match
`;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 22px; border: 1px solid #ffccd5; border-radius: 14px; background-color: #fffafb;">
      <div style="text-align: center; margin-bottom: 22px;">
        <h1 style="color: #e91e63; margin-bottom: 6px; font-size: 24px;">¡Solicitud de Adopción Aprobada! 🎉</h1>
        <p style="color: #666; font-size: 15px; margin: 0;">Fundación Maritza Arévalo • Paw Match</p>
      </div>

      <div style="background-color: #ffffff; padding: 24px; border-radius: 12px; border: 1px solid #f2e2e6; box-shadow: 0 2px 6px rgba(0,0,0,0.03);">
        <p style="font-size: 16px; color: #333; margin-top: 0;">Hola <strong>${nombre}</strong>,</p>
        <p style="font-size: 15px; color: #444; line-height: 1.5;">
          Nos complace informarte que tu solicitud para adoptar a <strong>${mascota}</strong> ha sido <span style="color: #2e7d32; font-weight: bold; background-color: #e8f5e9; padding: 2px 8px; border-radius: 4px;">APROBADA</span> exitosamente.
        </p>

        <div style="background-color: #fce4ec; padding: 14px 18px; border-radius: 10px; margin: 20px 0;">
          <p style="margin: 4px 0; color: #880e4f; font-size: 15px;"><strong>🐾 Mascota adoptada:</strong> ${mascota}</p>
          <p style="margin: 4px 0; color: #880e4f; font-size: 15px;"><strong>📅 Fecha oficial de inicio:</strong> ${inicio}</p>
          ${nota ? `<p style="margin: 8px 0 4px 0; color: #0d47a1; font-size: 14px; background-color: #e3f2fd; padding: 8px 12px; border-radius: 6px;"><strong>📝 Observaciones de la fundación:</strong> ${nota}</p>` : ''}
        </div>

        <div style="background-color: #fff8e1; border-left: 4px solid #f9a825; padding: 12px 16px; border-radius: 6px; margin: 18px 0;">
          <p style="margin: 0; color: #f57f17; font-size: 14px; line-height: 1.5;">
            <strong>📄 Pendiente subir contrato de adopción.</strong> Cuando el administrador cargue el contrato firmado, te avisaremos por correo y en la app para que puedas verlo y descargarlo en <strong>Mis adopciones</strong>.
          </p>
        </div>

        <div style="background-color: #fff3e0; border-left: 4px solid #ff9800; padding: 12px 16px; border-radius: 6px; margin: 18px 0;">
          <p style="margin: 0; color: #e65100; font-size: 14px; line-height: 1.5;">
            <strong>⚠️ Paso indispensable:</strong> Debes contactarte directamente con la fundación para coordinar la <strong>entrega y los últimos requisitos</strong> de la adopción.
          </p>
        </div>

        <p style="font-size: 14px; color: #555; line-height: 1.5;">
          Puedes coordinar todos los detalles de inmediato escribiéndonos por WhatsApp o consultando tu solicitud en <strong>Mis adopciones</strong> dentro de Paw Match.
        </p>

        <div style="text-align: center; margin-top: 25px; margin-bottom: 12px;">
          <a href="https://wa.me/${whatsappFundacion}?text=${encodeURIComponent(`Hola Fundación Maritza Arévalo, mi solicitud para adoptar a ${nombreMascota} fue aprobada en Paw Match y quiero coordinar la entrega.`)}"
             style="background-color: #25d366; color: white; padding: 14px 28px; text-decoration: none; font-weight: bold; border-radius: 25px; display: inline-block; font-size: 15px; box-shadow: 0 4px 10px rgba(37,211,102,0.3);">
            💬 Contactar por WhatsApp a la Fundación
          </a>
        </div>
      </div>

      <p style="text-align: center; font-size: 12px; color: #999; margin-top: 20px;">
        Este es un correo automático generado por Paw Match para la Fundación Maritza Arévalo (San Juan de Pasto).
      </p>
    </div>
  `;

  return enviarEmailGenerico({
    destinatario,
    asunto,
    textoPlano,
    html,
    tipoNotificacion: `Aprobación adopción (${nombreMascota})`,
  });
}

/**
 * Notifica al usuario que su solicitud de adopción fue rechazada.
 * Misma estructura que el correo de rechazo de apadrinamiento.
 */
async function enviarCorreoRechazoAdopcion({
  destinatario,
  nombreUsuario,
  nombreMascota,
  whatsappFundacion = '573136177747',
  observaciones,
}) {
  const nombre = escaparHtml(nombreUsuario);
  const mascota = escaparHtml(nombreMascota);
  const nota = observaciones ? escaparHtml(observaciones) : '';

  const asunto = `Información sobre tu solicitud de adopción para ${nombreMascota} - Paw Match`;

  const textoPlano = `
Hola ${nombreUsuario},

Agradecemos profundamente tu interés y el amor que demostraste al postularte para adoptar a ${nombreMascota} en la Fundación Maritza Arévalo.

Queremos informarte que, tras evaluar las solicitudes recibidas y los requerimientos del refugio, en esta ocasión tu solicitud no ha podido ser aprobada.

${observaciones ? `Motivo u observaciones de la fundación:\n${observaciones}\n\n` : ''}
¡No te desanimes! Aún hay muchos otros peluditos en Paw Match que esperan una familia. Te invitamos a ingresar a la aplicación para conocer a otros compañeros.

Si tienes dudas o deseas más detalles, puedes escribirnos por WhatsApp:
- WhatsApp oficial: +${whatsappFundacion} (enlace: https://wa.me/${whatsappFundacion})

¡Gracias por tu empatía y compromiso con el bienestar animal!

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match
`;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 22px; border: 1px solid #ffd1d9; border-radius: 14px; background-color: #fffafb;">
      <div style="text-align: center; margin-bottom: 22px;">
        <h2 style="color: #c2185b; margin-bottom: 6px; font-size: 22px;">Respuesta a tu Solicitud de Adopción</h2>
        <p style="color: #666; font-size: 15px; margin: 0;">Fundación Maritza Arévalo • Paw Match</p>
      </div>

      <div style="background-color: #ffffff; padding: 24px; border-radius: 12px; border: 1px solid #f2e2e6; box-shadow: 0 2px 6px rgba(0,0,0,0.03);">
        <p style="font-size: 16px; color: #333; margin-top: 0;">Hola <strong>${nombre}</strong>,</p>
        <p style="font-size: 15px; color: #444; line-height: 1.5;">
          Agradecemos de corazón tu interés y la noble intención de querer darle un hogar a <strong>${mascota}</strong>.
        </p>
        <p style="font-size: 15px; color: #444; line-height: 1.5;">
          Queremos informarte que, tras evaluar cuidadosamente las solicitudes recibidas y las necesidades de la fundación, en esta ocasión tu solicitud <span style="color: #c62828; font-weight: bold; background-color: #ffebee; padding: 2px 8px; border-radius: 4px;">NO HA SIDO APROBADA</span>.
        </p>

        ${nota ? `
        <div style="background-color: #fff8e1; border-left: 4px solid #ffb300; padding: 14px 16px; border-radius: 6px; margin: 18px 0;">
          <p style="margin: 0 0 6px 0; color: #f57f17; font-weight: bold; font-size: 14px;">Motivo / Observaciones de la Fundación:</p>
          <p style="margin: 0; color: #5d4037; font-size: 14px; line-height: 1.45;">${nota}</p>
        </div>
        ` : ''}

        <div style="background-color: #fce4ec; padding: 14px 18px; border-radius: 10px; margin: 18px 0;">
          <p style="margin: 0; color: #880e4f; font-size: 14px; line-height: 1.5;">
            🐾 <strong>¡Tu ayuda sigue siendo muy valiosa!</strong> En la Fundación aún tenemos muchos otros perritos rescatados esperando una familia. Te animamos a seguir explorando la app <strong>Paw Match</strong>.
          </p>
        </div>

        <p style="font-size: 14px; color: #555; line-height: 1.5;">
          Si deseas conocer más información o tienes alguna consulta, puedes escribirnos con confianza a nuestra línea de atención. También puedes ver esta respuesta en <strong>Mis adopciones</strong>.
        </p>

        <div style="text-align: center; margin-top: 22px; margin-bottom: 10px;">
          <a href="https://wa.me/${whatsappFundacion}"
             style="background-color: #25d366; color: white; padding: 13px 26px; text-decoration: none; font-weight: bold; border-radius: 25px; display: inline-block; font-size: 14px;">
            💬 Contactar por WhatsApp a la Fundación
          </a>
        </div>
      </div>

      <p style="text-align: center; font-size: 12px; color: #999; margin-top: 20px;">
        Este es un correo informativo generado por Paw Match para la Fundación Maritza Arévalo (San Juan de Pasto).
      </p>
    </div>
  `;

  return enviarEmailGenerico({
    destinatario,
    asunto,
    textoPlano,
    html,
    tipoNotificacion: `Rechazo adopción (${nombreMascota})`,
  });
}

/**
 * Avisa al adoptante que el administrador ya cargó el contrato y puede consultarlo.
 */
async function enviarCorreoContratoAdopcion({
  destinatario,
  nombreUsuario,
  nombreMascota,
  whatsappFundacion = '573136177747',
}) {
  const nombre = escaparHtml(nombreUsuario);
  const mascota = escaparHtml(nombreMascota);
  const asunto = `Tu contrato de adopción de ${nombreMascota} ya está disponible - Paw Match`;

  const textoPlano = `
Hola ${nombreUsuario},

El administrador de la Fundación Maritza Arévalo ya cargó el contrato de adopción firmado de ${nombreMascota}.

Ya puedes verlo y descargarlo en Paw Match:
- Abre la app e inicia sesión.
- Entra a Mis adopciones.
- En la solicitud de ${nombreMascota} pulsa «Ver y descargar contrato».

Si tienes dudas sobre la entrega, escríbenos por WhatsApp: +${whatsappFundacion} (https://wa.me/${whatsappFundacion}).

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match
`;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 22px; border: 1px solid #c8e6c9; border-radius: 14px; background-color: #f8fff9;">
      <div style="text-align: center; margin-bottom: 22px;">
        <h1 style="color: #2e7d32; margin-bottom: 6px; font-size: 24px;">Tu contrato de adopción ya está disponible</h1>
        <p style="color: #666; font-size: 15px; margin: 0;">Fundación Maritza Arévalo • Paw Match</p>
      </div>
      <div style="background-color: #ffffff; padding: 24px; border-radius: 12px; border: 1px solid #e8f5e9;">
        <p style="font-size: 16px; color: #333; margin-top: 0;">Hola <strong>${nombre}</strong>,</p>
        <p style="font-size: 15px; color: #444; line-height: 1.5;">
          El administrador ya cargó el contrato de adopción firmado de <strong>${mascota}</strong>. Puedes verlo y descargarlo desde <strong>Mis adopciones</strong> en Paw Match.
        </p>
        <div style="background-color: #e8f5e9; padding: 14px 18px; border-radius: 10px; margin: 20px 0;">
          <p style="margin: 4px 0; color: #1b5e20; font-size: 15px;"><strong>🐾 Mascota:</strong> ${mascota}</p>
          <p style="margin: 4px 0; color: #1b5e20; font-size: 15px;"><strong>📄 Estado del contrato:</strong> Disponible para ver y descargar</p>
        </div>
        <p style="font-size: 14px; color: #555; line-height: 1.5;">
          En la solicitud aprobada pulsa <strong>Ver y descargar contrato</strong>. Si necesitas coordinar la entrega, también puedes escribirnos por WhatsApp.
        </p>
        <div style="text-align: center; margin-top: 25px; margin-bottom: 12px;">
          <a href="https://wa.me/${whatsappFundacion}?text=${encodeURIComponent(`Hola Fundación Maritza Arévalo, ya puedo ver el contrato de adopción de ${nombreMascota} en Paw Match y quiero coordinar la entrega.`)}"
             style="background-color: #25d366; color: white; padding: 14px 28px; text-decoration: none; font-weight: bold; border-radius: 25px; display: inline-block; font-size: 15px;">
            💬 Contactar por WhatsApp a la Fundación
          </a>
        </div>
      </div>
      <p style="text-align: center; font-size: 12px; color: #999; margin-top: 20px;">
        Este es un correo automático generado por Paw Match para la Fundación Maritza Arévalo (San Juan de Pasto).
      </p>
    </div>
  `;

  return enviarEmailGenerico({
    destinatario,
    asunto,
    textoPlano,
    html,
    tipoNotificacion: `Contrato de adopción disponible (${nombreMascota})`,
  });
}

/**
 * Envía correo con enlace de verificación para solicitudes de apadrinamiento o adopción.
 */
async function enviarCorreoVerificacionSolicitud({
  destinatario,
  nombreUsuario,
  nombreMascota,
  token,
  tipo = 'apadrinamiento',
}) {
  const nombre = escaparHtml(nombreUsuario);
  const mascota = escaparHtml(nombreMascota);
  const esApadrinamiento = tipo === 'apadrinamiento';
  const accionTexto = esApadrinamiento ? 'apadrinamiento' : 'adopción';
  const asunto = `Confirma tu correo para tu solicitud de ${accionTexto} de ${nombreMascota} - Paw Match`;

  const backendHost = process.env.BACKEND_URL || `http://localhost:${process.env.PORT || 3000}`;
  const rutaVerificar = esApadrinamiento
    ? '/api/solicitudes-apadrinamiento/verificar-correo'
    : '/api/adoption-requests/verificar-correo';
  const urlVerificacion = `${backendHost}${rutaVerificar}?token=${encodeURIComponent(token)}`;

  const textoPlano = `
Hola ${nombreUsuario},

Gracias por tu solicitud de ${accionTexto} para ${nombreMascota} en la Fundación Maritza Arévalo.

Para que tu solicitud sea revisada por el administrador y puedas recibir notificaciones oficiales sobre su estado, debes confirmar tu correo electrónico haciendo clic en el siguiente enlace:

${urlVerificacion}

Mientras no confirmes tu correo, tu solicitud se mostrará en Paw Match con el estado "Correo pendiente de confirmación".
Una vez confirmado, el estado cambiará inmediatamente a "Correo confirmado".

Si no realizaste esta solicitud, puedes ignorar este mensaje.

Fundación Maritza Arévalo
Paw Match
`;

  const html = `
    <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e5e7eb; border-radius: 14px; background-color: #ffffff;">
      <div style="text-align: center; margin-bottom: 20px;">
        <h1 style="color: #ec4899; margin: 0; font-size: 26px; font-weight: 800; letter-spacing: -0.5px;">🐾 Paw Match</h1>
        <p style="color: #6b7280; font-size: 13px; margin: 4px 0 0 0;">Fundación Maritza Arévalo • San Juan de Pasto</p>
      </div>
      <div style="background-color: #fdf2f8; border: 1px solid #fbcfe8; border-radius: 12px; padding: 20px; margin-bottom: 20px;">
        <h2 style="color: #9d174d; margin-top: 0; font-size: 18px; font-weight: 700;">
          ✉️ Confirmación de correo electrónico requerida
        </h2>
        <p style="font-size: 14px; color: #374151; line-height: 1.5; margin-bottom: 12px;">
          Hola <strong>${nombre}</strong>,
        </p>
        <p style="font-size: 14px; color: #374151; line-height: 1.5; margin-bottom: 12px;">
          Hemos recibido tu solicitud de <strong>${accionTexto}</strong> para <strong>${mascota}</strong>.
          Para garantizar la seguridad de tus datos y que puedas recibir las notificaciones oficiales con respecto a tu solicitud, por favor confirma tu correo electrónico:
        </p>
        <div style="text-align: center; margin: 26px 0;">
          <a href="${urlVerificacion}" target="_blank"
             style="background: linear-gradient(135deg, #ec4899 0%, #db2777 100%); color: #ffffff; padding: 14px 28px; text-decoration: none; font-weight: bold; border-radius: 12px; display: inline-block; font-size: 15px; box-shadow: 0 4px 10px rgba(236,72,153,0.3);">
            ✅ Confirmar mi correo electrónico
          </a>
        </div>
        <p style="font-size: 12.5px; color: #6b7280; line-height: 1.4; margin-top: 16px;">
          <strong>Estado actual:</strong> <em>Correo pendiente de confirmación</em>.<br/>
          Al hacer clic en el botón superior, tu estado se actualizará automáticamente a <strong>«Correo confirmado»</strong> en la plataforma.
        </p>
        <div style="margin-top: 14px; padding-top: 12px; border-top: 1px dashed #fbcfe8;">
          <p style="font-size: 11px; color: #9ca3af; margin: 0; word-break: break-all;">
            Si el botón no funciona, copia y pega este enlace en tu navegador:<br/>
            <a href="${urlVerificacion}" style="color: #db2777;">${urlVerificacion}</a>
          </p>
        </div>
      </div>
      <p style="text-align: center; font-size: 11.5px; color: #9ca3af; margin-top: 20px;">
        Este es un correo automático de verificación emitido por Paw Match para la Fundación Maritza Arévalo.
      </p>
    </div>
  `;

  return enviarEmailGenerico({
    destinatario,
    asunto,
    textoPlano,
    html,
    tipoNotificacion: `Verificación de correo (${accionTexto} ${nombreMascota})`,
  });
}

/**
 * Notifica al correo administrativo configurado en .env que se ha recibido una nueva denuncia.
 * Cumple estrictamente con la privacidad de datos personales y los lineamientos de la Fundación Maritza Arévalo.
 */
async function enviarCorreoNuevaDenunciaAdmin({
  destinatarios,
  denuncia = {},
  urlPanel,
}) {
  const radicado = escaparHtml(denuncia.radicado || 'DEN-RECIBIDA');
  const asunto = `Nueva denuncia recibida – Fundación Maritza Arévalo`;

  const textoPlano = `
Se ha recibido una nueva denuncia de posible maltrato animal en la plataforma de la Fundación Maritza Arévalo.

Para consultar la información completa del caso, los datos del reporte, las evidencias y la información de contacto del denunciante, ingresa a la aplicación e inicia sesión con tu cuenta autorizada.

Por motivos de privacidad y protección de datos personales, los detalles de la denuncia no se incluyen en este correo.

Por favor, revisa el caso desde el panel administrativo y realiza el seguimiento correspondiente.

Fundación Maritza Arévalo – Protección y bienestar animal.
`.trim();

  const html = `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #ffd1d9; border-radius: 16px; background-color: #fffafb;">
      <div style="text-align: center; margin-bottom: 22px;">
        <div style="display: inline-block; background-color: #fce4ec; padding: 8px 18px; border-radius: 20px; margin-bottom: 12px;">
          <span style="color: #ed4f9d; font-weight: 800; font-size: 13px; letter-spacing: 0.5px;">
            🐾 FUNDACIÓN MARITZA ARÉVALO
          </span>
        </div>
        <h2 style="color: #2e2a2c; margin: 0 0 6px 0; font-size: 22px; font-weight: 800;">
          Nueva denuncia recibida
        </h2>
        <div style="font-size: 13.5px; color: #888; font-weight: 600;">Radicado: <span style="color: #ed4f9d;">${radicado}</span></div>
      </div>

      <div style="background-color: #ffffff; padding: 24px; border-radius: 14px; border: 1px solid #f2e2e6; box-shadow: 0 2px 8px rgba(0,0,0,0.03);">
        <p style="font-size: 15px; color: #333; line-height: 1.6; margin-top: 0;">
          Se ha recibido una nueva denuncia de posible maltrato animal en la plataforma de la <strong>Fundación Maritza Arévalo</strong>.
        </p>
        
        <p style="font-size: 14.5px; color: #444; line-height: 1.6;">
          Para consultar la información completa del caso, los datos del reporte, las evidencias y la información de contacto del denunciante, ingresa a la aplicación e inicia sesión con tu cuenta autorizada.
        </p>

        <div style="background-color: #fff3e0; border-left: 4px solid #ff9800; padding: 12px 16px; border-radius: 6px; margin: 18px 0;">
          <p style="margin: 0; color: #e65100; font-size: 13px; line-height: 1.5;">
            🔒 <strong>Protección de datos personales:</strong> Por motivos de privacidad y protección de datos personales, los detalles de la denuncia no se incluyen en este correo.
          </p>
        </div>

        <p style="font-size: 14px; color: #555; line-height: 1.5;">
          Por favor, revisa el caso desde el panel administrativo y realiza el seguimiento correspondiente.
        </p>

        <div style="text-align: center; margin: 24px 0 10px 0;">
          <a href="${urlPanel || 'http://localhost:3000'}" target="_blank"
             style="background: #ed4f9d; color: #ffffff; padding: 12px 28px; text-decoration: none; font-weight: 700; border-radius: 22px; display: inline-block; font-size: 14px;">
            Ir al Panel Administrativo
          </a>
        </div>
      </div>

      <p style="text-align: center; font-size: 12.5px; color: #666; margin-top: 20px; font-weight: 600;">
        Fundación Maritza Arévalo – Protección y bienestar animal.
      </p>
    </div>
  `;

  const correoAdminConfigurado = process.env.ADMIN_EMAIL || process.env.GMAIL_USER;
  const correosBase = (destinatarios && (!Array.isArray(destinatarios) || destinatarios.length > 0))
    ? destinatarios
    : [correoAdminConfigurado];
  const lista = Array.isArray(correosBase) ? correosBase : [correosBase];
  const resultados = [];
  for (const correo of lista) {
    if (correo && correo.includes('@')) {
      const res = await enviarEmailGenerico({
        destinatario: correo,
        asunto,
        textoPlano,
        html,
        tipoNotificacion: `Nueva denuncia (${radicado})`,
      });
      resultados.push({ correo, ...res });
    }
  }

  const exito = resultados.some(r => r.enviado);
  return {
    enviado: exito,
    resultados,
    error: exito ? null : (resultados[0]?.error || 'No se pudo enviar al correo configurado'),
  };
}

module.exports = {
  enviarCorreoAprobacionApadrinamiento,
  enviarCorreoRechazoApadrinamiento,
  enviarCorreoAprobacionAdopcion,
  enviarCorreoRechazoAdopcion,
  enviarCorreoContratoAdopcion,
  enviarCorreoVerificacionSolicitud,
  enviarCorreoNuevaDenunciaAdmin,
  enviarEmailGenerico,
  obtenerTransporter,
};


