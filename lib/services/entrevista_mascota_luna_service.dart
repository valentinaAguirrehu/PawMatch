import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';

class MensajeChatLuna {
  final String rol; // 'asistente' o 'usuario'
  final String texto;

  const MensajeChatLuna({
    required this.rol,
    required this.texto,
  });

  factory MensajeChatLuna.fromJson(Map<String, dynamic> j) => MensajeChatLuna(
    rol: j['rol'] == 'usuario' ? 'usuario' : 'asistente',
    texto: (j['texto'] ?? '').toString().trim(),
  );

  Map<String, String> toJson() => {
    'rol': rol,
    'texto': texto,
  };
}

class FichaMascotaLuna {
  final String? nombre;
  final String? especie;
  final String? sexo;
  final int? edad;
  final String? unidadEdad;
  final String? raza;
  final String? tamano;
  final bool? esCachorroEnProceso;
  final bool? personalidadDefinida;
  final Map<String, int> personalidad;
  final List<String> estadosSalud;
  final bool? vacunas;
  final bool? esterilizado;
  final String? detalleSalud;
  final String? descripcion;
  final bool saludConsultada;
  final bool historiaConsultada;

  const FichaMascotaLuna({
    this.nombre,
    this.especie,
    this.sexo,
    this.edad,
    this.unidadEdad,
    this.raza,
    this.tamano,
    this.esCachorroEnProceso,
    this.personalidadDefinida,
    this.personalidad = const {},
    this.estadosSalud = const [],
    this.vacunas,
    this.esterilizado,
    this.detalleSalud,
    this.descripcion,
    this.saludConsultada = false,
    this.historiaConsultada = false,
  });

