-- Esquema PawMatch para Cloudflare D1 (SQLite).
-- Traducido del esquema real de PostgreSQL y de las tablas que el backend crea al arrancar.
-- No ejecuta nada sobre la base PostgreSQL.
--
-- D1 no tiene tipos ENUM, UUID, JSONB, BOOLEAN ni gen_random_uuid().
-- Los identificadores son TEXT. Las fechas son TEXT en formato ISO.
-- Los booleanos son INTEGER: 0 falso, 1 verdadero.
-- Los JSON se guardan como TEXT.
--
-- Donde PostgreSQL usa gen_random_uuid(), el valor predeterminado es esta expresión:
-- (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6))))

PRAGMA foreign_keys = ON;

CREATE TABLE usuario (
  id_usuario TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  nombres TEXT NOT NULL,
  apellidos TEXT NOT NULL,
  correo TEXT NOT NULL UNIQUE,
  telefono TEXT,
  direccion TEXT,
  documento_identidad TEXT UNIQUE,
  fecha_nacimiento TEXT,
  fecha_registro TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  rol TEXT NOT NULL DEFAULT 'usuario' CHECK (rol IN ('usuario', 'administrador', 'superadmin')),
  estado_cuenta TEXT NOT NULL DEFAULT 'activo' CHECK (estado_cuenta IN ('activo', 'inactivo', 'suspendido')),
  foto_perfil TEXT,
  contrasena_hash TEXT NOT NULL,
  token_recuperacion TEXT,
  token_recuperacion_expira TEXT,
  bloqueado_apadrinar INTEGER DEFAULT 0 CHECK (bloqueado_apadrinar IS NULL OR bloqueado_apadrinar IN (0, 1)),
  genero TEXT CHECK (genero IS NULL OR genero IN ('Hombre', 'Mujer')),
  voz_asistente TEXT DEFAULT 'marin'
);

CREATE TABLE informacionfundacion (
  id_fundacion TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  nombre TEXT NOT NULL,
  descripcion TEXT,
  mision TEXT,
  vision TEXT,
  direccion TEXT,
  telefono TEXT,
  correo TEXT,
  redes_sociales TEXT,
  logo TEXT,
  ciudad TEXT,
  imagen_principal TEXT,
  imagen_fondo TEXT,
  rescatista_nombre TEXT,
  rescatista_texto TEXT,
  rescatista_foto TEXT,
  mapa_url TEXT,
  ayuda_adopta_titulo TEXT,
  ayuda_adopta_texto TEXT,
  ayuda_apadrina_titulo TEXT,
  ayuda_apadrina_texto TEXT,
  contacto_texto TEXT
);

