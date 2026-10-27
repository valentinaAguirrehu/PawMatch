import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/enlaces.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/services/acuerdo_adopcion_pdf_service.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Solicitudes de adopción del usuario, con el mismo detalle que Apadrinamiento.
class MyAdoptionsScreen extends StatefulWidget {
  const MyAdoptionsScreen({super.key});

  @override
  State<MyAdoptionsScreen> createState() => _MyAdoptionsScreenState();
}

class _MyAdoptionsScreenState extends State<MyAdoptionsScreen> {
  late Future<List<AdoptionRequest>> _future = AdoptionService.listMine();

  @override
  void initState() {
    super.initState();
    AdoptionService.marcarLeidasUsuario();
  }

  Future<void> _recargar() async {
    setState(() => _future = AdoptionService.listMine());
    await _future.catchError((_) => <AdoptionRequest>[]);
  }

  String? _descargandoPdfId;
  String? _reenviandoCorreoId;

  Future<void> _reenviarVerificacion(AdoptionRequest s) async {
    setState(() => _reenviandoCorreoId = s.id);
    try {
      final res = await AdoptionService.reenviarVerificacionCorreo(s.id);
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
        const SnackBar(content: Text('Acta de adopción descargada exitosamente.')),
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
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await AdoptionService.fetchContract(solicitud.id);
      if (!mounted) return;
      Navigator.pop(context);

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
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text('Contrato de adopción - ${solicitud.petName}'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
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

  void _contactar(AdoptionRequest solicitud) {
    final numero = FundacionInfo.whatsappNumero.replaceAll(RegExp(r'\D'), '');
    final destino = numero.isNotEmpty ? numero : '573136177747';
    final mensaje =
        'Hola Fundación Maritza Arévalo, mi solicitud para adoptar a ${solicitud.petName} fue aprobada en Paw Match y quiero coordinar la entrega.';
    abrirEnlace(
      context,
      'https://wa.me/$destino?text=${Uri.encodeComponent(mensaje)}',
      nombre: 'WhatsApp de la Fundación',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis adopciones')),
      body: FutureBuilder<List<AdoptionRequest>>(
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

          final lista = snap.data ?? [];
          if (lista.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, size: 68, color: Colors.grey.shade400),
                    const SizedBox(height: 14),
                    Text(
                      'Aún no tienes solicitudes de adopción',
                      textAlign: TextAlign.center,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Explora las mascotas disponibles y pulsa «Adoptar» para enviar tu solicitud.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _recargar,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final s = lista[i];
                final color = switch (s.status) {
                  'aprobada' => s.hasContract ? Colors.green : Colors.amber.shade800,
                  'rechazada' => Colors.redAccent,
                  _ => Colors.orange,
                };
                final whatsapp = FundacionInfo.whatsappNumero.isNotEmpty
                    ? FundacionInfo.whatsappNumero
                    : '573136177747';

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: color.withValues(alpha: 0.35)),
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
                                color: s.isEmailConfirmed
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: s.isEmailConfirmed
                                      ? const Color(0xFF81C784)
                                      : const Color(0xFFFFD54F),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    s.isEmailConfirmed
                                        ? Icons.mark_email_read_rounded
                                        : Icons.mark_email_unread_rounded,
                                    size: 14,
                                    color: s.isEmailConfirmed
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFF57F17),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    s.emailStatusLabel,
                                    style: TextStyle(
                                      color: s.isEmailConfirmed
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFF57F17),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (!s.isEmailConfirmed) ...[
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

                            // Chip estado del proceso
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width - 68,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color),
                              ),
                              child: Text(
                                s.contractPending ? s.statusLabel : s.status.toUpperCase(),
                                textAlign: TextAlign.center,
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
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 94,
                                height: 94,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.rosa, width: 2.5),
                                ),
                                child: ClipOval(child: PetImage(url: s.petPhoto)),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                s.petName.isEmpty ? 'Mascota' : s.petName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
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
                                  s.petAgeLabel,
                                  style: const TextStyle(
                                    color: AppColors.rosa,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.petSummary,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 24),
                        if (s.isApproved && !s.hasContract) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.amber.shade400, width: 1.5),
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
                                        '¡Solicitud aprobada! Falta 1 paso',
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
                                  'Tu solicitud para adoptar a ${s.petName} fue aprobada.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade900),
                                ),
                                if (s.adoptionStartDateLabel != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '📅 Fecha oficial de inicio: ${s.adoptionStartDateLabel}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.amber.shade300),
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
                                          'Pendiente subir contrato de adopción. Debes esperar a que el administrador suba el contrato firmado. Cuando lo haga, podrás verlo y descargarlo aquí.',
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
                                if (s.hasObservations) ...[
                                  const SizedBox(height: 8),
                                  _CajaObservacion(
                                    titulo: 'Observaciones de la fundación:',
                                    texto: s.observations!,
                                    color: Colors.amber.shade900,
                                    borde: Colors.amber.shade300,
                                  ),
                                ],
                                if (s.applicantEmail.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _AvisoCorreo(correo: s.applicantEmail.trim()),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => _contactar(s),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text(
                              'Contactar por WhatsApp a la Fundación',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ] else if (s.isApproved) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.green.shade300, width: 1.5),
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
                                        '¡Contrato de adopción disponible!',
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
                                  '📅 Fecha oficial de inicio: ${s.adoptionStartDateLabel ?? 'Activo'}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                if (s.contractUploadedAtLabel != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Contrato cargado el ${s.contractUploadedAtLabel}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Contacto oficial: Fundación Maritza Arévalo (+$whatsapp)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                ),
                                if (s.hasObservations) ...[
                                  const SizedBox(height: 8),
                                  _CajaObservacion(
                                    titulo: 'Observaciones de la fundación:',
                                    texto: s.observations!,
                                    color: Colors.green,
                                    borde: Colors.green.shade200,
                                  ),
                                ],
                                if (s.applicantEmail.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _AvisoCorreo(correo: s.applicantEmail.trim()),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.rosa,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => _verContrato(s),
                            icon: const Icon(Icons.assignment_turned_in),
                            label: const Text(
                              'Ver y descargar contrato',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => _contactar(s),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text(
                              'Contactar por WhatsApp a la Fundación',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ] else if (s.isPending) ...[
                          Text(
                            'Tu solicitud fue enviada el ${s.requestedAtLabel}. El administrador de la fundación está revisando tus respuestas y tus datos.',
                            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                          ),
                        ] else if (s.isRejected) ...[
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
                                const Text(
                                  'Motivo u observaciones:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.hasObservations
                                      ? s.observations!
                                      : 'No se especificó motivo.',
                                ),
                                if (s.applicantEmail.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _AvisoCorreo(correo: s.applicantEmail.trim()),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Tus respuestas registradas:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
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
                                Text(
                                  respuesta.answer,
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
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
                            'Descargar acta de compromiso (PDF)',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          onPressed: _descargandoPdfId == s.id ? null : () => _descargarActaPdf(s),
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
}

class _CajaObservacion extends StatelessWidget {
  final String titulo;
  final String texto;
  final Color color;
  final Color borde;

  const _CajaObservacion({
    required this.titulo,
    required this.texto,
    required this.color,
    required this.borde,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rate_review_outlined, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                titulo,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(texto, style: const TextStyle(fontSize: 12.5, height: 1.35)),
        ],
      ),
    );
  }
}

class _AvisoCorreo extends StatelessWidget {
  final String correo;
  const _AvisoCorreo({required this.correo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Esta respuesta también se envió a $correo.',
              style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
