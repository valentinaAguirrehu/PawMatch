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
      HomeTab(onVerMascotas: () => _irA(1), onCerrarSesion: _cerrarSesion),
      const PetScreen(),
      const ProfileScreen(),
      if (isAdmin) const PetsAdminScreen(),
    ];

    return Scaffold(
      
      appBar: _index == 0
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
      body: paginas[_index],
      bottomNavigationBar: NavFlotante(
        indice: _index,
        onTap: _irA,
        items: [
          const NavItem(FeatureIcon.inicio(), 'Inicio'),
          const NavItem(FeatureIcon.mascota(tamano: 24), 'Mascotas'),
          const NavItem(FeatureIcon.perfil(tamano: 24), 'Perfil'),
          if (isAdmin) const NavItem(FeatureIcon.gestionar(), 'Gestionar'),
        ],
      ),
    );
  }
}
