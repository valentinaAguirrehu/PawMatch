import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/acuerdo_apadrinamiento_pdf_service.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';
import 'package:printing/printing.dart';

class ApadrinamientoAdminScreen extends StatefulWidget {
  const ApadrinamientoAdminScreen({super.key});

  @override
  State<ApadrinamientoAdminScreen> createState() =>
      _ApadrinamientoAdminScreenState();
}

class _ApadrinamientoAdminScreenState extends State<ApadrinamientoAdminScreen> {
  int _filtro = 0;
  String? _procesandoId;
  String? _descargandoPdfId;
  late Future<List<SolicitudApadrinamiento>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
    ApadrinamientoService.marcarLeidasAdmin();
  }

  Future<List<SolicitudApadrinamiento>> _cargar() =>
      ApadrinamientoService.listarParaAdmin();

  Future<void> _recargar() async {
    setState(() {
      _future = _cargar();
    });
    await _future.catchError((_) => <SolicitudApadrinamiento>[]);
  }

  Future<void> _aprobar(SolicitudApadrinamiento s) async {
    DateTime fechaSeleccionada = DateTime.now();
    final observacionCtrl = TextEditingController();
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Aprobar apadrinamiento', textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¿Confirmas que ${s.solicitanteNombreCompleto} sea padrino de ${s.mascotaNombre.isEmpty ? 'la mascota' : s.mascotaNombre}?',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Fecha oficial de inicio',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, color: AppColors.rosa),
                  label: Text(
                    '${fechaSeleccionada.day.toString().padLeft(2, '0')}/${fechaSeleccionada.month.toString().padLeft(2, '0')}/${fechaSeleccionada.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final elegida = await showDatePicker(
                      context: ctx,
                      initialDate: fechaSeleccionada,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (elegida != null) {
                      setDialogState(() => fechaSeleccionada = elegida);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: observacionCtrl,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Observación para el padrino (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
    if (confirmacion != true || !mounted) return;

    setState(() => _procesandoId = s.id);
    try {
      final fechaStr =
          '${fechaSeleccionada.year}-${fechaSeleccionada.month.toString().padLeft(2, '0')}-${fechaSeleccionada.day.toString().padLeft(2, '0')}';
      await ApadrinamientoService.actualizarEstado(
        idSolicitud: s.id,
        estado: 'aprobada',
        fechaInicio: fechaStr,
        observaciones: observacionCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud aceptada. Ya puedes subir el contrato.')),
      );
      setState(() => _filtro = 1);
      await _recargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _procesandoId = null);
    }
  }

  Future<void> _rechazar(SolicitudApadrinamiento s) async {
    final motivoCtrl = TextEditingController();
    String? errorMotivo;
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Center(child: Text('Rechazar solicitud')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Indica el motivo por el cual se rechaza la solicitud de ${s.mascotaNombre.isEmpty ? 'la mascota' : s.mascotaNombre}:',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: motivoCtrl,
                maxLines: 3,
                maxLength: 500,
                onChanged: (_) {
                  if (errorMotivo != null) setLocal(() => errorMotivo = null);
                },
                decoration: InputDecoration(
                  hintText: 'Motivo del rechazo',
                  border: const OutlineInputBorder(),
                  errorText: errorMotivo,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                if (motivoCtrl.text.trim().isEmpty) {
                  setLocal(() => errorMotivo = 'Escribe el motivo del rechazo');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Rechazar'),
            ),
          ],
        ),
      ),
    );
    if (confirmacion != true || !mounted) return;

    setState(() => _procesandoId = s.id);
    try {
      await ApadrinamientoService.actualizarEstado(
        idSolicitud: s.id,
        estado: 'rechazada',
        observaciones: motivoCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud rechazada.')),
      );
      setState(() => _filtro = 2);
      await _recargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _procesandoId = null);
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

  void _abrirContrato(SolicitudApadrinamiento sol) {
    showGeneralDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black54,
      pageBuilder: (dialogContext, _, _) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: _DetalleSolicitudSheet(
              solicitud: sol,
              soloContrato: true,
              onCambioEstado: (_) {
                Navigator.pop(dialogContext);
                _recargar();
              },
            ),
          ),
        ),
      ),
    );
  }

  void _abrirDetalle(SolicitudApadrinamiento sol) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleSolicitudSheet(
        solicitud: sol,
        onCambioEstado: (nuevoEstado) {
          Navigator.pop(context);
          if (!mounted) return;
          setState(() {
            _filtro = switch (nuevoEstado) {
              'aprobada' => 1,
              'rechazada' => 2,
              'cancelada' => 1,
              _ => 0,
            };
          });
          _recargar();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: Column(
          children: [
            BarraSuperior(
              iconoTitulo: Icons.volunteer_activism_rounded,
              titulo: 'Solicitudes de apadrinamiento',
              onCerrarSesion: _confirmarCerrarSesion,
              onVolver: () {
                final ir = Navegacion.volverANotificaciones;
                if (ir != null) {
                  ir();
                  return;
                }
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            ),
            Expanded(
              child: FutureBuilder<List<SolicitudApadrinamiento>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.rosa),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text(
                              'No se pudieron cargar las solicitudes.\n${snap.error}',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                              onPressed: _recargar,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final todas = snap.data ?? [];
                  final nuevas = todas.where((s) => s.esPendiente).toList();
                  final aprobadas = [
                    ...todas.where((s) => s.esAprobada && !s.tieneContrato),
                    ...todas.where((s) => s.esAprobada && s.tieneContrato),
                  ];
                  final rechazadas = todas.where((s) => s.esRechazada).toList();
                  final lista = switch (_filtro) {
                    1 => aprobadas,
                    2 => rechazadas,
                    _ => nuevas,
                  };

                  return RefreshIndicator(
                    color: AppColors.rosa,
                    onRefresh: _recargar,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      children: [
                        _pestanas(
                          nuevas: nuevas.length,
                          aprobadas: aprobadas.length,
                          rechazadas: rechazadas.length,
                        ),
                        const SizedBox(height: 14),
                        if (lista.isEmpty)
                          _vacio(_filtro)
                        else
                          for (final s in lista) ...[
                            _TarjetaApadrinamiento(
                              solicitud: s,
                              procesando: _procesandoId == s.id,
                              descargando: _descargandoPdfId == s.id,
                              onDetalles: () => _abrirDetalle(s),
                              onContrato: () => _abrirContrato(s),
                              onAceptar: () => _aprobar(s),
                              onRechazar: () => _rechazar(s),
                              onDescargarAcuerdo: () => _descargarAcuerdo(s),
                            ),
                            const SizedBox(height: 12),
                          ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pestanas({
    required int nuevas,
    required int aprobadas,
    required int rechazadas,
  }) {
    Widget chip(int indice, String titulo, int conteo) {
      final activa = _filtro == indice;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _filtro = indice),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            decoration: BoxDecoration(
              color: activa ? AppColors.rosa : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: activa ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
                if (conteo > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: activa ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$conteo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: activa ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCE4EC)),
      ),
      child: Row(
        children: [
          chip(0, 'Nuevas', nuevas),
          chip(1, 'Aprobadas', aprobadas),
          chip(2, 'Rechazadas', rechazadas),
        ],
      ),
    );
  }

  Future<void> _descargarAcuerdo(SolicitudApadrinamiento s) async {
    setState(() => _descargandoPdfId = s.id);
    try {
      Uint8List? cedula;
      if (s.archivoCedula != null && s.archivoCedula!.isNotEmpty) {
        try {
          cedula = await ApadrinamientoService.obtenerBytesDocumento(s.id);
        } catch (_) {}
      }
      Uint8List? fotoMascota;
      if (s.mascotaFotos.isNotEmpty) {
        try {
          final res = await http.get(Uri.parse(urlFoto(s.mascotaFotos)));
          if (res.statusCode == 200) fotoMascota = res.bodyBytes;
        } catch (_) {}
      }
      final bytes = await AcuerdoApadrinamientoPdfService.generarPdfBytes(
        DatosActaApadrinamiento(
          idSolicitud: s.id,
          nombreUsuario: s.nombreCompleto,
          documentoUsuario: s.documentoIdentidad,
          correoUsuario: s.correo,
          telefonoUsuario: s.telefono,
          nombreMascota: s.mascotaNombre,
          especieMascota: s.mascotaEspecie,
          razaMascota: s.mascotaRaza,
          edadMascota: s.mascotaEdadTexto,
          sexoMascota: null,
          tipoAporte: s.tipoAporte,
          valorMensual: s.montoAporte,
          frecuenciaAporte: s.frecuenciaAporte,
          descripcionAporte: s.detalleAporte,
          detalleEspecie: s.detalleEspecie,
          fechaRegistro: s.fechaCreacion,
          estadoProceso: s.estado,
          estadoCorreo: s.estadoCorreo,
          aceptoTerminos: true,
          fotoCedula: cedula,
          fotoMascota: fotoMascota,
        ),
      );
      await AcuerdoApadrinamientoPdfService.descargarYGuardarPdf(
        bytes: bytes,
        nombreMascota: s.mascotaNombre,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acuerdo de compromiso descargado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar el acuerdo: $e')),
      );
    } finally {
      if (mounted) setState(() => _descargandoPdfId = null);
    }
  }

  Widget _vacio(int filtro) {
    final texto = switch (filtro) {
      1 => 'No hay apadrinamientos aprobados.',
      2 => 'No hay solicitudes rechazadas.',
      _ => 'No hay solicitudes nuevas.',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(texto, style: TextStyle(color: AppColors.grisTexto)),
        ],
      ),
    );
  }
}

class _TarjetaApadrinamiento extends StatelessWidget {
  final SolicitudApadrinamiento solicitud;
  final bool procesando;
  final bool descargando;
  final VoidCallback onDetalles;
  final VoidCallback onContrato;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;
  final VoidCallback onDescargarAcuerdo;

  const _TarjetaApadrinamiento({
    required this.solicitud,
    required this.procesando,
    required this.descargando,
    required this.onDetalles,
    required this.onContrato,
    required this.onAceptar,
    required this.onRechazar,
    required this.onDescargarAcuerdo,
  });

  String _fecha(String raw) {
    final texto = raw.trim();
    if (texto.isEmpty) return '';
    final partes = texto.split(RegExp(r'[ T]'));
    final fecha = partes.first.split('-');
    if (fecha.length != 3) return texto;
    final hora = partes.length > 1 ? partes[1] : '';
    final hm = hora.length >= 5 ? hora.substring(0, 5) : '';
    final base = '${fecha[2]}/${fecha[1]}/${fecha[0]}';
    return hm.isEmpty ? base : '$base $hm';
  }

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final especie = s.mascotaEspecie.isEmpty ? 'Mascota' : s.mascotaEspecie;
    final raza = s.mascotaRaza.isEmpty ? 'Mestizo' : s.mascotaRaza;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFCE4EC)),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFCE4EC), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: PetImage(url: s.mascotaFotos),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.mascotaNombre.isEmpty ? 'Mascota' : s.mascotaNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$especie · $raza',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Solicitante: ${s.solicitanteNombreCompleto}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF9D174D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fecha(s.fechaSolicitud),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!s.esPendiente) ...[
            const SizedBox(height: 12),
            _estado(s),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.rosa,
              side: const BorderSide(color: Color(0xFFF48FB1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size.fromHeight(42),
            ),
            onPressed: onDetalles,
            icon: const Icon(Icons.assignment_outlined, size: 18),
            label: const Text(
              'Ver detalles',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.rosa,
              side: const BorderSide(color: Color(0xFFF48FB1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size.fromHeight(42),
            ),
            onPressed: descargando ? null : onDescargarAcuerdo,
            icon: descargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rosa),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Descargar acuerdo de compromiso',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
          if (s.esPendiente) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size.fromHeight(42),
                    ),
                    onPressed: procesando ? null : onRechazar,
                    child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size.fromHeight(42),
                    ),
                    onPressed: procesando ? null : onAceptar,
                    child: procesando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ] else if (s.esAprobada) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9D174D),
                side: const BorderSide(color: Color(0xFFF48FB1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size.fromHeight(42),
              ),
              onPressed: onContrato,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(
                s.tieneContrato ? 'Ver contrato' : 'Subir contrato',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _estado(SolicitudApadrinamiento s) {
    final Color fondo;
    final Color texto;
    final String etiqueta;
    final IconData icono;
    if (s.esAprobada && s.tieneContrato) {
      fondo = const Color(0xFFECFDF5);
      texto = const Color(0xFF065F46);
      etiqueta = 'Aprobada';
      icono = Icons.check_circle_outline;
    } else if (s.esAprobada) {
      fondo = const Color(0xFFFFFBEB);
      texto = const Color(0xFF92400E);
      etiqueta = 'Pendiente un paso - Falta subir contrato de apadrinación';
      icono = Icons.hourglass_top_rounded;
    } else if (s.esRechazada) {
      fondo = const Color(0xFFFEF2F2);
      texto = const Color(0xFF991B1B);
      etiqueta = 'Rechazada';
      icono = Icons.cancel_outlined;
    } else if (s.esCancelada) {
      fondo = const Color(0xFFF1F5F9);
      texto = const Color(0xFF334155);
      etiqueta = 'Cancelada';
      icono = Icons.highlight_off_outlined;
    } else {
      fondo = const Color(0xFFFFFBEB);
      texto = const Color(0xFF92400E);
      etiqueta = 'Pendiente';
      icono = Icons.hourglass_top_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icono, size: 16, color: texto),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              etiqueta,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: texto),
            ),
          ),
        ],
      ),
    );
  }
}


