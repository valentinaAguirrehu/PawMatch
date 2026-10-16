// Test básico de que la app arranca y muestra la pantalla de bienvenida.

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:paw_match/main.dart';

void main() {
  testWidgets('La app arranca en la pantalla de bienvenida', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PawMatchApp());

    // Verifica que se muestre el título de la pantalla de bienvenida.
    expect(find.text('Paw Match'), findsOneWidget);

    // Verifica que estén los dos botones principales.
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Registrarse'), findsOneWidget);

    expect(find.text('Nuestra rescatista'), findsOneWidget);
    expect(find.text('Maritza Arévalo'), findsOneWidget);
    expect(find.text('Conoce a nuestros perritos'), findsOneWidget);
    expect(find.text('Juntos podemos hacer'), findsOneWidget);
    expect(find.text('Haz una donación'), findsOneWidget);
    expect(find.text('Adopta un amigo'), findsOneWidget);

    // Los enlaces sociales aparecen una sola vez y la galería no se muestra.
    expect(find.text('galería', skipOffstage: false), findsNothing);
    expect(find.text('Facebook', skipOffstage: false), findsOneWidget);
    expect(find.text('Instagram', skipOffstage: false), findsOneWidget);
    expect(find.text('WhatsApp', skipOffstage: false), findsOneWidget);
  });

  testWidgets('la bienvenida se adapta a una pantalla de celular', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PawMatchApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Nuestra rescatista'), findsOneWidget);
    expect(find.text('Conoce a nuestros perritos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
