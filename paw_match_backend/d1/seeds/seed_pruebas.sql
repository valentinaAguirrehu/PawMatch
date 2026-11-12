-- Datos ficticios para el entorno local. INSERT OR IGNORE omite la fila si la clave ya existe
-- y no reemplaza registros. La contraseña de las dos cuentas es Prueba#2026.
-- El valor guardado es un hash bcrypt de costo 10. No hay datos personales reales.

INSERT OR IGNORE INTO usuario (
  id_usuario, nombres, apellidos, correo, telefono, fecha_nacimiento, rol, estado_cuenta,
  contrasena_hash, genero, voz_asistente, bloqueado_apadrinar
) VALUES
(
  'a1111111-1111-4111-8111-111111111111',
  'Admin',
  'Prueba',
  'admin.prueba@example.com',
  '3000000001',
  '1990-01-15',
  'administrador',
  'activo',
  '$2b$10$ht6XVV1LkXxhH.IY01kahui4DbLM0OrjQhHwwSnh.xiaMA896GReW',
  'Mujer',
  'marin',
  0
),
(
  'a2222222-2222-4222-8222-222222222222',
  'Ana',
  'Ejemplo',
  'adoptante.prueba@example.com',
  '3000000002',
  '2000-06-20',
  'usuario',
  'activo',
  '$2b$10$ht6XVV1LkXxhH.IY01kahui4DbLM0OrjQhHwwSnh.xiaMA896GReW',
  'Mujer',
  'marin',
  0
);

INSERT OR IGNORE INTO informacionfundacion (
  id_fundacion, nombre, descripcion, mision, vision, ciudad, correo, telefono,
  ayuda_adopta_titulo, ayuda_adopta_texto, ayuda_apadrina_titulo, ayuda_apadrina_texto
) VALUES (
  'a3333333-3333-4333-8333-333333333333',
  'Fundación de prueba PawMatch',
  'Texto de demostración para la pantalla de la fundación.',
  'Cuidar animales de ejemplo mientras se prueba la aplicación.',
  'Una base de datos de prueba sin datos personales.',
  'Ciudad de prueba',
  'fundacion.prueba@example.com',
  '3000000000',
  'Adopta',
  'Conoce a las mascotas de prueba.',
  'Apadrina',
  'Apoya el cuidado de una mascota de prueba.'
);

INSERT OR IGNORE INTO mascota (
  id_mascota, nombre, especie, raza, edad, sexo, tamano, descripcion,
  esterilizado, vacunas, fecha_ingreso, estado_adopcion, estado_apadrinamiento,
  id_administrador, unidad_edad, personalidad_definida
) VALUES
(
  'a4444444-4444-4444-8444-444444444444',
  'Luna de prueba',
  'Perro',
  'Mestizo',
  2,
  'hembra',
  'mediano',
  'Mascota ficticia para probar adopción y match.',
  1, 1, '2026-01-10', 'disponible', 'disponible',
  'a1111111-1111-4111-8111-111111111111', 'anos', 1
),
(
  'a5555555-5555-4555-8555-555555555555',
  'Milo de prueba',
  'Gato',
  'Mestizo',
  1,
  'macho',
  'pequeño',
  'Mascota ficticia para probar apadrinamiento.',
  0, 1, '2026-02-01', 'disponible', 'disponible',
  'a1111111-1111-4111-8111-111111111111', 'anos', 1
);

