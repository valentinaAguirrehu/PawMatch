import 'package:flutter_test/flutter_test.dart';
import 'package:paw_match/models/pet.dart';

Pet _pet({
  required String id,
  String estadoAdopcion = 'disponible',
  String estadoApadrinamiento = 'disponible',
}) {
  return Pet(
    id: id,
    nombre: id,
    especie: 'Perro',
    estadoAdopcion: estadoAdopcion,
    estadoApadrinamiento: estadoApadrinamiento,
  );
}

void main() {
  test('ordena disponibles, luego apadrinadas y al final adoptadas', () {
    final lista = [
      _pet(id: 'adoptada', estadoAdopcion: 'adoptado'),
      _pet(id: 'disponible-2'),
      _pet(id: 'apadrinada', estadoApadrinamiento: 'apadrinado'),
      _pet(id: 'disponible-1'),
      _pet(
        id: 'adoptada-y-apadrinada',
        estadoAdopcion: 'adoptado',
        estadoApadrinamiento: 'apadrinado',
      ),
      _pet(id: 'en-proceso', estadoAdopcion: 'en_proceso'),
    ];

    final orden = ordenarMascotasPorEstado(lista).map((p) => p.id).toList();

    expect(orden, [
      'disponible-2',
      'disponible-1',
      'en-proceso',
      'apadrinada',
      'adoptada',
      'adoptada-y-apadrinada',
    ]);
  });

  test('cada filtro deja solo su grupo', () {
    final pets = [
      _pet(id: 'd'),
      _pet(id: 'a', estadoApadrinamiento: 'apadrinado'),
      _pet(id: 'ad', estadoAdopcion: 'adoptado'),
    ];

    List<String> ids(int grupo) => pets
        .where((p) => p.ordenEstadoListado == grupo)
        .map((p) => p.id)
        .toList();

    expect(ids(0), ['d']);
    expect(ids(1), ['a']);
    expect(ids(2), ['ad']);
  });
}
