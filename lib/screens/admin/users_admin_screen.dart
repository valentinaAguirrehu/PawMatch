import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/admin_user.dart';
import 'package:paw_match/services/api_service.dart';

class UsersAdminScreen extends StatefulWidget {
  const UsersAdminScreen({super.key});

  @override
  State<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends State<UsersAdminScreen> {
  late Future<List<AdminUser>> _future = ApiService.listarUsuariosAdmin(
    rol: 'usuario',
  );
  final Set<String> _actualizando = {};
  String _busqueda = '';

  Future<void> _recargar() async {
    final future = ApiService.listarUsuariosAdmin(rol: 'usuario');
    setState(() => _future = future);
    await future;
  }

  Future<void> _cambiarEstado(AdminUser usuario, bool activo) async {
    setState(() => _actualizando.add(usuario.id));
    try {
      final actualizado = await ApiService.cambiarEstadoUsuarioAdmin(
        id: usuario.id,
        activo: activo,
      );
      if (!mounted) return;
      setState(() {
        _actualizando.remove(usuario.id);
        _future = _future.then(
          (usuarios) => [
            for (final item in usuarios)
              if (item.id == actualizado.id) actualizado else item,
          ],
        );
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminUser>>(
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
                const Text('No pudimos cargar los usuarios'),
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

        final usuarios = snap.data!;
        final consulta = _busqueda.trim().toLowerCase();
        final filtrados = usuarios
            .where(
              (u) =>
                  u.nombreCompleto.toLowerCase().contains(consulta) ||
                  u.correo.toLowerCase().contains(consulta),
            )
            .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() => _busqueda = value),
                decoration: const InputDecoration(
                  labelText: 'Buscar usuario',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _recargar,
                child: filtrados.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 100),
                          Center(
                            child: Text(
                              usuarios.isEmpty
                                  ? 'Aún no hay usuarios registrados'
                                  : 'No hay usuarios que coincidan con la búsqueda',
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: filtrados.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final usuario = filtrados[index];
                          final cargando = _actualizando.contains(usuario.id);
                          return SwitchListTile(
                            title: Text(
                              usuario.nombreCompleto.isEmpty
                                  ? 'Sin nombre'
                                  : usuario.nombreCompleto,
                            ),
                            subtitle: Text(
                              '${usuario.correo}\n'
                              '${usuario.telefono.isEmpty ? 'Sin teléfono' : usuario.telefono}'
                              ' · ${usuario.activo ? 'Activo' : 'Inactivo'}',
                            ),
                            isThreeLine: true,
                            value: usuario.activo,
                            onChanged: cargando
                                ? null
                                : (activo) => _cambiarEstado(usuario, activo),
                            secondary: cargando
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : CircleAvatar(
                                    backgroundColor: AppColors.rosaClaro,
                                    child: Icon(
                                      Icons.person_outline,
                                      color: AppColors.rosa,
                                    ),
                                  ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
