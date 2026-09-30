import 'package:flutter/material.dart';
import '../models/pet.dart';
import '../services/mascota_service.dart';
import '../services/session.dart';
import '../widgets/pet_card.dart';
import 'admin/mascotas_admin_screen.dart';
import 'mascota_detalle_screen.dart';
import 'mascotas_screen.dart';
import 'welcome_screen.dart';

/// Pantalla principal después de iniciar sesión.
/// Usuario:        Inicio | Mascotas
/// Administrador:  Inicio | Mascotas | Gestionar
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _index = 0;

  void _irA(int i) => setState(() => _index = i);

  void _cerrarSesion() {
    Session.cerrar();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Session.isAdmin;

    final paginas = <Widget>[
      HomeTab(
        onVerMascotas: () => _irA(1),
        onGestionar: isAdmin ? () => _irA(2) : null,
      ),
      const MascotasScreen(),
      if (isAdmin) const MascotasAdminScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paw Match'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: paginas[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _irA,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: 'Mascotas',
          ),
          if (isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.edit_note_outlined),
              selectedIcon: Icon(Icons.edit_note),
              label: 'Gestionar',
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Pestaña "Inicio"
// ------------------------------------------------------------------
class HomeTab extends StatefulWidget {
  final VoidCallback onVerMascotas;
  final VoidCallback? onGestionar; // null si no es administrador
  const HomeTab({super.key, required this.onVerMascotas, this.onGestionar});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<Pet>> _future = MascotaService.listar(estado: 'disponible');

  Future<void> _recargar() async {
    setState(() => _future = MascotaService.listar(estado: 'disponible'));
    await _future.catchError((_) => <Pet>[]);
  }

  void _proximamente(String funcion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$funcion estará disponible próximamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _recargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('¡Hola, ${Session.nombre}! 👋', style: t.headlineSmall),
          const SizedBox(height: 4),
          const Text('Hoy puede ser el día de conocer a tu compañero'),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Accion(
                icon: Icons.pets,
                label: 'Adoptar',
                onTap: widget.onVerMascotas,
              ),
              _Accion(
                icon: Icons.favorite,
                label: 'Match',
                onTap: () => _proximamente('El match'),
              ),
              _Accion(
                icon: Icons.volunteer_activism,
                label: 'Apadrinar',
                onTap: () => _proximamente('El apadrinamiento'),
              ),
              if (widget.onGestionar != null)
                _Accion(
                  icon: Icons.edit_note,
                  label: 'Gestionar',
                  onTap: widget.onGestionar!,
                ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mascotas en adopción', style: t.titleMedium),
              TextButton(
                onPressed: widget.onVerMascotas,
                child: const Text('Ver todas'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Carrusel(future: _future, onReintentar: _recargar),
        ],
      ),
    );
  }
}

class _Accion extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Accion({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _Carrusel extends StatelessWidget {
  final Future<List<Pet>> future;
  final VoidCallback onReintentar;
  const _Carrusel({required this.future, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Pet>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return SizedBox(
            height: 240,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 40),
                  const SizedBox(height: 8),
                  const Text('No pudimos cargar las mascotas'),
                  TextButton(
                    onPressed: onReintentar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final pets = snap.data!;
        if (pets.isEmpty) {
          return SizedBox(
            height: 160,
            child: Center(
              child: Text(
                Session.isAdmin
                    ? 'Aún no hay mascotas. Ve a "Gestionar" para agregar la primera.'
                    : 'Pronto verás aquí a los peludos que buscan hogar.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final visibles = pets.take(10).toList();
        return SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visibles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(
              width: 170,
              child: PetCard(
                pet: visibles[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MascotaDetalleScreen(pet: visibles[i]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
