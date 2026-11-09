import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/seguimiento_adopcion_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Formulario para cancelar una adopción y devolver la mascota a disponible.
class CancelacionAdopcionForm extends StatefulWidget {
  final String idSolicitud;
  final String nombreMascota;
  final String? fotoMascota;
  final String adoptanteNombre;
  final String inicioTexto;
  // ignore: unused_field
  final int totalSeguimientos;
  final VoidCallback? onGuardadoExitoso;

  const CancelacionAdopcionForm({
    super.key,
    required this.idSolicitud,
    required this.nombreMascota,
    this.fotoMascota,
    required this.adoptanteNombre,
    required this.inicioTexto,
    required this.totalSeguimientos,
    this.onGuardadoExitoso,
  });

  @override
  State<CancelacionAdopcionForm> createState() => _CancelacionAdopcionFormState();
}

class _CancelacionAdopcionFormState extends State<CancelacionAdopcionForm> {
  final _formKey = GlobalKey<FormState>();
  final _observacionCtrl = TextEditingController();

  static const _motivos = [
    'Incumplimiento del contrato de adopción',
    'Problemas de comportamiento del adoptante',
    'Negligencia o falta de cuidado básico',
    'Abandono o desinterés por parte del adoptante',
    'Presunto maltrato animal',
    'Cambio imprevisto en la situación familiar o económica',
    'Otro',
  ];

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  DateTime _fecha = DateTime.now();
  String? _motivo;
  bool _inhabilitar = false;
  bool _guardando = false;
  Uint8List? _foto1;
  String? _nombreFoto1;
  Uint8List? _foto2;
  String? _nombreFoto2;

  @override
  void dispose() {
    _observacionCtrl.dispose();
    super.dispose();
  }

