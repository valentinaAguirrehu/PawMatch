import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/match_estado.dart';
import 'package:paw_match/services/personalidad_usuario_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';

/// Notificación de una nueva mascota con alta compatibilidad para el usuario.
class NotificacionMatchMascota {
  final String idNotificacion;
  final String idMascota;
  final String nombreMascota;
  final String? fotoMascota;
  final String? especieMascota;
  final String? sexoMascota;
  final String? tamanoMascota;
  final double porcentajeMatch;
  final bool leida;
  final bool mostradaEnMascotas;
  final String? fechaCreacion;

  const NotificacionMatchMascota({
    required this.idNotificacion,
    required this.idMascota,
    required this.nombreMascota,
    this.fotoMascota,
    this.especieMascota,
    this.sexoMascota,
    this.tamanoMascota,
    required this.porcentajeMatch,
    required this.leida,
    required this.mostradaEnMascotas,
    this.fechaCreacion,
  });

  int get porcentajeEntero => porcentajeMatch.round().clamp(0, 100);

  factory NotificacionMatchMascota.fromJson(Map<String, dynamic> j) {
    final rawPct = j['porcentaje_match'];
    final pct = rawPct is num
        ? rawPct.toDouble()
        : (double.tryParse('${rawPct ?? 0}') ?? 0.0);
    return NotificacionMatchMascota(
      idNotificacion: '${j['id_notificacion'] ?? ''}',
      idMascota: '${j['id_mascota'] ?? ''}',
      nombreMascota: '${j['nombre_mascota'] ?? 'Peludito'}',
      fotoMascota: j['foto_mascota'] as String?,
      especieMascota: j['especie_mascota'] as String?,
      sexoMascota: j['sexo_mascota'] as String?,
      tamanoMascota: j['tamano_mascota'] as String?,
      porcentajeMatch: pct,
      leida: j['leida'] == true,
      mostradaEnMascotas: j['mostrada_en_mascotas'] == true,
      fechaCreacion: j['fecha_creacion'] as String?,
    );
  }
}

/// Estado sincronizado del Match inicial y notificaciones del usuario desde la BD.
class SincronizacionMatchUsuario {
  final bool tienePersonalidad;
  final String? idMascotaMatchInicial;
  final double? porcentajeMatchInicial;
  final List<NotificacionMatchMascota> notificaciones;
  final int noLeidas;

  const SincronizacionMatchUsuario({
    required this.tienePersonalidad,
    this.idMascotaMatchInicial,
    this.porcentajeMatchInicial,
    this.notificaciones = const [],
    this.noLeidas = 0,
  });
}

/// Una mascota y su `porcentaje_match` (tabla `Match`, de 0 a 100).
class CompatibilidadMatch {
  final Pet mascota;
  final double porcentaje;

  /// Claves de `PreguntaPersonalidad`, de la respuesta más parecida a la menos.
  final List<String> rasgosOrdenados;

  /// True cuando esta mascota corresponde al Match inicial persistido del usuario.
  final bool esMatchInicial;

  const CompatibilidadMatch({
    required this.mascota,
    required this.porcentaje,
    required this.rasgosOrdenados,
    this.esMatchInicial = false,
  });

  int get porcentajeEntero => porcentaje.round().clamp(0, 100);
}

/// El Match inicial del usuario junto con las mejores nuevas coincidencias disponibles.
class RankingMatch {
  final bool tienePersonalidad;

  /// Nombre de pila leído de `Usuario.nombres`.
  final String nombreUsuario;
  final Map<String, int> usuario;
  final List<CompatibilidadMatch> mejores;
  final String? idMascotaMatchInicial;

  const RankingMatch({
    required this.tienePersonalidad,
    required this.nombreUsuario,
    required this.usuario,
    required this.mejores,
    this.idMascotaMatchInicial,
  });
}

