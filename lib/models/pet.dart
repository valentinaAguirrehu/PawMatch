/// Mascota tal como viene de la tabla `mascota`.
class Pet {
  final String id;
  final String nombre;
  final String especie;
  final String? raza;
  final int? edad;
  final String? sexo;
  final String? tamano;
  final String? descripcion;
  final bool esterilizado;
  final bool vacunas;
  final String? foto;
  final String estadoAdopcion;
  final String estadoApadrinamiento;

  // Personalidad: valores de 1 a 5 por cada rasgo.
  final Map<String, dynamic> personalidad;

  const Pet({
    required this.id,
    required this.nombre,
    required this.especie,
    this.raza,
    this.edad,
    this.sexo,
    this.tamano,
    this.descripcion,
    this.esterilizado = false,
    this.vacunas = false,
    this.foto,
    this.estadoAdopcion = 'disponible',
    this.estadoApadrinamiento = 'disponible',
    this.personalidad = const {},
  });

  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
    id: j['id_mascota'] as String,
    nombre: j['nombre'] as String,
    especie: j['especie'] as String,
    raza: j['raza'] as String?,
    edad: j['edad'] as int?,
    sexo: j['sexo'] as String?,
    tamano: j['tamano'] as String?,
    descripcion: j['descripcion'] as String?,
    esterilizado: j['esterilizado'] == true,
    vacunas: j['vacunas'] == true,
    foto: j['fotos'] as String?,
    estadoAdopcion: (j['estado_adopcion'] ?? 'disponible') as String,
    estadoApadrinamiento:
        (j['estado_apadrinamiento'] ?? 'disponible') as String,

    // Si el backend devuelve personalidad, la cargamos.
    personalidad: j['personalidad'] is Map
        ? Map<String, dynamic>.from(j['personalidad'] as Map)
        : const {},
  );

  /// Cuerpo que espera el backend en POST / PUT.
  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'especie': especie,
    'raza': raza,
    'edad': edad,
    'sexo': sexo,
    'tamano': tamano,
    'descripcion': descripcion,
    'esterilizado': esterilizado,
    'vacunas': vacunas,
    'fotos': foto,
    'estado_adopcion': estadoAdopcion,
    'estado_apadrinamiento': estadoApadrinamiento,
    'personalidad': personalidad,
  };

  String get edadTexto {
    if (edad == null) return 'Edad no registrada';
    return edad == 1 ? '1 año' : '$edad años';
  }

  String get estadoAdopcionTexto => etiquetaEstadoAdopcion(estadoAdopcion);
}

String etiquetaEstadoAdopcion(String e) {
  switch (e) {
    case 'disponible':
      return 'Disponible';
    case 'en_proceso':
      return 'En proceso';
    case 'adoptado':
      return 'Adoptado';
    default:
      return e;
  }
}

String etiquetaEstadoApadrinamiento(String e) {
  switch (e) {
    case 'disponible':
      return 'Disponible';
    case 'apadrinado':
      return 'Apadrinado';
    default:
      return e;
  }
}
