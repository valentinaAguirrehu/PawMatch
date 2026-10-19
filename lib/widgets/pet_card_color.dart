import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/widgets/pet_card.dart'; // PetImage

/// Tarjeta grande con fondo de color para el carrusel del inicio.
class PetCardColor extends StatelessWidget {
  final Pet pet;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onAdoptar;
  final VoidCallback? onApadrinar;

  const PetCardColor({
    super.key,
    required this.pet,
    required this.color,
    required this.onTap,
    required this.onAdoptar,
    this.onApadrinar,
  });

  bool get _esApadrinada =>
      pet.estadoApadrinamiento.trim().toLowerCase() == 'apadrinado';

  String get _etiquetaApadrinada {
    final s = pet.sexo?.trim().toLowerCase();
    return s == 'macho' ? 'Apadrinado' : 'Apadrinada';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final raza = pet.raza;
    final datos = [
      if (raza != null && raza.isNotEmpty) raza,
      if (pet.edad != null) pet.edadTexto,
    ].join(' · ');

    return SizedBox(
      width: 230,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen con badge "Apadrinada" arriba si aplica
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: PetImage(url: pet.foto),
                        ),
                      ),
                      if (_esApadrinada)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.stars,
                                  size: 15,
                                  color: AppColors.rosa,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _etiquetaApadrinada,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.rosa,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Nombre y datos
                Text(
                  pet.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.texto,
                  ),
                ),
                if (datos.isNotEmpty)
                  Text(
                    datos,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: Colors.black54),
                  ),

                const SizedBox(height: 10),

                // Botones de acción abajo
                if (_esApadrinada)
                  // Solo sale el botón por adoptar
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosa,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.pets, size: 16),
                      label: const Text(
                        'Adoptar',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: onAdoptar,
                    ),
                  )
                else
                  // Salen ambos botones: Adoptar y Apadrinar
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.rosa,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: onAdoptar,
                            child: const Text(
                              'Adoptar',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.rosa,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: onApadrinar,
                            child: const Text(
                              'Apadrinar',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
