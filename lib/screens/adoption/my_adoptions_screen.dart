import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/enlaces.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/services/adoption_service.dart';
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
                  'aprobada' => Colors.green,
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
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
                              s.status.toUpperCase(),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
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
                        if (s.isApproved) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.stars, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text(
                                      '¡Adopción aprobada!',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '📅 Fecha oficial de inicio: ${s.adoptionStartDateLabel ?? 'Activo'}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
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
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 16, color: Colors.orange),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Debes contactar a la fundación por WhatsApp para coordinar la entrega y los últimos requisitos.',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
