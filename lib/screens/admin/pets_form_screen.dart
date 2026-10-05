import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/widgets/pet_card.dart'; // PetImage

/// Formulario para agregar (pet == null) o editar una mascota.
/// Al guardar con éxito hace Navigator.pop(context, true).
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
  late String? _sexo = widget.pet?.sexo;
  late String? _tamano = widget.pet?.tamano;
  late bool _esterilizado = widget.pet?.esterilizado ?? false;
  late bool _vacunas = widget.pet?.vacunas ?? false;
  late String _estadoAdopcion = widget.pet?.estadoAdopcion ?? 'disponible';
  late String _estadoApadrinamiento =
      widget.pet?.estadoApadrinamiento ?? 'disponible';

  // Foto: la que ya tenía (ruta en el servidor) o una nueva elegida del equipo
  late String? _fotoActual = widget.pet?.foto;
  Uint8List? _fotoBytes;
  String _fotoNombre = 'foto.jpg';

  // Personalidad: un valor de 1 a 5 por rasgo (3 = punto medio)
  final Map<String, double> _valores = {
    for (final r in rasgosMascota) r.clave: 3,
  };

  bool _guardando = false;
  bool _cargandoPerfil = false;
  bool get _esEdicion => widget.pet != null;

  static const _especies = ['Perro', 'Gato', 'Otro'];
  static const _sexos = ['Macho', 'Hembra'];
  static const _tamanos = ['Pequeño', 'Mediano', 'Grande'];

  @override
  void initState() {
    super.initState();
    if (_esEdicion) _cargarPersonalidad();
  }

  /// La lista de mascotas no trae la personalidad; se consulta al editar.
  Future<void> _cargarPersonalidad() async {
    setState(() => _cargandoPerfil = true);
    try {
      final completa = await PetsService.obtener(widget.pet!.id);
      if (!mounted) return;
      setState(() {
        completa.personalidad.forEach((clave, valor) {
          if (_valores.containsKey(clave)) {
            _valores[clave] = valor.clamp(1, 5).toDouble();
          }
        });
      });
    } catch (_) {
      if (mounted) _aviso('No se pudo cargar la personalidad actual');
    } finally {
      if (mounted) setState(() => _cargandoPerfil = false);
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _raza.dispose();
    _edad.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
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
        sexo: _sexo,
        tamano: _tamano,
        descripcion: _descripcion.text.trim(),
        esterilizado: _esterilizado,
        vacunas: _vacunas,
        foto: ruta,
        estadoAdopcion: _estadoAdopcion,
        estadoApadrinamiento: _estadoApadrinamiento,
        personalidad: {
          for (final r in rasgosMascota) r.clave: _valores[r.clave]!.round(),
        },
      );

      if (_esEdicion) {
        await PetsService.actualizar(widget.pet!.id, pet);
      } else {
        await PetsService.crear(pet);
      }
      if (!mounted) return;
      _aviso(
        _esEdicion ? '${pet.nombre} actualizada' : '${pet.nombre} agregada',
      );
      Navigator.pop(context, true);
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

  Widget _seccionPersonalidad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personalidad',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Evalúa a la mascota de 1 a 5 en cada rasgo. Estas respuestas se '
          'usan para calcular el match con los adoptantes.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        if (_cargandoPerfil)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(color: AppColors.rosa),
          ),
        const SizedBox(height: 8),
        for (final r in rasgosMascota)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            decoration: BoxDecoration(
              color: AppColors.rosaSuave,
              border: Border.all(color: AppColors.bordeRosa),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(r.icono, size: 18, color: AppColors.rosa),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.titulo,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _valores[r.clave]!.round().toString(),
                      style: const TextStyle(
                        color: AppColors.rosa,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(r.pregunta, style: const TextStyle(fontSize: 13)),
                Slider(
                  value: _valores[r.clave]!,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: AppColors.rosa,
                  label: _valores[r.clave]!.round().toString(),
                  onChanged: _cargandoPerfil
                      ? null
                      : (v) => setState(() => _valores[r.clave] = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '1 · ${r.minimo}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '5 · ${r.maximo}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
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
                            'Edad (años)',
                            TextFormField(
                              controller: _edad,
                              decoration: _deco('Ej: 2'),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final n = int.tryParse(v.trim());
                                if (n == null || n < 0 || n > 40) {
                                  return '0 a 40';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _campo(
                            'Raza',
                            TextFormField(
                              controller: _raza,
                              decoration: _deco('Ej: Mestizo'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                      ],
                    ),
                    _campo(
                      'Tamaño',
                      DropdownButtonFormField<String>(
                        initialValue: _tamano,
                        decoration: _deco('Elegir'),
                        items: _items(_tamanos, _tamano),
                        onChanged: (v) => setState(() => _tamano = v),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _seccionPersonalidad(),
                    const SizedBox(height: 10),
                    _campo(
                      'Descripción',
                      TextFormField(
                        controller: _descripcion,
                        decoration: _deco('Cuéntanos sobre esta mascota...'),
                        maxLines: 4,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Vacunas al día'),
                      value: _vacunas,
                      onChanged: (v) => setState(() => _vacunas = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Esterilizado'),
                      value: _esterilizado,
                      onChanged: (v) => setState(() => _esterilizado = v),
                    ),
                    const SizedBox(height: 8),
                    _campo(
                      'Estado de adopción',
                      DropdownButtonFormField<String>(
                        initialValue: _estadoAdopcion,
                        decoration: _deco(''),
                        items: const [
                          DropdownMenuItem(
                            value: 'disponible',
                            child: Text('Disponible'),
                          ),
                          DropdownMenuItem(
                            value: 'en_proceso',
                            child: Text('En proceso'),
                          ),
                          DropdownMenuItem(
                            value: 'adoptado',
                            child: Text('Adoptado'),
                          ),
                        ],
                        onChanged: (v) => setState(
                          () => _estadoAdopcion = v ?? _estadoAdopcion,
                        ),
                      ),
                    ),
                    _campo(
                      'Estado de apadrinamiento',
                      DropdownButtonFormField<String>(
                        initialValue: _estadoApadrinamiento,
                        decoration: _deco(''),
                        items: const [
                          DropdownMenuItem(
                            value: 'disponible',
                            child: Text('Disponible'),
                          ),
                          DropdownMenuItem(
                            value: 'apadrinado',
                            child: Text('Apadrinado'),
                          ),
                        ],
                        onChanged: (v) => setState(
                          () => _estadoApadrinamiento =
                              v ?? _estadoApadrinamiento,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosa,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: (_guardando || _cargandoPerfil)
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
