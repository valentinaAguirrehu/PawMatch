import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import '../models/pet.dart';
import '../services/api_service.dart';
import '../services/session.dart';

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
      errorBuilder: (_, error, stack) => placeholder,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

/// Etiqueta con el estado de adopción (solo rosado y blanco).
class EstadoChip extends StatelessWidget {
  final String estado;
  const EstadoChip({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    // disponible: rosado intenso · en proceso: rosado suave · adoptado: gris neutro
    final (Color letra, Color fondo) = switch (estado) {
      'disponible' => (Colors.white, AppColors.rosa),
      'en_proceso' => (AppColors.rosa, AppColors.rosaClaro),
      _ => (AppColors.texto.withValues(alpha: 0.6), AppColors.rosaSuave),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiquetaEstadoAdopcion(estado),
        style: TextStyle(
          color: letra,
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
    final detalle = [
      pet.raza ?? pet.especie,
      if (pet.edad != null) pet.edadTexto,
    ].join(' · ');

    final descripcionCorta = (pet.descripcion != null && pet.descripcion!.trim().isNotEmpty)
        ? pet.descripcion!.trim()
        : 'Hermoso ${pet.especie.toLowerCase()} rescatado, lleno de amor y buscando una familia que lo cuide para siempre.';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Foto de la mascota a la izquierda (como en la referencia)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 110,
                    height: 120,
                    color: const Color(0xFFF1F3F7),
                    child: PetImage(url: pet.foto, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 14),

                // 2. Información y detalles a la derecha
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fila superior: Nombre y corazón flotante
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pet.nombre,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E272E),
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 13,
                                      color: AppColors.rosa,
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        'Pasto · Fundación M. Arévalo',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Botón / Distintivo de corazón (estilo imagen de referencia)
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFFF0F5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.rosa.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 18,
                              color: AppColors.rosa,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),

                      // Breve descripción
                      Text(
                        descripcionCorta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 9),

                      // Etiquetas: Raza/edad y estado
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              detalle,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ),
                          if (pet.estaAdoptada)
                            Text(
                              pet.mensajeFamiliaPara(Session.idUsuario),
                              style: const TextStyle(
                                color: AppColors.rosa,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            )
                          else
                            EstadoChip(estado: pet.estadoAdopcion),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
