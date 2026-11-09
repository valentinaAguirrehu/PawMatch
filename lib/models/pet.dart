import 'dart:convert';

/// Mascota tal como viene de la tabla `mascota`.
class Pet {
  final String id;
  final String nombre;
  final String especie;
  final String? raza;
  final int? edad;
  final String unidadEdad; // 'meses' o 'anos'

  /// Día de nacimiento. La edad que se muestra sale de aquí y cambia con el tiempo.
  final DateTime? fechaNacimiento;
  final String? sexo;
  final String? tamano;
  final String? descripcion;
  final bool esterilizado;
  final bool vacunas;
  final String? foto;
  final String estadoAdopcion;
  final String estadoApadrinamiento;
  final List<String> estadosSalud;
  final String? detalleSalud;
  final String? fechaActualizacion;

  /// Fecha real de creación del registro en la base de datos (ISO UTC).
  final String? fechaCreacion;

  /// Indicador calculado por la base de datos (true si fue creada hace <= 48 horas).
  final bool esNuevoDb;

  /// Usuario con la solicitud de adopción aprobada. Vacío si nadie la adoptó.
  final String? idAdoptante;

  /// False cuando es un cachorro y su temperamento todavía no se evaluó.
  final bool personalidadDefinida;

  // Personalidad: valores de 1 a 5 por cada rasgo. Null si aún no está definida.
  final Map<String, dynamic> personalidad;

  const Pet({
    required this.id,
    required this.nombre,
    required this.especie,
    this.raza,
    this.edad,
    this.unidadEdad = 'anos',
    this.fechaNacimiento,
    this.sexo,
    this.tamano,
    this.descripcion,
    this.esterilizado = false,
    this.vacunas = false,
    this.foto,
    this.estadoAdopcion = 'disponible',
    this.estadoApadrinamiento = 'disponible',
    this.estadosSalud = const ['No presenta necesidades veterinarias pendientes.'],
    this.detalleSalud,
    this.fechaActualizacion,
    this.fechaCreacion,
    this.esNuevoDb = false,
    this.idAdoptante,
    this.personalidadDefinida = true,
    this.personalidad = const {},
  });

  Pet copiar({
    bool? personalidadDefinida,
    Map<String, dynamic>? personalidad,
  }) {
    return Pet(
      id: id,
      nombre: nombre,
      especie: especie,
      raza: raza,
      edad: edad,
      unidadEdad: unidadEdad,
      fechaNacimiento: fechaNacimiento,
      sexo: sexo,
      tamano: tamano,
      descripcion: descripcion,
      esterilizado: esterilizado,
      vacunas: vacunas,
      foto: foto,
      estadoAdopcion: estadoAdopcion,
      estadoApadrinamiento: estadoApadrinamiento,
      estadosSalud: estadosSalud,
      detalleSalud: detalleSalud,
      fechaActualizacion: fechaActualizacion,
      fechaCreacion: fechaCreacion,
      esNuevoDb: esNuevoDb,
      idAdoptante: idAdoptante,
      personalidadDefinida: personalidadDefinida ?? this.personalidadDefinida,
      personalidad: personalidad ?? this.personalidad,
    );
  }

