import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/admin/apadrinamiento_form__follow_up.dart';
import 'package:paw_match/screens/apadrinamiento/apadrinamiento_admin_screen.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Mascotas del sistema que ya están apadrinadas y tienen el contrato subido.
class ApadrinacionFollowUpAdminScreen extends StatefulWidget {
  const ApadrinacionFollowUpAdminScreen({super.key});

  @override
  State<ApadrinacionFollowUpAdminScreen> createState() =>
      _ApadrinacionFollowUpAdminScreenState();
}

class _MascotaApadrinada {
  final Pet mascota;
  final SolicitudApadrinamiento solicitud;

  const _MascotaApadrinada({required this.mascota, required this.solicitud});
}

class _ApadrinacionFollowUpAdminScreenState
    extends State<ApadrinacionFollowUpAdminScreen> {
  late Future<List<_MascotaApadrinada>> _future = _cargar();
  String _busqueda = '';

  Future<List<_MascotaApadrinada>> _cargar() async {
    final resultados = await Future.wait([
      PetsService.listar(),
      ApadrinamientoService.listarParaAdmin(),
    ]);
    final mascotas = resultados[0] as List<Pet>;
    final solicitudes = resultados[1] as List<SolicitudApadrinamiento>;

    final contratoPorMascota = <String, SolicitudApadrinamiento>{};
    for (final solicitud in solicitudes) {
      if (!solicitud.esAprobada || !solicitud.tieneContrato) continue;
      final actual = contratoPorMascota[solicitud.idMascota];
      if (actual == null) {
        contratoPorMascota[solicitud.idMascota] = solicitud;
        continue;
      }
      final fechaNueva = solicitud.fechaInicioApadrinamiento ?? solicitud.fechaSolicitud;
      final fechaActual = actual.fechaInicioApadrinamiento ?? actual.fechaSolicitud;
      if (fechaNueva.compareTo(fechaActual) > 0) {
        contratoPorMascota[solicitud.idMascota] = solicitud;
      }
    }

    final lista = <_MascotaApadrinada>[
      for (final mascota in mascotas)
        if (mascota.estaApadrinada && contratoPorMascota.containsKey(mascota.id))
          _MascotaApadrinada(
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
    await future.catchError((_) => <_MascotaApadrinada>[]);
  }

  List<_MascotaApadrinada> _filtrar(List<_MascotaApadrinada> todas) {
    final consulta = _busqueda.trim().toLowerCase();
    if (consulta.isEmpty) return todas;
    return todas.where((item) {
      return item.mascota.nombre.toLowerCase().contains(consulta) ||
          item.solicitud.solicitanteNombreCompleto.toLowerCase().contains(consulta);
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

  void _verDetalles(SolicitudApadrinamiento solicitud) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => _conBarra(
          onVolver: () => Navigator.pop(ctx),
          DetalleSolicitudApadrinamiento(
            solicitud: solicitud,
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

  void _realizarSeguimiento(_MascotaApadrinada item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApadrinamientoFormFollowUp(
          mascota: item.mascota,
          solicitud: item.solicitud,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _conBarra(
      FutureBuilder<List<_MascotaApadrinada>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorCarga(
              mensaje: 'No pudimos cargar las mascotas apadrinadas',
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
                    labelText: 'Buscar mascota o padrino',
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
                    '${mascotas.length == 1 ? 'mascota apadrinada' : 'mascotas apadrinadas'}',
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
                                  'No hay mascotas apadrinadas con el contrato de apadrinamiento subido.',
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
                            final aporte = item.solicitud.montoAporte == null
                                ? item.solicitud.tipoAporte
                                : '\$${item.solicitud.montoAporte} · ${item.solicitud.frecuenciaAporte}';
                            return _TarjetaMascota(
                              mascota: item.mascota,
                              persona: 'Padrino: ${item.solicitud.solicitanteNombreCompleto}',
                              detalle: 'Aporte: $aporte',
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
                      'Ver Detalles de Apadrinación',
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
