import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/seguimiento_apadrinamiento.dart';

class ReportePadrinoPdfService {
  ReportePadrinoPdfService._();

  static const List<String> _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  static String _formatearFecha(DateTime f) {
    final dia = f.day.toString().padLeft(2, '0');
    final mes = _meses[(f.month - 1).clamp(0, 11)];
    return '$dia de $mes de ${f.year}';
  }

  static String _formatearFechaCorta(DateTime f) {
    final dia = f.day.toString().padLeft(2, '0');
    final mes = f.month.toString().padLeft(2, '0');
    return '$dia/$mes/${f.year}';
  }

  /// Genera el documento PDF y lo abre para compartir/descargar mediante Printing.sharePdf
  static Future<void> generarYDescargarReporte({
    required String padrinoNombre,
    required String padrinoCorreo,
    String? padrinoTelefono,
    required String mascotaNombre,
    String? mascotaEspecie,
    String? mascotaRaza,
    String? mascotaEdad,
    required List<SeguimientoApadrinamientoItem> seguimientos,
    String? estadoApadrinamiento,
    String? motivoCancelacion,
    DateTime? fechaCancelacion,
  }) async {
    final bytes = await construirPdfBytes(
      padrinoNombre: padrinoNombre,
      padrinoCorreo: padrinoCorreo,
      padrinoTelefono: padrinoTelefono,
      mascotaNombre: mascotaNombre,
      mascotaEspecie: mascotaEspecie,
      mascotaRaza: mascotaRaza,
      mascotaEdad: mascotaEdad,
      seguimientos: seguimientos,
      estadoApadrinamiento: estadoApadrinamiento,
      motivoCancelacion: motivoCancelacion,
      fechaCancelacion: fechaCancelacion,
    );

    final sanitizedPet =
        mascotaNombre.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filename = 'Reporte_Padrino_$sanitizedPet.pdf';

    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }

  /// Construye los bytes del PDF respetando la tipografía, colores y tablas requeridas.
  static Future<Uint8List> construirPdfBytes({
    required String padrinoNombre,
    required String padrinoCorreo,
    String? padrinoTelefono,
    required String mascotaNombre,
    String? mascotaEspecie,
    String? mascotaRaza,
    String? mascotaEdad,
    required List<SeguimientoApadrinamientoItem> seguimientos,
    String? estadoApadrinamiento,
    String? motivoCancelacion,
    DateTime? fechaCancelacion,
  }) async {
    pw.ThemeData tema;
    try {
      final ttfRegular = await PdfGoogleFonts.robotoRegular();
      final ttfBold = await PdfGoogleFonts.robotoBold();
      tema = pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold);
    } catch (_) {
      tema = pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }

    final pdf = pw.Document(theme: tema);

    // Cálculos
    final totalSeguimientos = seguimientos.length;
    final int sumaNotas =
        seguimientos.fold(0, (acc, item) => acc + item.calificacion);
    final double promedio =
        totalSeguimientos > 0 ? (sumaNotas / totalSeguimientos) : 0.0;
    final int incumplimientos =
        seguimientos.where((s) => !s.cumplimiento || s.calificacion <= 2).length;

    // Clasificación y estilos de color
    final String clasificacionTexto;
    final PdfColor colorPuntuacionFondo;
    final PdfColor colorPuntuacionBorde;
    final PdfColor colorPuntuacionTexto;

    if (promedio >= 4.0) {
      clasificacionTexto = 'BUEN APADRINANTE';
      colorPuntuacionFondo = PdfColor.fromHex('#E8F5E9');
      colorPuntuacionBorde = PdfColor.fromHex('#2E7D32');
      colorPuntuacionTexto = PdfColor.fromHex('#1B5E20');
    } else if (promedio >= 3.0) {
      clasificacionTexto = 'APADRINANTE REGULAR';
      colorPuntuacionFondo = PdfColor.fromHex('#FFF3E0');
      colorPuntuacionBorde = PdfColor.fromHex('#EF6C00');
      colorPuntuacionTexto = PdfColor.fromHex('#E65100');
    } else {
      clasificacionTexto = 'MAL APADRINANTE';
      colorPuntuacionFondo = PdfColor.fromHex('#FFEBEE');
      colorPuntuacionBorde = PdfColor.fromHex('#C62828');
      colorPuntuacionTexto = PdfColor.fromHex('#B71C1C');
    }