/// Detalle de una solicitud de apadrinamiento, usable como página o como hoja.
class DetalleSolicitudApadrinamiento extends StatelessWidget {
  final SolicitudApadrinamiento solicitud;
  final ValueChanged<String> onCambioEstado;
  final bool enPagina;

  const DetalleSolicitudApadrinamiento({
    super.key,
    required this.solicitud,
    required this.onCambioEstado,
    this.enPagina = false,
  });

  @override
  Widget build(BuildContext context) {
    return _DetalleSolicitudSheet(
      solicitud: solicitud,
      onCambioEstado: onCambioEstado,
      enPagina: enPagina,
    );
  }
}

class _DetalleSolicitudSheet extends StatefulWidget {
  final SolicitudApadrinamiento solicitud;
  final ValueChanged<String> onCambioEstado;
  final bool enPagina;
  final bool soloContrato;

  const _DetalleSolicitudSheet({
    required this.solicitud,
    required this.onCambioEstado,
    this.enPagina = false,
    this.soloContrato = false,
  });

  @override
  State<_DetalleSolicitudSheet> createState() => _DetalleSolicitudSheetState();
}

class _DetalleSolicitudSheetState extends State<_DetalleSolicitudSheet> {
  Uint8List? _docBytes;
  bool _cargandoDoc = true;
  String? _errorDoc;

