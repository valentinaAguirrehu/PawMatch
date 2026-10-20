import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/screens/adoption/my_adoptions_screen.dart';
import 'package:paw_match/screens/apadrinamiento/mis_apadrinamientos_screen.dart';
import 'package:paw_match/screens/apadrinamiento/solicitud_apadrinamiento_dialog.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/screens/pets/pet_detail_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/fundacion_banner.dart';
import 'package:paw_match/widgets/pet_card_color.dart';

/// Pestaña "Inicio": saludo, buscador, Fundación y perros para adoptar o apadrinar.
class HomeTab extends StatefulWidget {
  final VoidCallback onVerMascotas;
  const HomeTab({
    super.key,
    required this.onVerMascotas,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<Pet>> _future = PetsService.listar();

  Future<void> _recargar() async {
    setState(() {
      _future = PetsService.listar();
    });
    await _future.catchError((_) => <Pet>[]);
  }

  /// Perros disponibles para adopción o apadrinamiento.
  List<Pet> _filtrar(List<Pet> pets) => pets.where((p) {
    if (p.especie.toLowerCase() != 'perro') return false;
    return p.estadoAdopcion.toLowerCase() != 'adoptado';
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

  void _abrirApadrinamiento(Pet pet) {
    if (pet.estaAdoptada) return;
    SolicitudApadrinamientoDialog.mostrar(
      context,
      pet: pet,
      onEnviadaExitosamente: _recargar,
    );
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.rosa),
            SizedBox(width: 10),
            Text('Cerrar sesión'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rosa,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      ApadrinamientoService.detenerMonitoreo();
      AdoptionService.detenerMonitoreo();
      Session.cerrar();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    }
  }

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
                  onPressed: _confirmarCerrarSesion,
                  icon: const FeatureIcon.cerrarSesion(),
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
                      const FeatureIcon.buscar(color: AppColors.texto),
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

            // Encabezado sección perritos
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nuestros perritos',
                    style: t.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.texto,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onVerMascotas,
                  child: const Text('Ver todos'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: AdoptionService.noLeidasUsuario,
                    builder: (context, count, child) => Badge(
                      isLabelVisible: count > 0,
                      label: Text(count > 1 ? '$count' : 'Nuevo'),
                      backgroundColor: Colors.redAccent,
                      textColor: Colors.white,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppColors.rosa),
                        icon: const Icon(Icons.favorite_border, size: 16),
                        label: const Text('Mis adopciones'),
                        onPressed: () {
                          AdoptionService.marcarLeidasUsuario();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyAdoptionsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: ApadrinamientoService.noLeidasUsuario,
                    builder: (context, count, child) => Badge(
                      isLabelVisible: count > 0,
                      label: Text(count > 1 ? '$count' : 'Nuevo'),
                      backgroundColor: Colors.redAccent,
                      textColor: Colors.white,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.rosa,
                        ),
                        icon: const Icon(Icons.volunteer_activism, size: 16),
                        label: const Text('Mis apadrinamientos'),
                        onPressed: () {
                          ApadrinamientoService.marcarLeidasUsuario();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MisApadrinamientosScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
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
                          const FeatureIcon.sinConexion(tamano: 40),
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
                  height: 330,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visibles.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 14),
                    itemBuilder: (_, i) => PetCardColor(
                      pet: visibles[i],
                      color: AppColors.pastel[i % AppColors.pastel.length],
                      onTap: () => _abrirDetalle(visibles[i]),
                      onAdoptar: () => _abrirDetalle(visibles[i]),
                      onApadrinar: () => _abrirApadrinamiento(visibles[i]),
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