    final fechaHoyStr = _formatearFecha(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        build: (context) => [
          // 1. ENCABEZADO
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      FundacionInfo.nombre.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#880E4F'),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Reporte Oficial de Seguimiento de Apadrinamiento',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Fecha de emisión:',
                      style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      fechaHoyStr,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // 2. DATOS DEL PADRINO Y DE LA MASCOTA
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Columna Padrino
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FAFAFA'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DATOS DEL PADRINO',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#AD1457'),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      _filaDato('Nombre:', padrinoNombre),
                      _filaDato('Correo:', padrinoCorreo),
                      if (padrinoTelefono != null && padrinoTelefono.isNotEmpty)
                        _filaDato('Teléfono:', padrinoTelefono),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 14),
              // Columna Mascota
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FAFAFA'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MASCOTA APADRINADA',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#AD1457'),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      _filaDato('Nombre:', mascotaNombre),
                      if (mascotaEspecie != null && mascotaEspecie.isNotEmpty)
                        _filaDato('Especie:', mascotaEspecie),
                      if (mascotaRaza != null && mascotaRaza.isNotEmpty)
                        _filaDato('Raza:', mascotaRaza),
                      if (mascotaEdad != null && mascotaEdad.isNotEmpty)
                        _filaDato('Edad:', mascotaEdad),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 14),

          // 3. RESUMEN Y PUNTUACIÓN FINAL
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: colorPuntuacionFondo,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              border: pw.Border.all(color: colorPuntuacionBorde, width: 1.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RESUMEN GENERAL DE SEGUIMIENTOS',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: colorPuntuacionTexto,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Total de seguimientos: $totalSeguimientos',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Calificación promedio: ${promedio.toStringAsFixed(1)} / 5',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Incumplimientos registrados: $incumplimientos',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: incumplimientos > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                          color: incumplimientos > 0 ? PdfColor.fromHex('#C62828') : PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: colorPuntuacionBorde, width: 1.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'PUNTUACIÓN FINAL',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        clasificacionTexto,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: colorPuntuacionTexto,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${promedio.toStringAsFixed(1)} / 5',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: colorPuntuacionBorde,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 6. ALERTA DE CANCELACIÓN (Si aplica)
          if ((estadoApadrinamiento == 'cancelada') ||
              (motivoCancelacion != null && motivoCancelacion.trim().isNotEmpty)) ...[
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FFEBEE'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColor.fromHex('#E53935'), width: 1.2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'APADRINAMIENTO CANCELADO',
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#B71C1C'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  if (fechaCancelacion != null)
                    pw.Text(
                      'Fecha de cancelación: ${_formatearFecha(fechaCancelacion)}',
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                  if (motivoCancelacion != null && motivoCancelacion.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Motivo: $motivoCancelacion',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#C62828'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          pw.SizedBox(height: 16),

          // 5. TABLA DE HISTORIAL DE SEGUIMIENTOS
          pw.Text(
            'HISTORIAL DETALLADO DE SEGUIMIENTOS',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#880E4F'),
            ),
          ),
          pw.SizedBox(height: 8),

          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#AD1457'),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            headers: <String>[
              'Fecha',
              'Administrador',
              'Calificación',
              'Cumplió',
              'Observaciones / Comentarios'
            ],
            data: seguimientos.map((s) {
              return [
                _formatearFechaCorta(s.fechaSeguimiento),
                s.adminNombre.isNotEmpty ? s.adminNombre : 'Administrador',
                '${s.calificacion} / 5',
                s.cumplimiento ? 'Sí' : 'No',
                s.observaciones.isEmpty ? '-' : s.observaciones,
              ];
            }).toList(),
            columnWidths: {
              0: const pw.FixedColumnWidth(65),
              1: const pw.FixedColumnWidth(95),
              2: const pw.FixedColumnWidth(65),
              3: const pw.FixedColumnWidth(55),
              4: const pw.FlexColumnWidth(),
            },
          ),

          pw.SizedBox(height: 20),

          // Pie institucional
          pw.Center(
            child: pw.Text(
              'Documento emitido por el sistema PawMatch para la ${FundacionInfo.nombre}.',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ),
        ],
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
            width: 55,
            child: pw.Text(
              etiqueta,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              valor,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }
}
