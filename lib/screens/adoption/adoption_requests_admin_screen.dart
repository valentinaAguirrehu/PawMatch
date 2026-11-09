import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/screens/adoption/adoption_detail_admin_screen.dart';
import 'package:paw_match/services/adoption_service.dart';

/// Solicitudes de adopción en nuevas, aprobadas y rechazadas.
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
  void initState() {
    super.initState();
    AdoptionService.marcarLeidasAdmin();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _recargar() async {
    setState(() => _future = AdoptionService.listForAdmin());
    await _future.catchError((_) => <AdoptionRequest>[]);
  }

  void _abrirDetalle(AdoptionRequest solicitud) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdoptionDetailAdminScreen(
        request: solicitud,
        onCambioEstado: (nuevoEstado) {
          Navigator.pop(context);
          _recargar();
          if (nuevoEstado == 'aprobada') {
            _tabs.animateTo(1);
          } else if (nuevoEstado == 'rechazada') {
            _tabs.animateTo(2);
          }
        },
      ),
    );
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
            Tab(icon: Icon(Icons.check_circle_outline), text: 'Aprobadas'),
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
                      'Error al cargar solicitudes: ${snap.error}',
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
                vacio: 'No hay solicitudes nuevas pendientes por revisar.',
                onRefresh: _recargar,
                onTap: _abrirDetalle,
              ),
              _Lista(
                solicitudes: todas.where((s) => s.isApproved).toList(),
                vacio: 'No hay solicitudes de adopción aprobadas aún.',
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
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    vacio,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                ],
              ),
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
            'aprobada' => s.hasContract ? Colors.green : Colors.amber.shade800,
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.rosaClaro,
                          radius: 22,
                          child: Icon(Icons.favorite, color: AppColors.rosa),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.applicantFullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Desea adoptar a ${s.petName} (${s.petSpecies})',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color),
                          ),
                          child: Text(
                            s.status.toUpperCase(),
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: s.isEmailConfirmed
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(8),
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
                                size: 13,
                                color: s.isEmailConfirmed
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFF57F17),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s.emailStatusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: s.isEmailConfirmed
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFF57F17),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (s.isApproved) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: s.hasContract ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: s.hasContract ? Colors.green.shade200 : Colors.amber.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              s.hasContract ? Icons.verified : Icons.hourglass_top_rounded,
                              size: 14,
                              color: s.hasContract ? Colors.green.shade800 : Colors.amber.shade900,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                s.hasContract
                                    ? 'Contrato de adopción subido'
                                    : 'Falta subir contrato de adopción',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: s.hasContract
                                      ? Colors.green.shade800
                                      : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 20),
                    Text(
                      'Motivación:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.additionalInfo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '📅 ${s.requestedAtLabel}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
