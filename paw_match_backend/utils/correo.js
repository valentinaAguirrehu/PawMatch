const nodemailer = require('nodemailer');

function obtenerTransporter() {
  // Soporte directo para Gmail con contraseña de aplicación
  if (process.env.GMAIL_USER && process.env.GMAIL_PASS) {
    return nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.GMAIL_USER,
        pass: process.env.GMAIL_PASS,
      },
    });
  }

  // Soporte estándar SMTP
  if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
    return nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT) || 587,
      secure: Number(process.env.SMTP_PORT) === 465,
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }

  return null;
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
  const asunto = `¡Tu solicitud para apadrinar a ${nombreMascota} ha sido aprobada! 🎉 - Paw Match`;
  const textoPlano = `
Hola ${nombreUsuario},

¡Tenemos excelentes noticias! Tu solicitud para apadrinar a ${nombreMascota} ha sido APROBADA por la Fundación Maritza Arévalo.

Detalles del apadrinamiento:
- Mascota apadrinada: ${nombreMascota}
- Fecha oficial de inicio: ${fechaInicio || 'Inmediata'}
${observaciones ? `- Observaciones de la fundación: ${observaciones}\n` : ''}

IMPORTANTE:
Para continuar con el proceso y formalizar tu apadrinamiento, debes ponerte en contacto directamente con la Fundación Maritza Arévalo para revisar los últimos permisos, requerimientos y compromisos que pide la fundación.

Canales de contacto oficial:
- WhatsApp oficial: +${whatsappFundacion} (enlace: https://wa.me/${whatsappFundacion})
- App Paw Match: Inicia sesión para consultar el estado y la información oficial de tu apadrinamiento.

¡Gracias por tu amor, compromiso y apoyo para con nuestros perritos rescatados!

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match
`;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #ffccd5; border-radius: 12px; background-color: #fffafb;">
      <div style="text-align: center; margin-bottom: 20px;">
        <h1 style="color: #e91e63; margin-bottom: 8px;">¡Solicitud de Apadrinamiento Aprobada! 🎉</h1>
        <p style="color: #555; font-size: 16px;">Fundación Maritza Arévalo - Paw Match</p>
      </div>
      <div style="background-color: #ffffff; padding: 22px; border-radius: 8px; border: 1px solid #f0f0f0;">
        <p style="font-size: 16px; color: #333;">Hola <strong>${nombreUsuario}</strong>,</p>
        <p style="font-size: 15px; color: #444; line-height: 1.5;">
          Nos complace informarte que tu solicitud para apadrinar a <strong>${nombreMascota}</strong> ha sido <span style="color: #2e7d32; font-weight: bold;">APROBADA</span> exitosamente.
        </p>
        
        <div style="background-color: #fce4ec; padding: 14px 18px; border-radius: 8px; margin: 20px 0;">
          <p style="margin: 4px 0; color: #880e4f; font-size: 15px;"><strong>🐾 Mascota apadrinada:</strong> ${nombreMascota}</p>
          <p style="margin: 4px 0; color: #880e4f; font-size: 15px;"><strong>📅 Fecha oficial de inicio:</strong> ${fechaInicio || 'Inmediata'}</p>
          ${observaciones ? `<p style="margin: 8px 0 4px 0; color: #0d47a1; font-size: 14px; background-color: #e3f2fd; padding: 8px; border-radius: 6px;"><strong>📝 Observaciones:</strong> ${observaciones}</p>` : ''}
        </div>

        <div style="background-color: #fff3e0; border-left: 4px solid #ff9800; padding: 12px 16px; border-radius: 4px; margin: 18px 0;">
          <p style="margin: 0; color: #e65100; font-size: 14px; line-height: 1.5;">
            <strong>⚠️ Paso indispensable:</strong> Debes contactarte directamente con la fundación para revisar y acordar los <strong>últimos permisos, requerimientos y compromisos oficiales</strong> que pide la fundación para el cuidado de la mascota.
          </p>
        </div>

        <p style="font-size: 14px; color: #555; line-height: 1.5;">
          Puedes coordinar todos los detalles de inmediato escribiéndonos por WhatsApp o iniciando sesión en la aplicación <strong>Paw Match</strong>.
        </p>
        
        <div style="text-align: center; margin-top: 25px; margin-bottom: 10px;">
          <a href="https://wa.me/${whatsappFundacion}?text=${encodeURIComponent(`Hola Fundación Maritza Arévalo, mi solicitud para apadrinar a ${nombreMascota} fue aprobada en Paw Match y quiero coordinar los últimos requerimientos.`)}" 
             style="background-color: #25d366; color: white; padding: 13px 26px; text-decoration: none; font-weight: bold; border-radius: 25px; display: inline-block; font-size: 15px;">
            💬 Contactar por WhatsApp a la Fundación
          </a>
        </div>
      </div>
      <p style="text-align: center; font-size: 12px; color: #888; margin-top: 20px;">
        Este es un correo automático generado por Paw Match para la Fundación Maritza Arévalo (San Juan de Pasto).
      </p>
    </div>
  `;

  const transporter = obtenerTransporter();

  if (transporter) {
    try {
      const remitente = process.env.SMTP_FROM || process.env.GMAIL_USER || process.env.SMTP_USER;
      await transporter.sendMail({
        from: `"Fundación Maritza Arévalo - Paw Match" <${remitente}>`,
        to: destinatario,
        subject: asunto,
        text: textoPlano,
        html: html,
      });
      console.log(`[CORREO ENVIADO] Notificación enviada con éxito a ${destinatario}`);
      return { enviado: true };
    } catch (error) {
      console.error('[CORREO ERROR] No se pudo enviar el correo vía SMTP:', error.message);
      return { enviado: false, error: error.message };
    }
  } else {
    console.log(`[CORREO SIMULADO] Destinatario: ${destinatario}`);
    console.log(`  Asunto: ${asunto}`);
    console.log(`  Mascota: ${nombreMascota} | Inicio: ${fechaInicio}`);
    console.log('  (Para enviar correos reales por internet, configura GMAIL_USER y GMAIL_PASS o SMTP_* en tu archivo .env)');
    return { enviado: true, simulado: true };
  }
}

function escaparHtml(texto) {
  return String(texto ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * Notifica al usuario que su solicitud de adopción fue aprobada.
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
  const asunto = `¡Tu solicitud para adoptar a ${nombreMascota} fue aprobada! - Paw Match`;
  const textoPlano = `
