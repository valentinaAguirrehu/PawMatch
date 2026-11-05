import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:paw_match/services/entrevista_personalidad_service.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum EstadoReproduccionVoz {
  inactivo,
  reproduciendo,
  pausado,
}

/// Controlador de voz y reproducción continua del Asistente de Paw Match.
/// Conserva:
/// - Identificador del mensaje (`idMensajeActual`)
/// - Texto original (`textoOriginalActual`)
/// - Velocidad actual (`multiplicadorVelocidad`, predeterminada en X3 = 3.0)
/// - Estado de reproducción (`estado`: inactivo, reproduciendo, pausado)
/// - Posición exacta de lectura (`posicionCaracterActual`)
/// - Tiempo transcurrido (`tiempoTranscurrido`)
/// - Estado de pausa (`estaEnPausa`)
class VozEntrevista {
  static const List<double> velocidadesDisponibles = <double>[
    1.0,
    1.5,
    2.0,
    3.0,
  ];

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _grabadora = AudioRecorder();

  bool vozActiva = true;

  /// Velocidad predeterminada: X3 (3.0)
  double _multiplicadorVelocidad = 3.0;

  EstadoReproduccionVoz _estado = EstadoReproduccionVoz.inactivo;
  String? _idMensajeActual;
  String _textoOriginalActual = '';
  String _textoLimpioCompleto = '';
  final Set<String> _mensajesFinalizados = <String>{};
  final List<({String idMensaje, String texto})> _colaMensajes =
      <({String idMensaje, String texto})>[];

  /// Posición exacta del carácter donde va la lectura dentro de `_textoLimpioCompleto`.
  int _posicionCaracterActual = 0;

  /// Offset base desde el cual comenzó el segmento actual enviado al motor TTS.
  int _offsetBaseSegmento = 0;
  bool _progresoNativoRecibidoEnSegmento = false;

  /// Control de tiempo transcurrido y estimación de respaldo cuando el motor no emite eventos por palabra.
  DateTime? _inicioSegmento;
  Duration _tiempoAcumuladoPrevio = Duration.zero;
  Timer? _timerSeguimiento;

  /// Token incremental para ignorar eventos `onCancel` / `onComplete` obsoletos
  /// al cambiar de velocidad en caliente o pausar.
  int _tokenOperacion = 0;

  bool _ttsListo = false;
  bool _speechListo = false;
  bool _usandoArchivo = false;
  bool _grabandoArchivo = false;
  String _parcial = '';
  String? _rutaAudio;
  void Function(String texto)? _alCambiar;

  /// Callback opcional para notificar a la interfaz cambios en el estado/progreso de reproducción.
  VoidCallback? alCambiarEstadoReproduccion;

  bool get usaArchivo => _usandoArchivo;
  bool get hablando => _estado == EstadoReproduccionVoz.reproduciendo;
  bool get estaEnPausa => _estado == EstadoReproduccionVoz.pausado;
  EstadoReproduccionVoz get estado => _estado;
  String? get idMensajeActual => _idMensajeActual;
  String get textoOriginalActual => _textoOriginalActual;
  double get multiplicadorVelocidad => _multiplicadorVelocidad;
  int get posicionCaracterActual => _posicionCaracterActual;

  Duration get tiempoTranscurrido {
    if (_estado == EstadoReproduccionVoz.reproduciendo &&
        _inicioSegmento != null) {
      return _tiempoAcumuladoPrevio +
          DateTime.now().difference(_inicioSegmento!);
    }
    return _tiempoAcumuladoPrevio;
  }

  double get progresoLectura {
    if (_textoLimpioCompleto.isEmpty) return 0.0;
    return (_posicionCaracterActual / _textoLimpioCompleto.length).clamp(
      0.0,
      1.0,
    );
  }

  /// Indica si un mensaje específico ya terminó su reproducción al 100%.
  bool esFinalizado(String idMensaje) {
    if (_idMensajeActual == idMensaje &&
        (_estado == EstadoReproduccionVoz.reproduciendo ||
            _estado == EstadoReproduccionVoz.pausado)) {
      return false;
    }
    return _mensajesFinalizados.contains(idMensaje);
  }

