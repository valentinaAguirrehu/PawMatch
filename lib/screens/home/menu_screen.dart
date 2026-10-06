import 'package:flutter/material.dart';
import 'package:paw_match/screens/admin/pets_admin_screen.dart';
import 'package:paw_match/screens/home/home_tab.dart';
import 'package:paw_match/screens/pets/pet_screen.dart';
import 'package:paw_match/screens/users/profile_screen.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/nav_flotante.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _index = 0;

  // Cada pestaña tiene su propio Navigator: las pantallas que se abren desde
  // una pestaña (ej: el detalle de la mascota) aparecen DENTRO del menú,
  // encima del contenido pero sin tapar la barra flotante.
  late GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  late _ObservadorPaginas _obs = _ObservadorPaginas(_alCambiarPila);

  // true cuando la pestaña actual tiene una pantalla abierta (ej: el detalle).
  // En ese caso se oculta el AppBar del menú porque esa pantalla trae el suyo.
  bool _enDetalle = false;

  void _alCambiarPila() {
    // se difiere al final del frame para no llamar setState durante un build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final valor = _obs.profundidad > 0;
      if (valor != _enDetalle) setState(() => _enDetalle = valor);
    });
  }

  void _alTocarPestana(int i) {
    if (i == _index) {
      // tocar la pestaña actual vuelve a su pantalla principal
      _navKey.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _index = i;
      _enDetalle = false;
      _navKey = GlobalKey<NavigatorState>(); // navegador nuevo para la pestaña
      _obs = _ObservadorPaginas(_alCambiarPila);
    });
  }

  void _irA(int i) => _alTocarPestana(i);

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
      HomeTab(onVerMascotas: () => _irA(1), onCerrarSesion: _cerrarSesion),
      const PetScreen(),
      const ProfileScreen(),
      if (isAdmin) const PetsAdminScreen(),
    ];
    final paginaActual = paginas[_index];

    // Botón "atrás" del celular: primero cierra el detalle, luego vuelve a
    // Inicio, y solo desde Inicio sale de la pantalla.
    return PopScope(
      canPop: !_enDetalle && _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_enDetalle) {
          _navKey.currentState?.pop();
        } else if (_index != 0) {
          _irA(0);
        }
      },
      child: Scaffold(
        appBar: (_index == 0 || _enDetalle)
            ? null
            : AppBar(
                title: const Text('Paw Match'),
                actions: [
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    icon: const FeatureIcon.cerrarSesion(),
                    onPressed: _cerrarSesion,
                  ),
                ],
              ),
        body: Navigator(
          key: _navKey,
          observers: [_obs],
          onGenerateRoute: (_) =>
              MaterialPageRoute(builder: (_) => paginaActual),
        ),
        bottomNavigationBar: NavFlotante(
          indice: _index,
          onTap: _alTocarPestana,
          items: [
            const NavItem(FeatureIcon.inicio(), 'Inicio'),
            const NavItem(FeatureIcon.mascota(tamano: 24), 'Mascotas'),
            const NavItem(FeatureIcon.perfil(tamano: 24), 'Perfil'),
            if (isAdmin) const NavItem(FeatureIcon.gestionar(), 'Gestionar'),
          ],
        ),
      ),
    );
  }
}

/// Cuenta cuántas pantallas hay abiertas encima de la principal de la pestaña
/// (ignora diálogos, menús emergentes y bottom sheets).
class _ObservadorPaginas extends NavigatorObserver {
  _ObservadorPaginas(this.onCambio);

  final VoidCallback onCambio;
  int profundidad = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute != null) {
      profundidad++;
      onCambio();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute != null) {
      profundidad--;
      onCambio();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute != null) {
      profundidad--;
      onCambio();
    }
  }
}
