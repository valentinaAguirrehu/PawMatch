import 'package:flutter/material.dart';
import '../models/pet.dart';
import '../services/mascota_service.dart';
import '../widgets/pet_card.dart';
import 'mascota_detalle_screen.dart';

/// Lista de mascotas para el usuario (RF04): busca, filtra y abre el detalle.
class MascotasScreen extends StatefulWidget {
  const MascotasScreen({super.key});

  @override
  State<MascotasScreen> createState() => _MascotasScreenState();
}

class _MascotasScreenState extends State<MascotasScreen> {
  late Future<List<Pet>> _future = MascotaService.listar();
  String _busqueda = '';
  String _especie = 'Todas';

  static const _filtros = ['Todas', 'Perro', 'Gato', 'Otro'];

  Future<void> _recargar() async {
    setState(() => _future = MascotaService.listar());
    await _future.catchError((_) => <Pet>[]);
  }

  List<Pet> _filtrar(List<Pet> pets) {
    return pets.where((p) {
      final esp = p.especie.toLowerCase();
      final coincideEspecie = switch (_especie) {
        'Todas' => true,
        'Otro' => esp != 'perro' && esp != 'gato',
        _ => esp == _especie.toLowerCase(),
      };
      final q = _busqueda.toLowerCase();
      final coincideTexto = q.isEmpty ||
          p.nombre.toLowerCase().contains(q) ||
          (p.raza ?? '').toLowerCase().contains(q);
      return coincideEspecie && coincideTexto;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o raza',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _busqueda = v.trim()),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final f in _filtros)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: _especie == f,
                    onSelected: (_) => setState(() => _especie = f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Pet>>(
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
              final pets = _filtrar(snap.data!);
              return RefreshIndicator(
                onRefresh: _recargar,
                child: pets.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('No hay mascotas para mostrar')),
                        ],
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        physics: const AlwaysScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: pets.length,
                        itemBuilder: (_, i) => PetCard(
                          pet: pets[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MascotaDetalleScreen(pet: pets[i]),
                            ),
                          ),
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}
