import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/screens/adoption/adoption_requests_admin_screen.dart';
import 'package:paw_match/screens/adoption/my_adoptions_screen.dart';
import 'package:paw_match/screens/apadrinamiento/apadrinamiento_admin_screen.dart';
import 'package:paw_match/screens/apadrinamiento/mis_apadrinamientos_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';

/// Pestaña de Notificaciones y Solicitudes accesible desde el menú inferior.
class NotificationsTab extends StatelessWidget {
  final VoidCallback onCerrarSesion;

  const NotificationsTab({super.key, required this.onCerrarSesion});

  void _abrirAdopciones(BuildContext context) {
    if (Session.esAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdoptionRequestsAdminScreen()),
      );
    } else {
      AdoptionService.marcarLeidasUsuario();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyAdoptionsScreen()),
      );
    }
  }

  void _abrirApadrinamientos(BuildContext context) {
    if (Session.esAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ApadrinamientoAdminScreen()),
      );
    } else {
      ApadrinamientoService.marcarLeidasUsuario();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MisApadrinamientosScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esAdmin = Session.esAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F9),
      body: SafeArea(
        child: Column(
          children: [
            BarraSuperior(
              iconoTitulo: Icons.notifications_rounded,
              titulo: 'Mis Notificaciones',
              onCerrarSesion: onCerrarSesion,
            ),
            Expanded(
              child: AnimatedBuilder(
          animation: Listenable.merge([
            esAdmin
                ? ApadrinamientoService.noLeidasAdmin
                : ApadrinamientoService.noLeidasUsuario,
            esAdmin
                ? AdoptionService.noLeidasAdmin
                : AdoptionService.noLeidasUsuario,
          ]),
          builder: (context, _) {
            final noLeidasAdop = esAdmin
                ? AdoptionService.noLeidasAdmin.value
                : AdoptionService.noLeidasUsuario.value;
            final noLeidasApad = esAdmin
                ? ApadrinamientoService.noLeidasAdmin.value
                : ApadrinamientoService.noLeidasUsuario.value;
            final total = noLeidasAdop + noLeidasApad;

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
              children: [
                Text(
                  total > 0
                      ? 'Tienes $total notificación${total > 1 ? 'es' : ''} pendiente${total > 1 ? 's' : ''}'
                      : 'Al día con tus notificaciones',
                  style: TextStyle(
                    fontSize: 13,
                    color: total > 0 ? AppColors.rosa : Colors.grey.shade600,
                    fontWeight: total > 0 ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 16),

                // Tarjeta 1: Adopciones
                _TarjetaNotificacion(
                  titulo: esAdmin ? 'Solicitudes de Adopción' : 'Mis Adopciones',
                  subtitulo: esAdmin
                      ? 'Revisa solicitudes y sube el contrato de las adopciones aprobadas.'
                      : 'Consulta el estado de tu adopción, el contrato oficial y las observaciones.',
                  icono: Icons.pets_rounded,
                  contador: noLeidasAdop,
                  colorIcono: AppColors.rosa,
                  onTap: () => _abrirAdopciones(context),
                ),

                const SizedBox(height: 14),

                // Tarjeta 2: Apadrinamientos
                _TarjetaNotificacion(
                  titulo: esAdmin
                      ? 'Solicitudes de Apadrinamiento'
                      : 'Mis Apadrinamientos',
                  subtitulo: esAdmin
                      ? 'Revisa aportes, motivaciones y genera contratos de apadrinamiento.'
                      : 'Revisa tus mascotas apadrinadas, estado y contratos oficiales.',
                  icono: Icons.volunteer_activism_rounded,
                  contador: noLeidasApad,
                  colorIcono: const Color(0xFFE91E63),
                  onTap: () => _abrirApadrinamientos(context),
                ),

                const SizedBox(height: 26),

                // Tarjeta informativa de la fundación
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.rosaSuave,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: AppColors.rosa,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '¿Tienes dudas sobre un proceso?',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Comunícate directamente con ${FundacionInfo.nombre}.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaNotificacion extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final int contador;
  final Color colorIcono;
  final VoidCallback onTap;

  const _TarjetaNotificacion({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.contador,
    required this.colorIcono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: contador > 0
                  ? AppColors.rosa.withValues(alpha: 0.4)
                  : Colors.grey.shade200,
              width: contador > 0 ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: contador > 0
                    ? AppColors.rosa.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorIcono.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(icono, color: colorIcono, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titulo,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (contador > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$contador',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
