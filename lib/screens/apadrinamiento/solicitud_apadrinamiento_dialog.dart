import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/services/acuerdo_apadrinamiento_pdf_service.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/seguimiento_apadrinamiento_service.dart';
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
  }) async {
    // 1. Verificar si el usuario está bloqueado para apadrinar por incumplimiento
    final idUsuario = Session.idUsuario;
    if (idUsuario != null && idUsuario.isNotEmpty) {
      final resumen = await SeguimientoApadrinamientoService.obtenerResumenPadrino(idUsuario);
      if (resumen != null && resumen.bloqueadoApadrinar) {
        if (!context.mounted) return;
        return showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.block_rounded, color: Colors.red.shade700, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cuenta Inhabilitada',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Tu cuenta se encuentra inhabilitada para crear nuevas solicitudes de apadrinamiento debido al registro reiterado de incumplimientos en tus seguimientos previos.\n\nPara solicitar asistencia o regularizar tu caso, por favor comunícate directamente con la administración de la Fundación Maritza Arévalo.',
              style: TextStyle(fontSize: 14, height: 1.45),
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
    }

    if (pet.estaAdoptada) {
      if (!context.mounted) return;
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

    if (!context.mounted) return;
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
  static const String tipoMonetario = 'Aporte monetario.';
  static const String tipoEspecie =
      'Aporte en especie (alimento, cobijas, camas, juguetes, medicamentos, productos de aseo u otros artículos).';
  static const String tipoOtro = 'Otro tipo de ayuda.';

  final _formKey = GlobalKey<FormState>();
  final _motivacionCtrl = TextEditingController();
  final _correoCtrl = TextEditingController(text: Session.correo);

  // Selección de tipo de aporte
  String _tipoAporte = tipoMonetario;

  // Campos para Aporte monetario
  final _montoCtrl = TextEditingController();
  String _frecuenciaMonetario = 'mensual'; // 'semanal', 'quincenal', 'mensual', 'aporte_unico'

  // Campos para Aporte en especie
  final _detalleEspecieCtrl = TextEditingController();
  String _frecuenciaEspecie = 'mensual'; // 'semanal', 'quincenal', 'mensual', 'entrega_unica'

  // Campos para Otro tipo de ayuda
  final _otroAporteCtrl = TextEditingController();

  late Pet _mascotaActual = widget.pet;
  bool _cargandoSalud = false;

  int _paso = 0;
  Uint8List? _docBytes;
  String? _docNombre;

  bool _aceptoAcuerdo = false;
  bool _enviando = false;
  bool _actualizandoCorreo = false;
  bool _correoPerfilConfirmado = false;

  @override
  void initState() {
    super.initState();
    _consultarSaludMascota();
  }

  Future<void> _consultarSaludMascota() async {
    try {
      if (mounted) setState(() => _cargandoSalud = true);
      final fresca = await PetsService.obtener(widget.pet.id);
      if (mounted) {
        setState(() {
          _mascotaActual = fresca;
          _cargandoSalud = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoSalud = false);
    }
  }

  @override
  void dispose() {
    _motivacionCtrl.dispose();
    _montoCtrl.dispose();
    _correoCtrl.dispose();
    _detalleEspecieCtrl.dispose();
    _otroAporteCtrl.dispose();
    super.dispose();
  }

  bool _esPdf(String? nombre, Uint8List? bytes) {
    if (nombre != null && nombre.toLowerCase().endsWith('.pdf')) return true;
    if (bytes != null && bytes.length >= 4) {
      return bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46; // %PDF
    }
    return false;
  }

  Future<void> _seleccionarDocumento() async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_present_rounded, color: AppColors.rosa),
              title: const Text('Subir archivo o documento (PDF, JPG, PNG)'),
              subtitle: const Text('Permite seleccionar documentos PDF o imágenes de tu dispositivo'),
              onTap: () => Navigator.pop(ctx, 'archivo'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.rosa),
              title: const Text('Elegir foto de la galería'),
              onTap: () => Navigator.pop(ctx, 'galeria'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.rosa),
              title: const Text('Tomar foto con la cámara'),
              onTap: () => Navigator.pop(ctx, 'camara'),
            ),
          ],
        ),
      ),
    );
    if (opcion == null || !mounted) return;

    try {
      Uint8List? bytes;
      String? nombre;

      if (opcion == 'archivo') {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        );
        if (files.isNotEmpty) {
          final file = files.first;
          bytes = await file.xFile.readAsBytes();
          nombre = file.name;
        }
      } else {
        final source = opcion == 'camara' ? ImageSource.camera : ImageSource.gallery;
        final picked = await ImagePicker().pickImage(
          source: source,
          imageQuality: 85,
        );
        if (picked != null) {
          bytes = await picked.readAsBytes();
          nombre = picked.name;
        }
      }

      if (bytes == null || !mounted) return;

      setState(() {
        _docBytes = bytes;
        _docNombre = nombre ?? 'documento_identidad.jpg';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar el documento: $e')),
      );
    }
  }

  void _verDocumento() {
    if (_docBytes == null) return;
    final nombre = _docNombre ?? 'documento_identidad.pdf';

    if (_esPdf(_docNombre, _docBytes)) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: Colors.grey.shade100,
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.texto,
              elevation: 1,
              title: Text(nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            body: PdfPreview(
              build: (_) => _docBytes!,
              useActions: false,
              allowPrinting: false,
              allowSharing: false,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              dynamicLayout: false,
              pdfFileName: nombre,
            ),
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(nombre),
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
      final motivacion = _motivacionCtrl.text.trim();
      if (motivacion.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Debes responder por qué quieres apadrinar a ${widget.pet.nombre}',
            ),
          ),
        );
        return;
      }
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

    final motivacion = _motivacionCtrl.text.trim();
    if (motivacion.isEmpty) {
      setState(() => _paso = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Debes responder por qué quieres apadrinar a ${widget.pet.nombre}',
          ),
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

    if (!_correoPerfilConfirmado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Por favor pulsa el botón "Confirmar" en tu correo antes de enviar la solicitud.',
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
                          _correoPerfilConfirmado = false;
                          _actualizandoCorreo = false;
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.green,
                              content: Text('¡Correo actualizado en tu perfil y base de datos con éxito!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) setModalState(() => _actualizandoCorreo = false);
                        if (mounted) setState(() => _actualizandoCorreo = false);
                        final msg = e.toString().replaceFirst('Exception: ', '');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: Colors.redAccent, content: Text(msg)),
                          );
                        }
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
      final motivacion = _motivacionCtrl.text.trim();

      int? monto;
      String frecuenciaFinal;
      String? detalleFinal;

      if (_tipoAporte == tipoMonetario) {
        monto = int.tryParse(_montoCtrl.text.replaceAll(RegExp(r'\D'), ''));
        frecuenciaFinal = _frecuenciaMonetario;
        detalleFinal = null;
      } else if (_tipoAporte == tipoEspecie) {
        monto = null;
        frecuenciaFinal = _frecuenciaEspecie;
        detalleFinal = _detalleEspecieCtrl.text.trim();
      } else {
        monto = null;
        frecuenciaFinal = 'aporte_unico';
        detalleFinal = _otroAporteCtrl.text.trim();
      }

      // 1. Enviar a base de datos en el backend (incluyendo el correo confirmado)
      final SolicitudApadrinamiento? solicitudCreada =
          await ApadrinamientoService.enviarSolicitud(
        idMascota: widget.pet.id,
        motivacion: motivacion,
        tipoAporte: _tipoAporte,
        montoAporte: monto,
        frecuenciaAporte: frecuenciaFinal,
        detalleAporte: detalleFinal,
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

      // Obtener imagen de la mascota si está disponible
      Uint8List? petFotoBytes;
      try {
        if (widget.pet.foto != null && widget.pet.foto!.trim().isNotEmpty) {
          final url = urlFoto(widget.pet.foto!);
          final resImg = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
          if (resImg.statusCode == 200) petFotoBytes = resImg.bodyBytes;
        }
      } catch (_) {}

      // 2. Generar el PDF oficial del Acuerdo breve con datos reales y fotos integradas
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
        tipoAporte: _tipoAporte,
        detalleAporte: detalleFinal,
        montoAporte: monto,
        frecuenciaAporte: frecuenciaFinal,
        motivacion: motivacion,
        fechaAceptacion: fechaAhora,
        fotoCedula: _docBytes,
        fotoMascota: petFotoBytes,
        estadoProceso: 'pendiente',
        estadoCorreo: 'pendiente',
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

      // 4. Diálogo de confirmación con indicación del correo de verificación
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
            '¡Solicitud y Correo de Verificación Enviados!',
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
                            'Acuerdo en PDF descargado',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          Text(
                            'Incluye tus datos, los de ${widget.pet.nombre}, tu aporte y la fotografía de tu documento.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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
                    Icon(Icons.mark_email_unread_outlined, color: Colors.amber.shade900, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verifica tu correo electrónico',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Enviamos un enlace de verificación a $correoConfirmado. Haz clic en el enlace para actualizar tu estado a «Correo confirmado».',
                            style: TextStyle(fontSize: 11.5, height: 1.35, color: Colors.grey.shade900),
                          ),
                        ],
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

        // Pregunta obligatoria de motivación claramente destacada
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.bordeRosa, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.rosa.withValues(alpha: 0.06),
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
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.rosaSuave,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.favorite_rounded, color: AppColors.rosa, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¿Por qué quieres apadrinar a ${widget.pet.nombre}? *',
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.texto,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Cuéntanos por qué quieres apadrinar a ${widget.pet.nombre}. ¿Qué te motivó a elegirlo(a)? ¿Por qué deseas apoyarlo(a)?',
                style: t.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motivacionCtrl,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Escribe aquí tu motivación para apadrinar a ${widget.pet.nombre}...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.all(14),
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
                    return 'Debes responder por qué quieres apadrinar a ${widget.pet.nombre}.';
                  }
                  if (txt.length > 500) {
                    return 'Solo se aceptan un máximo de 500 caracteres.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Forma de Contribuir (Tipo de aporte y campos dinámicos)
        _seccionAporte(t),
      ];

  /// Sección interactiva de Tipo de Aporte con diseño moderno en tonos rosas
  Widget _seccionAporte(TextTheme t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.bordeRosa.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.06),
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.rosaSuave,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  color: AppColors.rosa,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Cómo deseas contribuir? *',
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.texto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Elige la forma en que apoyarás a ${widget.pet.nombre}',
                      style: t.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Selector de Tipo de Aporte (Dropdown)
          DropdownButtonFormField<String>(
            initialValue: _tipoAporte,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Tipo de aporte *',
              labelStyle: const TextStyle(
                color: AppColors.rosa,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.category_rounded,
                color: AppColors.rosa,
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFFFDF7F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.bordeRosa),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.bordeRosa),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.rosa, width: 2),
              ),
            ),
            selectedItemBuilder: (context) {
              return [
                tipoMonetario,
                tipoEspecie,
                tipoOtro,
              ].map((opcion) {
                final String labelCorto;
                final IconData icono;
                if (opcion == tipoMonetario) {
                  labelCorto = 'Aporte monetario.';
                  icono = Icons.payments_outlined;
                } else if (opcion == tipoEspecie) {
                  labelCorto = 'Aporte en especie';
                  icono = Icons.inventory_2_outlined;
                } else {
                  labelCorto = 'Otro tipo de ayuda.';
                  icono = Icons.handshake_outlined;
                }
                return Row(
                  children: [
                    Icon(icono, size: 18, color: AppColors.rosa),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        labelCorto,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.texto,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
            items: const [
              DropdownMenuItem(
                value: tipoMonetario,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined, color: AppColors.rosa, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Aporte monetario.',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.texto,
                              ),
                            ),
                            Text(
                              'Apoyo económico periódico o único',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DropdownMenuItem(
                value: tipoEspecie,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, color: AppColors.rosa, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Aporte en especie',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.texto,
                              ),
                            ),
                            Text(
                              'Alimento, cobijas, camas, juguetes, medicamentos, aseo u otros',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DropdownMenuItem(
                value: tipoOtro,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.handshake_outlined, color: AppColors.rosa, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Otro tipo de ayuda.',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.texto,
                              ),
                            ),
                            Text(
                              'Voluntariado, paseos, transporte o difusión',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _tipoAporte = v);
                if (v == tipoOtro) {
                  _consultarSaludMascota();
                }
              }
            },
          ),

          const SizedBox(height: 16),

          // 2. Vistas dinámicas según la opción elegida
          if (_tipoAporte == tipoMonetario) ...[
            _camposAporteMonetario(t),
          ] else if (_tipoAporte == tipoEspecie) ...[
            _camposAporteEspecie(t),
          ] else ...[
            _camposOtroTipoAyuda(t),
          ],
        ],
      ),
    );
  }

  /// Campos dinámicos para Aporte monetario
  Widget _camposAporteMonetario(TextTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.rosaSuave,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bordeRosa),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.rosa),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El dinero se destina a alimentación, vacunas y atención veterinaria de la mascota.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF6B213F)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final esAncho = constraints.maxWidth >= 480;

            final campoMonto = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valor del aporte (COP) *',
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _montoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Text(
                        '\$ ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.rosa,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 0),
                    suffixText: 'COP',
                    suffixStyle: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                    hintText: '0',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    if (_tipoAporte != tipoMonetario) return null;
                    final limpio = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    final valor = int.tryParse(limpio);
                    if (valor == null || valor <= 0) {
                      return 'Ingresa un valor válido en pesos colombianos.';
                    }
                    if (valor < 5000) {
                      return 'El aporte mínimo sugerido es de \$5.000 COP.';
                    }
                    return null;
                  },
                ),
              ],
            );

            final campoFrecuencia = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Frecuencia del aporte *',
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _frecuenciaMonetario,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.event_repeat_rounded, color: AppColors.rosa, size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  items: const [
                    DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                    DropdownMenuItem(value: 'quincenal', child: Text('Quincenal')),
                    DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                    DropdownMenuItem(value: 'aporte_unico', child: Text('Aporte único')),
                  ],
                  onChanged: (v) => setState(() => _frecuenciaMonetario = v ?? 'mensual'),
                ),
              ],
            );

            if (esAncho) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: campoMonto),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: campoFrecuencia),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  campoMonto,
                  const SizedBox(height: 12),
                  campoFrecuencia,
                ],
              );
            }
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Sugeridos:',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
            ...[20000, 30000, 50000, 100000].map((montoSugerido) {
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    _montoCtrl.text = montoSugerido.toString();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _montoCtrl.text == montoSugerido.toString()
                        ? AppColors.rosa
                        : AppColors.rosaSuave,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.bordeRosa),
                  ),
                  child: Text(
                    '\$${(montoSugerido / 1000).toInt()}k COP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _montoCtrl.text == montoSugerido.toString()
                          ? Colors.white
                          : AppColors.rosa,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Campos dinámicos para Aporte en especie
  Widget _camposAporteEspecie(TextTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.rosaSuave,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bordeRosa),
          ),
          child: const Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.rosa),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Puedes entregar donaciones de alimento, cobijas, camas, medicamentos o productos de aseo.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF6B213F)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '¿Qué deseas aportar? *',
          style: t.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.texto,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _detalleEspecieCtrl,
          maxLines: 3,
          maxLength: 400,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText:
                'Ejemplo: 1 bulto de alimento para perros de 15kg, 2 cobijas térmicas, cama mediana y productos de aseo...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.all(14),
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
            if (_tipoAporte != tipoEspecie) return null;
            final txt = (v ?? '').trim();
            if (txt.isEmpty) {
              return 'Por favor describe qué elementos vas a entregar.';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Frecuencia de entrega *',
          style: t.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.texto,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _frecuenciaEspecie,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.calendar_month_rounded, color: AppColors.rosa, size: 20),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          items: const [
            DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
            DropdownMenuItem(value: 'quincenal', child: Text('Quincenal')),
            DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
            DropdownMenuItem(value: 'entrega_unica', child: Text('Entrega única')),
          ],
          onChanged: (v) => setState(() => _frecuenciaEspecie = v ?? 'mensual'),
        ),
      ],
    );
  }

  /// Campos dinámicos para Otro tipo de ayuda, consultando el estado de salud de la mascota
  Widget _camposOtroTipoAyuda(TextTheme t) {
    final pet = _mascotaActual;
    final necesidades = pet.necesidadesPendientes;
    final procedimientos = pet.procedimientosRealizados;
    final sinPendientes = pet.noTieneNecesidadesPendientes || necesidades.isEmpty;
    final tieneNecesidad = !sinPendientes;

    // Ejemplos orientativos solicitados: vacunas, esterilización, desparasitación, exámenes médicos, medicamentos, consultas veterinarias o tratamientos.
    final List<String> ejemplosOrientativos = [
      'Vacunación',
      'Esterilización',
      'Desparasitación',
      'Exámenes médicos',
      'Medicamentos',
      'Consultas veterinarias',
      'Tratamientos veterinarios',
      'Paseos y recreación',
      'Difusión en redes',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tarjeta con información del estado de salud de la mascota
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tieneNecesidad ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tieneNecesidad ? const Color(0xFFFDBA74) : const Color(0xFF86EFAC),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (tieneNecesidad ? Colors.orange : Colors.green).withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tieneNecesidad ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      tieneNecesidad ? Icons.healing_rounded : Icons.health_and_safety_rounded,
                      color: tieneNecesidad ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Salud de ${pet.nombre}:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: tieneNecesidad ? const Color(0xFF9A3412) : const Color(0xFF166534),
                              ),
                            ),
                            const Spacer(),
                            if (_cargandoSalud)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rosa),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: tieneNecesidad ? const Color(0xFFFED7AA) : const Color(0xFFBBF7D0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tieneNecesidad ? 'Tiene necesidades registradas' : 'Saludable / Al día',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: tieneNecesidad ? const Color(0xFF7C2D12) : const Color(0xFF14532D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 1. Necesidades veterinarias pendientes confirmadas
              if (necesidades.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Color(0xFFEA580C)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Necesidades veterinarias registradas (Posibles formas de ayuda):',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: necesidades.map((necesidad) {
                    return ActionChip(
                      avatar: const Icon(Icons.add_circle, size: 15, color: Color(0xFFEA580C)),
                      label: Text(
                        necesidad,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C2D12),
                        ),
                      ),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFFDBA74), width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      tooltip: 'Toca para agregar a tu propuesta de aporte',
                      onPressed: () {
                        final actual = _otroAporteCtrl.text.trim();
                        final sugerencia = 'Apoyo para $necesidad';
                        if (actual.isEmpty) {
                          _otroAporteCtrl.text = '$sugerencia para ${pet.nombre}. ';
                        } else if (!actual.contains(necesidad)) {
                          _otroAporteCtrl.text = '$actual, $necesidad';
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ] else ...[
                // Mensaje requerido cuando no hay necesidades veterinarias pendientes
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Actualmente no hay necesidades médicas específicas registradas.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 2. Procedimientos y vacunas ya completados
              if (procedimientos.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.verified, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Vacunas y procedimientos ya realizados:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: procedimientos.map((proc) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check, size: 14, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Text(
                            proc,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF14532D),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Procedimientos atendidos por la fundación; no figuran como pendientes.',
                  style: TextStyle(fontSize: 10.5, color: Colors.green.shade800, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 10),
              ],

              // 3. Recomendaciones y observaciones veterinarias
              if (pet.detalleSalud != null && pet.detalleSalud!.trim().isNotEmpty) ...[
                const Text(
                  'Recomendaciones y observaciones veterinarias:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9A3412),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Text(
                    pet.detalleSalud!.trim(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF431407),
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 4. Ejemplos orientativos de ayudas veterinarias (claramente diferenciados)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.rosa),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Ejemplos orientativos de ayudas veterinarias:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.texto,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ideas de apoyo general. No representan necesidades confirmadas de ${pet.nombre} a menos que aparezcan listadas arriba.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ejemplosOrientativos.map((ejemplo) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            final actual = _otroAporteCtrl.text.trim();
                            final prefijo = 'Apoyo en $ejemplo';
                            if (actual.isEmpty) {
                              _otroAporteCtrl.text = '$prefijo para ${pet.nombre}. ';
                            } else if (!actual.contains(ejemplo)) {
                              _otroAporteCtrl.text = '$actual, $ejemplo';
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.rosaSuave,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.bordeRosa),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 12, color: AppColors.rosa),
                                const SizedBox(width: 4),
                                Text(
                                  ejemplo,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.rosa,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Text(
          '¿Cómo deseas contribuir? *',
          style: t.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.texto,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _otroAporteCtrl,
          maxLines: 3,
          maxLength: 400,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: tieneNecesidad
                ? 'Describe cómo deseas apoyar sus necesidades médicas o veterinarias (ej: cubrir vacunas, medicamentos, exámenes o acompañar la consulta)...'
                : 'Describe tu propuesta de ayuda (ej: voluntariado en eventos, paseos los fines de semana, transporte o fotografías)...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.all(14),
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
            if (_tipoAporte != tipoOtro) return null;
            final txt = (v ?? '').trim();
            if (txt.isEmpty) {
              return 'Por favor describe en qué consiste tu ayuda.';
            }
            return null;
          },
        ),
      ],
    );
  }

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
                if (_esPdf(_docNombre, _docBytes))
                  InkWell(
                    onTap: null,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 160,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade200, width: 1.2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade700, size: 48),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _docNombre ?? 'documento_identidad.pdf',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.red.shade900,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 14, color: Colors.green.shade800),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Documento PDF listo',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: null,
                    borderRadius: BorderRadius.circular(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _docBytes!,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 140,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.rosaSuave,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.description_outlined, color: AppColors.rosa, size: 48),
                              const SizedBox(height: 6),
                              Text(
                                _docNombre ?? 'documento_identidad',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.rosa,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Ver documento'),
                        onPressed: _verDocumento,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.rosa,
                          side: const BorderSide(color: AppColors.rosa),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Cambiar'),
                        onPressed: _seleccionarDocumento,
                      ),
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
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Subir documento (PDF, JPG, PNG)'),
                  onPressed: _seleccionarDocumento,
                ),
              ],
            ],
          ),
        ),
      ];

  /// Paso 3: Resumen y Acuerdo de Responsabilidad y Compromiso
  List<Widget> _pasoCompromiso(TextTheme t) {
    final String aporteResumen;
    if (_tipoAporte == tipoMonetario) {
      final montoTexto = _montoCtrl.text.trim().isNotEmpty
          ? '\$ ${_montoCtrl.text.trim()} COP'
          : '\$ 0 COP';
      final frec = switch (_frecuenciaMonetario) {
        'semanal' => 'Semanal',
        'quincenal' => 'Quincenal',
        'mensual' => 'Mensual',
        'aporte_unico' => 'Aporte único',
        _ => _frecuenciaMonetario,
      };
      aporteResumen = '$montoTexto ($frec)';
    } else if (_tipoAporte == tipoEspecie) {
      final frec = switch (_frecuenciaEspecie) {
        'semanal' => 'Semanal',
        'quincenal' => 'Quincenal',
        'mensual' => 'Mensual',
        'entrega_unica' => 'Entrega única',
        _ => _frecuenciaEspecie,
      };
      final detalle = _detalleEspecieCtrl.text.trim();
      aporteResumen = 'En especie ($frec)${detalle.isNotEmpty ? ': $detalle' : ''}';
    } else {
      final detalle = _otroAporteCtrl.text.trim();
      aporteResumen = 'Otro tipo de ayuda${detalle.isNotEmpty ? ': $detalle' : ''}';
    }

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
            _resumenFila('Tipo de aporte:', _tipoAporte),
            const Divider(height: 14),
            _resumenFila('Modalidad y Detalle:', aporteResumen),
            const Divider(height: 14),
            _resumenFila('¿Por qué apadrinar?:', _motivacionCtrl.text.trim().isEmpty ? 'No especificada' : _motivacionCtrl.text.trim()),
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

  /// Tarjeta que muestra el correo actual del perfil con botón de confirmar
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
          color: _correoPerfilConfirmado ? Colors.green.shade400 : AppColors.bordeRosa,
          width: _correoPerfilConfirmado ? 1.8 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (_correoPerfilConfirmado ? Colors.green : Colors.black).withValues(alpha: 0.05),
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
                      _correoPerfilConfirmado
                          ? 'Correo verificado para tu solicitud'
                          : 'Confirmación requerida para notificación',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _correoPerfilConfirmado
                ? '¡Tu correo ha sido confirmado con éxito! Allí te notificaremos el avance de tu solicitud.'
                : 'Al enviar la solicitud, el sistema te enviará automáticamente un correo electrónico con un enlace para confirmar tu dirección.',
            style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.rosaSuave.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _correoPerfilConfirmado ? Colors.green.shade300 : AppColors.bordeRosa,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.email,
                  color: _correoPerfilConfirmado ? Colors.green.shade700 : AppColors.rosa,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    correoPerfil,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.texto),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _correoPerfilConfirmado ? Colors.green.shade100 : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _correoPerfilConfirmado ? Icons.check_circle : Icons.hourglass_top_rounded,
                        size: 13,
                        color: _correoPerfilConfirmado ? Colors.green.shade800 : Colors.amber.shade900,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _correoPerfilConfirmado ? 'Confirmado' : 'Verificación al enviar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _correoPerfilConfirmado ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
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
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _correoPerfilConfirmado ? Colors.green.shade600 : AppColors.rosa,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: Icon(_correoPerfilConfirmado ? Icons.check_circle : Icons.check, size: 17),
                  label: Text(
                    _correoPerfilConfirmado ? 'Confirmado' : 'Confirmar',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    setState(() => _correoPerfilConfirmado = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                        content: Text('Correo $correoPerfil confirmado.'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade800,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.rosa),
                  label: const Text('No es / Cambiar correo', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  onPressed: _dialogoEditarCorreoPerfil,
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
