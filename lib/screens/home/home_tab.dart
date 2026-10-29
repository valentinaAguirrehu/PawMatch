import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/layout.dart';
import 'package:paw_match/models/noticia.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/screens/pets/pet_detail_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/noticias_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart' show urlFoto;

/// Vista principal de Paw Match (HomeTab)
/// Con la cabecera y degradado EXACTO del Welcome (curva rosada luminosa con burbujas bokeh),
/// adaptable a Computador y Móvil, con fotos en noticias y botones compactos.
class HomeTab extends StatefulWidget {
  final VoidCallback onVerMascotas;
  final VoidCallback? onVerMatch;

  const HomeTab({
    super.key,
    required this.onVerMascotas,
    this.onVerMatch,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // Colores exactos del Welcome Screen
  static const Color _rosaWelcomeTop = Color(0xFFFFA3C8);
  static const Color _rosaWelcomeMid = Color(0xFFF98BB8);
  static const Color _rosaWelcomeSoft = Color(0xFFFDE4EF);
  static const Color _rosaPrincipal = AppColors.rosa; // #ED4F9D
  static const Color _rosaFondo = Color(0xFFFFF0F5);
  static const Color _textoOscuro = Color(0xFF2E2A2C);
  static const Color _textoGris = Color(0xFF7A6E75);

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _esperandoHogarKey = GlobalKey();

  late Future<List<Pet>> _futureMascotas;
  late Future<List<Noticia>> _futureNoticias;

  // Estado local de favoritos de mascotas
  final Set<String> _mascotasFavoritas = {'Luna'};

  // Estado local de likes en noticias
  final Set<String> _noticiasLiked = {};
  final Map<String, int> _noticiasLikeCounts = {};

  @override
  void initState() {
    super.initState();
    PetsService.iniciarMonitoreo();
    _cargarDatos();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _cargarDatos() {
    setState(() {
      _futureMascotas = PetsService.listar(estado: 'disponible');
      _futureNoticias = NoticiasService.listar();
    });
  }

  Future<void> _refrescar() async {
    _cargarDatos();
    await Future.wait([_futureMascotas, _futureNoticias]);
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (confirmar && mounted) {
      PetsService.detenerMonitoreo();
      ApadrinamientoService.detenerMonitoreo();
      AdoptionService.detenerMonitoreo();
      Session.cerrar();
      Navegacion.ir(context, const WelcomeScreen());
    }
  }

  void _scrollHaciaEsperandoHogar() {
    final ctx = _esperandoHogarKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      widget.onVerMascotas();
    }
  }

  void _toggleFavoritoMascota(Pet pet) {
    setState(() {
      if (_mascotasFavoritas.contains(pet.nombre)) {
        _mascotasFavoritas.remove(pet.nombre);
        _mostrarToast('Eliminaste a ${pet.nombre} de favoritos 🤍');
      } else {
        _mascotasFavoritas.add(pet.nombre);
        _mostrarToast('¡Añadiste a ${pet.nombre} a favoritos! 💖');
      }
    });
  }

  void _mostrarToast(String mensaje) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        backgroundColor: _rosaPrincipal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Interacción de Me Gusta en Noticias
  Future<void> _toggleLikeNoticia(Noticia noticia, [StateSetter? setModalState]) async {
    final yaDioLike = _noticiasLiked.contains(noticia.id);
    final conteo = _noticiasLikeCounts[noticia.id] ?? noticia.totalLikes;

    setState(() {
      if (yaDioLike) {
        _noticiasLiked.remove(noticia.id);
        _noticiasLikeCounts[noticia.id] = (conteo - 1).clamp(0, 999999);
      } else {
        _noticiasLiked.add(noticia.id);
        _noticiasLikeCounts[noticia.id] = conteo + 1;
      }
    });
    setModalState?.call(() {});

    try {
      final res = await NoticiasService.toggleLike(noticia.id);
      if (mounted) {
        final dioLikeServer = res['dio_like'] == true;
        final totalLikesServer = (res['total_likes'] as num?)?.toInt() ?? _noticiasLikeCounts[noticia.id]!;
        setState(() {
          if (dioLikeServer) {
            _noticiasLiked.add(noticia.id);
          } else {
            _noticiasLiked.remove(noticia.id);
          }
          _noticiasLikeCounts[noticia.id] = totalLikesServer;
        });
        setModalState?.call(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (yaDioLike) {
            _noticiasLiked.add(noticia.id);
            _noticiasLikeCounts[noticia.id] = conteo;
          } else {
            _noticiasLiked.remove(noticia.id);
            _noticiasLikeCounts[noticia.id] = conteo;
          }
        });
        setModalState?.call(() {});
      }
    }
  }

  void _abrirModalNoticia(Noticia noticia, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final dioLike = _noticiasLiked.contains(noticia.id);
            final totalLikes = _noticiasLikeCounts[noticia.id] ?? noticia.totalLikes;
            final categoria = _categoriaNoticia(noticia);
            final fecha = _formatearFecha(noticia.fecha);
            final tiempoLectura = _tiempoLectura(noticia.contenido);
            final fotoUrl = _obtenerFotoNoticia(noticia, index);

            return Center(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                constraints: const BoxConstraints(maxWidth: 680),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33ED4F9D),
                      blurRadius: 30,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _rosaWelcomeTop.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Image.network(
                                fotoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: _rosaFondo,
                                  child: const Icon(Icons.pets_rounded, color: _rosaPrincipal, size: 40),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [_rosaWelcomeTop, _rosaPrincipal],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  categoria.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                fecha,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('•', style: TextStyle(color: Colors.grey)),
                              const SizedBox(width: 6),
                              Text(
                                tiempoLectura,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _rosaPrincipal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Text(
                            noticia.titulo,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: _textoOscuro,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            noticia.contenido,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.6,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: _rosaWelcomeTop.withValues(alpha: 0.4))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => _toggleLikeNoticia(noticia, setModalState),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: dioLike ? _rosaFondo : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: dioLike ? _rosaPrincipal : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    dioLike ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: dioLike ? _rosaPrincipal : Colors.grey.shade600,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dioLike ? '¡Te gusta!' : 'Me gusta',
                                    style: TextStyle(
                                      color: dioLike ? _rosaPrincipal : Colors.grey.shade700,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: dioLike ? _rosaPrincipal : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$totalLikes',
                                      style: TextStyle(
                                        color: dioLike ? Colors.white : Colors.grey.shade800,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: FilledButton.styleFrom(
                              backgroundColor: _rosaPrincipal,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            child: const Text(
                              'Listo',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarInfoFundacion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _rosaWelcomeTop,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const Text(
              'Fundación Maritza Arévalo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textoOscuro),
            ),
            const SizedBox(height: 10),
            Text(
              'Dedicados con amor al rescate, cuidado veterinario y adopción responsable de perritos y gatitos sin hogar en Cali y sus alrededores.',
              style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _rosaPrincipal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onVerMascotas();
                },
                child: const Text('Conocer a los peluditos 🐾', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anchoTotal = MediaQuery.sizeOf(context).width;
    final esEscritorio = anchoTotal >= Layout.escritorio; // >= 900
    final anchoMaximoContenido = esEscritorio ? 1050.0 : Layout.anchoMaximo;

    return ColoredBox(
      color: _rosaFondo,
      child: RefreshIndicator(
        color: _rosaPrincipal,
        backgroundColor: Colors.white,
        onRefresh: _refrescar,
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ==========================================
            // 1. BARRA SUPERIOR (IDÉNTICA A LANDINGBARRA DE WELCOME)
            // Con el color rosado oficial (#FFA3C8), logo, saludo y botón salir
            // ==========================================
            Container(
              color: _rosaWelcomeTop,
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: anchoMaximoContenido),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: esEscritorio ? 24 : 16,
                        vertical: esEscritorio ? 10 : 8,
                      ),
                      child: _construirEncabezadoSuperior(esEscritorio),
                    ),
                  ),
                ),
              ),
            ),

            // ==========================================
            // 2. HERO BANNER CURVADO CON DEGRADADO Y BURBUJAS (IDÉNTICO A WELCOME)
            // ==========================================
            Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FondoHeroWelcomePainter(
                      colorTop: _rosaWelcomeTop,
                      colorMid: _rosaWelcomeMid,
                      colorBottom: _rosaWelcomeSoft,
                      colorFondo: Colors.white,
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: anchoMaximoContenido),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        esEscritorio ? 36 : 20,
                        esEscritorio ? 14 : 10,
                        esEscritorio ? 36 : 20,
                        esEscritorio ? 58 : 50,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'CONOCE NUESTRA',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: esEscritorio ? 14 : 12,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: Colors.white.withValues(alpha: 0.95),
                              letterSpacing: 2.8,
                              height: 1.1,
                              shadows: const [
                                Shadow(
                                  color: Color(0x35000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'FUNDACIÓN\nMARITZA\nARÉVALO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: esEscritorio ? 46.0 : 34.0,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: Colors.white,
                              height: 1.05,
                              letterSpacing: 0.4,
                              shadows: const [
                                Shadow(
                                  color: Color(0x40000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ==========================================
            // CONTENIDO PRINCIPAL ADAPTABLE (CELULAR Y COMPUTADOR)
            // ==========================================
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: anchoMaximoContenido),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: esEscritorio ? 32 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. HERO BANNER PRINCIPAL (con la ilustración oficial)
                      _construirHeroBanner(esEscritorio),

                      SizedBox(height: esEscritorio ? 22 : 16),

                      // 3. ACCIONES RÁPIDAS (3 CUADROS COMPACTOS)
                      _construirAccionesRapidas(esEscritorio),

                      SizedBox(height: esEscritorio ? 26 : 20),

                      // 4. SECCIÓN "ESPERANDO UN HOGAR" (SIN OVERFLOWS)
                      Container(
                        key: _esperandoHogarKey,
                        child: _construirSeccionEsperandoUnHogar(esEscritorio),
                      ),

                      SizedBox(height: esEscritorio ? 26 : 20),

                      // 5. SECCIÓN NOTICIAS DE LA FUNDACIÓN (CON FOTOS)
                      _construirSeccionNoticias(esEscritorio),

                      SizedBox(height: esEscritorio ? 36 : 28),

                      // PIE DE PÁGINA
                      _construirPieDePagina(esEscritorio),

                      const SizedBox(height: 30),
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

  // ==========================================
  // 1. ENCABEZADO SUPERIOR
  // ==========================================
  Widget _construirEncabezadoSuperior(bool esEscritorio) {
    final nombre = Session.nombre.trim().isNotEmpty ? Session.nombre.trim() : 'amigo';
    final tamanoLogo = esEscritorio ? 52.0 : 44.0;

    return Row(
      children: [
        // Logo circular oficial
        Container(
          width: tamanoLogo,
          height: tamanoLogo,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/Logo Fundación.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Image.asset(
                'assets/images/Logo Fundación.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.pets, color: _rosaPrincipal),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Saludo y Nombre en Blanco
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'FUNDACIÓN OFICIAL',
                    style: TextStyle(
                      fontSize: esEscritorio ? 10.5 : 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '¡Hola, $nombre! 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: esEscritorio ? 20 : 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Color(0x35000000), blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Botón Salir en pastilla blanca
          ElevatedButton.icon(
            onPressed: _confirmarCerrarSesion,
            icon: Icon(Icons.logout_rounded, size: esEscritorio ? 15 : 13, color: _rosaPrincipal),
            label: Text(
              'Salir',
              style: TextStyle(
                fontSize: esEscritorio ? 12.5 : 11,
                fontWeight: FontWeight.w800,
                color: _rosaPrincipal,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _rosaPrincipal,
              elevation: 2,
              shadowColor: Colors.black26,
              padding: EdgeInsets.symmetric(
                horizontal: esEscritorio ? 16 : 12,
                vertical: esEscritorio ? 9 : 6,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      );
  }

  // ==========================================
  // 2. HERO BANNER PRINCIPAL (ADAPTABLE)
  // ==========================================
  Widget _construirHeroBanner(bool esEscritorio) {
    return Container(
      width: double.infinity,
      height: esEscritorio ? 285 : 195,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x25ED4F9D),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Foto hero institucional (ilustración con Maritza y perritos)
          Image.asset(
            'assets/images/inicio/fundacion_hero.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Image.asset(
              'assets/images/fundacion_hero.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Image.network(
                'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?auto=format&fit=crop&w=1200&q=80',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Degradado inferior
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.40, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.12),
                  _rosaPrincipal.withValues(alpha: 0.32),
                  const Color(0xFF261D22).withValues(alpha: 0.90),
                ],
              ),
            ),
          ),

          // Textos y Botón Conocer más
          Padding(
            padding: EdgeInsets.all(esEscritorio ? 22 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'LABOR SOCIAL DE AMOR',
                    style: TextStyle(
                      color: _rosaPrincipal,
                      fontSize: esEscritorio ? 11 : 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                SizedBox(height: esEscritorio ? 8 : 5),
                Text(
                  'Uniendo Huellitas ❤️',
                  style: TextStyle(
                    fontSize: esEscritorio ? 27 : 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Rescatando vidas, creando finales felices 🐾',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: esEscritorio ? 13.5 : 11.5,
                          color: const Color(0xFFFFF0F5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _rosaPrincipal,
                        elevation: 2,
                        padding: EdgeInsets.symmetric(
                          horizontal: esEscritorio ? 16 : 12,
                          vertical: esEscritorio ? 9 : 6,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _mostrarInfoFundacion,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Conocer más',
                            style: TextStyle(
                              fontSize: esEscritorio ? 12.5 : 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.chevron_right_rounded, size: esEscritorio ? 16 : 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. ACCIONES RÁPIDAS (3 CUADROS)
  // ==========================================
  Widget _construirAccionesRapidas(bool esEscritorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿CÓMO QUIERES AYUDAR?',
          style: TextStyle(
            fontSize: esEscritorio ? 14 : 11.5,
            fontWeight: FontWeight.w900,
            color: _rosaPrincipal,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: esEscritorio ? 12 : 8),
        Row(
          children: [
            // 1. Adopta
            Expanded(
              child: _BotonAccionCompacto(
                titulo: 'Adopta',
                subtitulo: 'Un amigo',
                icono: Icons.pets_rounded,
                colorIcono: _rosaPrincipal,
                esEscritorio: esEscritorio,
                onTap: widget.onVerMascotas,
              ),
            ),
            SizedBox(width: esEscritorio ? 12 : 8),

            // 2. Apadrina
            Expanded(
              child: _BotonAccionCompacto(
                titulo: 'Apadrina',
                subtitulo: 'Dona amor',
                icono: Icons.volunteer_activism_rounded,
                colorIcono: _rosaWelcomeMid,
                esEscritorio: esEscritorio,
                onTap: widget.onVerMascotas,
              ),
            ),
            SizedBox(width: esEscritorio ? 12 : 8),

            // 3. Esperando hogar
            Expanded(
              child: _BotonAccionCompacto(
                titulo: 'Esperando',
                subtitulo: 'hogar',
                icono: Icons.home_outlined,
                colorIcono: _rosaWelcomeTop,
                esEscritorio: esEscritorio,
                onTap: _scrollHaciaEsperandoHogar,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 4. SECCIÓN "ESPERANDO UN HOGAR" (SIN OVERFLOWS)
  // ==========================================
  Widget _construirSeccionEsperandoUnHogar(bool esEscritorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite_rounded, color: _rosaPrincipal, size: esEscritorio ? 18 : 15),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'ESPERANDO UN HOGAR',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: esEscritorio ? 15 : 12,
                            fontWeight: FontWeight.w900,
                            color: _rosaPrincipal,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Peluditos listos para llenar tu vida de alegría',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: esEscritorio ? 13 : 11,
                      fontWeight: FontWeight.w500,
                      color: _textoGris,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            TextButton(
              onPressed: widget.onVerMascotas,
              style: TextButton.styleFrom(
                foregroundColor: _rosaPrincipal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver todos',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: esEscritorio ? 13 : 11.5,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 15),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: esEscritorio ? 12 : 8),

        // Carrusel Horizontal de Mascotas
        SizedBox(
          height: esEscritorio ? 270 : 220,
          child: FutureBuilder<List<Pet>>(
            future: _futureMascotas,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _rosaPrincipal, strokeWidth: 2),
                );
              }

              final lista = snapshot.data ?? [];
              final mascotas = lista.isNotEmpty ? lista : _mascotasPorDefecto();

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mascotas.length,
                separatorBuilder: (_, _) => SizedBox(width: esEscritorio ? 16 : 12),
                itemBuilder: (context, index) {
                  final pet = mascotas[index];
                  final esFav = _mascotasFavoritas.contains(pet.nombre);

                  return _TarjetaMascotaEstiloFoto(
                    pet: pet,
                    esFavorito: esFav,
                    esEscritorio: esEscritorio,
                    onToggleFavorito: () => _toggleFavoritoMascota(pet),
                    onAdoptar: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PetDetailScreen(pet: pet)),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 5. SECCIÓN NOTICIAS DE LA FUNDACIÓN (CON FOTOS)
  // ==========================================
  Widget _construirSeccionNoticias(bool esEscritorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.newspaper_rounded, color: _rosaPrincipal, size: esEscritorio ? 18 : 15),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'NOTICIAS DE LA FUNDACIÓN',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: esEscritorio ? 15 : 12,
                            fontWeight: FontWeight.w900,
                            color: _rosaPrincipal,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Novedades y reportes del refugio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: esEscritorio ? 13 : 11,
                      fontWeight: FontWeight.w500,
                      color: _textoGris,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            Container(
              padding: EdgeInsets.symmetric(
                horizontal: esEscritorio ? 12 : 9,
                vertical: esEscritorio ? 4 : 3,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _rosaWelcomeTop.withValues(alpha: 0.6)),
              ),
              child: Text(
                'Rosa Noticias ✨',
                style: TextStyle(
                  fontSize: esEscritorio ? 12 : 10,
                  fontWeight: FontWeight.w800,
                  color: _rosaPrincipal,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: esEscritorio ? 16 : 12),

        // Carga de Noticias
        FutureBuilder<List<Noticia>>(
          future: _futureNoticias,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: _rosaPrincipal, strokeWidth: 2),
                ),
              );
            }

            final lista = snapshot.data ?? [];
            final noticias = lista.isNotEmpty ? lista : _noticiasPorDefecto();

            // Inicializar likes locales
            for (final n in noticias) {
              if (!_noticiasLikeCounts.containsKey(n.id)) {
                _noticiasLikeCounts[n.id] = n.totalLikes > 0 ? n.totalLikes : 142;
                if (n.dioLike) _noticiasLiked.add(n.id);
              }
            }

            final destacada = noticias.first;
            final secundarias = noticias.skip(1).toList();

            // En Computador: 2 Columnas amplias y cómodas
            if (esEscritorio) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _TarjetaNoticiaDestacada(
                      noticia: destacada,
                      fotoUrl: _obtenerFotoNoticia(destacada, 0),
                      dioLike: _noticiasLiked.contains(destacada.id),
                      totalLikes: _noticiasLikeCounts[destacada.id] ?? destacada.totalLikes,
                      categoria: _categoriaNoticia(destacada),
                      fechaTexto: _formatearFecha(destacada.fecha),
                      tiempoLecturaTexto: _tiempoLectura(destacada.contenido),
                      esEscritorio: true,
                      onTap: () => _abrirModalNoticia(destacada, 0),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: secundarias.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final n = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TarjetaNoticiaSecundaria(
                            noticia: n,
                            fotoUrl: _obtenerFotoNoticia(n, idx),
                            dioLike: _noticiasLiked.contains(n.id),
                            totalLikes: _noticiasLikeCounts[n.id] ?? n.totalLikes,
                            categoria: _categoriaNoticia(n),
                            fechaTexto: _formatearFecha(n.fecha),
                            tiempoLecturaTexto: _tiempoLectura(n.contenido),
                            esEscritorio: true,
                            onTap: () => _abrirModalNoticia(n, idx),
                            onToggleLike: () => _toggleLikeNoticia(n),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            }

            // En Móvil: 1 Columna fluida
            return Column(
              children: [
                _TarjetaNoticiaDestacada(
                  noticia: destacada,
                  fotoUrl: _obtenerFotoNoticia(destacada, 0),
                  dioLike: _noticiasLiked.contains(destacada.id),
                  totalLikes: _noticiasLikeCounts[destacada.id] ?? destacada.totalLikes,
                  categoria: _categoriaNoticia(destacada),
                  fechaTexto: _formatearFecha(destacada.fecha),
                  tiempoLecturaTexto: _tiempoLectura(destacada.contenido),
                  esEscritorio: false,
                  onTap: () => _abrirModalNoticia(destacada, 0),
                ),

                const SizedBox(height: 12),

                ...secundarias.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final n = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TarjetaNoticiaSecundaria(
                      noticia: n,
                      fotoUrl: _obtenerFotoNoticia(n, idx),
                      dioLike: _noticiasLiked.contains(n.id),
                      totalLikes: _noticiasLikeCounts[n.id] ?? n.totalLikes,
                      categoria: _categoriaNoticia(n),
                      fechaTexto: _formatearFecha(n.fecha),
                      tiempoLecturaTexto: _tiempoLectura(n.contenido),
                      esEscritorio: false,
                      onTap: () => _abrirModalNoticia(n, idx),
                      onToggleLike: () => _toggleLikeNoticia(n),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  // ==========================================
  // PIE DE PÁGINA
  // ==========================================
  Widget _construirPieDePagina(bool esEscritorio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pets_rounded, size: esEscritorio ? 16 : 14, color: _rosaPrincipal.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(
                'Paw Match',
                style: TextStyle(
                  fontSize: esEscritorio ? 14 : 12,
                  fontWeight: FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Todos los derechos reservados © Fundación Maritza Arévalo 2026',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: esEscritorio ? 12 : 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // Helpers de Foto y Formato
  String _obtenerFotoNoticia(Noticia n, int index) {
    if (n.imagen != null && n.imagen!.trim().isNotEmpty) {
      final img = n.imagen!.trim();
      if (img.startsWith('http')) return img;
      final host = ApiService.baseUrl.replaceFirst(RegExp(r'/api$'), '');
      return '$host$img';
    }

    switch (index % 3) {
      case 0:
        return 'https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=800&q=80';
      case 1:
        return 'https://images.unsplash.com/photo-1529429617124-95b109e86bb8?auto=format&fit=crop&w=600&q=80';
      default:
        return 'https://images.unsplash.com/photo-1576201836106-db1758fd1c97?auto=format&fit=crop&w=600&q=80';
    }
  }

  String _categoriaNoticia(Noticia n) {
    final t = '${n.titulo} ${n.contenido}'.toLowerCase();
    if (t.contains('rescate') || t.contains('cachorr') || t.contains('encontr')) {
      return 'Rescate';
    }
    if (t.contains('salud') || t.contains('esteriliz') || t.contains('vacun') || t.contains('sanitaria')) {
      return 'Salud';
    }
    return 'Evento';
  }

  String _formatearFecha(String fechaRaw) {
    try {
      final p = DateTime.tryParse(fechaRaw);
      if (p != null) {
        const meses = [
          'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
          'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
        ];
        return '${p.day} ${meses[p.month - 1]}, ${p.year}';
      }
    } catch (_) {}
    return fechaRaw.isNotEmpty ? fechaRaw : '28 Oct, 2026';
  }

  String _tiempoLectura(String contenido) {
    final palabras = contenido.trim().split(RegExp(r'\s+')).length;
    final min = (palabras / 40).ceil().clamp(1, 10);
    return '$min min de lectura';
  }

  List<Pet> _mascotasPorDefecto() {
    return [
      const Pet(
        id: 'mock-1',
        nombre: 'Max',
        especie: 'perro',
        raza: 'Cachorro Juguetón',
        edad: 5,
        unidadEdad: 'meses',
        sexo: 'macho',
        foto: 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=600&q=80',
        descripcion: 'Cachorrito rescatado muy juguetón y lleno de vida.',
      ),
      const Pet(
        id: 'mock-2',
        nombre: 'Luna',
        especie: 'gato',
        raza: 'Gatita Cariñosa',
        edad: 1,
        unidadEdad: 'anos',
        sexo: 'hembra',
        foto: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=600&q=80',
        descripcion: 'Gatita bicolor curiosa que adora los mimos y ronronear.',
      ),
      const Pet(
        id: 'mock-3',
        nombre: 'Rocky',
        especie: 'perro',
        raza: 'Noble Guardián',
        edad: 2,
        unidadEdad: 'anos',
        sexo: 'macho',
        foto: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=600&q=80',
        descripcion: 'Compañero leal y atento, ideal para familias.',
      ),
    ];
  }

  List<Noticia> _noticiasPorDefecto() {
    return [
      const Noticia(
        id: 'noticia-1',
        titulo: 'Gran Jornada Sanitaria y de Adopción de la Fundación',
        contenido:
            'Acompáñanos este fin de semana en nuestra sede. Habrá vacunación gratuita, desparasitación para peluditos de la comunidad y un espacio especial para conocer a los rescatados en adopción. ¡Trae a tu familia y celebremos la oportunidad de cambiar vidas!',
        fecha: '2026-10-28',
        totalLikes: 142,
        dioLike: false,
      ),
      const Noticia(
        id: 'noticia-2',
        titulo: 'Rescatamos a 6 cachorritos en la zona norte de la ciudad',
        contenido:
            'Gracias al oportuno reporte vecinal, logramos poner a salvo a una camada de 6 cachorritos en estado de vulnerabilidad. Ya han recibido chequeo veterinario y vitaminas.',
        fecha: '2026-10-24',
        totalLikes: 98,
        dioLike: true,
      ),
      const Noticia(
        id: 'noticia-3',
        titulo: 'Éxito en la jornada de esterilización comunitaria',
        contenido:
            'Culminamos con éxito 85 procedimientos de esterilización en caninos y felinos. Esterilizar salva vidas y previene el abandono.',
        fecha: '2026-10-19',
        totalLikes: 74,
        dioLike: false,
      ),
    ];
  }
}

// ==========================================
// PAINTER: DEGRADADO ROSADO CON BURBUJAS Y ONDA EXACTO A WELCOME
// ==========================================
class _FondoHeroWelcomePainter extends CustomPainter {
  final Color colorTop;
  final Color colorMid;
  final Color colorBottom;
  final Color colorFondo;

  const _FondoHeroWelcomePainter({
    required this.colorTop,
    required this.colorMid,
    required this.colorBottom,
    this.colorFondo = const Color(0xFFFFF0F5),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final base = size.height;

    // Camino con curva idéntica a Welcome (welcome_screen.dart:1079-1089)
    final rosa = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, base - 36)
      ..cubicTo(w * 0.78, base - 8, w * 0.58, base - 58, w * 0.40, base - 34)
      ..cubicTo(w * 0.22, base - 10, w * 0.10, base - 48, 0, base - 22)
      ..close();

    final borde = Path()
      ..moveTo(w, base - 36)
      ..cubicTo(w * 0.78, base - 8, w * 0.58, base - 58, w * 0.40, base - 34)
      ..cubicTo(w * 0.22, base - 10, w * 0.10, base - 48, 0, base - 22);

    canvas.drawRect(rect, Paint()..color = colorFondo);
    canvas.save();
    canvas.clipPath(rosa);

    // Degradado suave y luminoso exacto del Welcome
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [colorTop, colorMid, colorBottom],
    ).createShader(rect);

    canvas.drawRect(rect, Paint()..shader = shader);

    // Burbujas Bokeh idénticas a la pantalla de bienvenida
    void burbuja(double x, double y, double radio, double alpha) {
      canvas.drawCircle(
        Offset(x, y),
        radio,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    final escala = math.min(size.width, 420);
    burbuja(size.width * 0.12, size.height * 0.24, escala * 0.18, 0.22);
    burbuja(size.width * 0.90, size.height * 0.18, escala * 0.20, 0.18);
    burbuja(size.width * 0.62, size.height * 0.12, escala * 0.09, 0.15);
    burbuja(size.width * 0.35, size.height * 0.52, escala * 0.12, 0.12);

    canvas.restore();

    // Borde blanco suave difuminado tipo resplandor
    canvas.drawPath(
      borde,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _FondoHeroWelcomePainter oldDelegate) =>
      oldDelegate.colorTop != colorTop ||
      oldDelegate.colorMid != colorMid ||
      oldDelegate.colorBottom != colorBottom ||
      oldDelegate.colorFondo != colorFondo;
}

// ==========================================
// WIDGET: BOTÓN DE ACCIÓN RÁPIDA COMPACTO (ADAPTABLE)
// ==========================================
class _BotonAccionCompacto extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color colorIcono;
  final bool esEscritorio;
  final VoidCallback onTap;

  const _BotonAccionCompacto({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.colorIcono,
    required this.esEscritorio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tamanoCirculo = esEscritorio ? 48.0 : 36.0;
    final tamanoIcono = esEscritorio ? 24.0 : 18.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(esEscritorio ? 20 : 16),
      elevation: 1.5,
      shadowColor: const Color(0xFFED4F9D).withValues(alpha: 0.18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(esEscritorio ? 20 : 16),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: esEscritorio ? 14 : 8,
            horizontal: esEscritorio ? 8 : 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: tamanoCirculo,
                height: tamanoCirculo,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFF0F5),
                  border: Border.all(color: colorIcono.withValues(alpha: 0.4), width: 1.2),
                ),
                child: Icon(icono, color: colorIcono, size: tamanoIcono),
              ),
              SizedBox(height: esEscritorio ? 8 : 5),
              Text(
                titulo,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: esEscritorio ? 14 : 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2E2A2C),
                ),
              ),
              Text(
                subtitulo,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: esEscritorio ? 11.5 : 9,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFED4F9D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// WIDGET: TARJETA DE MASCOTA DEL CARRUSEL (ADAPTABLE)
// ==========================================
class _TarjetaMascotaEstiloFoto extends StatelessWidget {
  final Pet pet;
  final bool esFavorito;
  final bool esEscritorio;
  final VoidCallback onToggleFavorito;
  final VoidCallback onAdoptar;

  const _TarjetaMascotaEstiloFoto({
    required this.pet,
    required this.esFavorito,
    required this.esEscritorio,
    required this.onToggleFavorito,
    required this.onAdoptar,
  });

  @override
  Widget build(BuildContext context) {
    final esHembra = (pet.sexo ?? '').toLowerCase().startsWith('h');
    final tagSexo = esHembra ? 'Hembra' : 'Macho';
    final fotoSrc = pet.foto != null && pet.foto!.isNotEmpty ? pet.foto! : '';
    final anchoTarjeta = esEscritorio ? 200.0 : 155.0;

    return Container(
      width: anchoTarjeta,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFED4F9D).withValues(alpha: 0.22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22ED4F9D),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto de la mascota
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (fotoSrc.isNotEmpty)
                  Image.network(
                    urlFoto(fotoSrc),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                else
                  _placeholder(),

                // Insignia Sexo • Edad
                Positioned(
                  bottom: 7,
                  left: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFED4F9D).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$tagSexo • ${pet.edadTexto}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: esEscritorio ? 10 : 8.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                // Botón de Favoritos
                Positioned(
                  top: 7,
                  right: 7,
                  child: InkWell(
                    onTap: onToggleFavorito,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: esEscritorio ? 32 : 28,
                      height: esEscritorio ? 32 : 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.95),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      child: Icon(
                        esFavorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: esEscritorio ? 17 : 15,
                        color: esFavorito ? const Color(0xFFED4F9D) : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Nombre, raza y botón Adoptar
          Padding(
            padding: EdgeInsets.fromLTRB(
              esEscritorio ? 12 : 10,
              esEscritorio ? 10 : 8,
              esEscritorio ? 12 : 10,
              esEscritorio ? 12 : 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pet.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: esEscritorio ? 15 : 13.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2E2A2C),
                  ),
                ),
                Text(
                  pet.raza ?? (pet.especie == 'gato' ? 'Gatita Cariñosa' : 'Cachorro Juguetón'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: esEscritorio ? 11.5 : 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: esEscritorio ? 8 : 6),
                InkWell(
                  onTap: onAdoptar,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: esEscritorio ? 7 : 5.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFA3C8), Color(0xFFED4F9D)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x35ED4F9D),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Adoptar 💖',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: esEscritorio ? 12 : 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFFFF0F5),
      child: Center(
        child: Icon(
          pet.especie == 'gato' ? Icons.pets : Icons.pets_rounded,
          color: const Color(0xFFED4F9D),
          size: 32,
        ),
      ),
    );
  }
}

// ==========================================
// WIDGET: TARJETA NOTICIA DESTACADA (ADAPTABLE)
// ==========================================
class _TarjetaNoticiaDestacada extends StatelessWidget {
  final Noticia noticia;
  final String fotoUrl;
  final bool dioLike;
  final int totalLikes;
  final String categoria;
  final String fechaTexto;
  final String tiempoLecturaTexto;
  final bool esEscritorio;
  final VoidCallback onTap;

  const _TarjetaNoticiaDestacada({
    required this.noticia,
    required this.fotoUrl,
    required this.dioLike,
    required this.totalLikes,
    required this.categoria,
    required this.fechaTexto,
    required this.tiempoLecturaTexto,
    required this.esEscritorio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 2,
      shadowColor: const Color(0x25ED4F9D),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto grande superior
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: SizedBox(
                height: esEscritorio ? 220 : 180,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      fotoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFFFF0F5),
                        child: const Icon(Icons.pets, color: Color(0xFFED4F9D), size: 36),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.5, 1.0],
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.80)],
                        ),
                      ),
                    ),
                    // Badge DESTACADO
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFED4F9D),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          '★ DESTACADO',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    // Fecha y lectura en el borde inferior
                    Positioned(
                      bottom: 8,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          Text(
                            '📅 $fechaTexto',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: esEscritorio ? 12 : 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: Colors.white70)),
                          const SizedBox(width: 6),
                          Text(
                            '⏱️ $tiempoLecturaTexto',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: esEscritorio ? 12 : 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Cuerpo
            Padding(
              padding: EdgeInsets.all(esEscritorio ? 16 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    noticia.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: esEscritorio ? 16 : 14.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2E2A2C),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    noticia.contenido,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: esEscritorio ? 13 : 11.5,
                      height: 1.4,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFED4F9D).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '📍 Sede Refugio',
                          style: TextStyle(
                            fontSize: esEscritorio ? 11 : 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFED4F9D),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'Leer y dar Me Gusta 💖',
                            style: TextStyle(
                              fontSize: esEscritorio ? 12.5 : 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFED4F9D),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFFED4F9D)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// WIDGET: TARJETA NOTICIA SECUNDARIA (ADAPTABLE)
// ==========================================
class _TarjetaNoticiaSecundaria extends StatelessWidget {
  final Noticia noticia;
  final String fotoUrl;
  final bool dioLike;
  final int totalLikes;
  final String categoria;
  final String fechaTexto;
  final String tiempoLecturaTexto;
  final bool esEscritorio;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;

  const _TarjetaNoticiaSecundaria({
    required this.noticia,
    required this.fotoUrl,
    required this.dioLike,
    required this.totalLikes,
    required this.categoria,
    required this.fechaTexto,
    required this.tiempoLecturaTexto,
    required this.esEscritorio,
    required this.onTap,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    final tamanoMiniatura = esEscritorio ? 90.0 : 76.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 1.5,
      shadowColor: const Color(0x22ED4F9D),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.all(esEscritorio ? 12 : 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: tamanoMiniatura,
                  height: tamanoMiniatura,
                  child: Image.network(
                    fotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFFFF0F5),
                      child: const Icon(Icons.pets, color: Color(0xFFED4F9D)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        categoria,
                        style: TextStyle(
                          fontSize: esEscritorio ? 10 : 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFED4F9D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      noticia.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: esEscritorio ? 14 : 12.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2E2A2C),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '📅 $fechaTexto • ⏱️ $tiempoLecturaTexto',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: esEscritorio ? 11 : 9.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFED4F9D), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}