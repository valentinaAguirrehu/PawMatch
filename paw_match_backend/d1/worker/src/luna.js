import { completar, errorOpenAI } from './openai.js';

const PASOS = [
  { id: 'informacion_basica', numero: 1, titulo: 'Información básica' },
  { id: 'personalidad', numero: 2, titulo: 'Personalidad y energía' },
  { id: 'sociabilidad', numero: 3, titulo: 'Sociabilidad' },
  { id: 'salud', numero: 4, titulo: 'Salud' },
  { id: 'historia', numero: 5, titulo: 'Información adicional' },
];

const RASGOS = [
  'nivel_energia', 'sociabilidad_personas', 'sociabilidad_mascotas', 'independencia',
  'nivel_juego', 'carino', 'proteccion', 'tolerancia_soledad', 'adaptabilidad',
];

function entero(valor) {
  const numero = Number(valor);
  return Number.isInteger(numero) ? numero : null;
}

function camposFaltantes(ficha) {
  const faltan = [];
  if (!ficha.nombre) faltan.push('Nombre');
  if (!ficha.especie) faltan.push('Especie');
  if (!ficha.sexo) faltan.push('Sexo');
  if (ficha.edad == null || !ficha.unidad_edad) faltan.push('Edad');
  if (!ficha.tamano) faltan.push('Tamaño');
  const personalidad = ficha.personalidad || {};
  if (!Number.isInteger(personalidad.nivel_energia) && !Number.isInteger(personalidad.nivel_juego)) faltan.push('Personalidad y energía');
  if (!Number.isInteger(personalidad.sociabilidad_personas)) faltan.push('Sociabilidad con personas');
  if (!Number.isInteger(personalidad.sociabilidad_mascotas)) faltan.push('Sociabilidad con animales');
  if (!ficha.salud_consultada) faltan.push('Salud');
  if (!ficha.historia_consultada || !ficha.descripcion) faltan.push('Historia / Observaciones');
  return faltan;
}

function pasoActual(ficha) {
  if (!ficha.nombre || !ficha.especie || !ficha.sexo || ficha.edad == null || !ficha.tamano) return PASOS[0];
  const personalidad = ficha.personalidad || {};
  if (!Number.isInteger(personalidad.nivel_energia) && !Number.isInteger(personalidad.nivel_juego)) return PASOS[1];
  if (!Number.isInteger(personalidad.sociabilidad_personas) || !Number.isInteger(personalidad.sociabilidad_mascotas)) return PASOS[2];
  if (!ficha.salud_consultada) return PASOS[3];
  if (!ficha.historia_consultada || !ficha.descripcion) return PASOS[4];
  return null;
}

function mezclar(base, nuevos) {
  const ficha = { ...(base || {}), ...(nuevos || {}) };
  if (base?.personalidad || nuevos?.personalidad) {
    ficha.personalidad = { ...(base?.personalidad || {}), ...(nuevos?.personalidad || {}) };
    for (const rasgo of RASGOS) {
      const valor = entero(ficha.personalidad[rasgo]);
      if (valor != null && valor >= 1 && valor <= 5) ficha.personalidad[rasgo] = valor;
      else delete ficha.personalidad[rasgo];
    }
  }
  if (ficha.edad != null) ficha.edad = entero(ficha.edad);
  return ficha;
}

function saludo(genero) {
  const g = String(genero || '').trim().toLowerCase();
  if (g === 'mujer' || g === 'femenino' || g === 'f') {
    return '¡Hola! 💗 ¡Estoy lista para ayudarte a registrar un nuevo peludito en Paw Match! Para comenzar, cuéntame, ¿cómo se llama nuestro peludito, qué edad tiene, es perrito o gatito, qué sexo tiene y qué tamaño es? 🐾 Puedes escribirme o contarme todo lo que sepas hablando por el micrófono.';
  }
  if (g === 'hombre' || g === 'masculino' || g === 'm') {
    return '¡Hola! 💗 ¡Estoy listo para ayudarte a registrar un nuevo peludito en Paw Match! Para comenzar, cuéntame, ¿cómo se llama nuestro peludito, qué edad tiene, es perrito o gatito, qué sexo tiene y qué tamaño es? 🐾 Puedes escribirme o contarme todo lo que sepas hablando por el micrófono.';
  }
  return '¡Hola! 💗 Estoy aquí para ayudarte a registrar un nuevo peludito en Paw Match. Para comenzar, cuéntame, ¿cómo se llama nuestro peludito, qué edad tiene, es perrito o gatito, qué sexo tiene y qué tamaño es? 🐾 Puedes escribirme o contarme todo lo que sepas hablando por el micrófono.';
}

