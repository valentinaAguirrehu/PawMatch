import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Detalle de una solicitud de adopción, con la misma revisión que Apadrinamiento.
class AdoptionDetailAdminScreen extends StatefulWidget {
  final AdoptionRequest request;
  final ValueChanged<String> onCambioEstado;

  /// Si es verdadero, se muestra como página (sin la barra de la hoja).
  final bool enPagina;

  /// Muestra solo el recuadro para subir o ver el contrato.
  final bool soloContrato;

  const AdoptionDetailAdminScreen({
    super.key,
    required this.request,
    required this.onCambioEstado,
    this.enPagina = false,
    this.soloContrato = false,
  });

  @override
  State<AdoptionDetailAdminScreen> createState() =>
      _AdoptionDetailAdminScreenState();
}

class _AdoptionDetailAdminScreenState extends State<AdoptionDetailAdminScreen> {
  Uint8List? _cedula;
  Uint8List? _recibo;
  bool _cargandoCedula = true;
  bool _cargandoRecibo = true;
  String? _errorCedula;
  String? _errorRecibo;

  Uint8List? _contratoBytes;
  bool _cargandoContrato = false;
  String? _errorContrato;
  bool _subiendoContrato = false;
  late bool _tieneContrato;
  String? _nombreContrato;

  bool _esPdf(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  @override
  void initState() {
    super.initState();
    _tieneContrato = widget.request.hasContract;
    _nombreContrato = widget.request.contractFile;
    if (!widget.soloContrato) _cargarDocumentos();
    if (_tieneContrato) _cargarContrato();
  }

  Future<void> _cargarDocumentos() async {
    await Future.wait([
      _cargar(cedula: true),
      _cargar(cedula: false),
    ]);
  }

  Future<void> _cargar({required bool cedula}) async {
    final hayArchivo = cedula
        ? widget.request.hasIdPhoto
        : widget.request.hasUtilityBill;
    if (!hayArchivo) {
      if (!mounted) return;
      setState(() {
        if (cedula) {
          _cargandoCedula = false;
        } else {
          _cargandoRecibo = false;
        }
      });
      return;
    }

    try {
      final bytes = cedula
          ? await AdoptionService.fetchIdCard(widget.request.id)
          : await AdoptionService.fetchUtilityBill(widget.request.id);
      if (!mounted) return;
      setState(() {
        if (cedula) {
          _cedula = bytes;
          _cargandoCedula = false;
        } else {
          _recibo = bytes;
          _cargandoRecibo = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final mensaje = e.toString().replaceFirst('Exception: ', '');
        if (cedula) {
          _errorCedula = mensaje;
          _cargandoCedula = false;
        } else {
          _errorRecibo = mensaje;
          _cargandoRecibo = false;
        }
      });
    }
  }

  Future<void> _descargarAdjunto(Uint8List bytes, String titulo) async {
    final esPdf = _esPdf(bytes);
    final esPng = bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final extension = esPdf ? 'pdf' : (esPng ? 'png' : 'jpg');
    final base = titulo
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    try {
      final ruta = await FilePicker.saveFile(
        dialogTitle: 'Descargar $titulo',
        fileName: '${base.isEmpty ? 'documento' : base}.$extension',
        bytes: bytes,
        mimeType: esPdf ? 'application/pdf' : (esPng ? 'image/png' : 'image/jpeg'),
      );
      if (!mounted || ruta == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$titulo descargado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar: $e')),
      );
    }
  }

  void _verCompleta(Uint8List bytes, String titulo) {
    final esPdf = _esPdf(bytes);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      pageBuilder: (ctx, _, _) {
        return SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 72, 22, 108),
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.rosa.withValues(alpha: 0.45),
                              blurRadius: 36,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: esPdf
                              ? ColoredBox(
                                  color: Colors.white,
                                  child: SizedBox(
                                    height: 220,
                                    width: double.infinity,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade700, size: 64),
                                        const SizedBox(height: 10),
                                        Text(
                                          titulo,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Image.memory(bytes, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1F2937),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 18,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosa,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _descargarAdjunto(bytes, titulo),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Descargar', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _cargarContrato() async {
    setState(() {
      _cargandoContrato = true;
      _errorContrato = null;
    });
    try {
      final bytes = await AdoptionService.fetchContract(widget.request.id);
      if (!mounted) return;
      setState(() {
        _contratoBytes = bytes;
        _cargandoContrato = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorContrato = e.toString().replaceFirst('Exception: ', '');
        _cargandoContrato = false;
      });
    }
  }

  void _verContrato() {
    final bytes = _contratoBytes;
    if (bytes == null) return;
    if (_esPdf(bytes)) {
      Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: _nombreContrato ?? 'Contrato_Adopcion_${widget.request.petName}.pdf',
      );
      return;
    }
    _verCompleta(bytes, 'Contrato de adopción');
  }

  Future<void> _subirContrato() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (files.isEmpty) return;
      final file = files.first;
      final bytes = await file.xFile.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('No se pudo leer el archivo seleccionado.'),
          ),
        );
        return;
      }

