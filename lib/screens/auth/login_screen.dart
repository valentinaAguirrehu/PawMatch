import 'package:flutter/material.dart';
import 'package:paw_match/screens/home/menu_screen.dart';
import 'package:paw_match/screens/auth/forgot_password_screen.dart';
import 'package:paw_match/screens/auth/register_screen.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/auth_scaffold.dart';
import 'package:paw_match/widgets/boton_blanco.dart';
import 'package:paw_match/widgets/campo_auth.dart';
import 'package:paw_match/widgets/logo_paw.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();

  bool _cargando = false;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      final usuario = await ApiService.iniciarSesion(
        correo: _correoCtrl.text,
        contrasena: _contrasenaCtrl.text,
      );

      if (!mounted) return;

      // Guarda quién inició sesión (id, nombre y rol) para usarlo en la app
      Session.iniciar(usuario);

      // Reemplaza la pantalla de login por el menú principal
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MenuScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final blanco = TextButton.styleFrom(foregroundColor: Colors.white);

    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: LogoPaw()),
            const SizedBox(height: 28),
            Text(
              'Iniciar sesión',
              style: t.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ingresa tu correo y contraseña',
              style: t.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            CampoAuth(
              controller: _correoCtrl,
              icono: Icons.email_outlined,
              etiqueta: 'Correo',
              teclado: TextInputType.emailAddress,
              accion: TextInputAction.next,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Correo inválido' : null,
            ),
            const SizedBox(height: 14),
            CampoAuth(
              controller: _contrasenaCtrl,
              icono: Icons.lock_outline,
              etiqueta: 'Contraseña',
              esContrasena: true,
              accion: TextInputAction.done,
              onEnviar: _iniciarSesion,
              validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: blanco,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                ),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
            const SizedBox(height: 8),
            BotonBlanco(
              texto: 'Iniciar sesión',
              cargando: _cargando,
              onPressed: _iniciarSesion,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '¿No tienes cuenta?',
                  style: t.bodyMedium?.copyWith(color: Colors.white70),
                ),
                TextButton(
                  style: blanco,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text(
                    'Regístrate',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
