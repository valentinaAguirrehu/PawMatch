import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/widgets/pet_card.dart'; // PetImage

/// Tarjeta grande con fondo de color para el carrusel del inicio.
class PetCardColor extends StatelessWidget {
  final Pet pet;
  final Color color;
  final VoidCallback onTap;
  const PetCardColor({
    super.key,
    required this.pet,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final raza = pet.raza;
    final datos = [
      if (raza != null && raza.isNotEmpty) raza,
      if (pet.edad != null) pet.edadTexto,
    ].join(' · ');

    return SizedBox(
      width: 210,
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
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: PetImage(url: pet.foto),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              style: t.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.rosa,
                      child: Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: Colors.white,
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
