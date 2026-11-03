import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/noticia.dart';
import 'package:paw_match/services/noticias_service.dart';
import 'package:paw_match/widgets/noticia_form_dialog.dart';
import 'package:paw_match/widgets/pet_card.dart' show urlFoto;
import 'package:url_launcher/url_launcher.dart';

/// Pantalla de detalle de noticia inspirada en el diseño de referencia:
/// Foto prominente con tarjeta flotante de título y lugar en la parte inferior de la imagen,
/// pestañas de navegación (Overview / Detalles), chips de información rápida (fecha, lugar, likes)
/// y cuerpo de texto completo con botones de interacción.
class NoticiaDetalleScreen extends StatefulWidget {
  final Noticia noticia;
  final bool esAdmin;
  final VoidCallback? onActualizado;

  const NoticiaDetalleScreen({
    super.key,
    required this.noticia,
    required this.esAdmin,
    this.onActualizado,
  });

  @override
  State<NoticiaDetalleScreen> createState() => _NoticiaDetalleScreenState();
}

class _NoticiaDetalleScreenState extends State<NoticiaDetalleScreen> {
  late Noticia _noticia = widget.noticia;

  Future<void> _toggleLike() async {
    final prevLike = _noticia.dioLike;
    final prevCount = _noticia.totalLikes;

    // Actualización optimista
    setState(() {
      _noticia = _noticia.copyWith(
        dioLike: !prevLike,
        totalLikes: prevLike ? (prevCount - 1) : (prevCount + 1),
      );
    });

    try {
      final res = await NoticiasService.toggleLike(_noticia.id);
      if (mounted) {
        setState(() {
          _noticia = _noticia.copyWith(
            dioLike: res['dio_like'] == true,
            totalLikes: (res['total_likes'] as num?)?.toInt() ?? prevCount,
          );
        });
        widget.onActualizado?.call();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _noticia = _noticia.copyWith(
            dioLike: prevLike,
            totalLikes: prevCount,
          );
        });
      }
    }
  }

  String get _lugarLimpio {
    final l = _noticia.lugar.replaceAll(RegExp(r',?\s*Cali', caseSensitive: false), '').trim();
    return l.isEmpty ? 'Fundación Maritza Arévalo' : l;
  }

  Future<void> _compartirPorWhatsApp() async {
    final buffer = StringBuffer();
    buffer.writeln('🐾 *${_noticia.titulo}*');
    buffer.writeln('📅 *Fecha:* ${_noticia.fechaFormateada}');
    if (_lugarLimpio.isNotEmpty) {
      buffer.writeln('📍 *Lugar:* $_lugarLimpio');
    }
    buffer.writeln();
    buffer.writeln(_noticia.contenido);
    buffer.writeln();
    if (_noticia.imagen != null && _noticia.imagen!.isNotEmpty) {
      final foto = urlFoto(_noticia.imagen!);
      buffer.writeln('📸 *Foto de la noticia:* $foto');
      buffer.writeln();
    }
    buffer.writeln('👉 *Para ver bien la noticia y más detalles, ingresa a nuestra plataforma y regístrate:*');
    buffer.writeln('🐾 *${FundacionInfo.nombre}*');

    final texto = buffer.toString().trim();
    final uriApp = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(texto)}');
    final uriWeb = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}');

    try {
      if (await canLaunchUrl(uriApp)) {
        await launchUrl(uriApp, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(uriWeb)) {
        await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  Future<void> _editar() async {
    final editado = await NoticiaFormDialog.mostrar(context, noticia: _noticia);
    if (editado == true && mounted) {
      final actualizadas = await NoticiasService.listar();
      final encontrada = actualizadas.firstWhere(
        (x) => x.id == _noticia.id,
        orElse: () => _noticia,
      );
      setState(() => _noticia = encontrada);
      widget.onActualizado?.call();
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar noticia'),
          ],
        ),
        content: Text('¿Seguro que deseas eliminar la noticia "${_noticia.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        await NoticiasService.eliminar(_noticia.id);
        widget.onActualizado?.call();
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneFoto = _noticia.imagen != null && _noticia.imagen!.isNotEmpty;
    final altoPantalla = MediaQuery.of(context).size.height;
    final altoHero = (altoPantalla * 0.46).clamp(320.0, 440.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // CABECERA CON FOTO Y TARJETA FLOTANTE (ESTILO IMAGEN DE REFERENCIA 2)
          SliverToBoxAdapter(
            child: SizedBox(
              height: altoHero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Foto principal
                  if (tieneFoto)
                    Image.network(
                      urlFoto(_noticia.imagen!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.rosaSuave,
                        child: const Center(
                          child: Icon(Icons.image, size: 60, color: AppColors.rosa),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: AppColors.rosaSuave,
                      child: const Center(
                        child: Icon(Icons.newspaper_rounded, size: 70, color: AppColors.rosa),
                      ),
                    ),

                  // 2. Degradado sutil para legibilidad
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),

                  // 3. Botones flotantes superiores (Atrás, Compartir, Like, Admin)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          _botonFrosted(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          if (widget.esAdmin) ...[
                            PopupMenuButton<String>(
                              icon: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.38),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                ),
                                child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                              ),
                              onSelected: (val) {
                                if (val == 'editar') _editar();
                                if (val == 'eliminar') _eliminar();
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'editar',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18, color: AppColors.rosa),
                                      SizedBox(width: 8),
                                      Text('Editar noticia'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'eliminar',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // 4. TARJETA FLOTANTE CON TÍTULO Y LUGAR (ESTILO IMAGEN 2)
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Título y lugar
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _noticia.titulo,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          color: AppColors.rosa,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            _lugarLimpio,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.9),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Columna lateral con fecha / badge
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Fundación',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.rosa.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      '🐾 Noticia',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
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
                  ),
                ],
              ),
            ),
          ),

          // CONTENIDO INFERIOR: PESTAÑAS, CHIPS Y TEXTO COMPLETO
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado "Detalles"
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detalles',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 18,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.rosa,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Chips de información rápida: 🕒 [Fecha] 📍 [Lugar] ❤️ [Likes]
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chipInfo(
                          icono: Icons.calendar_today_rounded,
                          texto: _noticia.fechaFormateada,
                        ),
                        const SizedBox(width: 10),
                        _chipInfo(
                          icono: Icons.place_rounded,
                          texto: _lugarLimpio,
                        ),
                        const SizedBox(width: 10),
                        _chipInfo(
                          icono: Icons.favorite_rounded,
                          colorIcono: AppColors.rosa,
                          texto: '${_noticia.totalLikes} Likes',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Texto completo de la noticia
                  Text(
                    _noticia.contenido,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade800,
                      height: 1.65,
                      letterSpacing: 0.15,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botones de acción inferiores
                  Row(
                    children: [
                      // Botón Like
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _noticia.dioLike ? AppColors.rosa : Colors.white,
                            foregroundColor: _noticia.dioLike ? Colors.white : AppColors.rosa,
                            side: const BorderSide(color: AppColors.rosa, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: _toggleLike,
                          icon: Icon(
                            _noticia.dioLike ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 20,
                          ),
                          label: Text(
                            _noticia.dioLike ? 'Te gusta' : 'Me gusta',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botón Compartir
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: _compartirPorWhatsApp,
                          icon: const Icon(Icons.share_rounded, size: 20),
                          label: const Text(
                            'Compartir por WhatsApp',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonFrosted({
    required IconData icon,
    required VoidCallback onTap,
    Color colorIcono = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: colorIcono, size: 19),
          ),
        ),
      ),
    );
  }


  Widget _chipInfo({
    required IconData icono,
    required String texto,
    Color colorIcono = const Color(0xFF4B5563),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: colorIcono),
          const SizedBox(width: 8),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

}
