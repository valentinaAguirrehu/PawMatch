import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/services/acuerdo_apadrinamiento_pdf_service.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/pet_card.dart';

class SolicitudApadrinamientoDialog extends StatefulWidget {
  final Pet pet;
  final VoidCallback? onEnviadaExitosamente;

  const SolicitudApadrinamientoDialog({
    super.key,
    required this.pet,
    this.onEnviadaExitosamente,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required Pet pet,
    VoidCallback? onEnviadaExitosamente,
  }) {
    if (pet.estaAdoptada) {
      return showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(
            pet.mensajeFamiliaPara(Session.idUsuario),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.rosa,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SolicitudApadrinamientoDialog(
        pet: pet,
        onEnviadaExitosamente: onEnviadaExitosamente,
      ),
    );
  }

  @override
  State<SolicitudApadrinamientoDialog> createState() =>
      _SolicitudApadrinamientoDialogState();
}

class _SolicitudApadrinamientoDialogState
    extends State<SolicitudApadrinamientoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _motivacionCtrl = TextEditingController();
  final _montoCtrl = TextEditingController(text: '30000');
  final _correoCtrl = TextEditingController(text: Session.correo);
  String _frecuencia = 'mensual';

  int _paso = 0;
  Uint8List? _docBytes;
  String? _docNombre;

  bool _aceptoAcuerdo = false;
  bool _enviando = false;
  bool _correoPerfilConfirmado = true;
  bool _actualizandoCorreo = false;

