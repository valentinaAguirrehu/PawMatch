import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/services/preparar_foto_pdf.dart';
import 'package:paw_match/services/session.dart';

typedef DatosActaApadrinamiento = DatosAcuerdoApadrinamiento;

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
  final String? sexoMascota;
  final String tipoAporte;
  final String? detalleAporte;
  final String? detalleEspecie;
  final int? montoAporte;
  final String frecuenciaAporte;
  final String motivacion;
  final DateTime fechaAceptacion;
  final Uint8List? fotoCedula;
  final Uint8List? fotoMascota;
  final String estadoProceso;
  final String estadoCorreo;
  final bool aceptoTerminos;

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
    this.sexoMascota,
    this.tipoAporte = 'Aporte monetario.',
    this.detalleAporte,
    this.detalleEspecie,
    int? montoAporte,
    int? valorMensual,
    required this.frecuenciaAporte,
    String? motivacion,
    String? descripcionAporte,
    DateTime? fechaAceptacion,
    DateTime? fechaRegistro,
    this.fotoCedula,
    this.fotoMascota,
    this.estadoProceso = 'pendiente',
    this.estadoCorreo = 'pendiente',
    this.aceptoTerminos = true,
  })  : montoAporte = montoAporte ?? valorMensual,
        motivacion = motivacion ?? descripcionAporte ?? detalleAporte ?? '',
        fechaAceptacion = fechaAceptacion ?? fechaRegistro ?? DateTime.now();
}

class AcuerdoApadrinamientoPdfService {
  AcuerdoApadrinamientoPdfService._();

  static const List<String> requisitosApadrinamiento = [
    'Proporcionar información personal y de contacto verídica y actualizada.',
    'Indicar una modalidad de ayuda que pueda cumplir de manera responsable.',
    'Si ofrece un aporte recurrente, comprometerse con la frecuencia que acuerde con el albergue.',
    'Aceptar las condiciones de contacto, coordinación de entregas y visitas establecidas por el albergue.',
    'Comprender que el bienestar de la mascota requiere compromiso, responsabilidad y respeto por sus necesidades.',
    'Aceptar el tratamiento de los datos personales de acuerdo con la política de privacidad del sistema.',
  ];

