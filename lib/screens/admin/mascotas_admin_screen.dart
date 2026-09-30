import 'package:flutter/material.dart';
import '../../../models/pet.dart';
import '../../../services/mascota_service.dart';
import '../../../widgets/pet_card.dart';
import '../admin/mascota_form_screen.dart';

/// Gestión de mascotas para el administrador (RF16): listar, agregar,
/// editar y eliminar.
class MascotasAdminScreen extends StatefulWidget {
  const MascotasAdminScreen({super.key});

  @override
  State<MascotasAdminScreen> createState() => _MascotasAdminScreenState();
}

class _MascotasAdminScreenState extends State<MascotasAdminScreen> {
  late Future<List<Pet>> _future = MascotaService.listar();

  Future<void> _recargar() async {
    setState(() => _future = MascotaService.listar());
    await _future.catchError((_) => <Pet>[]);
  }

  Future<void> _abrirFormulario([Pet? pet]) async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MascotaFormScreen(pet: pet)),
    );
    if (guardado == true) _recargar();
  }

  Future<void> _eliminar(Pet pet) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar mascota'),
        content: Text(
          '¿Seguro que quieres eliminar a ${pet.nombre}? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await MascotaService.eliminar(pet.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${pet.nombre} fue eliminada')));
      _recargar();
    } catch (e) {
      if (!mounted) return;
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
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar mascota'),
      ),
      body: FutureBuilder<List<Pet>>(
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
                  const Text('No pudimos cargar las mascotas'),
                  TextButton(
                    onPressed: _recargar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final pets = snap.data!;
          return RefreshIndicator(
            onRefresh: _recargar,
            child: pets.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Aún no hay mascotas registradas')),
                    ],
                  )
                : ListView.separated(
                    // espacio abajo para que el botón no tape el último item
                    padding: const EdgeInsets.only(bottom: 88),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: pets.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = pets[i];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: PetImage(url: p.foto),
                          ),
                        ),
                        title: Text(p.nombre),
                        subtitle: Text(
                          [p.especie, if (p.raza != null) p.raza!].join(' · '),
                        ),
                        onTap: () => _abrirFormulario(p),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            EstadoChip(estado: p.estadoAdopcion),
                            PopupMenuButton<String>(
                              onSelected: (v) => v == 'editar'
                                  ? _abrirFormulario(p)
                                  : _eliminar(p),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'editar',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'eliminar',
                                  child: Text('Eliminar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
