import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/adoption/adoption_requests_admin_screen.dart';
import 'package:paw_match/screens/admin/admins_admin_screen.dart';
import 'package:paw_match/screens/apadrinamiento/apadrinamiento_admin_screen.dart';
import 'package:paw_match/screens/admin/fundacion_admin_screen.dart';
import 'package:paw_match/screens/admin/pets_admin_screen.dart';
import 'package:paw_match/screens/admin/seccion_admin_screen.dart';
import 'package:paw_match/screens/admin/users_admin_screen.dart';
import 'package:paw_match/screens/home/home_tab.dart';
import 'package:paw_match/screens/match/perfect_match.dart';
import 'package:paw_match/screens/pets/pet_screen.dart';
import 'package:paw_match/screens/users/profile_screen.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
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
  administradores('Administradores', Icons.admin_panel_settings_outlined),
  fundacion('Fundación', Icons.info_outline);

  final String etiqueta;
  final IconData icono;
  const _Gestion(this.etiqueta, this.icono);
}

class MenuScreen extends StatefulWidget {
  /// Pestaña que se abre al entrar. [indiceMatch] es Match perfecto.
  final int indiceInicial;

  const MenuScreen({super.key, this.indiceInicial = 0});

  /// Match perfecto solo está en la barra de quien no administra.
  static int get indiceMatch => Session.isAdmin ? 0 : 2;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  /// Última pestaña del administrador: abre el menú desplegable.
  /// Inicio = 0, Perfil = 1, menú = 2. Mascotas no entra en esta barra.
  static const int _indiceGestionAdmin = 2;

  late int _index;
  _Gestion _seccion = _Gestion.mascotas;

  late GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  late _ObservadorPaginas _obs = _ObservadorPaginas(_alCambiarPila);

  bool _enDetalle = false;

  @override
  void initState() {
    super.initState();
    final pedido = widget.indiceInicial;
    final maximo = Session.isAdmin ? _indiceGestionAdmin : 3;
    _index = (pedido >= 0 && pedido <= maximo) ? pedido : 0;
    ApadrinamientoService.iniciarMonitoreo();
    AdoptionService.iniciarMonitoreo();
  }

  @override
  void dispose() {
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    super.dispose();
  }

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
    if (Session.isAdmin && i == _indiceGestionAdmin) {
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

  /// El administrador no tiene la pestaña Mascotas. Desde Inicio, la búsqueda
  /// abre la misma lista en una pantalla aparte.
  void _abrirListaMascotas() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Mascotas')),
          body: const PetScreen(),
        ),
      ),
    );
  }

  void _abrirMatch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PerfectMatchScreen()),
    );
  }

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
                Expanded(child: Text(g.etiqueta)),
                if (g == _Gestion.apadrinamiento)
                  _ContadorMenu(origen: ApadrinamientoService.noLeidasAdmin),
                if (g == _Gestion.adopcion)
                  _ContadorMenu(origen: AdoptionService.noLeidasAdmin),
              ],
            ),
          ),
      ],
    );

    if (elegida != null && mounted) {
      if (elegida == _Gestion.apadrinamiento) {
        ApadrinamientoService.marcarLeidasAdmin();
      } else if (elegida == _Gestion.adopcion) {
        AdoptionService.marcarLeidasAdmin();
      }
      _cambiarA(_indiceGestionAdmin, seccion: elegida);
    }
  }

  /// Pantalla que se muestra en la pestaña "Gestionar" según la opción elegida.
  Widget _paginaGestion() => switch (_seccion) {
    _Gestion.mascotas => const PetsAdminScreen(),
    _Gestion.adopcion => const AdoptionRequestsAdminScreen(),
    _Gestion.apadrinamiento => const ApadrinamientoAdminScreen(),
    _Gestion.seguimiento => const SeccionAdminScreen(
      titulo: 'Seguimiento de adopción',
      icono: Icons.timeline,
      detalle: 'Aquí harás el seguimiento de las mascotas ya adoptadas.',
    ),
    _Gestion.usuarios => const UsersAdminScreen(),
    _Gestion.administradores => const AdminsAdminScreen(),
    _Gestion.fundacion => const FundacionAdminScreen(),
  };

  void _confirmarCerrarSesion() {
    _ejecutarConfirmarCerrarSesion();
  }

  Future<void> _ejecutarConfirmarCerrarSesion() async {
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
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Session.isAdmin;

    final paginas = <Widget>[
      HomeTab(
        onVerMascotas: () => isAdmin ? _abrirListaMascotas() : _irA(1),
        onVerMatch: () => isAdmin ? _abrirMatch() : _irA(2),
      ),
      if (isAdmin)
        const ProfileScreen()
      else ...[
        const PetScreen(),
        const PerfectMatchScreen(),
      ],
      if (isAdmin) _paginaGestion() else const ProfileScreen(),
    ];
    final paginaActual = paginas[_index];

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
                    onPressed: _confirmarCerrarSesion,
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
            if (isAdmin)
              const NavItem(FeatureIcon.perfil(tamano: 24), 'Perfil')
            else ...[
              const NavItem(FeatureIcon.mascota(tamano: 24), 'Mascotas'),
              const NavItem(
                FeatureIcon.compatibilidad(tamano: 24),
                'Match perfecto',
              ),
            ],
            if (isAdmin)
              NavItem(
                AnimatedBuilder(
                  animation: Listenable.merge([
                    ApadrinamientoService.noLeidasAdmin,
                    AdoptionService.noLeidasAdmin,
                  ]),
                  builder: (context, child) {
                    final count = ApadrinamientoService.noLeidasAdmin.value +
                        AdoptionService.noLeidasAdmin.value;
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      backgroundColor: Colors.redAccent,
                      textColor: Colors.white,
                      child: child,
                    );
                  },
                  child: const FeatureIcon.gestionar(),
                ),
                'Gestionar',
              )
            else
              const NavItem(FeatureIcon.perfil(tamano: 24), 'Perfil'),
          ],
        ),
      ),
    );
  }
}

/// Cuenta cuántas pantallas hay abiertas encima de la principal de la pestaña
/// (ignora diálogos, menús emergentes y bottom sheets).
class _ContadorMenu extends StatelessWidget {
  final ValueNotifier<int> origen;

  const _ContadorMenu({required this.origen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: origen,
      builder: (context, count, _) {
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

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
