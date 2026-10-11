import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/widgets/dato_detalle.dart';
import 'package:paw_match/widgets/pet_card.dart'; // PetImage
import 'package:paw_match/widgets/tarjeta_blanca.dart';

/// Detalle de una mascota (RF04 / RF05): foto circular, datos, descripción,
/// personalidad y los botones Adoptar / Apadrinar.
/// `onAdoptar` y `onApadrinar` se conectan cuando existan RF08 y RF10.
class PetDetailScreen extends StatefulWidget {
  final Pet pet;
  final VoidCallback? onAdoptar, onApadrinar;
  const PetDetailScreen({
    super.key,
    required this.pet,
    this.onAdoptar,
    this.onApadrinar,
  });

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  // La personalidad vive en otra tabla: se consulta la mascota completa.
  late Future<Pet> _completa = PetsService.obtener(widget.pet.id);

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

  bool get _apadrinada => _t(widget.pet.estadoApadrinamiento) == 'apadrinado';
  bool get _puedeAdoptar => _estadoAdopcion == 'disponible';
  bool get _puedeApadrinar => !_apadrinada;

  /// Fecha de ingreso a la Fundación. Lee `fechaIngreso` del modelo Pet si existe
  /// (DateTime o texto ISO); si el modelo aún no lo tiene, simplemente no se muestra.
  DateTime? get _fechaIngreso {
    try {
      final v = (widget.pet as dynamic).fechaIngreso;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
    } catch (_) {}
    return null;
  }

  /// PNG/WebP = foto sin fondo (recorte): se ve entera sobre el rosado.
  /// JPG = foto normal: llena el círculo, como un retrato.
  bool get _esRecorte {
    final f = _t(widget.pet.foto).toLowerCase();
    return f.endsWith('.png') || f.endsWith('.webp');
  }

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  List<DatoDetalle> get _datos {
    final p = widget.pet;
    final edad = p.edad;
    final fecha = _fechaIngreso;
    return [
      if (edad != null)
        DatoDetalle(
          icono: Icons.cake_outlined,
          etiqueta: 'Edad',
          valor: '$edad ${edad == 1 ? 'año' : 'años'}',
        ),
      if (_t(p.sexo).isNotEmpty)
        DatoDetalle(
          icono: Icons.pets, // huella en lugar del ícono hombre/mujer
          etiqueta: 'Sexo',
          valor: _t(p.sexo),
        ),
      if (_t(p.raza).isNotEmpty)
        DatoDetalle(
          icono: Icons.category_outlined,
          etiqueta: 'Raza',
          valor: _t(p.raza),
        ),
      if (_t(p.tamano).isNotEmpty)
        DatoDetalle(
          icono: Icons.straighten,
          etiqueta: 'Tamaño',
          valor: _t(p.tamano),
        ),
      DatoDetalle(
        icono: Icons.vaccines_outlined,
        etiqueta: 'Vacunas',
        valor: p.vacunas == true ? 'Al día' : 'Pendiente',
      ),
      DatoDetalle(
        icono: Icons.medical_services_outlined,
        etiqueta: 'Esterilizado',
        valor: p.esterilizado == true ? 'Sí' : 'No',
      ),
      if (fecha != null)
        DatoDetalle(
          icono: Icons.event_outlined,
          etiqueta: 'Ingreso',
          valor: _fecha(fecha),
        ),
    ];
  }

