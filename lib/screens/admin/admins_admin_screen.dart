import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/admin_user.dart';
import 'package:paw_match/services/api_service.dart';

class AdminsAdminScreen extends StatefulWidget {
  const AdminsAdminScreen({super.key});

  @override
  State<AdminsAdminScreen> createState() => _AdminsAdminScreenState();
}

class _AdminsAdminScreenState extends State<AdminsAdminScreen> {
  late Future<List<AdminUser>> _future = ApiService.listarUsuariosAdmin(
    rol: 'administrador',
  );
  bool _creando = false;

  Future<void> _recargar() async {
    final future = ApiService.listarUsuariosAdmin(rol: 'administrador');
    setState(() => _future = future);
    await future;
  }

  Future<void> _agregarAdministrador() async {
    final datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _CrearAdministradorDialog(),
    );
    if (datos == null) return;

    setState(() => _creando = true);
    try {
      await ApiService.crearAdministrador(
        nombres: datos['nombres']!,
        apellidos: datos['apellidos']!,
        correo: datos['correo']!,
        telefono: datos['telefono']!,
        contrasena: datos['contrasena']!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Administrador agregado correctamente')),
      );
      await _recargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creando ? null : _agregarAdministrador,
        icon: _creando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.person_add_alt_1),
        label: const Text('Agregar administrador'),
      ),
      body: FutureBuilder<List<AdminUser>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 8),
                  const Text('No pudimos cargar los administradores'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      snap.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TextButton(
                    onPressed: _recargar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final administradores = snap.data!;
          return RefreshIndicator(
            onRefresh: _recargar,
            child: administradores.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Aún no hay administradores')),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: administradores.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final admin = administradores[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.rosaClaro,
                          child: Icon(
                            Icons.admin_panel_settings_outlined,
                            color: AppColors.rosa,
                          ),
                        ),
                        title: Text(
                          admin.nombreCompleto.isEmpty
                              ? 'Sin nombre'
                              : admin.nombreCompleto,
                        ),
                        subtitle: Text(
                          '${admin.correo}\n'
                          '${admin.telefono.isEmpty ? 'Sin teléfono' : admin.telefono}'
                          '${admin.fechaRegistro == null ? '' : ' · Registro ${_formatearFecha(admin.fechaRegistro!)}'}',
                        ),
                        isThreeLine: true,
                        trailing: const Chip(label: Text('Administrador')),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  String _formatearFecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/'
      '${fecha.year}';
}

class _CrearAdministradorDialog extends StatefulWidget {
  const _CrearAdministradorDialog();

  @override
  State<_CrearAdministradorDialog> createState() =>
      _CrearAdministradorDialogState();
}

class _CrearAdministradorDialogState extends State<_CrearAdministradorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _contrasena = TextEditingController();
  bool _mostrarContrasena = false;

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _correo.dispose();
    _telefono.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'nombres': _nombres.text.trim(),
      'apellidos': _apellidos.text.trim(),
      'correo': _correo.text.trim(),
      'telefono': _telefono.text.trim(),
      'contrasena': _contrasena.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar administrador'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombres,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nombres'),
                  validator: _requerido,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _apellidos,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Apellidos'),
                  validator: _requerido,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo'),
                  validator: (value) {
                    final correo = value?.trim() ?? '';
                    if (correo.isEmpty) return 'Ingresa el correo';
                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(correo)) {
                      return 'Ingresa un correo válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contrasena,
                  obscureText: !_mostrarContrasena,
                  decoration: InputDecoration(
                    labelText: 'Contraseña (mínimo 8 caracteres)',
                    suffixIcon: IconButton(
                      tooltip: _mostrarContrasena
                          ? 'Ocultar contraseña'
                          : 'Mostrar contraseña',
                      onPressed: () => setState(
                        () => _mostrarContrasena = !_mostrarContrasena,
                      ),
                      icon: Icon(
                        _mostrarContrasena
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').length < 8) {
                      return 'Usa al menos 8 caracteres';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: const Text('Crear administrador'),
        ),
      ],
    );
  }

  String? _requerido(String? value) => value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio'
      : null;
}
