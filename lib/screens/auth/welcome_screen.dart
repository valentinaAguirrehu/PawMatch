import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/logo_paw.dart';

import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _abrir(BuildContext context, Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final boton = texto.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    return Scaffold(
      backgroundColor: AppColors.blanco,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Encabezado(),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '¡Hagamos un match inolvidable juntos!',
                            style: texto.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.texto,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Adopta o apadrina a un peludito de la ${FundacionInfo.nombre} y haz la diferencia hoy.',
                            style: texto.bodyMedium?.copyWith(
                              color: AppColors.texto.withValues(alpha: 0.62),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const _Beneficio(
                            icono: FeatureIcon.adopcion(color: AppColors.rosa),
                            titulo: 'Adopción',
                            detalle:
                                'Encuentra al peludito ideal para ti y dale la oportunidad de tener un hogar lleno de amor.',
                          ),
                          const _Beneficio(
                            icono: FeatureIcon.apadrinamiento(
                              color: AppColors.rosa,
                            ),
                            titulo: 'Apadrinamiento',
                            detalle:
                                'Transforma su vida mientras espera una familia. Tu apoyo marca toda la diferencia.',
                          ),
                          const _Beneficio(
                            icono: FeatureIcon.compatibilidad(
                              color: AppColors.rosa,
                            ),
                            titulo: 'Compatibilidad',
                            detalle:
                                'Descubre qué peludito encaja perfecto con tu estilo de vida y personalidad.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    28,
                    12,
                    28,
                    20 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _abrir(context, const LoginScreen()),
                        icon: const FeatureIcon.iniciarSesion(),
                        label: const Text('Iniciar sesión'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          textStyle: boton,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _abrir(context, const RegisterScreen()),
                        icon: const FeatureIcon.registrarse(),
                        label: const Text('Registrarse'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          textStyle: boton,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.rosa,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.blanco,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.texto.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const LogoPaw(tamano: 92),
              ),
              const SizedBox(height: 18),
              Text(
                'Paw Match',
                style: texto.headlineMedium?.copyWith(
                  color: AppColors.blanco,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Encuentra a tu compañero ideal',
                textAlign: TextAlign.center,
                style: texto.titleMedium?.copyWith(
                  color: AppColors.blanco.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Beneficio extends StatelessWidget {
  final Widget icono;
  final String titulo;
  final String detalle;

  const _Beneficio({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.rosaSuave,
              borderRadius: BorderRadius.circular(14),
            ),
            child: icono,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: texto.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: texto.bodyMedium?.copyWith(
                    color: AppColors.texto.withValues(alpha: 0.62),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
