import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/seguimiento_apadrinamiento.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/screens/pets/pet_detail_screen.dart';
import 'package:paw_match/services/acuerdo_apadrinamiento_pdf_service.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/reporte_padrino_pdf_service.dart';
import 'package:paw_match/services/seguimiento_apadrinamiento_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_carga.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';

class MisApadrinamientosScreen extends StatefulWidget {
  const MisApadrinamientosScreen({super.key});

  @override
  State<MisApadrinamientosScreen> createState() =>
      _MisApadrinamientosScreenState();
}

class _MisApadrinamientosScreenState extends State<MisApadrinamientosScreen> {
  static bool _mensajeSesionMostrado = false;
  int _filtroSeleccionado = 0; // 0: Aprobadas, 1: Pendientes, 2: Rechazadas

  late Future<List<SolicitudApadrinamiento>> _future = _cargar();
  late Future<ResumenPadrino?> _resumenFuture = _cargarResumen();

  String? _descargandoPdfId;
  String? _reenviandoCorreoId;

  // Solicitud seleccionada como principal para ver en detalle (por defecto la primera de la lista activa)
  String? _idSolicitudSeleccionada;

  @override
  void initState() {
    super.initState();
    ApadrinamientoService.marcarLeidasUsuario();
    _resumenFuture = _cargarResumen()..then((resumen) async {
      if (!mounted || _mensajeSesionMostrado) return;
      if (resumen == null || resumen.totalSeguimientos == 0) return;
      _mensajeSesionMostrado = true;
      final lista = await _future.catchError((_) => <SolicitudApadrinamiento>[]);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mostrarMensajePrimeraVez(resumen, todas: lista);
      });
    });
  }

  Future<List<SolicitudApadrinamiento>> _cargar() =>
      ApadrinamientoService.listarMisSolicitudes();

  Future<ResumenPadrino?> _cargarResumen() =>
      SeguimientoApadrinamientoService.obtenerResumenPadrino(Session.idUsuario ?? '');

  Future<void> _recargar() async {
    setState(() {
      _future = _cargar();
      _resumenFuture = _cargarResumen();
    });
    await Future.wait([
      _future.catchError((_) => <SolicitudApadrinamiento>[]),
      _resumenFuture.catchError((_) => null),
    ]);
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (!confirmar || !mounted) return;
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    Session.cerrar();
    Navegacion.ir(context, const WelcomeScreen());
  }

  Future<void> _reenviarVerificacion(SolicitudApadrinamiento s) async {
    setState(() => _reenviandoCorreoId = s.id);
    try {
      final res = await ApadrinamientoService.reenviarVerificacionCorreo(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(res),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('No se pudo reenviar el correo: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _reenviandoCorreoId = null);
    }
  }

  Future<void> _descargarAcuerdoPdf(SolicitudApadrinamiento s) async {
    setState(() => _descargandoPdfId = s.id);
    try {
      Uint8List? cedula;
      if (s.archivoCedula != null && s.archivoCedula!.isNotEmpty) {
        try {
          cedula = await ApadrinamientoService.obtenerBytesDocumento(s.archivoCedula!);
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
        const SnackBar(content: Text('Acuerdo de apadrinamiento descargado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar acuerdo: $e')),
      );
    } finally {
      if (mounted) setState(() => _descargandoPdfId = null);
    }
  }

  void _verDetallesMascota(SolicitudApadrinamiento s) {
    if (s.idMascota.isEmpty) return;
    final pet = Pet(
      id: s.idMascota,
      nombre: s.mascotaNombre.isEmpty ? 'Mascota' : s.mascotaNombre,
      especie: s.mascotaEspecie.isEmpty ? 'Perro' : s.mascotaEspecie,
      raza: s.mascotaRaza.isEmpty ? null : s.mascotaRaza,
      edad: s.mascotaEdad,
      foto: s.mascotaFotos.isEmpty ? null : s.mascotaFotos,
      estadoAdopcion: s.esAprobada ? 'adoptado' : 'disponible',
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PetDetailScreen(pet: pet)),
    );
  }

  Future<void> _verContrato(SolicitudApadrinamiento s) async {
    late final Uint8List bytes;
    try {
      bytes = await DialogoCarga.mientras(
        context,
        () => ApadrinamientoService.obtenerBytesContrato(s.id),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al cargar contrato: $e'),
        ),
      );
      return;
    }
    if (!mounted) return;

    final esPdf = bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
    final titulo = 'Contrato de Apadrinamiento - ${s.mascotaNombre}';

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: esPdf ? const Color(0xFFF8F4F6) : Colors.black,
          appBar: AppBar(
            backgroundColor: esPdf ? Colors.white : Colors.black,
            foregroundColor: esPdf ? AppColors.texto : Colors.white,
            title: Text(
              titulo,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => _descargarContrato(
                  ctx,
                  bytes,
                  s.mascotaNombre,
                  esPdf,
                ),
                icon: Icon(
                  Icons.download_rounded,
                  color: esPdf ? AppColors.rosa : Colors.white,
                ),
                label: Text(
                  'Descargar',
                  style: TextStyle(
                    color: esPdf ? AppColors.rosa : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: esPdf
              ? PdfPreview(
                  build: (_) async => bytes,
                  pdfFileName: _nombreArchivoContrato(s.mascotaNombre, true, bytes),
                  useActions: false,
                  allowPrinting: false,
                  allowSharing: false,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                )
              : Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
        ),
      ),
    );
  }

  String _nombreArchivoContrato(String nombreMascota, bool esPdf, Uint8List bytes) {
    final limpio = nombreMascota
        .replaceAll(RegExp(r'[^\w\- ]', unicode: true), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final base = limpio.isEmpty ? 'Mascota' : limpio;
    if (esPdf) return 'Contrato_Apadrinamiento_$base.pdf';
    final esPng = bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    return 'Contrato_Apadrinamiento_$base.${esPng ? 'png' : 'jpg'}';
  }

  Future<void> _descargarContrato(
    BuildContext aviso,
    Uint8List bytes,
    String nombreMascota,
    bool esPdf,
  ) async {
    final nombre = _nombreArchivoContrato(nombreMascota, esPdf, bytes);
    final mime = esPdf
        ? 'application/pdf'
        : (nombre.endsWith('.png') ? 'image/png' : 'image/jpeg');
    try {
      final ruta = await FilePicker.saveFile(
        dialogTitle: 'Descargar contrato de apadrinamiento',
        fileName: nombre,
        bytes: bytes,
        mimeType: mime,
      );
      if (!aviso.mounted || ruta == null) return;
      ScaffoldMessenger.of(aviso).showSnackBar(
        const SnackBar(content: Text('Contrato de apadrinamiento descargado.')),
      );
    } catch (e) {
      if (!aviso.mounted) return;
      ScaffoldMessenger.of(aviso).showSnackBar(
        SnackBar(content: Text('No se pudo descargar el contrato: $e')),
      );
    }
  }

  static const List<String> _mesesCortos = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static const List<String> _mesesCompletos = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static String formatearFechaCorta(DateTime f) {
    return '${f.day} ${_mesesCortos[f.month - 1]}. ${f.year}';
  }

  static String formatearFechaLarga(DateTime f) {
    return '${f.day} de ${_mesesCompletos[f.month - 1]} de ${f.year}';
  }

  static String parsearYFormatearFecha(String? fechaStr, {bool larga = false}) {
    if (fechaStr == null || fechaStr.trim().isEmpty) return 'Activo';
    try {
      final parsed = DateTime.tryParse(fechaStr);
      if (parsed != null) {
        return larga ? formatearFechaLarga(parsed) : formatearFechaCorta(parsed);
      }
    } catch (_) {}
    return fechaStr;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: Column(
          children: [
            BarraSuperior(
              iconoTitulo: Icons.favorite_rounded,
              titulo: 'Mis Apadrinamientos',
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
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text('Error al cargar tus apadrinamientos: ${snap.error}',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.rosa,
                              ),
                              onPressed: _recargar,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final todas = snap.data ?? [];

                  // Filtrado según especificación
                  final List<SolicitudApadrinamiento> aprobadas = todas.where((s) {
                    final esAprobadaOContrato = s.estado == 'aprobada' || s.tieneContrato;
                    final tieneSeguimientosOCiclos = s.totalSeguimientos > 0 ||
                        s.seguimientosEnCiclo > 0 ||
                        s.cicloActual > 1 ||
                        s.evaluacionesCiclos.isNotEmpty;
                    return esAprobadaOContrato &&
                        tieneSeguimientosOCiclos &&
                        s.estado != 'cancelada' &&
                        s.estadoApadrinamiento != 'cancelada';
                  }).toList()
                    ..sort((a, b) {
                      final ciclosA = a.evaluacionesCiclos.length;
                      final ciclosB = b.evaluacionesCiclos.length;
                      if (ciclosA != ciclosB) return ciclosB.compareTo(ciclosA);
                      if (a.cicloActual != b.cicloActual) {
                        return b.cicloActual.compareTo(a.cicloActual);
                      }
                      if (a.totalSeguimientos != b.totalSeguimientos) {
                        return b.totalSeguimientos.compareTo(a.totalSeguimientos);
                      }
                      return b.seguimientosEnCiclo.compareTo(a.seguimientosEnCiclo);
                    });

                  final List<SolicitudApadrinamiento> pendientes = todas.where((s) {
                    final esRechazadaOCancelada = s.estado == 'rechazada' ||
                        s.estado == 'cancelada' ||
                        s.estadoApadrinamiento == 'cancelada';
                    if (esRechazadaOCancelada) return false;
                    final tieneSeguimientosOCiclos = s.totalSeguimientos > 0 ||
                        s.seguimientosEnCiclo > 0 ||
                        s.cicloActual > 1 ||
                        s.evaluacionesCiclos.isNotEmpty;
                    final esAprobadaConSeguimiento =
                        (s.estado == 'aprobada' || s.tieneContrato) &&
                            tieneSeguimientosOCiclos;
                    return !esAprobadaConSeguimiento;
                  }).toList();

                  final List<SolicitudApadrinamiento> rechazadas = todas.where((s) {
                    return s.estado == 'rechazada' ||
                        s.estado == 'cancelada' ||
                        s.estadoApadrinamiento == 'cancelada';
                  }).toList();

                  final listaActiva = _filtroSeleccionado == 0
                      ? aprobadas
                      : (_filtroSeleccionado == 1 ? pendientes : rechazadas);

                  // Identificar la solicitud principal y las otras apadrinaciones
                  SolicitudApadrinamiento? solicitudPrincipal;
                  if (listaActiva.isNotEmpty) {
                    if (_idSolicitudSeleccionada != null) {
                      final encontrada = listaActiva
                          .where((s) => s.id == _idSolicitudSeleccionada)
                          .firstOrNull;
                      solicitudPrincipal = encontrada ?? listaActiva.first;
                    } else {
                      solicitudPrincipal = listaActiva.first;
                    }
                  }

                  // ÚNICAMENTE las demás de la MISMA categoría activa (nunca mezclar estados)
                  final List<SolicitudApadrinamiento> otrasDePestana = solicitudPrincipal != null
                      ? listaActiva.where((s) => s.id != solicitudPrincipal!.id).toList()
                      : <SolicitudApadrinamiento>[];

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final double ancho = constraints.maxWidth;
                      final bool esDesktop = ancho >= 880;
                      final bool esTablet = ancho >= 600 && ancho < 880;

                      // Ancho máximo contenido fluido
                      final double maxAnchoContenedor = esDesktop
                          ? 1120.0
                          : (esTablet ? 780.0 : double.infinity);

                      return RefreshIndicator(
                        color: AppColors.rosa,
                        onRefresh: _recargar,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            esDesktop ? 28 : 16,
                            8,
                            esDesktop ? 28 : 16,
                            // Espacio generoso inferior para no solapar la barra de navegación flotante
                            110,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxAnchoContenedor),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 6),

                                  // Pestañas de navegación adaptables
                                  _construirPestanas(
                                    conteoAprobadas: aprobadas.length,
                                    conteoPendientes: pendientes.length,
                                    conteoRechazadas: rechazadas.length,
                                    esDesktop: esDesktop,
                                  ),
                                  const SizedBox(height: 16),

                                  // Tarjeta Principal y Sección de Otras Apadrinaciones
                                  if (listaActiva.isEmpty)
                                    _construirEstadoVacio()
                                  else ...[
                                    if (solicitudPrincipal != null)
                                      _TarjetaApadrinamientoPrincipal(
                                        solicitud: solicitudPrincipal,
                                        esDesktop: esDesktop,
                                        reenviandoCorreoId: _reenviandoCorreoId,
                                        descargandoPdfId: _descargandoPdfId,
                                        onReenviarVerificacion: () =>
                                            _reenviarVerificacion(solicitudPrincipal!),
                                        onDescargarAcuerdoPdf: () =>
                                            _descargarAcuerdoPdf(solicitudPrincipal!),
                                        onVerContrato: () => _verContrato(solicitudPrincipal!),
                                        onVerDetallesMascota: () =>
                                            _verDetallesMascota(solicitudPrincipal!),
                                      ),

                                    // Lista / Cuadrícula de Otras Apadrinaciones (SOLO si hay más de 1 en esta categoría)
                                    if (otrasDePestana.isNotEmpty) ...[
                                      const SizedBox(height: 24),
                                      _construirEncabezadoOtrasApadrinaciones(
                                        _filtroSeleccionado == 0
                                            ? 'Otras mascotas apadrinadas'
                                            : (_filtroSeleccionado == 1
                                                ? 'Otras solicitudes pendientes'
                                                : 'Otras solicitudes rechazadas'),
                                      ),
                                      const SizedBox(height: 12),
                                      _construirGridOtrasApadrinaciones(
                                        otras: otrasDePestana,
                                        esDesktop: esDesktop,
                                        esTablet: esTablet,
                                      ),
                                    ] else if (_filtroSeleccionado == 0) ...[
                                      // Si solo tiene 1 apadrinación aprobada
                                      const SizedBox(height: 18),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: const Color(0xFFFCE4EC)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFF772A9).withValues(alpha: 0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFDE8F1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.pets_rounded,
                                                color: AppColors.rosa,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(
                                              child: Text(
                                                'Hasta el momento solo tienes una apadrinación.',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: Color(0xFF4A1525),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Pestañas visuales responsive ----------------

  Widget _construirPestanas({
    required int conteoAprobadas,
    required int conteoPendientes,
    required int conteoRechazadas,
    required bool esDesktop,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCE4EC)),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _botonPestana(
              indice: 0,
              titulo: 'Aprobadas',
              conteo: conteoAprobadas,
              esDesktop: esDesktop,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _botonPestana(
              indice: 1,
              titulo: 'Pendientes',
              conteo: conteoPendientes,
              esDesktop: esDesktop,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _botonPestana(
              indice: 2,
              titulo: 'Rechazadas',
              conteo: conteoRechazadas,
              esDesktop: esDesktop,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonPestana({
    required int indice,
    required String titulo,
    required int conteo,
    required bool esDesktop,
  }) {
    final bool activa = _filtroSeleccionado == indice;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            _filtroSeleccionado = indice;
            _idSolicitudSeleccionada = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            vertical: esDesktop ? 12 : 9,
            horizontal: 6,
          ),
          decoration: BoxDecoration(
            color: activa ? AppColors.rosa : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: activa
                ? [
                    BoxShadow(
                      color: AppColors.rosa.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
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
                    fontWeight: activa ? FontWeight.w800 : FontWeight.w600,
                    fontSize: esDesktop ? 14 : 12.5,
                    color: activa ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
              if (conteo > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: activa
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFFF1F5F9),
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

  // ---------------- Encabezado de otras apadrinaciones ----------------

  Widget _construirEncabezadoOtrasApadrinaciones(String titulo) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFFFDE8F1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.pets, color: AppColors.rosa, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15.5,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- Cuadrícula / Lista responsive de otras apadrinaciones ----------------

  Widget _construirGridOtrasApadrinaciones({
    required List<SolicitudApadrinamiento> otras,
    required bool esDesktop,
    required bool esTablet,
  }) {
    if (esDesktop || esTablet) {
      final int columnas = esDesktop ? 2 : 2;
      return LayoutBuilder(
        builder: (context, constraints) {
          final double anchoItem = (constraints.maxWidth - 16) / columnas;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: otras.map((s) {
              return SizedBox(
                width: anchoItem,
                child: _TarjetaOtraApadrinacion(
                  solicitud: s,
                  onSeleccionar: () {
                    setState(() {
                      _idSolicitudSeleccionada = s.id;
                    });
                  },
                  onVerDetalles: () => _verDetallesMascota(s),
                ),
              );
            }).toList(),
          );
        },
      );
    }

    // En móviles: lista vertical compacta
    return Column(
      children: otras.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TarjetaOtraApadrinacion(
            solicitud: s,
            onSeleccionar: () {
              setState(() {
                _idSolicitudSeleccionada = s.id;
              });
            },
            onVerDetalles: () => _verDetallesMascota(s),
          ),
        );
      }).toList(),
    );
  }

  Widget _construirEstadoVacio() {
    final String mensaje = _filtroSeleccionado == 0
        ? 'No tienes apadrinamientos con seguimientos activos actualmente.'
        : (_filtroSeleccionado == 1
            ? 'No tienes solicitudes de apadrinamiento pendientes.'
            : 'No tienes solicitudes rechazadas o canceladas.');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFCE4EC)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rosa.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _filtroSeleccionado == 0
                    ? Icons.verified_outlined
                    : (_filtroSeleccionado == 1
                        ? Icons.hourglass_empty_rounded
                        : Icons.cancel_outlined),
                size: 38,
                color: AppColors.rosa,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarMensajePrimeraVez(
    ResumenPadrino resumen, {
    List<SolicitudApadrinamiento> todas = const [],
  }) {}
}

// ============================================================================
// TARJETA PRINCIPAL DE APADRINAMIENTO CON BOTÓN "VER SEGUIMIENTOS Y REPORTES"
// ============================================================================

class _TarjetaApadrinamientoPrincipal extends StatefulWidget {
  final SolicitudApadrinamiento solicitud;
  final bool esDesktop;
  final String? reenviandoCorreoId;
  final String? descargandoPdfId;
  final VoidCallback onReenviarVerificacion;
  final VoidCallback onDescargarAcuerdoPdf;
  final VoidCallback onVerContrato;
  final VoidCallback onVerDetallesMascota;

  const _TarjetaApadrinamientoPrincipal({
    required this.solicitud,
    required this.esDesktop,
    required this.reenviandoCorreoId,
    required this.descargandoPdfId,
    required this.onReenviarVerificacion,
    required this.onDescargarAcuerdoPdf,
    required this.onVerContrato,
    required this.onVerDetallesMascota,
  });

  @override
  State<_TarjetaApadrinamientoPrincipal> createState() =>
      _TarjetaApadrinamientoPrincipalState();
}

class _TarjetaApadrinamientoPrincipalState
    extends State<_TarjetaApadrinamientoPrincipal> {
  late Future<List<SeguimientoApadrinamientoItem>> _historialFuture;

  // Botón interactivo principal para desplegar u ocultar la sección completa
  bool _mostrarSeguimientosYReportes = false;

  // Secciones individuales colapsables
  bool _expandirCiclos = false;
  bool _expandirReportes = false;
  bool _expandirHistorial = false;

  @override
  void initState() {
    super.initState();
    _historialFuture =
        SeguimientoApadrinamientoService.obtenerHistorial(widget.solicitud.id);
  }

  @override
  void didUpdateWidget(covariant _TarjetaApadrinamientoPrincipal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.solicitud.id != widget.solicitud.id) {
      _historialFuture =
          SeguimientoApadrinamientoService.obtenerHistorial(widget.solicitud.id);
    }
  }

  Future<void> _abrirReporte(CicloEvaluacionItem ev, {required bool descargar}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.rosa)),
    );
    try {
      final seguimientos =
          await SeguimientoApadrinamientoService.obtenerHistorial(widget.solicitud.id);
      if (!mounted) return;
      Navigator.pop(context);

      if (!ev.vistoPorUsuario) {
        SeguimientoApadrinamientoService.marcarReporteVisto(ev.idEvaluacion);
        setState(() {
          ev.vistoPorUsuario = true;
        });
      }

      final ciclosPrev = widget.solicitud.evaluacionesCiclos
          .where((e) => e.ciclo < ev.ciclo)
          .toList();

      if (descargar) {
        await ReportePadrinoPdfService.descargarReporte(
          padrinoNombre: widget.solicitud.solicitanteNombreCompleto,
          padrinoCorreo: widget.solicitud.solicitanteCorreo,
          padrinoTelefono: widget.solicitud.solicitanteTelefono,
          padrinoCedula: widget.solicitud.solicitanteCedula,
          fechaInicio: DateTime.tryParse(
            (widget.solicitud.fechaInicioApadrinamiento ?? '').replaceFirst(' ', 'T'),
          ),
          mascotaNombre: widget.solicitud.mascotaNombre,
          mascotaFoto: widget.solicitud.mascotaFotos,
          mascotaEspecie: widget.solicitud.mascotaEspecie,
          mascotaRaza: widget.solicitud.mascotaRaza,
          mascotaEdad: widget.solicitud.mascotaEdad != null
              ? '${widget.solicitud.mascotaEdad} años'
              : null,
          seguimientos: seguimientos.where((s) => s.ciclo == ev.ciclo).toList(),
          todosLosSeguimientos: seguimientos,
          ciclosAnteriores: ciclosPrev,
          estadoApadrinamiento: widget.solicitud.estadoApadrinamiento,
          motivoCancelacion: widget.solicitud.motivoCancelacion,
          fechaCancelacion: widget.solicitud.fechaCancelacion,
          decisionAdmin: ev.decision,
          notaDecision: ev.nota,
          fechaDecision: ev.fechaDecision,
          adminDecisionNombre: ev.adminNombre,
          cicloReporte: ev.ciclo,
        );
      } else {
        await ReportePadrinoPdfService.verReporte(
          padrinoNombre: widget.solicitud.solicitanteNombreCompleto,
          padrinoCorreo: widget.solicitud.solicitanteCorreo,
          padrinoTelefono: widget.solicitud.solicitanteTelefono,
          padrinoCedula: widget.solicitud.solicitanteCedula,
          fechaInicio: DateTime.tryParse(
            (widget.solicitud.fechaInicioApadrinamiento ?? '').replaceFirst(' ', 'T'),
          ),
          mascotaNombre: widget.solicitud.mascotaNombre,
          mascotaFoto: widget.solicitud.mascotaFotos,
          mascotaEspecie: widget.solicitud.mascotaEspecie,
          mascotaRaza: widget.solicitud.mascotaRaza,
          mascotaEdad: widget.solicitud.mascotaEdad != null
              ? '${widget.solicitud.mascotaEdad} años'
              : null,
          seguimientos: seguimientos.where((s) => s.ciclo == ev.ciclo).toList(),
          todosLosSeguimientos: seguimientos,
          ciclosAnteriores: ciclosPrev,
          estadoApadrinamiento: widget.solicitud.estadoApadrinamiento,
          motivoCancelacion: widget.solicitud.motivoCancelacion,
          fechaCancelacion: widget.solicitud.fechaCancelacion,
          decisionAdmin: ev.decision,
          notaDecision: ev.nota,
          fechaDecision: ev.fechaDecision,
          adminDecisionNombre: ev.adminNombre,
          cicloReporte: ev.ciclo,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar el reporte: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;

    return FutureBuilder<List<SeguimientoApadrinamientoItem>>(
      future: _historialFuture,
      builder: (context, snap) {
        final List<SeguimientoApadrinamientoItem> historial = snap.data ?? [];
        final proximo = historial.isNotEmpty ? historial.first.proximoSeguimiento : null;
        final ultimo = historial.isNotEmpty ? historial.first : null;

        final CicloEvaluacionItem? primerReporte = s.evaluacionesCiclos.isNotEmpty
            ? s.evaluacionesCiclos.first
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------------- TARJETA PRINCIPAL BLANCA ----------------
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFCE4EC), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF772A9).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.all(widget.esDesktop ? 22 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Distribución adaptativa (Desktop: fila amplia / Móvil: fila compacta)
                  if (widget.esDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _construirFotoMascota(s, tamano: 120),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _construirInfoMascota(s),
                              const SizedBox(height: 12),
                              if (s.esAprobada && s.tieneContrato)
                                _construirBannerAgradecimiento(s),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _construirFotoMascota(s, tamano: 86),
                            const SizedBox(width: 12),
                            Expanded(child: _construirInfoMascota(s)),
                          ],
                        ),
                        if (s.esAprobada && s.tieneContrato) ...[
                          const SizedBox(height: 12),
                          _construirBannerAgradecimiento(s),
                        ],
                      ],
                    ),

                  const SizedBox(height: 14),

                  // Acciones: contrato de apadrinamiento y seguimientos
                  if (s.esAprobada && s.tieneContrato) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF880E4F),
                        side: const BorderSide(color: Color(0xFFF48FB1), width: 1.2),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text(
                        'Ver contrato de apadrinación',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      onPressed: widget.onVerContrato,
                    ),
                    const SizedBox(height: 8),

                    // ---------------- NUEVO BOTÓN INTERACTIVO DE SEGUIMIENTOS Y REPORTES ----------------
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _mostrarSeguimientosYReportes = !_mostrarSeguimientosYReportes;
                            if (_mostrarSeguimientosYReportes) {
                              _expandirCiclos = false;
                              _expandirReportes = false;
                              _expandirHistorial = false;
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          decoration: BoxDecoration(
                            color: _mostrarSeguimientosYReportes
                                ? const Color(0xFFFDE8F1)
                                : const Color(0xFFFFF9FB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _mostrarSeguimientosYReportes
                                  ? AppColors.rosa
                                  : const Color(0xFFF9A8D4),
                              width: 1.3,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _mostrarSeguimientosYReportes
                                    ? Icons.analytics_rounded
                                    : Icons.analytics_outlined,
                                size: 18,
                                color: AppColors.rosa,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _mostrarSeguimientosYReportes
                                    ? 'Ocultar seguimientos'
                                    : 'Ver seguimientos',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: AppColors.rosa,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _mostrarSeguimientosYReportes
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: AppColors.rosa,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // ---------------- SECCIÓN DESPLEGABLE COMPLETA (ACTIVADA POR EL NUEVO BOTÓN) ----------------
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: (s.esAprobada && _mostrarSeguimientosYReportes)
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Seguimiento de Ciclos
                            _construirSeccionDesplegable(
                              expandida: _expandirCiclos,
                              onToggle: () => setState(() => _expandirCiclos = !_expandirCiclos),
                              icono: Icons.calendar_month_rounded,
                              titulo: 'Detalle de ciclos',
                              subtitulo: '${s.seguimientosEnCiclo} de 3',
                              trailingHeader: _construirIndicadorEtapas(
                                etapaActual: s.seguimientosEnCiclo,
                                proximo: proximo != null
                                    ? _MisApadrinamientosScreenState.formatearFechaCorta(proximo)
                                    : null,
                              ),
                              contenido: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Cada ciclo de apadrinamiento incluye 3 seguimientos realizados por parte de la Fundación Maritza Arévalo para verificar el proceso de la apadrinación.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35),
                                  ),
                                  if (proximo != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Próxima fecha programada: ${_MisApadrinamientosScreenState.formatearFechaLarga(proximo)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.rosa,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  ..._tarjetasCiclo(s),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 2. Reportes de Apadrinamiento
                            _construirSeccionDesplegable(
                              expandida: _expandirReportes,
                              onToggle: () => setState(() => _expandirReportes = !_expandirReportes),
                              icono: Icons.description_rounded,
                              titulo: 'Reportes de Apadrinamiento',
                              etiquetaTitulo: primerReporte != null && !primerReporte.vistoPorUsuario
                                  ? 'Nuevo'
                                  : null,
                              subtitulo: primerReporte != null
                                  ? 'Reporte del ciclo ${primerReporte.ciclo} • Promedio: ${primerReporte.promedio.toStringAsFixed(1)}/5'
                                  : 'Reporte a partir de 3 seguimientos (${s.seguimientosEnCiclo}/3)',
                              etiquetaSubtitulo: primerReporte != null
                                  ? primerReporte.puntuacion.toUpperCase()
                                  : null,
                              trailingHeader: primerReporte != null
                                  ? OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.rosa,
                                        side: const BorderSide(color: Color(0xFFF48FB1)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: const Icon(Icons.download_rounded, size: 15),
                                      label: const Text('Descargar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                      onPressed: () => _abrirReporte(primerReporte, descargar: true),
                                    )
                                  : null,
                              contenido: s.evaluacionesCiclos.isEmpty
                                  ? const Text(
                                      'El reporte oficial se genera automáticamente al completar los 3 seguimientos de cada ciclo.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    )
                                  : Column(
                                      children: s.evaluacionesCiclos.map((ev) {
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF9FC),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: const Color(0xFFFCE4EC)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.picture_as_pdf_rounded, color: AppColors.rosa, size: 24),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Reporte del Ciclo ${ev.ciclo}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 13,
                                                        color: Color(0xFF1E293B),
                                                      ),
                                                    ),
                                                    Text(
                                                      'Promedio: ${ev.promedio.toStringAsFixed(1)}/5 • ${ev.puntuacion.toUpperCase()}',
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => _abrirReporte(ev, descargar: false),
                                                child: const Text('Ver', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.rosa)),
                                              ),
                                              FilledButton(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: AppColors.rosa,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                onPressed: () => _abrirReporte(ev, descargar: true),
                                                child: const Text('Descargar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ),
                            const SizedBox(height: 10),

                            // 3. Historial de Seguimientos
                            _construirSeccionDesplegable(
                              expandida: _expandirHistorial,
                              onToggle: () => setState(() => _expandirHistorial = !_expandirHistorial),
                              icono: Icons.history_rounded,
                              titulo: 'Historial de Seguimientos',
                              subtitulo: ultimo != null
                                  ? 'Último: #${ultimo.numeroSeguimiento} • ${ultimo.cumplimiento ? "Cumplió" : "Pendiente"} • ${_MisApadrinamientosScreenState.parsearYFormatearFecha(ultimo.fechaSeguimiento.toIso8601String())}'
                                  : 'Sin seguimientos registrados aún',
                              contenido: historial.isEmpty
                                  ? const Text(
                                      'Pronto el administrador registrará el primer seguimiento de tu apadrinamiento.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    )
                                  : Column(
                                      children: historial.map((it) {
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF9FC),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: const Color(0xFFFCE4EC)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Seguimiento #${it.numeroSeguimiento} • Ciclo ${it.ciclo}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 13,
                                                      color: Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: it.cumplimiento
                                                          ? const Color(0xFFDCFCE7)
                                                          : const Color(0xFFFEE2E2),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      it.cumplimiento ? 'Cumplió' : 'No cumplió',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        color: it.cumplimiento
                                                            ? const Color(0xFF15803D)
                                                            : const Color(0xFFB91C1C),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Fecha: ${_MisApadrinamientosScreenState.formatearFechaLarga(it.fechaSeguimiento)}',
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                              ),
                                              Text(
                                                'Calificación: ${it.calificacion}/5  •  Revisado por: ${it.adminNombre}',
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                              ),
                                              if (it.observaciones.trim().isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Comentario: ${it.observaciones}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                    color: Color(0xFF334155),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF880E4F),
                        side: const BorderSide(color: Color(0xFFF48FB1), width: 1.2),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      icon: widget.descargandoPdfId == s.id
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.rosa,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text(
                        'Descargar acuerdo de compromiso',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      onPressed: widget.descargandoPdfId == s.id
                          ? null
                          : widget.onDescargarAcuerdoPdf,
                    ),
                  ] else ...[
                    // Estado pendiente o rechazado
                    if (s.esPendiente)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          'Tu solicitud fue enviada el ${s.fechaSolicitud}. El administrador de la fundación la está revisando.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                    if (s.esRechazada)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          'Motivo: ${s.observaciones ?? "No se especificó motivo"}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                        ),
                      ),
                  ],
                ],
              ),
            ),

          ],
        );
      },
    );
  }

  // ---------------- Subcomponentes de información ----------------

  Widget _construirFotoMascota(SolicitudApadrinamiento s, {required double tamano}) {
    return Stack(
      children: [
        Container(
          width: tamano,
          height: tamano,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFCE4EC), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PetImage(url: s.mascotaFotos),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.rosa,
              size: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirInfoMascota(SolicitudApadrinamiento s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.pets_rounded, color: AppColors.rosa, size: 19),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s.mascotaNombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (s.esPendiente) ...[
          _construirBadgeCorreo(s),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFFE91E63)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${s.mascotaEdadTexto}  •  ${s.mascotaEspecie} • ${s.mascotaRaza.isEmpty ? "Mestiza" : s.mascotaRaza}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _construirBadgeEstado(s),
        if (s.esAprobada && s.tieneContrato) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 14),
              const SizedBox(width: 3),
              const Flexible(
                child: Text(
                  'PADRINO OFICIAL',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    color: Color(0xFFB45309),
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _construirBannerAgradecimiento(SolicitudApadrinamiento s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF9A8D4), width: 1.1),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Gracias por apadrinar a ${s.mascotaNombre}!',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF4A1525),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Inicio oficial: ${_MisApadrinamientosScreenState.parsearYFormatearFecha(s.fechaInicioApadrinamiento)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF701A75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBadgeCorreo(SolicitudApadrinamiento s) {
    final bool verificado = s.esCorreoConfirmado;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: verificado ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: verificado ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verificado ? Icons.mark_email_read_rounded : Icons.mail_outline_rounded,
              size: 13,
              color: verificado ? const Color(0xFF059669) : const Color(0xFFE11D48),
            ),
            const SizedBox(width: 4),
            Text(
              verificado ? 'Correo verificado' : 'Correo pendiente',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: verificado ? const Color(0xFF047857) : const Color(0xFFBE123C),
              ),
            ),
            if (!verificado) ...[
              const SizedBox(width: 5),
              const Text('|', style: TextStyle(fontSize: 10, color: Color(0xFFFDA4AF))),
              const SizedBox(width: 5),
              InkWell(
                onTap: widget.reenviandoCorreoId == s.id
                    ? null
                    : widget.onReenviarVerificacion,
                child: widget.reenviandoCorreoId == s.id
                    ? const SizedBox(
                        width: 9,
                        height: 9,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFBE123C)),
                      )
                    : const Text(
                        'Reenviar',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFBE123C),
                          decoration: TextDecoration.underline,
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _construirBadgeEstado(SolicitudApadrinamiento s) {
    final bool aprobada = s.etiquetaEstado == 'Aprobada';
    final bool cerrada = s.etiquetaEstado != 'Pendiente' && !aprobada;

    final Color fondo = aprobada
        ? const Color(0xFFDCFCE7)
        : (cerrada ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7));
    final Color texto = aprobada
        ? const Color(0xFF15803D)
        : (cerrada ? const Color(0xFFB91C1C) : const Color(0xFFB45309));
    final IconData icono = aprobada
        ? Icons.check_circle_rounded
        : (cerrada ? Icons.cancel_rounded : Icons.hourglass_top_rounded);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: texto),
            const SizedBox(width: 4),
            Text(
              s.etiquetaEstado,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: texto,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _tarjetasCiclo(SolicitudApadrinamiento s) {
    final porCiclo = <int, CicloEvaluacionItem>{
      for (final ev in s.evaluacionesCiclos) ev.ciclo: ev,
    };
    final completados = <int>{
      for (var n = 1; n < s.cicloActual; n++) n,
      if (s.seguimientosEnCiclo >= 3) s.cicloActual,
      ...porCiclo.keys,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final enProceso = s.seguimientosEnCiclo < 3 && !completados.contains(s.cicloActual);
    return [
      if (enProceso) _tarjetaCicloEnProceso(s.cicloActual),
      for (final n in completados)
        porCiclo[n] != null
            ? _tarjetaCicloCompletado(porCiclo[n]!)
            : _tarjetaCicloSoloCompletado(n),
    ];
  }

  Widget _tarjetaCicloSoloCompletado(int ciclo) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF48FB1)),
      ),
      child: Text(
        'Ciclo $ciclo completado',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.rosa,
        ),
      ),
    );
  }

  Widget _tarjetaCicloEnProceso(int ciclo) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF48FB1)),
      ),
      child: Text(
        'Ciclo $ciclo en proceso',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.rosa,
        ),
      ),
    );
  }

  Widget _tarjetaCicloCompletado(CicloEvaluacionItem ev) {
    final buena = ev.promedio >= 4;
    final regular = !buena && ev.promedio >= 3;
    final fondo = buena
        ? const Color(0xFFE8F5E9)
        : (regular ? const Color(0xFFFFF3E0) : const Color(0xFFFFEBEE));
    final borde = buena
        ? const Color(0xFF2E7D32)
        : (regular ? const Color(0xFFEF6C00) : const Color(0xFFC62828));
    final texto = buena
        ? const Color(0xFF1B5E20)
        : (regular ? const Color(0xFFE65100) : const Color(0xFFB71C1C));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF48FB1), width: 1.4),
      ),
      child: Column(
        children: [
          Text(
            'Ciclo ${ev.ciclo} completado',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.rosa,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borde),
            ),
            child: Column(
              children: [
                const Text(
                  'PUNTUACIÓN DEL CICLO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ev.clasificacionTexto,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ev.promedio.toStringAsFixed(1)} / 5',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: borde,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionDesplegable({
    required bool expandida,
    required VoidCallback onToggle,
    required IconData icono,
    required String titulo,
    String? etiquetaTitulo,
    required String subtitulo,
    String? etiquetaSubtitulo,
    Widget? trailingHeader,
    required Widget contenido,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFCE4EC), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icono, color: AppColors.rosa, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                titulo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (etiquetaTitulo != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  etiquetaTitulo,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                subtitulo,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (etiquetaSubtitulo != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  etiquetaSubtitulo,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (trailingHeader != null) ...[
                    trailingHeader,
                    const SizedBox(width: 6),
                  ],
                  Icon(
                    expandida ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expandida
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  contenido,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirIndicadorEtapas({
    required int etapaActual,
    String? proximo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _etapaPunto(1, etapaActual >= 1),
            _etapaLinea(etapaActual >= 2),
            _etapaPunto(2, etapaActual >= 2),
            _etapaLinea(etapaActual >= 3),
            _etapaPunto(3, etapaActual >= 3),
          ],
        ),
        if (proximo != null) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF64748B)),
              const SizedBox(width: 3),
              Text(
                'Próximo: $proximo',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _etapaPunto(int num, bool completada) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: completada ? AppColors.rosa : const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
        border: Border.all(
          color: completada ? AppColors.rosa : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _etapaLinea(bool completada) {
    return Container(
      width: 18,
      height: 2.5,
      color: completada ? AppColors.rosa : const Color(0xFFE2E8F0),
    );
  }
}

// ============================================================================
// TARJETA DE "OTRA APADRINACIÓN" (LISTA / GRID SECUNDARIO)
// ============================================================================

class _TarjetaOtraApadrinacion extends StatelessWidget {
  final SolicitudApadrinamiento solicitud;
  final VoidCallback onSeleccionar;
  final VoidCallback onVerDetalles;

  const _TarjetaOtraApadrinacion({
    required this.solicitud,
    required this.onSeleccionar,
    required this.onVerDetalles,
  });

  @override
  Widget build(BuildContext context) {
    final s = solicitud;

    final Color colorEstado = s.etiquetaEstado == 'Aprobada'
        ? const Color(0xFF15803D)
        : (s.etiquetaEstado == 'Pendiente'
            ? const Color(0xFFB45309)
            : const Color(0xFFB91C1C));
    final Color fondoEstado = s.etiquetaEstado == 'Aprobada'
        ? const Color(0xFFDCFCE7)
        : (s.etiquetaEstado == 'Pendiente'
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFCE4EC), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF772A9).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto de la mascota
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCE4EC)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: PetImage(url: s.mascotaFotos),
                ),
              ),
              const SizedBox(width: 12),

              // Datos principales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            s.mascotaNombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: fondoEstado,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.etiquetaEstado,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: colorEstado,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${s.mascotaEdadTexto}  •  ${s.mascotaEspecie} • ${s.mascotaRaza.isEmpty ? "Mestiza" : s.mascotaRaza}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Solicitud: ${s.fechaSolicitud}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Botones de acción en la tarjeta secundaria
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onVerDetalles,
                  child: const Text('Ver perfil', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosa,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onSeleccionar,
                  child: const Text('Ver detalles', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