  String _fechaTexto(DateTime fecha) => '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(ahora.year - 2),
      lastDate: ahora,
      helpText: 'Fecha de cancelación',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (elegida == null || !mounted) return;
    setState(() => _fecha = elegida);
  }

  Future<void> _elegirFoto({required bool primera, required ImageSource origen}) async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: origen,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (archivo == null || !mounted) return;
      final bytes = await archivo.readAsBytes();
      if (!mounted) return;
      final nombre = archivo.name.trim().isEmpty ? 'evidencia.jpg' : archivo.name;
      setState(() {
        if (primera) {
          _foto1 = bytes;
          _nombreFoto1 = nombre;
        } else {
          _foto2 = bytes;
          _nombreFoto2 = nombre;
        }
      });
    } catch (_) {
      if (!mounted) return;
      _aviso(
        origen == ImageSource.camera
            ? 'No se pudo abrir la cámara. Revisa el permiso o elige la foto desde la galería.'
            : 'No se pudo abrir la imagen.',
      );
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _guardando) return;
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar adopción'),
        content: Text(
          'Una vez cancele la adopción no puede deshacer esta acción y ${widget.nombreMascota} vuelve a estar en estado disponible para buscar una nueva familia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (aceptar != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      final res = await SeguimientoAdopcionService.cancelarAdopcion(
        idSolicitud: widget.idSolicitud,
        fechaCancelacion: _fecha,
        motivo: _motivo!,
        observacion: _observacionCtrl.text,
        inhabilitarCuenta: _inhabilitar,
        foto1: _foto1,
        nombreFoto1: _nombreFoto1,
        foto2: _foto2,
        nombreFoto2: _nombreFoto2,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.rosa,
          content: Text(res['mensaje']?.toString() ?? 'Adopción cancelada'),
        ),
      );
      final alGuardar = widget.onGuardadoExitoso;
      Navigator.of(context).pop();
      alGuardar?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (!confirmar || !mounted) return;
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    Session.cerrar();
    Navegacion.ir(context, const WelcomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            BarraSuperior(
              iconoTitulo: Icons.heart_broken_rounded,
              titulo: 'Cancelar adopción',
              onCerrarSesion: _confirmarCerrarSesion,
              onVolver: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _fichaMascota(),
                    const SizedBox(height: 16),
                    _FechaCampo(
                      etiqueta: 'Fecha de cancelación',
                      valor: _fechaTexto(_fecha),
                      onTap: _elegirFecha,
                    ),
                    const SizedBox(height: 14),
                    FormField<String>(
                      initialValue: _motivo,
                      validator: (valor) => valor == null ? 'Selecciona un motivo' : null,
                      builder: (campo) => _MenuMotivo(
                        motivos: _motivos,
                        valor: campo.value,
                        error: campo.errorText,
                        onSelected: (motivo) {
                          campo.didChange(motivo);
                          setState(() => _motivo = motivo);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _observacionCtrl,
                      minLines: 4,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoracion('Observación').copyWith(
                        alignLabelWithHint: true,
                        hintText: 'Explica con detalle por qué se cancela esta adopción.',
                      ),
                      validator: (valor) {
                        if (valor == null || valor.trim().length < 10) {
                          return 'Explica el motivo con más detalle';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Anexar fotografías',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.texto),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Puedes adjuntar hasta 2 fotos como evidencia. Es opcional.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    _FotoEvidencia(
                      titulo: 'Fotografía 1',
                      bytes: _foto1,
                      onGaleria: () => _elegirFoto(primera: true, origen: ImageSource.gallery),
                      onCamara: () => _elegirFoto(primera: true, origen: ImageSource.camera),
                      onQuitar: () => setState(() {
                        _foto1 = null;
                        _nombreFoto1 = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    _FotoEvidencia(
                      titulo: 'Fotografía 2',
                      bytes: _foto2,
                      onGaleria: () => _elegirFoto(primera: false, origen: ImageSource.gallery),
                      onCamara: () => _elegirFoto(primera: false, origen: ImageSource.camera),
                      onQuitar: () => setState(() {
                        _foto2 = null;
                        _nombreFoto2 = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _inhabilitar,
                      onChanged: _guardando ? null : (valor) => setState(() => _inhabilitar = valor ?? false),
                      activeColor: AppColors.rosa,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Inhabilitar la cuenta del adoptante',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: const Text('Si la marcas, el adoptante no podrá volver a ingresar.'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosa,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _guardando ? null : _guardar,
                      child: Text(
                        _guardando ? 'Guardando...' : 'Guardar',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fichaMascota() {
    final inicio = widget.inicioTexto.trim().isEmpty ? 'Sin fecha' : widget.inicioTexto.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 64, height: 64, child: PetImage(url: widget.fotoMascota)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.nombreMascota, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  'Adoptante: ${widget.adoptanteNombre}',
                  style: const TextStyle(fontSize: 13, color: AppColors.texto),
                ),
                Text(
                  'Inicio: $inicio',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Finalización de adopción',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.rosa),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoracion(String etiqueta) {
    return InputDecoration(
      labelText: etiqueta,
      filled: true,
      fillColor: AppColors.rosaSuave,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _MenuMotivo extends StatefulWidget {
  final List<String> motivos;
  final String? valor;
  final String? error;
  final ValueChanged<String> onSelected;

  const _MenuMotivo({
    required this.motivos,
    required this.valor,
    required this.error,
    required this.onSelected,
  });

  @override
  State<_MenuMotivo> createState() => _MenuMotivoState();
}

class _MenuMotivoState extends State<_MenuMotivo> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _abierto = !_abierto),
          child: InputDecorator(
            isEmpty: widget.valor == null,
            decoration: InputDecoration(
              labelText: 'Motivo',
              filled: true,
              fillColor: AppColors.rosaSuave,
              errorText: widget.error,
              suffixIcon: Icon(
                _abierto ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: AppColors.rosa,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              widget.valor ?? '',
              style: const TextStyle(fontSize: 14, color: AppColors.texto),
            ),
          ),
        ),
        if (_abierto)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: AppColors.rosa.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.bordeRosa, width: 1.4),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < widget.motivos.length; i++) ...[
                      if (i > 0) const ColoredBox(color: AppColors.rosaClaro, child: SizedBox(height: 7)),
                      InkWell(
                        onTap: () {
                          widget.onSelected(widget.motivos[i]);
                          setState(() => _abierto = false);
                        },
                        child: Container(
                          width: double.infinity,
                          color: widget.valor == widget.motivos[i] ? AppColors.rosaSuave : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Text(
                            widget.motivos[i],
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.3,
                              fontWeight: widget.valor == widget.motivos[i] ? FontWeight.w700 : FontWeight.w500,
                              color: widget.valor == widget.motivos[i] ? AppColors.rosa : AppColors.texto,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FechaCampo extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final VoidCallback onTap;

  const _FechaCampo({
    required this.etiqueta,
    required this.valor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.rosaSuave,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: AppColors.rosa, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etiqueta, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    Text(valor, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.texto)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FotoEvidencia extends StatelessWidget {
  final String titulo;
  final Uint8List? bytes;
  final VoidCallback onGaleria;
  final VoidCallback onCamara;
  final VoidCallback onQuitar;

  const _FotoEvidencia({
    required this.titulo,
    required this.bytes,
    required this.onGaleria,
    required this.onCamara,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0E5EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (bytes != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes!, height: 140, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                onPressed: onGaleria,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(bytes == null ? 'Galería' : 'Cambiar'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rosa,
                  side: const BorderSide(color: AppColors.rosa),
                ),
                onPressed: onCamara,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Tomar foto'),
              ),
              if (bytes != null) TextButton(onPressed: onQuitar, child: const Text('Quitar')),
            ],
          ),
        ],
      ),
    );
  }
}
