import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
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
  String _frecuencia = 'mensual';

  Uint8List? _docBytes;
  String? _docNombre;

  bool _aceptoAcuerdo = false; // Inicia en false por requisito de auditoría
  bool _enviando = false;

  @override
  void dispose() {
    _motivacionCtrl.dispose();
    _montoCtrl.dispose();
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

  void _verTerminosAcuerdo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel, color: AppColors.rosa),
            SizedBox(width: 8),
            Text('Acuerdo de Responsabilidad'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Al solicitar el apadrinamiento de esta mascota en la Fundación Maritza Arévalo, te comprometes a:\n\n'
            '1. Brindar apoyo voluntario constante para la alimentación, cuidados médicos y bienestar de la mascota apadrinada.\n\n'
            '2. Proporcionar información veraz y comprobable mediante tu documento de identidad oficial.\n\n'
            '3. Mantener una comunicación respetuosa con la fundación a través de los canales oficiales (WhatsApp / presencial).\n\n'
            '4. Respetar las decisiones de la fundación sobre la salud y eventual adopción permanente de la mascota.\n\n'
            'Tu documento de identidad será protegido de forma confidencial y solo accesible por el personal autorizado.',
            style: TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _enviar() async {
    if (widget.pet.estaAdoptada) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.pet.mensajeFamiliaPara(Session.idUsuario)),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

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

    setState(() => _enviando = true);

    try {
      final monto = int.tryParse(_montoCtrl.text.replaceAll(RegExp(r'\D'), ''));
      await ApadrinamientoService.enviarSolicitud(
        idMascota: widget.pet.id,
        motivacion: _motivacionCtrl.text.trim(),
        montoAporte: monto,
        frecuenciaAporte: _frecuencia,
        bytesDocumento: _docBytes!,
        nombreArchivo: _docNombre!,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cierra bottom sheet

      widget.onEnviadaExitosamente?.call();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 54,
          ),
          title: const Text('¡Solicitud Enviada!'),
          content: Text(
            'Tu solicitud para apadrinar a ${widget.pet.nombre} ha sido enviada a la Fundación Maritza Arévalo.\n\n'
            'El administrador revisará tu motivación y datos. Una vez aprobada, recibirás una notificación y podrás ver la fecha de inicio y contactar a la fundación por WhatsApp.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
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
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Barra de arrastre
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Encabezado superior con botón de cerrar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
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
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          // Contenido con scroll
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  // Presentación destacada y centrada del perro: Foto, Nombre y Edad
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
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
                          child: ClipOval(
                            child: PetImage(url: widget.pet.foto),
                          ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
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
                  ),
                  const SizedBox(height: 18),
                  // Datos del solicitante (precargados)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.rosaClaro.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.rosa.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 20,
                              color: AppColors.rosa,
                            ),
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
                        if (Session.correo.isNotEmpty)
                          Text('Correo: ${Session.correo}', style: t.bodySmall),
                        if (Session.telefono.isNotEmpty)
                          Text(
                            'Teléfono: ${Session.telefono}',
                            style: t.bodySmall,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // PREGUNTA OBLIGATORIA: Motivación (máx 500 caracteres)
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
                        borderSide: const BorderSide(
                          color: AppColors.rosa,
                          width: 2,
                        ),
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

                  // Aporte voluntario
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
                              style: t.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
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
                              style: t.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _frecuencia,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'mensual',
                                  child: Text('Mensual'),
                                ),
                                DropdownMenuItem(
                                  value: 'quincenal',
                                  child: Text('Quincenal'),
                                ),
                                DropdownMenuItem(
                                  value: 'unica_vez',
                                  child: Text('Única vez'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _frecuencia = v ?? 'mensual'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Fotografía del documento de identidad
                  Text(
                    'Fotografía del documento de identidad *',
                    style: t.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.texto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sube una foto clara de tu documento de identidad (cédula). Será almacenada de forma privada.',
                    style: t.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _docBytes == null
                            ? Colors.grey.shade300
                            : Colors.green.shade400,
                        width: _docBytes == null ? 1 : 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_docBytes != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _docBytes!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Documento adjuntado',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  _docNombre ?? 'foto_documento.jpg',
                                  style: t.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Cambiar'),
                            onPressed: _seleccionarDocumento,
                          ),
                        ] else ...[
                          CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            child: const Icon(
                              Icons.badge_outlined,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Ningún archivo seleccionado',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.rosa,
                              side: const BorderSide(color: AppColors.rosa),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                            label: const Text('Subir foto'),
                            onPressed: _seleccionarDocumento,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Acuerdo de responsabilidad (inicia en false)
                  Material(
                    color: _aceptoAcuerdo
                        ? Colors.green.shade50
                        : Colors.grey.shade50,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      side: BorderSide(
                        color: _aceptoAcuerdo
                            ? Colors.green.shade300
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _aceptoAcuerdo,
                      activeColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      title: RichText(
                        text: TextSpan(
                          style: t.bodyMedium?.copyWith(color: AppColors.texto),
                          children: const [
                            TextSpan(text: 'He leído y acepto el '),
                            TextSpan(
                              text: 'acuerdo de responsabilidad y compromiso',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.rosa,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' para el apadrinamiento de esta mascota.',
                            ),
                          ],
                        ),
                      ),
                      onChanged: (val) {
                        setState(() => _aceptoAcuerdo = val ?? false);
                      },
                      secondary: IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          color: AppColors.rosa,
                        ),
                        tooltip: 'Ver acuerdo completo',
                        onPressed: _verTerminosAcuerdo,
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Botón enviar
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosa,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _enviando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _enviando
                          ? 'Enviando solicitud...'
                          : 'Enviar Solicitud de Apadrinamiento',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    onPressed: _enviando ? null : _enviar,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
