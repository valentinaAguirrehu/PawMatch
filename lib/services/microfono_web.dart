import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:paw_match/services/audio_grabado.dart';
import 'package:web/web.dart' as web;

export 'package:paw_match/services/audio_grabado.dart';

web.MediaStream? _stream;
web.MediaRecorder? _grabadora;
final List<web.Blob> _trozos = <web.Blob>[];
String _mime = '';
Completer<void>? _alDetener;

/// Pide el micrófono en el mismo toque del botón. Hay que conservar el flujo:
/// si se cierra y se vuelve a pedir, varios celulares muestran otro permiso
/// o rechazan la segunda vez.
Future<bool> pedirMicrofono() async {
  try {
    final anterior = _stream;
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart;
    if (anterior != null) {
      for (final pista in anterior.getAudioTracks().toDart) {
        pista.stop();
      }
    }
    _stream = stream;
    return stream.getAudioTracks().toDart.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<void> iniciarGrabacion() async {
  final stream = _stream;
  if (stream == null || stream.getAudioTracks().toDart.isEmpty) {
    throw Exception(
      'El navegador no dejó usar el micrófono. En el celular, abre la configuración del sitio y permite el micrófono. Luego toca el botón otra vez.',
    );
  }
  await cancelarGrabacion(conservarMicrofono: true);
  _trozos.clear();
  final mime = _mimeDisponible();
  final grabadora = mime.isEmpty
      ? web.MediaRecorder(stream)
      : web.MediaRecorder(
          stream,
          web.MediaRecorderOptions(mimeType: mime),
        );
  _mime = grabadora.mimeType.isEmpty ? mime : grabadora.mimeType;
  grabadora.ondataavailable = ((web.BlobEvent evento) {
    if (evento.data.size > 0) _trozos.add(evento.data);
  }).toJS;
  grabadora.onstop = ((web.Event _) {
    final espera = _alDetener;
    if (espera != null && !espera.isCompleted) espera.complete();
  }).toJS;
  grabadora.start(250);
  if (grabadora.state != 'recording') {
    throw Exception(
      'No pude iniciar el micrófono. Permite el micrófono en el navegador y vuelve a tocarlo.',
    );
  }
  _grabadora = grabadora;
}

Future<AudioGrabado> detenerGrabacion() async {
  final grabadora = _grabadora;
  _grabadora = null;
  if (grabadora == null || grabadora.state == 'inactive') {
    _cerrarMicrofono();
    throw Exception(
      'No se grabó audio. Habla y toca otra vez el micrófono para transcribir.',
    );
  }
  final espera = Completer<void>();
  _alDetener = espera;
  grabadora.stop();
  await espera.future.timeout(const Duration(seconds: 3), onTimeout: () {});
  _alDetener = null;
  final mime = _mime.isEmpty ? 'audio/webm' : _mime;
  final blob = web.Blob(
    _trozos.toJS,
    web.BlobPropertyBag(type: mime),
  );
  _trozos.clear();
  _cerrarMicrofono();
  final bytes = await _leerBlob(blob);
  return AudioGrabado(bytes: bytes, nombre: _nombre(mime));
}

Future<void> cancelarGrabacion({bool conservarMicrofono = false}) async {
  final grabadora = _grabadora;
  _grabadora = null;
  if (grabadora != null && grabadora.state != 'inactive') {
    try {
      grabadora.stop();
    } catch (_) {}
  }
  _trozos.clear();
  if (!conservarMicrofono) _cerrarMicrofono();
}

String _mimeDisponible() {
  const candidatos = <String>[
    'audio/webm;codecs=opus',
    'audio/webm',
    'audio/mp4',
    'audio/aac',
  ];
  for (final tipo in candidatos) {
    if (web.MediaRecorder.isTypeSupported(tipo)) return tipo;
  }
  return '';
}

String _nombre(String mime) {
  final tipo = mime.toLowerCase();
  if (tipo.contains('mp4') || tipo.contains('aac') || tipo.contains('m4a')) {
    return 'respuesta.m4a';
  }
  if (tipo.contains('wav')) return 'respuesta.wav';
  if (tipo.contains('ogg')) return 'respuesta.ogg';
  return 'respuesta.webm';
}

void _cerrarMicrofono() {
  final stream = _stream;
  _stream = null;
  if (stream == null) return;
  for (final pista in stream.getAudioTracks().toDart) {
    pista.stop();
  }
}

Future<Uint8List> _leerBlob(web.Blob blob) {
  final lector = web.FileReader();
  final listo = Completer<Uint8List>();
  lector.onloadend = ((web.Event _) {
    if (listo.isCompleted) return;
    final resultado = lector.result;
    if (resultado == null) {
      listo.complete(Uint8List(0));
      return;
    }
    listo.complete((resultado as JSArrayBuffer).toDart.asUint8List());
  }).toJS;
  lector.onerror = ((web.Event _) {
    if (!listo.isCompleted) {
      listo.completeError(Exception('No pude leer el audio grabado'));
    }
  }).toJS;
  lector.readAsArrayBuffer(blob);
  return listo.future;
}