  /// True únicamente durante las primeras 48 horas desde la fecha real de creación en la BD.
  bool get esNuevo {
    final raw = fechaCreacion?.trim();
    if (raw != null && raw.isNotEmpty) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        final diff = DateTime.now().toUtc().difference(dt.toUtc());
        return diff.inMinutes <= 48 * 60 && diff.inMinutes >= -120;
      }
    }
    return esNuevoDb;
  }

  String get estadoSalud =>
      estadosSalud.isNotEmpty ? estadosSalud.join(' • ') : 'No presenta necesidades veterinarias pendientes.';

  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
    id: j['id_mascota'] as String,
    nombre: j['nombre'] as String,
    especie: j['especie'] as String,
    raza: j['raza'] as String?,
    edad: _entero(j['edad']),
    unidadEdad: (j['unidad_edad'] ?? 'anos') as String,
    fechaNacimiento: _fecha(j['fecha_nacimiento']),
    sexo: j['sexo'] as String?,
    tamano: j['tamano'] as String?,
    descripcion: j['descripcion'] as String?,
    esterilizado: j['esterilizado'] == true,
    vacunas: j['vacunas'] == true,
    foto: j['fotos'] as String?,
    estadoAdopcion: (j['estado_adopcion'] ?? 'disponible') as String,
    estadoApadrinamiento:
        (j['estado_apadrinamiento'] ?? 'disponible') as String,
    estadosSalud: _parseEstadosSalud(j['estado_salud'], j['vacunas'], j['esterilizado']),
    detalleSalud: j['detalle_salud'] as String?,
    fechaActualizacion: j['fecha_actualizacion'] as String?,
    fechaCreacion: j['fecha_creacion'] as String?,
    esNuevoDb: j['es_nuevo'] == true,
    idAdoptante: _id(j['id_usuario_adoptante']),
    personalidadDefinida: j['personalidad_definida'] != false,

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
    'fecha_nacimiento': fechaNacimiento == null
        ? null
        : _isoFecha(fechaNacimiento!),
    'sexo': sexo,
    'tamano': tamano,
    'descripcion': descripcion,
    'esterilizado': esterilizado || estadosSalud.contains('Esterilización realizada.'),
    'vacunas': vacunas || estadosSalud.contains('Vacunación al día.'),
    'fotos': foto,
    'estado_adopcion': estadoAdopcion,
    'estado_apadrinamiento': estadoApadrinamiento,
    'estado_salud': estadosSalud,
    'detalle_salud': detalleSalud,
    'personalidad_definida': personalidadDefinida,
    'personalidad': personalidad,
  };

  String get edadTexto {
    final nacimiento = fechaNacimiento;
    if (nacimiento != null) return Pet.textoEdad(nacimiento, DateTime.now());
    if (edad == null) return 'Edad no registrada';
    if (unidadEdad == 'meses' || unidadEdad == 'mes') {
      return edad == 1 ? '1 mes' : '$edad meses';
    }
    return edad == 1 ? '1 año' : '$edad años';
  }

  /// Fecha guardada, o una calculada con la edad cuando el registro antiguo no tiene día.
  DateTime? get fechaNacimientoParaEditar {
    final conocida = fechaNacimiento;
    if (conocida != null) {
      return DateTime(conocida.year, conocida.month, conocida.day);
    }
    final cantidad = edad;
    if (cantidad == null || cantidad < 0) return null;
    final hoy = DateTime.now();
    if (unidadEdad == 'meses' || unidadEdad == 'mes') {
      return DateTime(hoy.year, hoy.month - cantidad, hoy.day);
    }
    return DateTime(hoy.year - cantidad, hoy.month, hoy.day);
  }

  /// True cuando [fechaNacimientoParaEditar] sale de la edad y no de un día guardado.
  bool get fechaNacimientoEsEstimada =>
      fechaNacimiento == null && fechaNacimientoParaEditar != null;

  /// Meses ya cumplidos a partir de la fecha de nacimiento.
  int? get mesesCumplidos {
    final nacimiento = fechaNacimiento;
    if (nacimiento != null) return Pet.mesesEntre(nacimiento, DateTime.now());
    if (edad == null) return null;
    if (unidadEdad == 'meses' || unidadEdad == 'mes') return edad;
    return edad! * 12;
  }

  /// Cumplió 8 meses y la personalidad sigue sin registrarse.
  bool get pendienteLlenarPersonalidad {
    if (personalidadDefinida) return false;
    final meses = mesesCumplidos;
    return meses != null && meses >= 8;
  }

  /// Menos de un año. Con fecha de nacimiento se recalcula; si no hay fecha,
  /// se conserva el grupo que quedó guardado en meses o años.
  bool get esCachorro {
    final meses = mesesCumplidos;
    if (fechaNacimiento != null && meses != null) return meses < 12;
    return unidadEdad == 'meses' || unidadEdad == 'mes';
  }

  /// Años, meses y días cumplidos entre [nacimiento] y [hoy].
  static ({int anos, int meses, int dias}) partesEdad(
    DateTime nacimiento,
    DateTime hoy,
  ) {
    final n = DateTime(nacimiento.year, nacimiento.month, nacimiento.day);
    final h = DateTime(hoy.year, hoy.month, hoy.day);
    if (h.isBefore(n)) return (anos: 0, meses: 0, dias: 0);
    var anos = h.year - n.year;
    var meses = h.month - n.month;
    var dias = h.day - n.day;
    if (dias < 0) {
      meses--;
      dias += DateTime(h.year, h.month, 0).day;
    }
    if (meses < 0) {
      anos--;
      meses += 12;
    }
    return (anos: anos, meses: meses, dias: dias);
  }

  static int mesesEntre(DateTime nacimiento, DateTime hoy) {
    final partes = partesEdad(nacimiento, hoy);
    return partes.anos * 12 + partes.meses;
  }

  static String textoEdad(DateTime nacimiento, DateTime hoy) {
    final partes = partesEdad(nacimiento, hoy);
    if (partes.anos == 0 && partes.meses == 0) {
      if (partes.dias <= 0) return 'Menos de 1 día';
      return partes.dias == 1 ? '1 día' : '${partes.dias} días';
    }
    final textos = <String>[
      if (partes.anos > 0) partes.anos == 1 ? '1 año' : '${partes.anos} años',
      if (partes.meses > 0)
        partes.meses == 1 ? '1 mes' : '${partes.meses} meses',
    ];
    return textos.join(' y ');
  }

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

  /// Lista de necesidades veterinarias pendientes registradas para esta mascota
  List<String> get necesidadesPendientes {
    return estadosSalud
        .where((e) => opcionesNecesidadesPendientes.contains(e))
        .toList();
  }

  /// Lista de vacunas y procedimientos ya realizados
  List<String> get procedimientosRealizados {
    final list = estadosSalud
        .where((e) => opcionesProcedimientosRealizados.contains(e))
        .toList();
    if (vacunas && !list.contains('Vacunación al día.')) {
      list.add('Vacunación al día.');
    }
    if (esterilizado && !list.contains('Esterilización realizada.')) {
      list.add('Esterilización realizada.');
    }
    return list;
  }

  /// Indica si no presenta necesidades médicas o veterinarias pendientes
  bool get noTieneNecesidadesPendientes {
    if (estadosSalud.contains(opcionSinNecesidades)) return true;
    return necesidadesPendientes.isEmpty;
  }

  /// Retorna si la mascota tiene alguna necesidad médica o de salud que atender
  bool get tieneNecesidadSalud {
    return necesidadesPendientes.isNotEmpty ||
        (detalleSalud != null && detalleSalud!.trim().isNotEmpty);
  }

  String get estadoSaludTexto {
    if (estadosSalud.isEmpty) return opcionSinNecesidades;
    return estadosSalud.join(' • ');
  }
}

