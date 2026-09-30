import 'package:flutter/material.dart';
import 'package:paw_match/screens/admin/mascotas_admin_screen.dart';
import 'package:paw_match/screens/inicio_tab.dart';
import 'package:paw_match/screens/mascotas_screen.dart';
import 'package:paw_match/screens/welcome_screen.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/nav_flotante.dart';

/// Pantalla principal después de iniciar sesión (solo navegación).
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
      InicioTab(onVerMascotas: () => _irA(1), onCerrarSesion: _cerrarSesion),
      const MascotasScreen(),
      if (isAdmin) const MascotasAdminScreen(),
    ];

    return Scaffold(
      // El Inicio trae su propio encabezado; las otras pestañas usan la barra superior.
      appBar: _index == 0
          ? null
          : AppBar(
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
      bottomNavigationBar: NavFlotante(
        indice: _index,
        onTap: _irA,
        items: [
          const NavItem(Icons.home_rounded, 'Inicio'),
          const NavItem(Icons.pets, 'Mascotas'),
          if (isAdmin) const NavItem(Icons.edit_note, 'Gestionar'),
        ],
      ),
    );
  }
}
