import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/screens/admin/adoption_form__follow_up.dart';
import 'package:paw_match/screens/adoption/adoption_detail_admin_screen.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Mascotas del sistema que ya están adoptadas y tienen el contrato subido.
class AdoptionFollowUpAdminScreen extends StatefulWidget {
  const AdoptionFollowUpAdminScreen({super.key});

  @override
  State<AdoptionFollowUpAdminScreen> createState() =>
      _AdoptionFollowUpAdminScreenState();
}

class _MascotaAdoptada {
  final Pet mascota;
  final AdoptionRequest solicitud;

  const _MascotaAdoptada({required this.mascota, required this.solicitud});
}

class _AdoptionFollowUpAdminScreenState extends State<AdoptionFollowUpAdminScreen> {
  late Future<List<_MascotaAdoptada>> _future = _cargar();
  String _busqueda = '';

  Future<List<_MascotaAdoptada>> _cargar() async {
    final resultados = await Future.wait([
      PetsService.listar(),
      AdoptionService.listForAdmin(),
    ]);
    final mascotas = resultados[0] as List<Pet>;
    final solicitudes = resultados[1] as List<AdoptionRequest>;

    final contratoPorMascota = <String, AdoptionRequest>{};
    for (final solicitud in solicitudes) {
      if (!solicitud.isApproved || !solicitud.hasContract) continue;
      final actual = contratoPorMascota[solicitud.petId];
      if (actual == null) {
        contratoPorMascota[solicitud.petId] = solicitud;
        continue;
      }
      final fechaNueva = solicitud.adoptionStartDate ?? solicitud.requestedAt;
      final fechaActual = actual.adoptionStartDate ?? actual.requestedAt;
      if (fechaNueva.compareTo(fechaActual) > 0) {
        contratoPorMascota[solicitud.petId] = solicitud;
      }
    }

    final lista = <_MascotaAdoptada>[
      for (final mascota in mascotas)
        if (mascota.estaAdoptada && contratoPorMascota.containsKey(mascota.id))
          _MascotaAdoptada(
            mascota: mascota,
            solicitud: contratoPorMascota[mascota.id]!,
          ),
    ];
    lista.sort(
      (a, b) => a.mascota.nombre.toLowerCase().compareTo(b.mascota.nombre.toLowerCase()),
    );
    return lista;
  }

  Future<void> _recargar() async {
    final future = _cargar();
    setState(() => _future = future);
    await future.catchError((_) => <_MascotaAdoptada>[]);
  }

  List<_MascotaAdoptada> _filtrar(List<_MascotaAdoptada> todas) {
    final consulta = _busqueda.trim().toLowerCase();
    if (consulta.isEmpty) return todas;
    return todas.where((item) {
      return item.mascota.nombre.toLowerCase().contains(consulta) ||
          item.solicitud.applicantFullName.toLowerCase().contains(consulta);
    }).toList();
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (!confirmar || !mounted) return;
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    Session.cerrar();
    Navegacion.ir(context, const WelcomeScreen());
  }

  Widget _conBarra(Widget contenido, {VoidCallback? onVolver}) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            BarraSuperior(
              iconoTitulo: Icons.favorite_rounded,
              titulo: 'Seguimiento',
              onCerrarSesion: _confirmarCerrarSesion,
              onVolver: onVolver,
            ),
            Expanded(child: contenido),
          ],
        ),
      ),
    );
  }

  void _verDetalles(AdoptionRequest solicitud) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => _conBarra(
          onVolver: () => Navigator.pop(ctx),
          AdoptionDetailAdminScreen(
            request: solicitud,
            enPagina: true,
            onCambioEstado: (_) {
              Navigator.pop(context);
              _recargar();
            },
          ),
        ),
      ),
    );
  }

  void _realizarSeguimiento(_MascotaAdoptada item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdoptionFormFollowUp(
          mascota: item.mascota,
          solicitud: item.solicitud,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _conBarra(
      FutureBuilder<List<_MascotaAdoptada>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorCarga(
              mensaje: 'No pudimos cargar las mascotas adoptadas',
              detalle: snap.error.toString().replaceFirst('Exception: ', ''),
              onReintentar: _recargar,
            );
          }

          final mascotas = _filtrar(snap.data ?? []);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  onChanged: (valor) => setState(() => _busqueda = valor),
                  decoration: const InputDecoration(
                    labelText: 'Buscar mascota o adoptante',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${mascotas.length} '
                    '${mascotas.length == 1 ? 'mascota adoptada' : 'mascotas adoptadas'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.texto,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _recargar,
                  child: mascotas.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            _Vacio(
                              texto:
                                  'No hay mascotas adoptadas con el contrato de adopción subido.',
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: mascotas.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = mascotas[index];
                            return _TarjetaMascota(
                              mascota: item.mascota,
                              persona: 'Adoptante: ${item.solicitud.applicantFullName}',
                              detalle:
                                  'Inicio: ${item.solicitud.adoptionStartDateLabel ?? 'Sin fecha'}',
                              onVerDetalles: () => _verDetalles(item.solicitud),
                              onSeguimiento: () => _realizarSeguimiento(item),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TarjetaMascota extends StatelessWidget {
  final Pet mascota;
  final String persona;
  final String detalle;
  final VoidCallback onVerDetalles;
  final VoidCallback onSeguimiento;

  const _TarjetaMascota({
    required this.mascota,
    required this.persona,
    required this.detalle,
    required this.onVerDetalles,
    required this.onSeguimiento,
  });

  @override
  Widget build(BuildContext context) {
    final raza = (mascota.raza ?? '').trim();
    final resumen = [
      mascota.especie,
      if (raza.isNotEmpty) raza,
      mascota.edadTexto,
    ].join(' · ');

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: PetImage(url: mascota.foto),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mascota.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resumen,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        persona,
                        style: const TextStyle(fontSize: 13, color: AppColors.texto),
                      ),
                      Text(
                        detalle,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rosa,
                      side: const BorderSide(color: AppColors.rosa),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onVerDetalles,
                    child: const Text(
                      'Ver Detalles de Adopción',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosa,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onSeguimiento,
                    child: const Text(
                      'Realizar Seguimiento',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
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

class _Vacio extends StatelessWidget {
  final String texto;

  const _Vacio({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Icon(Icons.pets_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  final String mensaje;
  final String detalle;
  final VoidCallback onReintentar;

  const _ErrorCarga({
    required this.mensaje,
    required this.detalle,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.rosa),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
