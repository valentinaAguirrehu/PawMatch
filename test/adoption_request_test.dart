import 'package:flutter_test/flutter_test.dart';
import 'package:paw_match/models/adoption_request.dart';

void main() {
  test('arma las respuestas y la etiqueta de estado', () {
    final solicitud = AdoptionRequest.fromJson({
      'id_solicitud_adopcion': 'abc',
      'id_usuario': 'user',
      'id_mascota': 'pet',
      'tipo_vivienda': 'Casa',
      'tiene_patio': true,
      'tiene_ninos': false,
      'tiene_mascotas': true,
      'otras_mascotas': 'Un gato',
      'tiempo_disponible': 'De 2 a 4 horas al día',
      'experiencia_previa': true,
      'informacion_adicional': 'Quiero darle un hogar.',
      'tiene_foto_cedula': true,
      'tiene_foto_recibo': false,
      'fecha_solicitud': '2026-10-19 17:05:00',
      'estado': 'pendiente',
      'solicitante_nombres': 'Ana',
      'solicitante_apellidos': 'Pérez',
      'mascota_nombre': 'Luna',
      'mascota_especie': 'Perro',
      'mascota_edad': 2,
    });

    expect(solicitud.isPending, isTrue);
    expect(solicitud.statusLabel, 'Pendiente');
    expect(solicitud.applicantFullName, 'Ana Pérez');
    expect(solicitud.requestedAtLabel, '19/10/2026 17:05');
    expect(solicitud.petAgeLabel, '2 años');
    expect(solicitud.hasIdPhoto, isTrue);
    expect(solicitud.hasUtilityBill, isFalse);
    expect(
      solicitud.answers.map((a) => a.question),
      contains('Otras mascotas'),
    );
    expect(
      solicitud.answers.firstWhere((a) => a.question == '¿Tiene patio o zona verde?').answer,
      'Sí',
    );
  });

  test('traduce los estados revisados', () {
    expect(
      AdoptionRequest.fromJson({'estado': 'aprobada'}).statusLabel,
      'Aprobada',
    );
    expect(
      AdoptionRequest.fromJson({'estado': 'rechazada'}).isRejected,
      isTrue,
    );
  });
}
