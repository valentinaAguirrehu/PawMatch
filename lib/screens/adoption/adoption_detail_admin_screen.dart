import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Detalle de una solicitud de adopción, con la misma revisión que Apadrinamiento.
class AdoptionDetailAdminScreen extends StatefulWidget {
  final AdoptionRequest request;
  final ValueChanged<String> onCambioEstado;

  const AdoptionDetailAdminScreen({
    super.key,
    required this.request,
    required this.onCambioEstado,
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
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
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

  void _verCompleta(Uint8List bytes, String titulo) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(titulo),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _aprobar() async {
    DateTime fechaSeleccionada = DateTime.now();
    final observacionCtrl = TextEditingController();
    final s = widget.request;

    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Expanded(child: Text('Aprobar adopción')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Confirmas que ${s.applicantFullName} adoptará a ${s.petName}? La mascota quedará marcada como adoptada.',
                  style: const TextStyle(height: 1.35),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Fecha oficial de inicio de la adopción:',
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
                  'Observaciones para el adoptante (opcional):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: observacionCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Indicaciones, requisitos o recomendaciones...',
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
              child: const Text('Confirmar aprobación'),
            ),
          ],
        ),
      ),
    );

    if (confirmacion != true) return;

    final fecha =
        '${fechaSeleccionada.year}-${fechaSeleccionada.month.toString().padLeft(2, '0')}-${fechaSeleccionada.day.toString().padLeft(2, '0')}';
    await _guardar(
      estado: 'aprobada',
      fechaInicio: fecha,
      observaciones: observacionCtrl.text.trim(),
      mensaje: '¡Solicitud aprobada y notificación enviada con éxito!',
      color: Colors.green,
    );
  }

  Future<void> _rechazar() async {
    final motivoCtrl = TextEditingController();
    final s = widget.request;
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indica el motivo por el cual se rechaza la solicitud de ${s.applicantFullName}:',
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
            const SizedBox(height: 8),
            const Text(
              'El solicitante verá este mensaje en su notificación y en el detalle.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
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
    await _guardar(
      estado: 'rechazada',
      observaciones: motivoCtrl.text.trim(),
      mensaje: 'La solicitud ha sido rechazada.',
      color: Colors.orange,
    );
  }

  Future<void> _guardar({
    required String estado,
    required String mensaje,
    required Color color,
    String? fechaInicio,
    String? observaciones,
  }) async {
    setState(() => _procesando = true);
    try {
      await AdoptionService.updateStatus(
        id: widget.request.id,
        status: estado,
        startDate: fechaInicio,
        observations: observaciones,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: color, content: Text(mensaje)),
      );
      widget.onCambioEstado(estado);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      final texto = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text(texto)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.request;
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                _Seccion(
                  titulo: 'Mascota a adoptar',
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
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Seccion(
                  titulo: 'Datos del solicitante',
                  icono: Icons.person,
                  child: Column(
                    children: [
                      _Dato('Nombre completo', s.applicantFullName),
                      _Dato('Correo electrónico', _vacio(s.applicantEmail)),
                      _Dato('Teléfono de contacto', _vacio(s.applicantPhone)),
                      _Dato('Dirección', _vacio(s.applicantAddress)),
                      if (s.applicantIdNumber.trim().isNotEmpty)
                        _Dato('Número de cédula (perfil)', s.applicantIdNumber),
                    ],
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
                  titulo: 'Foto de la cédula (privado)',
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
                  titulo: 'Recibo de servicio público (privado)',
                  icono: Icons.receipt_long_outlined,
                  child: _vistaFoto(
                    cargando: _cargandoRecibo,
                    error: _errorRecibo,
                    bytes: _recibo,
                    titulo: 'Recibo de servicio público',
                  ),
                ),
                const SizedBox(height: 14),
                _Seccion(
                  titulo: 'Detalles de la adopción',
                  icono: Icons.info_outline,
                  child: Column(
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
                const SizedBox(height: 24),
                if (s.isPending) ...[
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
                            onPressed: _rechazar,
                            icon: const Icon(Icons.close),
                            label: const Text('Rechazar'),
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
                            onPressed: _aprobar,
                            icon: const Icon(Icons.check),
                            label: const Text('Aprobar'),
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
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.rosa,
            side: const BorderSide(color: AppColors.rosa),
          ),
          onPressed: () => _verCompleta(bytes, titulo),
          icon: const Icon(Icons.fullscreen),
          label: const Text('Ver documento en pantalla completa'),
        ),
      ],
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

  const _Dato(this.etiqueta, this.valor);

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
