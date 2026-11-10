import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/screens/adoption/adoption_detail_admin_screen.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/acuerdo_adopcion_pdf_service.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Solicitudes de adopción del administrador: foto, peludito, adoptante
/// y el detalle completo en una hoja.
class AdoptionRequestsAdminScreen extends StatefulWidget {
  const AdoptionRequestsAdminScreen({super.key});

  @override
  State<AdoptionRequestsAdminScreen> createState() =>
      _AdoptionRequestsAdminScreenState();
}

class _AdoptionRequestsAdminScreenState extends State<AdoptionRequestsAdminScreen> {
  int _filtro = 0;
  String? _procesandoId;
  String? _descargandoPdfId;
  late Future<List<AdoptionRequest>> _future = AdoptionService.listForAdmin();

  @override
  void initState() {
    super.initState();
    AdoptionService.marcarLeidasAdmin();
  }

  Future<void> _recargar() async {
    final siguiente = AdoptionService.listForAdmin();
    setState(() {
      _future = siguiente;
    });
    await siguiente.catchError((_) => <AdoptionRequest>[]);
  }

  Future<void> _aprobar(AdoptionRequest s) async {
    final notas = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¡Todo listo para la adopción! 🐾',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¡Qué emoción! ${s.applicantFullName} está a punto de darle un nuevo hogar lleno de amor a ${s.petName.isEmpty ? 'la mascota' : s.petName}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notas,
              maxLines: 2,
              maxLength: 300,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'Envía una nota o recomendación',
                hintMaxLines: 3,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('¡Confirmar adopción! 💖'),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final hoy = DateTime.now();
    final inicio =
        '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
    final guardada = await _guardar(
      s,
      estado: 'aprobada',
      fechaInicio: inicio,
      observaciones: notas.text.trim(),
      aviso: 'Solicitud aceptada. Ya puedes subir el contrato.',
    );
    if (guardada && mounted) setState(() => _filtro = 1);
  }