/// Compara `PersonalidadUsuario` con `PersonalidadMascota` y gestiona la
/// persistencia del primer Match y las notificaciones de nuevas coincidencias.
class MatchService {
  static const int limite = 3;

  /// Contador reactivo de notificaciones de nuevas coincidencias no leídas.
  static final ValueNotifier<int> noLeidasUsuario = ValueNotifier<int>(0);

  /// Sincroniza con la base de datos el Match inicial del usuario y sus notificaciones.
  static Future<SincronizacionMatchUsuario> sincronizar() async {
    final id = Session.idUsuario;
    if (id == null || id.isEmpty || Session.esAdmin) {
      noLeidasUsuario.value = 0;
      return const SincronizacionMatchUsuario(tienePersonalidad: false);
    }
    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/usuarios/$id/match-sincronizar',
      ).replace(
        queryParameters: {'_': '${DateTime.now().microsecondsSinceEpoch}'},
      );
      final resp = await http.get(
        uri,
        headers: {
          'x-usuario-id': id,
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );
      if (resp.statusCode != 200) {
        return const SincronizacionMatchUsuario(tienePersonalidad: false);
      }
      final data = jsonDecode(resp.body);
      if (data is! Map<String, dynamic>) {
        return const SincronizacionMatchUsuario(tienePersonalidad: false);
      }
      final listaRaw = data['notificaciones'];
      final notifs = listaRaw is List
          ? listaRaw
              .whereType<Map>()
              .map(
                (e) => NotificacionMatchMascota.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : <NotificacionMatchMascota>[];
      final noLeidas = data['no_leidas'] is int
          ? data['no_leidas'] as int
          : notifs.where((n) => !n.leida).length;
      noLeidasUsuario.value = noLeidas;

      final rawPct = data['porcentaje_match_inicial'];
      final pctInicial = rawPct is num
          ? rawPct.toDouble()
          : double.tryParse('${rawPct ?? ''}');

      final idInicialRaw = data['id_mascota_match_inicial']?.toString().trim();

      return SincronizacionMatchUsuario(
        tienePersonalidad: data['tiene_personalidad'] == true,
        idMascotaMatchInicial:
            (idInicialRaw != null && idInicialRaw.isNotEmpty)
                ? idInicialRaw
                : null,
        porcentajeMatchInicial: pctInicial,
        notificaciones: notifs,
        noLeidas: noLeidas,
      );
    } catch (_) {
      return const SincronizacionMatchUsuario(tienePersonalidad: false);
    }
  }

  /// Marca como leída y/o mostrada una notificación de nueva coincidencia en la BD.
  static Future<void> marcarNotificacionLeida({
    String? idMascota,
    String? idNotificacion,
    bool soloMostrada = false,
  }) async {
    final id = Session.idUsuario;
    if (id == null || id.isEmpty) return;
    try {
      await http.patch(
        Uri.parse('${ApiService.baseUrl}/usuarios/$id/notificaciones-match/leer'),
        headers: {
          'Content-Type': 'application/json',
          'x-usuario-id': id,
        },
        body: jsonEncode({
          if (idMascota != null) 'id_mascota': idMascota,
          if (idNotificacion != null) 'id_notificacion': idNotificacion,
          'solo_mostrada': soloMostrada,
        }),
      );
      await sincronizar();
    } catch (_) {}
  }