  Uint8List? _contratoBytes;
  bool _cargandoContrato = false;
  String? _errorContrato;
  bool _subiendoContrato = false;
  late bool _tieneContrato;
  String? _nombreContrato;

  bool _procesando = false;

  bool _esBytesPdf(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46; // %PDF
  }

  @override
  void initState() {
    super.initState();
    _tieneContrato = widget.solicitud.tieneContrato;
    _nombreContrato = widget.solicitud.contratoArchivo;
    if (!widget.soloContrato) _cargarDocumentoSeguro();
    if (_tieneContrato) {
      _cargarContratoSeguro();
    }
  }

  Future<void> _cargarDocumentoSeguro() async {
    try {
      final bytes = await ApadrinamientoService.obtenerBytesDocumento(
        widget.solicitud.id,
      );
      if (!mounted) return;
      setState(() {
        _docBytes = bytes;
        _cargandoDoc = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorDoc = e.toString().replaceFirst('Exception: ', '');
        _cargandoDoc = false;
      });
    }
  }

  Future<void> _cargarContratoSeguro() async {
    setState(() => _cargandoContrato = true);
    try {
      final bytes = await ApadrinamientoService.obtenerBytesContrato(
        widget.solicitud.id,
      );
      if (!mounted) return;
      setState(() {
        _contratoBytes = bytes;
        _cargandoContrato = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorContrato = e.toString().replaceFirst('Exception: ', '');
        _cargandoContrato = false;
      });
    }
  }

