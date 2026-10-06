import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/home/menu_screen.dart';
import 'package:paw_match/screens/auth/forgot_password_screen.dart';
import 'package:paw_match/screens/auth/register_screen.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/auth_scaffold.dart';
import 'package:paw_match/widgets/boton_blanco.dart';
import 'package:paw_match/widgets/feature_icon.dart';
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
            _CampoLogin(
              controller: _correoCtrl,
              icono: const FeatureIcon.sobre(color: AppColors.rosa),
              etiqueta: 'Correo',
              teclado: TextInputType.emailAddress,
              accion: TextInputAction.next,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Correo inválido' : null,
            ),
            const SizedBox(height: 14),
            _CampoLogin(
              controller: _contrasenaCtrl,
              icono: const FeatureIcon.cerradura(color: AppColors.rosa),
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

class _CampoLogin extends StatefulWidget {
  final TextEditingController controller;
  final Widget icono;
  final String etiqueta;
  final bool esContrasena;
  final TextInputType? teclado;
  final String? Function(String?)? validator;
  final TextInputAction? accion;
  final VoidCallback? onEnviar;

  const _CampoLogin({
    required this.controller,
    required this.icono,
    required this.etiqueta,
    this.esContrasena = false,
    this.teclado,
    this.validator,
    this.accion,
    this.onEnviar,
  });

  @override
  State<_CampoLogin> createState() => _CampoLoginState();
}

class _CampoLoginState extends State<_CampoLogin> {
  late bool _oculto = widget.esContrasena;

  OutlineInputBorder _borde([Color? color, double ancho = 0]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: ancho),
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _oculto,
      keyboardType: widget.teclado,
      textInputAction: widget.accion,
      onFieldSubmitted: widget.onEnviar == null
          ? null
          : (_) => widget.onEnviar!(),
      validator: widget.validator,
      style: const TextStyle(color: AppColors.texto),
      decoration: InputDecoration(
        hintText: widget.etiqueta,
        filled: true,
        fillColor: AppColors.blanco,
        prefixIcon: widget.icono,
        suffixIcon: widget.esContrasena
            ? IconButton(
                tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => _oculto = !_oculto),
                icon: _oculto
                    ? const FeatureIcon.ocultarContrasena(color: AppColors.rosa)
                    : const FeatureIcon.mostrarContrasena(color: AppColors.rosa),
              )
            : null,
        errorStyle: const TextStyle(
          color: AppColors.blanco,
          fontWeight: FontWeight.w600,
        ),
        border: _borde(),
        enabledBorder: _borde(),
        focusedBorder: _borde(AppColors.bordeRosa, 2),
        errorBorder: _borde(AppColors.blanco, 2),
        focusedErrorBorder: _borde(AppColors.blanco, 2),
      ),
    );
  }
}