      final ext = file.name.split('.').last.toLowerCase();
      final esPdf = ext == 'pdf' || _esPdf(bytes);
      if (!mounted) return;

      final confirmacion = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: AppColors.rosa),
              SizedBox(width: 8),
              Expanded(child: Text('Confirmar subida')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Subir este contrato de adopción para ${widget.request.applicantFullName}? El adoptante recibirá un correo y una alerta en la app.',
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      esPdf ? Icons.picture_as_pdf : Icons.image,
                      color: esPdf ? Colors.redAccent : AppColors.rosa,
                      size: 32,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '${(bytes.length / 1024).toStringAsFixed(1)} KB • ${ext.toUpperCase()}',
                            style: TextStyle(color: AppColors.grisTexto, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      if (confirmacion != true) return;

      setState(() => _subiendoContrato = true);
      await AdoptionService.subirContrato(
        id: widget.request.id,
        bytes: bytes,
        nombreArchivo: file.name,
      );
      if (!mounted) return;
      setState(() {
        _subiendoContrato = false;
        _contratoBytes = bytes;
        _tieneContrato = true;
        _nombreContrato = file.name;
        _errorContrato = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Contrato subido. El adoptante ya puede verlo y descargarlo.',
          ),
        ),
      );
      widget.onCambioEstado('aprobada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _subiendoContrato = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al subir contrato: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.soloContrato) {
      return _seccionContrato();
    }

    final s = widget.request;
    final t = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, limites) {
        final menu = 82 + MediaQuery.paddingOf(context).bottom;
        final tope = MediaQuery.sizeOf(context).height - menu;
        final altoDisponible = limites.maxHeight.isFinite && limites.maxHeight < tope
            ? limites.maxHeight
            : tope;
        return Container(
          constraints: widget.enPagina
              ? null
              : BoxConstraints(maxHeight: altoDisponible),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.enPagina
            ? null
            : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          if (!widget.enPagina) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detalle de la solicitud',
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
          ],
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                _Seccion(
                  titulo: 'Mascota',
                  icono: Icons.pets,
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.rosa, width: 2.5),
                          ),
                          child: ClipOval(child: PetImage(url: s.petPhoto)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.petName.isEmpty ? 'Mascota' : s.petName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.rosaSuave,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.bordeRosa),
                          ),
                          child: Text(
                            s.petAgeLabel,
                            style: const TextStyle(
                              color: AppColors.rosa,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.petSummary,
                          style: TextStyle(color: AppColors.grisTexto),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Seccion(
                  titulo: 'Datos del solicitante',
                  icono: Icons.person,
                  child: Builder(
                    builder: (context) {
                      final filas = <(String, String)>[
                        ('Nombre completo', s.applicantFullName),
                        ('Correo electrónico', _vacio(s.applicantEmail)),
                        ('Celular', _vacio(s.applicantPhone)),
                        ('Dirección', _vacio(s.applicantAddress)),
                        if (s.applicantIdNumber.trim().isNotEmpty)
                          ('Número de cédula', s.applicantIdNumber),
                      ];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < filas.length; i++) ...[
                            _Dato(filas[i].$1, filas[i].$2, anchoEtiqueta: 114),
                            if (i != filas.length - 1)
                              Divider(height: 1, color: Colors.grey.shade200),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _Seccion(
                  titulo: 'Respuestas del formulario',
                  icono: Icons.favorite,
                  colorFondo: AppColors.rosaClaro.withValues(alpha: 0.35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final respuesta in s.answers) ...[
                        Text(
                          respuesta.question,
                          style: const TextStyle(
                            color: AppColors.rosa,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          respuesta.answer,
                          style: const TextStyle(height: 1.45, fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Seccion(
                  titulo: 'Foto de la cédula',
                  icono: Icons.badge_outlined,
                  child: _vistaFoto(
                    cargando: _cargandoCedula,
                    error: _errorCedula,
                    bytes: _cedula,
                    titulo: 'Cédula',
                  ),
                ),
                const SizedBox(height: 14),
                _Seccion(
                  titulo: 'Recibo de servicio público',
                  icono: Icons.receipt_long_outlined,
                  child: _vistaFoto(
                    cargando: _cargandoRecibo,
                    error: _errorRecibo,
                    bytes: _recibo,
                    titulo: 'Recibo de servicio público',
                  ),
                ),
                if (s.isApproved) ...[
                  const SizedBox(height: 14),
                  _seccionContrato(),
                ],
                const SizedBox(height: 14),
                _Seccion(
                  titulo: 'Detalles de la adopción',
                  icono: Icons.info_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Dato('Fecha de envío de solicitud', s.requestedAtLabel),
                      _Dato('Estado de la solicitud', s.status.toUpperCase()),
                      if (s.adoptionStartDateLabel != null)
                        _Dato('Fecha de inicio oficial', s.adoptionStartDateLabel!),
                      if (s.statusUpdatedAtLabel != null)
                        _Dato('Fecha de revisión', s.statusUpdatedAtLabel!),
                      if (s.hasObservations)
                        _Dato('Observaciones / motivo', s.observations!),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
        );
      },
    );
  }

  Widget _seccionContrato() {
    final hayArchivo = _tieneContrato || _contratoBytes != null;
    final Color fondoBase =
        hayArchivo ? Colors.green.shade50 : Colors.amber.shade50;
    return _Seccion(
      titulo: 'Contrato de adopción',
      icono: Icons.assignment_outlined,
      colorFondo: widget.soloContrato
          ? fondoBase
          : fondoBase.withValues(alpha: 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_subiendoContrato)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Procesando contrato de adopción...'),
                  ],
                ),
              ),
            )
          else if (hayArchivo) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Contrato de adopción subido. El adoptante ya puede verlo y descargarlo.',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_cargandoContrato)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [CircularProgressIndicator()],
                  ),
                ),
              )
            else if (_errorContrato != null)
              Text(
                'Error al cargar contrato: $_errorContrato',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              )
            else if (_contratoBytes != null) ...[
              if (_esPdf(_contratoBytes!))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nombreContrato ?? 'Contrato_Adopcion.pdf',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Documento PDF (${(_contratoBytes!.length / 1024).toStringAsFixed(1)} KB)',
                              style: TextStyle(color: AppColors.grisTexto, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _contratoBytes!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rosa,
                        side: const BorderSide(color: AppColors.rosa),
                      ),
                      onPressed: _verContrato,
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Ver'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _subirContrato,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Reemplazar'),
                    ),
                  ],
                ),
              ),
            ] else
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                onPressed: _cargarContrato,
                icon: const Icon(Icons.visibility),
                label: const Text('Cargar y ver contrato'),
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pendiente subir contrato de adopción. El adoptante verá ese estado hasta que cargues el contrato firmado (JPG, PNG o PDF).',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosa,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _subirContrato,
                icon: const Icon(Icons.upload_file),
                label: const Text(
                  'Subir contrato (JPG, PNG o PDF)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vistaFoto({
    required bool cargando,
    required String? error,
    required Uint8List? bytes,
    required String titulo,
  }) {
    if (cargando) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Text(error, style: const TextStyle(color: Colors.redAccent));
    }
    if (bytes == null) return const Text('No hay archivo adjunto.');
    final bool esDocumentoPdf = _esPdf(bytes);

    return GestureDetector(
      onTap: () => _verCompleta(bytes, titulo),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: esDocumentoPdf
              ? ColoredBox(
                  color: Colors.red.shade50,
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade700, size: 52),
                        const SizedBox(height: 8),
                        Text(
                          titulo,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Image.memory(
                  bytes,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, error, stackTrace) => Container(
                    height: 140,
                    alignment: Alignment.center,
                    color: AppColors.rosaSuave,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.description_outlined, color: AppColors.rosa, size: 40),
                        const SizedBox(height: 6),
                        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  String _vacio(String valor) => valor.trim().isEmpty ? 'No especificado' : valor;
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;
  final Color? colorFondo;

  const _Seccion({
    required this.titulo,
    required this.icono,
    required this.child,
    this.colorFondo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorFondo ?? Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: AppColors.rosa),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final double anchoEtiqueta;

  const _Dato(this.etiqueta, this.valor, {this.anchoEtiqueta = 132});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: anchoEtiqueta,
            child: Text(
              etiqueta,
              style: TextStyle(
                color: AppColors.grisTexto,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                height: 1.35,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