  factory FichaMascotaLuna.fromJson(Map<String, dynamic> j) {
    final persRaw = j['personalidad'];
    final mapaPers = <String, int>{};
    if (persRaw is Map) {
      for (final r in rasgosMascota) {
        final v = persRaw[r.clave];
        final n = v is int ? v : (v is num ? v.round() : int.tryParse('${v ?? ''}'));
        if (n != null && n >= 1 && n <= 5) {
          mapaPers[r.clave] = n;
        }
      }
    }

    final saludLista = <String>[];
    final rawSalud = j['estado_salud'];
    if (rawSalud is List) {
      for (final item in rawSalud) {
        final txt = item?.toString().trim() ?? '';
        if (txt.isNotEmpty && !saludLista.contains(txt)) {
          saludLista.add(txt);
        }
      }
    }

    final edadRaw = j['edad'];
    final edadInt = edadRaw is int
        ? edadRaw
        : (edadRaw is num ? edadRaw.round() : int.tryParse('${edadRaw ?? ''}'));

    return FichaMascotaLuna(
      nombre: _str(j['nombre']),
      especie: _str(j['especie']),
      sexo: _str(j['sexo']),
      edad: edadInt,
      unidadEdad: _str(j['unidad_edad']),
      raza: _str(j['raza']),
      tamano: _str(j['tamano']),
      esCachorroEnProceso: j['es_cachorro_en_proceso'] is bool
          ? j['es_cachorro_en_proceso'] as bool
          : null,
      personalidadDefinida: j['personalidad_definida'] is bool
          ? j['personalidad_definida'] as bool
          : null,
      personalidad: mapaPers,
      estadosSalud: saludLista,
      vacunas: j['vacunas'] is bool ? j['vacunas'] as bool : null,
      esterilizado: j['esterilizado'] is bool ? j['esterilizado'] as bool : null,
      detalleSalud: _str(j['detalle_salud']),
      descripcion: _str(j['descripcion']),
      saludConsultada: j['salud_consultada'] == true,
      historiaConsultada: j['historia_consultada'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'especie': especie,
    'sexo': sexo,
    'edad': edad,
    'unidad_edad': unidadEdad,
    'raza': raza,
    'tamano': tamano,
    'es_cachorro_en_proceso': esCachorroEnProceso,
    'personalidad_definida': personalidadDefinida,
    'personalidad': personalidad,
    'estado_salud': estadosSalud,
    'vacunas': vacunas,
    'esterilizado': esterilizado,
    'detalle_salud': detalleSalud,
    'descripcion': descripcion,
    'salud_consultada': saludConsultada,
    'historia_consultada': historiaConsultada,
  };

  /// Calcula la fecha de nacimiento aproximada a partir de la edad y unidad.
  DateTime calcularFechaNacimiento() {
    final hoy = DateTime.now();
    final cant = (edad ?? 1).clamp(1, 360);
    final esMeses = (unidadEdad ?? '').toLowerCase().startsWith('mes');
    if (esMeses) {
      return DateTime(hoy.year, hoy.month - cant, hoy.day);
    }
    return DateTime(hoy.year - cant, hoy.month, hoy.day);
  }

  /// Calcula el porcentaje real de información recopilada (0 a 100%)
  /// usando únicamente los campos requeridos realmente completados y validados.
  int get porcentajeProgreso {
    int puntos = 0;
    if (nombre != null && nombre!.trim().isNotEmpty) puntos += 12;
    if (especie != null && especie!.trim().isNotEmpty) puntos += 10;
    if (sexo != null && sexo!.trim().isNotEmpty) puntos += 10;
    if (edad != null && unidadEdad != null && unidadEdad!.trim().isNotEmpty) {
      puntos += 12;
    }
    if (tamano != null && tamano!.trim().isNotEmpty) puntos += 10;

    final enProceso =
        esCachorroEnProceso == true || personalidadDefinida == false;
    if (enProceso) {
      puntos += 26;
    } else {
      if (personalidad.containsKey('nivel_juego') ||
          personalidad.containsKey('nivel_energia')) {
        puntos += 14;
      }
      if (personalidad.containsKey('sociabilidad_personas')) {
        puntos += 6;
      }
      if (personalidad.containsKey('sociabilidad_mascotas')) {
        puntos += 6;
      }
    }

    if (saludConsultada) puntos += 10;
    if (historiaConsultada &&
        descripcion != null &&
        descripcion!.trim().isNotEmpty) {
      puntos += 10;
    }
    return puntos.clamp(0, 100);
  }

  static String? _str(dynamic val) {
    final s = val?.toString().trim() ?? '';
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
  }
}

class RespuestaTurnoLuna {
  final String mensaje;
  final bool necesitaAclaracion;
  final String? confirmacionGuardado;
  final bool entrevistaCompletada;
  final FichaMascotaLuna ficha;
  final String pasoActual;
  final int numeroPaso;
  final int totalPasos;
  final List<String> camposFaltantes;
  final List<MensajeChatLuna> historialGuardado;
  final bool guardadoEnBd;
  final bool reanudado;

  const RespuestaTurnoLuna({
    required this.mensaje,
    this.necesitaAclaracion = false,
    this.confirmacionGuardado,
    required this.entrevistaCompletada,
    required this.ficha,
    this.pasoActual = 'nombre',
    this.numeroPaso = 1,
    this.totalPasos = 12,
    required this.camposFaltantes,
    this.historialGuardado = const [],
    this.guardadoEnBd = false,
    this.reanudado = false,
  });

  factory RespuestaTurnoLuna.fromJson(Map<String, dynamic> j) {
    final faltan = <String>[];
    if (j['campos_faltantes'] is List) {
      for (final item in j['campos_faltantes'] as List) {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty) faltan.add(s);
      }
    }
    final hist = <MensajeChatLuna>[];
    if (j['historial_guardado'] is List) {
      for (final item in j['historial_guardado'] as List) {
        if (item is Map) {
          final m = MensajeChatLuna.fromJson(Map<String, dynamic>.from(item));
          if (m.texto.isNotEmpty) hist.add(m);
        }
      }
    }
    final numPasoRaw = j['numero_paso'];
    final totalPasosRaw = j['total_pasos'];
    return RespuestaTurnoLuna(
      mensaje: (j['mensaje'] ?? '').toString().trim(),
      necesitaAclaracion: j['necesita_aclaracion'] == true,
      confirmacionGuardado: j['confirmacion_guardado']?.toString().trim(),
      entrevistaCompletada: j['entrevista_completada'] == true,
      ficha: j['ficha'] is Map
          ? FichaMascotaLuna.fromJson(Map<String, dynamic>.from(j['ficha'] as Map))
          : const FichaMascotaLuna(),
      pasoActual: (j['paso_actual'] ?? 'nombre').toString(),
      numeroPaso: numPasoRaw is int ? numPasoRaw : (int.tryParse('$numPasoRaw') ?? 1),
      totalPasos: totalPasosRaw is int ? totalPasosRaw : (int.tryParse('$totalPasosRaw') ?? 12),
      camposFaltantes: faltan,
      historialGuardado: hist,
      guardadoEnBd: j['guardado_en_bd'] == true,
      reanudado: j['reanudado'] == true,
    );
  }
}

/// Servicio que conecta con el Asistente de Paw Match (`gpt-6-luna` configurado en `.env`)
/// para registrar mascotas paso a paso con persistencia progresiva en PostgreSQL.
class EntrevistaMascotaLunaService {
  static Future<RespuestaTurnoLuna> enviarTurno({
    required FichaMascotaLuna ficha,
    required List<MensajeChatLuna> historial,
    required String mensaje,
    bool reiniciar = false,
  }) async {
    final idAdmin = Session.idUsuario ?? '';
    if (idAdmin.isEmpty) {
      throw Exception('Debes iniciar sesión como administrador.');
    }

    try {
      final resp = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/mascotas/entrevista-luna'),
            headers: {
              'Content-Type': 'application/json',
              'x-usuario-id': idAdmin,
            },
            body: jsonEncode({
              'ficha': ficha.toJson(),
              'historial': historial.map((h) => h.toJson()).toList(),
              'mensaje': mensaje,
              'reiniciar': reiniciar,
            }),
          )
          .timeout(const Duration(seconds: 45));

      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}

