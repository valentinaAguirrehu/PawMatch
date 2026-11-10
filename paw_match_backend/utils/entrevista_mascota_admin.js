const path = require('path');
const pool = require('../db');
const {
  MODELO,
  personalityColumns,
  extraerJson,
  textoDeMensaje,
} = require('./entrevista_personalidad');

const OPCIONES_ESTADO_SALUD = [
  'No presenta necesidades veterinarias pendientes.',
  'Requiere vacunación.',
  'Vacunación al día.',
  'Requiere esterilización.',
  'Esterilización realizada.',
  'Requiere desparasitación.',
  'Requiere exámenes médicos.',
  'Necesita medicamentos.',
  'Se encuentra en tratamiento veterinario.',
  'Requiere cuidados especiales.',
];

/**
 * 5 Grupos inteligentes de conversación para agilizar el registro de mascotas
 * recopilando varios datos relacionados en una sola respuesta.
 */
const PASOS_ENTREVISTA = [
  {
    id: 'informacion_basica',
    numero: 1,
    titulo: 'Información básica',
    preguntaBase:
      'Para comenzar, cuéntame, ¿cómo se llama nuestro peludito, qué edad tiene, es perrito o gatito, qué sexo tiene y qué tamaño es? 🐾',
  },
  {
    id: 'personalidad',
    numero: 2,
    titulo: 'Personalidad y energía',
    preguntaBase:
      '¡Qué bonito! Ahora cuéntame, ¿cómo es su personalidad? ¿Es juguetón, cariñoso, tranquilo o independiente? ¿Cómo es su nivel de energía?',
  },
  {
    id: 'sociabilidad',
    numero: 3,
    titulo: 'Sociabilidad',
    preguntaBase:
      '¿Y cómo se lleva con las personas y con otros animalitos? ¿Le gusta jugar con ellos o prefiere estar tranquilito?',
  },
  {
    id: 'salud',
    numero: 4,
    titulo: 'Salud',
    preguntaBase:
      'Para cuidar bien su perfil, ¿sabes si está vacunado, esterilizado o tiene alguna condición de salud que debamos conocer?',
  },
  {
    id: 'historia',
    numero: 5,
    titulo: 'Información adicional',
    preguntaBase:
      '¿Hay alguna historia especial o algún detalle de sus cuidados que te gustaría que las personas conocieran?',
  },
];

function preguntaPersonalizadaPaso(paso, ficha) {
  if (!paso) return '';
  const nombre = ficha?.nombre || 'nuestro peludito';
  const esHembra = ficha?.sexo === 'Hembra';
  switch (paso.id) {
    case 'informacion_basica': {
      const pendientes = [];
      if (!ficha?.nombre) pendientes.push('cómo se llama');
      if (ficha?.edad === null || !ficha?.unidad_edad) pendientes.push('qué edad tiene');
      if (!ficha?.especie) pendientes.push('si es perrito o gatito');
      if (!ficha?.sexo) pendientes.push('si es machito o hembrita');
      if (!ficha?.tamano) pendientes.push('qué tamaño tiene (pequeño, mediano o grande)');
      if (pendientes.length >= 4) {
        return 'Para comenzar, cuéntame, ¿cómo se llama nuestro peludito, qué edad tiene, es perrito o gatito, qué sexo tiene y qué tamaño es? 🐾';
      }
      if (pendientes.length === 1) {
        return `Para completar sus datos básicos, cuéntame ${pendientes[0]} ${ficha?.nombre ? `de ${nombre}` : ''}. 🐾`.replace(/\s+/g, ' ');
      }
      const ult = pendientes.pop();
      return `¡Vamos muy bien! De ${nombre}, cuéntame ${pendientes.join(', ')} y ${ult}. 🐾`;
    }
    case 'personalidad':
      return `¡Qué bonito! Ahora cuéntame, ¿cómo es ${nombre}? ¿Es ${esHembra ? 'juguetona, cariñosa, tranquila' : 'juguetón, cariñoso, tranquilo'} o independiente? ¿Cómo es su nivel de energía?`;
    case 'sociabilidad': {
      const p = ficha?.personalidad || {};
      const faltaPersonas = !Number.isInteger(p.sociabilidad_personas);
      const faltaMascotas = !Number.isInteger(p.sociabilidad_mascotas);
      if (faltaPersonas && faltaMascotas) {
        return `¿Y cómo se lleva ${nombre} con las personas y con otros animalitos? ¿Le gusta jugar con ellos o prefiere estar ${esHembra ? 'tranquilita' : 'tranquilito'}?`;
      }
      if (faltaMascotas) {
        return `Cuéntame, ¿cómo se lleva ${nombre} con otros animalitos? ¿Disfruta jugar con ellos o prefiere tener su propio espacio?`;
      }
      return `¿Y con las personas cómo se comporta ${nombre}? ¿Es ${esHembra ? 'cariñosa, tímida' : 'cariñoso, tímido'} o le gusta estar ${esHembra ? 'acompañada' : 'acompañado'}?`;
    }
    case 'salud':
      return `Para cuidar bien su perfil, ¿sabes si ${nombre} está ${esHembra ? 'vacunada, esterilizada' : 'vacunado, esterilizado'} o tiene alguna condición de salud que debamos conocer?`;
    case 'historia':
      return `¿Hay alguna historia especial de ${nombre} o algún detalle de sus cuidados que te gustaría que las personas conocieran?`;
    default:
      return paso.preguntaBase;
  }
}

let limitesColumnasCache = null;
let tablaBorradorLista = false;

/**
 * Consulta los límites reales de caracteres de la tabla `mascota` en PostgreSQL
 * y aplica topes seguros para evitar errores de truncado o desbordamiento.
 */
async function obtenerLimitesColumnasMascota() {
  if (limitesColumnasCache) return limitesColumnasCache;
  const limitesPorDefecto = {
    nombre: 50,
    especie: 20,
    raza: 50,
    sexo: 10,
    tamano: 20,
    unidad_edad: 10,
    descripcion: 300,
    detalle_salud: 300,
  };
  try {
    const res = await pool.query(`
      SELECT column_name, character_maximum_length, data_type
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'mascota'
    `);
    for (const row of res.rows) {
      const maxLen = Number(row.character_maximum_length);
      if (Number.isInteger(maxLen) && maxLen > 0) {
        limitesPorDefecto[row.column_name] = maxLen;
      }
    }
    limitesColumnasCache = limitesPorDefecto;
  } catch (_) {
    limitesColumnasCache = limitesPorDefecto;
  }
  return limitesColumnasCache;
}

/**
 * Crea la tabla de borradores progresivos en PostgreSQL para guardar cada
 * respuesta válida paso a paso durante la conversación.
 */
