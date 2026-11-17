import 'package:paw_match/services/audio_grabado.dart';

export 'package:paw_match/services/audio_grabado.dart';

Future<bool> pedirMicrofono() async => true;

Future<void> iniciarGrabacion() async {}

Future<AudioGrabado> detenerGrabacion() async {
  throw UnsupportedError('La grabación del navegador no se usa en la aplicación.');
}

Future<void> cancelarGrabacion({bool conservarMicrofono = false}) async {
  if (conservarMicrofono) return;
}
