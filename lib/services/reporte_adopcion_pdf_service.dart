import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/seguimiento_adopcion.dart';
import 'package:paw_match/services/compartir_acta_whatsapp.dart';
import 'package:paw_match/widgets/pet_card.dart' show urlFoto;

/// Reporte de seguimiento de una adopción. Se puede generar desde el primer
/// registro y siempre incluye todos los seguimientos hechos hasta el momento.
class ReporteAdopcionPdfService {
  ReporteAdopcionPdfService._();

  static const _rosa = '#AD1457';
  static const _rosaOscuro = '#880E4F';
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static String _fecha(DateTime f) {
    final dia = f.day.toString().padLeft(2, '0');
    return '$dia de ${_meses[f.month - 1]} de ${f.year}';
  }

  static String _fechaCorta(DateTime? f) {
    if (f == null) return '-';
    final dia = f.day.toString().padLeft(2, '0');
    final mes = f.month.toString().padLeft(2, '0');
    return '$dia/$mes/${f.year}';
  }

  static String nombreArchivo(String mascotaNombre) {
    final seguro = mascotaNombre.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return 'Reporte_Seguimiento_Adopcion_$seguro.pdf';
  }

  static Future<void> ver({
    required AdopcionActivaSeguimiento adopcion,
    required List<SeguimientoAdopcionItem> seguimientos,
  }) async {
    final bytes = await construir(adopcion: adopcion, seguimientos: seguimientos);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: nombreArchivo(adopcion.mascotaNombre),
    );
  }

  static Future<void> descargar({
    required AdopcionActivaSeguimiento adopcion,
    required List<SeguimientoAdopcionItem> seguimientos,
  }) async {
    final bytes = await construir(adopcion: adopcion, seguimientos: seguimientos);
    await Printing.sharePdf(
      bytes: bytes,
      filename: nombreArchivo(adopcion.mascotaNombre),
    );
  }

  /// Devuelve false si el dispositivo no pudo abrir WhatsApp con el archivo.
  static Future<bool> compartirWhatsApp({
    required AdopcionActivaSeguimiento adopcion,
    required List<SeguimientoAdopcionItem> seguimientos,
  }) async {
    final bytes = await construir(adopcion: adopcion, seguimientos: seguimientos);
    final total = seguimientos.length;
    return compartirActaPorWhatsApp(
      bytes: bytes,
      nombreArchivo: nombreArchivo(adopcion.mascotaNombre),
      mensaje:
          'Hola, te comparto el reporte de seguimiento de adopción de ${adopcion.mascotaNombre} '
          '($total ${total == 1 ? 'visita registrada' : 'visitas registradas'}).',
    );
  }

  static Future<Uint8List> construir({
    required AdopcionActivaSeguimiento adopcion,
    required List<SeguimientoAdopcionItem> seguimientos,
    CancelacionAdopcion? cancelacion,
  }) async {
    pw.ThemeData tema;
    try {
      tema = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.robotoRegular(),
        bold: await PdfGoogleFonts.robotoBold(),
      );
    } catch (_) {
      tema = pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }

    final logo = await _logo();
    final logoFundacion = await _logoFundacion();
    final fotoMascota = await _imagen(adopcion.fotoPrincipal);
    final fotoCancelacion1 = await _imagen(cancelacion?.foto1);
    final fotoCancelacion2 = await _imagen(cancelacion?.foto2);
    final ordenados = List<SeguimientoAdopcionItem>.from(seguimientos)
      ..sort((a, b) => b.numeroSeguimiento.compareTo(a.numeroSeguimiento));
    final fotosVisita = <String, ({pw.MemoryImage? estado, pw.MemoryImage? entorno})>{};
    for (final seg in ordenados) {
      fotosVisita[seg.idSeguimiento] = (
        estado: await _imagen(seg.fotoEstado),
        entorno: await _imagen(seg.fotoEntorno),
      );
    }

    final pdf = pw.Document(theme: tema);
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
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: 58,
                height: 58,
                child: logoFundacion == null
                    ? pw.SizedBox()
                    : pw.Image(logoFundacion, fit: pw.BoxFit.contain),
              ),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      FundacionInfo.nombre.toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex(_rosaOscuro),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Reporte Oficial de Seguimiento de Adopción',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(
                width: 58,
                height: 58,
                child: logo == null
                    ? pw.SizedBox()
                    : pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            ],
          ),
        ),
        build: (context) => [
          ..._encabezado(adopcion, fotoMascota),
          if (adopcion.adopcionCancelada) ...[
            pw.SizedBox(height: 12),
            _bloqueCancelacion(cancelacion, fotoCancelacion1, fotoCancelacion2),
          ],
          pw.SizedBox(height: 12),
          _resumen(ordenados),
          pw.SizedBox(height: 14),
          ..._tablas(ordenados, fotosVisita, adopcion.mascotaNombre),
        ],
      ),
    );

    return pdf.save();
  }

  static List<pw.Widget> _encabezado(
    AdopcionActivaSeguimiento adopcion,
    pw.MemoryImage? fotoMascota,
  ) {
    return [
      pw.Center(
        child: pw.Text(
          'DETALLES DE LA ADOPCIÓN',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex(_rosa),
          ),
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Emisión: ${_fecha(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
        ),
      ),
      pw.SizedBox(height: 12),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _tarjeta('DATOS DEL ADOPTANTE', [
              _filaDato('Nombre:', _dato(adopcion.adoptanteNombre)),
              _filaDato('Cédula:', _dato(adopcion.adoptanteCedula)),
              _filaDato('Teléfono:', _dato(adopcion.adoptanteTelefono)),
              _filaDato('Correo:', _dato(adopcion.adoptanteCorreo)),
              _filaDato('Dirección:', _dato(adopcion.adoptanteDireccion)),
            ]),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _tarjeta(
              'MASCOTA ADOPTADA',
              [
                _filaDato('Nombre:', adopcion.mascotaNombre),
                _filaDato('Especie:', _dato(adopcion.mascotaEspecie)),
                _filaDato('Raza:', _dato(adopcion.mascotaRaza)),
                _filaDato('Edad:', adopcion.edadTexto),
              ],
              foto: fotoMascota,
            ),
          ),
        ],
      ),
    ];
  }

  static pw.Widget _bloqueCancelacion(
    CancelacionAdopcion? cancelacion,
    pw.MemoryImage? foto1,
    pw.MemoryImage? foto2,
  ) {
    final filas = <List<String>>[
      ['Fecha de cancelación', cancelacion == null ? '-' : _fecha(cancelacion.fechaCancelacion)],
      ['Motivo', cancelacion == null || cancelacion.motivo.trim().isEmpty ? '-' : cancelacion.motivo.trim()],
      ['Observación', cancelacion == null || cancelacion.observacion.trim().isEmpty ? '-' : cancelacion.observacion.trim()],
      [
        'Cuenta del adoptante',
        cancelacion == null
            ? '-'
            : cancelacion.inhabilitarCuenta
                ? 'Inhabilitada'
                : 'Se mantiene activa',
      ],
      ['Encargado', cancelacion == null ? '-' : cancelacion.adminNombre],
    ];

    pw.Widget celda(String texto, {bool titulo = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          texto,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: titulo ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: titulo ? PdfColors.white : PdfColors.black,
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            'ADOPCIÓN CANCELADA',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#760000'),
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.15),
            1: pw.FlexColumnWidth(2.2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#760000')),
              children: [
                celda('Dato', titulo: true),
                celda('Detalle', titulo: true),
              ],
            ),
            for (final fila in filas)
              pw.TableRow(
                children: [
                  celda(fila[0]),
                  celda(fila[1]),
                ],
              ),
          ],
        ),
        if (foto1 != null || foto2 != null) ...[
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (foto1 != null) _fotoVisita('Fotografía 1', foto1),
              if (foto1 != null && foto2 != null) pw.SizedBox(width: 10),
              if (foto2 != null) _fotoVisita('Fotografía 2', foto2),
            ],
          ),
        ],
      ],
    );
  }

  static String _dato(String valor) {
    final limpio = valor.trim();
    return limpio.isEmpty ? 'No registrada' : limpio;
  }

  static List<pw.Widget> _tablas(
    List<SeguimientoAdopcionItem> visitas,
    Map<String, ({pw.MemoryImage? estado, pw.MemoryImage? entorno})> fotos,
    String nombreMascota,
  ) {
    final encabezado = pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final borde = pw.TableBorder.all(color: PdfColors.grey300, width: 0.8);
    final decoracion = pw.BoxDecoration(color: PdfColor.fromHex(_rosa));

    return [
      pw.Text(
        'RESUMEN DE SEGUIMIENTOS',
        style: pw.TextStyle(
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex(_rosaOscuro),
        ),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        border: borde,
        headerStyle: encabezado,
        headerDecoration: decoracion,
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        headers: const ['Seg.', 'Fecha', 'Encargado', 'Calificación', 'Cumplió', 'Observaciones'],
        data: [
          for (final seg in visitas)
            [
              '#${seg.numeroSeguimiento}',
              _fechaCorta(seg.fechaSeguimiento),
              seg.adminNombre.trim().isEmpty ? 'Encargado' : seg.adminNombre,
              '${seg.calificacion} / 5',
              seg.cumplimiento ? 'Sí' : 'No',
              seg.observaciones.trim().isEmpty ? '-' : seg.observaciones.trim(),
            ],
        ],
        columnWidths: {
          0: const pw.FixedColumnWidth(32),
          1: const pw.FixedColumnWidth(58),
          2: const pw.FixedColumnWidth(88),
          3: const pw.FixedColumnWidth(62),
          4: const pw.FixedColumnWidth(46),
          5: const pw.FlexColumnWidth(),
        },
      ),
      pw.SizedBox(height: 14),
      pw.Center(
        child: pw.Text(
          'SEGUIMIENTOS REALIZADOS A ${nombreMascota.trim().isEmpty ? 'LA MASCOTA' : nombreMascota.trim().toUpperCase()}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex(_rosaOscuro),
          ),
        ),
      ),
      pw.SizedBox(height: 8),
      for (final seg in visitas) _detalleVisita(seg, fotos[seg.idSeguimiento]),
    ];
  }

  static pw.Widget _detalleVisita(
    SeguimientoAdopcionItem seg,
    ({pw.MemoryImage? estado, pw.MemoryImage? entorno})? fotos,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text(
              'SEGUIMIENTO ${seg.numeroSeguimiento}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex(_rosa),
              ),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Fecha del seguimiento: ${_fecha(seg.fechaSeguimiento)}',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Encargado: ${seg.adminNombre.trim().isEmpty ? 'Encargado' : seg.adminNombre}',
            style: const pw.TextStyle(fontSize: 8.5),
          ),
          pw.SizedBox(height: 6),
          _tablaEvaluacion(seg),
          if (fotos?.estado != null || fotos?.entorno != null) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (fotos?.estado != null) _fotoVisita('Estado general', fotos!.estado!),
                if (fotos?.estado != null && fotos?.entorno != null) pw.SizedBox(width: 10),
                if (fotos?.entorno != null) _fotoVisita('Entorno', fotos!.entorno!),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _tablaEvaluacion(SeguimientoAdopcionItem seg) {
    final filas = <List<String>>[
      ['1. Estado físico y nutricional', 'Peso y pelaje', '${seg.pesoSaludable}/5'],
      ['', 'Salud e higiene', '${seg.condicionSanitaria}/5'],
      ['2. Entorno y bienestar', 'Vivienda y seguridad', '${seg.entornoApto}/5'],
      ['', 'Nivel de confianza', '${seg.comportamiento}/5'],
      ['3. Compromiso del adoptante', 'Cumplimiento médico', etiquetaRespuestaSeguimiento(seg.compromisoVeterinario)],
      ['', 'Trato y responsabilidad', etiquetaRespuestaSeguimiento(seg.disposicionAdoptante)],
      ['', 'Señales de alerta', seg.observaciones.trim().isEmpty ? '-' : seg.observaciones.trim()],
      ['4. Evaluación final', 'Calificación del adoptante', '${seg.calificacion}/5'],
      ['', 'Próximo seguimiento', _fechaCorta(seg.proximoSeguimiento)],
    ];

    pw.Widget celda(String texto, {bool titulo = false, bool categoria = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          texto,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: titulo || categoria ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: titulo ? PdfColors.white : PdfColors.black,
          ),
        ),
      );
    }

    const rosaPastel = '#FDE7F1';
    var grupo = -1;
    final fondos = <PdfColor>[
      for (final fila in filas)
        fila[0].isNotEmpty
            ? (grupo = grupo + 1).isOdd
                ? PdfColor.fromHex(rosaPastel)
                : PdfColors.white
            : grupo.isOdd
                ? PdfColor.fromHex(rosaPastel)
                : PdfColors.white,
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.45),
        1: pw.FlexColumnWidth(1.45),
        2: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex(_rosa)),
          children: [
            celda('Categoría', titulo: true),
            celda('Elemento evaluado', titulo: true),
            celda('Resultado', titulo: true),
          ],
        ),
        for (var i = 0; i < filas.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: fondos[i]),
            children: [
              celda(filas[i][0], categoria: filas[i][0].isNotEmpty),
              celda(filas[i][1]),
              celda(filas[i][2]),
            ],
          ),
      ],
    );
  }

  static pw.Widget _fotoVisita(String titulo, pw.MemoryImage imagen) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(titulo, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Container(
          width: 108,
          height: 80,
          child: pw.ClipRRect(
            horizontalRadius: 4,
            verticalRadius: 4,
            child: pw.Image(imagen, fit: pw.BoxFit.cover),
          ),
        ),
      ],
    );
  }

  static pw.Widget _resumen(List<SeguimientoAdopcionItem> visitas) {
    final promedio = visitas.isEmpty
        ? 0.0
        : visitas.fold<int>(0, (suma, seg) => suma + seg.calificacion) / visitas.length;
    final clasificacion = _clasificacion(promedio);
    final colores = _colores(promedio);
    final incumplimientos = visitas.where((seg) => !seg.cumplimiento).length;
    final alertas = visitas.where((seg) => seg.observaciones.trim().isNotEmpty).length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: colores.fondo,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: colores.borde, width: 1.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PROMEDIO TOTAL',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: colores.texto,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Seguimientos registrados: ${visitas.length}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Calificación promedio: ${promedio.toStringAsFixed(1)} / 5',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Incumplimientos: $incumplimientos',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: incumplimientos > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: incumplimientos > 0 ? PdfColor.fromHex('#C62828') : PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Señales de alerta registradas: $alertas',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: alertas > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: alertas > 0 ? PdfColor.fromHex('#C62828') : PdfColors.black,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: colores.borde, width: 1.5),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'PUNTUACIÓN',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  clasificacion,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: colores.texto,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${promedio.toStringAsFixed(1)} / 5',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: colores.borde,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _clasificacion(double promedio) {
    if (promedio >= 4) return 'BUEN ADOPTANTE';
    if (promedio >= 3) return 'ADOPTANTE REGULAR';
    return 'ADOPTANTE EN RIESGO';
  }

  static ({PdfColor fondo, PdfColor borde, PdfColor texto}) _colores(double promedio) {
    if (promedio >= 4) {
      return (
        fondo: PdfColor.fromHex('#E8F5E9'),
        borde: PdfColor.fromHex('#2E7D32'),
        texto: PdfColor.fromHex('#1B5E20'),
      );
    }
    if (promedio >= 3) {
      return (
        fondo: PdfColor.fromHex('#FFF3E0'),
        borde: PdfColor.fromHex('#EF6C00'),
        texto: PdfColor.fromHex('#E65100'),
      );
    }
    return (
      fondo: PdfColor.fromHex('#FFEBEE'),
      borde: PdfColor.fromHex('#C62828'),
      texto: PdfColor.fromHex('#B71C1C'),
    );
  }

  static pw.Widget _tarjeta(
    String titulo,
    List<pw.Widget> filas, {
    pw.MemoryImage? foto,
  }) {
    final datos = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: filas,
    );
    return pw.Container(
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
            titulo,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex(_rosa),
            ),
          ),
          pw.SizedBox(height: 5),
          if (foto == null)
            datos
          else
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: datos),
                pw.Container(
                  width: 64,
                  height: 64,
                  margin: const pw.EdgeInsets.only(left: 8),
                  child: pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(foto, fit: pw.BoxFit.cover),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static pw.Widget _filaDato(String etiqueta, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 58,
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

  static Future<pw.MemoryImage?> _imagen(String? ruta) async {
    final limpia = ruta?.trim() ?? '';
    if (limpia.isEmpty || limpia == 'null') return null;
    try {
      final res = await http.get(Uri.parse(urlFoto(limpia))).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      return pw.MemoryImage(res.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  static Future<pw.MemoryImage?> _logo() async {
    return _asset('assets/images/logo.png');
  }

  static Future<pw.MemoryImage?> _logoFundacion() async {
    return _asset('assets/images/Logo Fundación.png');
  }

  static Future<pw.MemoryImage?> _asset(String ruta) async {
    try {
      final data = await rootBundle.load(ruta);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
