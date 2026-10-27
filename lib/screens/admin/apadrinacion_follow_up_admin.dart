import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/seguimiento_apadrinamiento.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/admin/apadrinamiento_form__follow_up.dart';
import 'package:paw_match/screens/apadrinamiento/apadrinamiento_admin_screen.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/reporte_padrino_pdf_service.dart';
import 'package:paw_match/services/seguimiento_apadrinamiento_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/calendario_seguimientos.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';
import 'package:paw_match/widgets/star_rating_selector.dart';
import 'package:paw_match/widgets/tarjeta_seguimiento.dart';

/// Pantalla administrativa de Seguimiento de Apadrinamientos con vista de lista y calendario.
class ApadrinacionFollowUpAdminScreen extends StatefulWidget {
  const ApadrinacionFollowUpAdminScreen({super.key});

  @override
  State<ApadrinacionFollowUpAdminScreen> createState() =>
      _ApadrinacionFollowUpAdminScreenState();
}

class _ApadrinacionFollowUpAdminScreenState
    extends State<ApadrinacionFollowUpAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<ApadrinamientoActivoSeguimiento>> _futureActivos;
  late Future<List<ItemCalendarioSeguimiento>> _futureCalendario;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _cargarTodo() {
    _futureActivos = SeguimientoApadrinamientoService.listarApadrinamientosActivos();
    _futureCalendario = SeguimientoApadrinamientoService.obtenerCalendario();
  }

  Future<void> _recargar() async {
    setState(() {
      _cargarTodo();
    });
    await Future.wait([
      _futureActivos.catchError((_) => <ApadrinamientoActivoSeguimiento>[]),
      _futureCalendario.catchError((_) => <ItemCalendarioSeguimiento>[]),
    ]);
  }

  List<ApadrinamientoActivoSeguimiento> _filtrar(
      List<ApadrinamientoActivoSeguimiento> todas) {
    final consulta = _busqueda.trim().toLowerCase();
    if (consulta.isEmpty) return todas;
    return todas.where((item) {
      return item.mascotaNombre.toLowerCase().contains(consulta) ||
          item.padrinoNombre.toLowerCase().contains(consulta);
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

  void _realizarSeguimiento(ApadrinamientoActivoSeguimiento item) {
    final pet = Pet(
      id: item.idMascota,
      nombre: item.mascotaNombre,
      especie: item.mascotaEspecie,
      raza: item.mascotaRaza,
      edad: item.mascotaEdad,
      unidadEdad: item.mascotaUnidadEdad,
      foto: item.mascotaFotos is List && item.mascotaFotos.isNotEmpty
          ? item.mascotaFotos[0].toString()
          : item.mascotaFotos.toString(),
      estadoAdopcion: 'apadrinado',
    );

    final fotoStr = item.mascotaFotos is List && item.mascotaFotos.isNotEmpty
        ? item.mascotaFotos[0].toString()
        : item.mascotaFotos.toString();

    final solicitud = SolicitudApadrinamiento(
      id: item.idSolicitud,
      idMascota: item.idMascota,
      idUsuario: item.idPadrino,
      solicitanteNombres: item.padrinoNombre,
      solicitanteCorreo: item.padrinoCorreo,
      solicitanteTelefono: item.padrinoTelefono,
      mascotaNombre: item.mascotaNombre,
      mascotaFotos: fotoStr,
      mascotaEspecie: item.mascotaEspecie,
      mascotaRaza: item.mascotaRaza,
      mascotaEdad: item.mascotaEdad,
      tipoAporte: item.tipoAporte,
      montoAporte: item.montoAporte,
      frecuenciaAporte: item.frecuenciaAporte,
      motivacion: 'Apadrinamiento activo formalizado',
      estado: item.estado,
      contratoArchivo: item.contratoArchivo,
      fechaSolicitud: DateTime.now().toIso8601String(),
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApadrinamientoFormFollowUp(
          mascota: pet,
          solicitud: solicitud,
          onGuardadoExitoso: _recargar,
        ),
      ),
    );
  }

  void _verHistorial(ApadrinamientoActivoSeguimiento item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.45,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FD),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Historial de ${item.mascotaNombre}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                              ),
                              Text(
                                'Padrino: ${item.padrinoNombre}',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        StarRatingBadge(rating: item.calificacionPromedio, totalSeguimientos: item.totalSeguimientos),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder<List<SeguimientoApadrinamientoItem>>(
                      future: SeguimientoApadrinamientoService.obtenerHistorial(item.idSolicitud),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final lista = snap.data ?? [];
                        if (lista.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'No se han registrado seguimientos para este apadrinamiento.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'El reporte se habilita a partir de 3 seguimientos (0/3)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                              child: lista.length >= 3
                                  ? SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.rosa,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 11),
                                        ),
                                        onPressed: () {
                                          ReportePadrinoPdfService.generarYDescargarReporte(
                                            padrinoNombre: item.padrinoNombre,
                                            padrinoCorreo: item.padrinoCorreo,
                                            padrinoTelefono: item.padrinoTelefono,
                                            mascotaNombre: item.mascotaNombre,
                                            mascotaEspecie: item.mascotaEspecie,
                                            mascotaRaza: item.mascotaRaza,
                                            mascotaEdad: '${item.mascotaEdad} ${item.mascotaUnidadEdad}',
                                            seguimientos: lista,
                                            estadoApadrinamiento: item.estadoApadrinamiento,
                                            motivoCancelacion: item.motivoCancelacion,
                                            fechaCancelacion: item.fechaCancelacion,
                                          );
                                        },
                                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                                        label: const Text(
                                          'Descargar reporte PDF',
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.info_outline_rounded, size: 17, color: Colors.grey.shade700),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              'El reporte se habilita a partir de 3 seguimientos (${lista.length}/3)',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                                itemCount: lista.length,
                                itemBuilder: (_, index) => TarjetaSeguimiento(seguimiento: lista[index]),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _verDetallesSolicitud(ApadrinamientoActivoSeguimiento item) {
    final fotoStr = item.mascotaFotos is List && item.mascotaFotos.isNotEmpty
        ? item.mascotaFotos[0].toString()
        : item.mascotaFotos.toString();

    final solicitud = SolicitudApadrinamiento(
      id: item.idSolicitud,
      idMascota: item.idMascota,
      idUsuario: item.idPadrino,
      solicitanteNombres: item.padrinoNombre,
      solicitanteCorreo: item.padrinoCorreo,
      solicitanteTelefono: item.padrinoTelefono,
      mascotaNombre: item.mascotaNombre,
      mascotaFotos: fotoStr,
      mascotaEspecie: item.mascotaEspecie,
      mascotaRaza: item.mascotaRaza,
      mascotaEdad: item.mascotaEdad,
      tipoAporte: item.tipoAporte,
      montoAporte: item.montoAporte,
      frecuenciaAporte: item.frecuenciaAporte,
      motivacion: 'Apadrinamiento activo formalizado',
      estado: item.estado,
      contratoArchivo: item.contratoArchivo,
      fechaSolicitud: DateTime.now().toIso8601String(),
    );

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

  Future<void> _dialogoCancelarApadrinamiento(ApadrinamientoActivoSeguimiento item) async {
    final motivoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.gavel_rounded, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Cancelar Apadrinamiento',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se cancelará el apadrinamiento de ${item.mascotaNombre} y el usuario ${item.padrinoNombre} quedará BLOQUEADO para volver a apadrinar mascotas.',
                style: TextStyle(color: Colors.grey.shade800, fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: motivoCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Motivo de la cancelación *',
                  hintText: 'Ej. Acumulación de 3 incumplimientos consecutivos sin respuesta',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El motivo de la cancelación es obligatorio';
                  }
                  if (v.trim().length < 8) {
                    return 'Ingresa un motivo detallado (mínimo 8 caracteres)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Confirmar Cancelación'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      await SeguimientoApadrinamientoService.cancelarApadrinamientoPorIncumplimiento(
        idSolicitud: item.idSolicitud,
        motivo: motivoCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          content: Text('Apadrinamiento cancelado y usuario bloqueado para nuevos apadrinamientos.'),
        ),
      );
      _recargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al cancelar: $e'),
        ),
      );
    } finally {
      motivoCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _conBarra(
      Column(
        children: [
          // Selector de pestañas: Lista Activos vs Calendario
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0E5EC)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.rosa,
              labelColor: AppColors.rosa,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              tabs: const [
                Tab(icon: Icon(Icons.list_alt_rounded), text: 'Apadrinamientos Activos'),
                Tab(icon: Icon(Icons.calendar_month_rounded), text: 'Próximos Seguimientos'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // PESTAÑA 1: LISTA DE APADRINAMIENTOS ACTIVOS
                _construirPestanaLista(),

                // PESTAÑA 2: CALENDARIO DE SEGUIMIENTOS
                _construirPestanaCalendario(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirPestanaLista() {
    return FutureBuilder<List<ApadrinamientoActivoSeguimiento>>(
      future: _futureActivos,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorCarga(
            mensaje: 'No pudimos cargar los apadrinamientos activos',
            detalle: snap.error.toString().replaceFirst('Exception: ', ''),
            onReintentar: _recargar,
          );
        }

        final mascotas = _filtrar(snap.data ?? []);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: TextField(
                onChanged: (valor) => setState(() => _busqueda = valor),
                decoration: InputDecoration(
                  hintText: 'Buscar mascota o padrino...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.rosa),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFF0E5EC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFF0E5EC)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${mascotas.length} '
                    '${mascotas.length == 1 ? 'apadrinamiento activo' : 'apadrinamientos activos'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.texto,
                      fontSize: 13.5,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: _recargar,
                    icon: const Icon(Icons.refresh, size: 16, color: AppColors.rosa),
                    label: const Text('Actualizar', style: TextStyle(fontSize: 12, color: AppColors.rosa)),
                  ),
                ],
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
                                'No hay apadrinamientos activos con contrato firmado en este momento.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: mascotas.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = mascotas[index];
                          return _TarjetaSeguimientoAdmin(
                            item: item,
                            onVerDetalles: () => _verDetallesSolicitud(item),
                            onSeguimiento: () => _realizarSeguimiento(item),
                            onVerHistorial: () => _verHistorial(item),
                            onCancelarApadrinamiento: () => _dialogoCancelarApadrinamiento(item),
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

  Widget _construirPestanaCalendario() {
    return FutureBuilder<List<ItemCalendarioSeguimiento>>(
      future: _futureCalendario,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorCarga(
            mensaje: 'Error al cargar el calendario de seguimientos',
            detalle: snap.error.toString().replaceFirst('Exception: ', ''),
            onReintentar: _recargar,
          );
        }

        final eventos = snap.data ?? [];
        return CalendarioSeguimientosWidget(
          eventos: eventos,
          onRecargar: _recargar,
        );
      },
    );
  }
}

/// Tarjeta enriquecida para cada apadrinamiento en el panel del administrador.
class _TarjetaSeguimientoAdmin extends StatelessWidget {
  final ApadrinamientoActivoSeguimiento item;
  final VoidCallback onVerDetalles;
  final VoidCallback onSeguimiento;
  final VoidCallback onVerHistorial;
  final VoidCallback onCancelarApadrinamiento;

  const _TarjetaSeguimientoAdmin({
    required this.item,
    required this.onVerDetalles,
    required this.onSeguimiento,
    required this.onVerHistorial,
    required this.onCancelarApadrinamiento,
  });

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin registro';
    return '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tieneAlerta = item.tieneTresIncumplimientos;
    final proximoVencido = item.proximoSeguimientoVencido;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: tieneAlerta
              ? Colors.red.shade400
              : (proximoVencido ? Colors.orange.shade300 : const Color(0xFFF2E4EC)),
          width: tieneAlerta ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ALERTA DE 3 INCUMPLIMIENTOS CONSECUTIVOS
            if (tieneAlerta) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Atención! 3 Incumplimientos Consecutivos',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            item.ultimoCorreoAlertaEnviado
                                ? 'Se envió correo de advertencia al padrino.'
                                : 'Padrino en riesgo de cancelación.',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onCancelarApadrinamiento,
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Fila principal: Foto de mascota + Datos del padrino y mascota + Estrellas
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: PetImage(
                      url: item.mascotaFotos is List && item.mascotaFotos.isNotEmpty
                          ? item.mascotaFotos[0].toString()
                          : item.mascotaFotos.toString(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.mascotaNombre,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
                            ),
                          ),
                          StarRatingBadge(
                            rating: item.calificacionPromedio,
                            totalSeguimientos: item.totalSeguimientos,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.resumenMascota,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Padrino: ${item.padrinoNombre}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.texto),
                      ),
                      Text(
                        'Aporte: ${item.resumenAporte}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Fechas de último y próximo seguimiento
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFECEFF5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, size: 15, color: Colors.grey.shade600),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Último seguimiento', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                          Text(
                            _formatearFecha(item.ultimoSeguimientoFecha),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.alarm,
                        size: 15,
                        color: proximoVencido ? Colors.red.shade700 : Colors.purple.shade400,
                      ),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            proximoVencido ? 'Próximo (¡Vencido!)' : 'Próximo seguimiento',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: proximoVencido ? Colors.red.shade700 : Colors.grey,
                              fontWeight: proximoVencido ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                          Text(
                            _formatearFecha(item.proximoSeguimientoFecha),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: proximoVencido ? Colors.red.shade900 : AppColors.texto,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Botonera de acciones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rosa,
                      side: const BorderSide(color: AppColors.rosa),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onVerHistorial,
                    child: const Text(
                      'Historial',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosa,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
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