  @override
  void dispose() {
    _motivacionCtrl.dispose();
    _montoCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarDocumento() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _docBytes = bytes;
          _docNombre = picked.name;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la imagen: $e')),
      );
    }
  }

  /// Muestra el texto breve, claro y completo del acuerdo en un diálogo modal responsive.
  void _verTerminosAcuerdo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.rosaSuave,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.handshake_outlined, color: AppColors.rosa, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acuerdo de Compromiso',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    'Fundación Maritza Arévalo',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Al solicitar el apadrinamiento de ${widget.pet.nombre}, aceptas libre y voluntariamente los siguientes puntos:',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                ...AcuerdoApadrinamientoPdfService.clausulasAcuerdo.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.rosaSuave,
                          child: Text(
                            c['num']!,
                            style: const TextStyle(
                              color: AppColors.rosa,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.black87,
                                    height: 1.38,
                                  ),
                              children: [
                                TextSpan(
                                  text: '${c['titulo']}: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: c['cuerpo']),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_outlined, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Al confirmar, el sistema registrará tu constancia electrónica y generará el PDF descargable.',
                          style: TextStyle(fontSize: 11.5, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rosa,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _continuar() {
    if (_paso == 0) {
      if (!_formKey.currentState!.validate()) return;
      setState(() => _paso = 1);
    } else if (_paso == 1) {
      if (_docBytes == null || _docNombre == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Por favor, adjunta la fotografía de tu documento de identidad.',
            ),
          ),
        );
        return;
      }
      setState(() => _paso = 2);
    }
  }

  /// Valida los requisitos y ejecuta el envío de la solicitud
  Future<void> _solicitarConfirmacionCorreoYEnviar() async {
    if (widget.pet.estaAdoptada) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.pet.mensajeFamiliaPara(Session.idUsuario)),
        ),
      );
      return;
    }

    if (!_aceptoAcuerdo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Debes aceptar el acuerdo de responsabilidad para continuar.',
          ),
        ),
      );
      return;
    }

    if (_docBytes == null || _docNombre == null) {
      setState(() => _paso = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Por favor, adjunta la fotografía de tu documento de identidad.',
          ),
        ),
      );
      return;
    }

    final correoFinal = _correoCtrl.text.trim();
    if (correoFinal.isEmpty || !correoFinal.contains('@') || !correoFinal.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Por favor, verifica que tu correo electrónico sea válido.',
          ),
        ),
      );
      return;
    }

    if (!_correoPerfilConfirmado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text(
            'Por favor confirma tu correo electrónico en la sección inferior.',
          ),
        ),
      );
      return;
    }

    await _ejecutarEnvioFinal(correoFinal);
  }

  /// Diálogo para editar el correo del perfil del usuario y persistirlo en la base de datos
  Future<void> _dialogoEditarCorreoPerfil() async {
    final nuevoCtrl = TextEditingController(text: _correoCtrl.text.trim());
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppColors.rosa, size: 28),
              SizedBox(width: 10),
              Text('Editar Correo de tu Perfil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingresa tu correo correcto. Se actualizará en tu perfil de Paw Match y en la base de datos para que recibas allí todas tus notificaciones:',
                  style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nuevoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nuevo correo electrónico *',
                    labelStyle: const TextStyle(color: AppColors.rosa),
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.rosa),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.rosa, width: 2),
                    ),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'El correo es obligatorio';
                    if (!t.contains('@') || !t.contains('.')) return 'Ingresa un correo electrónico válido';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _actualizandoCorreo ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rosa,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _actualizandoCorreo
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final nuevo = nuevoCtrl.text.trim();
                      setModalState(() => _actualizandoCorreo = true);
                      setState(() => _actualizandoCorreo = true);

                      try {
                        if (Session.idUsuario != null && Session.idUsuario!.isNotEmpty) {
                          await ApiService.actualizarCorreoUsuario(
                            idUsuario: Session.idUsuario!,
                            nuevoCorreo: nuevo,
                          );
                        } else {
                          await Session.actualizarCorreo(nuevo);
                        }

                        if (!mounted) return;
                        setState(() {
                          _correoCtrl.text = nuevo;
                          _correoPerfilConfirmado = true;
                          _actualizandoCorreo = false;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.green,
                            content: Text('¡Correo actualizado en tu perfil y base de datos con éxito!'),
                          ),
                        );
                      } catch (e) {
                        setModalState(() => _actualizandoCorreo = false);
                        setState(() => _actualizandoCorreo = false);
                        final msg = e.toString().replaceFirst('Exception: ', '');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(backgroundColor: Colors.redAccent, content: Text(msg)),
                        );
                      }
                    },
              child: _actualizandoCorreo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Guardar y Actualizar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ejecutarEnvioFinal(String correoConfirmado) async {
    setState(() => _enviando = true);

    try {
      final monto = int.tryParse(_montoCtrl.text.replaceAll(RegExp(r'\D'), ''));
      final motivacion = _motivacionCtrl.text.trim();

      // 1. Enviar a base de datos en el backend (incluyendo el correo confirmado)
      final SolicitudApadrinamiento? solicitudCreada =
          await ApadrinamientoService.enviarSolicitud(
        idMascota: widget.pet.id,
        motivacion: motivacion,
        montoAporte: monto,
        frecuenciaAporte: _frecuencia,
        bytesDocumento: _docBytes!,
        nombreArchivo: _docNombre!,
        correoContacto: correoConfirmado,
      );

      final fechaAhora = DateTime.now();
      final idRadicado = solicitudCreada != null && solicitudCreada.id.isNotEmpty
          ? solicitudCreada.id
          : 'APAD-${fechaAhora.millisecondsSinceEpoch}';

      final nombreCompletoUsuario =
          '${Session.nombre} ${Session.apellidos}'.trim().isEmpty
              ? 'Usuario Registrado'
              : '${Session.nombre} ${Session.apellidos}'.trim();

      // Asegurar que el documento de identidad esté cargado
      if (Session.documentoIdentidad.trim().isEmpty && Session.idUsuario != null) {
        try {
          final u = await ApiService.obtenerUsuario(Session.idUsuario!);
          if (u.documentoIdentidad.trim().isNotEmpty) {
            Session.documentoIdentidad = u.documentoIdentidad.trim();
          }
        } catch (_) {}
      }

      // 2. Generar el PDF oficial del Acuerdo breve con datos reales
      final datosAcuerdo = DatosAcuerdoApadrinamiento(
        idSolicitud: idRadicado,
        nombreUsuario: nombreCompletoUsuario,
        documentoUsuario: Session.documentoIdentidad.trim().isNotEmpty
            ? Session.documentoIdentidad.trim()
            : null,
        correoUsuario: correoConfirmado.isNotEmpty ? correoConfirmado : (Session.correo.isNotEmpty ? Session.correo : 'No especificado'),
        telefonoUsuario: Session.telefono.isNotEmpty ? Session.telefono : null,
        nombreMascota: widget.pet.nombre,
        especieMascota: widget.pet.especie,
        razaMascota: widget.pet.raza,
        edadMascota: widget.pet.edadTexto,
        montoAporte: monto,
        frecuenciaAporte: _frecuencia,
        motivacion: motivacion,
        fechaAceptacion: fechaAhora,
      );

      final pdfBytes = await AcuerdoApadrinamientoPdfService.generarPdfBytes(datosAcuerdo);

      // 3. Descarga y guardado automático del PDF
      await AcuerdoApadrinamientoPdfService.descargarYGuardarPdf(
        bytes: pdfBytes,
        nombreMascota: widget.pet.nombre,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cierra bottom sheet

      widget.onEnviadaExitosamente?.call();

      // 4. Diálogo de confirmación con opción de volver a descargar
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          icon: const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 56,
          ),
          title: const Text(
            '¡Solicitud Enviada y Acuerdo Descargado!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tu solicitud para apadrinar a ${widget.pet.nombre} ha sido registrada exitosamente en la Fundación Maritza Arévalo.',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.4, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rosaSuave,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bordeRosa),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: AppColors.rosa, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Acuerdo en PDF generado',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          Text(
                            'Se descargó el comprobante con tu constancia de aceptación electrónica.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mail_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notificación: Te llegará un correo a $correoConfirmado cuando la fundación apruebe o rechace tu solicitud.',
                        style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Radicado: #$idRadicado',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Descargar copia'),
              onPressed: () {
                AcuerdoApadrinamientoPdfService.descargarYGuardarPdf(
                  bytes: pdfBytes,
                  nombreMascota: widget.pet.nombre,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Descargando copia del acuerdo...')),
                );
              },
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Barra de arrastre superior
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Encabezado con título e icono de cerrar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.volunteer_activism,
                      color: AppColors.rosa,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Detalles del apadrinamiento',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.texto,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar',
                  onPressed: _enviando ? null : () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 12),

          // Indicador de pasos idéntico al de Adopción
          _Pasos(paso: _paso),

          const SizedBox(height: 4),

          // Contenido del paso actual con scroll
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                children: [
                  _resumenMascota(t),
                  const SizedBox(height: 14),

                  if (_paso == 0) ..._pasoMotivacion(t),
                  if (_paso == 1) ..._pasoDocumento(t),
                  if (_paso == 2) ..._pasoCompromiso(t),
                ],
              ),
            ),
          ),

          // Barra inferior de navegación con botones Atrás y Continuar / Enviar
          _barraBotones(),
        ],
      ),
    );
  }

  /// Tarjeta de presentación de la mascota
  Widget _resumenMascota(TextTheme t) {
    if (_paso > 0) {
      // Formato compacto para los pasos 2 y 3 para aprovechar mejor el espacio
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.rosaSuave,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.bordeRosa),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.rosa, width: 2),
              ),
              child: ClipOval(child: PetImage(url: widget.pet.foto)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.pet.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    '${widget.pet.especie} • ${(widget.pet.raza == null || widget.pet.raza!.isEmpty) ? 'Mestizo' : widget.pet.raza} • ${widget.pet.edadTexto}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Paso 0: Presentación destacada y centrada del perro
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.rosa, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.rosa.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(child: PetImage(url: widget.pet.foto)),
          ),
          const SizedBox(height: 10),
          Text(
            widget.pet.nombre,
            textAlign: TextAlign.center,
            style: t.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.texto,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.rosaSuave,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.bordeRosa),
            ),
            child: Text(
              widget.pet.edadTexto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.rosa,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.pet.especie} • ${(widget.pet.raza == null || widget.pet.raza!.isEmpty) ? 'Mestizo' : widget.pet.raza}',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  /// Paso 1: Motivación y Aporte
  List<Widget> _pasoMotivacion(TextTheme t) => [
        // Datos del solicitante
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.rosaClaro.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.rosa.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 20, color: AppColors.rosa),
                  const SizedBox(width: 8),
                  Text(
                    'Datos del solicitante',
                    style: t.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.rosa,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${Session.nombre} ${Session.apellidos}'.trim().isEmpty
                    ? 'Usuario registrado'
                    : '${Session.nombre} ${Session.apellidos}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (Session.telefono.isNotEmpty)
                Text('Teléfono: ${Session.telefono}', style: t.bodySmall),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Confirmación o modificación del correo para recibir respuesta
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.rosa.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: AppColors.rosa.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 20, color: AppColors.rosa),
                  const SizedBox(width: 8),
                  Text(
                    'Correo para recibir la respuesta *',
                    style: t.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.rosa,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Confirma o modifica el correo electrónico donde la Fundación te informará si tu solicitud fue aprobada o rechazada:',
                style: t.bodySmall?.copyWith(color: Colors.grey.shade700, height: 1.3),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _correoCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'ejemplo@correo.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.rosa),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.rosa, width: 2),
                  ),
                ),
                validator: (v) {
                  final correo = (v ?? '').trim();
                  if (correo.isEmpty) {
                    return 'Ingresa tu correo para recibir la notificación.';
                  }
                  if (!correo.contains('@') || !correo.contains('.')) {
                    return 'Ingresa un correo electrónico válido.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Pregunta obligatoria de motivación
        Text(
          '¿Por qué quieres apadrinar a esta mascota? *',
          style: t.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.texto,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Cuéntanos por qué quieres apadrinar a esta mascota. ¿Qué te gustó de ella? ¿Qué te motivó a elegirla? ¿Por qué deseas ayudarla?',
          style: t.bodySmall?.copyWith(
            color: Colors.grey.shade600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _motivacionCtrl,
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Escribe aquí tu motivación...',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.rosa, width: 2),
            ),
          ),
          validator: (v) {
            final txt = (v ?? '').trim();
            if (txt.isEmpty) {
              return 'Este campo es obligatorio para evaluar tu solicitud.';
            }
            if (txt.length > 500) {
              return 'Solo se aceptan un máximo de 500 caracteres.';
            }
            return null;
          },
        ),

        const SizedBox(height: 14),

        // Aporte voluntario y frecuencia
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aporte voluntario (COP)',
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _montoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Frecuencia',
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _frecuencia,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                      DropdownMenuItem(value: 'quincenal', child: Text('Quincenal')),
                      DropdownMenuItem(value: 'unica_vez', child: Text('Única vez')),
                    ],
                    onChanged: (v) => setState(() => _frecuencia = v ?? 'mensual'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ];

  /// Paso 2: Fotografía del documento de identidad
  List<Widget> _pasoDocumento(TextTheme t) => [
        Text(
          'Documento de Identidad',
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Adjunta una fotografía clara de tu documento de identidad (cédula de ciudadanía o extranjería). La Fundación mantendrá tus datos de forma confidencial.',
          style: t.bodySmall?.copyWith(color: Colors.grey.shade600, height: 1.35),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _docBytes == null ? Colors.grey.shade300 : Colors.green.shade400,
              width: _docBytes == null ? 1 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_docBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _docBytes!,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _docNombre ?? 'foto_documento.jpg',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Cambiar'),
                      onPressed: _seleccionarDocumento,
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  height: 130,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.rosaSuave,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.badge_outlined, color: AppColors.rosa, size: 40),
                      const SizedBox(height: 6),
                      Text(
                        'Ningún documento adjunto aún',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosa,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Subir fotografía de cédula'),
                  onPressed: _seleccionarDocumento,
                ),
              ],
            ],
          ),
        ),
      ];

  /// Paso 3: Resumen y Acuerdo de Responsabilidad y Compromiso
  List<Widget> _pasoCompromiso(TextTheme t) {
    final montoTexto = _montoCtrl.text.trim().isNotEmpty
        ? '\$ ${_montoCtrl.text.trim()} COP'
        : '\$ 0 COP';

    return [
      Text(
        'Acuerdo y Confirmación',
        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'Revisa el resumen de tu apadrinamiento y acepta el acuerdo para formalizar tu solicitud.',
        style: t.bodySmall?.copyWith(color: Colors.grey.shade600, height: 1.35),
      ),
      const SizedBox(height: 14),

      // Resumen del apadrinamiento
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            _resumenFila('Fundación:', FundacionInfo.nombre),
            const Divider(height: 14),
            _resumenFila(
              'Solicitante:',
              '${Session.nombre} ${Session.apellidos}'.trim().isEmpty
                  ? 'Usuario Registrado'
                  : '${Session.nombre} ${Session.apellidos}',
            ),
            const Divider(height: 14),
            _resumenFila('Notificación al correo:', _correoCtrl.text.trim()),
            const Divider(height: 14),
            _resumenFila('Aporte voluntario:', '$montoTexto ($_frecuencia)'),
            const Divider(height: 14),
            _resumenFila('Documento:', _docNombre ?? 'Adjuntado'),
          ],
        ),
      ),

      const SizedBox(height: 18),

      // Casilla de aceptación del acuerdo con enlace rosa
      Material(
        color: _aceptoAcuerdo ? Colors.green.shade50 : Colors.grey.shade50,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(
            color: _aceptoAcuerdo ? Colors.green.shade400 : Colors.grey.shade300,
            width: _aceptoAcuerdo ? 1.5 : 1,
          ),
        ),
        child: CheckboxListTile(
          value: _aceptoAcuerdo,
          activeColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: RichText(
            text: TextSpan(
              style: t.bodyMedium?.copyWith(color: AppColors.texto, height: 1.35),
              children: [
                const TextSpan(text: 'He leído y acepto el '),
                TextSpan(
                  text: 'acuerdo de responsabilidad y compromiso',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.rosa,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = _verTerminosAcuerdo,
                ),
                const TextSpan(text: ' para el apadrinamiento de esta mascota.'),
              ],
            ),
          ),
          onChanged: (val) {
            setState(() => _aceptoAcuerdo = val ?? false);
          },
          secondary: IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.rosa),
            tooltip: 'Ver acuerdo completo',
            onPressed: _verTerminosAcuerdo,
          ),
        ),
      ),

      const SizedBox(height: 14),

      // Aviso de constancia electrónica y descarga automática de PDF
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.rosaSuave,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.bordeRosa),
        ),
        child: Row(
          children: [
            const Icon(Icons.file_download_outlined, color: AppColors.rosa, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Al confirmar, el sistema registrará tu constancia electrónica de aceptación y descargará automáticamente tu Acuerdo en PDF con la identidad de la Fundación.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800, height: 1.35),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 18),

      // Confirmación del correo del perfil del usuario (después de leer el acuerdo)
      _tarjetaConfirmacionCorreoPerfil(t),
    ];
  }

  /// Tarjeta que muestra el correo actual del perfil con opción de confirmarlo o editarlo en la BD
  Widget _tarjetaConfirmacionCorreoPerfil(TextTheme t) {
    final correoPerfil = _correoCtrl.text.trim().isNotEmpty
        ? _correoCtrl.text.trim()
        : (Session.correo.isNotEmpty ? Session.correo : 'No especificado');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _correoPerfilConfirmado ? Colors.green.shade400 : AppColors.rosa,
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (_correoPerfilConfirmado ? Colors.green : AppColors.rosa).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _correoPerfilConfirmado ? Colors.green.shade50 : AppColors.rosaSuave,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _correoPerfilConfirmado ? Icons.mark_email_read_rounded : Icons.mail_outline_rounded,
                  color: _correoPerfilConfirmado ? Colors.green.shade700 : AppColors.rosa,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Correo electrónico de tu perfil',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Confirmación requerida para notificación',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Este es el correo electrónico de tu perfil. Por favor confirmar ya que recibirás una notificación con tu solicitud:',
            style: TextStyle(fontSize: 13, height: 1.38, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.rosaSuave.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bordeRosa),
            ),
            child: Row(
              children: [
                const Icon(Icons.email, color: AppColors.rosa, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    correoPerfil,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.texto),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_correoPerfilConfirmado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade800),
                        const SizedBox(width: 4),
                        Text(
                          'Confirmado',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade800,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.rosa),
                  label: const Text('No es / Cambiar', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  onPressed: _dialogoEditarCorreoPerfil,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _correoPerfilConfirmado ? Colors.green.shade600 : AppColors.rosa,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.check, size: 17),
                  label: Text(
                    _correoPerfilConfirmado ? '✓ Correo Confirmado' : 'Sí, confirmar correo',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    setState(() => _correoPerfilConfirmado = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                        content: Text('Correo $correoPerfil confirmado para recibir la notificación.'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resumenFila(String etiqueta, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta, style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }

  /// Barra de botones en la parte inferior idéntica a la pantalla de adopción
  Widget _barraBotones() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: Row(
          children: [
            if (_paso > 0)
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _enviando ? null : () => setState(() => _paso -= 1),
                  child: const Text('Atrás'),
                ),
              ),
            if (_paso > 0) const SizedBox(width: 12),
            Expanded(
              flex: _paso > 0 ? 2 : 1,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosa,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _enviando
                    ? null
                    : (_paso < 2 ? _continuar : _solicitarConfirmacionCorreoYEnviar),
                child: _enviando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_paso >= 2) ...[
                            const Icon(Icons.send_rounded, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _paso < 2
                                ? 'Continuar'
                                : 'Enviar Solicitud de Apadrinamiento',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
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
}

/// Widget indicador de pasos visualmente idéntico al de adopción
class _Pasos extends StatelessWidget {
  final int paso;
  const _Pasos({required this.paso});

  @override
  Widget build(BuildContext context) {
    const etiquetas = ['Motivación', 'Documento', 'Compromiso'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          for (var i = 0; i < etiquetas.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= paso ? AppColors.rosa : AppColors.bordeRosa,
                ),
              ),
            Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: i <= paso ? AppColors.rosa : AppColors.rosaClaro,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i <= paso ? Colors.white : AppColors.rosa,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  etiquetas[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: i == paso ? AppColors.rosa : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
