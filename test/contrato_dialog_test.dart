import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/screens/adoption/adoption_detail_admin_screen.dart';

void main() {
  testWidgets('el diálogo de contrato se ajusta al contenido y queda centrado', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final solicitud = AdoptionRequest.fromJson({
      'id_solicitud_adopcion': '1',
      'estado': 'aprobada',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                child: AdoptionDetailAdminScreen(
                  request: solicitud,
                  soloContrato: true,
                  onCambioEstado: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Contrato de adopción'), findsOneWidget);
    expect(find.textContaining('Pendiente subir contrato de adopción'), findsOneWidget);
    expect(find.text('Subir contrato (JPG, PNG o PDF)'), findsOneWidget);

    final tarjeta = tester.getRect(find.byType(AdoptionDetailAdminScreen));
    final pantalla = tester.getRect(find.byType(Scaffold));

    expect(tarjeta.height, lessThan(pantalla.height * 0.45));
    expect(tarjeta.top, greaterThan(pantalla.height * 0.2));
    expect(pantalla.bottom - tarjeta.bottom, greaterThan(pantalla.height * 0.2));
    expect(
      (tarjeta.top - (pantalla.bottom - tarjeta.bottom)).abs(),
      lessThan(8),
    );
  });
}
