import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/admin_user.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart' show urlFoto;

class UsersAdminScreen extends StatefulWidget {
  const UsersAdminScreen({super.key});

  @override
  State<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

enum _FiltroEstado { todos, activo, inactivo, adoptante, apadrinante }

extension on _FiltroEstado {
  String get etiqueta => switch (this) {
    _FiltroEstado.todos => 'Todos',
    _FiltroEstado.activo => 'Activo',
    _FiltroEstado.inactivo => 'Inactivo',
    _FiltroEstado.adoptante => 'Adoptante',
    _FiltroEstado.apadrinante => 'Apadrinante',
  };
}

enum _OrdenRegistro { reciente, antiguo }

class _UsersAdminScreenState extends State<UsersAdminScreen> {
  final Set<String> _actualizando = {};
  String _busqueda = '';
  _FiltroEstado _filtro = _FiltroEstado.todos;
  _OrdenRegistro _orden = _OrdenRegistro.reciente;
  List<AdminUser>? _usuarios;
  Set<String> _adoptantes = {};
  Set<String> _apadrinantes = {};
  String? _error;
  bool _cargandoRoles = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final usuarios = await ApiService.listarUsuariosAdmin(rol: 'usuario');
      if (!mounted) return;
      setState(() {
        _usuarios = usuarios;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    await _cargarRoles();
  }

  Future<void> _cargarRoles() async {
    if (!mounted) return;
    setState(() => _cargandoRoles = true);
    try {
      final roles = await ApiService.listarRolesUsuariosAdmin();
      if (!mounted) return;
      setState(() {
        _adoptantes = roles.adoptantes;
        _apadrinantes = roles.apadrinantes;
        _cargandoRoles = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoRoles = false);
    }
  }

  Future<void> _recargar() async {
    await _cargar();
  }

  Future<void> _cambiarEstado(AdminUser usuario, bool activo) async {
    final nombre = usuario.nombreCompleto.isEmpty
        ? 'este usuario'
        : usuario.nombreCompleto;
    String? motivo;
    if (activo) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Activar cuenta'),
          content: Text('¿Quieres activar la cuenta de $nombre?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Activar'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    } else {
      motivo = await showDialog<String>(
        context: context,
        builder: (context) => _MotivoInactivacionDialog(nombre: nombre),
      );
      if (motivo == null || !mounted) return;
    }

    setState(() => _actualizando.add(usuario.id));
    try {
      final actualizado = await ApiService.cambiarEstadoUsuarioAdmin(
        id: usuario.id,
        activo: activo,
        motivo: motivo,
      );
      if (!mounted) return;
      setState(() {
        _actualizando.remove(usuario.id);
        final actuales = _usuarios;
        if (actuales != null) {
          _usuarios = [
            for (final item in actuales)
              if (item.id == actualizado.id) actualizado else item,
          ];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${usuario.nombreCompleto}: cuenta ${activo ? 'activada' : 'desactivada'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actualizando.remove(usuario.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _mensajeVacio(bool sinUsuarios) {
    if (sinUsuarios) return 'Aún no hay usuarios registrados';
    if (_busqueda.trim().isNotEmpty) {
      return 'No hay usuarios que coincidan con la búsqueda';
    }
    return switch (_filtro) {
      _FiltroEstado.activo => 'No hay usuarios activos',
      _FiltroEstado.inactivo => 'No hay usuarios inactivos',
      _FiltroEstado.adoptante => 'No hay usuarios adoptantes',
      _FiltroEstado.apadrinante => 'No hay usuarios apadrinantes',
      _FiltroEstado.todos => 'No hay usuarios que coincidan con la búsqueda',
    };
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
      body: SafeArea(
        child: Column(
          children: [
            BarraSuperior(
              iconoTitulo: Icons.people_alt_outlined,
              titulo: 'Usuarios',
              onCerrarSesion: _confirmarCerrarSesion,
            ),
            Expanded(child: _contenido()),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    final usuarios = _usuarios;
    final error = _error;
    if (usuarios == null) {
      if (error != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 8),
              const Text('No pudimos cargar los usuarios'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(error, textAlign: TextAlign.center),
              ),
              TextButton(onPressed: _recargar, child: const Text('Reintentar')),
            ],
          ),
        );
      }
      return const Center(
        child: CircularProgressIndicator(color: AppColors.rosa),
      );
    }

    final consulta = _busqueda.trim().toLowerCase();
    final esperaRoles =
        _cargandoRoles &&
        (_filtro == _FiltroEstado.adoptante ||
            _filtro == _FiltroEstado.apadrinante);
    final filtrados = usuarios.where((u) {
      final coincideEstado = switch (_filtro) {
        _FiltroEstado.todos => true,
        _FiltroEstado.activo => u.activo,
        _FiltroEstado.inactivo => !u.activo,
        _FiltroEstado.adoptante => _adoptantes.contains(u.id),
        _FiltroEstado.apadrinante => _apadrinantes.contains(u.id),
      };
      if (!coincideEstado) return false;
      if (consulta.isEmpty) return true;
      return u.nombreCompleto.toLowerCase().contains(consulta) ||
          u.correo.toLowerCase().contains(consulta) ||
          u.documentoIdentidad.toLowerCase().contains(consulta) ||
          u.telefono.toLowerCase().contains(consulta);
    }).toList();
    filtrados.sort((a, b) {
      final fechaA = a.fechaRegistro;
      final fechaB = b.fechaRegistro;
      if (fechaA == null && fechaB == null) return 0;
      if (fechaA == null) return 1;
      if (fechaB == null) return -1;
      final comparacion = fechaB.compareTo(fechaA);
      return _orden == _OrdenRegistro.reciente ? comparacion : -comparacion;
    });

    return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _busqueda = value),
                      decoration: const InputDecoration(
                        labelText: 'Buscar usuario',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_FiltroEstado>(
                    tooltip: 'Filtrar usuarios',
                    initialValue: _filtro,
                    onSelected: (valor) => setState(() => _filtro = valor),
                    color: Colors.white,
                    icon: Icon(
                      Icons.filter_alt_outlined,
                      color: _filtro == _FiltroEstado.todos
                          ? AppColors.rosa
                          : Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: _filtro == _FiltroEstado.todos
                          ? AppColors.rosaClaro
                          : AppColors.rosa,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    itemBuilder: (context) => [
                      for (final opcion in _FiltroEstado.values)
                        PopupMenuItem(
                          value: opcion,
                          child: Row(
                            children: [
                              Icon(
                                _filtro == opcion
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 18,
                                color: AppColors.rosa,
                              ),
                              const SizedBox(width: 8),
                              Text(opcion.etiqueta),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.swap_vert,
                        size: 18,
                        color: Colors.grey.shade700,
                      ),
                      Text(
                        'Registro',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _OpcionChip(
                        texto: 'Más reciente',
                        seleccionado: _orden == _OrdenRegistro.reciente,
                        onTap: () => setState(
                          () => _orden = _OrdenRegistro.reciente,
                        ),
                      ),
                      _OpcionChip(
                        texto: 'Más antiguo',
                        seleccionado: _orden == _OrdenRegistro.antiguo,
                        onTap: () =>
                            setState(() => _orden = _OrdenRegistro.antiguo),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _recargar,
                child: esperaRoles
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: CircularProgressIndicator(
                              color: AppColors.rosa,
                            ),
                          ),
                        ],
                      )
                    : filtrados.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 100),
                          Center(child: Text(_mensajeVacio(usuarios.isEmpty))),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtrados.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final usuario = filtrados[index];
                          return _TarjetaUsuario(
                            usuario: usuario,
                            esAdoptante: _adoptantes.contains(usuario.id),
                            esApadrinante: _apadrinantes.contains(usuario.id),
                            cargando: _actualizando.contains(usuario.id),
                            onCambiarEstado: (activo) =>
                                _cambiarEstado(usuario, activo),
                          );
                        },
                      ),
              ),
            ),
          ],
    );
  }
}

class _OpcionChip extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  const _OpcionChip({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? AppColors.rosa : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: seleccionado ? AppColors.rosa : AppColors.bordeRosa,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            texto,
            style: TextStyle(
              color: seleccionado ? Colors.white : AppColors.texto,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _MotivoInactivacionDialog extends StatefulWidget {
  final String nombre;

  const _MotivoInactivacionDialog({required this.nombre});

  @override
  State<_MotivoInactivacionDialog> createState() =>
      _MotivoInactivacionDialogState();
}

class _MotivoInactivacionDialogState extends State<_MotivoInactivacionDialog> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  void _confirmar() {
    final texto = _motivo.text.trim();
    if (texto.isEmpty) return;
    Navigator.pop(context, texto);
  }

  @override
  Widget build(BuildContext context) {
    final listo = _motivo.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Inactivar cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Explica por qué inactivas la cuenta de ${widget.nombre}.'),
          const SizedBox(height: 12),
          TextField(
            controller: _motivo,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _confirmar(),
            decoration: const InputDecoration(
              labelText: 'Motivo',
              alignLabelWithHint: true,
              hintText: 'Escribe la razón de la inactivación',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: listo ? _confirmar : null,
          child: const Text('Inactivar'),
        ),
      ],
    );
  }
}

class _TarjetaUsuario extends StatelessWidget {
  final AdminUser usuario;
  final bool esAdoptante;
  final bool esApadrinante;
  final bool cargando;
  final ValueChanged<bool> onCambiarEstado;

  const _TarjetaUsuario({
    required this.usuario,
    required this.esAdoptante,
    required this.esApadrinante,
    required this.cargando,
    required this.onCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = usuario.nombreCompleto.isEmpty
        ? 'Sin nombre'
        : usuario.nombreCompleto;
    final cedula = usuario.documentoIdentidad.trim().isEmpty
        ? 'Sin cédula'
        : usuario.documentoIdentidad.trim();
    final celular = usuario.telefono.trim().isEmpty
        ? 'Sin celular'
        : usuario.telefono.trim();

    return Card(
      elevation: 0,
      color: usuario.activo ? AppColors.rosaSuave : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: usuario.activo ? AppColors.bordeRosa : AppColors.rosaClaro,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FotoUsuario(url: usuario.fotoPerfil),
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
                      const SizedBox(height: 2),
                      Text(
                        'Cédula: $cedula',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Celular: $celular',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Registro: ${usuario.fechaRegistroLabel ?? 'Sin fecha'}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (esAdoptante) const _RolChip(texto: 'Adoptante'),
                          if (esApadrinante)
                            const _RolChip(texto: 'Apadrinante'),
                          _EstadoChip(activo: usuario.activo),
                        ],
                      ),
                      if (!usuario.activo) ...[
                        if ((usuario.motivoInactivacion ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Motivo: ${usuario.motivoInactivacion}',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (usuario.fechaInactivacionLabel != null)
                          Text(
                            'Inactivado: ${usuario.fechaInactivacionLabel}',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 13,
                            ),
                          ),
                        if ((usuario.administradorInactivacion ?? '')
                            .isNotEmpty)
                          Text(
                            'Administrador: ${usuario.administradorInactivacion}',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: usuario.activo
                  ? OutlinedButton.icon(
                      onPressed: cargando
                          ? null
                          : () => onCambiarEstado(false),
                      icon: cargando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_off_outlined, size: 18),
                      label: const Text('Inactivar cuenta'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rosa,
                        side: const BorderSide(color: AppColors.rosa),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: cargando
                          ? null
                          : () => onCambiarEstado(true),
                      icon: cargando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.person_outline, size: 18),
                      label: const Text('Activar cuenta'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosa,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FotoUsuario extends StatelessWidget {
  final String? url;

  const _FotoUsuario({required this.url});

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

class _RolChip extends StatelessWidget {
  final String texto;

  const _RolChip({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.rosa,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final bool activo;

  const _EstadoChip({required this.activo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: const TextStyle(
          color: AppColors.texto,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