function instrucciones(paso, faltantes, nombre) {
  const peludito = nombre || 'nuestro peludito';
  return [
    'Eres el Asistente de Paw Match de la Fundación Maritza Arévalo. Tu propósito es agilizar el registro de mascotas mediante una conversación inteligente, cálida y natural que recopile MÁS INFORMACIÓN CON MENOS PREGUNTAS.',
    '',
    'REGLA DE IDENTIDAD:',
    '- Tu nombre visible es exclusivamente "Asistente de Paw Match".',
    '- NUNCA digas "Soy GPT Luna" ni menciones nombres técnicos de columnas o de IA.',
    '',
    'OBJETIVO PRINCIPAL – AGRUPAR PREGUNTAS RELACIONADAS PARA UN REGISTRO RÁPIDO:',
    '- No hagas preguntas individuales campo por campo como un formulario lento.',
    '- Utiliza estos 5 GRUPOS CONVERSACIONALES como referencia, adaptándolos y saltando todo lo que el administrador ya haya respondido:',
    '  * GRUPO 1 (Información básica): "Para comenzar, cuéntame, ¿cómo se llama nuestro peludito, qué edad tiene, es perrito o gatito, qué sexo tiene y qué tamaño es? 🐾"',
    `  * GRUPO 2 (Personalidad): "¡Qué bonito! Ahora cuéntame, ¿cómo es ${peludito}? ¿Es juguetón, cariñoso, tranquilo o independiente? ¿Cómo es su nivel de energía?"`,
    `  * GRUPO 3 (Sociabilidad): "¿Y cómo se lleva ${peludito} con las personas y con otros animalitos? ¿Le gusta jugar con ellos o prefiere estar tranquilito?"`,
    `  * GRUPO 4 (Salud): "Para cuidar bien su perfil, ¿sabes si ${peludito} está vacunado, esterilizado o tiene alguna condición de salud que debamos conocer?"`,
    `  * GRUPO 5 (Información adicional): "¿Hay alguna historia especial de ${peludito} o algún detalle de sus cuidados que te gustaría que las personas conocieran?"`,
    '',
    'COMPRENDER RESPUESTAS COMPLETAS Y EXTRAER VARIOS DATOS A LA VEZ:',
    '1. Analiza cada mensaje del administrador y extrae TODOS los datos presentes de cualquier grupo en "nuevos_datos":',
    '   - Ejemplo: si dice "Se llama Scrappy, tiene seis años, es un perrito mediano, es juguetón, le gusta estar tranquilo y no se lleva muy bien con otros perros", debes extraer:',
    '     * nombre: "Scrappy"',
    '     * edad: 6, unidad_edad: "anos"',
    '     * especie: "Perro", sexo: "Macho" (por "perrito", "juguetón", "tranquilo")',
    '     * tamano: "Mediano"',
    '     * personalidad.nivel_juego: 4, personalidad.nivel_energia: 3',
    '     * personalidad.sociabilidad_mascotas: 2 (necesita adaptación con otros perros)',
    '   - Y en tu siguiente pregunta NO vuelvas a preguntar nada de eso: pregunta únicamente por lo que falte.',
    '',
    '2. REGLAS DE EXTRACCIÓN EN "nuevos_datos":',
    '   - nombre: nombre propio limpio.',
    '   - especie: "Perro", "Gato" u "Otro".',
    '   - sexo: "Macho" o "Hembra" (infiérelo también de artículos y adjetivos como "el perrito", "es juguetón", "la gatita", "es cariñosa").',
    '   - edad: entero positivo, y unidad_edad: "meses" o "anos".',
    '   - tamano: "Pequeño", "Mediano" o "Grande".',
    '   - raza: si menciona una raza concreta ponla. Si dice que no tiene raza, que es criollo, mestizo, combinado, cruzado, mixto, callejero, desconocida o algo parecido, pon exactamente "Mestizo". Nunca uses "Desconocida".',
    '   - personalidad: valores enteros de 1 a 5 en nivel_energia, sociabilidad_personas, sociabilidad_mascotas, independencia, nivel_juego, carino, proteccion, tolerancia_soledad, adaptabilidad. Si es un cachorro muy pequeño con personalidad en desarrollo, pon es_cachorro_en_proceso: true y personalidad_definida: false.',
    '   - salud_consultada: true cuando responda sobre salud, vacunas o esterilización. Asigna vacunas true/false, esterilizado true/false, detalle_salud (sin inventar diagnósticos) y estado_salud usando solo valores de: "No presenta necesidades veterinarias pendientes.", "Requiere vacunación.", "Vacunación al día.", "Requiere esterilización.", "Esterilización realizada.", "Requiere desparasitación.", "Requiere exámenes médicos.", "Necesita medicamentos.", "Se encuentra en tratamiento veterinario.", "Requiere cuidados especiales."',
    '   - historia_consultada: true cuando comparta su historia/observaciones o indique que no hay más detalles adicionales. Guarda en descripcion un resumen cálido y breve (máx. 250 caracteres).',
    '',
    '3. COMPORTAMIENTO CUANDO EL ADMINISTRADOR RESPONDE ALGO FUERA DEL TEMA:',
    '   - Si responde algo sin relación con la mascota, pon necesita_aclaracion: true y nuevos_datos: {} (NUNCA guardes respuestas fuera de contexto).',
    '   - En la primera desviación responde con empatía y redirige suavemente: "¡Qué bien! Cuando puedas, seguimos con nuestro peludito. Me gustaría saber [lo que faltaba preguntar] para completar su perfil."',
    '   - Si en el historial reciente ya venía desviándose y vuelve a responder algo sin relación: "Creo que nos estamos desviando un poquito de nuestro registro. Te explico: necesito conocer [lo que falta] para que las personas puedan conocerlo mejor."',
    '   - Si la respuesta es confusa o no se comprende: "Perdóname, creo que no entendí muy bien. ¿Me lo puedes explicar de otra manera? Quiero asegurarme de guardar correctamente la información."',
    '',
    '4. LÍMITES: nombre 50, raza 50, descripcion 300, detalle_salud 300. Si se exceden, excede_limite es true y no guardes el dato recortado a la fuerza.',
    '',
    '5. CIERRE CUANDO TODOS LOS CAMPOS REQUERIDOS ESTÉN COMPLETOS:',
    '   - Cuando ya no falte ningún dato requerido, tu mensaje DEBE ser: "¡Qué alegría! Ya conocemos mucho mejor a nuestro peludito. Vamos a revisar su información para asegurarnos de que todo esté correcto."',
    '',
    'Devuelve EXCLUSIVAMENTE un objeto JSON válido con esta estructura:',
    '{',
    '  "necesita_aclaracion": boolean,',
    '  "excede_limite": boolean,',
    '  "confirmacion_guardado": "Resumen breve de los datos guardados en este turno",',
    '  "mensaje": "Respuesta corta, cálida y natural + pregunta agrupada de lo que falta (o mensaje de cierre).",',
    '  "nuevos_datos": {',
    '    "nombre": string | null,',
    '    "especie": "Perro" | "Gato" | "Otro" | null,',
    '    "sexo": "Macho" | "Hembra" | null,',
    '    "edad": number | null,',
    '    "unidad_edad": "meses" | "anos" | null,',
    '    "raza": string | null,',
    '    "tamano": "Pequeño" | "Mediano" | "Grande" | null,',
    '    "es_cachorro_en_proceso": boolean | null,',
    '    "personalidad_definida": boolean | null,',
    '    "personalidad": { nivel_energia, sociabilidad_personas, sociabilidad_mascotas, independencia, nivel_juego, carino, proteccion, tolerancia_soledad, adaptabilidad },',
    '    "vacunas": boolean | null,',
    '    "esterilizado": boolean | null,',
    '    "estado_salud": string[],',
    '    "detalle_salud": string | null,',
    '    "descripcion": string | null,',
    '    "salud_consultada": boolean | null,',
    '    "historia_consultada": boolean | null',
    '  }',
    '}',
    `Grupo sugerido ahora: ${paso.numero}. ${paso.titulo}.`,
    `Datos que aún faltan: ${faltantes.join(', ') || 'Ninguno'}.`,
  ].join('\n');
}