CREATE TABLE mascota (
  id_mascota TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  nombre TEXT NOT NULL,
  especie TEXT NOT NULL,
  raza TEXT,
  edad INTEGER,
  sexo TEXT,
  tamano TEXT,
  descripcion TEXT,
  esterilizado INTEGER DEFAULT 0 CHECK (esterilizado IS NULL OR esterilizado IN (0, 1)),
  vacunas INTEGER DEFAULT 0 CHECK (vacunas IS NULL OR vacunas IN (0, 1)),
  fotos TEXT,
  fecha_ingreso TEXT NOT NULL DEFAULT CURRENT_DATE,
  estado_adopcion TEXT NOT NULL DEFAULT 'disponible' CHECK (estado_adopcion IN ('disponible', 'en_proceso', 'adoptado')),
  estado_apadrinamiento TEXT NOT NULL DEFAULT 'disponible' CHECK (estado_apadrinamiento IN ('disponible', 'apadrinado')),
  id_administrador TEXT NOT NULL REFERENCES usuario(id_usuario),
  unidad_edad TEXT NOT NULL DEFAULT 'anos',
  estado_salud TEXT NOT NULL DEFAULT '["No presenta necesidades veterinarias pendientes."]',
  detalle_salud TEXT,
  fecha_actualizacion TEXT DEFAULT CURRENT_TIMESTAMP,
  personalidad_definida INTEGER NOT NULL DEFAULT 1 CHECK (personalidad_definida IN (0, 1)),
  fecha_nacimiento TEXT,
  fecha_creacion TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Tabla que el backend crea al arrancar y con la que trabaja hoy.
-- El volcado de PostgreSQL todavía contiene borrador_registro_mascota_luna;
-- el proceso actual la elimina y usa esta.
CREATE TABLE borrador_mascota_formulario_ia (
  id_borrador TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_administrador TEXT NOT NULL UNIQUE REFERENCES usuario(id_usuario) ON DELETE CASCADE,
  nombre TEXT,
  especie TEXT,
  sexo TEXT,
  edad INTEGER,
  unidad_edad TEXT,
  fecha_nacimiento TEXT,
  raza TEXT,
  tamano TEXT,
  es_cachorro_en_proceso INTEGER CHECK (es_cachorro_en_proceso IS NULL OR es_cachorro_en_proceso IN (0, 1)),
  personalidad_definida INTEGER CHECK (personalidad_definida IS NULL OR personalidad_definida IN (0, 1)),
  personalidad TEXT NOT NULL DEFAULT '{}',
  estado_salud TEXT NOT NULL DEFAULT '[]',
  vacunas INTEGER CHECK (vacunas IS NULL OR vacunas IN (0, 1)),
  esterilizado INTEGER CHECK (esterilizado IS NULL OR esterilizado IN (0, 1)),
  detalle_salud TEXT,
  descripcion TEXT,
  salud_consultada INTEGER NOT NULL DEFAULT 0 CHECK (salud_consultada IN (0, 1)),
  historia_consultada INTEGER NOT NULL DEFAULT 0 CHECK (historia_consultada IN (0, 1)),
  paso_actual TEXT NOT NULL DEFAULT 'nombre',
  historial_chat TEXT NOT NULL DEFAULT '[]',
  origen_registro TEXT NOT NULL DEFAULT 'ia',
  foto TEXT,
  estado_adopcion TEXT DEFAULT 'disponible',
  estado_apadrinamiento TEXT DEFAULT 'disponible',
  fecha_actualizacion TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE borrador_entrevista_personalidad (
  id_borrador TEXT PRIMARY KEY,
  id_usuario TEXT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
  clave_pregunta TEXT NOT NULL CHECK (clave_pregunta IN (
    'nivel_energia', 'sociabilidad_personas', 'sociabilidad_mascotas', 'independencia',
    'nivel_juego', 'carino', 'proteccion', 'tolerancia_soledad', 'adaptabilidad'
  )),
  respuesta_original TEXT NOT NULL,
  puntuacion INTEGER NOT NULL CHECK (puntuacion >= 1 AND puntuacion <= 5),
  justificacion TEXT NOT NULL,
  actualizado TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (id_usuario, clave_pregunta)
);

CREATE TABLE preguntapersonalidad (
  id_pregunta TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  dimension TEXT NOT NULL,
  pregunta_persona TEXT NOT NULL,
  pregunta_mascota TEXT NOT NULL,
  descripcion TEXT,
  activa INTEGER NOT NULL DEFAULT 1 CHECK (activa IN (0, 1))
);

CREATE TABLE personalidadusuario (
  id_perfil_usuario TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_usuario TEXT NOT NULL UNIQUE REFERENCES usuario(id_usuario),
  nivel_energia INTEGER,
  sociabilidad_personas INTEGER,
  sociabilidad_mascotas INTEGER,
  independencia INTEGER,
  nivel_juego INTEGER,
  carino INTEGER,
  proteccion INTEGER,
  tolerancia_soledad INTEGER,
  adaptabilidad INTEGER,
  fecha_actualizacion TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_mascota_match_inicial TEXT REFERENCES mascota(id_mascota) ON DELETE SET NULL,
  porcentaje_match_inicial REAL,
  fecha_match_inicial TEXT,
  aviso_reasignacion_pendiente INTEGER NOT NULL DEFAULT 0 CHECK (aviso_reasignacion_pendiente IN (0, 1)),
  nombre_match_anterior TEXT,
  id_aviso_reasignacion TEXT,
  CHECK (
    (nivel_energia IS NULL OR nivel_energia BETWEEN 1 AND 5)
    AND (sociabilidad_personas IS NULL OR sociabilidad_personas BETWEEN 1 AND 5)
    AND (sociabilidad_mascotas IS NULL OR sociabilidad_mascotas BETWEEN 1 AND 5)
    AND (independencia IS NULL OR independencia BETWEEN 1 AND 5)
    AND (nivel_juego IS NULL OR nivel_juego BETWEEN 1 AND 5)
    AND (carino IS NULL OR carino BETWEEN 1 AND 5)
    AND (proteccion IS NULL OR proteccion BETWEEN 1 AND 5)
    AND (tolerancia_soledad IS NULL OR tolerancia_soledad BETWEEN 1 AND 5)
    AND (adaptabilidad IS NULL OR adaptabilidad BETWEEN 1 AND 5)
  )
);

CREATE TABLE personalidadmascota (
  id_perfil_mascota TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_mascota TEXT NOT NULL UNIQUE REFERENCES mascota(id_mascota),
  nivel_energia INTEGER,
  sociabilidad_personas INTEGER,
  sociabilidad_mascotas INTEGER,
  independencia INTEGER,
  nivel_juego INTEGER,
  carino INTEGER,
  proteccion INTEGER,
  tolerancia_soledad INTEGER,
  adaptabilidad INTEGER,
  fecha_actualizacion TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (
    (nivel_energia IS NULL OR nivel_energia BETWEEN 1 AND 5)
    AND (sociabilidad_personas IS NULL OR sociabilidad_personas BETWEEN 1 AND 5)
    AND (sociabilidad_mascotas IS NULL OR sociabilidad_mascotas BETWEEN 1 AND 5)
    AND (independencia IS NULL OR independencia BETWEEN 1 AND 5)
    AND (nivel_juego IS NULL OR nivel_juego BETWEEN 1 AND 5)
    AND (carino IS NULL OR carino BETWEEN 1 AND 5)
    AND (proteccion IS NULL OR proteccion BETWEEN 1 AND 5)
    AND (tolerancia_soledad IS NULL OR tolerancia_soledad BETWEEN 1 AND 5)
    AND (adaptabilidad IS NULL OR adaptabilidad BETWEEN 1 AND 5)
  )
);

CREATE TABLE respuesta_entrevista_personalidad (
  id_respuesta TEXT PRIMARY KEY,
  id_perfil_usuario TEXT NOT NULL REFERENCES personalidadusuario(id_perfil_usuario) ON DELETE CASCADE,
  id_usuario TEXT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
  clave_pregunta TEXT NOT NULL CHECK (clave_pregunta IN (
    'nivel_energia', 'sociabilidad_personas', 'sociabilidad_mascotas', 'independencia',
    'nivel_juego', 'carino', 'proteccion', 'tolerancia_soledad', 'adaptabilidad'
  )),
  respuesta_original TEXT NOT NULL,
  puntuacion INTEGER NOT NULL CHECK (puntuacion >= 1 AND puntuacion <= 5),
  justificacion TEXT NOT NULL,
  fecha_registro TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (id_usuario, clave_pregunta)
);

CREATE TABLE respuestamascota (
  id_respuesta_mascota TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_mascota TEXT NOT NULL REFERENCES mascota(id_mascota),
  id_pregunta TEXT NOT NULL REFERENCES preguntapersonalidad(id_pregunta),
  valor INTEGER NOT NULL CHECK (valor BETWEEN 1 AND 5),
  id_administrador TEXT NOT NULL REFERENCES usuario(id_usuario),
  fecha_respuesta TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (id_mascota, id_pregunta)
);

CREATE TABLE respuestausuario (
  id_respuesta_usuario TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_usuario TEXT NOT NULL REFERENCES usuario(id_usuario),
  id_pregunta TEXT NOT NULL REFERENCES preguntapersonalidad(id_pregunta),
  valor INTEGER NOT NULL CHECK (valor BETWEEN 1 AND 5),
  fecha_respuesta TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (id_usuario, id_pregunta)
);

CREATE TABLE match (
  id_match TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_perfil_usuario TEXT NOT NULL REFERENCES personalidadusuario(id_perfil_usuario),
  id_perfil_mascota TEXT NOT NULL REFERENCES personalidadmascota(id_perfil_mascota),
  porcentaje_match REAL NOT NULL CHECK (porcentaje_match >= 0 AND porcentaje_match <= 100),
  fecha_calculo TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE noticia (
  id_noticia TEXT PRIMARY KEY,
  titulo TEXT NOT NULL,
  contenido TEXT NOT NULL,
  imagen TEXT,
  lugar TEXT NOT NULL DEFAULT 'Fundación Maritza Arévalo, Cali',
  fecha TEXT NOT NULL DEFAULT CURRENT_DATE,
  fecha_creacion TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_administrador TEXT REFERENCES usuario(id_usuario)
);

CREATE TABLE noticia_like (
  id_noticia TEXT NOT NULL REFERENCES noticia(id_noticia) ON DELETE CASCADE,
  id_usuario TEXT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
  PRIMARY KEY (id_noticia, id_usuario)
);

CREATE TABLE notificacion_match_usuario (
  id_notificacion TEXT PRIMARY KEY,
  id_usuario TEXT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
  id_mascota TEXT NOT NULL REFERENCES mascota(id_mascota) ON DELETE CASCADE,
  porcentaje_match REAL NOT NULL,
  leida INTEGER NOT NULL DEFAULT 0 CHECK (leida IN (0, 1)),
  mostrada_en_mascotas INTEGER NOT NULL DEFAULT 0 CHECK (mostrada_en_mascotas IN (0, 1)),
  fecha_creacion TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_lectura TEXT,
  UNIQUE (id_usuario, id_mascota)
);

CREATE TABLE solicitudadopcion (
  id_solicitud_adopcion TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_usuario TEXT NOT NULL REFERENCES usuario(id_usuario),
  id_mascota TEXT NOT NULL REFERENCES mascota(id_mascota),
  tipo_vivienda TEXT,
  tiene_patio INTEGER CHECK (tiene_patio IS NULL OR tiene_patio IN (0, 1)),
  tiene_ninos INTEGER CHECK (tiene_ninos IS NULL OR tiene_ninos IN (0, 1)),
  tiene_mascotas INTEGER CHECK (tiene_mascotas IS NULL OR tiene_mascotas IN (0, 1)),
  otras_mascotas TEXT,
  tiempo_disponible TEXT,
  experiencia_previa INTEGER CHECK (experiencia_previa IS NULL OR experiencia_previa IN (0, 1)),
  informacion_adicional TEXT,
  fecha_solicitud TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'aprobada', 'rechazada', 'cancelada')),
  fecha_actualizacion_estado TEXT,
  id_administrador_revisor TEXT REFERENCES usuario(id_usuario),
  foto_cedula TEXT,
  foto_servicios_publicos TEXT,
  observaciones TEXT,
  leido_admin INTEGER NOT NULL DEFAULT 0 CHECK (leido_admin IN (0, 1)),
  leido_usuario INTEGER NOT NULL DEFAULT 1 CHECK (leido_usuario IN (0, 1)),
  fecha_inicio_adopcion TEXT,
  correo_contacto TEXT,
  contrato_adopcion_archivo TEXT,
  contrato_adopcion_estado TEXT,
  contrato_adopcion_subido_en TEXT,
  estado_correo TEXT DEFAULT 'pendiente',
  token_verificacion_correo TEXT,
  fecha_verificacion_correo TEXT,
  acepto_requisitos INTEGER DEFAULT 1 CHECK (acepto_requisitos IS NULL OR acepto_requisitos IN (0, 1)),
  fecha_aceptacion_requisitos TEXT DEFAULT CURRENT_TIMESTAMP,
  estado_seguimiento TEXT DEFAULT 'activa'
);

CREATE TABLE solicitudapadrinamiento (
  id_solicitud_apadrinamiento TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_usuario TEXT NOT NULL REFERENCES usuario(id_usuario),
  id_mascota TEXT NOT NULL REFERENCES mascota(id_mascota),
  fecha_solicitud TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  monto_aporte INTEGER,
  frecuencia_aporte TEXT,
  informacion_adicional TEXT,
  estado TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'aprobada', 'rechazada', 'cancelada')),
  observaciones TEXT,
  fecha_actualizacion_estado TEXT,
  documento_identidad_archivo TEXT,
  acuerdo_responsabilidad INTEGER NOT NULL DEFAULT 0 CHECK (acuerdo_responsabilidad IN (0, 1)),
  fecha_acuerdo_responsabilidad TEXT,
  fecha_inicio_apadrinamiento TEXT,
  leido_admin INTEGER NOT NULL DEFAULT 0 CHECK (leido_admin IN (0, 1)),
  leido_usuario INTEGER NOT NULL DEFAULT 1 CHECK (leido_usuario IN (0, 1)),
  contrato_apadrinamiento_archivo TEXT,
  veces_rechazada INTEGER DEFAULT 1,
  correo_contacto TEXT,
  tipo_aporte TEXT DEFAULT 'Aporte monetario.',
  detalle_especie TEXT,
  estado_correo TEXT DEFAULT 'pendiente',
  token_verificacion_correo TEXT,
  fecha_verificacion_correo TEXT,
  acepto_requisitos INTEGER DEFAULT 1 CHECK (acepto_requisitos IS NULL OR acepto_requisitos IN (0, 1)),
  fecha_aceptacion_requisitos TEXT DEFAULT CURRENT_TIMESTAMP,
  estado_apadrinamiento TEXT DEFAULT 'activa' CHECK (estado_apadrinamiento IN ('activa', 'cancelada', 'finalizada')),
  motivo_cancelacion TEXT,
  fecha_cancelacion TEXT,
  decision_admin TEXT,
  nota_decision TEXT,
  id_admin_decision TEXT,
  fecha_decision TEXT,
  fecha_vista_usuario TEXT,
  eliminar_despues_de TEXT,
  aporta_monetario INTEGER DEFAULT 0 CHECK (aporta_monetario IS NULL OR aporta_monetario IN (0, 1)),
  monto_comprometido REAL,
  periodicidad TEXT,
  aporta_especie INTEGER DEFAULT 0 CHECK (aporta_especie IS NULL OR aporta_especie IN (0, 1)),
  aporta_otro INTEGER DEFAULT 0 CHECK (aporta_otro IS NULL OR aporta_otro IN (0, 1)),
  detalle_otro TEXT,
  observacion_cancelacion TEXT,
  foto_cancelacion TEXT
);

