import 'package:flutter/material.dart';
import 'package:paw_match/services/recuperacion_service.dart';
import 'package:paw_match/widgets/auth_scaffold.dart';
import 'package:paw_match/widgets/boton_blanco.dart';
import 'package:paw_match/widgets/campo_auth.dart';
import 'package:paw_match/widgets/logo_paw.dart';

/// Recuperar contraseña en dos pasos:
///   1) escribir el correo y recibir un código
///   2) escribir el código y la contraseña nueva
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _codigo = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();

  int _paso = 1;
  bool _cargando = false;

  @override
  void dispose() {
    _correo.dispose();
    _codigo.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  void _aviso(String texto) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  String _mensaje(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _enviarCodigo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await RecuperacionService.solicitarCodigo(_correo.text);
      if (!mounted) return;
      setState(() => _paso = 2);
      _aviso('Si el correo está registrado, te enviamos un código');
    } catch (e) {
      if (mounted) _aviso(_mensaje(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarContrasena() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await RecuperacionService.restablecer(
        correo: _correo.text,
        codigo: _codigo.text,
        nuevaContrasena: _nueva.text,
      );
      if (!mounted) return;
      _aviso('Contraseña actualizada. Ya puedes iniciar sesión');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _aviso(_mensaje(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final paso1 = _paso == 1;

    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: LogoPaw()),
            const SizedBox(height: 28),
            Text(paso1 ? '¿Olvidaste tu contraseña?' : 'Crea una contraseña nueva',
                style: t.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              paso1
                  ? 'Escribe tu correo y te enviaremos un código de 6 dígitos.'
                  : 'Escribe el código que llegó a ${_correo.text.trim()} (vence en 15 minutos).',
              style: t.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            if (paso1) ...[
              CampoAuth(
                controller: _correo,
                icono: Icons.email_outlined,
                etiqueta: 'Correo',
                teclado: TextInputType.emailAddress,
                accion: TextInputAction.done,
                onEnviar: _enviarCodigo,
                validator: (v) => (v == null || !v.contains('@')) ? 'Correo inválido' : null,
              ),
              const SizedBox(height: 20),
              BotonBlanco(texto: 'Enviar código', cargando: _cargando, onPressed: _enviarCodigo),
            ] else ...[
              CampoAuth(
                controller: _codigo,
                icono: Icons.pin_outlined,
                etiqueta: 'Código de 6 dígitos',
                teclado: TextInputType.number,
                accion: TextInputAction.next,
                validator: (v) => (v == null || v.trim().length != 6) ? 'Ingresa los 6 dígitos' : null,
              ),
              const SizedBox(height: 14),
              CampoAuth(
                controller: _nueva,
                icono: Icons.lock_outline,
                etiqueta: 'Contraseña nueva',
                esContrasena: true,
                accion: TextInputAction.next,
                validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 14),
              CampoAuth(
                controller: _confirmar,
                icono: Icons.lock_reset,
                etiqueta: 'Repite la contraseña',
                esContrasena: true,
                accion: TextInputAction.done,
                onEnviar: _cambiarContrasena,
                validator: (v) => v != _nueva.text ? 'Las contraseñas no coinciden' : null,
              ),
              const SizedBox(height: 20),
              BotonBlanco(texto: 'Cambiar contraseña', cargando: _cargando, onPressed: _cambiarContrasena),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _cargando ? null : () => setState(() => _paso = 1),
                child: const Text('Pedir otro código'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
