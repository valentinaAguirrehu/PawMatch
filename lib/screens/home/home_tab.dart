import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/screens/pets/pet_detail_screen.dart';
import 'package:paw_match/services/mascota_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/chip_seleccion.dart';
import 'package:paw_match/widgets/fundacion_banner.dart';
import 'package:paw_match/widgets/pet_card_color.dart';

/// Pestaña "Inicio": saludo, buscador, Fundación y perros para adoptar o apadrinar.
class HomeTab extends StatefulWidget {
  final VoidCallback onVerMascotas, onCerrarSesion;
  const HomeTab({
    super.key,
    required this.onVerMascotas,
    required this.onCerrarSesion,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<Pet>> _future = MascotaService.listar();
  bool _paraAdopcion = true; // false = para apadrinar

  Future<void> _recargar() async {
    setState(() => _future = MascotaService.listar());
    await _future.catchError((_) => <Pet>[]);
  }

  /// Solo perros, según el modo elegido.
  List<Pet> _filtrar(List<Pet> pets) => pets.where((p) {
    if (p.especie.toLowerCase() != 'perro') return false;
    return _paraAdopcion
        ? p.estadoAdopcion == 'disponible'
        : p.estadoApadrinamiento == 'disponible';
  }).toList();

  void _mostrarInfo(String titulo, String texto) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: t.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.rosa,
              ),
            ),
            const SizedBox(height: 12),
            Text(texto, style: t.bodyLarge?.copyWith(height: 1.5)),
          ],
        ),
      );
    },
  );

  void _abrirDetalle(Pet pet) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => PetDetailScreen(pet: pet)),
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _recargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // Encabezado
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¡Hola, ${Session.nombre}! 👋', style: t.bodyLarge),
                      Text(
                        'Encuentra a tu\ncompañero ideal',
                        style: t.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.texto,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Cerrar sesión',
                  onPressed: widget.onCerrarSesion,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Buscador (lleva a la lista completa, que ya tiene búsqueda y filtros)
            Material(
              color: AppColors.rosaSuave,
              shape: const StadiumBorder(
                side: BorderSide(color: AppColors.bordeRosa),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: widget.onVerMascotas,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.texto),
                      const SizedBox(width: 10),
                      Text('Buscar mascotas...', style: t.bodyLarge),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Fundación (misión y visión)
            FundacionBanner(
              onMision: () =>
                  _mostrarInfo('Nuestra misión', FundacionInfo.mision),
              onVision: () =>
                  _mostrarInfo('Nuestra visión', FundacionInfo.vision),
            ),
            const SizedBox(height: 24),

            // Selector adopción / apadrinamiento
            Row(
              children: [
                ChipSeleccion(
                  texto: 'Adopción',
                  icono: Icons.pets,
                  seleccionado: _paraAdopcion,
                  onTap: () => setState(() => _paraAdopcion = true),
                ),
                const SizedBox(width: 10),
                ChipSeleccion(
                  texto: 'Apadrinamiento',
                  icono: Icons.volunteer_activism,
                  seleccionado: !_paraAdopcion,
                  onTap: () => setState(() => _paraAdopcion = false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _paraAdopcion
                        ? 'Perros para adoptar'
                        : 'Perros para apadrinar',
                    style: t.titleLarge?.copyWith(color: AppColors.texto),
                  ),
                ),
                TextButton(
                  onPressed: widget.onVerMascotas,
                  child: const Text('Ver todos'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            FutureBuilder<List<Pet>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 280,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, size: 40),
                          const SizedBox(height: 8),
                          const Text('No pudimos cargar las mascotas'),
                          TextButton(
                            onPressed: _recargar,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final pets = _filtrar(snap.data!);
                if (pets.isEmpty) {
                  return SizedBox(
                    height: 160,
                    child: Center(
                      child: Text(
                        Session.isAdmin
                            ? 'No hay perros en esta categoría. Agrégalos desde "Gestionar".'
                            : 'Pronto verás aquí a los peludos que buscan hogar.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final visibles = pets.take(10).toList();
                return SizedBox(
                  height: 290,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visibles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, i) => PetCardColor(
                      pet: visibles[i],
                      color: AppColors.pastel[i % AppColors.pastel.length],
                      onTap: () => _abrirDetalle(visibles[i]),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
