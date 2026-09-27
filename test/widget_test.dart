// Test básico de que la app arranca y muestra la pantalla de bienvenida.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:paw_match/main.dart';

void main() {
  testWidgets('La app arranca en la pantalla de bienvenida', (WidgetTester tester) async {
    await tester.pumpWidget(const PawMatchApp());

    // Verifica que se muestre el título de la pantalla de bienvenida.
    expect(find.text('Paw Match'), findsOneWidget);

    // Verifica que estén los dos botones principales.
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Registrarse'), findsOneWidget);
  });
}