import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/widgets/perrito_landing_card.dart';

void main() {
  testWidgets('muestra hasta tres rasgos destacados y el modo seleccionado', (
    tester,
  ) async {
    var tocado = false;
    final pet = Pet(
      id: '1',
      nombre: 'Luna',
      especie: 'perro',
      sexo: 'hembra',
      personalidad: const {
        'nivel_energia': 5,
        'sociabilidad_mascotas': 1,
        'carino': 5,
        'proteccion': 1,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 440,
            child: PerritoLandingCard(
              pet: pet,
              paraAdopcion: false,
              onTap: () => tocado = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Para apadrinar'), findsOneWidget);
    expect(find.text('Muy activa'), findsOneWidget);
    expect(find.text('Prefiere estar sola'), findsOneWidget);
    expect(find.text('Muy cariñosa'), findsOneWidget);
    expect(find.text('Nada protectora'), findsNothing);
    expect(find.text('Conocer más ›'), findsOneWidget);

    await tester.tap(find.text('Conocer más ›'));
    expect(tocado, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('usa sexo, tamaño y edad cuando no hay rasgos guardados', (
    tester,
  ) async {
    final pet = Pet(
      id: '2',
      nombre: 'Toby',
      especie: 'perro',
      sexo: 'macho',
      tamano: 'Mediano',
      edad: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 440,
            child: PerritoLandingCard(
              pet: pet,
              paraAdopcion: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Para adoptar'), findsOneWidget);
    expect(find.text('macho'), findsOneWidget);
    expect(find.text('Mediano'), findsOneWidget);
    expect(find.text('3 años'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
