import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/services/mascota_service.dart';
import 'package:paw_match/widgets/dato_chip.dart';
import 'package:paw_match/widgets/pet_card.dart'; // PetImage
import 'package:paw_match/widgets/rasgo_barra.dart';

/// Detalle de una mascota (RF04 / RF05). Se abre con:
///   Navigator.push(context, MaterialPageRoute(builder: (_) => MascotaDetalleScreen(pet: pet)));
/// `onAdoptar` y `onApadrinar` se conectan cuando existan RF08 y RF10.
class MascotaDetalleScreen extends StatefulWidget {
  final Pet pet;
  final VoidCallback? onAdoptar, onApadrinar;
  const MascotaDetalleScreen({
    super.key,
    required this.pet,
    this.onAdoptar,
    this.onApadrinar,
  });

  @override
  State<MascotaDetalleScreen> createState() => _MascotaDetalleScreenState();
}

class _MascotaDetalleScreenState extends State<MascotaDetalleScreen> {
  // La lista no trae la personalidad: se consulta la mascota completa.
  late Future<Pet> _completa = MascotaService.obtener(widget.pet.id);

  static const _estados = {
    'disponible': 'Disponible',
    'en_proceso': 'En proceso',
    'adoptado': 'Adoptado',
  };

  String _t(String? v) => v?.trim() ?? '';

  String get _estadoAdopcion {
    final e = _t(widget.pet.estadoAdopcion);
    return e.isEmpty ? 'disponible' : e;
  }

  bool get _puedeAdoptar => _estadoAdopcion == 'disponible';
  bool get _puedeApadrinar =>
      _t(widget.pet.estadoApadrinamiento) != 'apadrinado';

  List<String> get _datos {
    final p = widget.pet;
    final edad = p.edad;
    return [
      if (edad != null) '$edad ${edad == 1 ? 'año' : 'años'}',
      if (_t(p.sexo).isNotEmpty) _t(p.sexo),
      if (_t(p.tamano).isNotEmpty) 'Tamaño ${_t(p.tamano).toLowerCase()}',
      if (p.vacunas == true) 'Vacunas al día',
      if (p.esterilizado == true) 'Esterilizado',
    ];
  }

