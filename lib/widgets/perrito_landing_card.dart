import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Tarjeta uniforme de un perrito para la pantalla de bienvenida.
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

  List<String> _etiquetas() {
    final rasgos = <(int, String)>[];
    for (final rasgo in rasgosMascota) {
      final valor = pet.personalidad[rasgo.clave];
      if (valor is! num) continue;
      final puntuacion = valor.toInt();
      if (puntuacion <= 2) {
        rasgos.add((3 - puntuacion, rasgo.minimoPara(pet.sexo)));
      } else if (puntuacion >= 4) {
        rasgos.add((puntuacion - 3, rasgo.maximoPara(pet.sexo)));
      }
    }
    rasgos.sort((a, b) => b.$1.compareTo(a.$1));
    final etiquetas = rasgos.take(3).map((rasgo) => rasgo.$2).toList();
    if (etiquetas.isNotEmpty) return etiquetas;

    return [
      if ((pet.sexo ?? '').trim().isNotEmpty) pet.sexo!.trim(),
      if ((pet.tamano ?? '').trim().isNotEmpty) pet.tamano!.trim(),
      if (pet.edad != null) pet.edadTexto,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final descripcion = (pet.descripcion ?? '').trim();
    final foto = (pet.foto ?? '').toLowerCase();
    final recorte = foto.endsWith('.png') || foto.endsWith('.webp');
    final etiquetas = _etiquetas();

    return Material(
      color: AppColors.rosaSuave,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: AppColors.rosa.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppColors.rosaClaro,
                    child: PetImage(
                      url: pet.foto,
                      fit: recorte ? BoxFit.contain : BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.rosa,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        paraAdopcion ? 'Para adoptar' : 'Para apadrinar',
                        style: tema.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.texto,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 72,
                        child: ClipRect(
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              for (final etiqueta in etiquetas)
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth * 0.88,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.rosaClaro,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      etiqueta,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tema.labelSmall?.copyWith(
                                        color: AppColors.texto,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Expanded(
                        child: Text(
                          descripcion.isEmpty
                              ? 'Un peludito esperando conocerte.'
                              : descripcion,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: tema.bodySmall?.copyWith(
                            height: 1.4,
                            color: AppColors.texto,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: onTap,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Conocer más',
                              style: tema.labelLarge?.copyWith(
                                color: AppColors.rosa,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
