import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/admin/admins_admin_screen.dart';
import 'package:paw_match/screens/admin/pets_admin_screen.dart';
import 'package:paw_match/screens/admin/seccion_admin_screen.dart';
import 'package:paw_match/screens/admin/users_admin_screen.dart';
import 'package:paw_match/screens/home/home_tab.dart';
import 'package:paw_match/screens/pets/pet_screen.dart';
import 'package:paw_match/screens/users/profile_screen.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/nav_flotante.dart';

/// Opciones del menú desplegable del administrador (último ícono de la barra).
enum _Gestion {
  mascotas('Mascotas', Icons.pets),
  adopcion('Adopción', Icons.favorite_border),
  apadrinamiento('Apadrinamiento', Icons.volunteer_activism),
  seguimiento('Seguimiento de adopción', Icons.timeline),
  usuarios('Usuarios', Icons.people_outline),
  administradores('Administradores', Icons.admin_panel_settings_outlined);

  final String etiqueta;
  final IconData icono;
  const _Gestion(this.etiqueta, this.icono);
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _index = 0;
  _Gestion _seccion = _Gestion.mascotas;

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

  /// Cambia de pestaña (o de sección de gestión) con un navegador nuevo.
  void _cambiarA(int i, {_Gestion? seccion}) {
    setState(() {
      _index = i;
      if (seccion != null) _seccion = seccion;
      _enDetalle = false;
      _navKey = GlobalKey<NavigatorState>();
      _obs = _ObservadorPaginas(_alCambiarPila);
    });
  }

  void _alTocarPestana(int i) {
    // Último ícono (solo administrador): abre el menú desplegable
    if (Session.isAdmin && i == 3) {
      _mostrarMenuGestion();
      return;
    }
    if (i == _index) {
      // tocar la pestaña actual vuelve a su pantalla principal
      _navKey.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    _cambiarA(i);
  }

  void _irA(int i) => _alTocarPestana(i);

  Future<void> _mostrarMenuGestion() async {
    final tam = MediaQuery.of(context).size;
    final inferior = MediaQuery.of(context).padding.bottom;

    // Ajusta estos dos números si el menú queda muy pegado o muy separado
    // de la barra flotante.
    const altoBarra = 96.0; // alto de la barra flotante + su margen
    final altoMenu = _Gestion.values.length * 48.0 + 16;

    final elegida = await showMenu<_Gestion>(
      context: context,
      position: RelativeRect.fromLTRB(
        tam.width - 270, // pegado a la derecha, bajo el último ícono
        tam.height - inferior - altoBarra - altoMenu,
        16,
        0,
      ),
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      items: [
        for (final g in _Gestion.values)
          PopupMenuItem<_Gestion>(
            value: g,
            child: Row(
              children: [
                Icon(g.icono, size: 20, color: AppColors.rosa),
                const SizedBox(width: 12),
                Text(g.etiqueta),
              ],
            ),
          ),
      ],
    );

    if (elegida != null && mounted) _cambiarA(3, seccion: elegida);
  }

  /// Pantalla que se muestra en la pestaña "Gestionar" según la opción elegida.
  Widget _paginaGestion() => switch (_seccion) {
    _Gestion.mascotas => const PetsAdminScreen(),
    _Gestion.adopcion => const SeccionAdminScreen(
      titulo: 'Solicitudes de adopción',
      icono: Icons.favorite_border,
      detalle: 'Aquí revisarás y responderás las solicitudes de adopción.',
    ),
    _Gestion.apadrinamiento => const SeccionAdminScreen(
      titulo: 'Solicitudes de apadrinamiento',
      icono: Icons.volunteer_activism,
      detalle:
          'Aquí revisarás y responderás las solicitudes de apadrinamiento.',
    ),
    _Gestion.seguimiento => const SeccionAdminScreen(
      titulo: 'Seguimiento de adopción',
      icono: Icons.timeline,
      detalle: 'Aquí harás el seguimiento de las mascotas ya adoptadas.',
    ),
    _Gestion.usuarios => const UsersAdminScreen(),
    _Gestion.administradores => const AdminsAdminScreen(),
  };

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
      if (isAdmin) _paginaGestion(),
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
