import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/services/preparar_foto_pdf.dart';
import 'package:paw_match/services/session.dart';

/// Datos que quedan consignados en el acta de compromiso de adopción.
class DatosActaAdopcion {
  final String idSolicitud;
  final String nombreUsuario;
  final String? documentoUsuario;
  final String correoUsuario;
  final String? telefonoUsuario;
  final String? direccionUsuario;
  final String tipoVivienda;
  final bool tienePatio;
  final bool tieneNinos;
  final bool tieneOtrasMascotas;
  final String otrasMascotas;
  final String tiempoDisponible;
  final bool experienciaPrevia;
  final String motivacion;
  final String nombreMascota;
  final String especieMascota;
  final String? razaMascota;
  final String edadMascota;
  final String? sexoMascota;
  final DateTime fechaAceptacion;
  final bool aceptoTerminos;
  final Uint8List? fotoCedula;
  final Uint8List? fotoRecibo;
  final Uint8List? fotoMascota;
  final String estadoCorreo;
  final String estadoProceso;

  DatosActaAdopcion({
    required this.idSolicitud,
    required this.nombreUsuario,
    this.documentoUsuario,
    required this.correoUsuario,
    this.telefonoUsuario,
    this.direccionUsuario,
    required this.tipoVivienda,
    required this.tienePatio,
    required this.tieneNinos,
    required this.tieneOtrasMascotas,
    this.otrasMascotas = '',
    required this.tiempoDisponible,
    required this.experienciaPrevia,
    required this.motivacion,
    required this.nombreMascota,
    required this.especieMascota,
    this.razaMascota,
    required this.edadMascota,
    this.sexoMascota,
    required this.fechaAceptacion,
    required this.aceptoTerminos,
    this.fotoCedula,
    this.fotoRecibo,
    this.fotoMascota,
    this.estadoCorreo = 'pendiente',
    this.estadoProceso = 'pendiente',
  });
}

class AcuerdoAdopcionPdfService {
  AcuerdoAdopcionPdfService._();

  /// Requisitos que el adoptante lee y acepta antes del formulario.
  /// El mismo listado se muestra en la pantalla de pasos y en el acta PDF.
  static const List<String> requisitosImportantes = [
    'Asumir el compromiso de cuidarlo durante toda su vida.',
    'Ofrecer un entorno familiar estable, protegido y lleno de amor.',
    'Ser mayor de 18 años.',
    'Contar con la solvencia para cubrir su alimentación, controles y gastos médicos.',
    'Realizar la esterilización obligatoria si aún no está esterilizado.',
    'Mantener su esquema de vacunación y desparasitación al día.',
    'Mantener contacto constante con la fundación para el seguimiento (fotos vía WhatsApp y visitas domiciliarias).',
  ];

  /// Cláusulas formales de la Fundación Maritza Arévalo.
  /// La clave `alerta` marca la cláusula de rescisión para destacarla en la UI y en el PDF.
  static const List<Map<String, String>> clausulasAdopcion = [
    {
      'num': '1',
      'titulo': 'Requisitos de la adopción responsable',
      'cuerpo':
          'La adopción es un compromiso permanente de tenencia responsable. '
          'El adoptante asume la alimentación, la atención veterinaria, las vacunas, '
          'un espacio seguro y el cuidado diario del perro. Declara que su hogar '
          'ofrece condiciones adecuadas de convivencia y que no entregará al animal '
          'a terceros sin autorización previa de la Fundación Maritza Arévalo.',
    },
    {
      'num': '2',
      'titulo': 'Visitas domiciliarias de verificación',
      'cuerpo':
          'El adoptante autoriza y se compromete a recibir visitas domiciliarias '
          'frecuentes de la Fundación Maritza Arévalo, destinadas a verificar las '
          'condiciones de vida, la salud y el bienestar del perro. Impedir estas '
          'visitas sin justa causa se entiende como incumplimiento de este compromiso.',
    },
    {
      'num': '3',
      'titulo': 'Fotografías y actualizaciones por WhatsApp',
      'cuerpo':
          'El adoptante se compromete a enviar de forma periódica fotografías y '
          'actualizaciones sobre el estado de la mascota por el WhatsApp oficial de '
          'la Fundación, cuando esta lo solicite o según el seguimiento acordado, '
          'para constatar su adaptación y bienestar.',
    },
    {
      'num': '4',
      'titulo': 'Rescisión, retiro de la mascota y sanción',
      'alerta': 'si',
      'cuerpo':
          'Si no se cumple con una adopción responsable o la Fundación detecta '
          'irregularidades en el cuidado, la tenencia o las condiciones de vida del '
          'perro, realizará el proceso de retiro de la mascota (recuperación). '
          'En ese evento aplicará una sanción e inhabilitará de forma permanente '
          'a la familia para futuras adopciones en la Fundación Maritza Arévalo.',
    },
    {
      'num': '5',
      'titulo': 'Veracidad de la información y confidencialidad',
      'cuerpo':
          'El adoptante garantiza que los datos personales y el documento de identidad '
          'adjunto corresponden a su identidad. La Fundación tratará '
          'esta información con confidencialidad, conforme a la normativa vigente.',
    },
  ];

