import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/noticia.dart';
import 'package:paw_match/services/noticias_service.dart';
import 'package:paw_match/widgets/pet_card.dart' show urlFoto;

/// Diálogo/Formulario para que el Administrador cree o edite una noticia.
class NoticiaFormDialog extends StatefulWidget {
  final Noticia? noticia;

  const NoticiaFormDialog({super.key, this.noticia});

  static Future<bool?> mostrar(BuildContext context, {Noticia? noticia}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NoticiaFormDialog(noticia: noticia),
    );
  }

  @override
  State<NoticiaFormDialog> createState() => _NoticiaFormDialogState();
}

class _NoticiaFormDialogState extends State<NoticiaFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final _tituloCtrl = TextEditingController(text: widget.noticia?.titulo);
  late final _lugarCtrl = TextEditingController(
      text: widget.noticia?.lugar ?? 'Fundación Maritza Arévalo');
  late final _contenidoCtrl =
      TextEditingController(text: widget.noticia?.contenido);

  late DateTime _fecha = widget.noticia != null && widget.noticia!.fecha.isNotEmpty
      ? DateTime.tryParse(widget.noticia!.fecha) ?? DateTime.now()
      : DateTime.now();

  late String? _fotoActual = widget.noticia?.imagen;
  Uint8List? _fotoBytes;
  String _fotoNombre = 'noticia.jpg';

  bool _guardando = false;
  bool get _esEdicion => widget.noticia != null;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _lugarCtrl.dispose();
    _contenidoCtrl.dispose();
    super.dispose();
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.rosaSuave,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.bordeRosa),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.bordeRosa),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.rosa, width: 2),
        ),
      );

  Future<void> _elegirFoto() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La imagen supera los 5 MB')),
          );
        }
        return;
      }
      setState(() {
        _fotoBytes = bytes;
        _fotoNombre = x.name.isEmpty ? 'noticia.jpg' : x.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir imagen: $e')),
        );
      }
    }
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Fecha de la noticia',
    );
    if (elegida != null && mounted) {
      setState(() => _fecha = elegida);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      String? rutaImagen = _fotoActual;
      if (_fotoBytes != null) {
        rutaImagen = await NoticiasService.subirFoto(_fotoBytes!, _fotoNombre);
      }

      final fechaIso =
          '${_fecha.year.toString().padLeft(4, '0')}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}';

      final noticia = Noticia(
        id: widget.noticia?.id ?? '',
        titulo: _tituloCtrl.text.trim(),
        contenido: _contenidoCtrl.text.trim(),
        imagen: rutaImagen,
        lugar: _lugarCtrl.text.trim().isNotEmpty
            ? _lugarCtrl.text.trim()
            : 'Fundación Maritza Arévalo',
        fecha: fechaIso,
      );

      if (_esEdicion) {
        await NoticiasService.actualizar(widget.noticia!.id, noticia);
      } else {
        await NoticiasService.crear(noticia);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esEdicion
                ? 'Noticia actualizada con éxito'
                : 'Noticia publicada con éxito',
          ),
          backgroundColor: AppColors.rosa,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _previewImagen() {
    Widget contenido;
    if (_fotoBytes != null) {
      contenido = Image.memory(_fotoBytes!, fit: BoxFit.cover);
    } else if (_fotoActual != null && _fotoActual!.isNotEmpty) {
      contenido = Image.network(
        urlFoto(_fotoActual!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.image, size: 40, color: AppColors.rosa),
      );
    } else {
      contenido = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.rosa),
          SizedBox(height: 6),
          Text(
            'Subir imagen de la noticia',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.texto,
            ),
          ),
          Text(
            'JPG o PNG · Máx. 5 MB',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _elegirFoto,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.rosaSuave,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.bordeRosa),
            ),
            clipBehavior: Clip.antiAlias,
            child: contenido,
          ),
        ),
        if (_fotoBytes != null || (_fotoActual != null && _fotoActual!.isNotEmpty))
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _elegirFoto,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Cambiar'),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _fotoBytes = null;
                  _fotoActual = null;
                }),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Quitar'),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaStr =
        '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cabecera
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.rosaSuave,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.newspaper_rounded, color: AppColors.rosa),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _esEdicion ? 'Editar Noticia' : 'Nueva Noticia de la Fundación',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Campos del formulario con scroll
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _previewImagen(),
                      const SizedBox(height: 12),

                      // Título
                      const Text(
                        'Título de la noticia',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.texto,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _tituloCtrl,
                        decoration: _deco('Ej: Gran Jornada de Adopción'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'El título es obligatorio' : null,
                      ),
                      const SizedBox(height: 14),

                      // Lugar / Ubicación
                      const Text(
                        'Lugar de la noticia o evento',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.texto,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _lugarCtrl,
                        decoration: _deco('Ej: Sede Principal, Cali o Parque La Flora'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'El lugar es obligatorio' : null,
                      ),
                      const SizedBox(height: 14),

                      // Selector de Fecha
                      const Text(
                        'Fecha de la noticia',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.texto,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _elegirFecha,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.rosaSuave,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.bordeRosa),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, color: AppColors.rosa, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                fechaStr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.texto,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Cambiar',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.rosa,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Contenido / Texto
                      const Text(
                        'Texto de la noticia',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.texto,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _contenidoCtrl,
                        decoration: _deco('Escribe la noticia o novedades para la comunidad...'),
                        maxLines: 5,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'El texto es obligatorio' : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Botón Guardar
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosa,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _guardando ? null : _guardar,
                    child: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _esEdicion ? 'Guardar Cambios' : 'Publicar Noticia',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