/// Las 10 opciones oficiales para el estado de salud de la mascota
const List<String> opcionesEstadoSalud = [
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

const List<String> opcionesNecesidadesPendientes = [
  'Requiere vacunación.',
  'Requiere esterilización.',
  'Requiere desparasitación.',
  'Requiere exámenes médicos.',
  'Necesita medicamentos.',
  'Se encuentra en tratamiento veterinario.',
  'Requiere cuidados especiales.',
];

const List<String> opcionesProcedimientosRealizados = [
  'Vacunación al día.',
  'Esterilización realizada.',
];

const String opcionSinNecesidades = 'No presenta necesidades veterinarias pendientes.';

List<String> _parseEstadosSalud(dynamic raw, dynamic vacunas, dynamic esterilizado) {
  final result = <String>[];
  if (raw != null) {
    if (raw is List) {
      for (final item in raw) {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty) result.add(s);
      }
    } else {
      final s = raw.toString().trim();
      if (s.startsWith('[') && s.endsWith(']')) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is List) {
            for (final item in decoded) {
              final str = item?.toString().trim() ?? '';
              if (str.isNotEmpty) result.add(str);
            }
          }
        } catch (_) {}
      } else if (s.isNotEmpty) {
        if (s.toLowerCase().startsWith('saludable')) {
          result.add(opcionSinNecesidades);
        } else if (s.contains('•')) {
          for (final parte in s.split('•')) {
            final str = parte.trim();
            if (str.isNotEmpty) result.add(str);
          }
        } else if (s.contains(',')) {
          for (final parte in s.split(',')) {
            final str = parte.trim();
            if (str.isNotEmpty) result.add(str);
          }
        } else {
          result.add(s);
        }
      }
    }
  }

  // Compatibilidad con registros antiguos que tenían vacunas o esterilizado como booleanos
  if (vacunas == true && !result.contains('Vacunación al día.') && !result.contains('Requiere vacunación.')) {
    result.add('Vacunación al día.');
  }
  if (esterilizado == true && !result.contains('Esterilización realizada.') && !result.contains('Requiere esterilización.')) {
    result.add('Esterilización realizada.');
  }

  if (result.isEmpty) {
    result.add(opcionSinNecesidades);
  }

  return result;
}

int? _entero(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _fecha(dynamic value) {
  final texto = value?.toString() ?? '';
  final coincidencia = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(texto);
  if (coincidencia == null) return null;
  return DateTime(
    int.parse(coincidencia.group(1)!),
    int.parse(coincidencia.group(2)!),
    int.parse(coincidencia.group(3)!),
  );
}

String _isoFecha(DateTime fecha) {
  final mes = fecha.month.toString().padLeft(2, '0');
  final dia = fecha.day.toString().padLeft(2, '0');
  return '${fecha.year}-$mes-$dia';
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