function extraerJson(texto) {
  const limpio = String(texto || '').trim().replace(/^```json\s*|```$/gi, '').trim();
  const inicio = limpio.indexOf('{');
  const fin = limpio.lastIndexOf('}');
  if (inicio < 0 || fin <= inicio) throw new Error('JSON inválido');
  return JSON.parse(limpio.slice(inicio, fin + 1));
}

function respuesta(ficha, historial, mensaje, reanudado) {
  const paso = pasoActual(ficha);
  return {
    mensaje,
    necesita_aclaracion: false,
    confirmacion_guardado: null,
    entrevista_completada: paso == null,
    ficha,
    paso_actual: paso ? paso.id : 'completado',
    numero_paso: paso ? paso.numero : PASOS.length,
    total_pasos: PASOS.length,
    campos_faltantes: camposFaltantes(ficha),
    porcentaje_progreso: Math.round(((9 - Math.min(camposFaltantes(ficha).length, 9)) / 9) * 100),
    historial_guardado: historial,
    guardado_en_bd: true,
    reanudado,
  };
}

export async function turnoLuna(env, { ficha, historial, mensaje, genero, reiniciar }) {
  const base = reiniciar ? {} : mezclar({}, ficha || {});
  const conversacion = reiniciar || !Array.isArray(historial) ? [] : historial.map((item) => ({
    rol: item.rol === 'usuario' || item.role === 'user' ? 'usuario' : 'asistente',
    texto: String(item.texto || item.content || '').trim(),
  })).filter((item) => item.texto);
  const texto = String(mensaje || '').trim();
  if (!texto) {
    const reanudar = !reiniciar && (conversacion.some((item) => item.rol === 'usuario') || base.nombre || base.especie);
    const actual = reanudar ? conversacion : [{ rol: 'asistente', texto: saludo(genero) }];
    return { status: 200, body: respuesta(reanudar ? base : {}, actual, actual[actual.length - 1].texto, Boolean(reanudar)) };
  }
  if (!env.OPENAI_API_KEY) {
    return { status: 503, body: { error: 'El asistente de Paw Match está ocupado en este momento. Inténtalo de nuevo.' } };
  }
  const paso = pasoActual(base) || PASOS[PASOS.length - 1];
  const modelo = await completar(env, [
    { role: 'system', content: instrucciones(paso, camposFaltantes(base), base.nombre) },
    {
      role: 'user',
      content: [
        `Género del administrador autenticado: ${genero || 'No especificado'}`,
        `Grupo actual sugerido: Grupo ${paso.numero} - ${paso.titulo}`,
        `Datos requeridos que aún faltaban antes de este mensaje: ${camposFaltantes(base).join(', ') || 'Ninguno'}`,
        '',
        'Borrador actual:',
        JSON.stringify(base, null, 2),
        '',
        'Historial reciente de la conversación:',
        conversacion.slice(-10).map((item) => `${item.rol === 'asistente' ? 'Asistente' : 'Administrador'}: ${item.texto}`).join('\n') || '(Inicio)',
        '',
        'Respuesta del administrador:',
        texto,
      ].join('\n'),
    },
  ]);
  if (!modelo.ok) return errorOpenAI(modelo, 'luna');
  const data = await modelo.respuesta.json();
  let crudo;
  try {
    crudo = extraerJson(data?.choices?.[0]?.message?.content);
  } catch {
    return { status: 502, body: { error: 'No se pudo guardar o procesar la respuesta en este momento. Por favor reintenta.' } };
  }
  const aclaracion = crudo.necesita_aclaracion === true || crudo.excede_limite === true;
  const siguiente = aclaracion ? base : mezclar(base, crudo.nuevos_datos || {});
  const completada = !aclaracion && pasoActual(siguiente) == null;
  if (completada && !siguiente.raza) siguiente.raza = 'Mestizo';
  let mensajeRespuesta = String(crudo.mensaje || '').trim();
  if (completada) {
    mensajeRespuesta = '¡Qué alegría! Ya conocemos mucho mejor a nuestro peludito. Vamos a revisar su información para asegurarnos de que todo esté correcto.';
  } else if (!mensajeRespuesta) {
    mensajeRespuesta = aclaracion
      ? 'Perdóname, creo que no entendí muy bien. ¿Me lo puedes explicar de otra manera? Quiero asegurarme de guardar correctamente la información.'
      : '¡Ahora entiendo mejor cómo es! Seguimos con lo que falta.';
  }
  const nuevoHistorial = [
    ...conversacion,
    { rol: 'usuario', texto },
    { rol: 'asistente', texto: mensajeRespuesta },
  ];
  const salida = respuesta(siguiente, nuevoHistorial, mensajeRespuesta, false);
  salida.necesita_aclaracion = aclaracion;
  salida.confirmacion_guardado = crudo.confirmacion_guardado || null;
  return { status: 200, body: salida };
}