  void _proximamente(String texto) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) {
    final p = widget.pet;
    final t = Theme.of(context).textTheme;
    final raza = _t(p.raza);
    final descripcion = _t(p.descripcion);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tarjetaFoto(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nombre,
                          style: t.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.marron,
                          ),
                        ),
                        if (raza.isNotEmpty) Text(raza, style: t.bodyLarge),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _datos.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) => DatoChip(
                              texto: _datos[i],
                              color:
                                  AppColors.pastel[i % AppColors.pastel.length],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Sobre ${p.nombre}',
                          style: t.titleMedium?.copyWith(
                            color: AppColors.marron,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          descripcion.isEmpty
                              ? 'Aún no hay una descripción.'
                              : descripcion,
                          style: t.bodyLarge?.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Personalidad',
                          style: t.titleMedium?.copyWith(
                            color: AppColors.marron,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _personalidad(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _barraInferior(),
        ],
      ),
    );
  }

  // ───── Tarjeta de la foto (fondo suave + foto redondeada) ─────
  Widget _tarjetaFoto() {
    final p = widget.pet;
    final estado = _estados[_estadoAdopcion] ?? _estadoAdopcion;
    final apadrinada = _t(p.estadoApadrinamiento) == 'apadrinado';

    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.durazno, AppColors.rosaSuave],
          ),
        ),
        child: SizedBox(
          height: 340,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PetImage(url: p.foto),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _botonRedondo(
                    Icons.arrow_back,
                    () => Navigator.pop(context),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _pildora(estado, AppColors.naranja, Colors.white),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _pildora(
                    [
                      _t(p.especie),
                      if (apadrinada) 'Apadrinada',
                    ].where((e) => e.isNotEmpty).join(' · '),
                    Colors.black.withValues(alpha: 0.4),
                    Colors.white,
                    icono: Icons.pets,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonRedondo(IconData icono, VoidCallback onTap) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icono, size: 22, color: AppColors.marron),
      ),
    ),
  );

  Widget _pildora(String texto, Color fondo, Color letra, {IconData? icono}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 16, color: letra),
              const SizedBox(width: 6),
            ],
            Text(
              texto,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: letra),
            ),
          ],
        ),
      );

  // ───── Personalidad (se carga aparte) ─────
  Widget _personalidad() => FutureBuilder<Pet>(
    future: _completa,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(color: AppColors.naranja),
        );
      }
      if (snap.hasError) {
        return Row(
          children: [
            const Expanded(child: Text('No se pudo cargar la personalidad.')),
            TextButton(
              onPressed: () => setState(
                () => _completa = MascotaService.obtener(widget.pet.id),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        );
      }
      final valores = snap.data!.personalidad;
      return Column(
        children: [
          for (final r in rasgosMascota)
            RasgoBarra(
              icono: r.icono,
              titulo: r.titulo,
              valor: (valores[r.clave] ?? 3).toInt().clamp(1, 5),
              minimo: '${r.minimo}',
              maximo: '${r.maximo}',
            ),
        ],
      );
    },
  );

  // ───── Botón grande fijo abajo ─────
  Widget _barraInferior() => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.naranja,
                minimumSize: const Size.fromHeight(56),
                shape: const StadiumBorder(),
                textStyle: Theme.of(context).textTheme.titleMedium,
              ),
              onPressed: _puedeAdoptar
                  ? (widget.onAdoptar ??
                        () => _proximamente(
                          'La solicitud de adopción estará disponible pronto',
                        ))
                  : null,
              child: Text(switch (_estadoAdopcion) {
                'en_proceso' => 'En proceso de adopción',
                'adoptado' => 'Ya fue adoptado',
                _ => 'Quiero adoptar',
              }),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 56,
            width: 56,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
                side: const BorderSide(color: AppColors.naranja, width: 1.5),
              ),
              onPressed: _puedeApadrinar
                  ? (widget.onApadrinar ??
                        () => _proximamente(
                          'El apadrinamiento estará disponible pronto',
                        ))
                  : null,
              child: const Icon(
                Icons.volunteer_activism,
                color: AppColors.naranja,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class MascotaFormScreen extends StatefulWidget {
  final Pet? pet;
  const MascotaFormScreen({super.key, this.pet});

  @override
  State<MascotaFormScreen> createState() => _MascotaFormScreenState();
}

class _MascotaFormScreenState extends State<MascotaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _raza;
  late final TextEditingController _edad;
  late final TextEditingController _descripcion;
  late String _especie;
  late String _sexo;
  late String _tamano;
  bool _guardando = false;

  bool get _edicion => widget.pet != null;

  @override
  void initState() {
    super.initState();
    final pet = widget.pet;
    _nombre = TextEditingController(text: pet?.nombre ?? '');
    _raza = TextEditingController(text: pet?.raza ?? '');
    _edad = TextEditingController(text: pet?.edad?.toString() ?? '');
    _descripcion = TextEditingController(text: pet?.descripcion ?? '');
    _especie = pet?.especie ?? 'Perro';
    _sexo = pet?.sexo ?? 'Macho';
    _tamano = pet?.tamano ?? 'Mediano';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _raza.dispose();
    _edad.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    final anterior = widget.pet;
    final pet = Pet(
      id: anterior?.id ?? '',
      nombre: _nombre.text.trim(),
      especie: _especie,
      raza: _raza.text.trim().isEmpty ? null : _raza.text.trim(),
      edad: int.tryParse(_edad.text.trim()),
      sexo: _sexo,
      tamano: _tamano,
      descripcion: _descripcion.text.trim(),
      esterilizado: anterior?.esterilizado ?? false,
      vacunas: anterior?.vacunas ?? false,
      foto: anterior?.foto,
      estadoAdopcion: anterior?.estadoAdopcion ?? 'disponible',
      estadoApadrinamiento: anterior?.estadoApadrinamiento ?? 'disponible',
      personalidad: anterior?.personalidad ?? const {},
    );

    try {
      if (_edicion) {
        await MascotaService.actualizar(anterior!.id, pet);
      } else {
        await MascotaService.crear(pet);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_edicion ? 'Editar mascota' : 'Nueva mascota')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nombre,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escribe el nombre de la mascota'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _especie,
            decoration: const InputDecoration(labelText: 'Especie'),
            items: const ['Perro', 'Gato', 'Otro']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _especie = value!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _raza,
            decoration: const InputDecoration(labelText: 'Raza'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _edad,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Edad'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _sexo,
            decoration: const InputDecoration(labelText: 'Sexo'),
            items: const ['Macho', 'Hembra']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _sexo = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _tamano,
            decoration: const InputDecoration(labelText: 'Tamaño'),
            items: const ['Pequeño', 'Mediano', 'Grande']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _tamano = value!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descripcion,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_edicion ? 'Guardar cambios' : 'Publicar mascota'),
          ),
        ],
      ),
    ),
  );
}
