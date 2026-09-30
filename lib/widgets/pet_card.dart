import 'package:flutter/material.dart';
import '../models/pet.dart';
import '../services/api_service.dart';

/// En la BD la foto se guarda como ruta relativa (/uploads/mascotas/x.jpg).
/// Aquí se le antepone el servidor (así funciona en emulador, celular y web).
String urlFoto(String ruta) {
  if (ruta.startsWith('http')) return ruta;
  final host = ApiService.baseUrl.replaceFirst(RegExp(r'/api$'), '');
  return '$host$ruta';
}

/// Foto de la mascota con un ícono de respaldo si no hay foto o falla la carga.
class PetImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const PetImage({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.pets,
        size: 40,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return Image.network(
      urlFoto(url!),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

/// Etiqueta de color con el estado de adopción.
class EstadoChip extends StatelessWidget {
  final String estado;
  const EstadoChip({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      'disponible' => Colors.green,
      'en_proceso' => Colors.amber.shade800,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiquetaEstadoAdopcion(estado),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class PetCard extends StatelessWidget {
  final Pet pet;
  final VoidCallback onTap;
  const PetCard({super.key, required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final detalle = [
      pet.raza ?? pet.especie,
      if (pet.edad != null) pet.edadTexto,
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: PetImage(url: pet.foto)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.nombre,
                    style: t.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: t.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  EstadoChip(estado: pet.estadoAdopcion),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