async function asegurarTablaBorradorMascota() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS borrador_mascota_formulario_ia (
      id_borrador UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      id_administrador UUID NOT NULL UNIQUE REFERENCES usuario(id_usuario) ON DELETE CASCADE,
      nombre VARCHAR(100),
      especie VARCHAR(30),
      sexo VARCHAR(20),
      edad INTEGER,
      unidad_edad VARCHAR(10),
      fecha_nacimiento DATE,
      raza VARCHAR(100),
      tamano VARCHAR(30),
      es_cachorro_en_proceso BOOLEAN,
      personalidad_definida BOOLEAN,
      personalidad JSONB NOT NULL DEFAULT '{}'::jsonb,
      estado_salud JSONB NOT NULL DEFAULT '[]'::jsonb,
      vacunas BOOLEAN,
      esterilizado BOOLEAN,
      detalle_salud TEXT,
      descripcion TEXT,
      salud_consultada BOOLEAN NOT NULL DEFAULT FALSE,
      historia_consultada BOOLEAN NOT NULL DEFAULT FALSE,
      paso_actual VARCHAR(40) NOT NULL DEFAULT 'nombre',
      historial_chat JSONB NOT NULL DEFAULT '[]'::jsonb,
      origen_registro VARCHAR(20) NOT NULL DEFAULT 'ia',
      foto TEXT,
      estado_adopcion VARCHAR(20) DEFAULT 'disponible',
      estado_apadrinamiento VARCHAR(20) DEFAULT 'disponible',
      fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  `);

  try {
    await pool.query(`
      ALTER TABLE borrador_mascota_formulario_ia
        ADD COLUMN IF NOT EXISTS foto TEXT,
        ADD COLUMN IF NOT EXISTS origen_registro VARCHAR(20) NOT NULL DEFAULT 'ia',
        ADD COLUMN IF NOT EXISTS estado_adopcion VARCHAR(20) DEFAULT 'disponible',
        ADD COLUMN IF NOT EXISTS estado_apadrinamiento VARCHAR(20) DEFAULT 'disponible';
    `);
  } catch (_) {}

  // Eliminar definitivamente y sin excepción cualquier tabla antigua o con nombres anteriores
  await pool.query('DROP TABLE IF EXISTS borrador_registro_mascota_luna CASCADE;').catch(() => {});
  await pool.query('DROP TABLE IF EXISTS borrador_mascota_ia CASCADE;').catch(() => {});
  await pool.query('DROP TABLE IF EXISTS borrador_mascota CASCADE;').catch(() => {});
}

function obtenerApiKey() {
  let key = process.env.OPENAI_API_KEY;
  if (!key || !String(key).trim()) {
    require('dotenv').config({
      path: path.join(__dirname, '..', '.env'),
      override: true,
    });
    key = process.env.OPENAI_API_KEY;
  }
  if (!key || !String(key).trim()) return null;
  return String(key).trim();
}

async function completarConGptLuna(messages) {
  const key = obtenerApiKey();
  if (!key) {
    const err = new Error('Sin OPENAI_API_KEY');
    err.estado = 503;
    throw err;
  }

  const intentos = [
    { temperature: 0.2, response_format: { type: 'json_object' } },
    { response_format: { type: 'json_object' } },
    {},
  ];
  let ultimo = null;

  for (const extra of intentos) {
    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ model: MODELO, messages, ...extra }),
      signal: AbortSignal.timeout(40000),
    });
    if (resp.ok) return resp;

    const texto = await resp.text();
    ultimo = { status: resp.status, texto };
    const recuperable =
      resp.status === 400 &&
      /temperature|response_format|json_object|unsupported|unknown parameter/i.test(texto);
    if (!recuperable) break;
  }

  const error = new Error('OpenAI');
  error.estado = ultimo?.status || 502;
  error.detalle = ultimo?.texto || '';
  throw error;
}

/**
 * Obtiene el género real del administrador autenticado desde PostgreSQL.
 * Nunca asume el género por el nombre.
 */
async function obtenerGeneroAdministrador(idAdmin) {
  if (!idAdmin) return '';
  try {
    const res = await pool.query(
      'SELECT genero FROM usuario WHERE id_usuario = $1',
      [idAdmin],
    );
    return String(res.rows[0]?.genero || '').trim();
  } catch (_) {
    return '';
  }
}

/**
 * Construye el saludo inicial agrupado adaptado al género real del administrador,
 * invitando desde el primer momento a dar la información básica o descripción completa.
 */
function construirSaludoInicial(generoRaw) {
  const g = String(generoRaw || '').trim().toLowerCase();
  if (g === 'mujer' || g === 'femenino' || g === 'f') {
    return '¡Hola! 💗 ¡Estoy lista para ayudarte a registrar un nuevo peludito en Paw Match! Para comenzar, cuéntame, ¿cómo se llama nuestro peludito, qué edad tiene, es perrito o gatito, qué sexo tiene y qué tamaño es? 🐾 Puedes escribirme o contarme todo lo que sepas hablando por el micrófono.';
  }
  if (g === 'hombre' || g === 'masculino' || g === 'm') {
    return '¡Hola! 💗 ¡Estoy listo para ayudarte a registrar un nuevo peludito en Paw Match! Para comenzar, cuéntame, ¿cómo se llama nuestro peludito, qué edad tiene, es perrito o gatito, qué sexo tiene y qué tamaño es? 🐾 Puedes escribirme o contarme todo lo que sepas hablando por el micrófono.';
  }
  return '¡Hola! 💗 Estoy aquí para ayudarte a registrar un nuevo peludito en Paw Match. Para comenzar, cuéntame, ¿cómo se llama nuestro peludito, qué edad tiene, es perrito o gatito, qué sexo tiene y qué tamaño es? 🐾 Puedes escribirme o contarme todo lo que sepas hablando por el micrófono.';
}

function calcularFechaNacimientoIso(edad, unidadEdad) {
  if (edad === null || edad === undefined) return null;
  const cant = Math.max(1, Math.min(360, Number(edad) || 1));
  const hoy = new Date();
  let year = hoy.getFullYear();
  let month = hoy.getMonth() + 1;
  const day = Math.min(hoy.getDate(), 28);

  if (String(unidadEdad || '').toLowerCase().startsWith('mes')) {
    month -= cant;
    while (month <= 0) {
      month += 12;
      year -= 1;
    }
  } else {
    year -= cant;
  }
  const mm = String(month).padStart(2, '0');
  const dd = String(day).padStart(2, '0');
  return `${year}-${mm}-${dd}`;
}

/**
 * Determina cuál de los 5 grupos conversacionales tiene datos pendientes,
 * saltando automáticamente cualquier grupo que ya haya sido respondido.
 */
function determinarSiguientePaso(ficha) {
  if (
    !ficha.nombre ||
    !ficha.especie ||
    !ficha.sexo ||
    ficha.edad === null ||
    !ficha.unidad_edad ||
    !ficha.tamano
  ) {
    return PASOS_ENTREVISTA[0]; // 1. informacion_basica
  }

  const enProceso =
    ficha.es_cachorro_en_proceso === true || ficha.personalidad_definida === false;

  if (!enProceso) {
    const p = ficha.personalidad || {};
    const tieneCaracterOEnergia =
      Number.isInteger(p.nivel_juego) || Number.isInteger(p.nivel_energia);
    if (!tieneCaracterOEnergia) {
      return PASOS_ENTREVISTA[1]; // 2. personalidad
    }
    if (
      !Number.isInteger(p.sociabilidad_personas) ||
      !Number.isInteger(p.sociabilidad_mascotas)
    ) {
      return PASOS_ENTREVISTA[2]; // 3. sociabilidad
    }
  }

  if (!ficha.salud_consultada) {
    return PASOS_ENTREVISTA[3]; // 4. salud
  }
  if (!ficha.historia_consultada || !ficha.descripcion) {
    return PASOS_ENTREVISTA[4]; // 5. historia
  }
  return null; // Registro conversacional completado
}

function camposFaltantes(ficha) {
  const faltan = [];
  if (!ficha.nombre) faltan.push('Nombre');
  if (!ficha.especie) faltan.push('Especie');
  if (!ficha.sexo) faltan.push('Sexo');
  if (ficha.edad === null || !ficha.unidad_edad) faltan.push('Edad');
  if (!ficha.tamano) faltan.push('Tamaño');

  const enProceso =
    ficha.es_cachorro_en_proceso === true || ficha.personalidad_definida === false;
  if (!enProceso) {
    const p = ficha.personalidad || {};
    if (!Number.isInteger(p.nivel_juego) && !Number.isInteger(p.nivel_energia)) {
      faltan.push('Personalidad y energía');
    }
    if (!Number.isInteger(p.sociabilidad_mascotas)) {
      faltan.push('Sociabilidad con animales');
    }
    if (!Number.isInteger(p.sociabilidad_personas)) {
      faltan.push('Sociabilidad con personas');
    }
  }
  if (!ficha.salud_consultada) faltan.push('Salud');
  if (!ficha.historia_consultada || !ficha.descripcion) {
    faltan.push('Historia / Observaciones');
  }
  return faltan;
}

/**
 * Calcula el porcentaje real de información recopilada (0 a 100%)
 * basándose exclusivamente en los campos requeridos validados (nunca en el número de mensajes).
 */
function calcularPorcentajeProgreso(ficha) {
  if (!ficha || typeof ficha !== 'object') return 0;
  let puntos = 0;
  if (ficha.nombre) puntos += 12;
  if (ficha.especie) puntos += 10;
  if (ficha.sexo) puntos += 10;
  if (ficha.edad !== null && ficha.edad !== undefined && ficha.unidad_edad) {
    puntos += 12;
  }
  if (ficha.tamano) puntos += 10;

  const enProceso =
    ficha.es_cachorro_en_proceso === true || ficha.personalidad_definida === false;
  if (enProceso) {
    puntos += 26;
  } else {
    const p = ficha.personalidad || {};
    if (Number.isInteger(p.nivel_juego) || Number.isInteger(p.nivel_energia)) {
      puntos += 14;
    }
    if (Number.isInteger(p.sociabilidad_personas)) {
      puntos += 6;
    }
    if (Number.isInteger(p.sociabilidad_mascotas)) {
      puntos += 6;
    }
  }

  if (ficha.salud_consultada) puntos += 10;
  if (ficha.historia_consultada && ficha.descripcion) puntos += 10;

  return Math.max(0, Math.min(100, Math.round(puntos)));
}

function canonRaza(valor, maxRaza = 50) {
  if (valor == null) return null;
  const original = String(valor).trim();
  if (!original) return null;
  const limpio = original
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const indefinida =
    /\b(mestiz[oa]s?|crioll[oa]s?|combinad[oa]s?|cruzad[oa]s?|cruce|mixt[oa]s?|mezcl[oa]s?|mezcla|callej[oa]s?|desconocid[oa]s?|corriente|ordinari[oa]|comun|indefinid[oa]s?|variad[oa]s?)\b/.test(
      limpio,
    ) ||
    /sin raza|no tiene raza|no se sabe|no la se|no conozco|no es de raza|sin definir|sin pedigree|de la calle|ninguna raza|ningun raza|no aplica/.test(
      limpio,
    );
  const relleno = new Set([
    'es', 'un', 'una', 'el', 'la', 'lo', 'los', 'las', 'de', 'del', 'al', 'y', 'o',
    'con', 'que', 'se', 'su', 'sus', 'por', 'para', 'como', 'tipo', 'parece', 'creo',
    'dice', 'mascota', 'perro', 'perra', 'perrito', 'perrita', 'gato', 'gata',
    'gatito', 'gatita', 'raza', 'tiene', 'tener', 'no', 'si', 'muy', 'solo', 'sola',
    'puro', 'pura', 'definida', 'definido', 'algo', 'parecido', 'parecida', 'tambien',
    'nuestro', 'nuestra',
  ]);
  const genericos = new Set([
    'mestizo', 'mestiza', 'mestizos', 'mestizas', 'criollo', 'criolla', 'criollos',
    'criollas', 'combinado', 'combinada', 'combinados', 'combinadas', 'cruzado',
    'cruzada', 'cruzados', 'cruzadas', 'cruce', 'mixto', 'mixta', 'mixtos', 'mixtas',
    'mezcla', 'mezclado', 'mezclada', 'mezclados', 'mezcladas', 'callejero',
    'callejera', 'callejeros', 'callejeras', 'desconocido', 'desconocida',
    'desconocidos', 'desconocidas', 'ninguno', 'ninguna', 'comun', 'corriente',
    'ordinario', 'ordinaria', 'indefinido', 'indefinida', 'variado', 'variada',
    'varias', 'varios', 'sin', 'sabe', 'conozco', 'aplica', 'pedigree', 'calle',
  ]);
  const especificos = limpio
    .split(' ')
    .filter((t) => t && !relleno.has(t) && !genericos.has(t));
  if (indefinida && especificos.length === 0) return 'Mestizo';
  return original.length <= maxRaza ? original : original.slice(0, maxRaza);
}

function normalizarFicha(raw = {}, fichaPrevia = {}, limites = {}) {
  const maxNombre = limites.nombre || 50;
  const maxRaza = limites.raza || 50;
  const maxDesc = limites.descripcion || 300;
  const maxDetalleSalud = limites.detalle_salud || 300;

  const base = {
    nombre: fichaPrevia.nombre || null,
    especie: fichaPrevia.especie || null,
    sexo: fichaPrevia.sexo || null,
    edad: fichaPrevia.edad ?? null,
    unidad_edad: fichaPrevia.unidad_edad || null,
    raza: fichaPrevia.raza || null,
    tamano: fichaPrevia.tamano || null,
    es_cachorro_en_proceso:
      typeof fichaPrevia.es_cachorro_en_proceso === 'boolean'
        ? fichaPrevia.es_cachorro_en_proceso
        : null,
    personalidad_definida:
      typeof fichaPrevia.personalidad_definida === 'boolean'
        ? fichaPrevia.personalidad_definida
        : null,
    personalidad: {
      ...(fichaPrevia.personalidad && typeof fichaPrevia.personalidad === 'object'
        ? fichaPrevia.personalidad
        : {}),
    },
    estado_salud: Array.isArray(fichaPrevia.estado_salud)
      ? [...fichaPrevia.estado_salud]
      : [],
    vacunas:
      typeof fichaPrevia.vacunas === 'boolean' ? fichaPrevia.vacunas : null,
    esterilizado:
      typeof fichaPrevia.esterilizado === 'boolean'
        ? fichaPrevia.esterilizado
        : null,
    detalle_salud: fichaPrevia.detalle_salud || null,
    descripcion: fichaPrevia.descripcion || null,
    salud_consultada: Boolean(fichaPrevia.salud_consultada),
    historia_consultada: Boolean(fichaPrevia.historia_consultada),
  };

  if (!raw || typeof raw !== 'object') return base;

  const limpiarTexto = (val) => {
    if (val === undefined || val === null) return null;
    const s = String(val).trim();
    if (!s || /^(null|undefined|ninguno)$/i.test(s)) return null;
    return s;
  };

  const nombre = limpiarTexto(raw.nombre);
  if (nombre && nombre.length <= maxNombre) {
    base.nombre = nombre;
  }

  const especieRaw = limpiarTexto(raw.especie);
  if (especieRaw) {
    const e = especieRaw.toLowerCase();
    if (e.includes('perr') || e.includes('can') || e.includes('cachorr')) {
      base.especie = 'Perro';
    } else if (e.includes('gat') || e.includes('felin') || e.includes('michi')) {
      base.especie = 'Gato';
    } else if (e.includes('otr')) {
      base.especie = 'Otro';
    }
  }

  const sexoRaw = limpiarTexto(raw.sexo);
  if (sexoRaw) {
    const s = sexoRaw.toLowerCase();
    if (s.startsWith('m') || s.includes('macho') || s.includes('machito') || s.includes('niño')) {
      base.sexo = 'Macho';
    } else if (
      s.startsWith('h') ||
      s.startsWith('f') ||
      s.includes('hembra') ||
      s.includes('hembrita') ||
      s.includes('niña')
    ) {
      base.sexo = 'Hembra';
    }
  }

  if (raw.edad !== undefined && raw.edad !== null && raw.edad !== '') {
    const n = Number(raw.edad);
    if (Number.isFinite(n) && n >= 0 && n <= 360) {
      base.edad = Math.max(1, Math.round(n));
    }
  }

  const unidadRaw = limpiarTexto(raw.unidad_edad);
  if (unidadRaw) {
    const u = unidadRaw.toLowerCase();
    base.unidad_edad = u.startsWith('mes') ? 'meses' : 'anos';
  } else if (base.edad !== null && !base.unidad_edad) {
    base.unidad_edad = 'anos';
  }

  if (raw.raza !== undefined && raw.raza !== null) {
    const r = String(raw.raza).trim();
    if (r) base.raza = canonRaza(r, maxRaza);
  }

  const tamanoRaw = limpiarTexto(raw.tamano);
  if (tamanoRaw) {
    const t = tamanoRaw.toLowerCase();
    if (t.startsWith('peq') || t.includes('chico') || t.includes('mini')) {
      base.tamano = 'Pequeño';
    } else if (t.startsWith('med')) {
      base.tamano = 'Mediano';
    } else if (t.startsWith('gran')) {
      base.tamano = 'Grande';
    }
  }

  if (typeof raw.es_cachorro_en_proceso === 'boolean') {
    base.es_cachorro_en_proceso = raw.es_cachorro_en_proceso;
  }
  if (typeof raw.personalidad_definida === 'boolean') {
    base.personalidad_definida = raw.personalidad_definida;
  }
  if (base.es_cachorro_en_proceso === true) {
    base.personalidad_definida = false;
  }

  if (raw.personalidad && typeof raw.personalidad === 'object') {
    for (const col of personalityColumns) {
      const v = Number(raw.personalidad[col]);
      if (Number.isInteger(v) && v >= 1 && v <= 5) {
        base.personalidad[col] = v;
      }
    }
    if (Object.keys(base.personalidad).length > 0 && base.es_cachorro_en_proceso !== true) {
      base.personalidad_definida = true;
    }
  }

  // Completar coherente y automáticamente rasgos secundarios para el algoritmo Match
  // una vez que ya conocemos su personalidad general, trato con animales y con personas.
  if (base.es_cachorro_en_proceso !== true && base.personalidad_definida !== false) {
    const p = base.personalidad;
    if (Number.isInteger(p.nivel_juego) && !Number.isInteger(p.nivel_energia)) {
      p.nivel_energia = p.nivel_juego;
    } else if (Number.isInteger(p.nivel_energia) && !Number.isInteger(p.nivel_juego)) {
      p.nivel_juego = p.nivel_energia;
    }
    if (
      Number.isInteger(p.nivel_juego) &&
      Number.isInteger(p.sociabilidad_mascotas) &&
      Number.isInteger(p.sociabilidad_personas)
    ) {
      if (!Number.isInteger(p.carino)) {
        p.carino = p.sociabilidad_personas;
      }
      if (!Number.isInteger(p.independencia)) {
        p.independencia = p.sociabilidad_mascotas <= 2 ? 4 : 3;
      }
      if (!Number.isInteger(p.tolerancia_soledad)) {
        p.tolerancia_soledad = p.independencia >= 4 ? 4 : 3;
      }
      if (!Number.isInteger(p.proteccion)) {
        p.proteccion = 3;
      }
      if (!Number.isInteger(p.adaptabilidad)) {
        p.adaptabilidad = Math.max(
          1,
          Math.min(
            5,
            Math.round((p.sociabilidad_personas + p.sociabilidad_mascotas) / 2),
          ),
        );
      }
    }
  }

  if (typeof raw.vacunas === 'boolean') base.vacunas = raw.vacunas;
  if (typeof raw.esterilizado === 'boolean') base.esterilizado = raw.esterilizado;

  if (Array.isArray(raw.estado_salud)) {
    const limpios = [];
    for (const item of raw.estado_salud) {
      const txt = String(item || '').trim();
      const oficial = OPCIONES_ESTADO_SALUD.find(
        (op) => op.toLowerCase() === txt.toLowerCase(),
      );
      if (oficial && !limpios.includes(oficial)) {
        limpios.push(oficial);
      }
    }
    if (limpios.length > 0) {
      base.estado_salud = limpios;
      base.salud_consultada = true;
    }
  }

  if (base.vacunas === true && !base.estado_salud.includes('Vacunación al día.')) {
    base.estado_salud = base.estado_salud.filter((e) => e !== 'Requiere vacunación.');
    base.estado_salud.push('Vacunación al día.');
    base.salud_consultada = true;
  } else if (base.vacunas === false && !base.estado_salud.includes('Requiere vacunación.')) {
    base.estado_salud = base.estado_salud.filter(
      (e) =>
        e !== 'Vacunación al día.' &&
        e !== 'No presenta necesidades veterinarias pendientes.',
    );
    base.estado_salud.push('Requiere vacunación.');
    base.salud_consultada = true;
  }

  if (base.esterilizado === true && !base.estado_salud.includes('Esterilización realizada.')) {
    base.estado_salud = base.estado_salud.filter((e) => e !== 'Requiere esterilización.');
    base.estado_salud.push('Esterilización realizada.');
    base.salud_consultada = true;
  } else if (base.esterilizado === false && !base.estado_salud.includes('Requiere esterilización.')) {
    base.estado_salud = base.estado_salud.filter(
      (e) =>
        e !== 'Esterilización realizada.' &&
        e !== 'No presenta necesidades veterinarias pendientes.',
    );
    base.estado_salud.push('Requiere esterilización.');
    base.salud_consultada = true;
  }

  const detalleSalud = limpiarTexto(raw.detalle_salud);
  if (detalleSalud && detalleSalud.length <= maxDetalleSalud) {
    base.detalle_salud = detalleSalud;
    base.salud_consultada = true;
  }

  const descripcion = limpiarTexto(raw.descripcion);
  if (descripcion && descripcion.length <= maxDesc) {
    base.descripcion = descripcion;
    base.historia_consultada = true;
  }

  if (raw.salud_consultada === true) base.salud_consultada = true;
  if (raw.historia_consultada === true) base.historia_consultada = true;

  if (base.salud_consultada && base.estado_salud.length === 0) {
    base.estado_salud = ['No presenta necesidades veterinarias pendientes.'];
  }

  base.raza = canonRaza(base.raza, maxRaza);

  return base;
}

/**
 * Guarda o actualiza el borrador progresivo de la mascota en PostgreSQL
 * inmediatamente después de cada respuesta válida del administrador.
 */
async function guardarBorradorMascotaEnBd(
  idAdmin,
  ficha,
  pasoActual = 'nombre',
  historial = [],
  origen = 'ia',
  foto = null,
) {
  await asegurarTablaBorradorMascota();
  const fechaNac = ficha.fecha_nacimiento || calcularFechaNacimientoIso(ficha.edad, ficha.unidad_edad);
  const historialLimpio = Array.isArray(historial)
    ? historial.slice(-30).map((m) => ({
        rol: m.rol === 'asistente' ? 'asistente' : 'usuario',
        texto: String(m.texto || '').slice(0, 1000),
      }))
    : [];

  const fotoFinal = foto || ficha.foto || null;
  const origenFinal = origen || ficha.origen_registro || 'ia';

  try {
    await pool.query(
      `INSERT INTO borrador_mascota_formulario_ia (
        id_administrador, nombre, especie, sexo, edad, unidad_edad, fecha_nacimiento,
        raza, tamano, es_cachorro_en_proceso, personalidad_definida, personalidad,
        estado_salud, vacunas, esterilizado, detalle_salud, descripcion,
        salud_consultada, historia_consultada, paso_actual, historial_chat,
        origen_registro, foto, fecha_actualizacion
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7,
        $8, $9, $10, $11, $12::jsonb,
        $13::jsonb, $14, $15, $16, $17,
        $18, $19, $20, $21::jsonb,
        $22, $23, CURRENT_TIMESTAMP
      )
      ON CONFLICT (id_administrador) DO UPDATE SET
        nombre = EXCLUDED.nombre,
        especie = EXCLUDED.especie,
        sexo = EXCLUDED.sexo,
        edad = EXCLUDED.edad,
        unidad_edad = EXCLUDED.unidad_edad,
        fecha_nacimiento = EXCLUDED.fecha_nacimiento,
        raza = EXCLUDED.raza,
        tamano = EXCLUDED.tamano,
        es_cachorro_en_proceso = EXCLUDED.es_cachorro_en_proceso,
        personalidad_definida = EXCLUDED.personalidad_definida,
        personalidad = EXCLUDED.personalidad,
        estado_salud = EXCLUDED.estado_salud,
        vacunas = EXCLUDED.vacunas,
        esterilizado = EXCLUDED.esterilizado,
        detalle_salud = EXCLUDED.detalle_salud,
        descripcion = EXCLUDED.descripcion,
        salud_consultada = EXCLUDED.salud_consultada,
        historia_consultada = EXCLUDED.historia_consultada,
        paso_actual = EXCLUDED.paso_actual,
        historial_chat = CASE WHEN $21::jsonb = '[]'::jsonb THEN borrador_mascota_formulario_ia.historial_chat ELSE EXCLUDED.historial_chat END,
        origen_registro = EXCLUDED.origen_registro,
        foto = COALESCE(EXCLUDED.foto, borrador_mascota_formulario_ia.foto),
        fecha_actualizacion = CURRENT_TIMESTAMP`,
      [
        idAdmin,
        ficha.nombre || null,
        ficha.especie || null,
        ficha.sexo || null,
        ficha.edad ?? null,
        ficha.unidad_edad || null,
        fechaNac,
        ficha.raza || null,
        ficha.tamano || null,
        ficha.es_cachorro_en_proceso ?? null,
        ficha.personalidad_definida ?? null,
        JSON.stringify(ficha.personalidad || {}),
        JSON.stringify(ficha.estado_salud || []),
        ficha.vacunas ?? null,
        ficha.esterilizado ?? null,
        ficha.detalle_salud || null,
        ficha.descripcion || null,
        Boolean(ficha.salud_consultada),
        Boolean(ficha.historia_consultada),
        pasoActual || 'nombre',
        JSON.stringify(historialLimpio),
        origenFinal,
        fotoFinal,
      ],
    );
  } catch (err) {
    console.error('Error guardando en borrador_mascota_formulario_ia:', err.message);
  }
}

async function obtenerBorradorMascotaDeBd(idAdmin) {
  await asegurarTablaBorradorMascota().catch(() => {});
  let r = null;
  try {
    let res = await pool.query(
      `SELECT * FROM borrador_mascota_formulario_ia WHERE id_administrador = $1`,
      [idAdmin],
    );
    if (res.rows.length === 0) {
      res = await pool.query(
        `SELECT * FROM borrador_mascota_formulario_ia ORDER BY fecha_actualizacion DESC LIMIT 1`,
      );
    }
    if (res.rows.length > 0) {
      r = res.rows[0];
    }
  } catch (err) {
    console.error('Error en obtenerBorradorMascotaDeBd:', err.message);
  }
  if (!r) return null;
  const limites = await obtenerLimitesColumnasMascota();
  const ficha = normalizarFicha(
    {
      nombre: r.nombre,
      especie: r.especie,
      sexo: r.sexo,
      edad: r.edad,
      unidad_edad: r.unidad_edad,
      raza: r.raza,
      tamano: r.tamano,
      es_cachorro_en_proceso: r.es_cachorro_en_proceso,
      personalidad_definida: r.personalidad_definida,
      personalidad: r.personalidad || {},
      estado_salud: r.estado_salud || [],
      vacunas: r.vacunas,
      esterilizado: r.esterilizado,
      detalle_salud: r.detalle_salud,
      descripcion: r.descripcion,
      salud_consultada: r.salud_consultada,
      historia_consultada: r.historia_consultada,
      foto: r.foto || null,
      origen_registro: r.origen_registro || 'ia',
    },
    {},
    limites,
  );
  return {
    id_borrador: r.id_borrador,
    id_administrador: r.id_administrador,
    ficha,
    foto: r.foto || null,
    origen_registro: r.origen_registro || 'ia',
    paso_actual: r.paso_actual || 'nombre',
    historial: Array.isArray(r.historial_chat) ? r.historial_chat : [],
  };
}

async function listarBorradoresMascotaDeBd(idAdmin) {
  await asegurarTablaBorradorMascota().catch(() => {});
  try {
    const res = await pool.query(
      `SELECT id_borrador, id_administrador, nombre, especie, sexo, edad, unidad_edad,
              to_char(fecha_nacimiento, 'YYYY-MM-DD') as fecha_nacimiento,
              raza, tamano, es_cachorro_en_proceso, personalidad_definida,
              personalidad, estado_salud, vacunas, esterilizado, detalle_salud, descripcion,
              salud_consultada, historia_consultada, paso_actual,
              jsonb_array_length(COALESCE(historial_chat, '[]'::jsonb)) as total_mensajes,
              COALESCE(foto, NULL) as foto,
              COALESCE(origen_registro, 'ia') as origen_registro,
              fecha_actualizacion
       FROM borrador_mascota_formulario_ia
       ORDER BY fecha_actualizacion DESC`,
    );
    return res.rows || [];
  } catch (err) {
    console.error('Error listando de borrador_mascota_formulario_ia:', err.message);
    return [];
  }
}

async function eliminarBorradorMascotaDeBd(idOAdmin, idAdminSecundario = null, nombre = null) {
  await asegurarTablaBorradorMascota().catch(() => {});
  const id1 = String(idOAdmin || '').trim();
  const id2 = String(idAdminSecundario || '').trim();
  const nombreLimpio = String(nombre || '').trim();

  try {
    const res = await pool.query(
      `DELETE FROM borrador_mascota_formulario_ia 
       WHERE (id_administrador::text = $1 AND $1 <> '')
          OR (id_administrador::text = $2 AND $2 <> '')
          OR (id_borrador::text = $1 AND $1 <> '')
          OR (id_borrador::text = $2 AND $2 <> '')
          OR ($3::text <> '' AND LOWER(TRIM(nombre)) = LOWER(TRIM($3)))`,
      [id1, id2, nombreLimpio],
    );
    if (res.rowCount === 0) {
      await pool.query(
        `DELETE FROM borrador_mascota_formulario_ia
         WHERE id_administrador::text = $1 
            OR id_administrador::text = $2
            OR ($3::text <> '' AND LOWER(TRIM(nombre)) LIKE LOWER(CONCAT('%', TRIM($3), '%')))`,
        [id1, id2, nombreLimpio],
      );
    }
  } catch (err) {
    console.error('Error eliminando de borrador_mascota_formulario_ia:', err.message);
  }

  // Eliminar definitivamente y sin excepción cualquier tabla antigua o con nombres anteriores
  for (const tablaAntigua of ['borrador_registro_mascota_luna', 'borrador_mascota_ia', 'borrador_mascota']) {
    try {
      await pool.query(`DROP TABLE IF EXISTS ${tablaAntigua} CASCADE;`);
    } catch (_) {}
  }
}

function construirMensajesPasoAPaso({
  fichaActual,
  pasoEnCurso,
  historial,
  respuestaAdmin,
  limites,
  generoAdmin,
}) {
  const textoHistorial =
    Array.isArray(historial) && historial.length > 0
      ? historial
          .slice(-10)
          .map(
            (m) =>
              `${m.rol === 'asistente' ? 'Asistente' : 'Administrador'}: ${String(m.texto || '').trim()}`,
          )
          .join('\n')
      : '(Inicio)';

  const faltantesActuales = camposFaltantes(fichaActual);
  const preguntaSugeridaActual = preguntaPersonalizadaPaso(pasoEnCurso, fichaActual);

  return [
    {
      role: 'system',
      content: [
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
        '  * GRUPO 2 (Personalidad): "¡Qué bonito! Ahora cuéntame, ¿cómo es [nombre]? ¿Es juguetón, cariñoso, tranquilo o independiente? ¿Cómo es su nivel de energía?"',
        '  * GRUPO 3 (Sociabilidad): "¿Y cómo se lleva [nombre] con las personas y con otros animalitos? ¿Le gusta jugar con ellos o prefiere estar tranquilito?"',
        '  * GRUPO 4 (Salud): "Para cuidar bien su perfil, ¿sabes si [nombre] está vacunado, esterilizado o tiene alguna condición de salud que debamos conocer?"',
        '  * GRUPO 5 (Información adicional): "¿Hay alguna historia especial de [nombre] o algún detalle de sus cuidados que te gustaría que las personas conocieran?"',
        '',
        'COMPRENDER RESPUESTAS COMPLETAS Y EXTRAER VARIOS DATOS A LA VEZ:',
        '1. Analiza cada mensaje del administrador y extrae TODOS los datos presentes de cualquier grupo en `"nuevos_datos"`:',
        '   - Ejemplo: si dice "Se llama Scrappy, tiene seis años, es un perrito mediano, es juguetón, le gusta estar tranquilo y no se lleva muy bien con otros perros", debes extraer:',
        '     * `nombre`: "Scrappy"',
        '     * `edad`: 6, `unidad_edad`: "anos"',
        '     * `especie`: "Perro", `sexo`: "Macho" (por "perrito", "juguetón", "tranquilo")',
        '     * `tamano`: "Mediano"',
        '     * `personalidad.nivel_juego`: 4, `personalidad.nivel_energia`: 3',
        '     * `personalidad.sociabilidad_mascotas`: 2 (necesita adaptación con otros perros)',
        '   - Y en tu siguiente pregunta NO vuelvas a preguntar nada de eso: pregunta únicamente por lo que falte (por ejemplo, cómo se lleva Scrappy con las personas y cómo está de salud/vacunas/esterilización).',
        '',
        '2. REGLAS DE EXTRACCIÓN EN `"nuevos_datos"`:',
        '   - `nombre`: nombre propio limpio.',
        '   - `especie`: "Perro", "Gato" u "Otro".',
        '   - `sexo`: "Macho" o "Hembra" (infiérelo también de artículos y adjetivos como "el perrito", "es juguetón", "la gatita", "es cariñosa").',
        '   - `edad`: entero positivo, y `unidad_edad`: "meses" o "anos".',
        '   - `tamano`: "Pequeño", "Mediano" o "Grande".',
        '   - `raza`: si menciona una raza concreta ponla. Si dice que no tiene raza, que es criollo, mestizo, combinado, cruzado, mixto, callejero, desconocida o algo parecido, pon exactamente "Mestizo". Nunca uses "Desconocida".',
        '   - `personalidad`: valores enteros de 1 a 5 en `nivel_energia`, `sociabilidad_personas`, `sociabilidad_mascotas`, `independencia`, `nivel_juego`, `carino`, `proteccion`, `tolerancia_soledad`, `adaptabilidad`. Si es un cachorro muy pequeño con personalidad en desarrollo, pon `es_cachorro_en_proceso: true` y `personalidad_definida: false`.',
        '   - `salud_consultada`: `true` cuando responda sobre salud, vacunas o esterilización. Asigna `vacunas: true/false`, `esterilizado: true/false`, `detalle_salud` (sin inventar diagnósticos) y `estado_salud` usando solo valores de:',
        '     ["No presenta necesidades veterinarias pendientes.", "Requiere vacunación.", "Vacunación al día.", "Requiere esterilización.", "Esterilización realizada.", "Requiere desparasitación.", "Requiere exámenes médicos.", "Necesita medicamentos.", "Se encuentra en tratamiento veterinario.", "Requiere cuidados especiales."]',
        '   - `historia_consultada`: `true` cuando comparta su historia/observaciones o indique que no hay más detalles adicionales. Guarda en `descripcion` un resumen cálido y breve (máx. 250 caracteres).',
        '',
        '3. COMPORTAMIENTO CUANDO EL ADMINISTRADOR RESPONDE ALGO FUERA DEL TEMA:',
        '   - Si responde algo sin relación con la mascota (ej. "Hoy voy a salir a comprar"), pon `"necesita_aclaracion": true` y `"nuevos_datos": {}` (NUNCA guardes respuestas fuera de contexto en la base de datos).',
        '   - En la primera desviación responde con empatía y redirige suavemente:',
        '     "¡Qué bien! 💗 Cuando puedas, seguimos con nuestro peludito. Me gustaría saber [lo que faltaba preguntar] para completar su perfil."',
        '   - Si en el historial reciente ya venía desviándose y vuelve a responder algo sin relación:',
        '     "Creo que nos estamos desviando un poquito de nuestro registro. 😊 Te explico: necesito conocer [lo que falta] para que las personas puedan conocerlo mejor."',
        '   - Si la respuesta es confusa o no se comprende:',
        '     "Perdóname, creo que no entendí muy bien. ¿Me lo puedes explicar de otra manera? Quiero asegurarme de guardar correctamente la información."',
        '',
        '4. RESPETAR LOS LÍMITES DE POSTGRESQL:',
        `   - nombre: máximo ${limites.nombre || 50} caracteres.`,
        `   - raza: máximo ${limites.raza || 50} caracteres.`,
        `   - descripcion: máximo ${limites.descripcion || 300} caracteres.`,
        `   - detalle_salud: máximo ${limites.detalle_salud || 300} caracteres.`,
        '',
        '5. CIERRE CUANDO TODOS LOS CAMPOS REQUERIDOS ESTÉN COMPLETOS:',
        '   - Cuando ya no falte ningún dato requerido, tu `"mensaje"` DEBE ser:',
        '     "¡Qué alegría! Ya conocemos mucho mejor a nuestro peludito. 💗 Vamos a revisar su información para asegurarnos de que todo esté correcto."',
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
        '    "personalidad": {',
        '      "nivel_energia": 1..5 | null,',
        '      "sociabilidad_personas": 1..5 | null,',
        '      "sociabilidad_mascotas": 1..5 | null,',
        '      "independencia": 1..5 | null,',
        '      "nivel_juego": 1..5 | null,',
        '      "carino": 1..5 | null,',
        '      "proteccion": 1..5 | null,',
        '      "tolerancia_soledad": 1..5 | null,',
        '      "adaptabilidad": 1..5 | null',
        '    },',
        '    "vacunas": boolean | null,',
        '    "esterilizado": boolean | null,',
        '    "estado_salud": string[],',
        '    "detalle_salud": string | null,',
        '    "descripcion": string | null,',
        '    "salud_consultada": boolean | null,',
        '    "historia_consultada": boolean | null',
        '  }',
        '}',
      ].join('\n'),
    },
    {
      role: 'user',
      content: [
        `Género del administrador autenticado: ${generoAdmin || 'No especificado'}`,
        `Grupo actual sugerido: Grupo ${pasoEnCurso.numero} - ${pasoEnCurso.titulo} (${preguntaSugeridaActual})`,
        `Datos requeridos que aún faltaban antes de este mensaje: ${faltantesActuales.join(', ') || 'Ninguno'}`,
        '',
        'Borrador actual guardado en PostgreSQL:',
        JSON.stringify(fichaActual, null, 2),
        '',
        'Historial reciente de la conversación:',
        textoHistorial,
        '',
        'Respuesta del administrador:',
        String(respuestaAdmin || '').trim(),
      ].join('\n'),
    },
  ];
}

async function procesarTurnoEntrevistaMascota({
  idAdmin,
  ficha = {},
  historial = [],
  mensaje = '',
  reiniciar = false,
}) {
  const limites = await obtenerLimitesColumnasMascota();
  const generoAdmin = await obtenerGeneroAdministrador(idAdmin);

  if (reiniciar && idAdmin) {
    await eliminarBorradorMascotaDeBd(idAdmin);
  }

  const textoUsuario = String(mensaje || '').trim();

  // Inicio o reanudación de la conversación
  if (!textoUsuario) {
    if (!reiniciar && idAdmin) {
      const borradorExistente = await obtenerBorradorMascotaDeBd(idAdmin);
      const tieneRespuestasUsuario =
        borradorExistente &&
        ((Array.isArray(borradorExistente.historial) &&
          borradorExistente.historial.some((m) => m.rol === 'usuario')) ||
         Boolean(borradorExistente.ficha?.nombre || borradorExistente.ficha?.especie));
      if (tieneRespuestasUsuario) {
        const sigPaso = determinarSiguientePaso(borradorExistente.ficha);
        const faltantes = camposFaltantes(borradorExistente.ficha);
        return {
          mensaje:
            borradorExistente.historial[borradorExistente.historial.length - 1]
              ?.texto || construirSaludoInicial(generoAdmin),
          entrevista_completada: sigPaso === null,
          ficha: borradorExistente.ficha,
          paso_actual: sigPaso ? sigPaso.id : 'completado',
          numero_paso: sigPaso ? sigPaso.numero : PASOS_ENTREVISTA.length,
          total_pasos: PASOS_ENTREVISTA.length,
          porcentaje_progreso: calcularPorcentajeProgreso(borradorExistente.ficha),
          campos_faltantes: faltantes,
          historial_guardado: borradorExistente.historial,
          guardado_en_bd: true,
          reanudado: true,
        };
      }
    }

    const fichaInicial = normalizarFicha({}, {}, limites);
    const saludo = construirSaludoInicial(generoAdmin);
    const historialInicial = [{ rol: 'asistente', texto: saludo }];

    if (idAdmin) {
      await guardarBorradorMascotaEnBd(
        idAdmin,
        fichaInicial,
        'informacion_basica',
        historialInicial,
      );
    }

    return {
      mensaje: saludo,
      entrevista_completada: false,
      ficha: fichaInicial,
      paso_actual: 'informacion_basica',
      numero_paso: 1,
      total_pasos: PASOS_ENTREVISTA.length,
      porcentaje_progreso: calcularPorcentajeProgreso(fichaInicial),
      campos_faltantes: camposFaltantes(fichaInicial),
      historial_guardado: historialInicial,
      guardado_en_bd: true,
      reanudado: false,
    };
  }

  // Cargar el borrador guardado en BD y combinar con la ficha actual
  let baseGuardada = {};
  if (idAdmin) {
    const enBd = await obtenerBorradorMascotaDeBd(idAdmin);
    if (enBd?.ficha) baseGuardada = enBd.ficha;
  }
  const fichaPrevia = normalizarFicha(ficha, baseGuardada, limites);
  const pasoEnCurso =
    determinarSiguientePaso(fichaPrevia) ||
    PASOS_ENTREVISTA[PASOS_ENTREVISTA.length - 1];

  const messages = construirMensajesPasoAPaso({
    fichaActual: fichaPrevia,
    pasoEnCurso,
    historial,
    respuestaAdmin: textoUsuario,
    limites,
    generoAdmin,
  });

  const resp = await completarConGptLuna(messages);
  const cuerpo = await resp.json();
  const contenido = textoDeMensaje(cuerpo?.choices?.[0]?.message);
  const crudo = extraerJson(contenido);

  const necesitaAclaracion =
    crudo?.necesita_aclaracion === true || crudo?.excede_limite === true;

  // Si la respuesta fue fuera de tema o ambigua, NO modificamos los datos de la mascota
  const fichaActualizada = necesitaAclaracion
    ? fichaPrevia
    : normalizarFicha(crudo?.nuevos_datos || {}, fichaPrevia, limites);

  const siguientePaso = determinarSiguientePaso(fichaActualizada);
  const completada = !necesitaAclaracion && siguientePaso === null;
  if (completada && !fichaActualizada.raza) {
    fichaActualizada.raza = 'Mestizo';
  } else if (fichaActualizada.raza) {
    fichaActualizada.raza = canonRaza(fichaActualizada.raza, limites.raza || 50);
  }
  const faltantes = camposFaltantes(fichaActualizada);
  const porcentajeProgreso = calcularPorcentajeProgreso(fichaActualizada);

  const mensajeCierreRevision =
    '¡Qué alegría! Ya conocemos mucho mejor a nuestro peludito. 💗 Vamos a revisar su información para asegurarnos de que todo esté correcto.';

  let mensajeRespuesta = String(crudo?.mensaje || '').trim();
  if (completada) {
    mensajeRespuesta = mensajeCierreRevision;
  } else if (!mensajeRespuesta) {
    if (necesitaAclaracion) {
      mensajeRespuesta =
        'Perdóname, creo que no entendí muy bien. ¿Me lo puedes explicar de otra manera? Quiero asegurarme de guardar correctamente la información.';
    } else {
      mensajeRespuesta = `¡Ahora entiendo mejor cómo es! 💗 ${preguntaPersonalizadaPaso(siguientePaso, fichaActualizada)}`;
    }
  }

  const historialActualizado = [
    ...historial,
    { rol: 'usuario', texto: textoUsuario },
    { rol: 'asistente', texto: mensajeRespuesta },
  ];

  // Guardar progresivamente en PostgreSQL antes de pasar a la siguiente pregunta
  if (idAdmin) {
    await guardarBorradorMascotaEnBd(
      idAdmin,
      fichaActualizada,
      siguientePaso ? siguientePaso.id : 'completado',
      historialActualizado,
    );
  }

  return {
    mensaje: mensajeRespuesta,
    necesita_aclaracion: necesitaAclaracion,
    confirmacion_guardado: necesitaAclaracion
      ? null
      : String(crudo?.confirmacion_guardado || 'Progreso guardado').trim(),
    entrevista_completada: completada,
    ficha: fichaActualizada,
    paso_actual: siguientePaso ? siguientePaso.id : 'completado',
    numero_paso: siguientePaso ? siguientePaso.numero : PASOS_ENTREVISTA.length,
    total_pasos: PASOS_ENTREVISTA.length,
    porcentaje_progreso: porcentajeProgreso,
    campos_faltantes: faltantes,
    guardado_en_bd: true,
  };
}

module.exports = {
  OPCIONES_ESTADO_SALUD,
  PASOS_ENTREVISTA,
  asegurarTablaBorradorMascota,
  obtenerLimitesColumnasMascota,
  normalizarFicha,
  camposFaltantes,
  calcularPorcentajeProgreso,
  guardarBorradorMascotaEnBd,
  obtenerBorradorMascotaDeBd,
  listarBorradoresMascotaDeBd,
  eliminarBorradorMascotaDeBd,
  procesarTurnoEntrevistaMascota,
};
