import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/adoption/my_adoptions_screen.dart';
import 'package:paw_match/screens/apadrinamiento/mis_apadrinamientos_screen.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/acordeon_inicio.dart';
import 'package:paw_match/widgets/cta_inicio.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/fila_punto.dart';
import 'package:paw_match/widgets/foto_tarjeta.dart';
import 'package:paw_match/widgets/hero_inicio.dart';
import 'package:paw_match/widgets/impacto_carrusel.dart';
import 'package:paw_match/widgets/manifiesto_inicio.dart';
import 'package:paw_match/widgets/punto_inicio.dart';
import 'package:paw_match/widgets/seccion_inicio.dart';

/// Pestaña "Inicio": hero con foto, secciones interactivas y llamado final.
class HomeTab extends StatefulWidget {
  final VoidCallback onVerMascotas;
  final VoidCallback onVerMatch;

  const HomeTab({
    super.key,
    required this.onVerMascotas,
    required this.onVerMatch,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  void _abrirAdopciones() {
    AdoptionService.marcarLeidasUsuario();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyAdoptionsScreen()),
    );
  }

  void _abrirApadrinamientos() {
    ApadrinamientoService.marcarLeidasUsuario();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MisApadrinamientosScreen()),
    );
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (confirmar && mounted) {
      ApadrinamientoService.detenerMonitoreo();
      AdoptionService.detenerMonitoreo();
      Session.cerrar();
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.rosaClaro,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroInicio(
            nombre: Session.nombre,
            onCerrarSesion: _confirmarCerrarSesion,
            onVerMascotas: widget.onVerMascotas,
            onAdopciones: _abrirAdopciones,
            onApadrinamientos: _abrirApadrinamientos,
          ),
          SeccionInicio(
            titulo: 'Adoptar es Dar una Segunda Oportunidad',
            texto:
                'Adoptar no es solo llevar una mascota a casa; es salvar dos vidas: la del animal que acoges con amor y la del próximo rescatado que podrá ocupar su lugar en el refugio.',
            hijos: [
              FotoTarjeta(
                asset: 'assets/images/inicio/familia.jpg',
                alto: 220,
                pie: 'Toca para conocer a tu alma gemela',
                onTap: widget.onVerMatch,
              ),
              const SizedBox(height: 16),
              const AcordeonInicio(
                items: [
                  PuntoInicio(
                    icono: Icons.favorite_rounded,
                    titulo: 'Amor incondicional y gratitud',
                    texto:
                        'Los animales rescatados desarrollan un vínculo único y profundo con quienes les abren las puertas de su hogar.',
                  ),
                  PuntoInicio(
                    icono: Icons.loop_rounded,
                    titulo: 'Rompemos el ciclo del abandono',
                    texto:
                        'Al elegir la adopción frente a la compra, desincentivas el comercio e impulsas el bienestar colectivo.',
                  ),
                  PuntoInicio(
                    icono: Icons.home_rounded,
                    titulo: 'Un nuevo miembro en tu familia',
                    texto:
                        'Adoptar llena tu vida de alegría, compañía sincera y momentos inolvidables.',
                  ),
                ],
              ),
            ],
          ),
          SeccionInicio(
            fondo: AppColors.rosaSuave,
            curvaSuperior: true,
            titulo:
                '¿Qué significa Apadrinar y por qué tu ayuda transforma vidas?',
            texto:
                'No todos pueden adoptar en este momento por espacio, tiempo o estilo de vida, ¡y está bien! Apadrinar es ser el ángel guardián de un animal rescatado mientras encuentra un hogar definitivo o pasa sus días en el refugio.',
            hijos: [
              const FotoTarjeta(
                asset: 'assets/images/inicio/juntos.jpg',
                alto: 220,
              ),
              const SizedBox(height: 18),
              const FilaPunto(
                icono: Icons.restaurant_rounded,
                titulo: 'Tu aporte mensual asegura',
                texto:
                    'Su alimentación diaria, atención médica, vacunas, tratamientos y un espacio seguro.',
              ),
              const FilaPunto(
                icono: Icons.photo_camera_rounded,
                titulo: 'Un vínculo real',
                texto:
                    'Recibes noticias periódicas, fotografías y actualizaciones del estado y progreso de tu ahijado.',
              ),
              const FilaPunto(
                icono: Icons.favorite_border_rounded,
                titulo: 'Amor a la distancia',
                texto:
                    'Puedes visitarlo, brindarle cariño y acompañarlo en su proceso de recuperación y socialización.',
                ultimo: true,
              ),
            ],
          ),
          const ImpactoCarrusel(
            titulo: 'Todo lo que construyes cuando decides actuar',
            items: [
              PuntoInicio(
                icono: Icons.healing_rounded,
                titulo: 'Sanamos heridas físicas y emocionales',
                texto:
                    'Tu apoyo permite rehabilitar animales con traumas, desnutrición o enfermedades, devolviéndoles la confianza y la alegría.',
              ),
              PuntoInicio(
                icono: Icons.groups_rounded,
                titulo: 'Fortaleces la labor comunitaria',
                texto:
                    'Respaldas a los refugios y rescatistas para que continúen salvando vidas, cubriendo gastos veterinarios y manteniendo instalaciones dignas.',
              ),
              PuntoInicio(
                icono: Icons.spa_rounded,
                titulo: 'Creas conciencia ambiental y social',
                texto:
                    'Fomentas el control ético de la población animal a través de la esterilización y promueves una sociedad más empática.',
              ),
            ],
          ),
          const ManifiestoInicio(),
          CtaInicio(
            onVerMascotas: widget.onVerMascotas,
            onVerMatch: widget.onVerMatch,
          ),
        ],
      ),
    );
  }
}