  Future<void> _rechazar(AdoptionRequest s) async {
    final motivo = TextEditingController();
    String? errorMotivo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Center(
            child: Text(
              'Rechazar solicitud',
              textAlign: TextAlign.center,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Indica el motivo por el cual se rechaza la solicitud de ${s.petName.isEmpty ? 'la mascota' : s.petName}:',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: motivo,
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
              const SizedBox(height: 8),
              Text(
                _avisoCorreo(s.applicantEmail, 'rechazo'),
                style: const TextStyle(fontSize: 12, color: AppColors.grisTexto),
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
                if (motivo.text.trim().isEmpty) {
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
    if (ok != true || !mounted) return;
    final guardada = await _guardar(
      s,
      estado: 'rechazada',
      observaciones: motivo.text.trim(),
      aviso: 'Solicitud rechazada. Se envió el correo al adoptante.',
    );
    if (guardada && mounted) setState(() => _filtro = 2);
  }

  String _avisoCorreo(String correo, String decision) {
    final destino = correo.trim();
    if (destino.isEmpty) {
      return 'Se enviará un correo de $decision y una notificación en la app al solicitante.';
    }
    return 'Se enviará un correo de $decision a $destino y una notificación en la app.';
  }

  Future<bool> _guardar(
    AdoptionRequest s, {
    required String estado,
    required String aviso,
    String? fechaInicio,
    String? observaciones,
  }) async {
    setState(() => _procesandoId = s.id);
    try {
      await AdoptionService.updateStatus(
        id: s.id,
        status: estado,
        startDate: fechaInicio,
        observations: observaciones,
      );
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aviso)));
      await _recargar();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return false;
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

  void _abrirContrato(AdoptionRequest s) {
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
            child: AdoptionDetailAdminScreen(
              request: s,
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

  void _abrirDetalle(AdoptionRequest s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      builder: (_) => AdoptionDetailAdminScreen(
        request: s,
        onCambioEstado: (_) {
          Navigator.pop(context);
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
              iconoTitulo: Icons.pets_rounded,
              titulo: 'Solicitudes de adopción',
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
                    Text('No se pudieron cargar las solicitudes.\n${snap.error}', textAlign: TextAlign.center),
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
          final nuevas = todas.where((s) => s.isPending).toList();
          final aprobadas = [
            ...todas.where((s) => s.contractPending),
            ...todas.where((s) => s.isApproved && s.hasContract),
          ];
          final rechazadas = todas.where((s) => s.isRejected).toList();
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
                    _TarjetaAdmin(
                      solicitud: s,
                      procesando: _procesandoId == s.id,
                      descargando: _descargandoPdfId == s.id,
                      onAceptar: () => _aprobar(s),
                      onRechazar: () => _rechazar(s),
                      onDetalles: () => _abrirDetalle(s),
                      onContrato: () => _abrirContrato(s),
                      onDescargarActa: () => _descargarActa(s),
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

  Widget _pestanas({required int nuevas, required int aprobadas, required int rechazadas}) {
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

  Future<void> _descargarActa(AdoptionRequest s) async {
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
        const SnackBar(content: Text('Acta de compromiso descargada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar el acta: $e')),
      );
    } finally {
      if (mounted) setState(() => _descargandoPdfId = null);
    }
  }

  Widget _vacio(int filtro) {
    final texto = switch (filtro) {
      1 => 'No hay adopciones aprobadas.',
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

class _TarjetaAdmin extends StatefulWidget {
  final AdoptionRequest solicitud;
  final bool procesando;
  final bool descargando;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;
  final VoidCallback onDetalles;
  final VoidCallback onContrato;
  final VoidCallback onDescargarActa;

  const _TarjetaAdmin({
    required this.solicitud,
    required this.procesando,
    required this.descargando,
    required this.onAceptar,
    required this.onRechazar,
    required this.onDetalles,
    required this.onContrato,
    required this.onDescargarActa,
  });

  @override
  State<_TarjetaAdmin> createState() => _TarjetaAdminState();
}

class _TarjetaAdminState extends State<_TarjetaAdmin> {
  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final especie = s.petSpecies.isEmpty ? 'Mascota' : s.petSpecies;
    final raza = s.petBreed.isEmpty ? 'Mestizo' : s.petBreed;

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
                  child: PetImage(url: s.petPhoto),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.petName.isEmpty ? 'Mascota' : s.petName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$especie · $raza',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Adoptante: ${s.applicantFullName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF9D174D)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.requestedAtLabel,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!s.isPending) ...[
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
            onPressed: widget.onDetalles,
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
            onPressed: widget.descargando ? null : widget.onDescargarActa,
            icon: widget.descargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rosa),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Descargar acta de compromiso',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
          if (s.isPending) ...[
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
                    onPressed: widget.procesando ? null : widget.onRechazar,
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
                    onPressed: widget.procesando ? null : widget.onAceptar,
                    child: widget.procesando
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
          ] else if (s.isApproved) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9D174D),
                side: const BorderSide(color: Color(0xFFF48FB1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size.fromHeight(42),
              ),
              onPressed: widget.onContrato,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(
                s.hasContract ? 'Ver contrato' : 'Subir contrato',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _estado(AdoptionRequest s) {
    final Color fondo;
    final Color texto;
    final String etiqueta;
    final IconData icono;
    if (s.isApproved && s.hasContract) {
      fondo = const Color(0xFFECFDF5);
      texto = const Color(0xFF065F46);
      etiqueta = 'Aprobada';
      icono = Icons.check_circle_outline;
    } else if (s.isApproved) {
      fondo = const Color(0xFFFFFBEB);
      texto = const Color(0xFF92400E);
      etiqueta = 'Pendiente un paso - Falta subir contrato de adopción';
      icono = Icons.hourglass_top_rounded;
    } else if (s.isRejected) {
      fondo = const Color(0xFFFEF2F2);
      texto = const Color(0xFF991B1B);
      etiqueta = 'Rechazada';
      icono = Icons.cancel_outlined;
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
