import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/enlaces.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/seguimiento_apadrinamiento.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/pets/pet_detail_screen.dart';
import 'package:paw_match/services/acuerdo_apadrinamiento_pdf_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/reporte_padrino_pdf_service.dart';
import 'package:paw_match/services/seguimiento_apadrinamiento_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/pet_card.dart';
import 'package:paw_match/widgets/star_rating_selector.dart';
import 'package:paw_match/widgets/tarjeta_seguimiento.dart';

class MisApadrinamientosScreen extends StatefulWidget {
  const MisApadrinamientosScreen({super.key});

  @override
  State<MisApadrinamientosScreen> createState() =>
      _MisApadrinamientosScreenState();
}

class _InfoBannerPadrino {
  final String titulo;
  final String mensaje;
  final IconData icono;
  final Color colorFondo;
  final Color colorBorde;
  final Color colorTexto;
  final Color colorIcono;

  const _InfoBannerPadrino({
    required this.titulo,
    required this.mensaje,
    required this.icono,
    required this.colorFondo,
    required this.colorBorde,
    required this.colorTexto,
    required this.colorIcono,
  });
}

class _MisApadrinamientosScreenState extends State<MisApadrinamientosScreen> {
  static bool _mensajeSesionMostrado = false;
  int _filtroSeleccionado = 0; // 0: Mis aprobadas, 1: Mis rechazadas o canceladas
  late Future<List<SolicitudApadrinamiento>> _future = _cargar();
  late Future<ResumenPadrino?> _resumenFuture = _cargarResumen();

  @override
  void initState() {
    super.initState();
    ApadrinamientoService.marcarLeidasUsuario();
    _resumenFuture = _cargarResumen()..then((resumen) {
      if (!mounted) return;
      if (!_mensajeSesionMostrado) {
        _mensajeSesionMostrado = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mostrarMensajePrimeraVez(
              resumen ??
                  ResumenPadrino(
                    idUsuario: Session.idUsuario ?? '',
                    nombres: Session.nombre,
                    apellidos: Session.apellidos,
                    bloqueadoApadrinar: false,
                    totalSeguimientos: 0,
                    calificacionPromedio: 0.0,
                    tieneAlerta: false,
                    solicitudesConAlerta: const [],
                  ),
            );
          }
        });
      }
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

  String? _descargandoPdfId;
  String? _reenviandoCorreoId;

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

  void _contactarWhatsApp(SolicitudApadrinamiento s) {
    final numero = FundacionInfo.whatsappNumero.isNotEmpty
        ? FundacionInfo.whatsappNumero
        : '573136177747';
    final mensaje =
        'Hola Fundación Maritza Arévalo, soy el padrino de ${s.mascotaNombre} y vengo de la app Paw Match para coordinar los detalles de mi apadrinamiento.';
    final url =
        'https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}';
    abrirEnlace(context, url, nombre: 'WhatsApp de la Fundación');
  }

