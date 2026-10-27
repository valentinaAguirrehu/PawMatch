import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
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

  /// Carga el logo institucional de PawMatch de forma segura.
  static Future<pw.MemoryImage?> _cargarLogoPawMatch() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      final Uint8List bytes = data.buffer.asUint8List();
      return pw.MemoryImage(bytes);
    } catch (e) {
      debugPrint('[PDF] Logo no encontrado en assets/images/logo.png: $e');
      return null;
    }
  }

  /// Solo abre la vista previa dentro de la app (sin descargar).
  static Future<void> verReporte({
    required String padrinoNombre,
    required String padrinoCorreo,
    String? padrinoTelefono,
    required String mascotaNombre,
    String? mascotaEspecie,
    String? mascotaRaza,
    String? mascotaEdad,
    required List<SeguimientoApadrinamientoItem> seguimientos,
    int cicloReporte = 1,
    List<CicloEvaluacionItem> ciclosAnteriores = const [],
    String? estadoApadrinamiento,
    String? motivoCancelacion,
    DateTime? fechaCancelacion,
    String? decisionAdmin,
    String? notaDecision,
    DateTime? fechaDecision,
    String? adminDecisionNombre,
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
      cicloReporte: cicloReporte,
      ciclosAnteriores: ciclosAnteriores,
      estadoApadrinamiento: estadoApadrinamiento,
      motivoCancelacion: motivoCancelacion,
      fechaCancelacion: fechaCancelacion,
      decisionAdmin: decisionAdmin,
      notaDecision: notaDecision,
      fechaDecision: fechaDecision,
      adminDecisionNombre: adminDecisionNombre,
    );

    final sanitizedPet = mascotaNombre.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filename = 'Reporte_Ciclo${cicloReporte}_$sanitizedPet.pdf';

    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: filename,
    );
  }

  /// Solo descarga / comparte el reporte PDF (sin abrir vista previa dentro de la app).
  static Future<void> descargarReporte({
    required String padrinoNombre,
    required String padrinoCorreo,
    String? padrinoTelefono,
    required String mascotaNombre,
    String? mascotaEspecie,
    String? mascotaRaza,
    String? mascotaEdad,
    required List<SeguimientoApadrinamientoItem> seguimientos,
    int cicloReporte = 1,
    List<CicloEvaluacionItem> ciclosAnteriores = const [],
    String? estadoApadrinamiento,
    String? motivoCancelacion,
    DateTime? fechaCancelacion,
    String? decisionAdmin,
    String? notaDecision,
    DateTime? fechaDecision,
    String? adminDecisionNombre,
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
      cicloReporte: cicloReporte,
      ciclosAnteriores: ciclosAnteriores,
      estadoApadrinamiento: estadoApadrinamiento,
      motivoCancelacion: motivoCancelacion,
      fechaCancelacion: fechaCancelacion,
      decisionAdmin: decisionAdmin,
      notaDecision: notaDecision,
      fechaDecision: fechaDecision,
      adminDecisionNombre: adminDecisionNombre,
    );

    final sanitizedPet = mascotaNombre.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filename = 'Reporte_Ciclo${cicloReporte}_$sanitizedPet.pdf';

    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }

  /// Construye los bytes del PDF respetando la tipografía, colores, logo y tablas requeridas.
  static Future<Uint8List> construirPdfBytes({
    required String padrinoNombre,
    required String padrinoCorreo,
    String? padrinoTelefono,
    required String mascotaNombre,
    String? mascotaEspecie,
    String? mascotaRaza,
    String? mascotaEdad,
    required List<SeguimientoApadrinamientoItem> seguimientos,
    int cicloReporte = 1,
    List<CicloEvaluacionItem> ciclosAnteriores = const [],
    String? estadoApadrinamiento,
    String? motivoCancelacion,
    DateTime? fechaCancelacion,
    String? decisionAdmin,
    String? notaDecision,
    DateTime? fechaDecision,
    String? adminDecisionNombre,
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

    final logoImage = await _cargarLogoPawMatch();
    final pdf = pw.Document(theme: tema);

    // Filtrar seguimientos pertenecientes al ciclo especificado
    final List<SeguimientoApadrinamientoItem> segsCiclo = seguimientos
        .where((s) => s.ciclo == cicloReporte || seguimientos.length <= 3)
        .toList();

    final listaSegs = segsCiclo.isNotEmpty ? segsCiclo : seguimientos;
    final totalSeguimientos = listaSegs.length;

    final int sumaNotas = listaSegs.fold(0, (acc, item) => acc + item.calificacion);
    final double promedio = totalSeguimientos > 0 ? (sumaNotas / totalSeguimientos) : 0.0;
    final int incumplimientos =
        listaSegs.where((s) => !s.cumplimiento || s.calificacion <= 2).length;

    // Resumen de aportes del ciclo
    int totalAportesRevisados = 0;
    int aportesRecibidos = 0;
    int aportesNoRecibidos = 0;
    for (final seg in listaSegs) {
      for (final ap in seg.aportes) {
        totalAportesRevisados++;
        if (ap.recibido) {
          aportesRecibidos++;
        } else {
          aportesNoRecibidos++;
        }
      }
    }

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
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          margin: const pw.EdgeInsets.only(bottom: 14),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      FundacionInfo.nombre.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#880E4F'),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Reporte Oficial de Seguimiento de Apadrinamiento · Ciclo $cicloReporte',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (logoImage != null)
                pw.Container(
                  width: 55,
                  height: 55,
                  margin: const pw.EdgeInsets.only(left: 10),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
            ],
          ),
        ),
        build: (context) => [
          // 1. FECHA DE EMISIÓN Y TÍTULO
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'EVALUACIÓN DEL CICLO $cicloReporte (SEGUIMIENTOS ${(cicloReporte - 1) * 3 + 1} A ${cicloReporte * 3})',
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#AD1457'),
                ),
              ),
              pw.Text(
                'Emisión: $fechaHoyStr',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
              ),
            ],
          ),

          pw.SizedBox(height: 12),

          // 2. DATOS DEL PADRINO Y DE LA MASCOTA
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Columna Padrino
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
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
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#AD1457'),
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      _filaDato('Nombre:', padrinoNombre),
                      _filaDato('Correo:', padrinoCorreo),
                      if (padrinoTelefono != null && padrinoTelefono.isNotEmpty)
                        _filaDato('Teléfono:', padrinoTelefono),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              // Columna Mascota
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
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
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#AD1457'),
                        ),
                      ),
                      pw.SizedBox(height: 5),
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

          pw.SizedBox(height: 12),

          // 3. RESUMEN Y PUNTUACIÓN FINAL DEL CICLO
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
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
                        'RESUMEN DEL CICLO $cicloReporte',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: colorPuntuacionTexto,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Seguimientos en este ciclo: $totalSeguimientos de 3',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Calificación promedio del ciclo: ${promedio.toStringAsFixed(1)} / 5',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Incumplimientos en este ciclo: $incumplimientos',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: incumplimientos > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                          color: incumplimientos > 0 ? PdfColor.fromHex('#C62828') : PdfColors.black,
                        ),
                      ),
                      if (totalAportesRevisados > 0) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Aportes revisados: $totalAportesRevisados (Recibidos: $aportesRecibidos · No recibidos: $aportesNoRecibidos)',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: aportesNoRecibidos > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                            color: aportesNoRecibidos > 0 ? PdfColor.fromHex('#C62828') : PdfColor.fromHex('#1B5E20'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: colorPuntuacionBorde, width: 1.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'PUNTUACIÓN DEL CICLO',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        clasificacionTexto,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: colorPuntuacionTexto,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${promedio.toStringAsFixed(1)} / 5',
                        style: pw.TextStyle(
                          fontSize: 10.5,
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

          // 4. COMPARATIVO CON CICLOS ANTERIORES (si cicloReporte > 1)
          if (cicloReporte > 1 && ciclosAnteriores.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'RESUMEN COMPARATIVO DE CICLOS ANTERIORES',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#880E4F'),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
              headerStyle: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#AD1457'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              headers: ['Ciclo', 'Promedio', 'Puntuación', 'Decisión', 'Fecha'],
              data: ciclosAnteriores.map((c) {
                return [
                  'Ciclo ${c.ciclo}',
                  '${c.promedio.toStringAsFixed(1)} / 5',
                  c.clasificacionTexto,
                  c.decision == 'continuar' ? 'Continuar' : 'Cancelar',
                  _formatearFechaCorta(c.fechaDecision),
                ];
              }).toList(),
            ),
          ],

          pw.SizedBox(height: 14),

          // 5. TABLA DE HISTORIAL DE SEGUIMIENTOS DEL CICLO
          pw.Text(
            'DETALLE DE SEGUIMIENTOS DEL CICLO $cicloReporte',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#880E4F'),
            ),
          ),
          pw.SizedBox(height: 6),

          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#AD1457'),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            headers: <String>[
              'Seg.',
              'Fecha',
              'Administrador',
              'Calificación',
              'Cumplió',
              'Observaciones'
            ],
            data: listaSegs.map((s) {
              return [
                '#${s.numeroSeguimiento}',
                _formatearFechaCorta(s.fechaSeguimiento),
                s.adminNombre.isNotEmpty ? s.adminNombre : 'Administrador',
                '${s.calificacion} / 5',
                s.cumplimiento ? 'Sí' : 'No',
                s.observaciones.isEmpty ? '-' : s.observaciones,
              ];
            }).toList(),
            columnWidths: {
              0: const pw.FixedColumnWidth(35),
              1: const pw.FixedColumnWidth(60),
              2: const pw.FixedColumnWidth(85),
              3: const pw.FixedColumnWidth(60),
              4: const pw.FixedColumnWidth(50),
              5: const pw.FlexColumnWidth(),
            },
          ),

          // 6. DETALLE DE APORTES POR CADA SEGUIMIENTO
          if (listaSegs.any((s) => s.aportes.isNotEmpty)) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'REVISIÓN DE APORTES COMPROMETIDOS',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#880E4F'),
              ),
            ),
            pw.SizedBox(height: 5),
            ...listaSegs.where((s) => s.aportes.isNotEmpty).map((s) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F9FAFC'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Seguimiento #${s.numeroSeguimiento} (${_formatearFechaCorta(s.fechaSeguimiento)}):',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                    ),
                    pw.SizedBox(height: 3),
                    ...s.aportes.map((ap) {
                      final tipoStr = ap.tipo.toUpperCase();
                      final recStr = ap.recibido ? 'RECIBIDO' : 'NO RECIBIDO';
                      final colorAp = ap.recibido ? PdfColor.fromHex('#1B5E20') : PdfColor.fromHex('#C62828');

                      String extra = '';
                      if (ap.tipo == 'monetario') {
                        extra = 'Medio: ${ap.medio ?? '-'}' +
                            (ap.montoRecibido != null ? ' · Monto: \$${ap.montoRecibido!.toStringAsFixed(0)}' : '') +
                            (ap.referencia != null && ap.referencia!.isNotEmpty ? ' · Ref: ${ap.referencia}' : '');
                      } else {
                        extra = ap.detalleRecibido != null && ap.detalleRecibido!.isNotEmpty
                            ? 'Detalle: ${ap.detalleRecibido}'
                            : '';
                      }
                      if (!ap.recibido && ap.observacion != null && ap.observacion!.isNotEmpty) {
                        extra += ' · Motivo: ${ap.observacion}';
                      }

                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 4),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: pw.BoxDecoration(
                                color: ap.recibido ? PdfColor.fromHex('#E8F5E9') : PdfColor.fromHex('#FFEBEE'),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                              ),
                              child: pw.Text(
                                '$tipoStr: $recStr',
                                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: colorAp),
                              ),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Expanded(
                              child: pw.Text(
                                extra.isNotEmpty ? extra : (ap.comprometido ?? ''),
                                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],

          // 7. DECISIÓN DE LA FUNDACIÓN
          if (decisionAdmin != null ||
              estadoApadrinamiento == 'cancelada' ||
              (motivoCancelacion != null && motivoCancelacion.trim().isNotEmpty)) ...[
            pw.SizedBox(height: 12),
            () {
              final esCancelada = decisionAdmin == 'cancelar' || estadoApadrinamiento == 'cancelada';
              final colorFondo = esCancelada ? PdfColor.fromHex('#FFEBEE') : PdfColor.fromHex('#E8F5E9');
              final colorBorde = esCancelada ? PdfColor.fromHex('#E53935') : PdfColor.fromHex('#2E7D32');
              final colorTitulo = esCancelada ? PdfColor.fromHex('#B71C1C') : PdfColor.fromHex('#1B5E20');
              final titulo = esCancelada
                  ? 'Decisión de la fundación: Apadrinamiento cancelado'
                  : 'Decisión de la fundación: Continúa como padrino';

              return pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: colorFondo,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: colorBorde, width: 1.2),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      titulo,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: colorTitulo,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (fechaDecision != null || fechaCancelacion != null)
                      pw.Text(
                        'Fecha de decisión: ${_formatearFecha(fechaDecision ?? fechaCancelacion!)}',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    if (adminDecisionNombre != null && adminDecisionNombre.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Evaluado por: $adminDecisionNombre',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    ],
                    if (notaDecision != null && notaDecision.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Nota / Observaciones: $notaDecision',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                        ),
                      ),
                    ],
                    if (esCancelada &&
                        motivoCancelacion != null &&
                        motivoCancelacion.trim().isNotEmpty &&
                        motivoCancelacion != notaDecision) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Motivo de cancelación: $motivoCancelacion',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#C62828'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }(),
          ],

          pw.SizedBox(height: 16),

          // Pie institucional
          pw.Center(
            child: pw.Text(
              'Documento emitido por el sistema PawMatch para la ${FundacionInfo.nombre}.',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500),
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
            width: 50,
            child: pw.Text(
              etiqueta,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              valor,
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }
}