  Future<void> _descargarDocumento(Uint8List bytes) async {
    const titulo = 'Documento de identidad';
    final esPdf = _esBytesPdf(bytes);
    final esPng = bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final extension = esPdf ? 'pdf' : (esPng ? 'png' : 'jpg');
    try {
      final ruta = await FilePicker.saveFile(
        dialogTitle: 'Descargar $titulo',
        fileName: 'documento_de_identidad.$extension',
        bytes: bytes,
        mimeType: esPdf ? 'application/pdf' : (esPng ? 'image/png' : 'image/jpeg'),
      );
      if (!mounted || ruta == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('$titulo descargado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar: $e')),
      );
    }
  }

  void _verDocumentoCompleto() {
    final bytes = _docBytes;
    if (bytes == null) return;
    const titulo = 'Documento de identidad';
    final esPdf = _esBytesPdf(bytes);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      pageBuilder: (ctx, _, _) {
        return SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 72, 22, 108),
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.rosa.withValues(alpha: 0.45),
                              blurRadius: 36,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: esPdf
                              ? ColoredBox(
                                  color: Colors.white,
                                  child: SizedBox(
                                    height: 220,
                                    width: double.infinity,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade700, size: 64),
                                        const SizedBox(height: 10),
                                        const Text(
                                          titulo,
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Image.memory(bytes, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1F2937),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 18,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosa,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _descargarDocumento(bytes),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Descargar', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _verContratoCompleto() {
    if (_contratoBytes == null) return;
    if (_esBytesPdf(_contratoBytes!)) {
      Printing.layoutPdf(
        onLayout: (_) => _contratoBytes!,
        name: _nombreContrato ?? 'Contrato_Apadrinamiento_${widget.solicitud.mascotaNombre}.pdf',
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Contrato de Apadrinamiento'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(_contratoBytes!, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _subirContrato() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.xFile.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('No se pudo leer el archivo seleccionado.'),
          ),
        );
        return;
      }

      final ext = file.name.split('.').last.toLowerCase();
      final esPdf = ext == 'pdf' || _esBytesPdf(bytes);

      if (!mounted) return;
      // Diálogo de confirmación: "¿Estás seguro de que deseas subir el contrato?"
      final confirmacion = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: AppColors.rosa),
              SizedBox(width: 8),
              Expanded(child: Text('Confirmar Subida')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que deseas subir este contrato de apadrinamiento para ${widget.solicitud.solicitanteNombreCompleto}?',
                style: const TextStyle(fontSize: 14.5),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      esPdf ? Icons.picture_as_pdf : Icons.image,
                      color: esPdf ? Colors.redAccent : AppColors.rosa,
                      size: 32,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${(bytes.length / 1024).toStringAsFixed(1)} KB • Formato: ${ext.toUpperCase()}',
                            style: TextStyle(
                              color: AppColors.grisTexto,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      if (confirmacion != true) return;

      setState(() => _subiendoContrato = true);

      await ApadrinamientoService.subirContrato(
        idSolicitud: widget.solicitud.id,
        bytesContrato: bytes,
        nombreArchivo: file.name,
      );

      if (!mounted) return;
      setState(() {
        _subiendoContrato = false;
        _contratoBytes = bytes;
        _tieneContrato = true;
        _nombreContrato = file.name;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            '¡Contrato de apadrinamiento subido con éxito! El usuario ya es padrino oficial.',
          ),
        ),
      );
      widget.onCambioEstado('aprobada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _subiendoContrato = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al subir contrato: $e'),
        ),
      );
    }
  }

  Future<void> _aprobar() async {
    DateTime fechaSeleccionada = DateTime.now();
    final observacionCtrl = TextEditingController();

    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Expanded(child: Text('Aprobar Apadrinamiento')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Confirmas la aprobación para que ${widget.solicitud.solicitanteNombreCompleto} sea padrino de ${widget.solicitud.mascotaNombre}?',
                  style: const TextStyle(height: 1.35),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Fecha oficial de inicio del apadrinamiento:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, color: AppColors.rosa),
                  label: Text(
                    '${fechaSeleccionada.year}-${fechaSeleccionada.month.toString().padLeft(2, '0')}-${fechaSeleccionada.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final elegida = await showDatePicker(
                      context: context,
                      initialDate: fechaSeleccionada,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (elegida != null) {
                      setDialogState(() => fechaSeleccionada = elegida);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Observaciones para el padrino (opcional):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: observacionCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Escribe aquí cualquier indicación o recomendación...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Al aprobar, deberás subir el contrato de apadrinamiento para formalizar el proceso.',
                  style: TextStyle(fontSize: 12, color: AppColors.grisTexto),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar Aprobación'),
            ),
          ],
        ),
      ),
    );

    if (confirmacion != true) return;

    setState(() => _procesando = true);
    try {
      final fechaStr =
          '${fechaSeleccionada.year}-${fechaSeleccionada.month.toString().padLeft(2, '0')}-${fechaSeleccionada.day.toString().padLeft(2, '0')}';
      await ApadrinamientoService.actualizarEstado(
        idSolicitud: widget.solicitud.id,
        estado: 'aprobada',
        fechaInicio: fechaStr,
        observaciones: observacionCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('¡Solicitud aprobada! Ahora puedes adjuntar el contrato.'),
        ),
      );
      widget.onCambioEstado('aprobada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
      );
    }
  }

  Future<void> _rechazar() async {
    final motivoCtrl = TextEditingController();
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar Solicitud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indica el motivo por el cual se rechaza la solicitud de ${widget.solicitud.solicitanteNombreCompleto}:',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: motivoCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Motivo del rechazo u observaciones...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmacion != true) return;

    setState(() => _procesando = true);
    try {
      await ApadrinamientoService.actualizarEstado(
        idSolicitud: widget.solicitud.id,
        estado: 'rechazada',
        observaciones: motivoCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('La solicitud ha sido rechazada.'),
        ),
      );
      widget.onCambioEstado('rechazada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
      );
    }
  }

  Future<void> _cancelarApadrinamiento() async {
    final motivoCtrl = TextEditingController();
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(child: Text('Cancelar Apadrinamiento')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Confirmas la cancelación del apadrinamiento de ${widget.solicitud.solicitanteNombreCompleto} para ${widget.solicitud.mascotaNombre}?',
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 14),
              const Text(
                'Motivo de cancelación (obligatorio para el usuario):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: motivoCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Explica el motivo por el cual se cancela el apadrinamiento...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Este comentario se guardará en la base de datos y se mostrará al usuario en sus apadrinamientos.',
                style: TextStyle(fontSize: 12, color: AppColors.grisTexto),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (motivoCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text('Por favor escribe el motivo de cancelación.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirmar Cancelación'),
          ),
        ],
      ),
    );

    if (confirmacion != true) return;

    setState(() => _procesando = true);
    try {
      await ApadrinamientoService.cancelarSolicitud(
        idSolicitud: widget.solicitud.id,
        motivo: motivoCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('El apadrinamiento ha sido cancelado con éxito.'),
        ),
      );
      widget.onCambioEstado('cancelada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
      );
    }
  }

  Widget _vistaDocumento() {
    if (_cargandoDoc) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorDoc != null) {
      return Text(
        'No se pudo cargar el documento: $_errorDoc',
        style: const TextStyle(color: Colors.redAccent),
      );
    }
    final bytes = _docBytes;
    if (bytes == null) return const Text('No se encontró archivo adjunto.');
    final esPdf = _esBytesPdf(bytes);

    return GestureDetector(
      onTap: _verDocumentoCompleto,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: esPdf
              ? ColoredBox(
                  color: Colors.red.shade50,
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade700, size: 52),
                        const SizedBox(height: 8),
                        Text(
                          'Documento de identidad',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Image.memory(
                  bytes,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 140,
                    alignment: Alignment.center,
                    color: AppColors.rosaSuave,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description_outlined, color: AppColors.rosa, size: 40),
                        SizedBox(height: 6),
                        Text('Documento de identidad', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _seccionContrato() {
    final hayArchivo = _tieneContrato || _contratoBytes != null;
    final Color fondoBase = hayArchivo ? Colors.green.shade50 : Colors.amber.shade50;
    return _SeccionTarjeta(
      titulo: 'Contrato de apadrinamiento',
      icono: Icons.assignment_outlined,
      colorFondo: widget.soloContrato ? fondoBase : fondoBase.withValues(alpha: 0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_subiendoContrato)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Procesando contrato de apadrinamiento...'),
                  ],
                ),
              ),
            )
          else if (hayArchivo) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Contrato de apadrinamiento subido. El padrino ya puede verlo y descargarlo.',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_cargandoContrato)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [CircularProgressIndicator()],
                  ),
                ),
              )
            else if (_errorContrato != null)
              Text(
                'Error al cargar contrato: $_errorContrato',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              )
            else if (_contratoBytes != null) ...[
              if (_esBytesPdf(_contratoBytes!))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nombreContrato ?? 'Contrato_Apadrinamiento.pdf',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Documento PDF (${(_contratoBytes!.length / 1024).toStringAsFixed(1)} KB)',
                              style: TextStyle(color: AppColors.grisTexto, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _contratoBytes!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rosa,
                        side: const BorderSide(color: AppColors.rosa),
                      ),
                      onPressed: _verContratoCompleto,
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Ver'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _subirContrato,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Reemplazar'),
                    ),
                  ],
                ),
              ),
            ] else
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                onPressed: _cargarContratoSeguro,
                icon: const Icon(Icons.visibility),
                label: const Text('Cargar y ver contrato'),
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pendiente subir contrato de apadrinamiento. El padrino verá ese estado hasta que cargues el contrato firmado (JPG, PNG o PDF).',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosa,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _subirContrato,
                icon: const Icon(Icons.upload_file),
                label: const Text(
                  'Subir contrato (JPG, PNG o PDF)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (widget.soloContrato) {
      return _seccionContrato();
    }
    final s = widget.solicitud;
    final t = Theme.of(context).textTheme;

    return Container(
      constraints: widget.enPagina
          ? null
          : BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.enPagina
            ? null
            : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          if (!widget.enPagina) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detalle de la Solicitud',
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
          ],
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                // Mascota que desea apadrinar
                _SeccionTarjeta(
                  titulo: 'Mascota',
                  icono: Icons.pets,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.rosa, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: PetImage(url: s.mascotaFotos),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.mascotaNombre,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                            color: AppColors.texto,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.rosaSuave,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.bordeRosa),
                          ),
                          child: Text(
                            s.mascotaEdadTexto,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.rosa,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${s.mascotaEspecie} • ${s.mascotaRaza.isEmpty ? 'Mestizo' : s.mascotaRaza}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.grisTexto,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Solicitante y datos de contacto
                _SeccionTarjeta(
                  titulo: 'Datos del solicitante',
                  icono: Icons.person,
                  child: Table(
                    columnWidths: const {
                      0: IntrinsicColumnWidth(),
                      1: FlexColumnWidth(),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      for (final fila in <(String, String)>[
                        ('Nombre completo', s.solicitanteNombreCompleto),
                        ('Correo electrónico', s.solicitanteCorreo),
                        (
                          'Celular',
                          s.solicitanteTelefono.isEmpty
                              ? 'No especificado'
                              : s.solicitanteTelefono,
                        ),
                        (
                          'Dirección',
                          s.solicitanteDireccion.isEmpty
                              ? 'No especificada'
                              : s.solicitanteDireccion,
                        ),
                        if (s.solicitanteCedula.isNotEmpty)
                          ('Número de cédula', s.solicitanteCedula),
                      ])
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 5, 10, 5),
                              child: Text(
                                '${fila.$1}:',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(color: AppColors.grisTexto, fontSize: 13),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  fila.$2,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // MOTIVACIÓN OBLIGATORIA COMPLETA
                _SeccionTarjeta(
                  titulo: '¿Por qué quiere apadrinar a esta mascota?',
                  icono: Icons.favorite,
                  colorFondo: AppColors.rosaClaro.withOpacity(0.35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Respuesta completa del solicitante:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.rosa,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        s.motivacion,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (s.montoAporte != null) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Aporte voluntario:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.rosa,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          '\$${s.montoAporte} COP (${s.frecuenciaAporte})',
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (s.observaciones != null && s.observaciones!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Observaciones / Motivo:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.rosa,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          s.observaciones!.trim(),
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                _SeccionTarjeta(
                  titulo: 'Documento de identidad',
                  icono: Icons.badge_outlined,
                  child: _vistaDocumento(),
                ),
                const SizedBox(height: 14),

                if (s.esAprobada) ...[
                  _seccionContrato(),
                  const SizedBox(height: 14),
                ],

                // SI ESTÁ CANCELADA, MOSTRAR MOTIVO
                if (s.esCancelada) ...[
                  _SeccionTarjeta(
                    titulo: 'Apadrinamiento Cancelado',
                    icono: Icons.highlight_off,
                    colorFondo: Colors.red.shade50.withOpacity(0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Motivo de cancelación registrado en base de datos:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            s.observaciones?.trim().isNotEmpty == true
                                ? s.observaciones!
                                : 'Sin motivo especificado.',
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                        if (s.fechaActualizacionEstado != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Fecha de cancelación: ${s.fechaActualizacionEstado}',
                            style: TextStyle(fontSize: 12, color: AppColors.grisTexto),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // SI ESTÁ RECHAZADA, MOSTRAR EL MOTIVO
                if (s.esRechazada) ...[
                  _SeccionTarjeta(
                    titulo: 'Solicitud Rechazada',
                    icono: Icons.cancel_outlined,
                    colorFondo: Colors.red.shade50.withOpacity(0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.replay, size: 16, color: Colors.red.shade900),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Esta solicitud ha sido rechazada.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Motivo del rechazo u observaciones:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            s.observaciones?.trim().isNotEmpty == true
                                ? s.observaciones!
                                : 'Sin motivo especificado.',
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                        if (s.fechaActualizacionEstado != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Fecha de rechazo: ${s.fechaActualizacionEstado}',
                            style: TextStyle(fontSize: 12, color: AppColors.grisTexto),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ACUERDO DE RESPONSABILIDAD
                _SeccionTarjeta(
                  titulo: 'Acuerdo de responsabilidad',
                  icono: Icons.gavel,
                  child: Row(
                    children: [
                      Icon(
                        s.acuerdoResponsabilidad
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: s.acuerdoResponsabilidad
                            ? Colors.green
                            : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.acuerdoResponsabilidad
                                  ? 'Aceptado explícitamente por el solicitante'
                                  : 'No aceptado',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: s.acuerdoResponsabilidad
                                    ? Colors.green.shade800
                                    : Colors.red,
                              ),
                            ),
                            if (s.fechaAcuerdoResponsabilidad != null)
                              Text(
                                'Fecha de aceptación: ${s.fechaAcuerdoResponsabilidad}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grisTexto,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Fechas y Aporte
                _SeccionTarjeta(
                  titulo: 'Detalles del apadrinamiento',
                  icono: Icons.info_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FilaInfo('Fecha de envío de solicitud', s.fechaSolicitud),
                      _FilaInfo(
                        'Estado de la solicitud',
                        s.estado.toUpperCase(),
                      ),
                      if (s.fechaInicioApadrinamiento != null)
                        _FilaInfo(
                          'Fecha de inicio oficial',
                          s.fechaInicioApadrinamiento!,
                        ),
                      if (s.fechaActualizacionEstado != null)
                        _FilaInfo(
                          'Fecha de revisión',
                          s.fechaActualizacionEstado!,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Botones de acción si es pendiente
                if (s.esPendiente) ...[
                  if (_procesando)
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Rechazar'),
                            onPressed: _rechazar,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Aprobar'),
                            onPressed: _aprobar,
                          ),
                        ),
                      ],
                    ),
                ],

                // Botón para CANCELAR si ya está aprobada
                if (s.esAprobada) ...[
                  if (_procesando)
                    const Center(child: CircularProgressIndicator())
                  else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text(
                        'Cancelar Apadrinamiento',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _cancelarApadrinamiento,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccionTarjeta extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;
  final Color? colorFondo;

  const _SeccionTarjeta({
    required this.titulo,
    required this.icono,
    required this.child,
    this.colorFondo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorFondo ?? Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: AppColors.rosa),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FilaInfo extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _FilaInfo(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              '$etiqueta:',
              style: TextStyle(color: AppColors.grisTexto, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
