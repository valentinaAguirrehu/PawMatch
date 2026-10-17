import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/widgets/pet_card.dart';

class ApadrinamientoAdminScreen extends StatefulWidget {
  const ApadrinamientoAdminScreen({super.key});

  @override
  State<ApadrinamientoAdminScreen> createState() =>
      _ApadrinamientoAdminScreenState();
}

class _ApadrinamientoAdminScreenState extends State<ApadrinamientoAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 3, vsync: this);
  late Future<List<SolicitudApadrinamiento>> _future = _cargar();

  @override
  void initState() {
    super.initState();
    ApadrinamientoService.marcarLeidasAdmin();
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
          tabs: const [
            Tab(icon: Icon(Icons.mark_email_unread_outlined), text: 'Nuevas'),
            Tab(icon: Icon(Icons.check_circle_outline), text: 'Aprobadas'),
            Tab(icon: Icon(Icons.cancel_outlined), text: 'Rechazadas'),
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
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargarDocumentoSeguro();
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
                  'Se enviará un correo y una notificación en la app al solicitante.',
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
          content: Text('¡Solicitud aprobada y notificación enviada con éxito!'),
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

                // MOTIVACIÓN OBLIGATORIA COMPLETA (SIN TRUNCAR)
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

                // Botones de acción (solo si es pendiente)
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
