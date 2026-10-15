import 'package:flutter_test/flutter_test.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/services/match_service.dart';

void main() {
  Map<String, int> todos(int valor) => {
    for (final rasgo in rasgosMascota) rasgo.clave: valor,
  };

  test('100 cuando todas las respuestas coinciden', () {
    final calculo = MatchService.calcular(todos(5), todos(5));
    expect(calculo, isNotNull);
    expect(calculo!.$1, 100);
  });

  test('0 cuando cada rasgo está en el extremo opuesto', () {
    final calculo = MatchService.calcular(todos(1), todos(5));
    expect(calculo!.$1, 0);
  });

  test('50 cuando cada respuesta queda a la mitad de la escala', () {
    final calculo = MatchService.calcular(todos(3), todos(5));
    expect(calculo!.$1, 50);
  });

  test('ignora una mascota sin personalidad', () {
    expect(MatchService.calcular(todos(3), const {}), isNull);
  });
}
