import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Detalle de una solicitud: respuestas, documentos y decisión del administrador.
class AdoptionDetailAdminScreen extends StatefulWidget {
  final AdoptionRequest request;

  const AdoptionDetailAdminScreen({super.key, required this.request});

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

  Future<void> _decidir(String estado) async {
    final aprobar = estado == 'aprobada';
    final s = widget.request;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(aprobar ? 'Aprobar adopción' : 'Rechazar solicitud'),
        content: Text(
          aprobar
              ? '¿Confirmas que ${s.applicantFullName} adoptará a ${s.petName}? La mascota quedará marcada como adoptada.'
              : '¿Rechazas la solicitud de ${s.applicantFullName} para adoptar a ${s.petName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: aprobar ? Colors.green : Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(aprobar ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _procesando = true);
    try {
      await AdoptionService.updateStatus(id: s.id, status: estado);
      if (!mounted) return;
      Navigator.pop(context, estado);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      final mensaje = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text(mensaje)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.request;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la solicitud')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      children: [
                        _Seccion(
                          titulo: 'Mascota',
                          icono: Icons.pets,
                          child: Row(
                            children: [
                              ClipOval(
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: PetImage(url: s.petPhoto),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.petName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(s.petSummary),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Seccion(
                          titulo: 'Datos del solicitante',
                          icono: Icons.person_outline,
                          child: Column(
                            children: [
                              _Dato('Nombre', s.applicantFullName),
                              _Dato('Correo', _vacio(s.applicantEmail)),
                              _Dato('Teléfono', _vacio(s.applicantPhone)),
                              _Dato('Dirección', _vacio(s.applicantAddress)),
                              _Dato(
                                'Cédula en el perfil',
                                _vacio(s.applicantIdNumber),
                              ),
                              _Dato('Estado', s.statusLabel),
                              _Dato('Enviada', s.requestedAtLabel),
                              if (s.statusUpdatedAtLabel != null)
                                _Dato('Revisada', s.statusUpdatedAtLabel!),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Seccion(
                          titulo: 'Respuestas del formulario',
                          icono: Icons.quiz_outlined,
                          child: Column(
                            children: [
                              for (final respuesta in s.answers) ...[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    respuesta.question,
                                    style: const TextStyle(
                                      color: AppColors.rosa,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: SelectableText(
                                    respuesta.answer,
                                    style: const TextStyle(height: 1.4),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (s.isPending) _acciones(),
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
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _verCompleta(bytes, titulo),
          icon: const Icon(Icons.fullscreen),
          label: const Text('Ver en pantalla completa'),
        ),
      ],
    );
  }

  Widget _acciones() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: _procesando
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () => _decidir('rechazada'),
                      icon: const Icon(Icons.close),
                      label: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () => _decidir('aprobada'),
                      icon: const Icon(Icons.check),
                      label: const Text('Aprobar'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _vacio(String valor) => valor.trim().isEmpty ? 'No registrado' : valor;
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;

  const _Seccion({
    required this.titulo,
    required this.icono,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
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
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              etiqueta,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
