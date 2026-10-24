import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/services/session.dart';

class DatosAcuerdoApadrinamiento {
  final String idSolicitud;
  final String nombreUsuario;
  final String? documentoUsuario;
  final String correoUsuario;
  final String? telefonoUsuario;
  final String nombreMascota;
  final String especieMascota;
  final String? razaMascota;
  final String edadMascota;
  final String tipoAporte;
  final String? detalleAporte;
  final int? montoAporte;
  final String frecuenciaAporte;
  final String motivacion;
  final DateTime fechaAceptacion;

  DatosAcuerdoApadrinamiento({
    required this.idSolicitud,
    required this.nombreUsuario,
    this.documentoUsuario,
    required this.correoUsuario,
    this.telefonoUsuario,
    required this.nombreMascota,
    required this.especieMascota,
    this.razaMascota,
    required this.edadMascota,
    this.tipoAporte = 'Aporte monetario.',
    this.detalleAporte,
    this.montoAporte,
    required this.frecuenciaAporte,
    required this.motivacion,
    required this.fechaAceptacion,
  });
}

class AcuerdoApadrinamientoPdfService {
  AcuerdoApadrinamientoPdfService._();

  static const String textoAcuerdoCompleto = '''
Al formalizar tu solicitud de apadrinamiento, aceptas de manera libre y voluntaria los siguientes compromisos:

1. Compromiso de Apoyo y Bienestar:
Brindar el aporte voluntario periódico acordado para contribuir a la alimentación, atención veterinaria, medicamentos y bienestar integral de la mascota apadrinada.

2. Veracidad de la Información:
Garantizar que todos los datos suministrados y la fotografía del documento de identidad adjunto corresponden a tu identidad y son verídicos.

3. Comunicación Responsable:
Mantener contacto respetuoso a través de los canales oficiales de la Fundación (WhatsApp y visitas presenciales programadas) para el seguimiento del estado de la mascota.

4. Tutela y Decisiones Médicas:
Reconocer que la Fundación Maritza Arévalo mantiene la tutela y custodia legal del animal, reservándose las decisiones médicas y de eventual adopción permanente en beneficio de su bienestar.

5. Confidencialidad y Protección de Datos:
La Fundación tratará tu información personal y los documentos suministrados bajo estricta confidencialidad conforme a la normativa vigente.
''';

  static const List<Map<String, String>> clausulasAcuerdo = [
    {
      'num': '1',
      'titulo': 'Compromiso de Apoyo y Bienestar',
      'cuerpo':
          'Brindar el aporte voluntario periódico acordado para contribuir a la alimentación, atención veterinaria, medicamentos y bienestar integral de la mascota apadrinada.',
    },
    {
      'num': '2',
      'titulo': 'Veracidad de la Información',
      'cuerpo':
          'Garantizar que todos los datos suministrados y la fotografía del documento de identidad adjunto corresponden a tu identidad y son verídicos.',
    },
    {
      'num': '3',
      'titulo': 'Comunicación Responsable',
      'cuerpo':
          'Mantener contacto respetuoso a través de los canales oficiales de la Fundación (WhatsApp y visitas presenciales programadas) para el seguimiento del estado de la mascota.',
    },
    {
      'num': '4',
      'titulo': 'Tutela y Decisiones Médicas',
      'cuerpo':
          'Reconocer que la Fundación Maritza Arévalo mantiene la tutela y custodia legal del animal, reservándose las decisiones médicas y de eventual adopción permanente en beneficio de su bienestar.',
    },
    {
      'num': '5',
      'titulo': 'Confidencialidad y Protección de Datos',
      'cuerpo':
          'La Fundación tratará tu información personal y los documentos suministrados bajo estricta confidencialidad conforme a la normativa legal vigente de protección de datos.',
    },
  ];