CREATE TABLE notificaciones (
  id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_usuario TEXT REFERENCES usuario(id_usuario) ON DELETE CASCADE,
  id_solicitud_apadrinamiento TEXT REFERENCES solicitudapadrinamiento(id_solicitud_apadrinamiento) ON DELETE CASCADE,
  tipo TEXT,
  titulo TEXT,
  mensaje TEXT,
  leida INTEGER DEFAULT 0 CHECK (leida IS NULL OR leida IN (0, 1)),
  fecha TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE evaluacion_ciclo (
  id_evaluacion TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_solicitud_apadrinamiento TEXT NOT NULL REFERENCES solicitudapadrinamiento(id_solicitud_apadrinamiento) ON DELETE CASCADE,
  ciclo INTEGER NOT NULL,
  promedio REAL NOT NULL,
  puntuacion TEXT NOT NULL,
  decision TEXT NOT NULL,
  nota TEXT,
  id_administrador TEXT REFERENCES usuario(id_usuario),
  fecha_decision TEXT NOT NULL DEFAULT CURRENT_DATE,
  visto_por_usuario INTEGER DEFAULT 0 CHECK (visto_por_usuario IS NULL OR visto_por_usuario IN (0, 1)),
  fecha_vista_usuario TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (id_solicitud_apadrinamiento, ciclo)
);

CREATE TABLE evaluacion_ciclo_adopcion (
  id_evaluacion TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_solicitud_adopcion TEXT NOT NULL REFERENCES solicitudadopcion(id_solicitud_adopcion) ON DELETE CASCADE,
  ciclo INTEGER NOT NULL,
  promedio REAL NOT NULL,
  puntuacion TEXT NOT NULL,
  decision TEXT NOT NULL,
  nota TEXT,
  id_administrador TEXT REFERENCES usuario(id_usuario),
  fecha_decision TEXT NOT NULL DEFAULT CURRENT_DATE,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (id_solicitud_adopcion, ciclo)
);

CREATE TABLE seguimientoadopcion (
  id_seguimiento_adopcion TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_solicitud_adopcion TEXT NOT NULL REFERENCES solicitudadopcion(id_solicitud_adopcion),
  id_administrador TEXT NOT NULL REFERENCES usuario(id_usuario),
  fecha_seguimiento TEXT NOT NULL DEFAULT CURRENT_DATE,
  observaciones TEXT,
  proxima_fecha_seguimiento TEXT,
  calificacion INTEGER,
  cumplimiento INTEGER DEFAULT 1 CHECK (cumplimiento IS NULL OR cumplimiento IN (0, 1)),
  numero_seguimiento INTEGER,
  ciclo INTEGER,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  peso_saludable INTEGER,
  condicion_sanitaria INTEGER,
  entorno_apto INTEGER,
  comportamiento INTEGER,
  compromiso_veterinario INTEGER,
  disposicion_adoptante INTEGER,
  foto_estado TEXT,
  foto_entorno TEXT
);

CREATE TABLE seguimientoapadrinamiento (
  id_seguimiento_apadrinacion TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_solicitud_apadrinamiento TEXT NOT NULL REFERENCES solicitudapadrinamiento(id_solicitud_apadrinamiento),
  id_administrador TEXT NOT NULL REFERENCES usuario(id_usuario),
  fecha_seguimiento TEXT NOT NULL DEFAULT CURRENT_DATE,
  cumplimiento INTEGER CHECK (cumplimiento IS NULL OR cumplimiento IN (0, 1)),
  observaciones TEXT,
  proximo_seguimiento TEXT,
  calificacion INTEGER CHECK (calificacion IS NULL OR (calificacion >= 1 AND calificacion <= 5)),
  correo_alerta_enviado INTEGER DEFAULT 0 CHECK (correo_alerta_enviado IS NULL OR correo_alerta_enviado IN (0, 1)),
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  numero_seguimiento INTEGER,
  ciclo INTEGER
);

CREATE TABLE seguimiento_aporte (
  id_aporte TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_seguimiento_apadrinacion TEXT NOT NULL REFERENCES seguimientoapadrinamiento(id_seguimiento_apadrinacion) ON DELETE CASCADE,
  tipo TEXT NOT NULL,
  comprometido TEXT,
  recibido INTEGER NOT NULL DEFAULT 1 CHECK (recibido IN (0, 1)),
  medio TEXT,
  monto_recibido REAL,
  referencia TEXT,
  detalle_recibido TEXT,
  observacion TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cancelacion_adopcion (
  id_cancelacion TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_solicitud_adopcion TEXT NOT NULL UNIQUE REFERENCES solicitudadopcion(id_solicitud_adopcion) ON DELETE CASCADE,
  id_mascota TEXT NOT NULL REFERENCES mascota(id_mascota),
  id_usuario TEXT NOT NULL REFERENCES usuario(id_usuario),
  id_administrador TEXT NOT NULL REFERENCES usuario(id_usuario),
  fecha_cancelacion TEXT NOT NULL DEFAULT CURRENT_DATE,
  motivo TEXT NOT NULL,
  observacion TEXT NOT NULL,
  foto_1 TEXT,
  foto_2 TEXT,
  inhabilitar_cuenta INTEGER NOT NULL DEFAULT 0 CHECK (inhabilitar_cuenta IN (0, 1)),
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE denuncia (
  id_denuncia TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  radicado TEXT NOT NULL UNIQUE,
  id_usuario TEXT REFERENCES usuario(id_usuario) ON DELETE SET NULL,
  es_anonimo INTEGER DEFAULT 0 CHECK (es_anonimo IS NULL OR es_anonimo IN (0, 1)),
  nombre_reportante TEXT,
  documento_reportante TEXT,
  correo_reportante TEXT,
  telefono_reportante TEXT,
  ciudad_reportante TEXT,
  barrio_reportante TEXT,
  tipo_reporte TEXT NOT NULL,
  tipo_animal TEXT NOT NULL,
  ubicacion_animal TEXT NOT NULL,
  ciudad_caso TEXT NOT NULL,
  fecha_situacion TEXT NOT NULL,
  peligro_inmediato TEXT NOT NULL DEFAULT 'no',
  descripcion_caso TEXT NOT NULL,
  caracteristicas_animal TEXT,
  estado_salud TEXT,
  heridas_visibles TEXT,
  dificultad_movilidad TEXT,
  condiciones_lugar TEXT,
  observaciones_adicionales TEXT,
  acepto_politica INTEGER DEFAULT 1 CHECK (acepto_politica IS NULL OR acepto_politica IN (0, 1)),
  estado TEXT DEFAULT 'recibido',
  leido_admin INTEGER DEFAULT 0 CHECK (leido_admin IS NULL OR leido_admin IN (0, 1)),
  observaciones_internas TEXT,
  acciones_realizadas TEXT,
  estado_correo TEXT DEFAULT 'pendiente',
  error_correo TEXT,
  fecha_creacion TEXT DEFAULT CURRENT_TIMESTAMP,
  fecha_actualizacion TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE denuncia_archivo (
  id_archivo TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_denuncia TEXT NOT NULL REFERENCES denuncia(id_denuncia) ON DELETE CASCADE,
  nombre_original TEXT NOT NULL,
  nombre_guardado TEXT NOT NULL,
  ruta_archivo TEXT NOT NULL,
  tipo_mime TEXT,
  tamano_bytes INTEGER,
  es_video INTEGER DEFAULT 0 CHECK (es_video IS NULL OR es_video IN (0, 1)),
  fecha_subida TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE denuncia_historial (
  id_historial TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_denuncia TEXT NOT NULL REFERENCES denuncia(id_denuncia) ON DELETE CASCADE,
  id_usuario_admin TEXT REFERENCES usuario(id_usuario) ON DELETE SET NULL,
  nombre_admin TEXT,
  estado_anterior TEXT,
  estado_nuevo TEXT,
  observacion TEXT,
  fecha TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE valoracion_usuario (
  id_valoracion TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-' || substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6)))),
  id_usuario TEXT NOT NULL REFERENCES usuario(id_usuario),
  id_administrador TEXT NOT NULL REFERENCES usuario(id_usuario),
  comentarios TEXT NOT NULL,
  fecha_valoracion TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE VIEW vista_resumen_padrinos AS
SELECT
  u.id_usuario,
  u.nombres,
  u.apellidos,
  u.correo,
  COALESCE(u.bloqueado_apadrinar, 0) AS bloqueado_apadrinar,
  COALESCE(ROUND(AVG(seg.calificacion), 1), 0.0) AS calificacion_promedio,
  COUNT(seg.id_seguimiento_apadrinacion) AS total_seguimientos,
  COUNT(CASE WHEN seg.cumplimiento = 0 OR seg.calificacion <= 2 THEN 1 END) AS total_incumplimientos
FROM usuario u
LEFT JOIN solicitudapadrinamiento sa ON sa.id_usuario = u.id_usuario
LEFT JOIN seguimientoapadrinamiento seg ON seg.id_solicitud_apadrinamiento = sa.id_solicitud_apadrinamiento
GROUP BY u.id_usuario, u.nombres, u.apellidos, u.correo, u.bloqueado_apadrinar;

CREATE INDEX idx_mascota_estado_adopcion ON mascota (estado_adopcion);
CREATE INDEX idx_mascota_estado_apadrinamiento ON mascota (estado_apadrinamiento);
CREATE INDEX idx_solicitud_adopcion_usuario ON solicitudadopcion (id_usuario);
CREATE INDEX idx_solicitud_apadrinamiento_usuario ON solicitudapadrinamiento (id_usuario);
CREATE INDEX idx_usuario_rol ON usuario (rol);
CREATE INDEX idx_solicitud_adopcion_estado ON solicitudadopcion (estado);
CREATE INDEX idx_solicitud_apadrinamiento_estado ON solicitudapadrinamiento (estado);
CREATE INDEX idx_denuncia_estado ON denuncia (estado);
CREATE INDEX idx_noticia_fecha ON noticia (fecha);