      if (resp.statusCode == 200 && data != null) {
        return RespuestaTurnoLuna.fromJson(data);
      }
      final err = data?['error']?.toString() ??
          'No se pudo guardar o procesar tu respuesta (${resp.statusCode}). Inténtalo de nuevo.';
      throw Exception(err);
    } on TimeoutException {
      throw Exception('El asistente tardó demasiado en responder. Inténtalo de nuevo.');
    }
  }

  static Future<void> guardarBorradorRevision({
    required FichaMascotaLuna ficha,
    required List<MensajeChatLuna> historial,
    String pasoActual = 'revision',
  }) async {
    final idAdmin = Session.idUsuario ?? '';
    if (idAdmin.isEmpty) return;

    final resp = await http
        .put(
          Uri.parse('${ApiService.baseUrl}/mascotas/entrevista-luna/borrador'),
          headers: {
            'Content-Type': 'application/json',
            'x-usuario-id': idAdmin,
          },
          body: jsonEncode({
            'ficha': ficha.toJson(),
            'historial': historial.map((h) => h.toJson()).toList(),
            'paso_actual': pasoActual,
            'origen_registro': 'ia',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('No se pudo guardar la ficha en la base de datos.');
    }
  }

  static Future<void> guardarBorradorManual({
    required String? nombre,
    required String? especie,
    required String? raza,
    required String? sexo,
    required String? tamano,
    required DateTime? fechaNacimiento,
    required String? descripcion,
    required List<String> estadosSalud,
    required String? detalleSalud,
    required bool personalidadDefinida,
    required Map<String, int> personalidad,
    required String? foto,
  }) async {
    final idAdmin = Session.idUsuario ?? '';
    if (idAdmin.isEmpty) return;

    final String? fNacStr = fechaNacimiento != null
        ? '${fechaNacimiento.year.toString().padLeft(4, '0')}-'
          '${fechaNacimiento.month.toString().padLeft(2, '0')}-'
          '${fechaNacimiento.day.toString().padLeft(2, '0')}'
        : null;

    int? edadCalc;
    String? unidadCalc;
    if (fechaNacimiento != null) {
      final meses = Pet.mesesEntre(fechaNacimiento, DateTime.now());
      if (meses >= 12) {
        edadCalc = meses ~/ 12;
        unidadCalc = 'anos';
      } else {
        edadCalc = meses <= 0 ? 1 : meses;
        unidadCalc = 'meses';
      }
    }

    try {
      await http
          .put(
            Uri.parse('${ApiService.baseUrl}/mascotas/borrador'),
            headers: {
              'Content-Type': 'application/json',
              'x-usuario-id': idAdmin,
            },
            body: jsonEncode({
              'nombre': nombre,
              'especie': especie,
              'raza': raza,
              'sexo': sexo,
              'tamano': tamano,
              'edad': edadCalc,
              'unidad_edad': unidadCalc,
              'fecha_nacimiento': fNacStr,
              'descripcion': descripcion,
              'estado_salud': estadosSalud,
              'detalle_salud': detalleSalud,
              'vacunas': estadosSalud.contains('Vacunación al día.'),
              'esterilizado': estadosSalud.contains('Esterilización realizada.'),
              'personalidad_definida': personalidadDefinida,
              'personalidad': personalidad,
              'foto': foto,
              'origen_registro': 'manual',
              'paso_actual': 'manual',
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  static Future<List<BorradorMascotaResumen>> obtenerBorradores() async {
    final idAdmin = Session.idUsuario ?? '';
    if (idAdmin.isEmpty) return const [];

    try {
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/mascotas/borradores'),
        headers: {
          'Content-Type': 'application/json',
          'x-usuario-id': idAdmin,
        },
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((item) => BorradorMascotaResumen.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> eliminarBorrador(String idBorrador, {String? nombre}) async {
    final idAdmin = Session.idUsuario ?? '';
    if (idAdmin.isEmpty) return false;

    try {
      final queryParams = <String, String>{};
      if (nombre != null && nombre.trim().isNotEmpty) {
        queryParams['nombre'] = nombre.trim();
      }
      final queryStr = queryParams.isNotEmpty
          ? '?${Uri(queryParameters: queryParams).query}'
          : '';

      final url = idBorrador.isNotEmpty && idBorrador != 'null'
          ? '${ApiService.baseUrl}/mascotas/borradores/$idBorrador$queryStr'
          : '${ApiService.baseUrl}/mascotas/borrador$queryStr';
      final resp = await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-usuario-id': idAdmin,
        },
      ).timeout(const Duration(seconds: 15));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class BorradorMascotaResumen {
  final String idBorrador;
  final String? nombre;
  final String? especie;
  final String? sexo;
  final int? edad;
  final String? unidadEdad;
  final String? raza;
  final String? tamano;
  final String pasoActual;
  final int totalMensajes;
  final DateTime fechaActualizacion;
  final FichaMascotaLuna ficha;
  final String origenRegistro;
  final String? foto;
  final DateTime? fechaNacimiento;
  final String? descripcion;
  final String? detalleSalud;

  const BorradorMascotaResumen({
    required this.idBorrador,
    this.nombre,
    this.especie,
    this.sexo,
    this.edad,
    this.unidadEdad,
    this.raza,
    this.tamano,
    required this.pasoActual,
    required this.totalMensajes,
    required this.fechaActualizacion,
    required this.ficha,
    this.origenRegistro = 'ia',
    this.foto,
    this.fechaNacimiento,
    this.descripcion,
    this.detalleSalud,
  });

  bool get esManual => origenRegistro.trim().toLowerCase() == 'manual';

  factory BorradorMascotaResumen.fromJson(Map<String, dynamic> j) {
    final edadRaw = j['edad'];
    final edadInt = edadRaw is int
        ? edadRaw
        : (edadRaw is num ? edadRaw.round() : int.tryParse('${edadRaw ?? ''}'));
    final totalMsgRaw = j['total_mensajes'];
    final totalMsgInt = totalMsgRaw is int
        ? totalMsgRaw
        : (totalMsgRaw is num ? totalMsgRaw.round() : int.tryParse('${totalMsgRaw ?? ''}') ?? 0);

    DateTime fecha = DateTime.now();
    final fechaRaw = j['fecha_actualizacion'];
    if (fechaRaw != null) {
      final parsed = DateTime.tryParse(fechaRaw.toString());
      if (parsed != null) fecha = parsed;
    }

    DateTime? fNac;
    final fNacRaw = j['fecha_nacimiento'];
    if (fNacRaw != null && fNacRaw.toString().trim().isNotEmpty) {
      fNac = DateTime.tryParse(fNacRaw.toString());
    }

    final String origen = (j['origen_registro'] ?? 'ia').toString();
    final String? fotoStr = j['foto']?.toString().trim();

    return BorradorMascotaResumen(
      idBorrador: (j['id_borrador'] ?? '').toString(),
      nombre: (j['nombre'] != null && j['nombre'].toString().trim().isNotEmpty)
          ? j['nombre'].toString().trim()
          : null,
      especie: (j['especie'] != null && j['especie'].toString().trim().isNotEmpty)
          ? j['especie'].toString().trim()
          : null,
      sexo: (j['sexo'] != null && j['sexo'].toString().trim().isNotEmpty)
          ? j['sexo'].toString().trim()
          : null,
      edad: edadInt,
      unidadEdad: j['unidad_edad']?.toString(),
      raza: j['raza']?.toString(),
      tamano: j['tamano']?.toString(),
      pasoActual: (j['paso_actual'] ?? (origen == 'manual' ? 'manual' : 'informacion_basica')).toString(),
      totalMensajes: totalMsgInt,
      fechaActualizacion: fecha,
      ficha: FichaMascotaLuna.fromJson(j),
      origenRegistro: origen,
      foto: (fotoStr != null && fotoStr.isNotEmpty) ? fotoStr : null,
      fechaNacimiento: fNac,
      descripcion: j['descripcion']?.toString(),
      detalleSalud: j['detalle_salud']?.toString(),
    );
  }

  String get nombreVisible => nombre ?? 'Peludito en registro';

  String get descripcionPaso {
    if (esManual) {
      return 'Formulario manual en progreso';
    }
    switch (pasoActual) {
      case 'informacion_basica':
      case 'nombre':
        return 'Paso 1: Información básica';
      case 'personalidad':
        return 'Paso 2: Personalidad y energía';
      case 'sociabilidad':
        return 'Paso 3: Sociabilidad';
      case 'salud':
        return 'Paso 4: Salud y cuidados';
      case 'historia':
        return 'Paso 5: Historia y detalles';
      case 'revision':
        return 'Revisión y confirmación';
      case 'fotografia':
        return 'Fotografía del peludito';
      default:
        return 'En progreso con el asistente';
    }
  }
}

