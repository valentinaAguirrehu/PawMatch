import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/auth/forgot_password_screen.dart';
import 'package:paw_match/screens/match/user_personality.dart';
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
  bool _recordarContrasena = true;

  @override
  void initState() {
    super.initState();
    _cargarCredenciales();
  }

  Future<void> _cargarCredenciales() async {
    final creds = await Session.obtenerCredencialesRecordadas();
    if (!mounted) return;
    setState(() {
      _recordarContrasena = creds.recordar;
      if (creds.recordar) {
        if (creds.correo.isNotEmpty) _correoCtrl.text = creds.correo;
        if (creds.contrasena.isNotEmpty) _contrasenaCtrl.text = creds.contrasena;
      }
    });
  }

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
        correo: _correoCtrl.text.trim(),
        contrasena: _contrasenaCtrl.text,
      );

      if (!mounted) return;

      // Guarda o elimina las credenciales según la preferencia seleccionada
      await Session.guardarCredenciales(
        recordar: _recordarContrasena,
        correo: _correoCtrl.text.trim(),
        contrasena: _contrasenaCtrl.text,
      );

      if (!mounted) return;

      // Guarda quién inició sesión (id, nombre y rol) para usarlo en la app
      Session.iniciar(usuario);

      // Cuestionario solo la primera vez; si ya existe, va al inicio
      await abrirDestinoTrasAuth(context);
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
            const SizedBox(height: 8),
            // Fila: Recordar contraseña & ¿Olvidaste tu contraseña?
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    setState(() => _recordarContrasena = !_recordarContrasena);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _recordarContrasena,
                            activeColor: Colors.white,
                            checkColor: AppColors.rosa,
                            side: const BorderSide(color: Colors.white, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            onChanged: (val) {
                              setState(() => _recordarContrasena = val ?? false);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Recordar contraseña',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  style: blanco,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  ),
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
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