  Future<void> _verDetallesMascota(String idMascota) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final pet = await PetsService.obtener(idMascota);
      if (!mounted) return;
      Navigator.pop(context); // cerrar diálogo de espera
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PetDetailScreen(pet: pet),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la mascota: $e')),
      );
    }
  }

  Future<void> _verContrato(SolicitudApadrinamiento s) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await ApadrinamientoService.obtenerBytesContrato(s.id);
      if (!mounted) return;
      Navigator.pop(context); // cerrar diálogo de espera

      final esPdf = bytes.length >= 4 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46; // %PDF

      if (esPdf) {
        await Printing.layoutPdf(
          onLayout: (_) => bytes,
          name: 'Contrato_Apadrinamiento_${s.mascotaNombre}.pdf',
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
              title: Text('Contrato de Apadrinamiento - ${s.mascotaNombre}'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al cargar contrato: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Apadrinamientos'),
      ),
      body: FutureBuilder<List<SolicitudApadrinamiento>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
          if (todas.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volunteer_activism_outlined,
                        size: 68, color: Colors.grey.shade400),
                    const SizedBox(height: 14),
                    Text(
                      'Aún no tienes solicitudes de apadrinamiento',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Explora las mascotas disponibles y pulsa «Apadrinar» para brindar tu apoyo y transformar una vida.',
                      style: t.bodyMedium?.copyWith(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final lista = _filtroSeleccionado == 0
              ? todas
                  .where((s) =>
                      s.estado == 'aprobada' ||
                      s.estadoApadrinamiento == 'activa' ||
                      s.tieneContrato)
                  .toList()
              : todas
                  .where((s) =>
                      s.estado == 'rechazada' ||
                      s.estado == 'cancelada' ||
                      s.estadoApadrinamiento == 'cancelada')
                  .toList();

          final totalElementos = lista.isEmpty ? 2 : lista.length + 1;

          return RefreshIndicator(
            onRefresh: _recargar,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: totalElementos,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _construirCabeceraPadrino(todas);
                }

                if (lista.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _filtroSeleccionado == 0
                                ? Icons.verified_outlined
                                : Icons.cancel_outlined,
                            size: 42,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _filtroSeleccionado == 0
                                ? 'No tienes apadrinamientos aprobados activos actualmente.'
                                : 'No tienes solicitudes rechazadas o canceladas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final s = lista[i - 1];
                final color = switch (s.estado) {
                  'aprobada' =>
                    s.tieneContrato ? Colors.green : Colors.amber.shade800,
                  'rechazada' => Colors.redAccent,
                  'cancelada' => Colors.blueGrey,
                  _ => Colors.orange,
                };

                final estadoTexto = switch (s.estado) {
                  'aprobada' => s.tieneContrato
                      ? 'APROBADA (PADRINO OFICIAL)'
                      : 'APROBADA (ESPERANDO CONTRATO)',
                  'rechazada' => 'RECHAZADA',
                  'cancelada' => 'CANCELADA',
                  _ => 'PENDIENTE',
                };

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: color.withOpacity(0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabecera: Estado de verificación de correo y Estado del proceso
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            // Badge de verificación de correo
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: s.esCorreoConfirmado
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: s.esCorreoConfirmado
                                      ? const Color(0xFF81C784)
                                      : const Color(0xFFFFD54F),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    s.esCorreoConfirmado
                                        ? Icons.mark_email_read_rounded
                                        : Icons.mark_email_unread_rounded,
                                    size: 14,
                                    color: s.esCorreoConfirmado
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFF57F17),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    s.correoEstadoTexto,
                                    style: TextStyle(
                                      color: s.esCorreoConfirmado
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFF57F17),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (!s.esCorreoConfirmado) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: _reenviandoCorreoId == s.id
                                          ? null
                                          : () => _reenviarVerificacion(s),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        child: _reenviandoCorreoId == s.id
                                            ? const SizedBox(
                                                width: 10,
                                                height: 10,
                                                child: CircularProgressIndicator(strokeWidth: 1.5),
                                              )
                                            : const Text(
                                                'Reenviar',
                                                style: TextStyle(
                                                  decoration: TextDecoration.underline,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10.5,
                                                  color: Color(0xFFE65100),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            if (s.tieneReporteNuevo) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.rosa,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.mark_email_unread_rounded, size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'Reporte nuevo',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Chip estado del proceso
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color),
                              ),
                              child: Text(
                                estadoTexto,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Fotografía centrada, nombre debajo centrado, y edad debajo
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 94,
                                height: 94,
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
                                  fontSize: 20,
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
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.rosa,
                                  side: const BorderSide(color: AppColors.rosa),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.pets, size: 18),
                                label: Text('Ver perfil de ${s.mascotaNombre}'),
                                onPressed: () => _verDetallesMascota(s.idMascota),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 24),

                        // Progreso del ciclo actual (para apadrinamientos aprobados/activos)
                        if (s.esAprobada) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF7F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFF3D5E2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Ciclo ${s.cicloActual} · ${s.seguimientosEnCiclo}/3',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: AppColors.texto,
                                      ),
                                    ),
                                    Text(
                                      s.seguimientosEnCiclo >= 3
                                          ? 'Ciclo completado'
                                          : '${3 - s.seguimientosEnCiclo} pendiente(s)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: s.seguimientosEnCiclo >= 3
                                            ? Colors.green.shade700
                                            : AppColors.rosa,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: (s.seguimientosEnCiclo / 3.0).clamp(0.0, 1.0),
                                    minHeight: 8,
                                    backgroundColor: const Color(0xFFE8D5DF),
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.rosa),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ESTADO APROBADA
                        if (s.esAprobada) ...[
                          if (!s.tieneContrato) ...[
                            // PASO PENDIENTE: ESPERANDO CONTRATO
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.amber.shade400,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.hourglass_top_rounded,
                                        color: Colors.amber.shade900,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '¡Solicitud aprobada! Falta 1 paso ⏳',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tu solicitud para apadrinar a ${s.mascotaNombre} ha sido aprobada por la fundación.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.amber.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.assignment_outlined,
                                          color: Colors.amber.shade900,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Aún falta un paso: debes esperar que el administrador suba el contrato de apadrinamiento firmado. Una vez lo suba, serás formalmente el padrino de ${s.mascotaNombre} y podrás descargarlo aquí.',
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
                                  if (s.observaciones != null &&
                                      s.observaciones!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Indicaciones de la fundación: ${s.observaciones}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ] else ...[
                            // YA TIENE CONTRATO: PADRINO OFICIAL
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.green.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.verified, color: Colors.green, size: 24),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '¡Eres padrino oficial! 🎉',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '📅 Fecha oficial de inicio: ${s.fechaInicioApadrinamiento ?? 'Activo'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Contacto oficial: Fundación Maritza Arévalo (+${FundacionInfo.whatsappNumero.isNotEmpty ? FundacionInfo.whatsappNumero : '573136177747'})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  if (s.observaciones != null &&
                                      s.observaciones!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.rate_review_outlined,
                                                  size: 15, color: Colors.green),
                                              SizedBox(width: 6),
                                              Text(
                                                'Observaciones de la fundación:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            s.observaciones!,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.rosa,
                                      minimumSize: const Size.fromHeight(44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.assignment_turned_in),
                                    label: const Text(
                                      'Ver Contrato de Apadrinamiento',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => _verContrato(s),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.chat_bubble_outline),
                                    label: const Text(
                                      'Contactar por WhatsApp a la Fundación',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => _contactarWhatsApp(s),
                                  ),
                                  const SizedBox(height: 12),
                                  _SeccionSeguimientoUsuario(
                                    solicitud: s,
                                    idSolicitud: s.id,
                                    nombreMascota: s.mascotaNombre,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ] else if (s.esCancelada) ...[
                          // ESTADO CANCELADA
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.red.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.cancel,
                                      color: Colors.redAccent,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Apadrinamiento cancelado por la administración',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                          color: Colors.red.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Motivo de la cancelación informado por la fundación:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Text(
                                    s.observaciones?.trim().isNotEmpty == true
                                        ? s.observaciones!
                                        : 'No se detalló un motivo específico.',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                if (s.fechaActualizacionEstado != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Fecha de cancelación: ${s.fechaActualizacionEstado}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                _construirCuentaRegresivaEliminacion(s),
                              ],
                            ),
                          ),
                        ] else if (s.esPendiente) ...[
                          Text(
                            'Tu solicitud fue enviada el ${s.fechaSolicitud}. El administrador de la fundación está revisando tu motivación y tus datos.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ] else if (s.esRechazada) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Motivo u observaciones:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Rechazada ${s.vecesRechazada} ${s.vecesRechazada == 1 ? 'vez' : 'veces'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.observaciones ?? 'No se especificó motivo.',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                  ),
                                ),
                                _construirCuentaRegresivaEliminacion(s),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Tu motivación enviada
                        Text(
                          'Tu motivación registrada:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.motivacion,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.rosa,
                            side: const BorderSide(color: AppColors.rosa, width: 1.4),
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _descargandoPdfId == s.id
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rosa),
                                )
                              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                          label: const Text(
                            'Descargar acuerdo de apadrinamiento (PDF)',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          onPressed: _descargandoPdfId == s.id ? null : () => _descargarAcuerdoPdf(s),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Cabecera con nombre de usuario, promedio de estrellas, banner y filtros.
  Widget _construirCabeceraPadrino(List<SolicitudApadrinamiento> todas) {
    final tieneReporteNuevoEnAprobadas = todas.any(
      (s) =>
          (s.estado == 'aprobada' ||
              s.estadoApadrinamiento == 'activa' ||
              s.tieneContrato) &&
          s.tieneReporteNuevo,
    );

    return FutureBuilder<ResumenPadrino?>(
      future: _resumenFuture,
      builder: (context, snap) {
        final resumen = snap.data;
        final nombre = '${Session.nombre} ${Session.apellidos}'.trim();

        return Column(
          children: [
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFF0E5EC)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.rosa.withValues(alpha: 0.12),
                      radius: 20,
                      child: const Icon(Icons.volunteer_activism, color: AppColors.rosa, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre.isNotEmpty ? nombre : 'Padrino PawMatch',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Calificación como padrino',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    StarRatingBadge(
                      rating: resumen?.calificacionPromedio ?? 0.0,
                      totalSeguimientos: resumen?.totalSeguimientos ?? 0,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _construirBannerPadrino(resumen),
            const SizedBox(height: 14),
            _construirFiltros(tieneReporteNuevoEnAprobadas),
          ],
        );
      },
    );
  }

  Widget _construirFiltros(bool tieneReporteNuevoEnAprobadas) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _filtroSeleccionado = 0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: _filtroSeleccionado == 0
                    ? AppColors.rosa
                    : AppColors.rosa.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _filtroSeleccionado == 0
                      ? AppColors.rosa
                      : AppColors.rosa.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: _filtroSeleccionado == 0 ? Colors.white : AppColors.rosa,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Mis aprobadas',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _filtroSeleccionado == 0 ? Colors.white : AppColors.rosa,
                      ),
                    ),
                  ),
                  if (tieneReporteNuevoEnAprobadas) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _filtroSeleccionado == 0 ? Colors.white : AppColors.rosa,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _filtroSeleccionado = 1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: _filtroSeleccionado == 1
                    ? AppColors.rosa
                    : AppColors.rosa.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _filtroSeleccionado == 1
                      ? AppColors.rosa
                      : AppColors.rosa.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cancel_rounded,
                    size: 16,
                    color: _filtroSeleccionado == 1 ? Colors.white : AppColors.rosa,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Mis rechazadas o canceladas',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: _filtroSeleccionado == 1 ? Colors.white : AppColors.rosa,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirCuentaRegresivaEliminacion(SolicitudApadrinamiento s) {
    final limite = s.eliminarDespuesDe;
    String texto;
    if (limite != null) {
      final diff = limite.difference(DateTime.now());
      final minutos = diff.inMinutes;
      if (minutos <= 0) {
        texto =
            'Esta solicitud se eliminará en cualquier momento (tiempo de 2 horas cumplido tras ver la notificación).';
      } else if (minutos > 60) {
        texto =
            'Esta solicitud se eliminará en 1 hora y ${minutos % 60} min (regla de 2 horas tras ver la notificación).';
      } else {
        texto =
            'Esta solicitud se eliminará en $minutos min (regla de 2 horas tras ver la notificación).';
      }
    } else {
      texto =
          'Esta solicitud se eliminará automáticamente 2 horas después de que veas su notificación.';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, size: 16, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade900,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Estructura de información visual para el banner y modal
  _InfoBannerPadrino _calcularInfoBanner(ResumenPadrino? resumen) {
    final total = resumen?.totalSeguimientos ?? 0;
    final prom = resumen?.calificacionPromedio ?? 0.0;

    if (total == 0) {
      return const _InfoBannerPadrino(
        titulo: 'Bienvenido a tus apadrinamientos',
        mensaje: 'Aún no tienes seguimientos. Tu apadrinamiento será evaluado por la fundación.',
        icono: Icons.volunteer_activism_outlined,
        colorFondo: Color(0xFFFCE4EC),
        colorBorde: Color(0xFFF48FB1),
        colorTexto: Color(0xFF880E4F),
        colorIcono: AppColors.rosa,
      );
    }

    if (prom >= 4.0) {
      return const _InfoBannerPadrino(
        titulo: '¡Excelente compromiso!',
        mensaje: '¡Eres un buen padrino! Sigue así, tu compromiso hace la diferencia.',
        icono: Icons.military_tech_rounded,
        colorFondo: Color(0xFFE8F5E9),
        colorBorde: Color(0xFF81C784),
        colorTexto: Color(0xFF1B5E20),
        colorIcono: Color(0xFF2E7D32),
      );
    }

    if (prom >= 3.0) {
      return const _InfoBannerPadrino(
        titulo: 'Vas por buen camino',
        mensaje: 'Vas por buen camino, pero puedes mejorar. Cumple con tus compromisos para mantener tu apadrinamiento.',
        icono: Icons.warning_amber_rounded,
        colorFondo: Color(0xFFFFF3E0),
        colorBorde: Color(0xFFFFB74D),
        colorTexto: Color(0xFFE65100),
        colorIcono: Color(0xFFEF6C00),
      );
    }

    return const _InfoBannerPadrino(
      titulo: 'Atención a tu apadrinamiento',
      mensaje: 'Tu apadrinamiento no está cumpliendo lo esperado. Si no mejoras, podrías perder la posibilidad de seguir siendo padrino.',
      icono: Icons.error_outline_rounded,
      colorFondo: Color(0xFFFFEBEE),
      colorBorde: Color(0xFFEF9A9A),
      colorTexto: Color(0xFFB71C1C),
      colorIcono: Color(0xFFC62828),
    );
  }

  /// Banner informativo permanente en la cabecera
  Widget _construirBannerPadrino(ResumenPadrino? resumen) {
    final info = _calcularInfoBanner(resumen);
    final total = resumen?.totalSeguimientos ?? 0;
    final progreso = (total / 3.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: info.colorFondo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: info.colorBorde, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(info.icono, color: info.colorIcono, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: info.colorTexto,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.mensaje,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: info.colorTexto.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Colors.black12),
          const SizedBox(height: 12),
          if (total < 3) ...[
            Text(
              'En tu 3er seguimiento podrás ver tu reporte de padrino y la fundación evaluará si puedes seguir siendo padrino. Llevas $total de 3.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: info.colorTexto,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 7,
                backgroundColor: Colors.black.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(info.colorIcono),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: info.colorBorde),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: info.colorIcono, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¡Cuentas con seguimientos evaluados! Puedes consultar y descargar el reporte en la tarjeta de cada mascota abajo.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: info.colorTexto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Diálogo / bottom sheet modal que se muestra la primera vez que entra en la sesión
  void _mostrarMensajePrimeraVez(ResumenPadrino resumen) {
    final info = _calcularInfoBanner(resumen);
    final total = resumen.totalSeguimientos;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: 100 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 30,
                backgroundColor: info.colorFondo,
                child: Icon(info.icono, size: 32, color: info.colorIcono),
              ),
              const SizedBox(height: 14),
              Text(
                info.titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: info.colorTexto,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                info.mensaje,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  total < 3
                      ? 'Progreso de evaluación: Llevas $total de 3 seguimientos.'
                      : '¡Ya cuentas con 3 o más seguimientos! Tu reporte de padrino está disponible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosa,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sección de historial de seguimiento dentro de la tarjeta de apadrinamiento del usuario.
class _SeccionSeguimientoUsuario extends StatefulWidget {
  final SolicitudApadrinamiento solicitud;
  final String idSolicitud;
  final String nombreMascota;

  const _SeccionSeguimientoUsuario({
    required this.solicitud,
    required this.idSolicitud,
    required this.nombreMascota,
  });

  @override
  State<_SeccionSeguimientoUsuario> createState() =>
      _SeccionSeguimientoUsuarioState();
}

class _SeccionSeguimientoUsuarioState extends State<_SeccionSeguimientoUsuario> {
  late Future<List<SeguimientoApadrinamientoItem>> _historialFuture;

  @override
  void initState() {
    super.initState();
    _historialFuture =
        SeguimientoApadrinamientoService.obtenerHistorial(widget.idSolicitud);
  }

  Future<void> _abrirReporte(CicloEvaluacionItem ev, {required bool descargar}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final seguimientos =
          await SeguimientoApadrinamientoService.obtenerHistorial(widget.solicitud.id);
      if (!mounted) return;
      Navigator.pop(context);

      // Si no estaba visto por el usuario, marcarlo visto de inmediato
      if (!ev.vistoPorUsuario) {
        SeguimientoApadrinamientoService.marcarReporteVisto(ev.idEvaluacion);
        setState(() {
          ev.vistoPorUsuario = true;
        });
      }

      if (descargar) {
        await ReportePadrinoPdfService.descargarReporte(
          padrinoNombre: widget.solicitud.solicitanteNombreCompleto,
          padrinoCorreo: widget.solicitud.solicitanteCorreo,
          padrinoTelefono: widget.solicitud.solicitanteTelefono,
          mascotaNombre: widget.solicitud.mascotaNombre,
          mascotaEspecie: widget.solicitud.mascotaEspecie,
          mascotaRaza: widget.solicitud.mascotaRaza,
          mascotaEdad: widget.solicitud.mascotaEdad != null
              ? '${widget.solicitud.mascotaEdad} años'
              : null,
          seguimientos: seguimientos,
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
          mascotaNombre: widget.solicitud.mascotaNombre,
          mascotaEspecie: widget.solicitud.mascotaEspecie,
          mascotaRaza: widget.solicitud.mascotaRaza,
          mascotaEdad: widget.solicitud.mascotaEdad != null
              ? '${widget.solicitud.mascotaEdad} años'
              : null,
          seguimientos: seguimientos,
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
    return FutureBuilder<List<SeguimientoApadrinamientoItem>>(
      future: _historialFuture,
      builder: (context, snap) {
        final lista = snap.data ?? [];
        final cargando = snap.connectionState == ConnectionState.waiting;
        final proximo = lista.isNotEmpty ? lista.first.proximoSeguimiento : null;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF0E5EC)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              leading: CircleAvatar(
                backgroundColor: AppColors.rosa.withValues(alpha: 0.12),
                radius: 18,
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  color: AppColors.rosa,
                  size: 20,
                ),
              ),
              title: Text(
                'Seguimiento de ${widget.nombreMascota}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              subtitle: Text(
                lista.isEmpty
                    ? (cargando ? 'Cargando reportes...' : 'Sin seguimientos registrados')
                    : '${lista.length} seguimiento(s) · Próximo: ${proximo != null ? "${proximo.day}/${proximo.month}/${proximo.year}" : "Por programar"}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              children: [
                if (cargando)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (lista.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Text(
                          'Aún no se han registrado seguimientos oficiales para ${widget.nombreMascota}. Pronto el administrador añadirá los reportes.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'El reporte se habilita a partir de 3 seguimientos (0/3)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Filas de reportes por ciclo evaluado
                  if (widget.solicitud.evaluacionesCiclos.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reportes de apadrinamiento disponibles:',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.texto,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...widget.solicitud.evaluacionesCiclos.map((ev) {
                            final noVisto = !ev.vistoPorUsuario;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: noVisto ? const Color(0xFFFFF0F5) : const Color(0xFFF9F9FB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: noVisto ? AppColors.rosa : Colors.grey.shade300,
                                  width: noVisto ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: noVisto ? AppColors.rosa : Colors.grey.shade700,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Reporte ciclo ${ev.ciclo}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (noVisto) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.rosa,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Reporte nuevo',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Promedio: ${ev.promedio.toStringAsFixed(1)}/5 · ${ev.puntuacion.toUpperCase()}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.rosa,
                                      side: const BorderSide(color: AppColors.rosa),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _abrirReporte(ev, descargar: false),
                                    child: const Text('Ver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 6),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.rosa,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _abrirReporte(ev, descargar: true),
                                    child: const Text('Descargar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'El reporte se habilita a partir de 3 seguimientos (${widget.solicitud.seguimientosEnCiclo}/3)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  ...lista.map((it) => TarjetaSeguimiento(seguimiento: it)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