  static const List<Map<String, String>> clausulasAcuerdo = [
    {
      'num': '1',
      'titulo': 'Compromiso de Apoyo y Bienestar',
      'cuerpo':
          'Brindar el aporte voluntario según la modalidad y periodicidad acordadas para contribuir a la alimentación, atención veterinaria, medicamentos y bienestar integral de la mascota apadrinada.',
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

  /// Genera los bytes del documento PDF con diseño limpio, logo oficial de Paw Match y fotos integradas.
  static Future<Uint8List> generarPdfBytes(
      DatosAcuerdoApadrinamiento datos) async {
    final pdf = pw.Document();

    // Intentar cargar la foto del logo de Paw Match
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('No se pudo cargar logo de Paw Match: $e');
    }

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
          debugPrint('Error al rasterizar cédula PDF para acuerdo: $e');
        }
      } else {
        jpgCedula = await prepararFotoParaPdf(bytesCedula);
      }
    }
    final fotoCedula = jpgCedula == null ? null : pw.MemoryImage(jpgCedula);

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

    final tipoNorm = datos.tipoAporte.toLowerCase();
    final esMonetario = tipoNorm.contains('monetario');
    final esEspecie = tipoNorm.contains('especie');

    final razaTexto = (datos.razaMascota != null &&
            datos.razaMascota!.trim().isNotEmpty)
        ? datos.razaMascota!
        : 'Mestiza';

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
          // ───────── ENCABEZADO SUPERIOR CON LOGO Y FUNDACIÓN ─────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 54,
                height: 54,
                padding: const pw.EdgeInsets.all(3),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(10)),
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

          // ───────── TÍTULO PRINCIPAL ─────────
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
                  'ACUERDO DE RESPONSABILIDAD Y COMPROMISO DE APADRINAMIENTO',
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

          // ───────── SECCIÓN 1: INFORMACIÓN DEL APADRINAMIENTO ─────────
          pw.Text(
            '1. Información del apadrinamiento',
            style: pw.TextStyle(
              color: grisOscuro,
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Datos del padrino/madrina, mascota apadrinada, modalidad de ayuda seleccionada y estado del proceso:',
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
                // Ficha de la mascota con fotografía integrada
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
                            'Mascota apadrinada: ${datos.nombreMascota}',
                            style: pw.TextStyle(
                              fontSize: 11.5,
                              fontWeight: pw.FontWeight.bold,
                              color: verdePrincipal,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '${datos.especieMascota} · $razaTexto · ${datos.edadMascota}',
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

                _filaDato('Fundación protectora:', FundacionInfo.nombre),
                _filaDato('Nombre del padrino/madrina:', datos.nombreUsuario),
                if (datos.documentoUsuario != null &&
                    datos.documentoUsuario!.trim().isNotEmpty)
                  _filaDato('Documento de identidad:', datos.documentoUsuario!.trim())
                else if (Session.documentoIdentidad.trim().isNotEmpty)
                  _filaDato('Documento de identidad:', Session.documentoIdentidad.trim()),
                _filaDato('Correo electrónico:', datos.correoUsuario),
                if (datos.telefonoUsuario != null &&
                    datos.telefonoUsuario!.trim().isNotEmpty)
                  _filaDato('Teléfono de contacto:', datos.telefonoUsuario!.trim()),

                // CAMPOS DIVERGENTES SEGÚN LA MODALIDAD
                pw.SizedBox(height: 4),
                pw.Container(height: 0.5, color: grisBorde),
                pw.SizedBox(height: 4),

                if (esMonetario) ...[
                  _filaDato('Modalidad de ayuda:', 'Aporte monetario'),
                  _filaDato(
                    'Valor del aporte:',
                    datos.montoAporte != null && datos.montoAporte! > 0
                        ? '\$ ${datos.montoAporte.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} COP'
                        : '\$ 0 COP',
                  ),
                  _filaDato('Frecuencia del aporte:', frecuenciaTexto),
                ] else if (esEspecie) ...[
                  _filaDato('Modalidad de ayuda:', 'Aporte en especie'),
                  _filaDato(
                    'Artículos y productos ofrecidos:',
                    (datos.detalleAporte != null &&
                            datos.detalleAporte!.trim().isNotEmpty)
                        ? datos.detalleAporte!.trim()
                        : 'Alimento y artículos de cuidado',
                  ),
                  _filaDato('Frecuencia de las entregas:', frecuenciaTexto),
                ] else ...[
                  _filaDato('Modalidad de ayuda:', 'Otro tipo de ayuda'),
                  _filaDato(
                    'Descripción del apoyo ofrecido:',
                    (datos.detalleAporte != null &&
                            datos.detalleAporte!.trim().isNotEmpty)
                        ? datos.detalleAporte!.trim()
                        : 'Acompañamiento y apoyo general',
                  ),
                ],

                pw.SizedBox(height: 4),
                pw.Container(height: 0.5, color: grisBorde),
                pw.SizedBox(height: 4),

                _filaDato('Fecha de registro:', fechaFormateada),
              ],
            ),
          ),

          pw.SizedBox(height: 8),
          pw.Text(
            'Motivación declarada por el padrino/madrina:',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#374151'),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            datos.motivacion.trim().isNotEmpty
                ? datos.motivacion.trim()
                : 'Deseo contribuir con amor y responsabilidad al bienestar de esta mascota.',
            style: pw.TextStyle(fontSize: 10, color: grisOscuro),
          ),

          pw.SizedBox(height: 10),

          // ───────── SECCIÓN 2: REQUISITOS Y CONDICIONES ─────────
          pw.Text(
            '2. Requisitos y condiciones del apadrinamiento',
            style: pw.TextStyle(
              color: grisOscuro,
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Condiciones y compromisos fundamentales aceptados por el solicitante antes de registrarse:',
            style: pw.TextStyle(color: grisMedio, fontSize: 10),
          ),
          pw.SizedBox(height: 6),

          ...requisitosApadrinamiento.asMap().entries.map((entry) {
            final num = entry.key + 1;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 18,
                    child: pw.Text(
                      '$num.',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: verdePrincipal,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      entry.value,
                      style: pw.TextStyle(fontSize: 9.5, color: grisOscuro),
                    ),
                  ),
                ],
              ),
            );
          }),

          pw.SizedBox(height: 10),

          // ───────── SECCIÓN 3: COMPROMISOS DEL ACUERDO ─────────
          pw.Text(
            '3. Compromisos del acuerdo',
            style: pw.TextStyle(
              color: grisOscuro,
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Cláusulas oficiales aceptadas por el padrino o madrina:',
            style: pw.TextStyle(color: grisMedio, fontSize: 10),
          ),
          pw.SizedBox(height: 6),

          ...clausulasAcuerdo.map(
            (c) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 18,
                    child: pw.Text(
                      '${c['num']}.',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: verdePrincipal,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.RichText(
                      text: pw.TextSpan(
                        style: pw.TextStyle(fontSize: 9.5, color: grisOscuro),
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

          // ───────── SECCIÓN 4: CONSTANCIA DE ACEPTACIÓN ELECTRÓNICA ─────────
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
            'Radicado, fecha y hora del registro y constancia de aceptación expresa:',
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
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'El solicitante marcó las casillas obligatorias de comprensión del proceso y aceptación de los requisitos del apadrinamiento, enviando formalmente su solicitud a través de la plataforma Paw Match. La constancia ha sido registrada de forma segura en la base de datos de la Fundación.',
                  style: pw.TextStyle(fontSize: 9, color: grisOscuro),
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
                  style: pw.TextStyle(fontSize: 9, color: grisOscuro),
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
            width: 195,
            child: pw.Text(
              etiqueta,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#374151'),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              valor,
              style: pw.TextStyle(
                fontSize: 9.5,
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
    final sanitizedPet =
        nombreMascota.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filename = 'Acuerdo_Apadrinamiento_$sanitizedPet.pdf';

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
