import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/enlaces.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Lista de solicitudes de adopción enviadas por el usuario en sesión.
class MyAdoptionsScreen extends StatefulWidget {
  const MyAdoptionsScreen({super.key});

  @override
  State<MyAdoptionsScreen> createState() => _MyAdoptionsScreenState();
}

class _MyAdoptionsScreenState extends State<MyAdoptionsScreen> {
  late Future<List<AdoptionRequest>> _future = AdoptionService.listMine();

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
            return _ErrorCarga(
              mensaje: 'No se pudieron cargar tus solicitudes.',
              onReintentar: _recargar,
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
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Abre el perfil de un perrito y pulsa Adoptar para enviar tu solicitud.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: Colors.black54),
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
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) => _TarjetaSolicitud(
                solicitud: lista[i],
                onContactar: () => _contactar(lista[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaSolicitud extends StatelessWidget {
  final AdoptionRequest solicitud;
  final VoidCallback onContactar;

  const _TarjetaSolicitud({required this.solicitud, required this.onContactar});

  Color get _color => switch (solicitud.status) {
    'aprobada' => Colors.green,
    'rechazada' => Colors.redAccent,
    _ => Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 72,
                    height: 72,
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
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(s.petSummary, style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 6),
                      Text(
                        'Enviada el ${s.requestedAtLabel}',
                        style: const TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
                _EstadoChip(texto: s.statusLabel, color: _color),
              ],
            ),
            if (s.isApproved) ...[
              const SizedBox(height: 12),
              const Text(
                'Tu solicitud fue aprobada. Contacta a la fundación para coordinar la entrega.',
                style: TextStyle(height: 1.35),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: onContactar,
                icon: const Icon(Icons.chat),
                label: const Text('Contactar por WhatsApp'),
              ),
            ],
            if (s.isPending && s.petAdoptionStatus == 'adoptado')
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Esta mascota ya fue adoptada. La fundación aún puede cerrar tu solicitud.',
                  style: TextStyle(color: Colors.black54, height: 1.35),
                ),
              ),
            if (s.isRejected)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'La fundación no aprobó esta solicitud. Si la mascota sigue disponible, puedes enviar una nueva desde su perfil.',
                  style: TextStyle(color: Colors.black54, height: 1.35),
                ),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Ver respuestas enviadas',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              children: [
                for (final respuesta in s.answers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
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
                          const SizedBox(height: 2),
                          Text(respuesta.answer),
                        ],
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

class _EstadoChip extends StatelessWidget {
  final String texto;
  final Color color;

  const _EstadoChip({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _ErrorCarga({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
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
