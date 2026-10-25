import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/admin/admins_admin_screen.dart';
import 'package:paw_match/screens/admin/denuncias_admin_screen.dart';
import 'package:paw_match/screens/admin/fundacion_admin_screen.dart';
import 'package:paw_match/screens/admin/seccion_admin_screen.dart';
import 'package:paw_match/screens/admin/users_admin_screen.dart';
import 'package:paw_match/screens/home/home_tab.dart';
import 'package:paw_match/screens/home/notifications_tab.dart';
import 'package:paw_match/screens/match/perfect_match.dart';
import 'package:paw_match/screens/pets/pet_screen.dart';
import 'package:paw_match/screens/users/profile_screen.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/denuncias_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/nav_flotante.dart';

/// Opciones del menú desplegable del administrador (último ícono de la barra).
enum _Gestion {
  denuncias('Denuncias de maltrato', Icons.campaign_rounded),
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

  /// Match perfecto está en el centro (índice 2).
  static int get indiceMatch => 2;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late int _index;

  late GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  late _ObservadorPaginas _obs = _ObservadorPaginas(_alCambiarPila);

  bool _enDetalle = false;

  @override
  void initState() {
    super.initState();
    final pedido = widget.indiceInicial;
    const maximo = 4;
    _index = (pedido >= 0 && pedido <= maximo) ? pedido : 0;
    ApadrinamientoService.iniciarMonitoreo();
    AdoptionService.iniciarMonitoreo();
    PetsService.iniciarMonitoreo();
    DenunciasService.iniciarMonitoreo();
  }

  @override
  void dispose() {
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    PetsService.detenerMonitoreo();
    DenunciasService.detenerMonitoreo();
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

  /// Cambia de pestaña con un navegador nuevo.
  void _cambiarA(int i) {
    setState(() {
      _index = i;
      _enDetalle = false;
      _navKey = GlobalKey<NavigatorState>();
      _obs = _ObservadorPaginas(_alCambiarPila);
    });
  }

  void _alTocarPestana(int i) {
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

    const altoBarra = 96.0;
    final altoMenu = _Gestion.values.length * 48.0 + 16;

    final elegida = await showMenu<_Gestion>(
      context: context,
      position: RelativeRect.fromLTRB(
        (tam.width - 270) / 2,
        tam.height - inferior - altoBarra - altoMenu,
        (tam.width - 270) / 2,
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
              ],
            ),
          ),
      ],
    );

    if (elegida != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _paginaGestion(elegida)),
      );
    }
  }

  /// Pantalla que se muestra en "Gestionar" según la opción elegida.
  Widget _paginaGestion(_Gestion g) => switch (g) {
    _Gestion.denuncias => const DenunciasAdminScreen(),
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
      Navegacion.ir(context, const WelcomeScreen());
    }
  }



  @override
  Widget build(BuildContext context) {


    final paginas = <Widget>[
      HomeTab(
        onVerMascotas: () => _irA(1),
        onVerMatch: () => _irA(2),
      ),
      const PetScreen(),
      PerfectMatchScreen(onCerrarSesion: _confirmarCerrarSesion),
      NotificationsTab(onCerrarSesion: _confirmarCerrarSesion),
      ProfileScreen(onCerrarSesion: _confirmarCerrarSesion),
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
        appBar: (_index == 0 ||
                _index == 1 ||
                _index == 2 ||
                _index == 3 ||
                _index == 4 ||
                _enDetalle)
            ? null
            : AppBar(
                title: const Text('Paw Match'),
                actions: [
                  if (Session.isAdmin)
                    IconButton(
                      tooltip: 'Gestión Admin',
                      icon: const Icon(Icons.tune_rounded, color: AppColors.rosa),
                      onPressed: _mostrarMenuGestion,
                    ),
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
            const NavItem(
              icono: Icon(Icons.home_outlined),
              iconoActivo: Icon(Icons.home_rounded),
              etiqueta: 'Inicio',
            ),
            const NavItem(
              icono: Icon(Icons.pets_outlined),
              iconoActivo: Icon(Icons.pets_rounded),
              etiqueta: 'Mascotas',
            ),
            const NavItem(
              icono: Icon(Icons.favorite_rounded),
              iconoActivo: Icon(Icons.favorite_rounded),
              etiqueta: 'Match perfecto',
              esDestacado: true,
            ),
            NavItem(
              icono: AnimatedBuilder(
                animation: Listenable.merge([
                  Session.esAdmin
                      ? ApadrinamientoService.noLeidasAdmin
                      : ApadrinamientoService.noLeidasUsuario,
                  Session.esAdmin
                      ? AdoptionService.noLeidasAdmin
                      : AdoptionService.noLeidasUsuario,
                  if (Session.esAdmin) DenunciasService.noLeidasAdmin,
                ]),
                builder: (context, _) {
                  final total = Session.esAdmin
                      ? (ApadrinamientoService.noLeidasAdmin.value +
                          AdoptionService.noLeidasAdmin.value +
                          DenunciasService.noLeidasAdmin.value)
                      : (ApadrinamientoService.noLeidasUsuario.value +
                          AdoptionService.noLeidasUsuario.value);
                  return Badge(
                    isLabelVisible: total > 0,
                    label: Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.notifications_outlined),
                  );
                },
              ),
              iconoActivo: AnimatedBuilder(
                animation: Listenable.merge([
                  Session.esAdmin
                      ? ApadrinamientoService.noLeidasAdmin
                      : ApadrinamientoService.noLeidasUsuario,
                  Session.esAdmin
                      ? AdoptionService.noLeidasAdmin
                      : AdoptionService.noLeidasUsuario,
                  if (Session.esAdmin) DenunciasService.noLeidasAdmin,
                ]),
                builder: (context, _) {
                  final total = Session.esAdmin
                      ? (ApadrinamientoService.noLeidasAdmin.value +
                          AdoptionService.noLeidasAdmin.value +
                          DenunciasService.noLeidasAdmin.value)
                      : (ApadrinamientoService.noLeidasUsuario.value +
                          AdoptionService.noLeidasUsuario.value);
                  return Badge(
                    isLabelVisible: total > 0,
                    label: Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.notifications_rounded),
                  );
                },
              ),
              etiqueta: 'Notificaciones',
            ),
            const NavItem(
              icono: Icon(Icons.person_outline_rounded),
              iconoActivo: Icon(Icons.person_rounded),
              etiqueta: 'Perfil',
            ),
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