  void _proximamente(String texto) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) {
    final p = widget.pet;
    final t = Theme.of(context).textTheme;
    final descripcion = _t(p.descripcion);
    final subtitulo = [
      _t(p.especie),
      _t(p.raza),
    ].where((e) => e.isNotEmpty).join(' · ');

    return Scaffold(
      backgroundColor: AppColors.rosa,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  const BackButton(color: Colors.white),
                  Expanded(
                    child: Text(
                      'Detalle de la mascota',
                      textAlign: TextAlign.center,
                      style: t.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        _fotoCircular(),
                        const SizedBox(height: 16),
                        Text(
                          p.nombre,
                          textAlign: TextAlign.center,
                          style: t.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitulo.isNotEmpty)
                          Text(
                            subtitulo,
                            style: t.bodyLarge?.copyWith(color: Colors.white70),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _pildora(
                              _estados[_estadoAdopcion] ?? _estadoAdopcion,
                              Icons.pets,
                            ),
                            if (_apadrinada)
                              _pildora('Apadrinada', Icons.volunteer_activism),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TarjetaBlanca(
                          titulo: 'Datos',
                          icono: Icons.info_outline,
                          child: LayoutBuilder(
                            builder: (_, c) {
                              final ancho = (c.maxWidth - 10) / 2;
                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final d in _datos)
                                    SizedBox(width: ancho, child: d),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        TarjetaBlanca(
                          titulo: 'Sobre ${p.nombre}',
                          icono: Icons.notes,
                          child: Text(
                            descripcion.isEmpty
                                ? 'Aún no hay una descripción.'
                                : descripcion,
                            style: t.bodyLarge?.copyWith(height: 1.45),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TarjetaBlanca(
                          titulo: 'Personalidad',
                          icono: Icons.favorite_border,
                          child: _personalidad(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _acciones(),
          ],
        ),
      ),
    );
  }

  // Foto circular con aro blanco sobre el rosado de la pantalla.
  Widget _fotoCircular() => Container(
    width: 236,
    height: 236,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.rosa,
      border: Border.all(color: Colors.white, width: 7),
    ),
    child: ClipOval(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: PetImage(
          url: widget.pet.foto,
          fit: _esRecorte ? BoxFit.contain : BoxFit.cover,
        ),
      ),
    ),
  );

  Widget _pildora(String texto, IconData icono) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: AppColors.rosa),
        const SizedBox(width: 6),
        Text(
          texto,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.rosa),
        ),
      ],
    ),
  );

  // Personalidad: solo se muestran las etiquetas de los rasgos que destacan,
  // sin la escala de 1 a 5.
  //   valor 1-2 => texto del extremo bajo  (ej: "Muy tranquila")
  //   valor 4-5 => texto del extremo alto  (ej: "Muy activa")
  //   valor 3   => no se muestra (el rasgo no destaca)
  Widget _personalidad() => FutureBuilder<Pet>(
    future: _completa,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator(
          color: AppColors.rosa,
          backgroundColor: AppColors.rosaClaro,
        );
      }
      if (snap.hasError) {
        return Row(
          children: [
            const Expanded(child: Text('No se pudo cargar la personalidad.')),
            TextButton(
              onPressed: () => setState(
                () => _completa = PetsService.obtener(widget.pet.id),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        );
      }

      final valores = snap.data!.personalidad;
      if (valores.isEmpty) {
        return const Text('Aún no hay datos de personalidad.');
      }

      final chips = <Widget>[];
      for (final r in rasgosMascota) {
        final v = valores[r.clave];
        if (v == null || v == 3) continue;
        // El texto concuerda con el sexo: "Muy activo" / "Muy activa", etc.
        final texto = v <= 2
            ? r.minimoPara(widget.pet.sexo)
            : r.maximoPara(widget.pet.sexo);
        chips.add(_chipRasgo(r.icono, texto));
      }

      if (chips.isEmpty) {
        return const Text('Tiene una personalidad equilibrada.');
      }
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    },
  );

  Widget _chipRasgo(IconData icono, String texto) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.rosaClaro,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: AppColors.rosa),
        const SizedBox(width: 6),
        Text(texto, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );

  // Botones Adoptar / Apadrinar fijos abajo
  Widget _acciones() {
    final tituloAdopcion = switch (_estadoAdopcion) {
      'en_proceso' => 'En proceso',
      'adoptado' => 'Adoptado',
      _ => 'Adoptar',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.rosa,
                    disabledBackgroundColor: Colors.white24,
                    disabledForegroundColor: Colors.white70,
                    minimumSize: const Size.fromHeight(54),
                    shape: const StadiumBorder(),
                    textStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.pets),
                  label: Text(tituloAdopcion),
                  onPressed: _puedeAdoptar
                      ? (widget.onAdoptar ??
                            () => _proximamente(
                              'La solicitud de adopción estará disponible pronto',
                            ))
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white54,
                    side: BorderSide(
                      color: _puedeApadrinar ? Colors.white : Colors.white38,
                      width: 1.5,
                    ),
                    minimumSize: const Size.fromHeight(54),
                    shape: const StadiumBorder(),
                    textStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.volunteer_activism),
                  label: Text(_apadrinada ? 'Apadrinada' : 'Apadrinar'),
                  onPressed: _puedeApadrinar
                      ? (widget.onApadrinar ??
                            () => _proximamente(
                              'El apadrinamiento estará disponible pronto',
                            ))
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
