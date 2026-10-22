import 'package:flutter_test/flutter_test.dart';
import 'package:paw_match/services/acuerdo_adopcion_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DatosActaAdopcion datos({bool acepto = true, String motivacion = 'Quiero darle un hogar.'}) {
    return DatosActaAdopcion(
      idSolicitud: '42',
      nombreUsuario: 'Ana Pérez',
      documentoUsuario: '1085123456',
      correoUsuario: 'ana@correo.com',
      telefonoUsuario: '3001234567',
      tipoVivienda: 'Casa',
      tienePatio: true,
      tieneNinos: false,
      tieneOtrasMascotas: true,
      otrasMascotas: 'Un gato adulto',
      tiempoDisponible: 'Estoy en casa todo el día',
      experienciaPrevia: false,
      motivacion: motivacion,
      nombreMascota: 'Luna',
      especieMascota: 'Perro',
      razaMascota: 'Mestiza',
      edadMascota: '2 años',
      sexoMascota: 'Hembra',
      fechaAceptacion: DateTime(2026, 10, 22, 13, 40),
      aceptoTerminos: acepto,
    );
  }

  test('genera el acta de adopción con la aceptación expresa', () async {
    final bytes = await AcuerdoAdopcionPdfService.generarPdfBytes(datos());

    expect(bytes.length, greaterThan(800));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('el acta admite una motivación extensa sin fallar el armado', () async {
    final bytes = await AcuerdoAdopcionPdfService.generarPdfBytes(
      datos(motivacion: 'Quiero acompañar su recuperación. ' * 80),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('no genera el acta si los términos no fueron aceptados', () {
    expect(
      AcuerdoAdopcionPdfService.generarPdfBytes(datos(acepto: false)),
      throwsA(isA<StateError>()),
    );
  });
}
