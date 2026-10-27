import 'package:flutter/material.dart';

/// Ícono, título y texto de un punto del inicio (acordeón, línea de tiempo o carrusel).
class PuntoInicio {
  final IconData icono;
  final String titulo;
  final String texto;

  const PuntoInicio({
    required this.icono,
    required this.titulo,
    required this.texto,
  });
}