  /// Genera el acta de compromiso con la misma identidad visual del acuerdo de apadrinamiento.
  static Future<Uint8List> generarPdfBytes(DatosActaAdopcion datos) async {
    if (!datos.aceptoTerminos) {
      throw StateError(
        'No se puede generar el acta sin la aceptación expresa de los términos.',
      );
    }

    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('No se pudo cargar logo de Paw Match: $e');
    }

    final verdePrincipal = PdfColor.fromHex('#23533E');
    final verdeSecundario = PdfColor.fromHex('#2E7D32');
    final verdeClaroBorde = PdfColor.fromHex('#80A892');
    final grisBorde = PdfColor.fromHex('#D1D5DB');
    final grisOscuro = PdfColor.fromHex('#1F2937');
    final grisMedio = PdfColor.fromHex('#4B5563');
    final rojoAlerta = PdfColor.fromHex('#991B1B');
    final fondoAlerta = PdfColor.fromHex('#FEF2F2');

    final dia = datos.fechaAceptacion.day.toString().padLeft(2, '0');
    final mes = datos.fechaAceptacion.month.toString().padLeft(2, '0');
    final anio = datos.fechaAceptacion.year.toString();
    final hora = datos.fechaAceptacion.hour.toString().padLeft(2, '0');
    final minuto = datos.fechaAceptacion.minute.toString().padLeft(2, '0');
    final fechaFormateada = '$dia/$mes/$anio a las $hora:$minuto';

    final razaTexto = (datos.razaMascota != null && datos.razaMascota!.trim().isNotEmpty)
        ? datos.razaMascota!.trim()
        : 'Mestiza';
    final sexoTexto = (datos.sexoMascota != null && datos.sexoMascota!.trim().isNotEmpty)
        ? datos.sexoMascota!.trim()
        : 'No registrado';

    final documento = (datos.documentoUsuario != null &&
            datos.documentoUsuario!.trim().isNotEmpty)
        ? datos.documentoUsuario!.trim()
        : (Session.documentoIdentidad.trim().isNotEmpty
            ? Session.documentoIdentidad.trim()
            : 'No registrado');

    final direccionTexto = (datos.direccionUsuario != null &&
            datos.direccionUsuario!.trim().isNotEmpty)
        ? datos.direccionUsuario!.trim()
        : 'No registrada';

    // Preparar imagen de la mascota
    final jpgMascota = await prepararFotoParaPdf(datos.fotoMascota);
    final fotoMascota = jpgMascota == null ? null : pw.MemoryImage(jpgMascota);

