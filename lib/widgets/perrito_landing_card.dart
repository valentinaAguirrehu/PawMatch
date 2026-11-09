import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Tarjeta compacta, moderna y uniforme de un perrito para la pantalla de bienvenida.
/// Muestra únicamente: Fotografía superior, Nombre, Sexo y Edad.
class PerritoLandingCard extends StatelessWidget {
  final Pet pet;
  final bool paraAdopcion;
  final VoidCallback onTap;

  const PerritoLandingCard({
    super.key,
    required this.pet,
    required this.paraAdopcion,
    required this.onTap,
  });

  String _sexoTexto() {
    final s = (pet.sexo ?? '').trim();
    if (s.isEmpty) return 'Peludito';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final foto = (pet.foto ?? '').toLowerCase();
    final recorte = foto.endsWith('.png') || foto.endsWith('.webp');
    final sexo = _sexoTexto();
    final esHembra = sexo.toLowerCase().startsWith('h');
    final edad = pet.edadTexto.trim().isNotEmpty ? pet.edadTexto.trim() : 'Joven';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.bordeRosa.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fotografía superior con proporción uniforme
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: AppColors.rosaSuave,
                      child: PetImage(
                        url: pet.foto,
                        fit: recorte ? BoxFit.contain : BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.rosa.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          paraAdopcion ? 'Adopción' : 'Apadrinar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Información compacta inferior: únicamente Nombre, Sexo y Edad
              LayoutBuilder(
                builder: (context, constraints) {
                  final muyEstrecho = constraints.maxWidth < 150;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      muyEstrecho ? 8 : 12,
                      muyEstrecho ? 8 : 10,
                      muyEstrecho ? 8 : 12,
                      muyEstrecho ? 9 : 11,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pet.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            color: AppColors.texto,
                            fontSize: muyEstrecho ? 14.5 : 16.5,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: muyEstrecho ? 6 : 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.rosaSuave,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.bordeRosa.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    esHembra ? Icons.female_rounded : Icons.male_rounded,
                                    size: muyEstrecho ? 12 : 13.5,
                                    color: AppColors.rosa,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    sexo,
                                    style: TextStyle(
                                      color: AppColors.rosa,
                                      fontWeight: FontWeight.w700,
                                      fontSize: muyEstrecho ? 11 : 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: muyEstrecho ? 6 : 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDF4F8),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.bordeRosa.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                edad,
                                style: TextStyle(
                                  color: AppColors.texto.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w700,
                                  fontSize: muyEstrecho ? 11 : 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
