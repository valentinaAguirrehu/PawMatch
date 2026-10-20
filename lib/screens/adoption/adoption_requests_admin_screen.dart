import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/screens/adoption/adoption_detail_admin_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Solicitudes de adopción separadas en nuevas, aceptadas y rechazadas.
class AdoptionRequestsAdminScreen extends StatefulWidget {
  const AdoptionRequestsAdminScreen({super.key});

  @override
  State<AdoptionRequestsAdminScreen> createState() =>
      _AdoptionRequestsAdminScreenState();
}

class _AdoptionRequestsAdminScreenState extends State<AdoptionRequestsAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late Future<List<AdoptionRequest>> _future = AdoptionService.listForAdmin();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _recargar() async {
    setState(() => _future = AdoptionService.listForAdmin());
    await _future.catchError((_) => <AdoptionRequest>[]);
  }

  Future<void> _abrirDetalle(AdoptionRequest solicitud) async {
    final resultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AdoptionDetailAdminScreen(request: solicitud),
      ),
    );
    if (!mounted || resultado == null) return;
    final aprobada = resultado == 'aprobada';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: aprobada ? Colors.green : Colors.orange,
        content: Text(
          aprobada
              ? 'Solicitud aprobada. La mascota quedó como adoptada.'
              : 'La solicitud fue rechazada.',
        ),
      ),
    );
    _tabs.animateTo(aprobada ? 1 : 2);
    await _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de adopción'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.rosa,
          unselectedLabelColor: Colors.black54,
          indicatorColor: AppColors.rosa,
          tabs: const [
            Tab(icon: Icon(Icons.mark_email_unread_outlined), text: 'Nuevas'),
            Tab(icon: Icon(Icons.check_circle_outline), text: 'Aceptadas'),
            Tab(icon: Icon(Icons.cancel_outlined), text: 'Rechazadas'),
          ],
        ),
      ),
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
          return TabBarView(
            controller: _tabs,
            children: [
              _Lista(
                solicitudes: todas.where((s) => s.isPending).toList(),
                vacio: 'No hay solicitudes nuevas por revisar.',
                onRefresh: _recargar,
                onTap: _abrirDetalle,
              ),
              _Lista(
                solicitudes: todas.where((s) => s.isApproved).toList(),
                vacio: 'No hay solicitudes aceptadas.',
                onRefresh: _recargar,
                onTap: _abrirDetalle,
              ),
              _Lista(
                solicitudes: todas.where((s) => s.isRejected).toList(),
                vacio: 'No hay solicitudes rechazadas.',
                onRefresh: _recargar,
                onTap: _abrirDetalle,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  final List<AdoptionRequest> solicitudes;
  final String vacio;
  final RefreshCallback onRefresh;
  final ValueChanged<AdoptionRequest> onTap;

  const _Lista({
    required this.solicitudes,
    required this.vacio,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (solicitudes.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              vacio,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: solicitudes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final s = solicitudes[i];
          final color = switch (s.status) {
            'aprobada' => Colors.green,
            'rechazada' => Colors.redAccent,
            _ => Colors.orange,
          };
          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onTap(s),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: PetImage(url: s.petPhoto),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.applicantFullName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Quiere adoptar a ${s.petName}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${s.housingType.isEmpty ? 'Vivienda sin indicar' : s.housingType} · ${s.requestedAtLabel}',
                            style: const TextStyle(fontSize: 12, color: Colors.black45),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color),
                          ),
                          child: Text(
                            s.statusLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.black38),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
