import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/personalidad_usuario_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';

/// Una mascota y su `porcentaje_match` (tabla `Match`, de 0 a 100).
class CompatibilidadMatch {
  final Pet mascota;
  final double porcentaje;

  /// Claves de `PreguntaPersonalidad`, de la respuesta más parecida a la menos.
  final List<String> rasgosOrdenados;

  const CompatibilidadMatch({
    required this.mascota,
    required this.porcentaje,
    required this.rasgosOrdenados,
  });

  int get porcentajeEntero => porcentaje.round().clamp(0, 100);
}

/// Las tres mascotas más compatibles con la persona en sesión.
class RankingMatch {
  final bool tienePersonalidad;

  /// Nombre de pila leído de `Usuario.nombres`.
  final String nombreUsuario;
  final Map<String, int> usuario;
  final List<CompatibilidadMatch> mejores;

  const RankingMatch({
    required this.tienePersonalidad,
    required this.nombreUsuario,
    required this.usuario,
    required this.mejores,
  });
}

/// Compara `PersonalidadUsuario` con `PersonalidadMascota`.
///
/// Cada columna es una dimensión de `PreguntaPersonalidad` (la respuesta que
/// el cuestionario guarda para la persona y para la mascota, escala de 1 a 5).
/// El resultado es el `porcentaje_match` de la tabla `Match`: 100 si todas las
/// respuestas coinciden y 0 si todas están en extremos opuestos.
class MatchService {
  static const int limite = 3;

  static Future<RankingMatch> mejores() async {
    final personalidadFuture = PersonalidadUsuarioService.obtener();
    final mascotasFuture = PetsService.listar();
    final nombreFuture = _nombreUsuario();

    final usuario = await personalidadFuture;
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
    final resultados = <CompatibilidadMatch>[];
    for (final mascota in mascotas) {
      final calculo = calcular(usuario, mascota.personalidad);
      if (calculo == null) continue;
      resultados.add(
        CompatibilidadMatch(
          mascota: mascota,
          porcentaje: calculo.$1,
          rasgosOrdenados: calculo.$2,
        ),
      );
    }

    resultados.sort((a, b) {
      final porPorcentaje = b.porcentaje.compareTo(a.porcentaje);
      if (porPorcentaje != 0) return porPorcentaje;
      return a.mascota.nombre.toLowerCase().compareTo(
        b.mascota.nombre.toLowerCase(),
      );
    });

    return RankingMatch(
      tienePersonalidad: true,
      nombreUsuario: nombre,
      usuario: usuario,
      mejores: resultados.length <= limite
          ? resultados
          : resultados.sublist(0, limite),
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
      if (valorUsuario == null || valorMascota == null) continue;
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