  /// Devuelve el progreso de lectura (0.0 a 1.0) para un mensaje específico.
  double progresoDeMensaje(String idMensaje) {
    if (_idMensajeActual == idMensaje &&
        (_estado == EstadoReproduccionVoz.reproduciendo ||
            _estado == EstadoReproduccionVoz.pausado)) {
      return progresoLectura;
    }
    if (_mensajesFinalizados.contains(idMensaje)) {
      return 1.0;
    }
    return 0.0;
  }

  String get etiquetaVelocidad {
    if (_multiplicadorVelocidad == 1.0) return 'X1';
    if (_multiplicadorVelocidad == 1.5) return 'X1.5';
    if (_multiplicadorVelocidad == 2.0) return 'X2';
    return 'X3';
  }

  double _tasaTtsActual() {
    if (_multiplicadorVelocidad >= 3.0) return 0.98;
    if (_multiplicadorVelocidad >= 2.0) return 0.82;
    if (_multiplicadorVelocidad >= 1.5) return 0.67;
    return 0.52;
  }

  /// Caracteres por segundo estimados según la velocidad actual (respaldo cuando el TTS no reporta `onProgress`).
  double _caracteresPorSegundoActual() {
    if (_multiplicadorVelocidad >= 3.0) return 29.0;
    if (_multiplicadorVelocidad >= 2.0) return 22.0;
    if (_multiplicadorVelocidad >= 1.5) return 17.5;
    return 13.0;
  }

