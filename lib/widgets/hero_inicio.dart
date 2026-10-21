import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/logo_paw.dart';

/// Encabezado del inicio: foto, saludo y accesos a adopciones y apadrinamientos.
class HeroInicio extends StatelessWidget {
  final String nombre;
  final VoidCallback onCerrarSesion;
  final VoidCallback onVerMascotas;
  final VoidCallback onAdopciones;
  final VoidCallback onApadrinamientos;

  const HeroInicio({
    super.key,
    required this.nombre,
    required this.onCerrarSesion,
    required this.onVerMascotas,
    required this.onAdopciones,
    required this.onApadrinamientos,
  });

  @override
  Widget build(BuildContext context) {
    final alto = (MediaQuery.of(context).size.height * 0.58)
        .clamp(420.0, 500.0)
        .toDouble();

    return SizedBox(
      height: alto,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onVerMascotas,
              child: Image.asset(
                'assets/images/inicio/abrazo.jpg',
                fit: BoxFit.cover,
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.28, 0.55, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BarraSuperior(
                      nombre: nombre,
                      onCerrarSesion: onCerrarSesion,
                      onVerMascotas: onVerMascotas,
                      onAdopciones: onAdopciones,
                      onApadrinamientos: onApadrinamientos,
                    ),
                    const Spacer(),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, (1 - v) * 24),
                          child: child,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Un hogar para cada huella, un futuro para cada vida.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Descubre el poder de transformar historias. A través de la adopción y el apadrinamiento, le das una segunda oportunidad a un animal que solo busca amar y ser amado.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarraSuperior extends StatelessWidget {
  final String nombre;
  final VoidCallback onCerrarSesion;
  final VoidCallback onVerMascotas;
  final VoidCallback onAdopciones;
  final VoidCallback onApadrinamientos;

  const _BarraSuperior({
    required this.nombre,
    required this.onCerrarSesion,
    required this.onVerMascotas,
    required this.onAdopciones,
    required this.onApadrinamientos,
  });

  void _mostrarMenuSolicitudes(BuildContext context) {
    final bool esAdmin = Session.esAdmin;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  esAdmin ? Icons.inbox_outlined : Icons.assignment_outlined,
                  color: AppColors.rosa,
                ),
                const SizedBox(width: 8),
                Text(
                  esAdmin ? 'Solicitudes Recibidas' : 'Mis Solicitudes',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              leading: CircleAvatar(
                backgroundColor: AppColors.rosaClaro,
                child: const Icon(Icons.volunteer_activism, color: AppColors.rosa),
              ),
              title: Text(
                esAdmin ? 'Solicitudes de Apadrinamiento' : 'Mis Apadrinamientos',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                esAdmin
                    ? 'Revisar solicitudes enviadas por usuarios'
                    : 'Consulta estado de apadrinamiento y contratos',
              ),
              trailing: ValueListenableBuilder<int>(
                valueListenable: esAdmin
                    ? ApadrinamientoService.noLeidasAdmin
                    : ApadrinamientoService.noLeidasUsuario,
                builder: (context, count, child) => count > 0
                    ? Badge(label: Text('$count'), backgroundColor: Colors.redAccent)
                    : const Icon(Icons.chevron_right),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onApadrinamientos();
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              leading: CircleAvatar(
                backgroundColor: AppColors.rosaClaro,
                child: const Icon(Icons.pets, color: AppColors.rosa),
              ),
              title: Text(
                esAdmin ? 'Solicitudes de Adopción' : 'Mis Adopciones',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                esAdmin
                    ? 'Revisar solicitudes enviadas por usuarios'
                    : 'Consulta si tu adopción fue aprobada',
              ),
              trailing: ValueListenableBuilder<int>(
                valueListenable: esAdmin
                    ? AdoptionService.noLeidasAdmin
                    : AdoptionService.noLeidasUsuario,
                builder: (context, count, child) => count > 0
                    ? Badge(label: Text('$count'), backgroundColor: Colors.redAccent)
                    : const Icon(Icons.chevron_right),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onAdopciones();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const LogoPaw(tamano: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              'Hola, $nombre',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Ver Mascotas',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            foregroundColor: AppColors.rosa,
          ),
          onPressed: onVerMascotas,
          icon: const Icon(Icons.pets, color: AppColors.rosa, size: 21),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: Session.esAdmin
              ? 'Solicitudes recibidas y notificaciones'
              : 'Mis solicitudes y notificaciones',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            foregroundColor: AppColors.rosa,
          ),
          onPressed: () => _mostrarMenuSolicitudes(context),
          icon: AnimatedBuilder(
            animation: Listenable.merge([
              Session.esAdmin
                  ? ApadrinamientoService.noLeidasAdmin
                  : ApadrinamientoService.noLeidasUsuario,
              Session.esAdmin
                  ? AdoptionService.noLeidasAdmin
                  : AdoptionService.noLeidasUsuario,
            ]),
            builder: (context, child) {
              final total = Session.esAdmin
                  ? (ApadrinamientoService.noLeidasAdmin.value +
                      AdoptionService.noLeidasAdmin.value)
                  : (ApadrinamientoService.noLeidasUsuario.value +
                      AdoptionService.noLeidasUsuario.value);
              return Badge(
                isLabelVisible: total > 0,
                label: Text('$total'),
                backgroundColor: Colors.redAccent,
                textColor: Colors.white,
                child: const Icon(Icons.notifications_outlined, color: AppColors.rosa, size: 22),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Cerrar sesión',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            foregroundColor: AppColors.rosa,
          ),
          onPressed: onCerrarSesion,
          icon: const FeatureIcon.cerrarSesion(color: AppColors.rosa),
        ),
      ],
    );
  }
}
