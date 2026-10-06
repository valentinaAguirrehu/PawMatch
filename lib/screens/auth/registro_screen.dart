import 'package:flutter/material.dart';
import 'package:paw_match/screens/auth/login_screen.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/widgets/auth_scaffold.dart';
import 'package:paw_match/widgets/boton_blanco.dart';
import 'package:paw_match/widgets/campo_auth.dart';
import 'package:paw_match/widgets/logo_paw.dart';

/// RF01: registro de usuario (misma lógica de siempre, con el estilo rosado del login).
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombresCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  DateTime? _fecha;
  bool _cargando = false;

  @override
  void dispose() {
    for (final c in [
      _nombresCtrl,
      _apellidosCtrl,
      _correoCtrl,
      _telefonoCtrl,
      _contrasenaCtrl,
      _confirmarCtrl,
      _fechaCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _dos(int n) => n.toString().padLeft(2, '0');

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime(hoy.year - 18, hoy.month, hoy.day),
      firstDate: DateTime(1920),
      lastDate: hoy,
      helpText: 'Fecha de nacimiento',
    );
    if (elegida == null) return;
    setState(() {
      _fecha = elegida;
      _fechaCtrl.text =
          '${_dos(elegida.day)}/${_dos(elegida.month)}/${elegida.year}';
    });
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    try {
      final usuario = await ApiService.registrarUsuario(
        nombres: _nombresCtrl.text,
        apellidos: _apellidosCtrl.text,
        correo: _correoCtrl.text,
        telefono: _telefonoCtrl.text,
        fechaNacimiento: _fecha!, // tu ApiService recibe un DateTime
        contrasena: _contrasenaCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Usuario ${usuario['nombres']} registrado con éxito! Ya puedes iniciar sesión.',
          ),
        ),
      );
      Navigator.pop(
        context,
      ); // vuelve a la pantalla anterior para iniciar sesión
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
    const gap = SizedBox(height: 14);
    String? requerido(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Requerido' : null;

    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: LogoPaw()),
            const SizedBox(height: 24),
            Text(
              'Crea tu cuenta',
              style: t.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Regístrate para adoptar o apadrinar',
              style: t.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            CampoAuth(
              controller: _nombresCtrl,
              icono: Icons.person_outline,
              etiqueta: 'Nombres',
              accion: TextInputAction.next,
              validator: requerido,
            ),
            gap,
            CampoAuth(
              controller: _apellidosCtrl,
              icono: Icons.badge_outlined,
              etiqueta: 'Apellidos',
              accion: TextInputAction.next,
              validator: requerido,
            ),
            gap,
            CampoAuth(
              controller: _fechaCtrl,
              icono: Icons.cake_outlined,
              etiqueta: 'Fecha de nacimiento',
              soloLectura: true,
              onTap: _elegirFecha,
              validator: (v) => _fecha == null ? 'Requerido' : null,
            ),
            gap,
            CampoAuth(
              controller: _correoCtrl,
              icono: Icons.email_outlined,
              etiqueta: 'Correo',
              teclado: TextInputType.emailAddress,
              accion: TextInputAction.next,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Correo inválido' : null,
            ),
            gap,
            CampoAuth(
              controller: _telefonoCtrl,
              icono: Icons.phone_outlined,
              etiqueta: 'Teléfono',
              teclado: TextInputType.phone,
              accion: TextInputAction.next,
            ),
            gap,
            CampoAuth(
              controller: _contrasenaCtrl,
              icono: Icons.lock_outline,
              etiqueta: 'Contraseña',
              esContrasena: true,
              accion: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
            ),
            gap,
            CampoAuth(
              controller: _confirmarCtrl,
              icono: Icons.lock_reset,
              etiqueta: 'Repite la contraseña',
              esContrasena: true,
              accion: TextInputAction.done,
              onEnviar: _registrar,
              validator: (v) => v != _contrasenaCtrl.text
                  ? 'Las contraseñas no coinciden'
                  : null,
            ),
            const SizedBox(height: 24),
            BotonBlanco(
              texto: 'Registrarme',
              cargando: _cargando,
              onPressed: _registrar,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '¿Ya tienes cuenta?',
                  style: t.bodyMedium?.copyWith(color: Colors.white70),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text(
                    'Inicia sesión',
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
