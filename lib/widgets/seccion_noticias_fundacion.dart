import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/noticia.dart';
import 'package:paw_match/services/noticias_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/noticia_card.dart';
import 'package:paw_match/widgets/noticia_form_dialog.dart';

/// Sección de "Noticias de la Fundación" con carrusel horizontal interactivo,
/// previsualización de 2 tarjetas, puntitos de selección e ingreso a la vista detallada.
class SeccionNoticiasFundacion extends StatefulWidget {
  const SeccionNoticiasFundacion({super.key});

  @override
  State<SeccionNoticiasFundacion> createState() =>
      _SeccionNoticiasFundacionState();
}

class _SeccionNoticiasFundacionState extends State<SeccionNoticiasFundacion> {
  late Future<List<Noticia>> _future = NoticiasService.listar();
  List<Noticia>? _noticiasLocales;

  PageController? _pageController;
  double? _lastFraction;
  int _paginaActual = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ancho = MediaQuery.of(context).size.width;
    final fraction = ancho > 600 ? 0.38 : 0.72;
    if (_pageController == null) {
      _lastFraction = fraction;
      _pageController = PageController(
        viewportFraction: fraction,
        initialPage: _paginaActual,
      );
    } else if (_lastFraction != fraction) {
      _lastFraction = fraction;
      final old = _pageController;
      _pageController = PageController(
        viewportFraction: fraction,
        initialPage: _paginaActual,
      );
      old?.dispose();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _recargar() async {
    setState(() {
      _future = NoticiasService.listar();
    });
    final res = await _future.catchError((_) => <Noticia>[]);
    if (mounted) {
      setState(() {
        _noticiasLocales = res;
        if (_paginaActual >= res.length && res.isNotEmpty) {
          _paginaActual = res.length - 1;
        }
      });
    }
  }

  Future<void> _abrirCrear() async {
    final creado = await NoticiaFormDialog.mostrar(context);
    if (creado == true) _recargar();
  }

  Future<void> _abrirEditar(Noticia n) async {
    final editado = await NoticiaFormDialog.mostrar(context, noticia: n);
    if (editado == true) _recargar();
  }

  Future<void> _confirmarEliminar(Noticia n) async {
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
        content: Text('¿Seguro que deseas eliminar la noticia "${n.titulo}"? Esta acción no se puede deshacer.'),
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
        await NoticiasService.eliminar(n.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Noticia eliminada correctamente'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _recargar();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleLike(Noticia n) async {
    final prevLike = n.dioLike;
    final prevCount = n.totalLikes;

    // Actualización optimista inmediata
    setState(() {
      if (_noticiasLocales != null) {
        final idx = _noticiasLocales!.indexWhere((x) => x.id == n.id);
        if (idx != -1) {
          _noticiasLocales![idx] = n.copyWith(
            dioLike: !prevLike,
            totalLikes: prevLike ? (prevCount - 1) : (prevCount + 1),
          );
        }
      }
    });

    try {
      final res = await NoticiasService.toggleLike(n.id);
      if (mounted && _noticiasLocales != null) {
        final idx = _noticiasLocales!.indexWhere((x) => x.id == n.id);
        if (idx != -1) {
          setState(() {
            _noticiasLocales![idx] = n.copyWith(
              dioLike: res['dio_like'] == true,
              totalLikes: (res['total_likes'] as num?)?.toInt() ?? prevCount,
            );
          });
        }
      }
    } catch (_) {
      // Revertir si hubo error
      if (mounted && _noticiasLocales != null) {
        final idx = _noticiasLocales!.indexWhere((x) => x.id == n.id);
        if (idx != -1) {
          setState(() {
            _noticiasLocales![idx] = n.copyWith(
              dioLike: prevLike,
              totalLikes: prevCount,
            );
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esAdmin = Session.esAdmin;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 26, 0, 20),
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Encabezado de la sección
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.rosaSuave,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bordeRosa),
                  ),
                  child: const Center(
                    child: Icon(Icons.newspaper_rounded, color: AppColors.rosa, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Noticias de la Fundación',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E272E),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Eventos, jornadas, rescates y novedades destacadas.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Botón del Administrador para publicar nueva noticia
          if (esAdmin) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosa,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _abrirCrear,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: const Text(
                    'Publicar Nueva Noticia',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),

          // 3. CARRUSEL CON FUTUREBUILDER (ESTILO REFERENCIA IMAGEN 1)
          FutureBuilder<List<Noticia>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && _noticiasLocales == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.rosa),
                  ),
                );
              }

              final lista = _noticiasLocales ?? snap.data ?? [];
              if (_noticiasLocales == null && snap.hasData) {
                _noticiasLocales = snap.data;
              }

              if (lista.isEmpty) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.feed_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 10),
                      const Text(
                        'Aún no hay noticias publicadas',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Próximamente la fundación compartirá aquí sus eventos y rescates.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }


              return Column(
                children: [
                  // Carrusel de tarjetas
                  SizedBox(
                    height: 295,
                    child: PageView.builder(
                      controller: _pageController,
                      padEnds: false,
                      physics: const BouncingScrollPhysics(),
                      itemCount: lista.length,
                      onPageChanged: (idx) {
                        setState(() => _paginaActual = idx);
                      },
                      itemBuilder: (context, index) {
                        final noticia = lista[index];
                        final paddingLeft = index == 0 ? 16.0 : 4.0;
                        final paddingRight = index == lista.length - 1 ? 16.0 : 4.0;

                        return Padding(
                          padding: EdgeInsets.only(left: paddingLeft, right: paddingRight),
                          child: NoticiaCard(
                            key: ValueKey(noticia.id),
                            noticia: noticia,
                            esAdmin: esAdmin,
                            onToggleLike: () => _toggleLike(noticia),
                            onEditar: () => _abrirEditar(noticia),
                            onEliminar: () => _confirmarEliminar(noticia),
                            onActualizado: _recargar,
                          ),
                        );
                      },
                    ),
                  ),

                  // 4. PUNTITOS DE SELECCIÓN (INDICADOR INFERIOR ESTILO REFERENCIA)
                  if (lista.length > 1) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        lista.length,
                        (i) {
                          final activo = _paginaActual == i;
                          return GestureDetector(
                            onTap: () {
                              _pageController?.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: activo ? 24 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: activo
                                    ? AppColors.rosa
                                    : AppColors.rosa.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