  /// Genera los bytes del documento PDF con diseño limpio, logo oficial de Paw Match y sin caracteres raros.
  static Future<Uint8List> generarPdfBytes(DatosAcuerdoApadrinamiento datos) async {
    final pdf = pw.Document();

    // Intentar cargar la foto del logo de Paw Match
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

    final dia = datos.fechaAceptacion.day.toString().padLeft(2, '0');
    final mes = datos.fechaAceptacion.month.toString().padLeft(2, '0');
    final anio = datos.fechaAceptacion.year.toString();
    final hora = datos.fechaAceptacion.hour.toString().padLeft(2, '0');
    final minuto = datos.fechaAceptacion.minute.toString().padLeft(2, '0');
    final fechaFormateada = '$dia/$mes/$anio a las $hora:$minuto';

    final frecuenciaTexto = switch (datos.frecuenciaAporte) {
      'semanal' => 'Semanal',
      'quincenal' => 'Quincenal',
      'mensual' => 'Mensual',
      'aporte_unico' => 'Aporte único',
      'entrega_unica' => 'Entrega única',
      'unica_vez' => 'Única vez',
      _ => datos.frecuenciaAporte,
    };

    final esMonetario = datos.tipoAporte.toLowerCase().contains('monetario');
    final esEspecie = datos.tipoAporte.toLowerCase().contains('especie');

    final String modalidadTexto;
    if (esMonetario) {
      final monto = datos.montoAporte != null && datos.montoAporte! > 0
          ? '\$ ${datos.montoAporte.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} COP'
          : '\$ 0 COP';
      modalidadTexto = 'Aporte monetario: $monto ($frecuenciaTexto)';
    } else if (esEspecie) {
      final detalle = (datos.detalleAporte != null && datos.detalleAporte!.trim().isNotEmpty)
          ? ': ${datos.detalleAporte!.trim()}'
          : '';
      modalidadTexto = 'Aporte en especie$detalle ($frecuenciaTexto)';
    } else {
      final detalle = (datos.detalleAporte != null && datos.detalleAporte!.trim().isNotEmpty)
          ? ': ${datos.detalleAporte!.trim()}'
          : '';
      modalidadTexto = 'Otro tipo de ayuda$detalle';
    }

    final razaTexto = (datos.razaMascota != null && datos.razaMascota!.trim().isNotEmpty)
        ? datos.razaMascota!
        : 'Mestiza';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ───────── ENCABEZADO SUPERIOR CON LOGO Y FUNDACIÓN ─────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Contenedor de la foto del logo de Paw Match
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
                                fontSize: 11,
                              ),
                            ),
                          ),
                  ),
                  pw.SizedBox(width: 14),
                  // Datos oficiales de la Fundación
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          FundacionInfo.nombre.toUpperCase(),
                          style: pw.TextStyle(
                            color: verdePrincipal,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          FundacionInfo.ciudad,
                          style: pw.TextStyle(
                            color: grisOscuro,
                            fontSize: 8.5,
                          ),
                        ),
                        pw.Text(
                          'WhatsApp: +57 ${FundacionInfo.whatsappNumero.replaceFirst(RegExp(r'^57'), '')}',
                          style: pw.TextStyle(
                            color: grisOscuro,
                            fontSize: 8.5,
                          ),
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          'Protección, Bienestar y Rescate Animal',
                          style: pw.TextStyle(
                            color: verdeSecundario,
                            fontSize: 8,
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

              // ───────── TÍTULO PRINCIPAL (ESTILO IMAGEN 3) ─────────
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PAW MATCH',
                      style: pw.TextStyle(
                        color: verdePrincipal,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'ACUERDO DE RESPONSABILIDAD Y COMPROMISO DE APADRINAMIENTO',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: grisOscuro,
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'DOCUMENTO DE ACEPTACIÓN ELECTRÓNICA',
                      style: pw.TextStyle(
                        color: grisMedio,
                        fontSize: 7.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),
              pw.Container(height: 0.8, color: grisBorde),
              pw.SizedBox(height: 10),

              // ───────── SECCIÓN 1: INFORMACIÓN DEL APADRINAMIENTO ─────────
              pw.Text(
                '1. Información del apadrinamiento',
                style: pw.TextStyle(
                  color: grisOscuro,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Nombre del padrino, datos de contacto, mascota apadrinada, aporte mensual y fecha de aceptación, organizados en una ficha de lectura rápida:',
                style: pw.TextStyle(color: grisMedio, fontSize: 8),
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
                  children: [
                    _filaDato('Nombre de la Fundación:', FundacionInfo.nombre),
                    _filaDato('Nombre del Padrino/Usuario:', datos.nombreUsuario),
                    if (datos.documentoUsuario != null && datos.documentoUsuario!.trim().isNotEmpty)
                      _filaDato('Número de Identificación:', datos.documentoUsuario!.trim())
                    else if (Session.documentoIdentidad.trim().isNotEmpty)
                      _filaDato('Número de Identificación:', Session.documentoIdentidad.trim()),
                    _filaDato('Correo del Usuario:', datos.correoUsuario),
                    if (datos.telefonoUsuario != null && datos.telefonoUsuario!.trim().isNotEmpty)
                      _filaDato('Teléfono de Contacto:', datos.telefonoUsuario!),
                    _filaDato(
                      'Mascota Apadrinada:',
                      '${datos.nombreMascota} (${datos.especieMascota} - $razaTexto - ${datos.edadMascota})',
                    ),
                    _filaDato('Modalidad y Aporte:', modalidadTexto),
                    _filaDato('Fecha de Aceptación:', fechaFormateada),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // ───────── SECCIÓN 2: TÉRMINOS Y CONDICIONES ─────────
              pw.Text(
                '2. Términos y condiciones',
                style: pw.TextStyle(
                  color: grisOscuro,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Los cinco compromisos numerados, con subtítulos destacados y párrafos bien espaciados:',
                style: pw.TextStyle(color: grisMedio, fontSize: 8),
              ),
              pw.SizedBox(height: 6),

              ...clausulasAcuerdo.map(
                (c) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 14,
                        child: pw.Text(
                          '${c['num']}.',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: verdePrincipal,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            style: pw.TextStyle(fontSize: 8, color: grisOscuro),
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
                  ),
                ),
              ),

              pw.SizedBox(height: 8),

              // ───────── SECCIÓN 3: CONSTANCIA DE ACEPTACIÓN ELECTRÓNICA ─────────
              pw.Text(
                '3. Constancia de aceptación electrónica',
                style: pw.TextStyle(
                  color: grisOscuro,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Radicado, fecha y hora del registro, estado de la solicitud y una nota de validación del sistema:',
                style: pw.TextStyle(color: grisMedio, fontSize: 8),
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
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'El solicitante ha marcado la casilla obligatoria de aceptación del Acuerdo de Responsabilidad y Compromiso y ha enviado formalmente su solicitud a través de la plataforma Paw Match. La aceptación ha sido registrada de forma segura en la base de datos de la Fundación.',
                      style: pw.TextStyle(fontSize: 7.5, color: grisOscuro),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Radicado / Ref: ${datos.idSolicitud}',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: grisOscuro),
                        ),
                        pw.Text(
                          'Fecha: $fechaFormateada',
                          style: pw.TextStyle(fontSize: 7.5, color: grisOscuro),
                        ),
                        pw.Text(
                          'Estado: ACEPTADO Y REGISTRADO',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: verdeSecundario,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // ───────── PIE DE PÁGINA ─────────
              pw.Container(height: 0.6, color: grisBorde),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Documento electrónico emitido por Paw Match para la Fundación Maritza Arévalo.',
                    style: pw.TextStyle(fontSize: 6.8, color: grisMedio),
                  ),
                  pw.Text(
                    'Página 1 de 1',
                    style: pw.TextStyle(fontSize: 6.8, color: grisMedio),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _filaDato(String etiqueta, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              etiqueta,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#374151'),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              valor,
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromHex('#111827'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Descarga y/o abre el archivo PDF en el dispositivo o navegador.
  static Future<String?> descargarYGuardarPdf({
    required Uint8List bytes,
    required String nombreMascota,
  }) async {
    final sanitizedPet = nombreMascota.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filename = 'Acuerdo_Apadrinamiento_$sanitizedPet.pdf';

    try {
      // En Web o como primer método de descarga universal: Printing.sharePdf
      // maneja descargas en web directamente con el diálogo nativo del navegador.
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
        return filename;
      }

      // En Windows / Escritorio:
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

      // Además, activamos la vista / compartir / guardar del sistema mediante Printing
      await Printing.sharePdf(bytes: bytes, filename: filename);

      return rutaGuardada ?? filename;
    } catch (e) {
      debugPrint('Error al guardar o compartir PDF: $e');
      try {
        await Printing.sharePdf(bytes: bytes, filename: filename);
        return filename;
      } catch (_) {
        return null;
      }
    }
  }
}
