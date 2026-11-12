const WHATSAPP = '573136177747';

function escapar(valor) {
  return String(valor ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function tarjeta(titulo, color, interior) {
  return `<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:22px;border:1px solid ${color};border-radius:14px;background:#fffafb;">
    <h1 style="color:${color};font-size:22px;margin:0 0 8px;">${titulo}</h1>
    <p style="color:#666;margin:0 0 16px;">Fundación Maritza Arévalo · Paw Match</p>
    <div style="background:#fff;padding:18px;border-radius:12px;border:1px solid #f2e2e6;">${interior}</div>
  </div>`;
}

export function aprobacionAdopcion({ nombre, mascota, fecha, observaciones, whatsapp = WHATSAPP }) {
  const inicio = fecha || 'Inmediata';
  const asunto = `¡Tu solicitud para adoptar a ${mascota} ha sido aprobada! 🎉 - Paw Match`;
  const texto = `Hola ${nombre},

¡Tenemos excelentes noticias! Tu solicitud para adoptar a ${mascota} ha sido APROBADA por la Fundación Maritza Arévalo.

Detalles de la adopción:
- Mascota adoptada: ${mascota}
- Fecha oficial de inicio: ${inicio}
${observaciones ? `- Observaciones de la fundación: ${observaciones}\n` : ''}
ESTADO DEL CONTRATO:
Tu adopción quedó aprobada, pero el contrato oficial aún no está cargado. En Mis adopciones verás el estado "Pendiente subir contrato de adopción". Cuando el administrador lo suba, te avisaremos por correo y en la app para que puedas verlo y descargarlo.

IMPORTANTE:
Para continuar con el proceso y coordinar la entrega, debes ponerte en contacto directamente con la Fundación Maritza Arévalo para revisar los últimos requerimientos.

Canales de contacto oficial:
- WhatsApp oficial: +${whatsapp} (enlace: https://wa.me/${whatsapp})
- App Paw Match: Inicia sesión y abre Mis adopciones para consultar el estado y las observaciones.

¡Gracias por abrir tu hogar a uno de nuestros perritos rescatados!

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match`;
  const html = tarjeta('¡Solicitud de adopción aprobada!', '#e91e63', `
    <p>Hola <strong>${escapar(nombre)}</strong>,</p>
    <p>Tu solicitud para adoptar a <strong>${escapar(mascota)}</strong> ha sido <strong>APROBADA</strong>.</p>
    <p>Mascota adoptada: ${escapar(mascota)}<br>Fecha oficial de inicio: ${escapar(inicio)}</p>
    ${observaciones ? `<p>Observaciones de la fundación: ${escapar(observaciones)}</p>` : ''}
    <p><strong>Pendiente subir contrato de adopción.</strong> Cuando el administrador lo cargue, te avisaremos para verlo y descargarlo en Mis adopciones.</p>
    <p>WhatsApp oficial: +${escapar(whatsapp)}</p>`);
  return { asunto, texto, html };
}

export function rechazoAdopcion({ nombre, mascota, observaciones, whatsapp = WHATSAPP }) {
  const asunto = `Información sobre tu solicitud de adopción para ${mascota} - Paw Match`;
  const texto = `Hola ${nombre},

Agradecemos profundamente tu interés y el amor que demostraste al postularte para adoptar a ${mascota} en la Fundación Maritza Arévalo.

Queremos informarte que, tras evaluar las solicitudes recibidas y los requerimientos del refugio, en esta ocasión tu solicitud no ha podido ser aprobada.

${observaciones ? `Motivo u observaciones de la fundación:\n${observaciones}\n\n` : ''}¡No te desanimes! Aún hay muchos otros peluditos en Paw Match que esperan una familia. Te invitamos a ingresar a la aplicación para conocer a otros compañeros.

Si tienes dudas o deseas más detalles, puedes escribirnos por WhatsApp:
- WhatsApp oficial: +${whatsapp} (enlace: https://wa.me/${whatsapp})

¡Gracias por tu empatía y compromiso con el bienestar animal!

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match`;
  const html = tarjeta('Información sobre tu solicitud de adopción', '#c2185b', `
    <p>Hola <strong>${escapar(nombre)}</strong>,</p>
    <p>En esta ocasión tu solicitud para adoptar a <strong>${escapar(mascota)}</strong> no ha podido ser aprobada.</p>
    ${observaciones ? `<p>Motivo u observaciones de la fundación: ${escapar(observaciones)}</p>` : ''}
    <p>Aún hay otros peluditos en Paw Match que esperan una familia.</p>
    <p>WhatsApp oficial: +${escapar(whatsapp)}</p>`);
  return { asunto, texto, html };
}

export function contratoAdopcion({ nombre, mascota, whatsapp = WHATSAPP }) {
  const asunto = `Tu contrato de adopción de ${mascota} ya está disponible - Paw Match`;
  const texto = `Hola ${nombre},

El administrador de la Fundación Maritza Arévalo ya cargó el contrato de adopción firmado de ${mascota}.

Ya puedes verlo y descargarlo en Paw Match:
- Abre la app e inicia sesión.
- Entra a Mis adopciones.
- En la solicitud de ${mascota} pulsa «Ver y descargar contrato».

Si tienes dudas sobre la entrega, escríbenos por WhatsApp: +${whatsapp} (https://wa.me/${whatsapp}).

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match`;
  const html = tarjeta('Tu contrato de adopción ya está disponible', '#2e7d32', `
    <p>Hola <strong>${escapar(nombre)}</strong>,</p>
    <p>El contrato de adopción firmado de <strong>${escapar(mascota)}</strong> ya está disponible en Mis adopciones.</p>
    <p>WhatsApp oficial: +${escapar(whatsapp)}</p>`);
  return { asunto, texto, html };
}

export function aprobacionApadrinamiento({ nombre, mascota, fecha, observaciones, whatsapp = WHATSAPP }) {
  const inicio = fecha || 'Inmediata';
  const asunto = `¡Tu solicitud para apadrinar a ${mascota} ha sido aprobada! 🎉 - Paw Match`;
  const texto = `Hola ${nombre},

¡Tenemos excelentes noticias! Tu solicitud para apadrinar a ${mascota} ha sido APROBADA por la Fundación Maritza Arévalo.

Detalles del apadrinamiento:
- Mascota apadrinada: ${mascota}
- Fecha oficial de inicio: ${inicio}
${observaciones ? `- Observaciones de la fundación: ${observaciones}\n` : ''}
IMPORTANTE:
Para continuar con el proceso y formalizar tu apadrinamiento, debes ponerte en contacto directamente con la Fundación Maritza Arévalo para coordinar los últimos requerimientos y compromisos.

Canales de contacto oficial:
- WhatsApp oficial: +${whatsapp} (enlace: https://wa.me/${whatsapp})
- App Paw Match: Inicia sesión para consultar el estado y la información oficial de tu apadrinamiento.

¡Gracias por tu amor, compromiso y apoyo para con nuestros perritos rescatados!

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match`;
  const html = tarjeta('¡Solicitud de apadrinamiento aprobada!', '#e91e63', `
    <p>Hola <strong>${escapar(nombre)}</strong>,</p>
    <p>Tu solicitud para apadrinar a <strong>${escapar(mascota)}</strong> ha sido <strong>APROBADA</strong>.</p>
    <p>Mascota apadrinada: ${escapar(mascota)}<br>Fecha oficial de inicio: ${escapar(inicio)}</p>
    ${observaciones ? `<p>Observaciones de la fundación: ${escapar(observaciones)}</p>` : ''}
    <p>WhatsApp oficial: +${escapar(whatsapp)}</p>`);
  return { asunto, texto, html };
}

export function rechazoApadrinamiento({ nombre, mascota, observaciones, whatsapp = WHATSAPP }) {
  const asunto = `Información sobre tu solicitud de apadrinamiento para ${mascota} - Paw Match`;
  const texto = `Hola ${nombre},

Agradecemos profundamente tu interés y el amor que demostraste al postularte para apadrinar a ${mascota} en la Fundación Maritza Arévalo.

Queremos informarte que, tras evaluar las solicitudes recibidas y los requerimientos del refugio, en esta ocasión tu solicitud no ha podido ser aprobada.

${observaciones ? `Motivo u observaciones de la fundación:\n${observaciones}\n\n` : ''}¡No te desanimes! Aún hay muchos otros peluditos en Paw Match que esperan por un padrino o una familia. Te invitamos a ingresar a la aplicación para conocer a otros compañeros que necesitan de tu apoyo.

Si tienes dudas o deseas más detalles, puedes escribirnos por WhatsApp:
- WhatsApp oficial: +${whatsapp} (enlace: https://wa.me/${whatsapp})

¡Gracias por tu empatía y compromiso con el bienestar animal!

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match`;
  const html = tarjeta('Información sobre tu solicitud de apadrinamiento', '#c2185b', `
    <p>Hola <strong>${escapar(nombre)}</strong>,</p>
    <p>En esta ocasión tu solicitud para apadrinar a <strong>${escapar(mascota)}</strong> no ha podido ser aprobada.</p>
    ${observaciones ? `<p>Motivo u observaciones de la fundación: ${escapar(observaciones)}</p>` : ''}
    <p>WhatsApp oficial: +${escapar(whatsapp)}</p>`);
  return { asunto, texto, html };
}

export function alertaIncumplimiento({ nombre, mascota, consecutivos = 3 }) {
  const asunto = `Alerta importante: Seguimiento de apadrinamiento de ${mascota} – Fundación Maritza Arévalo`;
  const texto = `Estimado(a) ${nombre}:

Nos comunicamos desde la Fundación Maritza Arévalo para informarle que se han registrado ${consecutivos} seguimientos consecutivos en los cuales no se evidencia el cumplimiento de los compromisos acordados para el apadrinamiento de ${mascota}.

Le recordamos que el aporte y compromiso asumido son indispensables para garantizar el sustento, alimentación y atención veterinaria de la mascota. Debido a la reiteración de incumplimientos, su apadrinamiento se encuentra en riesgo inminente de cancelación y su usuario podría ser inhabilitado para realizar nuevos apadrinamientos.

Por favor, póngase en contacto a la brevedad con la administración de la fundación o ingrese a la aplicación PawMatch para revisar sus compromisos.

Atentamente,
Fundación Maritza Arévalo – Protección y bienestar animal.`;
  const html = tarjeta('Aviso de incumplimiento en apadrinamiento', '#c2185b', `
    <p>Hola, <strong>${escapar(nombre)}</strong>:</p>
    <p>Se han registrado <strong>${escapar(consecutivos)} seguimientos consecutivos</strong> sin el cumplimiento acordado para el apadrinamiento de <strong>${escapar(mascota)}</strong>.</p>
    <p>El apadrinamiento está en riesgo de cancelación y la cuenta podría quedar inhabilitada para nuevas solicitudes.</p>`);
  return { asunto, texto, html };
}

export function decisionApadrinamiento({ nombre, mascota, decision, nota, admin, ciclo = 1 }) {
  const continuar = decision === 'continuar';
  const actual = Number(ciclo) || 1;
  const siguiente = actual + 1;
  const asunto = continuar
    ? `Evaluación Ciclo ${actual} de ${mascota}: Aprobada (Comenzará el Ciclo ${siguiente}) – Fundación Maritza Arévalo`
    : `Notificación: Cancelación de apadrinamiento de ${mascota} (Ciclo ${actual}) – Fundación Maritza Arévalo`;
  const texto = `Estimado(a) ${nombre}:

Le comunicamos que la Fundación Maritza Arévalo ha realizado la evaluación oficial del Ciclo ${actual} de su apadrinamiento con ${mascota}.

Decisión de la fundación: ${continuar ? `CONTINUAR CON EL APADRINAMIENTO (Comenzará el Ciclo ${siguiente})` : 'APADRINAMIENTO CANCELADO'}
${nota ? `Observaciones / Nota del administrador: ${nota}\n` : ''}${continuar ? `Se ha cerrado con éxito el Ciclo ${actual} y comenzará el Ciclo ${siguiente}.\n` : 'Por este motivo, el apadrinamiento ha sido cancelado.\n'}
Atentamente,
${admin || 'Administrador'}
Fundación Maritza Arévalo`;
  const html = tarjeta(continuar ? 'Evaluación de apadrinamiento' : 'Cancelación de apadrinamiento', continuar ? '#2e7d32' : '#c62828', `
    <p>Estimado(a) <strong>${escapar(nombre)}</strong>:</p>
    <p>Decisión del ciclo ${escapar(actual)} de <strong>${escapar(mascota)}</strong>: <strong>${continuar ? 'CONTINUAR' : 'CANCELADO'}</strong>.</p>
    ${nota ? `<p>Nota del administrador: ${escapar(nota)}</p>` : ''}
    <p>Evaluado por ${escapar(admin || 'Administrador')}.</p>`);
  return { asunto, texto, html };
}

export function denunciaAdmin({ radicado }) {
  const folio = radicado || 'DEN-RECIBIDA';
  const asunto = 'Nueva denuncia recibida – Fundación Maritza Arévalo';
  const texto = `Se ha recibido una nueva denuncia de posible maltrato animal en la plataforma de la Fundación Maritza Arévalo.

Para consultar la información completa del caso, los datos del reporte, las evidencias y la información de contacto del denunciante, ingresa a la aplicación e inicia sesión con tu cuenta autorizada.

Por motivos de privacidad y protección de datos personales, los detalles de la denuncia no se incluyen en este correo.

Por favor, revisa el caso desde el panel administrativo y realiza el seguimiento correspondiente.

Radicado: ${folio}

Fundación Maritza Arévalo – Protección y bienestar animal.`;
  const html = tarjeta('Nueva denuncia recibida', '#ed4f9d', `
    <p>Se ha recibido una nueva denuncia de posible maltrato animal.</p>
    <p>Radicado: <strong>${escapar(folio)}</strong></p>
    <p>Para consultar el caso, ingresa a la aplicación e inicia sesión con tu cuenta autorizada.</p>
    <p><strong>Protección de datos personales:</strong> los detalles de la denuncia no se incluyen en este correo.</p>`);
  return { asunto, texto, html };
}

export function recuperacion({ nombre, codigo }) {
  const persona = nombre || 'Usuario';
  const asunto = `Tu código de recuperación: ${codigo} - Paw Match`;
  const texto = `Hola ${persona},

Recibimos una solicitud para restablecer la contraseña de tu cuenta en Paw Match.

Tu código de verificación de 4 dígitos es:
${codigo}

Este código es de uso único y tiene una validez de 15 minutos.
Si tú no realizaste esta solicitud, puedes ignorar este mensaje; tu cuenta sigue segura.

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match`;
  const html = tarjeta('Recuperación de contraseña', '#ff4081', `
    <p>Hola <strong>${escapar(persona)}</strong>,</p>
    <p>Tu código de verificación de 4 dígitos es:</p>
    <p style="font-size:28px;letter-spacing:6px;"><strong>${escapar(codigo)}</strong></p>
    <p>Es de uso único y vence en 15 minutos. Si no solicitaste el cambio, ignora este mensaje.</p>`);
  return { asunto, texto, html };
}

export function verificacionSolicitud({ nombre, mascota, token, tipo, origen }) {
  const apadrinar = tipo === 'apadrinamiento';
  const accion = apadrinar ? 'apadrinamiento' : 'adopción';
  const ruta = apadrinar
    ? '/api/solicitudes-apadrinamiento/verificar-correo'
    : '/api/adoption-requests/verificar-correo';
  const base = String(origen || '').replace(/\/$/, '');
  const enlace = `${base}${ruta}?token=${encodeURIComponent(token)}`;
  const asunto = `Confirma tu correo para tu solicitud de ${accion} de ${mascota} - Paw Match`;
  const texto = `Hola ${nombre},

Gracias por tu solicitud de ${accion} para ${mascota} en la Fundación Maritza Arévalo.

Para que tu solicitud sea revisada por el administrador y puedas recibir notificaciones oficiales sobre su estado, debes confirmar tu correo electrónico abriendo este enlace:

${enlace}

Mientras no confirmes tu correo, tu solicitud se mostrará en Paw Match con el estado "Correo pendiente de confirmación".
Una vez confirmado, el estado cambiará a "Correo confirmado".

Si no realizaste esta solicitud, puedes ignorar este mensaje.

Atentamente,
Fundación Maritza Arévalo & Equipo Paw Match`;
  const html = tarjeta('Confirma tu correo', '#e91e63', `
    <p>Hola <strong>${escapar(nombre)}</strong>,</p>
    <p>Confirma tu correo para la solicitud de ${escapar(accion)} de <strong>${escapar(mascota)}</strong>.</p>
    <p><a href="${escapar(enlace)}">Confirmar correo</a></p>`);
  return { asunto, texto, html };
}
