import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/noticia.dart';
import 'package:paw_match/screens/noticias/noticia_detalle_screen.dart';
import 'package:paw_match/widgets/pet_card.dart' show urlFoto;

/// Tarjeta moderna inspirada en la imagen de referencia:
/// Foto completa de fondo, botón flotante de "Me gusta" arriba a la derecha,
/// y tarjeta flotante con efecto frosted glass abajo con el título y el lugar.
class NoticiaCard extends StatelessWidget {
  final Noticia noticia;
  final bool esAdmin;
  final VoidCallback onToggleLike;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback? onActualizado;

  const NoticiaCard({
    super.key,
    required this.noticia,
    required this.esAdmin,
    required this.onToggleLike,
    required this.onEditar,
    required this.onEliminar,
    this.onActualizado,
  });

  void _abrirDetalle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoticiaDetalleScreen(
          noticia: noticia,
          esAdmin: esAdmin,
          onActualizado: onActualizado,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tieneFoto = noticia.imagen != null && noticia.imagen!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _abrirDetalle(context),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. FOTO COMPLETA DE FONDO
                if (tieneFoto)
                  Image.network(
                    urlFoto(noticia.imagen!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                else
                  _placeholder(),

                // 2. DEGRADADO INFERIOR PARA CONTRASTE
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.20),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // 3. BOTÓN FLOTANTE SUPERIOR DERECHO: CORAZÓN / LIKE (ESTILO IMAGEN 1)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggleLike,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            noticia.dioLike ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 20,
                            color: noticia.dioLike ? AppColors.rosa : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. BOTÓN FLOTANTE SUPERIOR IZQUIERDO: OPCIONES ADMIN (SI APLICA)
                if (esAdmin)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                                width: 1,
                              ),
                            ),
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.white),
                              onSelected: (val) {
                                if (val == 'editar') onEditar();
                                if (val == 'eliminar') onEliminar();
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'editar',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 17, color: AppColors.rosa),
                                      SizedBox(width: 8),
                                      Text('Editar', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'eliminar',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 17, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Eliminar', style: TextStyle(fontSize: 13, color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 5. TARJETA FLOTANTE INFERIOR CON TÍTULO Y LUGAR (ESTILO IMAGEN 1)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.40),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Título de la noticia
                            Text(
                              noticia.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 5),

                            // Fila con Lugar y Likes (estilo Tokyo, Japan - 4.8)
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 13,
                                  color: AppColors.rosa,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    noticia.lugar,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.favorite_rounded,
                                      size: 12,
                                      color: AppColors.rosa,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${noticia.totalLikes}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.rosaSuave,
      child: const Center(
        child: Icon(Icons.newspaper_rounded, size: 48, color: AppColors.rosa),
      ),
    );
  }
}
