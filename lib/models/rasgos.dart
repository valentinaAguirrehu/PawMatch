import 'package:flutter/material.dart';

/// Un rasgo de personalidad. [clave] es EXACTAMENTE el nombre de la columna
/// en la tabla `personalidadmascota` (y de `personalidadusuario`, que se usará
/// en el cuestionario del usuario para calcular el match).
class Rasgo {
  final String clave;
  final String titulo;
  final String pregunta; // pregunta para la MASCOTA (evaluación de la fundación)
  final String minimo; // significado del 1
  final String maximo; // significado del 5
  final IconData icono;

  const Rasgo({
    required this.clave,
    required this.titulo,
    required this.pregunta,
    required this.minimo,
    required this.maximo,
    required this.icono,
  });
}

const rasgosMascota = <Rasgo>[
  Rasgo(
    clave: 'nivel_energia',
    titulo: 'Nivel de energía',
    pregunta: '¿Cuál es el nivel de actividad física de la mascota?',
    minimo: 'Muy tranquila',
    maximo: 'Muy activa',
    icono: Icons.bolt,
  ),
  Rasgo(
    clave: 'sociabilidad_personas',
    titulo: 'Sociabilidad con personas',
    pregunta: '¿Qué tan sociable es con las personas?',
    minimo: 'Reservada o tímida',
    maximo: 'Muy sociable',
    icono: Icons.groups,
  ),
  Rasgo(
    clave: 'sociabilidad_mascotas',
    titulo: 'Sociabilidad con mascotas',
    pregunta: '¿Cuánto disfruta la compañía de otras mascotas?',
    minimo: 'Prefiere estar sola',
    maximo: 'Le encantan',
    icono: Icons.pets,
  ),
  Rasgo(
    clave: 'independencia',
    titulo: 'Independencia',
    pregunta: '¿Qué tan independiente es?',
    minimo: 'Necesita atención constante',
    maximo: 'Muy independiente',
    icono: Icons.directions_walk,
  ),
  Rasgo(
    clave: 'nivel_juego',
    titulo: 'Nivel de juego',
    pregunta: '¿Qué tan juguetona es?',
    minimo: 'Poco juguetona',
    maximo: 'Muy juguetona',
    icono: Icons.sports_tennis,
  ),
  Rasgo(
    clave: 'carino',
    titulo: 'Cariño',
    pregunta: '¿Qué tan afectuosa es?',
    minimo: 'Poco afectuosa',
    maximo: 'Muy cariñosa',
    icono: Icons.favorite,
  ),
  Rasgo(
    clave: 'proteccion',
    titulo: 'Protección',
    pregunta: '¿Qué tan protectora es?',
    minimo: 'Nada protectora',
    maximo: 'Muy protectora',
    icono: Icons.shield,
  ),
  Rasgo(
    clave: 'tolerancia_soledad',
    titulo: 'Tolerancia a la soledad',
    pregunta: '¿Qué tan bien tolera estar sola?',
    minimo: 'No tolera la soledad',
    maximo: 'Tolera muy bien',
    icono: Icons.home,
  ),
  Rasgo(
    clave: 'adaptabilidad',
    titulo: 'Adaptabilidad',
    pregunta: '¿Qué tan fácil se adapta a cambios y lugares nuevos?',
    minimo: 'Le cuesta adaptarse',
    maximo: 'Se adapta fácil',
    icono: Icons.swap_horiz,
  ),
];
