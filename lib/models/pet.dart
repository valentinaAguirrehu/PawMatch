/// Mascota tal como viene de la tabla `mascota`.
class Pet {
  final String id;
  final String nombre;
  final String especie;
  final String? raza;
  final int? edad;
  final String unidadEdad; // 'meses' o 'anos'
  final String? sexo;
  final String? tamano;
  final String? descripcion;
  final bool esterilizado;
  final bool vacunas;
  final String? foto;
  final String estadoAdopcion;
  final String estadoApadrinamiento;

  /// Usuario con la solicitud de adopción aprobada. Vacío si nadie la adoptó.
  final String? idAdoptante;

  // Personalidad: valores de 1 a 5 por cada rasgo.
  final Map<String, dynamic> personalidad;

  const Pet({
    required this.id,
    required this.nombre,
    required this.especie,
    this.raza,
    this.edad,
    this.unidadEdad = 'anos',
    this.sexo,
    this.tamano,
    this.descripcion,
    this.esterilizado = false,
    this.vacunas = false,
    this.foto,
    this.estadoAdopcion = 'disponible',
    this.estadoApadrinamiento = 'disponible',
    this.idAdoptante,
    this.personalidad = const {},
  });

  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
    id: j['id_mascota'] as String,
    nombre: j['nombre'] as String,
    especie: j['especie'] as String,
    raza: j['raza'] as String?,
    edad: j['edad'] as int?,
    unidadEdad: (j['unidad_edad'] ?? 'anos') as String,
    sexo: j['sexo'] as String?,
    tamano: j['tamano'] as String?,
    descripcion: j['descripcion'] as String?,
    esterilizado: j['esterilizado'] == true,
    vacunas: j['vacunas'] == true,
    foto: j['fotos'] as String?,
    estadoAdopcion: (j['estado_adopcion'] ?? 'disponible') as String,
    estadoApadrinamiento:
        (j['estado_apadrinamiento'] ?? 'disponible') as String,
    idAdoptante: _id(j['id_usuario_adoptante']),

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
    'unidad_edad': unidadEdad,
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
    if (unidadEdad == 'meses' || unidadEdad == 'mes') {
      return edad == 1 ? '1 mes' : '$edad meses';
    }
    return edad == 1 ? '1 año' : '$edad años';
  }

  /// La unidad decide el grupo: meses es cachorro y años es adulto.
  bool get esCachorro => unidadEdad == 'meses' || unidadEdad == 'mes';

  String get estadoAdopcionTexto => etiquetaEstadoAdopcion(estadoAdopcion);

  bool get estaAdoptada => estadoAdopcion.trim().toLowerCase() == 'adoptado';

  bool get estaApadrinada =>
      estadoApadrinamiento.trim().toLowerCase() == 'apadrinado';

  /// Prioridad de la lista: 0 disponibles, 1 apadrinadas, 2 adoptadas.
  /// Adoptada gana sobre apadrinada cuando la mascota tiene ambos estados.
  int get ordenEstadoListado {
    if (estaAdoptada) return 2;
    if (estaApadrinada) return 1;
    return 0;
  }

  /// True solo si esta mascota adoptada pertenece a quien está consultando.
  bool adoptadaPor(String? currentUserId) {
    if (!estaAdoptada) return false;
    final adoptanteId = idAdoptante?.trim() ?? '';
    final actual = currentUserId?.trim() ?? '';
    return adoptanteId.isNotEmpty && actual == adoptanteId;
  }

  /// Mensaje de la tarjeta y del detalle cuando la mascota ya fue adoptada.
  String mensajeFamiliaPara(String? currentUserId) {
    if (adoptadaPor(currentUserId)) return '¡Ya es parte de tu familia! 💖';
    return '¡Ya es parte de una familia! 💖';
  }
}

String? _id(dynamic value) {
  final texto = value?.toString().trim() ?? '';
  return texto.isEmpty ? null : texto;
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

/// Disponibles, luego apadrinadas y al final adoptadas.
/// Dentro de cada grupo se conserva el orden original.
List<Pet> ordenarMascotasPorEstado(List<Pet> mascotas) {
  final entradas = mascotas.asMap().entries.toList();
  entradas.sort((a, b) {
    final porEstado =
        a.value.ordenEstadoListado.compareTo(b.value.ordenEstadoListado);
    if (porEstado != 0) return porEstado;
    return a.key.compareTo(b.key);
  });
  return [for (final entrada in entradas) entrada.value];
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
