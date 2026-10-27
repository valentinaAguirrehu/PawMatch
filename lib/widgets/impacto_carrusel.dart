import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/widgets/pet_card.dart' show PetImage;

/// Carrusel que muestra las fotos de los perritos rescatados sin textos ni descripciones.
class ImpactoCarrusel extends StatefulWidget {
  final String titulo;
  final String? subtitulo;
  final VoidCallback? onVerMascotas;

  const ImpactoCarrusel({
    super.key,
    this.titulo = 'Todo lo que construyes cuando decides actuar',
    this.subtitulo = 'Caritas de felicidad de nuestros peluditos al recibir tu ayuda',
    this.onVerMascotas,
  });

  @override
  State<ImpactoCarrusel> createState() => _ImpactoCarruselState();
}

class _ImpactoCarruselState extends State<ImpactoCarrusel> {
  final _controller = PageController(viewportFraction: 0.82);
  int _pagina = 0;
  late Future<List<Pet>> _futureMascotas;

  // Fotos de respaldo si la base de datos o el backend no tienen fotos registradas
  static const _fotosRespaldo = [
    'assets/images/inicio/familia.jpg',
    'assets/images/inicio/juntos.jpg',
    'assets/images/inicio/fundacion_hero.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _futureMascotas = PetsService.listar().catchError((_) => <Pet>[]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.rosaSuave,
      child: Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: AppColors.texto,
                ),
              ),
            ),
            if (widget.subtitulo != null && widget.subtitulo!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  widget.subtitulo!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FutureBuilder<List<Pet>>(
              future: _futureMascotas,
              builder: (context, snapshot) {
                final mascotasConFoto = (snapshot.data ?? [])
                    .where((p) => p.foto != null && p.foto!.trim().isNotEmpty)
                    .toList();

                final List<String> fotos;
                if (mascotasConFoto.isNotEmpty) {
                  fotos = mascotasConFoto.map((p) => p.foto!).toList();
                } else {
                  fotos = _fotosRespaldo;
                }

                return Column(
                  children: [
                    SizedBox(
                      height: 250,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: fotos.length,
                        onPageChanged: (i) => setState(() => _pagina = i),
                        itemBuilder: (context, i) {
                          final foto = fotos[i];
                          return AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              double page = _pagina.toDouble();
                              if (_controller.hasClients &&
                                  _controller.position.haveDimensions) {
                                page = _controller.page ?? page;
                              }
                              final escala = 1 -
                                  (math.min(1.0, (page - i).abs()) * 0.08);
                              return Transform.scale(
                                scale: escala,
                                child: child,
                              );
                            },
                            child: GestureDetector(
                              onTap: widget.onVerMascotas,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.14),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: foto.startsWith('assets/')
                                      ? Image.asset(
                                          foto,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        )
                                      : PetImage(
                                          url: foto,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < fotos.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _pagina ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _pagina
                                  ? AppColors.rosa
                                  : AppColors.bordeRosa,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
