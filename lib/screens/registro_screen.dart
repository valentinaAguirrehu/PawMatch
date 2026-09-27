import 'package:flutter/material.dart';
import '/services/api_service.dart';

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

  bool _cargando = false;

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      final usuario = await ApiService.registrarUsuario(
        nombres: _nombresCtrl.text,
        apellidos: _apellidosCtrl.text,
        correo: _correoCtrl.text,
        telefono: _telefonoCtrl.text,
        contrasena: _contrasenaCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Usuario ${usuario['nombres']} registrado con éxito!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro - Paw Match')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombresCtrl,
                decoration: const InputDecoration(labelText: 'Nombres'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _apellidosCtrl,
                decoration: const InputDecoration(labelText: 'Apellidos'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _correoCtrl,
                decoration: const InputDecoration(labelText: 'Correo'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Correo inválido' : null,
              ),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _contrasenaCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _cargando ? null : _registrar,
                child: _cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Registrarme'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
