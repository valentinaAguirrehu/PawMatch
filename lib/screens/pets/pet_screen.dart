import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/screens/adoption/adoption_requests_admin_screen.dart';
import 'package:paw_match/screens/adoption/my_adoptions_screen.dart';
import 'package:paw_match/screens/apadrinamiento/apadrinamiento_admin_screen.dart';
import 'package:paw_match/screens/apadrinamiento/mis_apadrinamientos_screen.dart';
import 'package:paw_match/screens/pets/pet_detail_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/pet_card.dart';

class _Categoria {
  final String filtro;
  final String etiqueta;
  final IconData icono;
  const _Categoria(this.filtro, this.etiqueta, this.icono);
}

/// Pantalla moderna de mascotas con diseño inspirado en la referencia:
/// cabecera con ubicación y notificaciones, filtro por especies tipo píldora,
/// barra de búsqueda y tarjetas horizontales.
class PetScreen extends StatefulWidget {
  const PetScreen({super.key});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  late Future<List<Pet>> _future = PetsService.listar();
  final TextEditingController _searchCtrl = TextEditingController();
  String _busqueda = '';
  String _especie = 'Todas';

  static const List<_Categoria> _categorias = [
    _Categoria('Todas', 'Todas', Icons.all_inclusive_rounded),
    _Categoria('Perro', 'Perros', Icons.pets_rounded),
    _Categoria('Gato', 'Gatos', Icons.cruelty_free_rounded),
    _Categoria('Otro', 'Otros', Icons.auto_awesome_rounded),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _recargar() async {
    setState(() => _future = PetsService.listar());
    await _future.catchError((_) => <Pet>[]);
  }

  List<Pet> _filtrar(List<Pet> pets) {
    return pets.where((p) {
      final esp = p.especie.toLowerCase();
      final coincideEspecie = switch (_especie) {
        'Todas' => true,
        'Otro' => esp != 'perro' && esp != 'gato',
        _ => esp == _especie.toLowerCase(),
      };
      final q = _busqueda.toLowerCase();
      final coincideTexto = q.isEmpty ||
          p.nombre.toLowerCase().contains(q) ||
          (p.raza ?? '').toLowerCase().contains(q);
      return coincideEspecie && coincideTexto;
    }).toList();
  }

  void _mostrarMenuSolicitudes(BuildContext context) {
    final bool esAdmin = Session.esAdmin;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  esAdmin ? Icons.inbox_outlined : Icons.assignment_outlined,
                  color: AppColors.rosa,
                ),
                const SizedBox(width: 8),
                Text(
                  esAdmin ? 'Solicitudes Recibidas' : 'Mis Solicitudes',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              leading: const CircleAvatar(
                backgroundColor: AppColors.rosaClaro,
                child: Icon(Icons.volunteer_activism, color: AppColors.rosa),
              ),
              title: Text(
                esAdmin ? 'Solicitudes de Apadrinamiento' : 'Mis Apadrinamientos',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                esAdmin
                    ? 'Revisar solicitudes enviadas por usuarios'
                    : 'Consulta estado de apadrinamiento y contratos',
              ),
              trailing: ValueListenableBuilder<int>(
                valueListenable: esAdmin
                    ? ApadrinamientoService.noLeidasAdmin
                    : ApadrinamientoService.noLeidasUsuario,
                builder: (context, count, child) => count > 0
                    ? Badge(label: Text('$count'), backgroundColor: Colors.redAccent)
                    : const Icon(Icons.chevron_right),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => esAdmin
                        ? const ApadrinamientoAdminScreen()
                        : const MisApadrinamientosScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              leading: const CircleAvatar(
                backgroundColor: AppColors.rosaClaro,
                child: Icon(Icons.pets, color: AppColors.rosa),
              ),
              title: Text(
                esAdmin ? 'Solicitudes de Adopción' : 'Mis Adopciones',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                esAdmin
                    ? 'Revisar solicitudes enviadas por usuarios'
                    : 'Consulta si tu adopción fue aprobada',
              ),
              trailing: ValueListenableBuilder<int>(
                valueListenable: esAdmin
                    ? AdoptionService.noLeidasAdmin
                    : AdoptionService.noLeidasUsuario,
                builder: (context, count, child) => count > 0
                    ? Badge(label: Text('$count'), backgroundColor: Colors.redAccent)
                    : const Icon(Icons.chevron_right),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => esAdmin
                        ? const AdoptionRequestsAdminScreen()
                        : const MyAdoptionsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool puedeVolver = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            // ───────── ENCABEZADO SUPERIOR (ESTILO REFERENCIA) ─────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Row(
                children: [
                  // Botón Volver o Avatar del Usuario
                  if (puedeVolver)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.rosa.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.pets, color: AppColors.rosa, size: 22),
                      ),
                    ),

                  const SizedBox(width: 12),

                  // Ubicación central con pin (como en la imagen de referencia)
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: AppColors.rosa,
                            ),
                            const SizedBox(width: 4),
                            const Flexible(
                              child: Text(
                                'Fundación Maritza Arévalo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Campanita de notificaciones (estilo botón circular blanco con sombra)
                  GestureDetector(
                    onTap: () => _mostrarMenuSolicitudes(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          Session.esAdmin
                              ? ApadrinamientoService.noLeidasAdmin
                              : ApadrinamientoService.noLeidasUsuario,
                          Session.esAdmin
                              ? AdoptionService.noLeidasAdmin
                              : AdoptionService.noLeidasUsuario,
                        ]),
                        builder: (context, child) {
                          final total = Session.esAdmin
                              ? (ApadrinamientoService.noLeidasAdmin.value +
                                  AdoptionService.noLeidasAdmin.value)
                              : (ApadrinamientoService.noLeidasUsuario.value +
                                  AdoptionService.noLeidasUsuario.value);
                          return Badge(
                            isLabelVisible: total > 0,
                            label: Text('$total'),
                            backgroundColor: Colors.redAccent,
                            child: const Icon(
                              Icons.notifications_outlined,
                              size: 20,
                              color: AppColors.rosa,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ───────── BARRA DE BÚSQUEDA FLOTANTE ─────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o raza...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.rosa,
                      size: 21,
                    ),
                    suffixIcon: _busqueda.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchCtrl.clear();
                                _busqueda = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onChanged: (v) => setState(() => _busqueda = v.trim()),
                ),
              ),
            ),

            // ───────── FILTRO POR ESPECIES EN PÍLDORAS ─────────
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                children: [
                  for (final cat in _categorias)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _especie = cat.filtro),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _especie == cat.filtro ? AppColors.rosa : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _especie == cat.filtro
                                    ? AppColors.rosa.withValues(alpha: 0.35)
                                    : Colors.black.withValues(alpha: 0.04),
                                blurRadius: _especie == cat.filtro ? 8 : 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat.icono,
                                size: 16,
                                color: _especie == cat.filtro
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.etiqueta,
                                style: TextStyle(
                                  color: _especie == cat.filtro
                                      ? Colors.white
                                      : const Color(0xFF4A4B4D),
                                  fontSize: 13,
                                  fontWeight: _especie == cat.filtro
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ───────── LISTA DE TARJETAS DE MASCOTAS ─────────
            Expanded(
              child: FutureBuilder<List<Pet>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.rosa),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                          const SizedBox(height: 10),
                          const Text(
                            'No pudimos cargar las mascotas',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                            onPressed: _recargar,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }

                  final pets = _filtrar(snap.data!);

                  if (pets.isEmpty) {
                    return RefreshIndicator(
                      color: AppColors.rosa,
                      onRefresh: _recargar,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 100),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.pets,
                                    size: 36,
                                    color: AppColors.rosaSuave,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No hay mascotas con este criterio',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3436),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Intenta cambiar el filtro o el término de búsqueda.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.rosa,
                    onRefresh: _recargar,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 6, bottom: 24),
                          itemCount: pets.length,
                          itemBuilder: (_, i) => PetCard(
                            pet: pets[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PetDetailScreen(pet: pets[i]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