INSERT OR IGNORE INTO preguntapersonalidad (id_pregunta, dimension, pregunta_persona, pregunta_mascota, descripcion, activa) VALUES
('b0000001-0000-4000-8000-000000000001', 'nivel_energia', '¿Qué tan activo/a te consideras en tu día a día?', '¿Cuál es el nivel de actividad física de la mascota?', 'Poco activo/a a muy activo/a', 1),
('b0000002-0000-4000-8000-000000000002', 'sociabilidad_personas', '¿Qué tan cómodo/a te sientes rodeado/a de nuevas personas?', '¿Qué tan sociable es con las personas?', 'Incómodo/a a muy cómodo/a', 1),
('b0000003-0000-4000-8000-000000000003', 'sociabilidad_mascotas', '¿Qué tan bien te llevas con otras mascotas o animales?', '¿Cuánto disfruta la compañía de otras mascotas?', 'Me cuesta a me llevo muy bien', 1),
('b0000004-0000-4000-8000-000000000004', 'independencia', '¿Prefieres pasar tiempo a solas realizando tus actividades?', '¿Qué tan independiente es?', 'Prefiero compañía a prefiero estar a solas', 1),
('b0000005-0000-4000-8000-000000000005', 'nivel_juego', '¿Qué tanto disfrutas dedicar tiempo a actividades recreativas o juegos?', '¿Qué tan juguetona es?', 'Casi nada a muchísimo', 1),
('b0000006-0000-4000-8000-000000000006', 'carino', '¿Qué tan expresivo/a y afectuoso/a te consideras?', '¿Qué tan afectuosa es?', 'Reservado/a a muy afectuoso/a', 1),
('b0000007-0000-4000-8000-000000000007', 'proteccion', '¿Te consideras una persona protectora y atenta con quienes te rodean?', '¿Qué tan protectora es?', 'Poco protector/a a muy protector/a', 1),
('b0000008-0000-4000-8000-000000000008', 'tolerancia_soledad', '¿Qué tan bien toleras pasar varias horas fuera de casa?', '¿Qué tan bien tolera estar sola?', 'Me cuesta a lo tolero muy bien', 1),
('b0000009-0000-4000-8000-000000000009', 'adaptabilidad', '¿Qué tan fácil te adaptas a cambios en tu rutina diaria?', '¿Qué tan fácil se adapta a cambios y lugares nuevos?', 'Me cuesta a me adapto fácil', 1);

INSERT OR IGNORE INTO personalidadusuario (
  id_perfil_usuario, id_usuario,
  nivel_energia, sociabilidad_personas, sociabilidad_mascotas, independencia,
  nivel_juego, carino, proteccion, tolerancia_soledad, adaptabilidad
) VALUES (
  'c2222222-2222-4222-8222-222222222222',
  'a2222222-2222-4222-8222-222222222222',
  4, 5, 4, 2, 4, 5, 3, 3, 4
);

INSERT OR IGNORE INTO personalidadmascota (
  id_perfil_mascota, id_mascota,
  nivel_energia, sociabilidad_personas, sociabilidad_mascotas, independencia,
  nivel_juego, carino, proteccion, tolerancia_soledad, adaptabilidad
) VALUES
(
  'c4444444-4444-4444-8444-444444444444',
  'a4444444-4444-4444-8444-444444444444',
  4, 5, 4, 2, 5, 5, 3, 2, 4
),
(
  'c5555555-5555-4555-8555-555555555555',
  'a5555555-5555-4555-8555-555555555555',
  2, 3, 2, 4, 2, 3, 2, 4, 3
);

INSERT OR IGNORE INTO respuestausuario (id_respuesta_usuario, id_usuario, id_pregunta, valor) VALUES
('f0000001-0000-4000-8000-000000000001', 'a2222222-2222-4222-8222-222222222222', 'b0000001-0000-4000-8000-000000000001', 4),
('f0000002-0000-4000-8000-000000000002', 'a2222222-2222-4222-8222-222222222222', 'b0000002-0000-4000-8000-000000000002', 5),
('f0000003-0000-4000-8000-000000000003', 'a2222222-2222-4222-8222-222222222222', 'b0000003-0000-4000-8000-000000000003', 4),
('f0000004-0000-4000-8000-000000000004', 'a2222222-2222-4222-8222-222222222222', 'b0000004-0000-4000-8000-000000000004', 2),
('f0000005-0000-4000-8000-000000000005', 'a2222222-2222-4222-8222-222222222222', 'b0000005-0000-4000-8000-000000000005', 4),
('f0000006-0000-4000-8000-000000000006', 'a2222222-2222-4222-8222-222222222222', 'b0000006-0000-4000-8000-000000000006', 5),
('f0000007-0000-4000-8000-000000000007', 'a2222222-2222-4222-8222-222222222222', 'b0000007-0000-4000-8000-000000000007', 3),
('f0000008-0000-4000-8000-000000000008', 'a2222222-2222-4222-8222-222222222222', 'b0000008-0000-4000-8000-000000000008', 3),
('f0000009-0000-4000-8000-000000000009', 'a2222222-2222-4222-8222-222222222222', 'b0000009-0000-4000-8000-000000000009', 4);

