import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/banner_hero_inicio.dart';
import 'package:paw_match/widgets/cabecera_inicio.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/impacto_carrusel.dart';
import 'package:paw_match/widgets/seccion_noticias_fundacion.dart';
import 'package:paw_match/widgets/tarjetas_destacadas_inicio.dart';

/// Pestaña "Inicio": cabecera, banner hero institucional, tarjetas destacadas, noticias e impacto.
class HomeTab extends StatefulWidget {
  final VoidCallback onVerMascotas;
  final VoidCallback? onVerMatch;

  const HomeTab({
    super.key,
    required this.onVerMascotas,
    this.onVerMatch,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  void initState() {
    super.initState();
    PetsService.iniciarMonitoreo();
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (confirmar && mounted) {
      PetsService.detenerMonitoreo();
      ApadrinamientoService.detenerMonitoreo();
      AdoptionService.detenerMonitoreo();
      Session.cerrar();
      Navegacion.ir(context, const WelcomeScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.rosaClaro,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. Cabecera con saludo al usuario y botón para cerrar sesión
          CabeceraInicio(
            nombre: Session.nombre,
            onCerrarSesion: _confirmarCerrarSesion,
          ),

          // 2. Banner Hero con foto de fondo (fundacion_hero.jpg)
          const BannerHeroInicio(),

          // 3. Tarjetas destacadas sobre fondo claro (ambos botones llevan a Mascotas)
          TarjetasDestacadasInicio(
            onAdopta: widget.onVerMascotas,
            onApadrina: widget.onVerMascotas,
          ),

          // 4. Sección de noticias institucionales de la fundación
          const SeccionNoticiasFundacion(),

          const SizedBox(height: 16),

          // 5. Carrusel de fotos de perritos rescatados sin descripciones de texto
          ImpactoCarrusel(
            titulo: 'Todo lo que construyes cuando decides actuar',
            subtitulo: 'Caritas de felicidad de nuestros peluditos al recibir tu ayuda',
            onVerMascotas: widget.onVerMascotas,
          ),

          const SizedBox(height: 14),

          // 6. Pie de página institucional
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pets,
                      size: 14,
                      color: AppColors.rosa.withValues(alpha: 0.65),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Paw Match',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.texto.withValues(alpha: 0.7),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Todos los derechos reservados © Fundación Maritza Arévalo 2026',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.texto.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}