import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/core/imagenes_fundacion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('incluye y carga todas las imágenes de la Fundación', () async {
    final rutas = await imagenesDeLaFundacion();

    expect(
      rutas,
      containsAll([
        'assets/fundacion/Maritzanimada.jpg',
        'assets/fundacion/bebe.jpg',
        'assets/fundacion/blanca.jpg',
        'assets/fundacion/gris.jpg',
        'assets/fundacion/maitza.jpeg',
      ]),
    );
    expect(
      rutas,
      containsAll([
        FundacionInfo.fotoRescatista,
        FundacionInfo.fotoFondoAyudas,
      ]),
    );

    for (final ruta in rutas) {
      final imagen = await rootBundle.load(ruta);
      expect(imagen.lengthInBytes, greaterThan(0), reason: ruta);

      final codec = await ui.instantiateImageCodec(imagen.buffer.asUint8List());
      try {
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0), reason: ruta);
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    }
  });

  test('usa los datos de contacto oficiales de la Fundación', () {
    expect(FundacionInfo.whatsappNumero, '573136177747');
    expect(
      Uri.parse(FundacionInfo.whatsappUrl).queryParameters['text'],
      'Hola, vengo de la app Paw Match y quiero más información sobre la fundación',
    );
    expect(
      FundacionInfo.facebookUrl,
      'https://www.facebook.com/maritzaarevalogatos',
    );
    expect(
      FundacionInfo.instagramUrl,
      'https://www.instagram.com/fundacion_maritza_arevalo/',
    );
  });
}
