import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/widgets/pet_card.dart'; // PetImage

/// Tarjeta de un perrito para la landing. Al tocarla se invita a crear cuenta.
class PerritoLandingCard extends StatelessWidget {
  final Pet pet;
  final bool paraAdopcion;
  final VoidCallback onTap;
  const PerritoLandingCard({super.key, required this.pet, required this.paraAdopcion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final raza = pet.raza;
    final datos = [
      if (raza != null && raza.isNotEmpty) raza,
      if (pet.edad != null) pet.edadTexto,
    ].join(' · ');
    final f = (pet.foto ?? '').toLowerCase();
    final recorte = f.endsWith('.png') || f.endsWith('.webp'); // sin fondo: se ve entero

    return Material(
      color: AppColors.rosaClaro,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: PetImage(url: pet.foto, fit: recorte ? BoxFit.contain : BoxFit.cover),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pet.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.texto)),
                if (datos.isNotEmpty)
                  Text(datos, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.rosa, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(paraAdopcion ? 'Adoptar' : 'Apadrinar',
                        style: t.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                  ]),
                ),
                const SizedBox(height: 4),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