  static Future<RankingMatch> mejores() async {
    final publicadas = MatchEstado.instancia.respuestas;
    final mascotasFuture = PetsService.listar();
    final nombreFuture = _nombreUsuario();
    final syncFuture = sincronizar();

    final usuario = publicadas ?? await PersonalidadUsuarioService.obtener();
    final nombre = await nombreFuture;
    if (usuario == null) {
      return RankingMatch(
        tienePersonalidad: false,
        nombreUsuario: nombre,
        usuario: const {},
        mejores: const [],
      );
    }

    final mascotas = await mascotasFuture;
    final sync = await syncFuture;
    final idMatchInicial = sync.idMascotaMatchInicial;

    final resultados = <CompatibilidadMatch>[];
    CompatibilidadMatch? matchInicialGuardado;

    for (final mascota in mascotas) {
      final esInicial = idMatchInicial != null && mascota.id == idMatchInicial;
      // El Match inicial del usuario se conserva siempre (incluso si luego fue adoptada por él);
      // para las demás solo entran mascotas disponibles con personalidad definida.
      if (!esInicial && (mascota.estaAdoptada || !mascota.personalidadDefinida)) {
        continue;
      }
      if (!mascota.personalidadDefinida) continue;

      final calculo = calcular(usuario, mascota.personalidad);
      if (calculo == null) continue;

      final item = CompatibilidadMatch(
        mascota: mascota,
        porcentaje: calculo.$1,
        rasgosOrdenados: calculo.$2,
        esMatchInicial: esInicial,
      );

      if (esInicial) {
        matchInicialGuardado = item;
      } else if (!mascota.estaAdoptada) {
        resultados.add(item);
      }
    }

    resultados.sort((a, b) {
      final porPorcentaje = b.porcentaje.compareTo(a.porcentaje);
      if (porPorcentaje != 0) return porPorcentaje;
      return a.mascota.nombre.toLowerCase().compareTo(
        b.mascota.nombre.toLowerCase(),
      );
    });

    // El Match inicial siempre va primero como «Mi Match Perfecto»,
    // seguido de las mejores nuevas coincidencias sin reemplazar nunca el Match inicial.
    final listaFinal = <CompatibilidadMatch>[
      if (matchInicialGuardado != null) matchInicialGuardado,
      ...resultados,
    ];

    return RankingMatch(
      tienePersonalidad: true,
      nombreUsuario: nombre,
      usuario: usuario,
      idMascotaMatchInicial:
          matchInicialGuardado?.mascota.id ??
          (listaFinal.isNotEmpty ? listaFinal.first.mascota.id : null),
      mejores: listaFinal.length <= limite
          ? listaFinal
          : listaFinal.sublist(0, limite),
    );
  }

  /// `Usuario.nombres` de la persona en sesión. Si la consulta falla, usa
  /// el nombre que quedó guardado al iniciar sesión.
  static Future<String> _nombreUsuario() async {
    final id = Session.idUsuario;
    if (id != null && id.isNotEmpty) {
      try {
        final perfil = await ApiService.obtenerUsuario(id);
        final nombres = perfil.nombres.trim();
        if (nombres.isNotEmpty) return nombres;
      } catch (_) {}
    }
    final sesion = Session.nombre.trim();
    return sesion.isEmpty ? 'Tú' : sesion;
  }

  /// `null` si la mascota no tiene respuestas de personalidad.
  /// Devuelve el porcentaje (dos decimales) y las claves ordenadas por cercanía.
  static (double, List<String>)? calcular(
    Map<String, int> usuario,
    Map<String, dynamic> mascota,
  ) {
    final cercanos = <({String clave, int distancia})>[];
    var suma = 0.0;

    for (final rasgo in rasgosMascota) {
      final valorUsuario = usuario[rasgo.clave];
      final valorMascota = _entero(mascota[rasgo.clave]);
      if (valorUsuario == null || valorMascota == null) return null;
      final distancia = (valorUsuario - valorMascota).abs().clamp(0, 4);
      suma += 1 - (distancia / 4);
      cercanos.add((clave: rasgo.clave, distancia: distancia));
    }

    if (cercanos.isEmpty) return null;
    cercanos.sort((a, b) => a.distancia.compareTo(b.distancia));
    final porcentaje = (suma / cercanos.length) * 100;
    final redondeado = ((porcentaje * 100).round() / 100).clamp(0, 100);
    return (redondeado.toDouble(), [for (final c in cercanos) c.clave]);
  }

  static int? _entero(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}
