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
    if (item.evaluacionPendiente) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text(
            'Primero debes evaluar al padrino para cerrar el ciclo actual antes de registrar un nuevo seguimiento.',
          ),
        ),
      );
      _evaluarPadrino(item);
      return;
    }

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
      aportaMonetario: item.aportaMonetario,
      montoComprometido: item.montoComprometido,
      periodicidad: item.periodicidad,
      aportaEspecie: item.aportaEspecie,
      detalleEspecie: item.detalleEspecie,
      aportaOtro: item.aportaOtro,
      detalleOtro: item.detalleOtro,
      cicloActual: item.cicloActual,
      seguimientosEnCiclo: item.seguimientosEnCiclo,
      totalSeguimientos: item.totalSeguimientos,
      evaluacionesCiclos: item.evaluacionesCiclos,
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
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
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
                        StarRatingBadge(
                          rating: item.calificacionPromedio,
                          totalSeguimientos: item.totalSeguimientos,
                        ),
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
                                    'El reporte se habilita a partir de 3 seguimientos (${item.seguimientosEnCiclo}/3)',
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

                        // Agrupar seguimientos por ciclo
                        final Map<int, List<SeguimientoApadrinamientoItem>> porCiclo = {};
                        for (final s in lista) {
                          final c = s.ciclo;
                          porCiclo.putIfAbsent(c, () => []).add(s);
                        }

                        // Determinar qué ciclos tienen reportes disponibles (al menos 3 seguimientos o evaluación)
                        final ciclosConReporte = porCiclo.keys.where((c) {
                          return (porCiclo[c]?.length ?? 0) >= 3 ||
                              item.evaluacionesCiclos.any((e) => e.ciclo == c);
                        }).toList()..sort();

                        return ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          children: [
                            // FILAS DE REPORTES PDF CON BOTONES SEPARADOS "VER" Y "DESCARGAR" (CAMBIO 4)
                            if (ciclosConReporte.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 8),
                                child: Text(
                                  'Reportes Oficiales de Seguimiento:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppColors.texto,
                                  ),
                                ),
                              ),
                              ...ciclosConReporte.map((c) {
                                final segsDelCiclo = porCiclo[c] ?? [];
                                final ev = item.evaluacionesCiclos.where((e) => e.ciclo == c).firstOrNull;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFF0E5EC)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.picture_as_pdf_rounded, color: AppColors.rosa, size: 22),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Reporte del Ciclo $c',
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                            ),
                                            Text(
                                              ev != null
                                                  ? 'Evaluado (${ev.clasificacionTexto} · ${ev.promedio.toStringAsFixed(1)}/5)'
                                                  : 'Ciclo completo (3/3)',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Botón "Ver reporte" (solo vista previa)
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.rosa,
                                          side: const BorderSide(color: AppColors.rosa),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          minimumSize: const Size(0, 34),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          ReportePadrinoPdfService.verReporte(
                                            padrinoNombre: item.padrinoNombre,
                                            padrinoCorreo: item.padrinoCorreo,
                                            padrinoTelefono: item.padrinoTelefono,
                                            mascotaNombre: item.mascotaNombre,
                                            mascotaEspecie: item.mascotaEspecie,
                                            mascotaRaza: item.mascotaRaza,
                                            mascotaEdad: '${item.mascotaEdad} ${item.mascotaUnidadEdad}',
                                            seguimientos: segsDelCiclo,
                                            cicloReporte: c,
                                            ciclosAnteriores: item.evaluacionesCiclos.where((e) => e.ciclo < c).toList(),
                                            estadoApadrinamiento: item.estadoApadrinamiento,
                                            motivoCancelacion: item.motivoCancelacion,
                                            fechaCancelacion: item.fechaCancelacion,
                                            decisionAdmin: ev?.decision ?? item.decisionAdmin,
                                            notaDecision: ev?.nota ?? item.notaDecision,
                                            fechaDecision: ev?.fechaDecision ?? item.fechaDecision,
                                            adminDecisionNombre: ev?.adminNombre ?? item.adminDecisionNombre,
                                          );
                                        },
                                        icon: const Icon(Icons.visibility_outlined, size: 15),
                                        label: const Text('Ver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 6),
                                      // Botón "Descargar PDF" (solo descargar)
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.rosa,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          minimumSize: const Size(0, 34),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          ReportePadrinoPdfService.descargarReporte(
                                            padrinoNombre: item.padrinoNombre,
                                            padrinoCorreo: item.padrinoCorreo,
                                            padrinoTelefono: item.padrinoTelefono,
                                            mascotaNombre: item.mascotaNombre,
                                            mascotaEspecie: item.mascotaEspecie,
                                            mascotaRaza: item.mascotaRaza,
                                            mascotaEdad: '${item.mascotaEdad} ${item.mascotaUnidadEdad}',
                                            seguimientos: segsDelCiclo,
                                            cicloReporte: c,
                                            ciclosAnteriores: item.evaluacionesCiclos.where((e) => e.ciclo < c).toList(),
                                            estadoApadrinamiento: item.estadoApadrinamiento,
                                            motivoCancelacion: item.motivoCancelacion,
                                            fechaCancelacion: item.fechaCancelacion,
                                            decisionAdmin: ev?.decision ?? item.decisionAdmin,
                                            notaDecision: ev?.nota ?? item.notaDecision,
                                            fechaDecision: ev?.fechaDecision ?? item.fechaDecision,
                                            adminDecisionNombre: ev?.adminNombre ?? item.adminDecisionNombre,
                                          );
                                        },
                                        icon: const Icon(Icons.download_rounded, size: 15),
                                        label: const Text('Descargar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                            ] else ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                        'El reporte se habilita a partir de 3 seguimientos (${item.seguimientosEnCiclo}/3)',
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
                            ],

                            // LISTA DETALLADA DE SEGUIMIENTOS
                            const Padding(
                              padding: EdgeInsets.only(left: 4, top: 8, bottom: 4),
                              child: Text(
                                'Historial de registros:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.texto,
                                ),
                              ),
                            ),
                            ...lista.map((seg) => TarjetaSeguimiento(seguimiento: seg)),
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
      aportaMonetario: item.aportaMonetario,
      montoComprometido: item.montoComprometido,
      periodicidad: item.periodicidad,
      aportaEspecie: item.aportaEspecie,
      detalleEspecie: item.detalleEspecie,
      aportaOtro: item.aportaOtro,
      detalleOtro: item.detalleOtro,
      cicloActual: item.cicloActual,
      seguimientosEnCiclo: item.seguimientosEnCiclo,
      totalSeguimientos: item.totalSeguimientos,
      evaluacionesCiclos: item.evaluacionesCiclos,
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
    bool bloquearUsuario = item.calificacionPromedio < 3.0;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Se cancelará el apadrinamiento de ${item.mascotaNombre} para el usuario ${item.padrinoNombre}.',
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13.5),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: motivoCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Motivo de la cancelación *',
                      hintText: 'Ej. Incumplimiento reiterado de compromisos',
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
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: bloquearUsuario,
                    activeColor: Colors.red.shade700,
                    title: const Text(
                      'Impedir que vuelva a apadrinar',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Inhabilita al usuario para enviar nuevas solicitudes de apadrinamiento.',
                      style: TextStyle(fontSize: 11),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        bloquearUsuario = val ?? false;
                      });
                    },
                  ),
                ],
              ),
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
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      await SeguimientoApadrinamientoService.cancelarApadrinamientoPorIncumplimiento(
        idSolicitud: item.idSolicitud,
        motivo: motivoCtrl.text.trim(),
        bloquearUsuario: bloquearUsuario,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          content: Text(
            bloquearUsuario
                ? 'Apadrinamiento cancelado y usuario bloqueado para nuevos apadrinamientos.'
                : 'Apadrinamiento cancelado exitosamente.',
          ),
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

  void _evaluarPadrino(ApadrinamientoActivoSeguimiento item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModalEvaluacionPadrino(
        item: item,
        onGuardadoExitoso: _recargar,
      ),
    );
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
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
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
                            onEvaluarPadrino: () => _evaluarPadrino(item),
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
  final VoidCallback onEvaluarPadrino;

  const _TarjetaSeguimientoAdmin({
    required this.item,
    required this.onVerDetalles,
    required this.onSeguimiento,
    required this.onVerHistorial,
    required this.onCancelarApadrinamiento,
    required this.onEvaluarPadrino,
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

            // BANNER EVALUACIÓN PENDIENTE (Al completar 3/3 en el ciclo actual)
            if (item.evaluacionPendiente) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFD54F), width: 1.3),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.rate_review_rounded, color: Color(0xFFF57F17), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evaluación pendiente (Ciclo ${item.cicloActual})',
                            style: const TextStyle(
                              color: Color(0xFFE65100),
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            '3/3 seguimientos completados en este ciclo',
                            style: const TextStyle(
                              color: Color(0xFFBF360C),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onEvaluarPadrino,
                      child: const Text(
                        'Evaluar padrino',
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

            // BARRA DE PROGRESO DEL CICLO ACTUAL (CAMBIO 1)
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFECEFF5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ciclo ${item.cicloActual} · ${item.seguimientosEnCiclo}/3 seguimientos',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.texto,
                        ),
                      ),
                      Text(
                        '${(item.seguimientosEnCiclo * 100 ~/ 3)}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          color: AppColors.rosa,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (item.seguimientosEnCiclo / 3.0).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.rosa),
                    ),
                  ),
                ],
              ),
            ),

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
                      backgroundColor: item.evaluacionPendiente ? const Color(0xFFE65100) : AppColors.rosa,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: item.evaluacionPendiente ? onEvaluarPadrino : onSeguimiento,
                    child: Text(
                      item.evaluacionPendiente ? 'Evaluar Ciclo ${item.cicloActual}' : 'Realizar Seguimiento',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(mensaje, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(detalle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal inferior para evaluar al padrino al llegar a 3 seguimientos o en cualquier ciclo.
class _ModalEvaluacionPadrino extends StatefulWidget {
  final ApadrinamientoActivoSeguimiento item;
  final VoidCallback onGuardadoExitoso;

  const _ModalEvaluacionPadrino({
    required this.item,
    required this.onGuardadoExitoso,
  });

  @override
  State<_ModalEvaluacionPadrino> createState() => _ModalEvaluacionPadrinoState();
}

class _ModalEvaluacionPadrinoState extends State<_ModalEvaluacionPadrino> {
  final _formKey = GlobalKey<FormState>();
  final _notaCtrl = TextEditingController();
  bool _guardando = false;
  late Future<List<SeguimientoApadrinamientoItem>> _historialFuture;

  @override
  void initState() {
    super.initState();
    _historialFuture = SeguimientoApadrinamientoService.obtenerHistorial(widget.item.idSolicitud);
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _ejecutarDecision(
    String decision, {
    String? motivoCancelacion,
    bool bloquearUsuario = false,
  }) async {
    setState(() => _guardando = true);
    try {
      final notaFinal = decision == 'cancelar' ? motivoCancelacion : _notaCtrl.text.trim();
      final res = await SeguimientoApadrinamientoService.registrarEvaluacion(
        idSolicitud: widget.item.idSolicitud,
        decision: decision,
        nota: notaFinal,
        ciclo: widget.item.cicloActual,
        bloquearUsuario: bloquearUsuario,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar bottom sheet

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: decision == 'continuar' ? AppColors.rosa : Colors.red.shade700,
          content: Text(res['mensaje']?.toString() ?? 'Evaluación registrada exitosamente.'),
        ),
      );

      widget.onGuardadoExitoso();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _dialogoConfirmarCancelar() async {
    final motivoCtrl = TextEditingController();
    final cancelFormKey = GlobalKey<FormState>();
    // REGLA CAMBIO 1: Casilla marcada por defecto solo si el promedio del ciclo es menor a 3
    bool bloquearUsuario = widget.item.esMalPadrino;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.gavel_rounded, color: Colors.red.shade700, size: 26),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Cancelar Apadrinamiento',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
            ],
          ),
          content: Form(
            key: cancelFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Esta acción cancelará el apadrinamiento de ${widget.item.mascotaNombre} para el usuario ${widget.item.padrinoNombre}.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: motivoCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Motivo de la cancelación *',
                      hintText: 'Ingresa la razón detallada...',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'El motivo de la cancelación es obligatorio';
                      }
                      if (v.trim().length < 8) {
                        return 'El motivo debe tener al menos 8 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: bloquearUsuario,
                    activeColor: Colors.red.shade700,
                    title: const Text(
                      'Impedir que vuelva a apadrinar',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Inhabilita al usuario para enviar nuevas solicitudes de apadrinamiento.',
                      style: TextStyle(fontSize: 11),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        bloquearUsuario = val ?? false;
                      });
                    },
                  ),
                ],
              ),
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
                if (cancelFormKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Confirmar Cancelación'),
            ),
          ],
        ),
      ),
    );

    if (confirmar == true) {
      await _ejecutarDecision(
        'cancelar',
        motivoCancelacion: motivoCtrl.text.trim(),
        bloquearUsuario: bloquearUsuario,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final esMal = item.esMalPadrino;
    final esBueno = item.esBuenPadrino;
    final esRegular = item.esPadrinoRegular;

    final Color colorBadge;
    final Color colorBadgeFondo;
    final Color colorBadgeBorde;
    final String textoClasificacion;

    if (esBueno) {
      colorBadge = const Color(0xFF1B5E20);
      colorBadgeFondo = const Color(0xFFE8F5E9);
      colorBadgeBorde = const Color(0xFF81C784);
      textoClasificacion = 'BUEN APADRINANTE';
    } else if (esRegular) {
      colorBadge = const Color(0xFFE65100);
      colorBadgeFondo = const Color(0xFFFFF3E0);
      colorBadgeBorde = const Color(0xFFFFB74D);
      textoClasificacion = 'APADRINANTE REGULAR';
    } else {
      colorBadge = const Color(0xFFB71C1C);
      colorBadgeFondo = const Color(0xFFFFEBEE);
      colorBadgeBorde = const Color(0xFFEF9A9A);
      textoClasificacion = 'MAL APADRINANTE';
    }

    final promMostrado = item.evaluacionPendiente ? item.promedioCicloActual : item.calificacionPromedio;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evaluación del Ciclo ${item.cicloActual}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Padrino: ${item.padrinoNombre} · Mascota: ${item.mascotaNombre}',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tarjeta de Calificación y Clasificación
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorBadgeFondo,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorBadgeBorde, width: 1.5),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colorBadge.withValues(alpha: 0.15),
                      child: Icon(
                        esBueno
                            ? Icons.military_tech_rounded
                            : (esRegular ? Icons.warning_amber_rounded : Icons.error_outline_rounded),
                        color: colorBadge,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            textoClasificacion,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: colorBadge,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${promMostrado.toStringAsFixed(1)} / 5.0',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colorBadge,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(Ciclo ${item.cicloActual} · ${item.seguimientosEnCiclo}/3 seg.)',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Historial resumido del ciclo
              FutureBuilder<List<SeguimientoApadrinamientoItem>>(
                future: _historialFuture,
                builder: (context, snap) {
                  final seguimientos = snap.data ?? [];
                  final cargando = snap.connectionState == ConnectionState.waiting;
                  final segsCiclo = seguimientos
                      .where((s) => s.ciclo == item.cicloActual || seguimientos.length <= 3)
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seguimientos del ciclo actual:',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      if (cargando)
                        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                      else if (segsCiclo.isEmpty)
                        Text('Sin seguimientos registrados en este ciclo',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFECEFF5)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: segsCiclo.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, idx) {
                              final s = segsCiclo[idx];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: s.cumplimiento ? Colors.green.shade100 : Colors.red.shade100,
                                  child: Icon(
                                    s.cumplimiento ? Icons.check : Icons.close,
                                    size: 16,
                                    color: s.cumplimiento ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                ),
                                title: Text(
                                  '#${s.numeroSeguimiento} · ${s.fechaSeguimiento.day}/${s.fechaSeguimiento.month}/${s.fechaSeguimiento.year} · ${s.calificacion} / 5',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                ),
                                subtitle: Text(
                                  s.observaciones.isNotEmpty ? s.observaciones : 'Sin observaciones',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                trailing: Text(
                                  s.adminNombre.isNotEmpty ? s.adminNombre : 'Admin',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // Alerta de calificación crítica si aplica
              if (esMal) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade300, width: 1.2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Padrino con calificación crítica (< 3.0)',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Colors.red.shade900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Para continuar con el apadrinamiento, la nota explicativa es obligatoria.',
                              style: TextStyle(fontSize: 12, color: Colors.red.shade800, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Nota de la decisión
              TextFormField(
                controller: _notaCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: esMal
                      ? 'Nota de la decisión (Obligatoria para seguir) *'
                      : 'Nota u observaciones del ciclo (Opcional)',
                  hintText: esMal
                      ? 'Ej. Se concede continuidad bajo compromiso de pago puntual.'
                      : 'Ej. Excelente cumplimiento y puntualidad en los aportes.',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (v) {
                  if (esMal && (v == null || v.trim().isEmpty)) {
                    return 'La nota es obligatoria para continuar con un padrino con promedio < 3';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // REGLA CAMBIO 1: El administrador ve SIEMPRE las dos opciones juntas:
              // 1. "Seguir con el apadrinamiento" (cierra el ciclo, inicia Ciclo N+1 en 0/3)
              // 2. "Cancelar apadrinamiento" (motivo obligatorio, confirmación y bloqueo)
              if (_guardando)
                const Center(child: CircularProgressIndicator())
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.rosa,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _ejecutarDecision('continuar');
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          'Seguir con el apadrinamiento (Cerrar Ciclo ${item.cicloActual})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade700, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _dialogoConfirmarCancelar,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text(
                          'Cancelar apadrinamiento',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
