import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/seguimiento_adopcion.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/screens/pets/pet_detail_screen.dart';
import 'package:paw_match/services/acuerdo_adopcion_pdf_service.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/reporte_adopcion_pdf_service.dart';
import 'package:paw_match/services/seguimiento_adopcion_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_carga.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Solicitudes de adopción del usuario, con la misma presentación que Apadrinamientos.
class MyAdoptionsScreen extends StatefulWidget {
  const MyAdoptionsScreen({super.key});

  @override
  State<MyAdoptionsScreen> createState() => _MyAdoptionsScreenState();
}

class _MyAdoptionsScreenState extends State<MyAdoptionsScreen> {
  int _filtroSeleccionado = 0;
  String? _idSeleccionada;
  String? _descargandoPdfId;
  String? _reenviandoCorreoId;
  final Map<String, GlobalKey> _clavesTarjeta = {};

  late Future<List<AdoptionRequest>> _future = AdoptionService.listMine();

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  void initState() {
    super.initState();
    AdoptionService.marcarLeidasUsuario();
  }

  void _abrirDetalles(String id) {
    setState(() => _idSeleccionada = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final destino = _clavesTarjeta[id]?.currentContext;
      if (destino == null || !mounted) return;
      Scrollable.ensureVisible(
        destino,
        alignment: 0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _recargar() async {
    setState(() => _future = AdoptionService.listMine());
    await _future.catchError((_) => <AdoptionRequest>[]);
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (!confirmar || !mounted) return;
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    Session.cerrar();
    Navegacion.ir(context, const WelcomeScreen());
  }

  Future<void> _reenviarVerificacion(AdoptionRequest s) async {
    setState(() => _reenviandoCorreoId = s.id);
    try {
      final res = await AdoptionService.reenviarVerificacionCorreo(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green.shade700, content: Text(res)),
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

  Future<void> _descargarActaPdf(AdoptionRequest s) async {
    setState(() => _descargandoPdfId = s.id);
    try {
      final fecha = DateTime.tryParse(s.requestedAt.replaceFirst(' ', 'T')) ?? DateTime.now();
      Uint8List? cedula;
      Uint8List? recibo;
      try {
        final fotos = await Future.wait([
          AdoptionService.fetchIdCard(s.id).catchError((_) => Uint8List(0)),
          AdoptionService.fetchUtilityBill(s.id).catchError((_) => Uint8List(0)),
        ]);
        if (fotos[0].isNotEmpty) cedula = fotos[0];
        if (fotos[1].isNotEmpty) recibo = fotos[1];
      } catch (_) {}

      Uint8List? fotoMascota;
      if (s.petPhoto.isNotEmpty) {
        try {
          final res = await http.get(Uri.parse(urlFoto(s.petPhoto)));
          if (res.statusCode == 200) fotoMascota = res.bodyBytes;
        } catch (_) {}
      }

      final bytes = await AcuerdoAdopcionPdfService.generarPdfBytes(
        DatosActaAdopcion(
          idSolicitud: s.id,
          nombreUsuario: s.applicantFullName,
          documentoUsuario: s.applicantIdNumber.trim().isEmpty ? null : s.applicantIdNumber.trim(),
          correoUsuario: s.applicantEmail.trim().isNotEmpty ? s.applicantEmail.trim() : Session.correo,
          telefonoUsuario: s.applicantPhone.trim().isEmpty ? null : s.applicantPhone.trim(),
          direccionUsuario: s.applicantAddress.trim().isEmpty ? null : s.applicantAddress.trim(),
          tipoVivienda: s.housingType,
          tienePatio: s.hasYard ?? false,
          tieneNinos: s.hasChildren ?? false,
          tieneOtrasMascotas: s.hasOtherPets ?? false,
          otrasMascotas: s.otherPets,
          tiempoDisponible: s.availableTime,
          experienciaPrevia: s.previousExperience ?? false,
          motivacion: s.additionalInfo,
          nombreMascota: s.petName,
          especieMascota: s.petSpecies,
          razaMascota: s.petBreed,
          edadMascota: s.petAgeLabel,
          sexoMascota: null,
          fechaAceptacion: fecha,
          aceptoTerminos: true,
          fotoCedula: cedula,
          fotoRecibo: recibo,
          fotoMascota: fotoMascota,
          estadoProceso: s.status,
          estadoCorreo: s.emailStatus,
        ),
      );
      await AcuerdoAdopcionPdfService.descargarYGuardarPdf(
        bytes: bytes,
        nombreMascota: s.petName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acta de adopción descargada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar el acta: $e')),
      );
    } finally {
      if (mounted) setState(() => _descargandoPdfId = null);
    }
  }

  Future<void> _verContrato(AdoptionRequest solicitud) async {
    if (!solicitud.hasContract) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El contrato todavía no está disponible. El administrador lo sube cuando la adopción queda formalizada.',
          ),
        ),
      );
      return;
    }
    late final Uint8List bytes;
    try {
      bytes = await DialogoCarga.mientras(
        context,
        () => AdoptionService.fetchContract(solicitud.id),
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

    if (esPdf) {
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: 'Contrato_Adopcion_${solicitud.petName}.pdf',
      );
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('Contrato de adopción - ${solicitud.petName}'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  void _verMascota(AdoptionRequest s) {
    if (s.petId.isEmpty) return;
    final pet = Pet(
      id: s.petId,
      nombre: s.petName.isEmpty ? 'Mascota' : s.petName,
      especie: s.petSpecies.isEmpty ? 'Perro' : s.petSpecies,
      raza: s.petBreed.isEmpty ? null : s.petBreed,
      edad: s.petAge,
      foto: s.petPhoto.isEmpty ? null : s.petPhoto,
      estadoAdopcion: s.isApproved ? 'adoptado' : s.petAdoptionStatus,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PetDetailScreen(pet: pet)),
    );
  }

  static String fechaCorta(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Activo';
    final parsed = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
    if (parsed == null) return raw;
    return '${parsed.day} ${_meses[parsed.month - 1]}. ${parsed.year}';
  }

  bool _esRechazada(AdoptionRequest s) => s.isRejected || s.status == 'cancelada';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: Column(
          children: [
            BarraSuperior(
              iconoTitulo: Icons.favorite_rounded,
              titulo: 'Mis Adopciones',
              onCerrarSesion: _confirmarCerrarSesion,
              forzarHuella: true,
            ),
            Expanded(
              child: FutureBuilder<List<AdoptionRequest>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.rosa));
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
                              'Error al cargar tus adopciones: ${snap.error}',
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
                  final aprobadas = todas.where((s) => s.isApproved).toList();
                  final rechazadas = todas.where(_esRechazada).toList();
                  final pendientes = todas
                      .where((s) => !s.isApproved && !_esRechazada(s))
                      .toList();
                  final listaActiva = _filtroSeleccionado == 0
                      ? aprobadas
                      : (_filtroSeleccionado == 1 ? pendientes : rechazadas);

                  final idAbierta = listaActiva.any((s) => s.id == _idSeleccionada)
                      ? _idSeleccionada
                      : listaActiva.firstOrNull?.id;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final ancho = constraints.maxWidth;
                      final esDesktop = ancho >= 880;
                      final esTablet = ancho >= 600 && ancho < 880;
                      final maxAncho = esDesktop ? 1120.0 : (esTablet ? 780.0 : double.infinity);

                      return RefreshIndicator(
                        color: AppColors.rosa,
                        onRefresh: _recargar,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            esDesktop ? 28 : 16,
                            8,
                            esDesktop ? 28 : 16,
                            110,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxAncho),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 6),
                                  _pestanas(
                                    aprobadas: aprobadas.length,
                                    pendientes: pendientes.length,
                                    rechazadas: rechazadas.length,
                                    esDesktop: esDesktop,
                                  ),
                                  const SizedBox(height: 16),
                                  if (listaActiva.isEmpty)
                                    _vacio()
                                  else ...[
                                    for (final s in listaActiva)
                                      Padding(
                                        key: _clavesTarjeta.putIfAbsent(s.id, GlobalKey.new),
                                        padding: const EdgeInsets.only(bottom: 14),
                                        child: s.id == idAbierta
                                            ? _TarjetaAdopcion(
                                                key: ValueKey('abierta-${s.id}'),
                                                solicitud: s,
                                                esDesktop: esDesktop,
                                                reenviando: _reenviandoCorreoId == s.id,
                                                descargando: _descargandoPdfId == s.id,
                                                fechaInicio: fechaCorta(s.adoptionStartDate),
                                                fechaSolicitud: fechaCorta(s.requestedAt),
                                                onReenviar: () => _reenviarVerificacion(s),
                                                onActa: () => _descargarActaPdf(s),
                                                onContrato: () => _verContrato(s),
                                                onMascota: () => _verMascota(s),
                                              )
                                            : _TarjetaOtraAdopcion(
                                                key: ValueKey('cerrada-${s.id}'),
                                                solicitud: s,
                                                fecha: fechaCorta(s.requestedAt),
                                                onSeleccionar: () => _abrirDetalles(s.id),
                                                onVerPerfil: () => _verMascota(s),
                                              ),
                                      ),
                                    if (listaActiva.length == 1 && _filtroSeleccionado == 0)
                                      const _AvisoUnaSola(),
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

  Widget _pestanas({
    required int aprobadas,
    required int pendientes,
    required int rechazadas,
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
          Expanded(child: _botonPestana(0, 'Aprobadas', aprobadas, esDesktop)),
          const SizedBox(width: 4),
          Expanded(child: _botonPestana(1, 'Pendientes', pendientes, esDesktop)),
          const SizedBox(width: 4),
          Expanded(child: _botonPestana(2, 'Rechazadas', rechazadas, esDesktop)),
        ],
      ),
    );
  }

  Widget _botonPestana(int indice, String titulo, int conteo, bool esDesktop) {
    final activa = _filtroSeleccionado == indice;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          _filtroSeleccionado = indice;
          _idSeleccionada = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: esDesktop ? 12 : 9, horizontal: 6),
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

  Widget _vacio() {
    final mensaje = _filtroSeleccionado == 0
        ? 'No tienes adopciones aprobadas.'
        : (_filtroSeleccionado == 1
            ? 'No tienes solicitudes de adopción pendientes.'
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
}

class _AvisoUnaSola extends StatelessWidget {
  const _AvisoUnaSola();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCE4EC)),
      ),
      child: const Row(
        children: [
          Icon(Icons.pets_rounded, color: AppColors.rosa, size: 18),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hasta el momento solo tienes una adopción.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF4A1525),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAdopcion extends StatefulWidget {
  const _TarjetaAdopcion({
    super.key,
    required this.solicitud,
    required this.esDesktop,
    required this.reenviando,
    required this.descargando,
    required this.fechaInicio,
    required this.fechaSolicitud,
    required this.onReenviar,
    required this.onActa,
    required this.onContrato,
    required this.onMascota,
  });

  final AdoptionRequest solicitud;
  final bool esDesktop;
  final bool reenviando;
  final bool descargando;
  final String fechaInicio;
  final String fechaSolicitud;
  final VoidCallback onReenviar;
  final VoidCallback onActa;
  final VoidCallback onContrato;
  final VoidCallback onMascota;

  @override
  State<_TarjetaAdopcion> createState() => _TarjetaAdopcionState();
}

class _TarjetaAdopcionState extends State<_TarjetaAdopcion> {
  bool _respuestas = false;
  bool _seguimientos = false;
  Future<List<SeguimientoAdopcionItem>>? _historial;

  void _alternarSeguimientos() {
    setState(() {
      _seguimientos = !_seguimientos;
      _historial ??= SeguimientoAdopcionService.obtenerHistorial(widget.solicitud.id);
    });
  }

  Future<void> _reporte(List<SeguimientoAdopcionItem> lista, {required bool descargar}) async {
    final s = widget.solicitud;
    final suma = lista.fold<int>(0, (total, item) => total + item.calificacion);
    final adopcion = AdopcionActivaSeguimiento(
      idSolicitud: s.id,
      estado: s.status,
      fechaInicio: DateTime.tryParse((s.adoptionStartDate ?? '').replaceFirst(' ', 'T')),
      contratoArchivo: s.contractFile,
      idMascota: s.petId,
      mascotaNombre: s.petName.isEmpty ? 'Mascota' : s.petName,
      mascotaFotos: s.petPhoto,
      mascotaEspecie: s.petSpecies,
      mascotaRaza: s.petBreed,
      mascotaEdad: s.petAge ?? 0,
      mascotaUnidadEdad: 'años',
      idAdoptante: s.userId,
      adoptanteNombre: s.applicantFullName,
      adoptanteCedula: s.applicantIdNumber,
      adoptanteCorreo: s.applicantEmail,
      adoptanteTelefono: s.applicantPhone,
      adoptanteDireccion: s.applicantAddress,
      calificacionPromedio: lista.isEmpty ? 0 : suma / lista.length,
      totalSeguimientos: lista.length,
    );
    try {
      if (descargar) {
        await ReporteAdopcionPdfService.descargar(adopcion: adopcion, seguimientos: lista);
      } else {
        await ReporteAdopcionPdfService.ver(adopcion: adopcion, seguimientos: lista);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el reporte: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final oficial = s.isApproved && s.hasContract;
    final raza = s.petBreed.isEmpty ? 'Mestiza' : s.petBreed;
    final especie = s.petSpecies.isEmpty ? 'Mascota' : s.petSpecies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _foto(s, tamano: widget.esDesktop ? 120 : 86),
                  SizedBox(width: widget.esDesktop ? 20 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pets_rounded, color: AppColors.rosa, size: 19),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.petName.isEmpty ? 'Mascota' : s.petName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _correo(s),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFFE91E63)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${s.petAgeLabel}  •  $especie • $raza',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _estado(s),
                        if (oficial) ...[
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 14),
                              SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  'ADOPTANTE OFICIAL',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10.5,
                                    color: Color(0xFFB45309),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (oficial) ...[
                const SizedBox(height: 12),
                _banner(
                  emoji: '🎉',
                  fondo: const Color(0xFFFDE8F1),
                  borde: const Color(0xFFF9A8D4),
                  titulo: '¡Gracias por adoptar a ${s.petName}!',
                  detalle: 'Inicio oficial: ${widget.fechaInicio}',
                  colorTitulo: const Color(0xFF4A1525),
                  colorDetalle: const Color(0xFF701A75),
                ),
              ] else if (s.contractPending) ...[
                const SizedBox(height: 12),
                _banner(
                  emoji: '📄',
                  fondo: const Color(0xFFFFFBEB),
                  borde: const Color(0xFFFDE68A),
                  titulo: 'Solicitud aprobada. Falta el contrato.',
                  detalle: s.adoptionStartDateLabel == null
                      ? 'Cuando el administrador lo suba, podrás verlo aquí.'
                      : 'Inicio oficial: ${widget.fechaInicio}',
                  colorTitulo: const Color(0xFF92400E),
                  colorDetalle: const Color(0xFF92400E),
                ),
              ],
              if (s.hasObservations && s.isApproved) ...[
                const SizedBox(height: 10),
                Text(
                  s.observations!.trim(),
                  style: const TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF475569)),
                ),
              ],
              const SizedBox(height: 14),
              if (s.isApproved) ...[
                _botonLinea(
                  icono: Icons.description_outlined,
                  texto: s.hasContract ? 'Ver Contrato' : 'Contrato pendiente',
                  onPressed: widget.onContrato,
                ),
                const SizedBox(height: 8),
                _botonLinea(
                  icono: _seguimientos ? Icons.analytics_rounded : Icons.analytics_outlined,
                  texto: _seguimientos ? 'Ocultar seguimientos' : 'Ver seguimientos',
                  flecha: true,
                  abierto: _seguimientos,
                  onPressed: _alternarSeguimientos,
                ),
                if (_seguimientos) ...[
                  const SizedBox(height: 8),
                  _panelSeguimientos(),
                ],
              ] else if (s.isPending) ...[
                _cajaEstado(
                  const Color(0xFFFFFBEB),
                  const Color(0xFFFDE68A),
                  const Color(0xFF92400E),
                  'Tu solicitud fue enviada el ${widget.fechaSolicitud}. El administrador de la fundación la está revisando.',
                ),
              ] else ...[
                _cajaEstado(
                  const Color(0xFFFEF2F2),
                  const Color(0xFFFECACA),
                  const Color(0xFF991B1B),
                  'Motivo: ${s.hasObservations ? s.observations!.trim() : 'No se especificó motivo.'}',
                ),
              ],
              const SizedBox(height: 8),
              _botonLinea(
                icono: Icons.picture_as_pdf_outlined,
                texto: 'Descargar acta (PDF)',
                cargando: widget.descargando,
                onPressed: widget.descargando ? null : widget.onActa,
              ),
              const SizedBox(height: 8),
              _botonLinea(
                icono: Icons.quiz_outlined,
                texto: _respuestas ? 'Ocultar respuestas' : 'Tus respuestas',
                flecha: true,
                abierto: _respuestas,
                onPressed: () => setState(() => _respuestas = !_respuestas),
              ),
              if (_respuestas) ...[
                const SizedBox(height: 10),
                for (final respuesta in s.answers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          respuesta.question,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.rosa,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(respuesta.answer, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _panelSeguimientos() {
    return FutureBuilder<List<SeguimientoAdopcionItem>>(
      future: _historial,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: AppColors.rosa)),
          );
        }
        if (snap.hasError) {
          return _cajaEstado(
            const Color(0xFFFEF2F2),
            const Color(0xFFFECACA),
            const Color(0xFF991B1B),
            'No se pudieron cargar los seguimientos.',
          );
        }
        final lista = snap.data ?? [];
        if (lista.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(4, 2, 4, 4),
            child: Text(
              'Aún no hay visitas de seguimiento.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
              ),
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${lista.length} ${lista.length == 1 ? 'seguimiento registrado' : 'seguimientos registrados'}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              if (lista.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final item in lista)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '#${item.numeroSeguimiento} · ${_MyAdoptionsScreenState.fechaCorta(item.fechaSeguimiento.toIso8601String())} · ${item.cumplimiento ? 'Cumplió' : 'Pendiente'}',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                    ),
                  ),
                _botonLinea(
                  icono: Icons.picture_as_pdf_outlined,
                  texto: 'Ver reporte',
                  onPressed: () => _reporte(lista, descargar: false),
                ),
                const SizedBox(height: 8),
                _botonLinea(
                  icono: Icons.download_rounded,
                  texto: 'Descargar reporte',
                  onPressed: () => _reporte(lista, descargar: true),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _foto(AdoptionRequest s, {required double tamano}) {
    return GestureDetector(
      onTap: widget.onMascota,
      child: Stack(
        children: [
          Container(
            width: tamano,
            height: tamano,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFCE4EC), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PetImage(url: s.petPhoto),
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
              child: const Icon(Icons.favorite_rounded, color: AppColors.rosa, size: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _correo(AdoptionRequest s) {
    final verificado = s.isEmailConfirmed;
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
                onTap: widget.reenviando ? null : widget.onReenviar,
                child: widget.reenviando
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

  Widget _estado(AdoptionRequest s) {
    final faltaContrato = s.contractPending;
    final aprobada = s.isApproved && !faltaContrato;
    final rechazada = s.isRejected || s.status == 'cancelada';
    final fondo = faltaContrato
        ? const Color(0xFFFEF3C7)
        : (aprobada
            ? const Color(0xFFDCFCE7)
            : (rechazada ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)));
    final texto = faltaContrato
        ? const Color(0xFFB45309)
        : (aprobada
            ? const Color(0xFF15803D)
            : (rechazada ? const Color(0xFFB91C1C) : const Color(0xFFB45309)));
    final icono = faltaContrato || aprobada
        ? Icons.check_circle_rounded
        : (rechazada ? Icons.cancel_rounded : Icons.hourglass_top_rounded);
    final etiqueta = faltaContrato || aprobada
        ? 'Aprobada'
        : (s.status == 'cancelada' ? 'Cancelada' : (rechazada ? 'Rechazada' : 'Pendiente'));
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: texto),
            const SizedBox(width: 4),
            Text(
              etiqueta,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: texto),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner({
    required String emoji,
    required Color fondo,
    required Color borde,
    required String titulo,
    required String detalle,
    required Color colorTitulo,
    required Color colorDetalle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borde, width: 1.1),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: colorTitulo),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colorDetalle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cajaEstado(Color fondo, Color borde, Color texto, String mensaje) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borde),
      ),
      child: Text(mensaje, style: TextStyle(fontSize: 12, color: texto, height: 1.35)),
    );
  }

  Widget _botonLinea({
    required IconData icono,
    required String texto,
    required VoidCallback? onPressed,
    bool cargando = false,
    bool flecha = false,
    bool abierto = false,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF880E4F),
        side: const BorderSide(color: Color(0xFFF48FB1), width: 1.2),
        minimumSize: const Size.fromHeight(42),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      icon: cargando
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rosa),
            )
          : Icon(icono, size: 17),
      label: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
          ),
          if (flecha) ...[
            const SizedBox(width: 4),
            Icon(
              abierto ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              size: 20,
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaOtraAdopcion extends StatelessWidget {
  const _TarjetaOtraAdopcion({
    super.key,
    required this.solicitud,
    required this.fecha,
    required this.onSeleccionar,
    required this.onVerPerfil,
  });

  final AdoptionRequest solicitud;
  final String fecha;
  final VoidCallback onSeleccionar;
  final VoidCallback onVerPerfil;

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final faltaContrato = s.contractPending;
    final aprobada = s.isApproved && !faltaContrato;
    final rechazada = s.isRejected || s.status == 'cancelada';
    final color = faltaContrato
        ? const Color(0xFFB45309)
        : (aprobada
            ? const Color(0xFF15803D)
            : (rechazada ? const Color(0xFFB91C1C) : const Color(0xFFB45309)));
    final fondo = faltaContrato
        ? const Color(0xFFFEF3C7)
        : (aprobada
            ? const Color(0xFFDCFCE7)
            : (rechazada ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)));
    final etiqueta = faltaContrato || aprobada
        ? 'Aprobada'
        : (s.status == 'cancelada' ? 'Cancelada' : (rechazada ? 'Rechazada' : 'Pendiente'));
    final raza = s.petBreed.isEmpty ? 'Mestiza' : s.petBreed;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFCE4EC), width: 1.1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCE4EC)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: PetImage(url: s.petPhoto),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.petName.isEmpty ? 'Mascota' : s.petName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: fondo,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            etiqueta,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${s.petAgeLabel}  •  ${s.petSpecies} • $raza',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Solicitud: $fecha',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onVerPerfil,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
