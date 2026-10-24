import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/services/acuerdo_adopcion_pdf_service.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/compartir_acta_whatsapp.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Formulario para solicitar la adopción de una mascota.
/// Se muestra como ventana flotante sobre la pantalla actual.
class AdoptionFormScreen extends StatefulWidget {
  final Pet pet;

  const AdoptionFormScreen({super.key, required this.pet});

  /// Abre el formulario en un modal, sin cambiar de pantalla.
  static Future<bool?> mostrar(BuildContext context, {required Pet pet}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdoptionFormScreen(pet: pet),
    );
  }

  @override
  State<AdoptionFormScreen> createState() => _AdoptionFormScreenState();
}

class _AdoptionFormScreenState extends State<AdoptionFormScreen> {
  static const _avisoMotivacion =
      'Cuéntenos un poco más (mínimo 20 caracteres).';
  static const _viviendas = ['Casa', 'Apartamento', 'Finca', 'Habitación'];
  static const _tiempos = [
    'Menos de 2 horas al día',
    'De 2 a 4 horas al día',
    'Más de 4 horas al día',
    'Estoy en casa todo el día',
  ];

  final _otrasCtrl = TextEditingController();
  final _infoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController(text: Session.correo);
  final _scrollCtrl = ScrollController();

  int _paso = 0;
  bool _revisando = true;
  bool _enviando = false;
  bool _mostrarError = false;
  bool _correoPerfilConfirmado = false;
  bool _actualizandoCorreo = false;
  bool _aceptoTerminos = false;
  String? _error;

  String? _vivienda;
  bool? _patio;
  bool? _ninos;
  bool? _otrasMascotas;
  String? _tiempo;
  bool? _experiencia;

