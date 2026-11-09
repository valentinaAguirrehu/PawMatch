import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/admin_user.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart' show urlFoto;

bool _esRolSuperAdmin(String rol) => rol.trim().toLowerCase() == 'superadmin';

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
  final Set<String> _gestionando = {};
  String _busqueda = '';
  bool get _esSuperAdmin => Session.esSuperAdmin;

  Future<void> _recargar() async {
    final future = ApiService.listarUsuariosAdmin(rol: 'administrador');
    setState(() {
      _future = future;
    });
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

  Future<void> _editarAdministrador(AdminUser admin) async {
    final datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _CrearAdministradorDialog(administrador: admin),
    );
    if (datos == null) return;

    setState(() => _gestionando.add(admin.id));
    try {
      await ApiService.actualizarAdministrador(
        id: admin.id,
        nombres: datos['nombres']!,
        apellidos: datos['apellidos']!,
        correo: datos['correo']!,
        telefono: datos['telefono']!,
        contrasena: datos['contrasena'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Administrador actualizado')),
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
      if (mounted) setState(() => _gestionando.remove(admin.id));
    }
  }

  Future<void> _eliminarAdministrador(AdminUser admin) async {
    final nombre = admin.nombreCompleto.isEmpty
        ? 'este administrador'
        : admin.nombreCompleto;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar administrador'),
        content: Text(
          '¿Quieres eliminar a $nombre? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _gestionando.add(admin.id));
    try {
      await ApiService.eliminarAdministrador(admin.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Administrador eliminado')),
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
      if (mounted) setState(() => _gestionando.remove(admin.id));
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (!confirmar || !mounted) return;
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    Session.cerrar();
    Navegacion.ir(context, const WelcomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      floatingActionButton: _esSuperAdmin
          ? FloatingActionButton.extended(
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
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            BarraSuperior(
              iconoTitulo: Icons.admin_panel_settings_outlined,
              titulo: 'Administradores',
              onCerrarSesion: _confirmarCerrarSesion,
            ),
            Expanded(
              child: FutureBuilder<List<AdminUser>>(
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

                  final consulta = _busqueda.trim().toLowerCase();
                  final yo = Session.idUsuario?.trim() ?? '';
                  final administradores = snap.data!
                      .where((admin) => yo.isEmpty || admin.id.trim() != yo)
                      .where(
                        (admin) =>
                            admin.nombreCompleto.toLowerCase().contains(consulta) ||
                            admin.correo.toLowerCase().contains(consulta) ||
                            admin.telefono.toLowerCase().contains(consulta),
                      )
                      .toList()
                    ..sort((a, b) {
                      final prioridadA = _esRolSuperAdmin(a.rol) ? 0 : 1;
                      final prioridadB = _esRolSuperAdmin(b.rol) ? 0 : 1;
                      return prioridadA.compareTo(prioridadB);
                    });

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: TextField(
                          onChanged: (valor) => setState(() => _busqueda = valor),
                          decoration: const InputDecoration(
                            labelText: 'Buscar administrador',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _recargar,
                          child: administradores.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 100),
                                    Center(
                                      child: Text(
                                        snap.data!.isEmpty
                                            ? 'Aún no hay administradores'
                                            : consulta.isEmpty
                                            ? 'No hay otros administradores'
                                            : 'No hay administradores que coincidan con la búsqueda',
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                                  itemCount: administradores.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    return _TarjetaAdministrador(
                                      admin: administradores[index],
                                      puedeGestionar:
                                          _esSuperAdmin &&
                                          !_esRolSuperAdmin(administradores[index].rol),
                                      ocupado: _gestionando.contains(
                                        administradores[index].id,
                                      ),
                                      onEditar: () => _editarAdministrador(
                                        administradores[index],
                                      ),
                                      onEliminar: () => _eliminarAdministrador(
                                        administradores[index],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaAdministrador extends StatelessWidget {
  final AdminUser admin;
  final bool puedeGestionar;
  final bool ocupado;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _TarjetaAdministrador({
    required this.admin,
    required this.puedeGestionar,
    required this.ocupado,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = admin.nombreCompleto.isEmpty ? 'Sin nombre' : admin.nombreCompleto;
    final celular = admin.telefono.trim().isEmpty ? 'Sin celular' : admin.telefono.trim();
    final correo = admin.correo.trim().isEmpty ? 'Sin correo' : admin.correo.trim();

    return Card(
      elevation: 0,
      color: AppColors.rosaSuave,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.bordeRosa),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FotoAdministrador(url: admin.fotoPerfil),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.texto,
                        ),
                      ),
                      if (_esRolSuperAdmin(admin.rol)) ...[
                        const SizedBox(height: 2),
                        const Text(
                          'Super Administrador',
                          style: TextStyle(
                            color: AppColors.rosa,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        'Celular: $celular',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      Text(
                        'Correo: $correo',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (puedeGestionar) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: ocupado ? null : onEditar,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: ocupado ? null : onEliminar,
                      icon: ocupado
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Eliminar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FotoAdministrador extends StatelessWidget {
  final String? url;

  const _FotoAdministrador({required this.url});

  @override
  Widget build(BuildContext context) {
    final ruta = url?.trim() ?? '';
    return CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.rosaClaro,
      child: ClipOval(
        child: SizedBox(
          width: 56,
          height: 56,
          child: ruta.isEmpty
              ? const Icon(Icons.person_outline, color: AppColors.rosa)
              : Image.network(
                  urlFoto(ruta),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.person_outline,
                    color: AppColors.rosa,
                  ),
                ),
        ),
      ),
    );
  }
}

class _CrearAdministradorDialog extends StatefulWidget {
  final AdminUser? administrador;

  const _CrearAdministradorDialog({this.administrador});

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
  bool get _editando => widget.administrador != null;

  @override
  void initState() {
    super.initState();
    final admin = widget.administrador;
    if (admin == null) return;
    _nombres.text = admin.nombres;
    _apellidos.text = admin.apellidos;
    _correo.text = admin.correo;
    _telefono.text = admin.telefono;
  }

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
      title: Text(_editando ? 'Editar administrador' : 'Agregar administrador'),
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
                    labelText: _editando
                        ? 'Nueva contraseña (opcional)'
                        : 'Contraseña (mínimo 8 caracteres)',
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
                    final texto = value ?? '';
                    if (_editando && texto.isEmpty) return null;
                    if (texto.length < 8) {
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
          child: Text(_editando ? 'Guardar cambios' : 'Crear administrador'),
        ),
      ],
    );
  }

  String? _requerido(String? value) => value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio'
      : null;
}
