import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/pets/pet_detail_screen.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/widgets/pet_card.dart';
import 'package:printing/printing.dart';

class ApadrinamientoAdminScreen extends StatefulWidget {
  const ApadrinamientoAdminScreen({super.key});

  @override
  State<ApadrinamientoAdminScreen> createState() =>
      _ApadrinamientoAdminScreenState();
}

class _ApadrinamientoAdminScreenState extends State<ApadrinamientoAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Future<List<SolicitudApadrinamiento>> _future;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _future = _cargar();
    ApadrinamientoService.marcarLeidasAdmin();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Asegurar que si hubo Hot Reload el TabController tenga la longitud exacta de 4
    if (_tabCtrl.length != 4) {
      final oldIndex = _tabCtrl.index.clamp(0, 3);
      _tabCtrl.dispose();
      _tabCtrl = TabController(length: 4, vsync: this, initialIndex: oldIndex);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<List<SolicitudApadrinamiento>> _cargar() =>
      ApadrinamientoService.listarParaAdmin();

  Future<void> _recargar() async {
    setState(() {
      _future = _cargar();
    });
    await _future.catchError((_) => <SolicitudApadrinamiento>[]);
  }

  void _abrirDetalle(SolicitudApadrinamiento sol) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleSolicitudSheet(
        solicitud: sol,
        onCambioEstado: (nuevoEstado) {
          Navigator.pop(context);
          _recargar();
          if (nuevoEstado == 'aprobada') {
            _tabCtrl.animateTo(1);
          } else if (nuevoEstado == 'rechazada') {
            _tabCtrl.animateTo(2);
          } else if (nuevoEstado == 'cancelada') {
            _tabCtrl.animateTo(3);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de Apadrinamiento'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.rosa,
          unselectedLabelColor: Colors.black54,
          indicatorColor: AppColors.rosa,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.mark_email_unread_outlined), text: 'Nuevas'),
            Tab(icon: Icon(Icons.check_circle_outline), text: 'Aprobadas'),
            Tab(icon: Icon(Icons.cancel_outlined), text: 'Rechazadas'),
            Tab(icon: Icon(Icons.highlight_off_outlined), text: 'Canceladas'),
          ],
        ),
      ),
      body: FutureBuilder<List<SolicitudApadrinamiento>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Error al cargar solicitudes: ${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosa,
                      ),
                      onPressed: _recargar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final todas = snap.data ?? [];
          final nuevas = todas.where((s) => s.esPendiente).toList();
          final aprobadas = todas.where((s) => s.esAprobada).toList();
          final rechazadas = todas.where((s) => s.esRechazada).toList();
          final canceladas = todas.where((s) => s.esCancelada).toList();

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _ListaSolicitudes(
                solicitudes: nuevas,
                mensajeVacio:
                    'No hay solicitudes nuevas pendientes por revisar.',
                onRefrescar: _recargar,
                onTap: _abrirDetalle,
              ),
              _ListaSolicitudes(
                solicitudes: aprobadas,
                mensajeVacio:
                    'No hay solicitudes de apadrinamiento aprobadas aún.',
                onRefrescar: _recargar,
                onTap: _abrirDetalle,
              ),
              _ListaSolicitudes(
                solicitudes: rechazadas,
                mensajeVacio: 'No hay solicitudes rechazadas.',
                onRefrescar: _recargar,
                onTap: _abrirDetalle,
              ),
              _ListaSolicitudes(
                solicitudes: canceladas,
                mensajeVacio: 'No hay solicitudes canceladas.',
                onRefrescar: _recargar,
                onTap: _abrirDetalle,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ListaSolicitudes extends StatelessWidget {
  final List<SolicitudApadrinamiento> solicitudes;
  final String mensajeVacio;
  final RefreshCallback onRefrescar;
  final ValueChanged<SolicitudApadrinamiento> onTap;

  const _ListaSolicitudes({
    required this.solicitudes,
    required this.mensajeVacio,
    required this.onRefrescar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (solicitudes.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefrescar,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mensajeVacio,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefrescar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: solicitudes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final s = solicitudes[i];
          final colorEstado = switch (s.estado) {
            'aprobada' => Colors.green,
            'rechazada' => Colors.redAccent,
            'cancelada' => Colors.blueGrey,
            _ => Colors.orange,
          };

          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onTap(s),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.rosaClaro,
                          radius: 22,
                          child: const Icon(
                            Icons.volunteer_activism,
                            color: AppColors.rosa,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.solicitanteNombreCompleto,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Desea apadrinar a ${s.mascotaNombre} (${s.mascotaEspecie})',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorEstado.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorEstado),
                          ),
                          child: Text(
                            s.estado.toUpperCase(),
                            style: TextStyle(
                              color: colorEstado,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (s.esAprobada) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: s.tieneContrato ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: s.tieneContrato ? Colors.green.shade200 : Colors.amber.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              s.tieneContrato ? Icons.verified : Icons.hourglass_top_rounded,
                              size: 14,
                              color: s.tieneContrato ? Colors.green.shade800 : Colors.amber.shade900,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              s.tieneContrato ? 'Contrato de apadrinamiento subido' : 'Falta subir contrato de apadrinamiento',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: s.tieneContrato ? Colors.green.shade800 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (s.esCancelada && s.observaciones != null && s.observaciones!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'Cancelada: ${s.observaciones}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    if (s.esRechazada) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.replay,
                                  size: 14,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Rechazada ${s.vecesRechazada} ${s.vecesRechazada == 1 ? 'vez' : 'veces'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ],
                            ),
                            if (s.observaciones != null && s.observaciones!.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Motivo: ${s.observaciones!.trim()}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 20),
                    // Vista previa de la motivación
                    Text(
                      'Motivación:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.motivacion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📅 ${s.fechaSolicitud}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        if (s.montoAporte != null)
                          Text(
                            '\$${s.montoAporte} / ${s.frecuenciaAporte}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.rosa,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetalleSolicitudSheet extends StatefulWidget {
  final SolicitudApadrinamiento solicitud;
  final ValueChanged<String> onCambioEstado;

  const _DetalleSolicitudSheet({
    required this.solicitud,
    required this.onCambioEstado,
  });

  @override
  State<_DetalleSolicitudSheet> createState() => _DetalleSolicitudSheetState();
}

class _DetalleSolicitudSheetState extends State<_DetalleSolicitudSheet> {
  Uint8List? _docBytes;
  bool _cargandoDoc = true;
  String? _errorDoc;

  Uint8List? _contratoBytes;
  bool _cargandoContrato = false;
  String? _errorContrato;
  bool _subiendoContrato = false;
  late bool _tieneContrato;
  String? _nombreContrato;

  bool _procesando = false;

  bool _esBytesPdf(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46; // %PDF
  }

  @override
  void initState() {
    super.initState();
    _tieneContrato = widget.solicitud.tieneContrato;
    _nombreContrato = widget.solicitud.contratoArchivo;
    _cargarDocumentoSeguro();
    if (_tieneContrato) {
      _cargarContratoSeguro();
    }
  }

  Future<void> _cargarDocumentoSeguro() async {
    try {
      final bytes = await ApadrinamientoService.obtenerBytesDocumento(
        widget.solicitud.id,
      );
      if (!mounted) return;
      setState(() {
        _docBytes = bytes;
        _cargandoDoc = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorDoc = e.toString().replaceFirst('Exception: ', '');
        _cargandoDoc = false;
      });
    }
  }

  Future<void> _cargarContratoSeguro() async {
    setState(() => _cargandoContrato = true);
    try {
      final bytes = await ApadrinamientoService.obtenerBytesContrato(
        widget.solicitud.id,
      );
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

  void _verDocumentoCompleto() {
    if (_docBytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Documento de Identidad Oficial'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(_docBytes!, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  void _verContratoCompleto() {
    if (_contratoBytes == null) return;
    if (_esBytesPdf(_contratoBytes!)) {
      Printing.layoutPdf(
        onLayout: (_) => _contratoBytes!,
        name: _nombreContrato ?? 'Contrato_Apadrinamiento_${widget.solicitud.mascotaNombre}.pdf',
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Contrato de Apadrinamiento'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(_contratoBytes!, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
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
      final esPdf = ext == 'pdf' || _esBytesPdf(bytes);

      if (!mounted) return;
      // Diálogo de confirmación: "¿Estás seguro de que deseas subir el contrato?"
      final confirmacion = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: AppColors.rosa),
              SizedBox(width: 8),
              Expanded(child: Text('Confirmar Subida')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que deseas subir este contrato de apadrinamiento para ${widget.solicitud.solicitanteNombreCompleto}?',
                style: const TextStyle(fontSize: 14.5),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${(bytes.length / 1024).toStringAsFixed(1)} KB • Formato: ${ext.toUpperCase()}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
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

      await ApadrinamientoService.subirContrato(
        idSolicitud: widget.solicitud.id,
        bytesContrato: bytes,
        nombreArchivo: file.name,
      );

      if (!mounted) return;
      setState(() {
        _subiendoContrato = false;
        _contratoBytes = bytes;
        _tieneContrato = true;
        _nombreContrato = file.name;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            '¡Contrato de apadrinamiento subido con éxito! El usuario ya es padrino oficial.',
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

  Future<void> _eliminarContrato() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(child: Text('Eliminar Contrato')),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este contrato de apadrinamiento? El usuario dejará de tener el contrato disponible hasta que subas uno nuevo.',
          style: TextStyle(fontSize: 14.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmacion != true) return;

    setState(() => _subiendoContrato = true);
    try {
      await ApadrinamientoService.eliminarContrato(widget.solicitud.id);
      if (!mounted) return;
      setState(() {
        _subiendoContrato = false;
        _contratoBytes = null;
        _tieneContrato = false;
        _nombreContrato = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Contrato de apadrinamiento eliminado con éxito.'),
        ),
      );
      widget.onCambioEstado('aprobada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _subiendoContrato = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al eliminar contrato: $e'),
        ),
      );
    }
  }

  Future<void> _verDetallesMascota() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final pet = await PetsService.obtener(widget.solicitud.idMascota);
      if (!mounted) return;
      Navigator.pop(context); // cerrar diálogo de espera
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PetDetailScreen(pet: pet),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la mascota: $e')),
      );
    }
  }

  Future<void> _aprobar() async {
    DateTime fechaSeleccionada = DateTime.now();
    final observacionCtrl = TextEditingController();

    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Expanded(child: Text('Aprobar Apadrinamiento')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Confirmas la aprobación para que ${widget.solicitud.solicitanteNombreCompleto} sea padrino de ${widget.solicitud.mascotaNombre}?',
                  style: const TextStyle(height: 1.35),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Fecha oficial de inicio del apadrinamiento:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, color: AppColors.rosa),
                  label: Text(
                    '${fechaSeleccionada.year}-${fechaSeleccionada.month.toString().padLeft(2, '0')}-${fechaSeleccionada.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final elegida = await showDatePicker(
                      context: context,
                      initialDate: fechaSeleccionada,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (elegida != null) {
                      setDialogState(() => fechaSeleccionada = elegida);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Observaciones para el padrino (opcional):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: observacionCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Escribe aquí cualquier indicación o recomendación...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Al aprobar, deberás subir el contrato de apadrinamiento para formalizar el proceso.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar Aprobación'),
            ),
          ],
        ),
      ),
    );

    if (confirmacion != true) return;

    setState(() => _procesando = true);
    try {
      final fechaStr =
          '${fechaSeleccionada.year}-${fechaSeleccionada.month.toString().padLeft(2, '0')}-${fechaSeleccionada.day.toString().padLeft(2, '0')}';
      await ApadrinamientoService.actualizarEstado(
        idSolicitud: widget.solicitud.id,
        estado: 'aprobada',
        fechaInicio: fechaStr,
        observaciones: observacionCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('¡Solicitud aprobada! Ahora puedes adjuntar el contrato.'),
        ),
      );
      widget.onCambioEstado('aprobada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
      );
    }
  }

  Future<void> _rechazar() async {
    final motivoCtrl = TextEditingController();
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar Solicitud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indica el motivo por el cual se rechaza la solicitud de ${widget.solicitud.solicitanteNombreCompleto}:',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: motivoCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Motivo del rechazo u observaciones...',
                border: OutlineInputBorder(),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmacion != true) return;

    setState(() => _procesando = true);
    try {
      await ApadrinamientoService.actualizarEstado(
        idSolicitud: widget.solicitud.id,
        estado: 'rechazada',
        observaciones: motivoCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('La solicitud ha sido rechazada.'),
        ),
      );
      widget.onCambioEstado('rechazada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
      );
    }
  }

  Future<void> _cancelarApadrinamiento() async {
    final motivoCtrl = TextEditingController();
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(child: Text('Cancelar Apadrinamiento')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Confirmas la cancelación del apadrinamiento de ${widget.solicitud.solicitanteNombreCompleto} para ${widget.solicitud.mascotaNombre}?',
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 14),
              const Text(
                'Motivo de cancelación (obligatorio para el usuario):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: motivoCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Explica el motivo por el cual se cancela el apadrinamiento...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Este comentario se guardará en la base de datos y se mostrará al usuario en sus apadrinamientos.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (motivoCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text('Por favor escribe el motivo de cancelación.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirmar Cancelación'),
          ),
        ],
      ),
    );

    if (confirmacion != true) return;

    setState(() => _procesando = true);
    try {
      await ApadrinamientoService.cancelarSolicitud(
        idSolicitud: widget.solicitud.id,
        motivo: motivoCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('El apadrinamiento ha sido cancelado con éxito.'),
        ),
      );
      widget.onCambioEstado('cancelada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final t = Theme.of(context).textTheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
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
                    'Detalle de la Solicitud',
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                // Mascota que desea apadrinar
                _SeccionTarjeta(
                  titulo: 'Mascota a apadrinar',
                  icono: Icons.pets,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.rosa, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: PetImage(url: s.mascotaFotos),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.mascotaNombre,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                            color: AppColors.texto,
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
                            s.mascotaEdadTexto,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.rosa,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${s.mascotaEspecie} • ${s.mascotaRaza.isEmpty ? 'Mestizo' : s.mascotaRaza}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.rosa,
                            side: const BorderSide(color: AppColors.rosa),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.pets, size: 18),
                          label: Text('Ver perfil completo de ${s.mascotaNombre}'),
                          onPressed: _verDetallesMascota,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Solicitante y datos de contacto
                _SeccionTarjeta(
                  titulo: 'Datos del solicitante',
                  icono: Icons.person,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FilaInfo('Nombre completo', s.solicitanteNombreCompleto),
                      _FilaInfo('Correo electrónico', s.solicitanteCorreo),
                      _FilaInfo(
                        'Teléfono de contacto',
                        s.solicitanteTelefono.isEmpty
                            ? 'No especificado'
                            : s.solicitanteTelefono,
                      ),
                      _FilaInfo(
                        'Dirección',
                        s.solicitanteDireccion.isEmpty
                            ? 'No especificada'
                            : s.solicitanteDireccion,
                      ),
                      if (s.solicitanteCedula.isNotEmpty)
                        _FilaInfo(
                          'Número de Cédula (Perfil)',
                          s.solicitanteCedula,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // MOTIVACIÓN OBLIGATORIA COMPLETA
                _SeccionTarjeta(
                  titulo: '¿Por qué quiere apadrinar a esta mascota?',
                  icono: Icons.favorite,
                  colorFondo: AppColors.rosaClaro.withOpacity(0.35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Respuesta completa del solicitante:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.rosa,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        s.motivacion,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // DOCUMENTO DE IDENTIDAD (ACCESO SEGURO)
                _SeccionTarjeta(
                  titulo: 'Documento de identidad oficial (Privado)',
                  icono: Icons.verified_user,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_cargandoDoc)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_errorDoc != null)
                        Text(
                          'No se pudo cargar el documento: $_errorDoc',
                          style: const TextStyle(color: Colors.redAccent),
                        )
                      else if (_docBytes != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _docBytes!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.rosa,
                              side: const BorderSide(color: AppColors.rosa),
                            ),
                            icon: const Icon(Icons.fullscreen),
                            label: const Text(
                              'Ver documento en pantalla completa',
                            ),
                            onPressed: _verDocumentoCompleto,
                          ),
                        ),
                      ] else
                        const Text('No se encontró archivo adjunto.'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // SECCIÓN DE CONTRATO DE APADRINAMIENTO (ADMIN)
                 if (s.esAprobada) ...[
                   _SeccionTarjeta(
                     titulo: 'Contrato de apadrinamiento',
                     icono: Icons.assignment_outlined,
                     colorFondo: _tieneContrato || _contratoBytes != null
                         ? Colors.green.shade50.withOpacity(0.5)
                         : Colors.amber.shade50.withOpacity(0.5),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         if (_subiendoContrato)
                           const Center(
                             child: Padding(
                               padding: EdgeInsets.all(16),
                               child: Column(
                                 children: [
                                   CircularProgressIndicator(),
                                   SizedBox(height: 8),
                                   Text('Procesando contrato de apadrinamiento...'),
                                 ],
                               ),
                             ),
                           )
                         else if (_tieneContrato || _contratoBytes != null) ...[
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
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(
                                         'Contrato de apadrinamiento subido',
                                         style: TextStyle(
                                           fontWeight: FontWeight.bold,
                                           color: Colors.green,
                                         ),
                                       ),
                                       Text(
                                         'El usuario ya es oficialmente el padrino de la mascota.',
                                         style: TextStyle(
                                           fontSize: 12,
                                           color: Colors.black87,
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),
                               ],
                             ),
                           ),
                           const SizedBox(height: 12),
                           if (_cargandoContrato)
                             const Center(
                               child: Padding(
                                 padding: EdgeInsets.all(12),
                                 child: CircularProgressIndicator(),
                               ),
                             )
                           else if (_errorContrato != null)
                             Padding(
                               padding: const EdgeInsets.symmetric(vertical: 8),
                               child: Text(
                                 'Error al cargar contrato: $_errorContrato',
                                 style: const TextStyle(
                                   color: Colors.redAccent,
                                   fontSize: 12,
                                 ),
                               ),
                             )
                           else if (_contratoBytes != null) ...[
                             if (_esBytesPdf(_contratoBytes!))
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
                                     Container(
                                       padding: const EdgeInsets.all(10),
                                       decoration: BoxDecoration(
                                         color: Colors.red.shade100,
                                         borderRadius: BorderRadius.circular(10),
                                       ),
                                       child: const Icon(
                                         Icons.picture_as_pdf,
                                         color: Colors.redAccent,
                                         size: 32,
                                       ),
                                     ),
                                     const SizedBox(width: 12),
                                     Expanded(
                                       child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Text(
                                             _nombreContrato ?? 'Contrato_Apadrinamiento.pdf',
                                             style: const TextStyle(
                                               fontWeight: FontWeight.bold,
                                               fontSize: 13,
                                             ),
                                             maxLines: 1,
                                             overflow: TextOverflow.ellipsis,
                                           ),
                                           Text(
                                             'Documento PDF (${(_contratoBytes!.length / 1024).toStringAsFixed(1)} KB)',
                                             style: TextStyle(
                                               color: Colors.grey.shade600,
                                               fontSize: 11.5,
                                             ),
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
                             Row(
                               children: [
                                 Expanded(
                                   child: OutlinedButton.icon(
                                     style: OutlinedButton.styleFrom(
                                       foregroundColor: AppColors.rosa,
                                       side: const BorderSide(color: AppColors.rosa),
                                       padding: const EdgeInsets.symmetric(vertical: 10),
                                     ),
                                     icon: const Icon(Icons.visibility, size: 18),
                                     label: const Text('Ver'),
                                     onPressed: _verContratoCompleto,
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 Expanded(
                                   child: OutlinedButton.icon(
                                     style: OutlinedButton.styleFrom(
                                       foregroundColor: Colors.grey.shade800,
                                       side: BorderSide(color: Colors.grey.shade400),
                                       padding: const EdgeInsets.symmetric(vertical: 10),
                                     ),
                                     icon: const Icon(Icons.upload_file, size: 18),
                                     label: const Text('Reemplazar'),
                                     onPressed: _subirContrato,
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 Expanded(
                                   child: OutlinedButton.icon(
                                     style: OutlinedButton.styleFrom(
                                       foregroundColor: Colors.redAccent,
                                       side: const BorderSide(color: Colors.redAccent),
                                       padding: const EdgeInsets.symmetric(vertical: 10),
                                     ),
                                     icon: const Icon(Icons.delete_outline, size: 18),
                                     label: const Text('Eliminar'),
                                     onPressed: _eliminarContrato,
                                   ),
                                 ),
                               ],
                             ),
                           ] else ...[
                             Row(
                               children: [
                                 Expanded(
                                   child: FilledButton.icon(
                                     style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                                     icon: const Icon(Icons.visibility),
                                     label: const Text('Cargar y ver contrato'),
                                     onPressed: _cargarContratoSeguro,
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 IconButton(
                                   tooltip: 'Eliminar contrato',
                                   icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                   onPressed: _eliminarContrato,
                                 ),
                               ],
                             ),
                           ],
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
                                     'Paso pendiente: El apadrinamiento fue aprobado pero el usuario aún no es padrino oficial hasta que subas el contrato firmado (JPG, PNG o PDF).',
                                     style: TextStyle(
                                       fontSize: 12.5,
                                       fontWeight: FontWeight.w600,
                                       color: Colors.amber.shade900,
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
                                 shape: RoundedRectangleBorder(
                                   borderRadius: BorderRadius.circular(12),
                                 ),
                               ),
                               icon: const Icon(Icons.upload_file),
                               label: const Text(
                                 'Subir Contrato (JPG, PNG o PDF)',
                                 style: TextStyle(fontWeight: FontWeight.bold),
                               ),
                               onPressed: _subirContrato,
                             ),
                           ),
                         ],
                       ],
                     ),
                   ),
                   const SizedBox(height: 14),
                 ],

                // SI ESTÁ CANCELADA, MOSTRAR MOTIVO
                if (s.esCancelada) ...[
                  _SeccionTarjeta(
                    titulo: 'Apadrinamiento Cancelado',
                    icono: Icons.highlight_off,
                    colorFondo: Colors.red.shade50.withOpacity(0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Motivo de cancelación registrado en base de datos:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            s.observaciones?.trim().isNotEmpty == true
                                ? s.observaciones!
                                : 'Sin motivo especificado.',
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                        if (s.fechaActualizacionEstado != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Fecha de cancelación: ${s.fechaActualizacionEstado}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // SI ESTÁ RECHAZADA, MOSTRAR VECES RECHAZADA Y OBSERVACIONES
                if (s.esRechazada) ...[
                  _SeccionTarjeta(
                    titulo: 'Solicitud Rechazada',
                    icono: Icons.cancel_outlined,
                    colorFondo: Colors.red.shade50.withOpacity(0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.replay, size: 16, color: Colors.red.shade900),
                              const SizedBox(width: 6),
                              Text(
                                'Esta solicitud ha sido rechazada ${s.vecesRechazada} ${s.vecesRechazada == 1 ? 'vez' : 'veces'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Motivo del rechazo u observaciones:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            s.observaciones?.trim().isNotEmpty == true
                                ? s.observaciones!
                                : 'Sin motivo especificado.',
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                        if (s.fechaActualizacionEstado != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Fecha de rechazo: ${s.fechaActualizacionEstado}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ACUERDO DE RESPONSABILIDAD
                _SeccionTarjeta(
                  titulo: 'Acuerdo de responsabilidad',
                  icono: Icons.gavel,
                  child: Row(
                    children: [
                      Icon(
                        s.acuerdoResponsabilidad
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: s.acuerdoResponsabilidad
                            ? Colors.green
                            : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.acuerdoResponsabilidad
                                  ? 'Aceptado explícitamente por el solicitante'
                                  : 'No aceptado',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: s.acuerdoResponsabilidad
                                    ? Colors.green.shade800
                                    : Colors.red,
                              ),
                            ),
                            if (s.fechaAcuerdoResponsabilidad != null)
                              Text(
                                'Fecha de aceptación: ${s.fechaAcuerdoResponsabilidad}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Fechas y Aporte
                _SeccionTarjeta(
                  titulo: 'Detalles del apadrinamiento',
                  icono: Icons.info_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FilaInfo('Fecha de envío de solicitud', s.fechaSolicitud),
                      _FilaInfo(
                        'Estado de la solicitud',
                        s.estado.toUpperCase(),
                      ),
                      if (s.esRechazada)
                        _FilaInfo(
                          'Veces rechazada',
                          '${s.vecesRechazada} ${s.vecesRechazada == 1 ? 'vez' : 'veces'}',
                        ),
                      if (s.fechaInicioApadrinamiento != null)
                        _FilaInfo(
                          'Fecha de inicio oficial',
                          s.fechaInicioApadrinamiento!,
                        ),
                      if (s.fechaActualizacionEstado != null)
                        _FilaInfo(
                          'Fecha de revisión',
                          s.fechaActualizacionEstado!,
                        ),
                      if (s.montoAporte != null)
                        _FilaInfo(
                          'Aporte voluntario',
                          '\$${s.montoAporte} COP (${s.frecuenciaAporte})',
                        ),
                      if (s.observaciones != null && s.observaciones!.isNotEmpty)
                        _FilaInfo('Observaciones / Motivo', s.observaciones!),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Botones de acción si es pendiente
                if (s.esPendiente) ...[
                  if (_procesando)
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Rechazar'),
                            onPressed: _rechazar,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Aprobar'),
                            onPressed: _aprobar,
                          ),
                        ),
                      ],
                    ),
                ],

                // Botón para CANCELAR si ya está aprobada
                if (s.esAprobada) ...[
                  if (_procesando)
                    const Center(child: CircularProgressIndicator())
                  else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text(
                        'Cancelar Apadrinamiento',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _cancelarApadrinamiento,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccionTarjeta extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;
  final Color? colorFondo;

  const _SeccionTarjeta({
    required this.titulo,
    required this.icono,
    required this.child,
    this.colorFondo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorFondo ?? Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: AppColors.rosa),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
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

class _FilaInfo extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _FilaInfo(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              '$etiqueta:',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