Hola ${nombreUsuario},

Tu solicitud para adoptar a ${nombreMascota} fue APROBADA por la Fundación Maritza Arévalo.

Detalles de la adopción:
- Mascota: ${nombreMascota}
- Fecha oficial de inicio: ${fechaInicio || 'Inmediata'}
${observaciones ? `- Observaciones de la fundación: ${observaciones}\n` : ''}
Para coordinar la entrega y los últimos requisitos, escríbenos por WhatsApp:
https://wa.me/${whatsappFundacion}

También puedes ver el estado y las observaciones en la app Paw Match, sección Mis adopciones.

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match
`;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #ffccd5; border-radius: 12px; background-color: #fffafb;">
      <h1 style="color: #e91e63; text-align: center;">¡Adopción aprobada!</h1>
      <p>Hola <strong>${nombre}</strong>,</p>
      <p>Tu solicitud para adoptar a <strong>${mascota}</strong> fue <strong style="color:#2e7d32;">APROBADA</strong>.</p>
      <div style="background-color: #fce4ec; padding: 14px 18px; border-radius: 8px; margin: 20px 0;">
        <p style="margin: 4px 0;"><strong>Mascota:</strong> ${mascota}</p>
        <p style="margin: 4px 0;"><strong>Fecha oficial de inicio:</strong> ${inicio}</p>
        ${nota ? `<p style="margin: 8px 0 4px 0; background-color: #e3f2fd; padding: 8px; border-radius: 6px;"><strong>Observaciones:</strong> ${nota}</p>` : ''}
      </div>
      <p>Contacta a la fundación para coordinar la entrega y los últimos requisitos.</p>
      <p style="text-align:center;">
        <a href="https://wa.me/${whatsappFundacion}" style="background:#25d366;color:white;padding:12px 22px;border-radius:24px;text-decoration:none;font-weight:bold;">
          Contactar por WhatsApp
        </a>
      </p>
    </div>
  `;

  const transporter = obtenerTransporter();
  if (!transporter) {
    console.log(`[CORREO SIMULADO] Adopción aprobada para ${destinatario} (${nombreMascota})`);
    return { enviado: true, simulado: true };
  }

  try {
    const remitente = process.env.SMTP_FROM || process.env.GMAIL_USER || process.env.SMTP_USER;
    await transporter.sendMail({
      from: `"Fundación Maritza Arévalo - Paw Match" <${remitente}>`,
      to: destinatario,
      subject: asunto,
      text: textoPlano,
      html,
    });
    console.log(`[CORREO ENVIADO] Adopción aprobada notificada a ${destinatario}`);
    return { enviado: true };
  } catch (error) {
    console.error('[CORREO ERROR] No se pudo enviar la aprobación de adopción:', error.message);
    return { enviado: false, error: error.message };
  }
}

module.exports = {
  enviarCorreoAprobacionApadrinamiento,
  enviarCorreoAprobacionAdopcion,
};
