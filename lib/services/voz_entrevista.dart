import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:paw_match/services/entrevista_personalidad_service.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Lee las preguntas y convierte la voz en texto.
/// Primero usa el reconocimiento del dispositivo. Si no está disponible,
/// graba un audio y el servidor lo transcribe.
class VozEntrevista {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _grabadora = AudioRecorder();

  bool vozActiva = true;
  bool _ttsListo = false;
  bool _speechListo = false;
  bool _usandoArchivo = false;
  bool _grabandoArchivo = false;
  String _parcial = '';
  String? _rutaAudio;
  void Function(String texto)? _alCambiar;

  bool get usaArchivo => _usandoArchivo;

  bool get _reconocimientoLocal {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<void> preparar() async {
    if (_ttsListo) return;
    try {
      await _tts.setLanguage('es-ES');
      await _elegirVozMasNatural();
      // En Windows, si el tono queda en 0 el plugin lo baja demasiado y suena cortada.
      await _tts.setPitch(1.0);
      // 0.5 es el ritmo normal. Un poco por encima suena más conversada.
      await _tts.setSpeechRate(0.58);
      await _tts.setVolume(1);
      _ttsListo = true;
    } catch (_) {
      _ttsListo = false;
    }
  }

  Future<void> hablar(String texto) async {
    if (!vozActiva) return;
    final limpio = _paraHablar(texto);
    if (limpio.isEmpty) return;
    try {
      await preparar();
      await _tts.stop();
      await _tts.speak(limpio);
    } catch (_) {}
  }

  static bool _esCaracterLegible(int r) {
    // Solo letras, números, espacios y signos de puntuación del español (Latin-1).
    // Esto excluye el 100% de los emojis y símbolos Unicode (> 0x00FF).
    if (r >= 0x0020 && r <= 0x00FF) return true;
    return r == 0x2013 || r == 0x2014 || r == 0x201C || r == 0x201D || r == 0x2026;
  }

  /// El dispositivo se traba en formas como «activo/a» y solo debe leer hasta el punto final sin emojis.
  String _paraHablar(String texto) {
    var limpio = String.fromCharCodes(
      texto.runes.where(_esCaracterLegible),
    )
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

  Future<void> callar() async {
    try {
      await _tts.stop();
    } catch (_) {}
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
      throw Exception('No pude iniciar el micrófono. Puedes escribir la respuesta.');
    }
    _usandoArchivo = true;
    _grabandoArchivo = true;
  }
}