  bool get _reconocimientoLocal {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  void _notificarEstado() {
    alCambiarEstadoReproduccion?.call();
  }

  void _marcarMensajeActualFinalizado() {
    if (_estado != EstadoReproduccionVoz.reproduciendo) return;
    _timerSeguimiento?.cancel();
    if (_inicioSegmento != null) {
      _tiempoAcumuladoPrevio += DateTime.now().difference(_inicioSegmento!);
      _inicioSegmento = null;
    }
    _posicionCaracterActual = _textoLimpioCompleto.length;
    if (_idMensajeActual != null) {
      _mensajesFinalizados.add(_idMensajeActual!);
    }
    if (_colaMensajes.isNotEmpty && vozActiva) {
      final siguiente = _colaMensajes.removeAt(0);
      _hablarInterno(
        siguiente.texto,
        idMensaje: siguiente.idMensaje,
        limpiarCola: false,
      );
      return;
    }
    _estado = EstadoReproduccionVoz.inactivo;
    _notificarEstado();
  }

  void _iniciarTimerSeguimiento(int token) {
    _timerSeguimiento?.cancel();
    _timerSeguimiento = Timer.periodic(const Duration(milliseconds: 140), (t) {
      if (token != _tokenOperacion ||
          _estado != EstadoReproduccionVoz.reproduciendo) {
        t.cancel();
        return;
      }
      if (!_progresoNativoRecibidoEnSegmento &&
          _inicioSegmento != null &&
          _textoLimpioCompleto.isNotEmpty) {
        final segs =
            DateTime.now().difference(_inicioSegmento!).inMilliseconds / 1000.0;
        final avance = (segs * _caracteresPorSegundoActual()).round();
        final maxAntesDeFin = (_textoLimpioCompleto.length - 1).clamp(
          0,
          _textoLimpioCompleto.length,
        );
        final estimado = (_offsetBaseSegmento + avance).clamp(
          _offsetBaseSegmento,
          maxAntesDeFin,
        );
        if (estimado > _posicionCaracterActual) {
          _posicionCaracterActual = estimado;
        }
        final restanteEstimado =
            _textoLimpioCompleto.length - _offsetBaseSegmento;
        final margenExtra = (_caracteresPorSegundoActual() * 1.4).round();
        if (avance >= restanteEstimado + margenExtra) {
          _marcarMensajeActualFinalizado();
          return;
        }
      }
      _notificarEstado();
    });
  }

  Future<void> preparar() async {
    if (_ttsListo) return;
    try {
      await _tts.setLanguage('es-ES');
      await _elegirVozMasNatural();
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(_tasaTtsActual());
      await _tts.setVolume(1);

      _tts.setProgressHandler((
        String text,
        int startOffset,
        int endOffset,
        String word,
      ) {
        if (_estado != EstadoReproduccionVoz.reproduciendo) return;
        _progresoNativoRecibidoEnSegmento = true;
        final nuevaPos = (_offsetBaseSegmento + startOffset).clamp(
          0,
          _textoLimpioCompleto.length,
        );
        if (nuevaPos >= _offsetBaseSegmento) {
          _posicionCaracterActual = nuevaPos;
          _notificarEstado();
        }
      });

      _tts.setCompletionHandler(() {
        _marcarMensajeActualFinalizado();
      });

      _tts.setErrorHandler((_) {
        if (_estado != EstadoReproduccionVoz.reproduciendo) return;
        _timerSeguimiento?.cancel();
        _inicioSegmento = null;
        _estado = EstadoReproduccionVoz.inactivo;
        _notificarEstado();
      });

      _ttsListo = true;
    } catch (_) {
      _ttsListo = false;
    }
  }

  /// Ajusta un índice de carácter al inicio de la palabra actual o siguiente
  /// para no cortar una palabra a la mitad al cambiar de velocidad o reanudar.
  int _ajustarAlLimiteDePalabra(String texto, int indice) {
    if (texto.isEmpty) return 0;
    var pos = indice.clamp(0, texto.length);
    if (pos <= 0) return 0;
    if (pos >= texto.length) return texto.length;

    // Si cayó en medio de una palabra, avanzar hasta el siguiente espacio para no repetir la sílaba ya leída,
    // o retroceder al inicio de esa palabra si está apenas comenzándola.
    while (pos > 0 && texto[pos - 1] != ' ') {
      pos--;
    }
    return pos;
  }

  /// Actualiza la posición exacta antes de una transición (pausa o cambio de velocidad).
  void _consolidarPosicionYTiempoActual() {
    if (_inicioSegmento != null) {
      final delta = DateTime.now().difference(_inicioSegmento!);
      _tiempoAcumuladoPrevio += delta;
      if (!_progresoNativoRecibidoEnSegmento &&
          _textoLimpioCompleto.isNotEmpty) {
        final segs = delta.inMilliseconds / 1000.0;
        final avance = (segs * _caracteresPorSegundoActual()).round();
        _posicionCaracterActual = (_offsetBaseSegmento + avance).clamp(
          _offsetBaseSegmento,
          _textoLimpioCompleto.length,
        );
      }
      _inicioSegmento = null;
    }
    _posicionCaracterActual = _ajustarAlLimiteDePalabra(
      _textoLimpioCompleto,
      _posicionCaracterActual,
    );
  }

  /// Reproduce el segmento pendiente a partir de `_posicionCaracterActual` con la velocidad activa.
  Future<void> _reproducirDesdePosicionActual() async {
    if (!vozActiva || _textoLimpioCompleto.isEmpty) return;

    final token = ++_tokenOperacion;
    _timerSeguimiento?.cancel();

    if (_posicionCaracterActual >= _textoLimpioCompleto.length) {
      _posicionCaracterActual = 0;
      _tiempoAcumuladoPrevio = Duration.zero;
    }

    final subtexto = _textoLimpioCompleto
        .substring(_posicionCaracterActual)
        .trimLeft();
    if (subtexto.isEmpty) {
      _estado = EstadoReproduccionVoz.inactivo;
      _notificarEstado();
      return;
    }

    final caracteresDescartados =
        (_textoLimpioCompleto.length - _posicionCaracterActual) -
        subtexto.length;
    _offsetBaseSegmento = _posicionCaracterActual + caracteresDescartados;
    _posicionCaracterActual = _offsetBaseSegmento;
    _progresoNativoRecibidoEnSegmento = false;

    try {
      await preparar();
      await _tts.stop();
      // Pequeña pausa de 55ms para que el motor de síntesis (especialmente en Web y Windows)
      // procese el stop() sin cancelar la nueva locución que continúa desde el punto exacto.
      await Future<void>.delayed(const Duration(milliseconds: 55));
      if (token != _tokenOperacion) return;

      await _tts.setSpeechRate(_tasaTtsActual());
      _estado = EstadoReproduccionVoz.reproduciendo;
      _inicioSegmento = DateTime.now();
      _iniciarTimerSeguimiento(token);
      _notificarEstado();

      await _tts.speak(subtexto);
    } catch (_) {
      if (token == _tokenOperacion) {
        _timerSeguimiento?.cancel();
        _estado = EstadoReproduccionVoz.inactivo;
        _notificarEstado();
      }
    }
  }

  /// Cambia la velocidad (X1, X1.5, X2, X3).
  /// Si el asistente está leyendo un mensaje en este momento, detecta el punto exacto,
  /// actualiza la velocidad y continúa la lectura desde esa palabra sin volver al inicio.
  Future<void> cambiarVelocidad(double nuevoMultiplicador) async {
    if (_multiplicadorVelocidad == nuevoMultiplicador) return;
    _multiplicadorVelocidad = nuevoMultiplicador;

    if (_estado == EstadoReproduccionVoz.reproduciendo &&
        vozActiva &&
        _textoLimpioCompleto.isNotEmpty) {
      _consolidarPosicionYTiempoActual();
      if (_posicionCaracterActual < _textoLimpioCompleto.length) {
        await _reproducirDesdePosicionActual();
        return;
      }
    } else {
      try {
        await preparar();
        await _tts.setSpeechRate(_tasaTtsActual());
      } catch (_) {}
    }
    _notificarEstado();
  }

  Future<void> siguienteVelocidad() async {
    final idx = velocidadesDisponibles.indexOf(_multiplicadorVelocidad);
    final sig = idx == -1 || idx + 1 >= velocidadesDisponibles.length
        ? velocidadesDisponibles.first
        : velocidadesDisponibles[idx + 1];
    await cambiarVelocidad(sig);
  }

  /// Reproduce un mensaje desde el principio (o para «🔊 Volver a escuchar»).
  /// No genera otra respuesta de GPT ni reinicia la conversación.
  Future<void> hablar(
    String texto, {
    String? idMensaje,
    bool forzarActivarVoz = false,
  }) async {
    if (forzarActivarVoz) {
      vozActiva = true;
    }
    await _hablarInterno(
      texto,
      idMensaje: idMensaje,
      limpiarCola: true,
    );
  }

  /// Reproduce una secuencia de mensajes uno tras otro (por ejemplo, saludo de bienvenida
  /// seguido de la primera pregunta), manteniendo el indicador de progreso independiente de cada uno.
  Future<void> hablarSecuencia(
    List<({String idMensaje, String texto})> mensajes,
  ) async {
    _colaMensajes.clear();
    if (mensajes.isEmpty) return;
    final primero = mensajes.first;
    if (mensajes.length > 1) {
      _colaMensajes.addAll(mensajes.skip(1));
    }
    await _hablarInterno(
      primero.texto,
      idMensaje: primero.idMensaje,
      limpiarCola: false,
    );
  }

  Future<void> _hablarInterno(
    String texto, {
    String? idMensaje,
    required bool limpiarCola,
  }) async {
    if (limpiarCola) {
      _colaMensajes.clear();
    }
    final limpio = _paraHablar(texto);
    final id = idMensaje ?? 'msg_${texto.hashCode}';
    _idMensajeActual = id;
    _mensajesFinalizados.remove(id);
    _textoOriginalActual = texto;
    _textoLimpioCompleto = limpio;
    _posicionCaracterActual = 0;
    _offsetBaseSegmento = 0;
    _tiempoAcumuladoPrevio = Duration.zero;
    _inicioSegmento = null;

    if (!vozActiva || limpio.isEmpty) {
      _estado = EstadoReproduccionVoz.inactivo;
      _notificarEstado();
      return;
    }

    await _reproducirDesdePosicionActual();
  }

  /// Pausa la reproducción actual conservando el punto exacto de lectura.
  Future<void> pausar() async {
    if (_estado != EstadoReproduccionVoz.reproduciendo) return;
    ++_tokenOperacion;
    _timerSeguimiento?.cancel();
    _consolidarPosicionYTiempoActual();
    _estado = EstadoReproduccionVoz.pausado;
    try {
      await _tts.stop();
    } catch (_) {}
    _notificarEstado();
  }

  /// Continúa la reproducción exactamente desde el punto donde fue pausada.
  Future<void> continuar() async {
    if (_estado != EstadoReproduccionVoz.pausado ||
        _textoLimpioCompleto.isEmpty) {
      return;
    }
    vozActiva = true;
    await _reproducirDesdePosicionActual();
  }

  /// Vuelve a escuchar un mensaje específico desde el inicio con la velocidad actual.
  Future<void> volverAEscuchar({
    required String idMensaje,
    required String texto,
  }) async {
    await hablar(texto, idMensaje: idMensaje, forzarActivarVoz: true);
  }

  Future<void> callar() async {
    ++_tokenOperacion;
    _colaMensajes.clear();
    _timerSeguimiento?.cancel();
    _inicioSegmento = null;
    _estado = EstadoReproduccionVoz.inactivo;
    try {
      await _tts.stop();
    } catch (_) {}
    _notificarEstado();
  }

  static bool _esCaracterLegible(int r) {
    // Solo letras, números, espacios y signos de puntuación del español (Latin-1).
    // Esto excluye el 100% de los emojis y símbolos Unicode (> 0x00FF).
    if (r >= 0x0020 && r <= 0x00FF) return true;
    return r == 0x2013 ||
        r == 0x2014 ||
        r == 0x201C ||
        r == 0x201D ||
        r == 0x2026;
  }

  /// El dispositivo se traba en formas como «activo/a» y solo debe leer hasta el punto final sin emojis.
  String _paraHablar(String texto) {
    var limpio = String.fromCharCodes(texto.runes.where(_esCaracterLegible))
        .replaceAll(RegExp('o/a'), 'a')
        .replaceAll(RegExp('O/A'), 'A')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Cortar exactamente hasta el último signo de cierre (., !, ?)
    final ultimoPunto = limpio.lastIndexOf(RegExp(r'[.!?]'));
    if (ultimoPunto != -1) {
      limpio = limpio.substring(0, ultimoPunto + 1).trim();
    }
    return limpio;
  }

  Future<void> _elegirVozMasNatural() async {
    try {
      final crudas = await _tts.getVoices;
      if (crudas is! List) return;
      Map<dynamic, dynamic>? mejor;
      var mejorPuntos = -999;
      for (final item in crudas) {
        if (item is! Map) continue;
        final nombre = item['name']?.toString() ?? '';
        final locale = (item['locale'] ?? item['language'])?.toString() ?? '';
        if (nombre.isEmpty || !_esEspanol(locale, nombre)) continue;
        final puntos = _puntosVoz(nombre, locale, item);
        if (puntos > mejorPuntos) {
          mejorPuntos = puntos;
          mejor = item;
        }
      }
      if (mejor == null) return;
      await _tts.setVoice({
        'name': mejor['name'].toString(),
        'locale': (mejor['locale'] ?? mejor['language']).toString(),
      });
    } catch (_) {}
  }

  bool _esEspanol(String locale, String nombre) {
    final id = '${locale}_$nombre'.toLowerCase();
    return id.contains('es-') ||
        id.contains('es_') ||
        id.contains('spanish') ||
        id.contains('español');
  }

  int _puntosVoz(String nombre, String locale, Map<dynamic, dynamic> item) {
    final n = nombre.toLowerCase();
    final l = locale.toLowerCase().replaceAll('_', '-');
    final calidad = item['quality']?.toString().toLowerCase() ?? '';
    var puntos = 0;
    if (n.contains('natural') || n.contains('neural') || n.contains('premium')) {
      puntos += 50;
    }
    if (calidad.contains('very high') || calidad == 'premium') {
      puntos += 40;
    }
    if (calidad == 'high' || calidad == 'enhanced' || n.contains('enhanced')) {
      puntos += 25;
    }
    if (l.startsWith('es-co')) {
      puntos += 8;
    } else if (l.startsWith('es-mx')) {
      puntos += 6;
    } else if (l.startsWith('es-es')) {
      puntos += 4;
    } else if (l.startsWith('es')) {
      puntos += 2;
    }
    if (n.contains('desktop')) {
      puntos -= 8;
    }
    if (item['network_required']?.toString() == '1') {
      puntos -= 4;
    }
    return puntos;
  }

  Future<void> empezar({required void Function(String texto) alCambiar}) async {
    await callar();
    _alCambiar = alCambiar;
    _parcial = '';
    _usandoArchivo = false;
    if (_reconocimientoLocal) {
      try {
        await _empezarLocal();
        return;
      } catch (_) {
        if (kIsWeb) {
          throw Exception(
            'El micrófono no está disponible en este navegador. Escribe tu respuesta.',
          );
        }
      }
    }
    await _empezarArchivo();
  }

  Future<String> detener() async {
    if (_usandoArchivo) {
      if (!_grabandoArchivo) return _parcial.trim();
      _grabandoArchivo = false;
      final ruta = await _grabadora.stop();
      if (ruta == null || ruta.isEmpty) return '';
      return EntrevistaPersonalidadService.transcribir(ruta);
    }
    if (_speech.isListening) {
      await _speech.stop();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return _parcial.trim();
  }

  Future<void> cerrar() async {
    _timerSeguimiento?.cancel();
    alCambiarEstadoReproduccion = null;
    await callar();
    try {
      if (_speech.isListening) await _speech.cancel();
    } catch (_) {}
    try {
      if (_grabandoArchivo) await _grabadora.stop();
    } catch (_) {}
    try {
      await _grabadora.dispose();
    } catch (_) {}
  }

  Future<void> _empezarLocal() async {
    if (!_speechListo) {
      final ok = await _speech.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
      if (!ok) {
        throw Exception(
          'No tengo permiso para usar el micrófono. Puedes escribir la respuesta.',
        );
      }
      _speechListo = true;
    }
    final locale = await _localeEspanol();
    await _speech.listen(
      onResult: (resultado) {
        _parcial = resultado.recognizedWords;
        _alCambiar?.call(_parcial);
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        localeId: locale,
      ),
    );
    if (!_speech.isListening && _parcial.isEmpty) {
      throw Exception(
        'No pude iniciar el micrófono. Puedes escribir la respuesta.',
      );
    }
  }

  Future<String?> _localeEspanol() async {
    try {
      final locales = await _speech.locales();
      const preferidos = ['es_CO', 'es-CO', 'es_ES', 'es-ES', 'es_MX', 'es-MX'];
      for (final id in preferidos) {
        for (final locale in locales) {
          if (locale.localeId == id) return locale.localeId;
        }
      }
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase();
        if (id.startsWith('es_') || id.startsWith('es-')) return locale.localeId;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _empezarArchivo() async {
    final permiso = await _grabadora.hasPermission();
    if (!permiso) {
      throw Exception(
        'No tengo permiso para usar el micrófono. Puedes escribir la respuesta.',
      );
    }
    final dir = await getTemporaryDirectory();
    final wav = p.join(dir.path, 'pawmatch_entrevista.wav');
    try {
      await _grabadora.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: wav,
      );
      _rutaAudio = wav;
    } catch (_) {
      final m4a = p.join(dir.path, 'pawmatch_entrevista.m4a');
      await _grabadora.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: m4a,
      );
      _rutaAudio = m4a;
    }
    if (_rutaAudio == null) {
      throw Exception(
        'No pude iniciar el micrófono. Puedes escribir la respuesta.',
      );
    }
    _usandoArchivo = true;
    _grabandoArchivo = true;
  }
}
