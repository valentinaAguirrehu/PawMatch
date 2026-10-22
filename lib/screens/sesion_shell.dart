import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/screens/match/user_personality.dart';
import 'package:paw_match/services/fundacion_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/session.dart';

/// Ruta que no se destruye. Adentro se cambia entre bienvenida, cuestionario y menú.
class SesionShell extends StatefulWidget {
  const SesionShell({super.key});

  @override
  State<SesionShell> createState() => _SesionShellState();
}

class _SesionShellState extends State<SesionShell> {
  Widget _pagina = const _Espera();

  @override
  void initState() {
    super.initState();
    Navegacion.mostrar = _mostrar;
    FundacionService.cargar();
    _arranque();
  }

  Future<void> _arranque() async {
    final tieneSesion = await Session.restaurar();
    if (!mounted) return;
    if (!tieneSesion) {
      _mostrar(const WelcomeScreen());
      return;
    }
    await abrirDestinoTrasAuth(context);
  }

  @override
  void dispose() {
    if (Navegacion.mostrar == _mostrar) Navegacion.mostrar = null;
    super.dispose();
  }

  void _mostrar(Widget pagina) {
    if (!mounted) return;
    setState(() {
      _pagina = KeyedSubtree(key: UniqueKey(), child: pagina);
    });
  }

  @override
  Widget build(BuildContext context) => _pagina;
}

class _Espera extends StatelessWidget {
  const _Espera();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.rosa,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
