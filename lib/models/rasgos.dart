import 'package:flutter/material.dart';

/// Un rasgo de personalidad. [clave] es EXACTAMENTE el nombre de la columna
/// en la tabla `personalidadmascota` (y de `personalidadusuario`, que se usará
/// en el cuestionario del usuario para calcular el match).
class Rasgo {
  final String clave;
  final String titulo;
  final String
  pregunta; // pregunta para la MASCOTA (evaluación de la fundación)
  final String minimo; // significado del 1 (en femenino / neutro)
  final String maximo; // significado del 5 (en femenino / neutro)
  final IconData icono;

  /// Pregunta y extremos de la escala cuando responde la persona adoptante.
  final String preguntaUsuario;
  final String minimoUsuario;
  final String maximoUsuario;

  /// Versión en masculino. Solo se define cuando la frase cambia
  /// (ej: "Muy activa" -> "Muy activo"); si es null, la frase es neutra.
  final String? minimoMasc;
  final String? maximoMasc;

  const Rasgo({
    required this.clave,
    required this.titulo,
    required this.pregunta,
    required this.minimo,
    required this.maximo,
    required this.icono,
    required this.preguntaUsuario,
    required this.minimoUsuario,
    required this.maximoUsuario,
    this.minimoMasc,
    this.maximoMasc,
  });

  static bool _esMacho(String? sexo) => sexo?.trim().toLowerCase() == 'macho';

  /// Texto del extremo bajo (1) concordando con el sexo de la mascota.
  String minimoPara(String? sexo) =>
      _esMacho(sexo) ? (minimoMasc ?? minimo) : minimo;

  /// Texto del extremo alto (5) concordando con el sexo de la mascota.
  String maximoPara(String? sexo) =>
      _esMacho(sexo) ? (maximoMasc ?? maximo) : maximo;
}

const rasgosMascota = <Rasgo>[
  Rasgo(
    clave: 'nivel_energia',
    titulo: 'Nivel de energía',
    pregunta: '¿Cuál es el nivel de actividad física de la mascota?',
    minimo: 'Muy tranquila',
    minimoMasc: 'Muy tranquilo',
    maximo: 'Muy activa',
    maximoMasc: 'Muy activo',
    icono: Icons.bolt,
    preguntaUsuario: '¿Qué tan activo/a te consideras en tu día a día?',
    minimoUsuario: 'Poco activo/a',
    maximoUsuario: 'Muy activo/a',
  ),
  Rasgo(
    clave: 'sociabilidad_personas',
    titulo: 'Sociabilidad con personas',
    pregunta: '¿Qué tan sociable es con las personas?',
    minimo: 'Reservada o tímida',
    minimoMasc: 'Reservado o tímido',
    maximo: 'Muy sociable',
    icono: Icons.groups,
    preguntaUsuario:
        '¿Qué tan cómodo/a te sientes rodeado/a de nuevas personas?',
    minimoUsuario: 'Incómodo/a',
    maximoUsuario: 'Muy cómodo/a',
  ),
  Rasgo(
    clave: 'sociabilidad_mascotas',
    titulo: 'Sociabilidad con mascotas',
    pregunta: '¿Cuánto disfruta la compañía de otras mascotas?',
    minimo: 'Prefiere estar sola',
    minimoMasc: 'Prefiere estar solo',
    maximo: 'Le encantan',
    icono: Icons.pets,
    preguntaUsuario: '¿Qué tan bien te llevas con otras mascotas o animales?',
    minimoUsuario: 'Me cuesta',
    maximoUsuario: 'Me llevo muy bien',
  ),
  Rasgo(
    clave: 'independencia',
    titulo: 'Independencia',
    pregunta: '¿Qué tan independiente es?',
    minimo: 'Necesita atención constante',
    maximo: 'Muy independiente',
    icono: Icons.directions_walk,
    preguntaUsuario:
        '¿Prefieres pasar tiempo a solas realizando tus actividades?',
    minimoUsuario: 'Prefiero compañía',
    maximoUsuario: 'Prefiero estar a solas',
  ),
  Rasgo(
    clave: 'nivel_juego',
    titulo: 'Nivel de juego',
    pregunta: '¿Qué tan juguetona es?',
    minimo: 'Poco juguetona',
    minimoMasc: 'Poco juguetón',
    maximo: 'Muy juguetona',
    maximoMasc: 'Muy juguetón',
    icono: Icons.sports_tennis,
    preguntaUsuario:
        '¿Qué tanto disfrutas dedicar tiempo a actividades recreativas o juegos?',
    minimoUsuario: 'Casi nada',
    maximoUsuario: 'Muchísimo',
  ),
  Rasgo(
    clave: 'carino',
    titulo: 'Cariño',
    pregunta: '¿Qué tan afectuosa es?',
    minimo: 'Poco afectuosa',
    minimoMasc: 'Poco afectuoso',
    maximo: 'Muy cariñosa',
    maximoMasc: 'Muy cariñoso',
    icono: Icons.favorite,
    preguntaUsuario: '¿Qué tan expresivo/a y afectuoso/a te consideras?',
    minimoUsuario: 'Reservado/a',
    maximoUsuario: 'Muy afectuoso/a',
  ),
  Rasgo(
    clave: 'proteccion',
    titulo: 'Protección',
    pregunta: '¿Qué tan protectora es?',
    minimo: 'Nada protectora',
    minimoMasc: 'Nada protector',
    maximo: 'Muy protectora',
    maximoMasc: 'Muy protector',
    icono: Icons.shield,
    preguntaUsuario:
        '¿Te consideras una persona protectora y atenta con quienes te rodean?',
    minimoUsuario: 'Poco protector/a',
    maximoUsuario: 'Muy protector/a',
  ),
  Rasgo(
    clave: 'tolerancia_soledad',
    titulo: 'Tolerancia a la soledad',
    pregunta: '¿Qué tan bien tolera estar sola?',
    minimo: 'No tolera la soledad',
    maximo: 'Tolera muy bien',
    icono: Icons.home,
    preguntaUsuario: '¿Qué tan bien toleras pasar varias horas fuera de casa?',
    minimoUsuario: 'Me cuesta',
    maximoUsuario: 'Lo tolero muy bien',
  ),
  Rasgo(
    clave: 'adaptabilidad',
    titulo: 'Adaptabilidad',
    pregunta: '¿Qué tan fácil se adapta a cambios y lugares nuevos?',
    minimo: 'Le cuesta adaptarse',
    maximo: 'Se adapta fácil',
    icono: Icons.swap_horiz,
    preguntaUsuario: '¿Qué tan fácil te adaptas a cambios en tu rutina diaria?',
    minimoUsuario: 'Me cuesta',
    maximoUsuario: 'Me adapto fácil',
  ),
];