  Uint8List? _cedulaBytes;
  String? _cedulaNombre;
  Uint8List? _reciboBytes;
  String? _reciboNombre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revisarSiPuedeEnviar());
  }

  @override
  void dispose() {
    _otrasCtrl.dispose();
    _infoCtrl.dispose();
    _correoCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// El siguiente paso debe verse desde el inicio, no desde donde quedó el anterior.
  void _mostrarDesdeArriba() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(0);
    });
  }

  Future<void> _revisarSiPuedeEnviar() async {
    final estado = widget.pet.estadoAdopcion.toLowerCase();
    if (estado == 'adoptado' || estado == 'en_proceso') {
      _avisarYSalir(
        estado == 'adoptado'
            ? '${widget.pet.nombre} ya fue adoptado.'
            : '${widget.pet.nombre} ya tiene un proceso de adopción en curso.',
      );
      return;
    }

    try {
      final lista = await AdoptionService.listMine(petId: widget.pet.id);
      if (!mounted) return;
      final activa = lista.where((s) => s.isPending || s.isApproved);
      if (activa.isNotEmpty) {
        final solicitud = activa.first;
        _avisarYSalir(
          solicitud.isApproved
              ? 'Ya tienes una adopción aprobada para ${widget.pet.nombre}.'
              : 'Ya enviaste una solicitud para ${widget.pet.nombre}. Está pendiente de revisión.',
        );
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _revisando = false);
  }

  void _avisarYSalir(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    Navigator.pop(context);
  }

  String? _validarPaso() {
    if (_paso == 0) {
      if (_vivienda == null) return 'Elige el tipo de vivienda.';
      if (_patio == null) return 'Indica si la vivienda tiene patio.';
      if (_ninos == null) return 'Indica si hay niños en el hogar.';
      if (_otrasMascotas == null) return 'Indica si tienes otras mascotas.';
      if (_otrasMascotas == true && _otrasCtrl.text.trim().isEmpty) {
        return 'Cuéntenos un poco sobre sus otras mascotas.';
      }
      if (_otrasCtrl.text.trim().length > 200) {
        return 'La descripción de las otras mascotas no puede pasar de 200 caracteres.';
      }
    }
    if (_paso == 1) {
      if (_tiempo == null) return 'Indica cuánto tiempo puedes dedicarle.';
      if (_experiencia == null) return 'Indica si has tenido mascotas antes.';
      if (_motivacionCorta) return _avisoMotivacion;
    }
    if (_paso == 2) {
      if (_cedulaBytes == null) return 'Adjunta la foto de tu cédula.';
      if (_reciboBytes == null) return 'Adjunta la foto de un recibo de servicio público.';
    }
    return null;
  }

  bool get _motivacionCorta => _infoCtrl.text.trim().length < 20;

  void _alEscribirMotivacion(String _) {
    if (_mostrarError && !_motivacionCorta) {
      setState(() => _mostrarError = false);
    }
  }

  void _continuar() {
    final error = _validarPaso();
    if (error != null) {
      setState(() {
        if (_motivacionCorta) _mostrarError = true;
        _error = error == _avisoMotivacion ? null : error;
      });
      return;
    }
    setState(() {
      _error = null;
      _mostrarError = false;
      _paso += 1;
    });
    _mostrarDesdeArriba();
  }

  Future<void> _elegirFoto({required bool cedula}) async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.rosa),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.rosa),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null || !mounted) return;

    try {
      final archivo = await ImagePicker().pickImage(
        source: origen,
        imageQuality: 85,
      );
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      final nombre = archivo.name.trim().isEmpty
          ? (cedula ? 'cedula.jpg' : 'recibo.jpg')
          : archivo.name;
      if (!mounted) return;
      setState(() {
        _error = null;
        if (cedula) {
          _cedulaBytes = bytes;
          _cedulaNombre = nombre;
        } else {
          _reciboBytes = bytes;
          _reciboNombre = nombre;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la imagen: $e')),
      );
    }
  }

  /// Valida el correo confirmado y envía la solicitud de adopción.
  Future<void> _enviar() async {
    final error = _validarPaso();
    if (error != null) {
      setState(() {
        if (_motivacionCorta) _mostrarError = true;
        _error = error == _avisoMotivacion ? null : error;
      });
      return;
    }

    if (_cedulaBytes == null || _reciboBytes == null) {
      setState(() => _paso = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Adjunta la cédula y el recibo de servicio público antes de continuar.'),
        ),
      );
      return;
    }

    final correoFinal = _correoCtrl.text.trim();
    if (correoFinal.isEmpty || !correoFinal.contains('@') || !correoFinal.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Por favor, verifica que tu correo electrónico sea válido.'),
        ),
      );
      return;
    }

    if (!_correoPerfilConfirmado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Por favor confirma tu correo electrónico en la sección inferior.'),
        ),
      );
      return;
    }

    if (!_aceptoTerminos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Debes aceptar los términos y condiciones de adopción responsable para continuar.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final idCreado = await AdoptionService.submit(
        petId: widget.pet.id,
        housingType: _vivienda!,
        hasYard: _patio!,
        hasChildren: _ninos!,
        hasOtherPets: _otrasMascotas!,
        otherPets: _otrasCtrl.text.trim(),
        availableTime: _tiempo!,
        previousExperience: _experiencia!,
        additionalInfo: _infoCtrl.text.trim(),
        idCardBytes: _cedulaBytes!,
        idCardName: _cedulaNombre!,
        utilityBillBytes: _reciboBytes!,
        utilityBillName: _reciboNombre!,
        correoContacto: correoFinal,
      );

      final fechaAhora = DateTime.now();
      final idRadicado = (idCreado != null && idCreado.isNotEmpty)
          ? idCreado
          : 'ADOP-${fechaAhora.millisecondsSinceEpoch}';

      String? direccionUsuario;
      if (Session.idUsuario != null) {
        try {
          final usuario = await ApiService.obtenerUsuario(Session.idUsuario!);
          if (usuario.documentoIdentidad.trim().isNotEmpty) {
            Session.documentoIdentidad = usuario.documentoIdentidad.trim();
          }
          if (usuario.direccion.trim().isNotEmpty) {
            direccionUsuario = usuario.direccion.trim();
          }
        } catch (_) {}
      }

      final nombreCompleto = '${Session.nombre} ${Session.apellidos}'.trim().isEmpty
          ? 'Usuario Registrado'
          : '${Session.nombre} ${Session.apellidos}'.trim();

      Uint8List? pdfBytes;
      String? avisoPdf;
      try {
        pdfBytes = await AcuerdoAdopcionPdfService.generarPdfBytes(
          DatosActaAdopcion(
            idSolicitud: idRadicado,
            nombreUsuario: nombreCompleto,
            documentoUsuario: Session.documentoIdentidad.trim().isNotEmpty
                ? Session.documentoIdentidad.trim()
                : null,
            correoUsuario: correoFinal,
            telefonoUsuario: Session.telefono.isNotEmpty ? Session.telefono : null,
            direccionUsuario: direccionUsuario,
            tipoVivienda: _vivienda!,
            tienePatio: _patio!,
            tieneNinos: _ninos!,
            tieneOtrasMascotas: _otrasMascotas!,
            otrasMascotas: _otrasCtrl.text.trim(),
            tiempoDisponible: _tiempo!,
            experienciaPrevia: _experiencia!,
            motivacion: _infoCtrl.text.trim(),
            nombreMascota: widget.pet.nombre,
            especieMascota: widget.pet.especie,
            razaMascota: widget.pet.raza,
            edadMascota: widget.pet.edadTexto,
            sexoMascota: widget.pet.sexo,
            fechaAceptacion: fechaAhora,
            aceptoTerminos: true,
            fotoCedula: _cedulaBytes,
            fotoRecibo: _reciboBytes,
          ),
        );
        await AcuerdoAdopcionPdfService.descargarYGuardarPdf(
          bytes: pdfBytes,
          nombreMascota: widget.pet.nombre,
        );
      } catch (e) {
        avisoPdf =
            'La solicitud quedó registrada, pero no se pudo generar el acta en PDF. Puedes solicitarla de nuevo a la fundación.';
      }

      if (!mounted) return;
      final navigator = Navigator.of(context);
      FocusManager.instance.primaryFocus?.unfocus();
      navigator.pop(true);

      showDialog<void>(
        context: navigator.context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 52),
          title: Text(
            pdfBytes != null
                ? 'Solicitud enviada y acta descargada'
                : 'Solicitud enviada',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tu solicitud para adoptar a ${widget.pet.nombre} ha sido enviada a la Fundación Maritza Arévalo.\n\n'
                'El administrador revisará tus respuestas y datos. Cuando haya una decisión, podrás ver las observaciones en Mis adopciones.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (pdfBytes != null)
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
                              'Acta de adopción en PDF',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            Text(
                              'Se descargó el compromiso con tu aceptación expresa de los términos.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (avisoPdf != null)
                Text(
                  avisoPdf,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
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
                        'Notificación: Te llegará un correo a $correoFinal cuando la fundación apruebe o rechace tu solicitud.',
                        style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Radicado: #$idRadicado',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosa,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Aceptar'),
                  ),
                  if (pdfBytes != null) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        minimumSize: const Size.fromHeight(46),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () async {
                        final seguro = widget.pet.nombre.replaceAll(
                          RegExp(r'[^a-zA-Z0-9_\-]'),
                          '_',
                        );
                        final abrio = await compartirActaPorWhatsApp(
                          bytes: pdfBytes!,
                          nombreArchivo: 'Acta_Compromiso_Adopcion_$seguro.pdf',
                          mensaje:
                              'Hola, te comparto el acta de compromiso de adopción de ${widget.pet.nombre}.',
                        );
                        if (!ctx.mounted || abrio) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No se pudo adjuntar el PDF en WhatsApp. Ábrelo desde el celular para enviarlo con el documento.',
                            ),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Compartir vía WhatsApp',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      final mensaje = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text(mensaje)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: !_enviando,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
                child: Row(
                  children: [
                    const Icon(Icons.pets, color: AppColors.rosa, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Adoptar a ${widget.pet.nombre}',
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.texto,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                      onPressed: _enviando ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              if (_revisando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: CircularProgressIndicator(color: AppColors.rosa),
                )
              else
                Flexible(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Pasos(paso: _paso),
                          Flexible(
                            child: ListView(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                              children: [
                                _MascotaResumen(pet: widget.pet),
                                const SizedBox(height: 16),
                                if (_paso == 0) ..._pasoHogar(t),
                                if (_paso == 1) ..._pasoExperiencia(t),
                                if (_paso == 2) ..._pasoDocumentos(t),
                                if (_paso == 3) ..._pasoCompromiso(t),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _botones(),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Diálogo para editar el correo del perfil y persistirlo en la base de datos.
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
              Expanded(
                child: Text(
                  'Editar Correo de tu Perfil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
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
                    final texto = (v ?? '').trim();
                    if (texto.isEmpty) return 'El correo es obligatorio';
                    if (!texto.contains('@') || !texto.contains('.')) {
                      return 'Ingresa un correo electrónico válido';
                    }
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
                      final messenger = ScaffoldMessenger.of(this.context);
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

                        if (!mounted || !ctx.mounted) return;
                        setState(() {
                          _correoCtrl.text = nuevo;
                          _correoPerfilConfirmado = false;
                          _actualizandoCorreo = false;
                        });
                        Navigator.pop(ctx);
                        messenger.showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.green,
                            content: Text(
                              '¡Correo actualizado en tu perfil y base de datos con éxito!',
                            ),
                          ),
                        );
                      } catch (e) {
                        if (ctx.mounted) setModalState(() => _actualizandoCorreo = false);
                        if (mounted) setState(() => _actualizandoCorreo = false);
                        final msg = e.toString().replaceFirst('Exception: ', '');
                        messenger.showSnackBar(
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

  List<Widget> _pasoHogar(TextTheme t) => [
    Text(
      'Informacion sobre su hogar',
      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 14),
    _Opciones(
      titulo: '¿En qué tipo de hogar vivirá el peludito?',
      opciones: _viviendas,
      valor: _vivienda,
      onChanged: (v) => setState(() => _vivienda = v),
    ),
    const SizedBox(height: 16),
    _SiNo(
      titulo: '¿Su hogar cuenta con patio o zona verde?',
      valor: _patio,
      onChanged: (v) => setState(() => _patio = v),
    ),
    const SizedBox(height: 16),
    _SiNo(
      titulo: '¿Hay niños viviendo en su hogar?',
      valor: _ninos,
      onChanged: (v) => setState(() => _ninos = v),
    ),
    const SizedBox(height: 16),
    _SiNo(
      titulo: '¿Tiene actualmente otras mascotas?',
      valor: _otrasMascotas,
      onChanged: (v) => setState(() => _otrasMascotas = v),
    ),
    if (_otrasMascotas == true) ...[
      const SizedBox(height: 12),
      TextField(
        controller: _otrasCtrl,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Cuéntenos un poco sobre sus otras mascotas',
          hintText: 'Por ejemplo: un gato adulto y un perro pequeño',
          border: OutlineInputBorder(),
        ),
      ),
    ],
  ];

  List<Widget> _pasoExperiencia(TextTheme t) => [
    Text(
      'Tiempo y experiencia',
      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 14),
    _Opciones(
      titulo: '¿Cuánto tiempo al día compartirá con su nuevo compañero?',
      opciones: _tiempos,
      valor: _tiempo,
      onChanged: (v) => setState(() => _tiempo = v),
    ),
    const SizedBox(height: 16),
    _SiNo(
      titulo:
          '¿Ha tenido procesos de adopción anteriormente con nosotros?',
      valor: _experiencia,
      onChanged: (v) => setState(() => _experiencia = v),
    ),
    const SizedBox(height: 16),
    const Text(
      '¿Por qué desea adoptar a este compañerito?',
      style: TextStyle(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    TextField(
      controller: _infoCtrl,
      minLines: 4,
      maxLines: 7,
      maxLength: 2000,
      textCapitalization: TextCapitalization.sentences,
      onChanged: _alEscribirMotivacion,
      decoration: InputDecoration(
        hintText:
            'Cuéntenos qué lo motivó a elegirlo y por qué considera que su hogar es el lugar ideal para él.',
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
        errorText: _mostrarError && _motivacionCorta ? _avisoMotivacion : null,
        errorStyle: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ];

  List<Widget> _pasoDocumentos(TextTheme t) => [
    Text(
      'Documentos de verificación',
      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 14),
    _FotoCampo(
      titulo: 'Cédula',
      descripcion:
          'No olvides adjuntar la foto de tu documento de identidad para validar la solicitud.',
      bytes: _cedulaBytes,
      onElegir: () => _elegirFoto(cedula: true),
    ),
    const SizedBox(height: 14),
    _FotoCampo(
      titulo: 'Recibo',
      descripcion:
          'Por favor adjunta la foto de un recibo de servicio público para verificar tu dirección.',
      bytes: _reciboBytes,
      onElegir: () => _elegirFoto(cedula: false),
    ),
  ];

  /// Tarjeta del último paso: confirma el correo o abre el mismo diálogo de cambio.
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: AppColors.texto,
                    ),
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
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosa,
                    disabledBackgroundColor: AppColors.rosa.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _correoPerfilConfirmado
                      ? null
                      : () {
                          setState(() => _correoPerfilConfirmado = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                              content: Text(
                                'Correo $correoPerfil confirmado para recibir la notificación.',
                              ),
                            ),
                          );
                        },
                  child: const Text(
                    'Confirmar',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade800,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.rosa),
                  label: const Text(
                    'No es / Cambiar',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _dialogoEditarCorreoPerfil,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Texto formal de los términos, con la cláusula de rescisión destacada.
  void _verTerminosAdopcion() {
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
              child: const Icon(Icons.gavel_outlined, color: AppColors.rosa, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Términos de adopción',
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
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 460),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Al solicitar la adopción de ${widget.pet.nombre}, aceptas libre y voluntariamente los siguientes términos y condiciones:',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                ...AcuerdoAdopcionPdfService.clausulasAdopcion.map((c) {
                  final esAlerta = c['alerta'] == 'si';
                  final fila = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: esAlerta ? Colors.red.shade50 : AppColors.rosaSuave,
                        child: Text(
                          c['num']!,
                          style: TextStyle(
                            color: esAlerta ? Colors.red.shade800 : AppColors.rosa,
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
                              color: esAlerta ? Colors.red.shade900 : Colors.black87,
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
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: esAlerta
                        ? Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: fila,
                          )
                        : fila,
                  );
                }),
                const SizedBox(height: 4),
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
                          'Al confirmar, el sistema registrará tu constancia electrónica y generará el acta de adopción en PDF.',
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

  /// Paso final: resumen, aceptación expresa y descarga del acta.
  List<Widget> _pasoCompromiso(TextTheme t) {
    final nombre = '${Session.nombre} ${Session.apellidos}'.trim().isEmpty
        ? 'Usuario registrado'
        : '${Session.nombre} ${Session.apellidos}'.trim();

    return [
      Text(
        'Términos y confirmación',
        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'Revisa el resumen de tu solicitud y acepta los términos de adopción responsable de la Fundación Maritza Arévalo.',
        style: t.bodySmall?.copyWith(color: Colors.grey.shade600, height: 1.35),
      ),
      const SizedBox(height: 14),
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
            _resumenFila('Adoptante:', nombre),
            const Divider(height: 14),
            _resumenFila('Notificación al correo:', _correoCtrl.text.trim()),
            const Divider(height: 14),
            _resumenFila('Mascota:', widget.pet.nombre),
            const Divider(height: 14),
            _resumenFila('Vivienda:', _vivienda ?? '—'),
            const Divider(height: 14),
            _resumenFila('Documentos:', 'Cédula y recibo adjuntos'),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Material(
        color: _aceptoTerminos ? Colors.green.shade50 : Colors.grey.shade50,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _aceptoTerminos ? Colors.green.shade400 : Colors.grey.shade300,
            width: _aceptoTerminos ? 1.5 : 1,
          ),
        ),
        child: CheckboxListTile(
          value: _aceptoTerminos,
          activeColor: Colors.green,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          title: RichText(
            text: TextSpan(
              style: t.bodyMedium?.copyWith(color: AppColors.texto, height: 1.35),
              children: [
                const TextSpan(text: 'He leído y acepto los '),
                TextSpan(
                  text: 'términos y condiciones de adopción responsable',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.rosa,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = _verTerminosAdopcion,
                ),
                TextSpan(text: ' de ${widget.pet.nombre}.'),
              ],
            ),
          ),
          onChanged: (valor) => setState(() => _aceptoTerminos = valor ?? false),
          secondary: IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.rosa),
            tooltip: 'Ver términos completos',
            onPressed: _verTerminosAdopcion,
          ),
        ),
      ),
      const SizedBox(height: 14),
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
                'Al confirmar, el sistema registrará tu aceptación expresa y descargará el acta de compromiso de adopción en PDF, con tus datos, los de la mascota y la fecha.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800, height: 1.35),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _tarjetaConfirmacionCorreoPerfil(t),
    ];
  }

  Widget _resumenFila(String etiqueta, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _botones() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            if (_paso > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _enviando
                      ? null
                      : () {
                          setState(() {
                            _paso -= 1;
                            _error = null;
                            _mostrarError = false;
                          });
                          _mostrarDesdeArriba();
                        },
                  child: const Text('Atrás'),
                ),
              ),
            if (_paso > 0) const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosa,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _enviando ? null : (_paso < 3 ? _continuar : _enviar),
                child: _enviando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _paso < 3 ? 'Continuar' : 'Enviar Solicitud',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pasos extends StatelessWidget {
  final int paso;
  const _Pasos({required this.paso});

  @override
  Widget build(BuildContext context) {
    const etiquetas = ['Hogar', 'Tiempo', 'Documentos', 'Compromiso'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
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
                    fontSize: 10,
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

class _MascotaResumen extends StatelessWidget {
  final Pet pet;
  const _MascotaResumen({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: PetImage(url: pet.foto),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  [
                    pet.edadTexto,
                    pet.especie,
                    if ((pet.sexo ?? '').trim().isNotEmpty) pet.sexo!.trim(),
                  ].join(' · '),
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Opciones extends StatelessWidget {
  final String titulo;
  final List<String> opciones;
  final String? valor;
  final ValueChanged<String> onChanged;

  const _Opciones({
    required this.titulo,
    required this.opciones,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opcion in opciones)
              ChoiceChip(
                label: Text(opcion),
                selected: valor == opcion,
                selectedColor: AppColors.rosa,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: valor == opcion ? Colors.white : AppColors.texto,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => onChanged(opcion),
              ),
          ],
        ),
      ],
    );
  }
}

class _SiNo extends StatelessWidget {
  final String titulo;
  final bool? valor;
  final ValueChanged<bool> onChanged;

  const _SiNo({
    required this.titulo,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Sí'),
              selected: valor == true,
              selectedColor: AppColors.rosa,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: valor == true ? Colors.white : AppColors.texto,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => onChanged(true),
            ),
            ChoiceChip(
              label: const Text('No'),
              selected: valor == false,
              selectedColor: AppColors.rosa,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: valor == false ? Colors.white : AppColors.texto,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}

class _FotoCampo extends StatelessWidget {
  final String titulo;
  final String? descripcion;
  final Uint8List? bytes;
  final VoidCallback onElegir;

  const _FotoCampo({
    required this.titulo,
    this.descripcion,
    required this.bytes,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (descripcion != null) ...[
            const SizedBox(height: 4),
            Text(
              descripcion!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes!, height: 160, fit: BoxFit.cover),
            )
          else
            Container(
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.rosaSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_a_photo_outlined, color: AppColors.rosa, size: 32),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onElegir,
            icon: const Icon(Icons.image_outlined),
            label: Text(bytes == null ? 'Adjuntar imagen' : 'Cambiar imagen'),
          ),
        ],
      ),
    );
  }
}