    // Preparar documento de identidad (imagen o primera página si es PDF)
    Uint8List? jpgCedula;
    if (datos.fotoCedula != null && datos.fotoCedula!.isNotEmpty) {
      final bytesCedula = datos.fotoCedula!;
      final esPdf = bytesCedula.length >= 4 &&
          bytesCedula[0] == 0x25 &&
          bytesCedula[1] == 0x50 &&
          bytesCedula[2] == 0x44 &&
          bytesCedula[3] == 0x46;
      if (esPdf) {
        try {
          await for (final page
              in Printing.raster(bytesCedula, pages: [0], dpi: 120)) {
            jpgCedula = await page.toPng();
            break;
          }
        } catch (e) {
          debugPrint('Error al rasterizar cédula PDF para acuerdo de adopción: $e');
        }
      } else {
        jpgCedula = await prepararFotoParaPdf(bytesCedula);
      }
    }
    final fotoCedula = jpgCedula == null ? null : pw.MemoryImage(jpgCedula);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 40),
        footer: (context) => pw.Column(
          children: [
            pw.SizedBox(height: 6),
            pw.Container(height: 0.6, color: grisBorde),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Documento electrónico emitido por Paw Match para la Fundación Maritza Arévalo.',
                    style: pw.TextStyle(fontSize: 8.5, color: grisMedio),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8.5, color: grisMedio),
                ),
              ],
            ),
          ],
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 54,
                height: 54,
                padding: const pw.EdgeInsets.all(3),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  border: pw.Border.all(color: verdeClaroBorde, width: 1.2),
                ),
                child: logoImage != null
                    ? pw.ClipRRect(
                        horizontalRadius: 8,
                        verticalRadius: 8,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      )
                    : pw.Center(
                        child: pw.Text(
                          'PAW',
                          style: pw.TextStyle(
                            color: verdePrincipal,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      FundacionInfo.nombre.toUpperCase(),
                      style: pw.TextStyle(
                        color: verdePrincipal,
                        fontSize: 15.5,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      FundacionInfo.ciudad,
                      style: pw.TextStyle(color: grisOscuro, fontSize: 10.5),
                    ),
                    pw.Text(
                      'WhatsApp: +57 ${FundacionInfo.whatsappNumero.replaceFirst(RegExp(r'^57'), '')}',
                      style: pw.TextStyle(color: grisOscuro, fontSize: 10.5),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'Protección, Bienestar y Rescate Animal',
                      style: pw.TextStyle(
                        color: verdeSecundario,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(height: 1.2, color: verdeClaroBorde),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'PAW MATCH',
                  style: pw.TextStyle(
                    color: verdePrincipal,
                    fontSize: 16.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'ACTA DE COMPROMISO Y TÉRMINOS DE ADOPCIÓN RESPONSABLE',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: grisOscuro,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  'DOCUMENTO DE ACEPTACIÓN ELECTRÓNICA',
                  style: pw.TextStyle(
                    color: grisMedio,
                    fontSize: 9.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 0.8, color: grisBorde),
          pw.SizedBox(height: 10),
          pw.Text(
            '1. Información de la adopción',
            style: pw.TextStyle(
              color: grisOscuro,
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Datos del adoptante, condiciones del hogar, mascota adoptada y fecha de aceptación expresa de los términos:',
            style: pw.TextStyle(color: grisMedio, fontSize: 10),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F9FAFB'),
              border: pw.Border.all(color: grisBorde, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (fotoMascota != null) ...[
                      pw.Container(
                        width: 52,
                        height: 52,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: verdeClaroBorde, width: 1.5),
                        ),
                        child: pw.ClipOval(
                          child: pw.Image(fotoMascota, fit: pw.BoxFit.cover),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                    ],
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Mascota en adopción: ${datos.nombreMascota}',
                            style: pw.TextStyle(
                              fontSize: 11.5,
                              fontWeight: pw.FontWeight.bold,
                              color: verdePrincipal,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '${datos.especieMascota} · $razaTexto · $sexoTexto · ${datos.edadMascota}',
                            style: pw.TextStyle(fontSize: 9.5, color: grisOscuro),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Container(height: 0.5, color: grisBorde),
                pw.SizedBox(height: 6),

                _filaDato('Nombre de la Fundación:', FundacionInfo.nombre),
                _filaDato('Nombre del adoptante:', datos.nombreUsuario),
                _filaDato('Número de identificación:', documento),
                _filaDato('Correo del adoptante:', datos.correoUsuario),
                if (datos.telefonoUsuario != null &&
                    datos.telefonoUsuario!.trim().isNotEmpty)
                  _filaDato('Teléfono de contacto:', datos.telefonoUsuario!.trim()),
                _filaDato('Dirección:', direccionTexto),
                _filaDato('Fecha de solicitud:', fechaFormateada),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '2. Requisitos importantes',
            style: pw.TextStyle(
              color: grisOscuro,
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Condiciones de adopción responsable que el adoptante leyó y se comprometió a cumplir, en orden de importancia:',
            style: pw.TextStyle(color: grisMedio, fontSize: 10),
          ),
          pw.SizedBox(height: 6),
          ...requisitosImportantes.asMap().entries.map((entrada) {
            final numero = entrada.key + 1;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 20,
                    child: pw.Text(
                      '$numero.',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: verdePrincipal,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      entrada.value,
                      style: pw.TextStyle(fontSize: 10, color: grisOscuro),
                    ),
                  ),
                ],
              ),
            );
          }),
          pw.SizedBox(height: 4),
          pw.Text(
            'El adoptante declaró: «He leído los términos de adopción y me comprometo a cumplir con todas las condiciones indicadas.»',
            style: pw.TextStyle(
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
              color: grisOscuro,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '3. Términos y condiciones',
            style: pw.TextStyle(
              color: grisOscuro,
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Compromisos de adopción responsable de la Fundación Maritza Arévalo, aceptados por el solicitante:',
            style: pw.TextStyle(color: grisMedio, fontSize: 10),
          ),
          pw.SizedBox(height: 6),
          ...clausulasAdopcion.map((c) {
            final esAlerta = c['alerta'] == 'si';
            final contenido = pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 20,
                  child: pw.Text(
                    '${c['num']}.',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: esAlerta ? rojoAlerta : verdePrincipal,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.RichText(
                    text: pw.TextSpan(
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: esAlerta ? rojoAlerta : grisOscuro,
                      ),
                      children: [
                        pw.TextSpan(
                          text: '${c['titulo']}: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.TextSpan(text: c['cuerpo']!),
                      ],
                    ),
                  ),
                ),
              ],
            );

            if (!esAlerta) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: contenido,
              );
            }

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 6, top: 2),
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: fondoAlerta,
                border: pw.Border.all(color: rojoAlerta, width: 0.7),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: contenido,
            );
          }),
          pw.SizedBox(height: 8),
          pw.Text(
            '4. Constancia de aceptación electrónica',
            style: pw.TextStyle(
              color: grisOscuro,
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Radicado, fecha y hora del registro, y constancia de que los términos fueron aceptados de forma expresa:',
            style: pw.TextStyle(color: grisMedio, fontSize: 10),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F4F9F6'),
              border: pw.Border.all(color: verdeClaroBorde, width: 0.9),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CONSTANCIA DE ACEPTACIÓN ELECTRÓNICA REGISTRADA POR EL SISTEMA',
                  style: pw.TextStyle(
                    color: verdeSecundario,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'El adoptante marcó la casilla obligatoria de aceptación de los términos y condiciones de adopción responsable de la Fundación Maritza Arévalo y envió formalmente su solicitud a través de la plataforma Paw Match. La aceptación ha sido registrada de forma segura en la base de datos de la Fundación.',
                  style: pw.TextStyle(fontSize: 9.5, color: grisOscuro),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Radicado / Ref: ${datos.idSolicitud}',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: grisOscuro,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Fecha: $fechaFormateada',
                  style: pw.TextStyle(fontSize: 9.5, color: grisOscuro),
                ),
              ],
            ),
          ),

          // ───────── DOCUMENTO DE IDENTIDAD Y FOTOGRAFÍA (SEGUNDA HOJA) ─────────
          if (fotoCedula != null && fotoMascota != null) ...[
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    margin: const pw.EdgeInsets.only(right: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F9FAFB'),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: verdeClaroBorde, width: 1),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Documento de Identidad Adjunto',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: verdePrincipal,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.ClipRRect(
                          horizontalRadius: 6,
                          verticalRadius: 6,
                          child: pw.Image(
                            fotoCedula,
                            height: 125,
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    margin: const pw.EdgeInsets.only(left: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F9FAFB'),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: verdeClaroBorde, width: 1),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Fotografía de ${datos.nombreMascota}',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: verdePrincipal,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.ClipRRect(
                          horizontalRadius: 6,
                          verticalRadius: 6,
                          child: pw.Image(
                            fotoMascota,
                            height: 125,
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else if (fotoCedula != null) ...[
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Container(
                width: 260,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F9FAFB'),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: verdeClaroBorde, width: 1),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Documento de Identidad Adjunto',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: verdePrincipal,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.ClipRRect(
                      horizontalRadius: 6,
                      verticalRadius: 6,
                      child: pw.Image(
                        fotoCedula,
                        height: 130,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (fotoMascota != null) ...[
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Container(
                width: 260,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F9FAFB'),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: verdeClaroBorde, width: 1),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Fotografía de ${datos.nombreMascota}',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: verdePrincipal,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.ClipRRect(
                      horizontalRadius: 6,
                      verticalRadius: 6,
                      child: pw.Image(
                        fotoMascota,
                        height: 130,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _filaDato(String etiqueta, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 205,
            child: pw.Text(
              etiqueta,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#374151'),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              valor,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColor.fromHex('#111827'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Descarga y abre el acta en el dispositivo o en el navegador.
  static Future<String?> descargarYGuardarPdf({
    required Uint8List bytes,
    required String nombreMascota,
  }) async {
    final sanitizedPet = nombreMascota.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filename = 'Acta_Compromiso_Adopcion_$sanitizedPet.pdf';

    try {
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
        return filename;
      }

      String? rutaGuardada;
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          final downloadsDir = Directory('$userProfile\\Downloads');
          if (await downloadsDir.exists()) {
            final file = File('${downloadsDir.path}\\$filename');
            await file.writeAsBytes(bytes);
            rutaGuardada = file.path;
          }
        }
      }

      await Printing.sharePdf(bytes: bytes, filename: filename);
      return rutaGuardada ?? filename;
    } catch (e) {
      debugPrint('Error al guardar o compartir el acta de adopción: $e');
      try {
        await Printing.sharePdf(bytes: bytes, filename: filename);
        return filename;
      } catch (_) {
        return null;
      }
    }
  }
}