INSERT OR IGNORE INTO respuestamascota (id_respuesta_mascota, id_mascota, id_pregunta, valor, id_administrador) VALUES
('f1000001-0000-4000-8000-000000000001', 'a4444444-4444-4444-8444-444444444444', 'b0000001-0000-4000-8000-000000000001', 4, 'a1111111-1111-4111-8111-111111111111'),
('f1000002-0000-4000-8000-000000000002', 'a4444444-4444-4444-8444-444444444444', 'b0000002-0000-4000-8000-000000000002', 5, 'a1111111-1111-4111-8111-111111111111'),
('f1000003-0000-4000-8000-000000000003', 'a4444444-4444-4444-8444-444444444444', 'b0000003-0000-4000-8000-000000000003', 4, 'a1111111-1111-4111-8111-111111111111'),
('f1000004-0000-4000-8000-000000000004', 'a4444444-4444-4444-8444-444444444444', 'b0000004-0000-4000-8000-000000000004', 2, 'a1111111-1111-4111-8111-111111111111'),
('f1000005-0000-4000-8000-000000000005', 'a4444444-4444-4444-8444-444444444444', 'b0000005-0000-4000-8000-000000000005', 5, 'a1111111-1111-4111-8111-111111111111'),
('f1000006-0000-4000-8000-000000000006', 'a4444444-4444-4444-8444-444444444444', 'b0000006-0000-4000-8000-000000000006', 5, 'a1111111-1111-4111-8111-111111111111'),
('f1000007-0000-4000-8000-000000000007', 'a4444444-4444-4444-8444-444444444444', 'b0000007-0000-4000-8000-000000000007', 3, 'a1111111-1111-4111-8111-111111111111'),
('f1000008-0000-4000-8000-000000000008', 'a4444444-4444-4444-8444-444444444444', 'b0000008-0000-4000-8000-000000000008', 2, 'a1111111-1111-4111-8111-111111111111'),
('f1000009-0000-4000-8000-000000000009', 'a4444444-4444-4444-8444-444444444444', 'b0000009-0000-4000-8000-000000000009', 4, 'a1111111-1111-4111-8111-111111111111');

INSERT OR IGNORE INTO solicitudadopcion (
  id_solicitud_adopcion, id_usuario, id_mascota, tipo_vivienda, tiene_patio, tiene_ninos,
  tiene_mascotas, tiempo_disponible, experiencia_previa, informacion_adicional,
  estado, leido_admin, leido_usuario, correo_contacto, acepto_requisitos
) VALUES (
  'd1111111-1111-4111-8111-111111111111',
  'a2222222-2222-4222-8222-222222222222',
  'a4444444-4444-4444-8444-444444444444',
  'apartamento', 0, 0, 0, 'medio dia', 1,
  'Solicitud ficticia para probar el panel de adopciones.',
  'pendiente', 0, 1, 'adoptante.prueba@example.com', 1
);

INSERT OR IGNORE INTO solicitudapadrinamiento (
  id_solicitud_apadrinamiento, id_usuario, id_mascota, monto_aporte, frecuencia_aporte,
  informacion_adicional, estado, acuerdo_responsabilidad, correo_contacto,
  aporta_monetario, monto_comprometido, periodicidad
) VALUES (
  'd2222222-2222-4222-8222-222222222222',
  'a2222222-2222-4222-8222-222222222222',
  'a5555555-5555-4555-8555-555555555555',
  50000, 'mensual',
  'Solicitud ficticia para probar el panel de apadrinamientos.',
  'pendiente', 1, 'adoptante.prueba@example.com',
  1, 50000, 'mensual'
);

INSERT OR IGNORE INTO noticia (id_noticia, titulo, contenido, lugar, fecha, id_administrador) VALUES (
  'e1111111-1111-4111-8111-111111111111',
  'Jornada de prueba',
  'Noticia ficticia para comprobar el listado.',
  'Sede de prueba',
  '2026-03-01',
  'a1111111-1111-4111-8111-111111111111'
);
