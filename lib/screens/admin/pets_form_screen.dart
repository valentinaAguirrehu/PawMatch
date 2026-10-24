import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/match/dog_personality.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/widgets/pet_card.dart'; // PetImage

/// Formulario para agregar (pet == null) o editar una mascota.
/// Al guardar con éxito hace Navigator.pop con la mascota guardada.
class PetsFormScreen extends StatefulWidget {
  final Pet? pet;
  const PetsFormScreen({super.key, this.pet});

  @override
  State<PetsFormScreen> createState() => _PetsFormScreenState();
}

class _PetsFormScreenState extends State<PetsFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _nombre = TextEditingController(text: widget.pet?.nombre);
  late final _raza = TextEditingController(text: widget.pet?.raza);
  late final _edad = TextEditingController(text: widget.pet?.edad?.toString());
  late final _descripcion = TextEditingController(
    text: widget.pet?.descripcion,
  );

  late String _especie = widget.pet?.especie ?? 'Perro';
  late String _unidadEdad =
      (widget.pet?.unidadEdad == 'meses' || widget.pet?.unidadEdad == 'mes')
          ? 'meses'
          : 'anos';
  late String? _sexo = widget.pet?.sexo;
  late String? _tamano = widget.pet?.tamano;
  late final String _estadoAdopcion =
      widget.pet?.estadoAdopcion ?? 'disponible';
  late final String _estadoApadrinamiento =
      widget.pet?.estadoApadrinamiento ?? 'disponible';
  late final List<String> _estadosSalud = List<String>.from(
    widget.pet?.estadosSalud ?? const [opcionSinNecesidades],
  );
  late final _detalleSalud = TextEditingController(
    text: widget.pet?.detalleSalud,
  );

  // Foto: la que ya tenía (ruta en el servidor) o una nueva elegida del equipo
  late String? _fotoActual = widget.pet?.foto;
  Uint8List? _fotoBytes;
  String _fotoNombre = 'foto.jpg';

  final _personalidad = DogPersonalityController();

  bool _guardando = false;
  bool get _esEdicion => widget.pet != null;

  static const _especies = ['Perro', 'Gato', 'Otro'];
  static const _sexos = ['Macho', 'Hembra'];
  static const _tamanos = ['Pequeño', 'Mediano', 'Grande'];

  @override
  void initState() {
    super.initState();
    _personalidad.addListener(_refrescarPersonalidad);
    _nombre.addListener(_refrescarPersonalidad);
  }

  void _refrescarPersonalidad() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _personalidad.removeListener(_refrescarPersonalidad);
    _nombre.removeListener(_refrescarPersonalidad);
    _personalidad.dispose();
    _nombre.dispose();
    _raza.dispose();
    _edad.dispose();
    _descripcion.dispose();
    _detalleSalud.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Macho/masculino usa participio masculino; hembra/femenino, el femenino.
  bool _esMacho(String? sexo) {
    final s = (sexo ?? '').trim().toLowerCase();
    return s == 'macho' || s == 'masculino' || s.startsWith('masc');
  }

  String _mensajeGuardado(Pet pet) {
    final macho = _esMacho(pet.sexo);
    final nombre = '"${pet.nombre}"';
    if (_esEdicion) {
      return '$nombre ${macho ? 'actualizado' : 'actualizada'} exitosamente.';
    }
    return '$nombre ${macho ? 'agregado' : 'agregada'} exitosamente.';
  }

  // ---------------- Foto ----------------

  Future<void> _elegirFoto() async {
    ImageSource origen = ImageSource.gallery;

    // En el celular se puede elegir entre galería y cámara
    final esCelular =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (esCelular) {
      final elegido = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Elegir de la galería'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Tomar una foto'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      if (elegido == null) return;
      origen = elegido;
    }

    try {
      final x = await ImagePicker().pickImage(
        source: origen,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) _aviso('La foto supera los 5 MB. Elige una más liviana.');
        return;
      }
      setState(() {
        _fotoBytes = bytes;
        _fotoNombre = x.name.isEmpty ? 'foto.jpg' : x.name;
      });
    } catch (e) {
      if (mounted) _aviso('No se pudo abrir la foto: $e');
    }
  }

  void _quitarFoto() => setState(() {
    _fotoBytes = null;
    _fotoActual = null;
  });

  // ---------------- Guardar ----------------

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _guardando = true);

    try {
      // 1) si eligió una foto nueva, primero se sube y se obtiene su ruta
      String? ruta = _fotoActual;
      if (_fotoBytes != null) {
        ruta = await PetsService.subirFoto(_fotoBytes!, _fotoNombre);
      }

      // 2) se guarda la mascota con su personalidad
      final pet = Pet(
        id: widget.pet?.id ?? '',
        nombre: _nombre.text.trim(),
        especie: _especie,
        raza: _raza.text.trim(),
        edad: int.tryParse(_edad.text.trim()),
        unidadEdad: _unidadEdad,
        sexo: _sexo,
        tamano: _tamano,
        descripcion: _descripcion.text.trim(),
        esterilizado: _estadosSalud.contains('Esterilización realizada.'),
        vacunas: _estadosSalud.contains('Vacunación al día.'),
        foto: ruta,
        estadoAdopcion: _estadoAdopcion,
        estadoApadrinamiento: _estadoApadrinamiento,
        estadosSalud: _estadosSalud,
        detalleSalud: _detalleSalud.text.trim().isEmpty
            ? null
            : _detalleSalud.text.trim(),
        personalidad: _personalidad.personalidad,
      );

      final guardada = _esEdicion
          ? await PetsService.actualizar(widget.pet!.id, pet)
          : await PetsService.crear(pet);
      if (!mounted) return;
      _aviso(_mensajeGuardado(guardada));
      Navigator.pop(context, guardada);
    } catch (e) {
      if (mounted) _aviso(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ---------------- Estilo ----------------

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.rosaSuave,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.bordeRosa),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.bordeRosa),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.rosa, width: 2),
    ),
  );

  Widget _campo(String etiqueta, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            etiqueta,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child,
      ],
    ),
  );

  List<DropdownMenuItem<String>> _items(List<String> base, String? actual) {
    final lista = [...base];
    if (actual != null && actual.isNotEmpty && !lista.contains(actual)) {
      lista.add(actual);
    }
    return lista
        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
        .toList();
  }

  void _toggleEstadoSalud(String opcion) {
    setState(() {
      final esta = _estadosSalud.contains(opcion);
      if (esta) {
        _estadosSalud.remove(opcion);
      } else {
        // Regla 1: Si se selecciona 'Requiere vacunación.', desmarcar 'Vacunación al día.' y desmarcar 'No presenta necesidades'
        if (opcion == 'Requiere vacunación.') {
          _estadosSalud.remove('Vacunación al día.');
          _estadosSalud.remove(opcionSinNecesidades);
        }
        // Regla 2: Si se selecciona 'Vacunación al día.', desmarcar 'Requiere vacunación.'
        else if (opcion == 'Vacunación al día.') {
          _estadosSalud.remove('Requiere vacunación.');
        }
        // Regla 3: Si se selecciona 'Requiere esterilización.', desmarcar 'Esterilización realizada.' y desmarcar 'No presenta necesidades'
        else if (opcion == 'Requiere esterilización.') {
          _estadosSalud.remove('Esterilización realizada.');
          _estadosSalud.remove(opcionSinNecesidades);
        }
        // Regla 4: Si se selecciona 'Esterilización realizada.', desmarcar 'Requiere esterilización.'
        else if (opcion == 'Esterilización realizada.') {
          _estadosSalud.remove('Requiere esterilización.');
        }
        // Regla 5: Si se selecciona cualquier necesidad pendiente, desmarcar 'No presenta necesidades veterinarias pendientes.'
        else if (opcionesNecesidadesPendientes.contains(opcion)) {
          _estadosSalud.remove(opcionSinNecesidades);
        }
        // Regla 6: Si se selecciona 'No presenta necesidades veterinarias pendientes.', desmarcar todas las necesidades pendientes
        else if (opcion == opcionSinNecesidades) {
          _estadosSalud.removeWhere((e) => opcionesNecesidadesPendientes.contains(e));
        }

        _estadosSalud.add(opcion);
      }
    });
  }

  Future<void> _abrirSelectorEstadoSalud() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          void toggle(String opcion) {
            _toggleEstadoSalud(opcion);
            setModalState(() {});
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.healing_rounded, color: AppColors.rosa, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Estado de salud de la mascota',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.texto,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Selecciona todas las opciones aplicables. Las condiciones incompatibles se actualizan automáticamente.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      itemCount: opcionesEstadoSalud.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 48),
                      itemBuilder: (context, index) {
                        final opcion = opcionesEstadoSalud[index];
                        final seleccionado = _estadosSalud.contains(opcion);
                        final esNecesidad = opcionesNecesidadesPendientes.contains(opcion);
                        final esRealizado = opcionesProcedimientosRealizados.contains(opcion);

                        final IconData icono;
                        final Color colorIcono;
                        if (esNecesidad) {
                          icono = Icons.warning_amber_rounded;
                          colorIcono = Colors.orange.shade700;
                        } else if (esRealizado) {
                          icono = Icons.check_circle_outline_rounded;
                          colorIcono = Colors.green.shade700;
                        } else {
                          icono = Icons.health_and_safety_outlined;
                          colorIcono = AppColors.rosa;
                        }

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => toggle(opcion),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: seleccionado,
                                  activeColor: AppColors.rosa,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  onChanged: (_) => toggle(opcion),
                                ),
                                Icon(icono, size: 20, color: colorIcono),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    opcion,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                                      color: seleccionado ? AppColors.texto : Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosa,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Confirmar selección', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _selectorEstadoSaludMulti() {
    return FormField<List<String>>(
      initialValue: _estadosSalud,
      validator: (_) {
        if (_estadosSalud.isEmpty) {
          return 'El estado de salud es obligatorio';
        }
        return null;
      },
      builder: (state) {
        final tieneError = state.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                await _abrirSelectorEstadoSalud();
                state.didChange(_estadosSalud);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.rosaSuave,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tieneError ? Colors.red.shade700 : AppColors.bordeRosa,
                    width: tieneError ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 8),
                      child: Icon(Icons.healing_rounded, size: 20, color: AppColors.rosa),
                    ),
                    Expanded(
                      child: _estadosSalud.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                'Seleccionar estado de salud...',
                                style: TextStyle(color: Colors.grey, fontSize: 13.5),
                              ),
                            )
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _estadosSalud.map((op) {
                                final esNecesidad = opcionesNecesidadesPendientes.contains(op);
                                final esRealizado = opcionesProcedimientosRealizados.contains(op);
                                final Color fondoChip;
                                final Color bordeChip;
                                final Color textoChip;
                                if (esNecesidad) {
                                  fondoChip = const Color(0xFFFFF7ED);
                                  bordeChip = const Color(0xFFFDBA74);
                                  textoChip = const Color(0xFF9A3412);
                                } else if (esRealizado) {
                                  fondoChip = const Color(0xFFF0FDF4);
                                  bordeChip = const Color(0xFF86EFAC);
                                  textoChip = const Color(0xFF166534);
                                } else {
                                  fondoChip = Colors.white;
                                  bordeChip = AppColors.bordeRosa;
                                  textoChip = AppColors.rosa;
                                }

                                return Container(
                                  padding: const EdgeInsets.only(left: 8, right: 4, top: 2, bottom: 2),
                                  decoration: BoxDecoration(
                                    color: fondoChip,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: bordeChip),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          op,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: textoChip,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () {
                                          _toggleEstadoSalud(op);
                                          state.didChange(_estadosSalud);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: Icon(Icons.close, size: 14, color: textoChip),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 2, left: 4),
                      child: Icon(Icons.arrow_drop_down_rounded, color: AppColors.rosa, size: 26),
                    ),
                  ],
                ),
              ),
            ),
            if (tieneError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  state.errorText ?? '',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _cajaFoto() {
    final tieneFoto =
        _fotoBytes != null || (_fotoActual != null && _fotoActual!.isNotEmpty);

    Widget contenido;
    if (_fotoBytes != null) {
      contenido = Image.memory(_fotoBytes!, fit: BoxFit.contain);
    } else if (tieneFoto) {
      contenido = PetImage(url: _fotoActual, fit: BoxFit.contain);
    } else {
      contenido = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.rosa),
          SizedBox(height: 8),
          Text(
            'Subir foto de la mascota',
            style: TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'JPG, PNG o WebP · máx. 5 MB',
            style: TextStyle(color: AppColors.texto, fontSize: 12),
          ),
        ],
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _elegirFoto,
          child: CustomPaint(
            painter: _BordePunteado(),
            child: Container(
              height: 260,
              width: double.infinity,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: AppColors.rosaSuave,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: contenido,
            ),
          ),
        ),
        if (tieneFoto)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _elegirFoto,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Cambiar'),
              ),
              TextButton.icon(
                onPressed: _quitarFoto,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Quitar'),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.rosa,
      body: Column(
        children: [
          // Encabezado rosado
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 18),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _esEdicion ? 'Editar mascota' : 'Nueva mascota',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _esEdicion
                              ? 'Actualiza los datos de ${widget.pet!.nombre}'
                              : 'Completa los datos para publicar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Contenido blanco con esquinas redondeadas arriba
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _cajaFoto(),
                    const SizedBox(height: 14),
                    _campo(
                      'Nombre',
                      TextFormField(
                        controller: _nombre,
                        decoration: _deco('Ej: Luna'),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El nombre es obligatorio'
                            : null,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _campo(
                            'Especie',
                            DropdownButtonFormField<String>(
                              initialValue: _especie,
                              decoration: _deco(''),
                              items: _items(_especies, _especie),
                              onChanged: (v) =>
                                  setState(() => _especie = v ?? _especie),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _campo(
                            'Raza',
                            TextFormField(
                              controller: _raza,
                              decoration: _deco('Ej: Mestizo'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _campo(
                      'Edad',
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: TextFormField(
                              controller: _edad,
                              decoration: _deco('Cantidad (ej: 2)'),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final n = int.tryParse(v.trim());
                                if (n == null || n < 0) {
                                  return 'Número inválido';
                                }
                                if (_unidadEdad == 'meses' && n > 24) {
                                  return 'Máx. 24 meses';
                                }
                                if (_unidadEdad == 'anos' && n > 35) {
                                  return 'Máx. 35 años';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  _unidadEdad == 'meses' ? 'Meses' : 'Años',
                              decoration: _deco('Unidad'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Meses',
                                  child: Text('Meses'),
                                ),
                                DropdownMenuItem(
                                  value: 'Años',
                                  child: Text('Años'),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _unidadEdad =
                                      (v == 'Meses') ? 'meses' : 'anos';
                                });
                              },
                              onSaved: (v) {
                                if (v != null) {
                                  _unidadEdad =
                                      (v == 'Meses') ? 'meses' : 'anos';
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _campo(
                            'Sexo',
                            DropdownButtonFormField<String>(
                              initialValue: _sexo,
                              decoration: _deco('Elegir'),
                              items: _items(_sexos, _sexo),
                              onChanged: (v) => setState(() => _sexo = v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _campo(
                            'Tamaño',
                            DropdownButtonFormField<String>(
                              initialValue: _tamano,
                              decoration: _deco('Elegir'),
                              items: _items(_tamanos, _tamano),
                              onChanged: (v) => setState(() => _tamano = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _campo(
                      'Sobre ${_nombre.text.trim().isNotEmpty ? _nombre.text.trim() : (_esEdicion ? widget.pet!.nombre : 'la mascota')}',
                      TextFormField(
                        controller: _descripcion,
                        decoration: _deco('Cuéntanos sobre esta mascota...'),
                        maxLines: 4,
                      ),
                    ),
                    _campo(
                      'Estado de salud de la mascota *',
                      _selectorEstadoSaludMulti(),
                    ),
                    _campo(
                      'Condición de salud y recomendaciones veterinarias',
                      TextFormField(
                        controller: _detalleSalud,
                        decoration: _deco(
                          'Describe con mayor detalle la condición de salud de la mascota, sus necesidades actuales y las recomendaciones veterinarias si corresponde...',
                        ),
                        maxLines: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DogPersonality(
                      controller: _personalidad,
                      mascotaId: _esEdicion ? widget.pet!.id : null,
                    ),

                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosa,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: (_guardando || _personalidad.cargando)
                          ? null
                          : _guardar,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _guardando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _esEdicion
                                    ? 'Guardar cambios'
                                    : 'Publicar mascota',
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Borde punteado para la caja de la foto.
class _BordePunteado extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.rosa.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
