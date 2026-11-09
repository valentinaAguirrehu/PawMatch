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

  test('la personalidad queda pendiente al cumplir 8 meses sin evaluación', () {
    final hoy = DateTime.now();
    final ochoMeses = DateTime(hoy.year, hoy.month - 8, 1);
    final sieteMeses = DateTime(hoy.year, hoy.month - 7, 1);

    final pendiente = Pet(
      id: 'pendiente',
      nombre: 'Pendiente',
      especie: 'Perro',
      fechaNacimiento: ochoMeses,
      personalidadDefinida: false,
    );
    final cachorro = Pet(
      id: 'cachorro',
      nombre: 'Cachorro',
      especie: 'Perro',
      fechaNacimiento: sieteMeses,
      personalidadDefinida: false,
    );
    final evaluada = Pet(
      id: 'evaluada',
      nombre: 'Evaluada',
      especie: 'Perro',
      fechaNacimiento: ochoMeses,
    );

    expect(pendiente.pendienteLlenarPersonalidad, isTrue);
    expect(cachorro.pendienteLlenarPersonalidad, isFalse);
    expect(evaluada.pendienteLlenarPersonalidad, isFalse);
  });

  test('al editar sin fecha guardada se calcula una a partir de la edad', () {
    final conocida = DateTime(2024, 1, 15);
    final conFecha = Pet(
      id: 'con-fecha',
      nombre: 'Con fecha',
      especie: 'Perro',
      edad: 2,
      unidadEdad: 'anos',
      fechaNacimiento: conocida,
    );
    final soloMeses = Pet(
      id: 'solo-meses',
      nombre: 'Solo meses',
      especie: 'Perro',
      edad: 4,
      unidadEdad: 'meses',
    );

    final hoy = DateTime.now();
    final esperada = DateTime(hoy.year, hoy.month - 4, hoy.day);

    expect(conFecha.fechaNacimientoParaEditar, DateTime(2024, 1, 15));
    expect(conFecha.fechaNacimientoEsEstimada, isFalse);
    expect(soloMeses.fechaNacimiento, isNull);
    expect(soloMeses.fechaNacimientoEsEstimada, isTrue);
    expect(
      soloMeses.fechaNacimientoParaEditar,
      DateTime(esperada.year, esperada.month, esperada.day),
    );
  });
}
