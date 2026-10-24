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
    final especie = pet.especie.toLowerCase();
    final edadTxt = pet.edad == null
        ? 'edad no reg.'
        : pet.edadTexto.toLowerCase();
    final subtituloFoto = '$edadTxt · $especie';

    final descripcionCorta = (pet.descripcion != null && pet.descripcion!.trim().isNotEmpty)
        ? pet.descripcion!.trim()
        : 'Hermoso ${pet.especie.toLowerCase()} rescatado, lleno de amor y buscando una familia que lo cuide para siempre.';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Foto cuadrada, igual en todas las tarjetas, con el nombre encima
              AspectRatio(
                aspectRatio: 1.0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: PetImage(url: pet.foto, fit: BoxFit.cover),
                    ),
                    // Sombra degradada para que el nombre blanco y texto se lean siempre nítidos
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.45, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Nombre y subtitulo en la esquina inferior izquierda (como en la foto de referencia)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pet.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtituloFoto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFFF72AD), // rosado luminoso sobre la foto
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Sección inferior: descripción
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: SizedBox(
                  height: 38,
                  child: Text(
                    descripcionCorta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),

              // 3. Pie de la tarjeta: Tamaño a la izquierda, Acción a la derecha.
              // En celdas angostas (2 columnas en celular) se apilan para no desbordar.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: LayoutBuilder(
                  builder: (context, footerConstraints) {
                    final chip = _chipTamano();
                    if (footerConstraints.maxWidth < 176) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          chip,
                          const SizedBox(height: 6),
                          _accionTarjeta(),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        chip,
                        const SizedBox(width: 8),
                        Expanded(child: _accionTarjeta(align: TextAlign.end)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipTamano() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bordeRosa,
          width: 1,
        ),
      ),
      child: Text(
        (pet.tamano ?? 'mediano').toLowerCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.rosa,
          fontWeight: FontWeight.bold,
          fontSize: 11.5,
        ),
      ),
    );
  }

  Widget _accionTarjeta({TextAlign align = TextAlign.start}) {
    if (pet.estaAdoptada) {
      return Text(
        pet.mensajeFamiliaPara(Session.idUsuario),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: const TextStyle(
          color: AppColors.rosa,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      );
    }
    return Text(
      'Apadrinar →',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: const TextStyle(
        color: AppColors.rosa,
        fontWeight: FontWeight.bold,
        fontSize: 12.5,
      ),
    );
  }
}
