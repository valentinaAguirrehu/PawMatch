import 'package:flutter_test/flutter_test.dart';
import 'package:paw_match/models/pet.dart';

void main() {
  final hoy = DateTime(2026, 11, 4);

  test('cuenta días cuando aún no cumple un mes', () {
    expect(Pet.textoEdad(DateTime(2026, 10, 20), hoy), '15 días');
  });

  test('siete meses todavía es menor de ocho', () {
    final nacimiento = DateTime(2026, 3, 5);
    expect(Pet.textoEdad(nacimiento, hoy), '7 meses');
    expect(Pet.mesesEntre(nacimiento, hoy) < 8, isTrue);
  });

  test('al cumplir ocho meses ya no entra en desarrollo', () {
    final nacimiento = DateTime(2026, 3, 4);
    expect(Pet.textoEdad(nacimiento, hoy), '8 meses');
    expect(Pet.mesesEntre(nacimiento, hoy) < 8, isFalse);
  });

  test('suma años y meses que faltan', () {
    expect(Pet.textoEdad(DateTime(2024, 8, 4), hoy), '2 años y 3 meses');
    expect(Pet.textoEdad(DateTime(2024, 11, 4), hoy), '2 años');
  });
}
