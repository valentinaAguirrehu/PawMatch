import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/enlaces.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/pets/pet_detail_screen.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/widgets/pet_card.dart';

class MisApadrinamientosScreen extends StatefulWidget {
  const MisApadrinamientosScreen({super.key});

  @override
  State<MisApadrinamientosScreen> createState() =>
      _MisApadrinamientosScreenState();
}

class _MisApadrinamientosScreenState extends State<MisApadrinamientosScreen> {
  late Future<List<SolicitudApadrinamiento>> _future = _cargar();

  @override
  void initState() {
    super.initState();
    ApadrinamientoService.marcarLeidasUsuario();
  }

  Future<List<SolicitudApadrinamiento>> _cargar() =>
      ApadrinamientoService.listarMisSolicitudes();

  Future<void> _recargar() async {
    setState(() {
      _future = _cargar();
    });
    await _future.catchError((_) => <SolicitudApadrinamiento>[]);
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

          final lista = snap.data ?? [];
          if (lista.isEmpty) {
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

          return RefreshIndicator(
            onRefresh: _recargar,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final s = lista[i];
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
                        // Estado arriba a la derecha
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
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
                        ),
                        const SizedBox(height: 4),

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
