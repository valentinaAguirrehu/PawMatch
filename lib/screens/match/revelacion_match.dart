import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/home/menu_screen.dart';
import 'package:paw_match/services/match_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Pantalla de sorpresa justo después de guardar la entrevista.
/// Primero simula el cálculo y luego revela al peludito más compatible.
class RevelacionMatchScreen extends StatefulWidget {
  const RevelacionMatchScreen({super.key});

  @override
  State<RevelacionMatchScreen> createState() => _RevelacionMatchScreenState();
}

class _RevelacionMatchScreenState extends State<RevelacionMatchScreen>
    with TickerProviderStateMixin {
  static const _esperaMinima = Duration(milliseconds: 2600);

  late final AnimationController _latido;
  late final AnimationController _brillo;
  late final AnimationController _entrada;

  CompatibilidadMatch? _destacado;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _latido = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    )..repeat();
    _brillo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _calcular();
  }

  @override
  void dispose() {
    _latido.dispose();
    _brillo.dispose();
    _entrada.dispose();
    super.dispose();
  }

  Future<void> _calcular() async {
    final inicio = DateTime.now();
    CompatibilidadMatch? mejor;
    try {
      final ranking = await MatchService.mejores();
      if (ranking.mejores.isNotEmpty) mejor = ranking.mejores.first;
    } catch (_) {}

    final restante = _esperaMinima - DateTime.now().difference(inicio);
    if (restante > Duration.zero) {
      await Future<void>.delayed(restante);
    }
    if (!mounted) return;
    if (mejor == null) {
      _abrirResultados();
      return;
    }
    setState(() {
      _destacado = mejor;
      _listo = true;
    });
    _entrada.forward();
  }

  void _abrirResultados() {
    Navegacion.ir(
      context,
      MenuScreen(indiceInicial: MenuScreen.indiceMatch),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFD0E4),
              Color(0xFFFFF4F8),
              Color(0xFFFFFBFC),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _brillo,
                builder: (context, _) => CustomPaint(
                  painter: _Destellos(progreso: _brillo.value),
                ),
              ),
            ),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: _listo && _destacado != null
                    ? _revelacion(_destacado!)
                    : _calculando(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calculando() {
    return Center(
      key: const ValueKey('calculando'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _latido,
            builder: (context, child) {
              return Transform.scale(
                scale: _escalaLatido(_latido.value),
                child: child,
              );
            },
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.rosa,
              size: 84,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Calculando tu compatibilidad…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.texto,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              'Estamos buscando al peludito que mejor conecta con tu corazón.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.35, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _revelacion(CompatibilidadMatch match) {
    final foto = (match.mascota.foto ?? '').toLowerCase();
    final recorte = foto.endsWith('.png') || foto.endsWith('.webp');
    final curva = CurvedAnimation(parent: _entrada, curve: Curves.easeOutBack);

    return FadeTransition(
      key: const ValueKey('revelacion'),
      opacity: _entrada,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          children: [
            const Spacer(),
            ScaleTransition(
              scale: Tween<double>(begin: 0.86, end: 1).animate(curva),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.rosaClaro,
                  border: Border.all(color: Colors.white, width: 6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.rosa.withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: PetImage(
                    url: match.mascota.foto,
                    fit: recorte ? BoxFit.contain : BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              match.mascota.nombre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.texto,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _abrirResultados,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosa,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('¡Deseo conocer más sobre mi nuevo amigo!'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _escalaLatido(double t) {
    if (t < 0.16) return 1 + 0.16 * (t / 0.16);
    if (t < 0.30) return 1.16 - 0.16 * ((t - 0.16) / 0.14);
    if (t < 0.46) return 1 + 0.08 * ((t - 0.30) / 0.16);
    if (t < 0.62) return 1.08 - 0.08 * ((t - 0.46) / 0.16);
    return 1;
  }
}

class _Destellos extends CustomPainter {
  final double progreso;

  const _Destellos({required this.progreso});

  static const _puntos = <(double, double, double)>[
    (0.12, 0.18, 0.0),
    (0.82, 0.14, 0.2),
    (0.22, 0.72, 0.45),
    (0.88, 0.68, 0.15),
    (0.50, 0.10, 0.6),
    (0.08, 0.46, 0.35),
    (0.70, 0.40, 0.8),
    (0.40, 0.86, 0.55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final punto in _puntos) {
      final fase = (progreso + punto.$3) % 1;
      final sube = math.sin(fase * math.pi);
      final centro = Offset(
        size.width * punto.$1,
        size.height * punto.$2 - 18 * sube,
      );
      final corazon = fase > 0.55;
      final icono = corazon ? Icons.favorite_rounded : Icons.auto_awesome_rounded;
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icono.codePoint),
          style: TextStyle(
            fontSize: corazon ? 22 : 18,
            fontFamily: icono.fontFamily,
            package: icono.fontPackage,
            color: AppColors.rosa.withValues(alpha: 0.18 + 0.55 * sube),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, centro - Offset(painter.width / 2, painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _Destellos oldDelegate) =>
      oldDelegate.progreso != progreso;
}
