import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/enlaces.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/core/layout.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/screens/auth/login_screen.dart';
import 'package:paw_match/screens/auth/register_screen.dart';
import 'package:paw_match/services/fundacion_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/widgets/bloque_landing.dart';
import 'package:paw_match/widgets/boton_landing.dart';
import 'package:paw_match/widgets/fundacion_imagen.dart';
import 'package:paw_match/widgets/landing_barra.dart';
import 'package:paw_match/widgets/perritos_carrusel.dart';
import 'package:paw_match/widgets/redes_sociales.dart';
import 'package:paw_match/widgets/stat_logro.dart';
import 'package:paw_match/widgets/tarjeta_ayuda.dart';
import 'package:paw_match/widgets/titulo_landing.dart';
import 'package:paw_match/screens/denuncias/denuncia_reporte_screen.dart';

/// Medidas calculadas según el ancho de la pantalla (celular, tablet o computador).
class _Medidas {
  final bool escritorio;
  final double ancho, interior, anchoInterior, tTitulo;
  const _Medidas(
    this.escritorio,
    this.ancho,
    this.interior,
    this.anchoInterior,
    this.tTitulo,
  );
}

/// Página de inicio (antes de iniciar sesión): presenta la Fundación, sus logros,
/// los perritos, cómo ayudar y cómo encontrarla. Arriba: Iniciar sesión y Registrarse.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  List<Pet> _pets = [];
  bool _cargando = true;
  bool _error = false;

  final _kAyuda = GlobalKey();
  final _kLogros = GlobalKey();
  final _scrollCtrl = ScrollController();
  bool _haAnimadoLogros = false;

  @override
  void initState() {
    super.initState();
    FundacionService.cargar();
    _cargar();
    _scrollCtrl.addListener(_verificarVisibilidadLogros);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarVisibilidadLogros();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_verificarVisibilidadLogros);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _verificarVisibilidadLogros() {
    if (_haAnimadoLogros || !mounted) return;
    final contextLogros = _kLogros.currentContext;
    if (contextLogros != null) {
      final renderBox = contextLogros.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final posicion = renderBox.localToGlobal(Offset.zero);
        final altoPantalla = MediaQuery.sizeOf(context).height;
        if (posicion.dy <= altoPantalla * 0.92 &&
            (posicion.dy + renderBox.size.height) >= 0) {
          setState(() => _haAnimadoLogros = true);
        }
      }
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = false;
    });
    try {
      final pets = await PetsService.listar();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _cargando = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verificarVisibilidadLogros();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _cargando = false;
      });
    }
  }

  void _irLogin() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
  void _irRegistro() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const RegisterScreen()),
  );

  void _bajarA(GlobalKey clave) {
    final contexto = clave.currentContext;
    if (contexto == null) return;
    Scrollable.ensureVisible(
      contexto,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  /// Al tocar un perrito o "Quiero adoptar / apadrinar": invita a crear cuenta o entrar.
  void _pedirCuenta({Pet? pet, required bool adopcion}) {
    final accion = adopcion ? 'adoptar' : 'apadrinar';
    final titulo = pet == null
        ? 'Crea tu cuenta para continuar'
        : '¿Quieres $accion a ${pet.nombre}?';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, size: 40, color: AppColors.rosa),
                const SizedBox(height: 12),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: t.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.texto,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Para continuar necesitas una cuenta. Es gratis y toma un minuto.',
                  textAlign: TextAlign.center,
                  style: t.bodyLarge,
                ),
                const SizedBox(height: 20),
                BotonLanding(
                  texto: 'Crear cuenta',
                  expandido: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _irRegistro();
                  },
                ),
                const SizedBox(height: 10),
                BotonLanding(
                  texto: 'Ya tengo cuenta',
                  expandido: true,
                  relleno: false,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _irLogin();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width < 60 || size.height < 60) {
      return const Scaffold(backgroundColor: AppColors.rosaSuave);
    }
    final ancho = size.width;
    final escritorio = ancho >= Layout.escritorio;
    final pad = escritorio ? 24.0 : (ancho < 380 ? 10.0 : 14.0);
    final interior = escritorio ? 40.0 : (ancho < 600 ? 16.0 : 24.0);
    final contenido = math.max(
      0.0,
      math.min(ancho, Layout.anchoMaximo) - 2 * pad,
    );
    final anchoInterior = math.max(0.0, contenido - 2 * interior);
    final m = _Medidas(
      escritorio,
      ancho,
      interior,
      anchoInterior,
      escritorio ? 38 : (ancho < 380 ? 22 : 26),
    );
    const separacion = SizedBox(height: 16);

    return Scaffold(
      backgroundColor: AppColors.rosaSuave,
      body: Column(
        children: [
          LandingBarra(onIniciarSesion: _irLogin, onRegistrarse: _irRegistro),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: FundacionInfo.cambios,
              builder: (context, _, _) =>
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      _verificarVisibilidadLogros();
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: Layout.anchoMaximo,
                          ),
                          child: Column(
                            children: [
                              _hero(m),
                              Padding(
                                padding: EdgeInsets.fromLTRB(pad, 6, pad, 80),
                                child: Column(
                                  children: [
                                    if (FundacionInfo
                                            .rescatistaNombre
                                            .isNotEmpty ||
                                        FundacionInfo
                                            .rescatistaTexto
                                            .isNotEmpty ||
                                        FundacionInfo
                                            .fotoRescatista
                                            .isNotEmpty) ...[
                                      _rescatista(m),
                                      separacion,
                                    ],
                                    _mision(m),
                                    separacion,
                                    _perritos(m),
                                    separacion,
                                    _denuncias(m),
                                    separacion,
                                    _ayuda(m),
                                    const SizedBox(height: 14),
                                    Text(
                                      '© ${DateTime.now().year} Paw Match · ${FundacionInfo.nombre} · ${FundacionInfo.ciudad}',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
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
          ),
        ],
      ),
    );
  }

  // ───────────── 1. Presentación (retrato primero, luego el texto y la ubicación) ─────────────
  Widget _hero(_Medidas m) {
    final pad = m.escritorio ? 36.0 : (m.ancho < 380 ? 14.0 : 20.0);
    final disponible = math.max(
      140.0,
      math.min(m.ancho, Layout.anchoMaximo) - 2 * pad,
    );
    final compacto = m.ancho < 768;

    final double lado;
    if (m.escritorio) {
      lado = 220.0;
    } else if (m.ancho >= 600) {
      lado = 180.0;
    } else {
      lado = (disponible * 0.46).clamp(132.0, 168.0);
    }

    final detalle = _heroDetalle(compacto: compacto, muyCompacto: m.ancho < 420);
    final cuerpo = Column(
      children: [
        Center(child: _RetratoHero(lado: lado)),
        SizedBox(height: m.ancho < 480 ? 8 : 12),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: m.ancho < 480 ? 12 : 8,
          ),
          child: detalle,
        ),
      ],
    );

    return Column(
      children: [
        Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: FondoHeroPainter()),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 8, pad, 16),
              child: _heroTitulo(compacto: compacto, ancho: m.ancho),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 6, pad, 4),
          child: cuerpo,
        ),
      ],
    );
  }

  /// Nombre de la fundación, centrado y sobre el degradado corto.
  Widget _heroTitulo({required bool compacto, required double ancho}) {
    final nombre = FundacionInfo.nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
    final tamTitulo = ancho < 360 ? 26.0 : (compacto ? 32.0 : 44.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CONOCE NUESTRA',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.94),
            fontFamily: 'Nunito',
            fontSize: compacto ? 11.5 : 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
            height: 1.1,
          ),
        ),
        if (nombre.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            nombre.toUpperCase().split(' ').join('\n'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              color: Colors.white,
              fontSize: tamTitulo,
              fontWeight: FontWeight.w800,
              height: 1.06,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }

  /// Historia centrada y, debajo, la ciudad también centrada.
  Widget _heroDetalle({required bool compacto, required bool muyCompacto}) {
    final ciudad = FundacionInfo.ciudad.trim();
    final historia = FundacionInfo.historia.trim();
    final ciudadTexto = ciudad.endsWith('.')
        ? ciudad.substring(0, ciudad.length - 1)
        : ciudad;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (historia.isNotEmpty)
          Text(
            historia,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF5E565A),
              fontSize: muyCompacto ? 12.5 : (compacto ? 14 : 16),
              height: muyCompacto ? 1.42 : 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        if (ciudad.isNotEmpty) ...[
          if (historia.isNotEmpty) SizedBox(height: muyCompacto ? 10 : 14),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: AppColors.rosa,
                  size: muyCompacto ? 16 : (compacto ? 18 : 22),
                ),
                const SizedBox(width: 5),
                Text(
                  'En $ciudadTexto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                    fontSize: muyCompacto ? 13.5 : (compacto ? 15 : 17),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ───────────── 2. Nuestra misión (dos fotos arriba y el texto debajo de cada una) ─────────────
  Widget _mision(_Medidas m) {
    final t = Theme.of(context).textTheme;
    final que = _TarjetaMision(
      titulo: 'Lo que hacemos',
      texto: FundacionInfo.mision,
      rutaImagen: 'assets/images/inicio/familia.jpg',
      iconoFallback: Icons.pets_rounded,
    );
    final queremos = _TarjetaMision(
      titulo: 'Lo que queremos',
      texto: FundacionInfo.vision,
      rutaImagen: 'assets/images/inicio/juntos.jpg',
      iconoFallback: Icons.favorite_rounded,
    );

    return BloqueLanding(
      color: Colors.white,
      padding: EdgeInsets.all(m.ancho < 600 ? 14.0 : m.interior),
      child: Column(
        children: [
          Text(
            'TRABAJANDO EN PRO DE LOS ANIMALES',
            textAlign: TextAlign.center,
            style: t.labelLarge?.copyWith(
              letterSpacing: m.ancho < 400 ? 1.3 : 2.2,
              color: AppColors.rosa,
              fontWeight: FontWeight.w800,
              fontSize: m.escritorio ? 12.5 : 10.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'NUESTRA MISIÓN',
            textAlign: TextAlign.center,
            style: t.headlineMedium?.copyWith(
              fontFamily: 'Nunito',
              fontSize: m.tTitulo,
              fontWeight: FontWeight.w800,
              color: AppColors.texto,
            ),
          ),
          SizedBox(height: m.ancho < 600 ? 14 : 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;
              final sep = maxW < 500 ? 10.0 : (maxW < 850 ? 16.0 : 24.0);
              if (maxW >= 260) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: que),
                    SizedBox(width: sep),
                    Expanded(child: queremos),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [que, const SizedBox(height: 12), queremos],
              );
            },
          ),
          SizedBox(height: m.ancho < 600 ? 16 : 24),
          BotonLanding(
            texto: '¿Cómo ayudar?',
            icono: Icons.volunteer_activism_outlined,
            onPressed: () => _bajarA(_kAyuda),
          ),
        ],
      ),
    );
  }

  // ───────────── 3. Nuestra rescatista (foto completa arriba y textos centrados) ─────────────
  Widget _rescatista(_Medidas m) {
    final t = Theme.of(context).textTheme;
    final compacto = m.ancho < 680;
    final muyCompacto = m.ancho < 420;

    return ClipRRect(
      borderRadius: BorderRadius.circular(compacto ? 24 : 32),
      child: ColoredBox(
        color: AppColors.rosaClaro,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                muyCompacto ? 6 : 10,
                muyCompacto ? 14 : 18,
                muyCompacto ? 6 : 10,
                0,
              ),
              child: LayoutBuilder(
                builder: (context, limites) {
                  final anchoFoto = (limites.maxWidth * 0.64)
                      .clamp(168.0, compacto ? 250.0 : 280.0);
                  return SizedBox(
                    height: anchoFoto * 4 / 3,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(child: _AdornoRescatista(izquierda: true)),
                        SizedBox(
                          width: anchoFoto,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              compacto ? 18 : 22,
                            ),
                            child: FundacionImagen(
                              ruta: FundacionInfo.fotoRescatista,
                              fit: BoxFit.contain,
                              fondo: AppColors.rosaClaro,
                              icono: Icons.volunteer_activism,
                              tamanoIcono: compacto ? 40 : 64,
                            ),
                          ),
                        ),
                        const Expanded(child: _AdornoRescatista(izquierda: false)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                muyCompacto ? 16 : (compacto ? 24 : 36),
                muyCompacto ? 14 : 18,
                muyCompacto ? 16 : (compacto ? 24 : 36),
                muyCompacto ? 16 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: muyCompacto ? 8 : 10,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'NUESTRA RESCATISTA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.rosa,
                        fontWeight: FontWeight.w800,
                        fontSize: muyCompacto ? 9.5 : (compacto ? 10.5 : 12),
                        letterSpacing: muyCompacto ? 0.7 : 1.2,
                      ),
                    ),
                  ),
                  SizedBox(height: muyCompacto ? 8 : 10),
                  Text(
                    FundacionInfo.rescatistaNombre,
                    textAlign: TextAlign.center,
                    style: (compacto ? t.titleLarge : t.headlineSmall)?.copyWith(
                      fontFamily: 'Nunito',
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                      fontSize: muyCompacto ? 18 : (compacto ? 22 : 26),
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: muyCompacto ? 8 : 10),
                  Text(
                    FundacionInfo.rescatistaTexto,
                    textAlign: TextAlign.center,
                    style: t.bodyLarge?.copyWith(
                      fontSize: muyCompacto ? 13.0 : (compacto ? 14.5 : 16),
                      height: muyCompacto ? 1.4 : 1.5,
                      color: AppColors.texto,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────── Logros (organizados en 2 columnas en móvil/tablet y 4 en escritorio) ─────────────
  Widget _logros(_Medidas m) {
    final totalAyudados = _pets.isNotEmpty ? _pets.length : 4;
    final disponibles = _pets.isNotEmpty
        ? _pets.where((p) => p.estadoAdopcion == 'disponible').length
        : 3;
    final adoptados = _pets.isNotEmpty
        ? _pets.where((p) => p.estadoAdopcion == 'adoptado').length
        : 1;
    final apadrinados = _pets.isNotEmpty
        ? _pets.where((p) => p.estadoApadrinamiento == 'apadrinado').length
        : 2;

    final items = [
      StatLogro(
        icono: Icons.pets_rounded,
        valorNumero: totalAyudados,
        cargando: _cargando,
        error: _error,
        animar: _haAnimadoLogros,
        etiqueta: 'Perritos que hemos ayudado',
      ),
      StatLogro(
        icono: Icons.home_rounded,
        valorNumero: disponibles,
        cargando: _cargando,
        error: _error,
        animar: _haAnimadoLogros,
        etiqueta: 'Esperando un hogar',
      ),
      StatLogro(
        icono: Icons.favorite_rounded,
        valorNumero: adoptados,
        cargando: _cargando,
        error: _error,
        animar: _haAnimadoLogros,
        etiqueta: 'Adopciones logradas',
      ),
      StatLogro(
        icono: Icons.volunteer_activism_rounded,
        valorNumero: apadrinados,
        cargando: _cargando,
        error: _error,
        animar: _haAnimadoLogros,
        etiqueta: 'Perritos apadrinados',
      ),
    ];

    return KeyedSubtree(
      key: _kLogros,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.60),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'HUELLITAS QUE DEJAN MARCA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: m.ancho < 380 ? 10 : 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'NUESTROS LOGROS',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: m.tTitulo + 2,
              letterSpacing: 0.5,
              shadows: const [
                Shadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cada número representa una vida transformada con amor',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: m.ancho < 400 ? 12.5 : 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: m.ancho < 600 ? 18 : 26),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth.isFinite
                  ? math.max(0.0, constraints.maxWidth)
                  : 0.0;
              if (maxW <= 0) return const SizedBox.shrink();
              final sep = maxW < 420 ? 10.0 : 14.0;
              final columnas = maxW >= 720 ? 4 : (maxW >= 200 ? 2 : 1);
              final anchoTarjeta = math.max(
                0.0,
                (maxW - sep * (columnas - 1)) / columnas,
              );
              return Wrap(
                spacing: sep,
                runSpacing: sep,
                alignment: WrapAlignment.center,
                children: [
                  for (final item in items)
                    SizedBox(width: anchoTarjeta, child: item),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ───────────── Perritos en adopción ─────────────
  Widget _perritos(_Medidas m) {
    final perros = _pets
        .where((p) => p.especie.toLowerCase() == 'perro')
        .where((p) => p.estadoAdopcion == 'disponible')
        .toList();

    Widget cuerpo;
    if (_cargando) {
      cuerpo = const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      );
    } else if (_error) {
      cuerpo = Column(
        children: [
          const Icon(Icons.cloud_off, size: 40, color: AppColors.rosa),
          const SizedBox(height: 8),
          const Text('No pudimos cargar a los perritos. Revisa tu conexión.'),
          TextButton(onPressed: _cargar, child: const Text('Reintentar')),
        ],
      );
    } else if (perros.isEmpty) {
      cuerpo = const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Pronto tendremos nuevos peluditos en esta categoría.',
          textAlign: TextAlign.center,
        ),
      );
    } else {
      cuerpo = PerritosCarrusel(
        perros: perros,
        onPedirCuenta: (p) => _pedirCuenta(pet: p, adopcion: true),
      );
    }

    return BloqueLanding(
      color: Colors.white,
      padding: EdgeInsets.all(m.ancho < 600 ? 14.0 : m.interior),
      child: Column(
        children: [
          TituloLanding(
            texto: 'Conoce a nuestros',
            acento: 'perritos',
            color: AppColors.texto,
            colorAcento: AppColors.rosa,
            tamano: m.tTitulo,
            alineacion: TextAlign.center,
          ),
          const SizedBox(height: 18),
          cuerpo,
        ],
      ),
    );
  }

  // ───────────── Sección Denuncias y Protección Animal (horizontal: texto + imagen lado a lado) ─────────────
  Widget _denuncias(_Medidas m) {
    final t = Theme.of(context).textTheme;
    final compacto = m.ancho < 640;
    final muyCompacto = m.ancho < 420;

    final titulo = Text.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: muyCompacto ? 17 : (compacto ? 21 : 28),
          fontWeight: FontWeight.w800,
          height: 1.18,
        ),
        children: const [
          TextSpan(
            text: 'Ayúdanos a ',
            style: TextStyle(color: AppColors.texto),
          ),
          TextSpan(
            text: 'proteger a los animales',
            style: TextStyle(color: AppColors.rosa),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );

    final parrafo = Text(
      'Si conoces una situación en la que un animal esté sufriendo maltrato, haya sido abandonado o se encuentre en condiciones que pongan en riesgo su bienestar, cuéntanos lo que sucede. Tu voz puede marcar la diferencia y salvar una vida.',
      style: t.bodyLarge?.copyWith(
        fontSize: muyCompacto ? 12 : (compacto ? 13.5 : 15.5),
        height: muyCompacto ? 1.38 : 1.5,
        color: const Color(0xFF5E565A),
      ),
    );

    final boton = BotonLanding(
      texto: 'Reportar un caso',
      icono: Icons.campaign_outlined,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DenunciaReporteScreen()),
        );
      },
    );

    final anchoImg = muyCompacto
        ? 105.0
        : (compacto ? 155.0 : (m.escritorio ? 290.0 : 210.0));
    final altoImg = muyCompacto
        ? 165.0
        : (compacto ? 190.0 : (m.escritorio ? 290.0 : 210.0));

    final imagen = ClipRRect(
      borderRadius: BorderRadius.circular(muyCompacto ? 18 : 24),
      child: Container(
        color: AppColors.rosaSuave,
        width: anchoImg,
        height: altoImg,
        child: Image.asset(
          'assets/images/denuncias_hero.jpg',
          fit: BoxFit.cover,
        ),
      ),
    );

    final etiqueta = Container(
      padding: EdgeInsets.symmetric(
        horizontal: muyCompacto ? 8 : 11,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            size: muyCompacto ? 12 : 14,
            color: AppColors.rosa,
          ),
          const SizedBox(width: 5),
          Text(
            'PROTECCIÓN ANIMAL',
            style: TextStyle(
              fontSize: muyCompacto ? 9.5 : 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.rosa,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );

    return BloqueLanding(
      color: Colors.white,
      padding: EdgeInsets.all(muyCompacto ? 14.0 : (compacto ? 18.0 : m.interior)),
      child: Column(
        children: [
          etiqueta,
          SizedBox(height: muyCompacto ? 8 : 12),
          titulo,
          SizedBox(height: muyCompacto ? 10 : 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: parrafo),
              SizedBox(width: muyCompacto ? 12 : (compacto ? 18 : 28)),
              imagen,
            ],
          ),
          SizedBox(height: muyCompacto ? 12 : 18),
          boton,
        ],
      ),
    );
  }

  // ───────────── 6. Ayuda y contacto (2 columnas lado a lado en móvil, tablet y PC) ─────────────
  Widget _ayuda(_Medidas m) {
    final adopta = TarjetaAyuda(
      icono: Icons.home_outlined,
      titulo: FundacionInfo.ayudaAdoptaTitulo,
      texto: FundacionInfo.ayudaAdoptaTexto,
    );
    final apadrina = TarjetaAyuda(
      icono: Icons.volunteer_activism,
      titulo: FundacionInfo.ayudaApadrinaTitulo,
      texto: FundacionInfo.ayudaApadrinaTexto,
    );

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(m.ancho < 600 ? 24 : 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: m.escritorio ? 340 : 0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: FundacionImagen(
                    ruta: FundacionInfo.fotoFondoAyudas,
                    fit: BoxFit.cover,
                    icono: Icons.pets,
                    fondo: const Color(0xFFF9B0CE),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFDCADA),
                          Color(0xFFF9B0CE),
                          Color(0xFFF396BF),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -40,
                  left: 30,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  right: 40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: m.ancho < 600 ? 12.0 : m.interior,
                    vertical: m.escritorio ? 38 : 24,
                  ),
                  child: _logros(m),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _kAyuda,
          child: BloqueLanding(
          color: AppColors.rosaClaro,
          padding: EdgeInsets.all(m.ancho < 600 ? 14.0 : m.interior),
          child: Column(
            children: [
              TituloLanding(
                texto: 'Encuéntranos',
                acento: 'y ayúdanos',
                color: AppColors.texto,
                colorAcento: AppColors.rosa,
                tamano: m.tTitulo,
                alineacion: TextAlign.center,
              ),
              SizedBox(height: m.ancho < 600 ? 14 : 20),
              // Tarjetas ADOPTA y APADRINA siempre en 2 columnas lado a lado (incluyendo celular)
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth.isFinite
                      ? math.max(0.0, constraints.maxWidth)
                      : 0.0;
                  if (maxW <= 0) return const SizedBox.shrink();
                  final sep = maxW < 420 ? 10.0 : 16.0;
                  if (maxW >= 240) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: adopta),
                        SizedBox(width: sep),
                        Expanded(child: apadrina),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [adopta, SizedBox(height: sep), apadrina],
                  );
                },
              ),
              SizedBox(height: m.ancho < 600 ? 14 : 20),
              _contactoContenido(m),
            ],
          ),
        ),
        ),
      ],
    );
  }

  // ───────────── 7. Dónde encontrarnos (Ubicación y Contacto lado a lado) ─────────────
  Widget _contactoContenido(_Medidas m) {
    final t = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final enDosColumnas = maxW >= 260;
        final sep = maxW < 420 ? 10.0 : 18.0;
        final anchoCol = enDosColumnas ? (maxW - sep) / 2 : maxW;
        final compacto = anchoCol < 215;
        final muyCompacto = anchoCol < 165;
        final pad = muyCompacto ? 12.0 : (compacto ? 15.0 : 20.0);
        final tamTitulo = muyCompacto ? 11.5 : (compacto ? 12.5 : 15.0);
        final tamTexto = muyCompacto ? 11.5 : (compacto ? 12.5 : 14.0);

        Widget encabezadoTarjeta(IconData icono, String titulo) {
          final tamCaja = muyCompacto ? 32.0 : (compacto ? 36.0 : 42.0);
          final tamIcono = muyCompacto ? 16.0 : (compacto ? 18.0 : 22.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: tamCaja,
                height: tamCaja,
                decoration: const BoxDecoration(
                  color: AppColors.rosaSuave,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: AppColors.rosa, size: tamIcono),
              ),
              SizedBox(width: muyCompacto ? 7 : 10),
              Expanded(
                child: Text(
                  titulo,
                  softWrap: true,
                  style: t.titleMedium?.copyWith(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: tamTitulo,
                    color: AppColors.texto,
                    letterSpacing: 0.15,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          );
        }

        final ubicacion = Container(
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(compacto ? 20 : 24),
            border: Border.all(
              color: AppColors.bordeRosa.withValues(alpha: 0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.rosa.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              encabezadoTarjeta(Icons.location_on_rounded, 'UBICACIÓN'),
              SizedBox(height: muyCompacto ? 9 : 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.place_outlined,
                      size: muyCompacto ? 14 : 17,
                      color: AppColors.rosa,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      FundacionInfo.direccion,
                      style: t.bodyMedium?.copyWith(
                        color: const Color(0xFF5E565A),
                        height: 1.35,
                        fontSize: tamTexto,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.location_city_outlined,
                      size: muyCompacto ? 14 : 17,
                      color: AppColors.rosa,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      FundacionInfo.ciudad,
                      style: t.bodyMedium?.copyWith(
                        color: const Color(0xFF5E565A),
                        height: 1.35,
                        fontSize: tamTexto,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (FundacionInfo.mapaUrl.isNotEmpty) ...[
                SizedBox(height: muyCompacto ? 10 : 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rosa,
                      side: const BorderSide(color: AppColors.rosa, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => abrirEnlace(
                      context,
                      FundacionInfo.mapaUrl,
                      nombre: 'el mapa',
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Google Maps',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: tamTexto,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );

        final donar = Container(
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(compacto ? 20 : 24),
            border: Border.all(
              color: AppColors.bordeRosa.withValues(alpha: 0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.rosa.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              encabezadoTarjeta(
                Icons.favorite_border_rounded,
                'CONTACTO Y REDES',
              ),
              SizedBox(height: muyCompacto ? 9 : 14),
              const RedesSociales(conTexto: true),
            ],
          ),
        );

        if (enDosColumnas) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ubicacion),
              SizedBox(width: sep),
              Expanded(child: donar),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [ubicacion, SizedBox(height: sep), donar],
        );
      },
    );
  }
}

/// Corazones, huellas y hojas a un lado de la foto de la rescatista.
class _AdornoRescatista extends StatelessWidget {
  final bool izquierda;
  const _AdornoRescatista({required this.izquierda});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limites) {
        final icono = (limites.maxHeight * 0.065).clamp(15.0, 26.0);
        final rosa = AppColors.rosa;
        Widget punto(double tam, Color color) {
          return Container(
            width: tam,
            height: tam,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          );
        }

        final piezas = <Widget>[
          Icon(Icons.favorite_rounded, color: rosa, size: icono),
          punto(icono * 0.36, Colors.white.withValues(alpha: 0.95)),
          Icon(Icons.pets_rounded, color: rosa.withValues(alpha: 0.7), size: icono * 0.82),
          punto(icono * 0.26, rosa.withValues(alpha: 0.35)),
          Icon(
            Icons.favorite_border_rounded,
            color: rosa.withValues(alpha: 0.85),
            size: icono * 0.9,
          ),
          SizedBox(height: icono * 1.15),
        ];

        return Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: izquierda ? piezas : piezas.reversed.toList(),
            ),
            Positioned(
              left: izquierda ? null : 0,
              right: izquierda ? 0 : null,
              bottom: limites.maxHeight * 0.03,
              child: CustomPaint(
                size: Size(icono * 2.4, icono * 2.0),
                painter: _RamoHojas(haciaDerecha: !izquierda),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Degradado rosado que termina en el mismo rosa pastel del resto de la página.
class FondoHeroPainter extends CustomPainter {
  const FondoHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFFA3C8),
        Color(0xFFF98BB8),
        AppColors.rosaSuave,
      ],
      stops: [0.0, 0.55, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);

    void burbuja(double x, double y, double radio, double alpha) {
      canvas.drawCircle(
        Offset(x, y),
        radio,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    final escala = math.min(size.width, 420);
    burbuja(size.width * 0.12, size.height * 0.18, escala * 0.14, 0.20);
    burbuja(size.width * 0.92, size.height * 0.12, escala * 0.16, 0.16);
    burbuja(size.width * 0.62, size.height * 0.08, escala * 0.07, 0.14);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Retrato circular de la imagen principal, con aro, corazón y hojas.
class _RetratoHero extends StatelessWidget {
  final double lado;
  const _RetratoHero({required this.lado});

  @override
  Widget build(BuildContext context) {
    final anillo = lado * 0.05;
    final ancho = lado * 1.36;
    final alto = lado * 1.12;
    return SizedBox(
      width: ancho,
      height: alto,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: lado * 0.04,
            child: CustomPaint(
              size: Size(lado * 0.40, lado * 0.34),
              painter: const _RamoHojas(haciaDerecha: false),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: CustomPaint(
              size: Size(lado * 0.38, lado * 0.32),
              painter: const _RamoHojas(haciaDerecha: true),
            ),
          ),
          Positioned(
            left: lado * 0.15,
            top: lado * 0.07,
            child: Container(
              width: lado,
              height: lado,
              padding: EdgeInsets.all(anillo),
              decoration: const BoxDecoration(
                color: AppColors.rosa,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: FundacionImagen(
                  ruta: FundacionInfo.imagenPrincipal,
                  fit: BoxFit.cover,
                  icono: Icons.volunteer_activism,
                  tamanoIcono: lado * 0.42,
                ),
              ),
            ),
          ),
          Positioned(
            right: lado * 0.02,
            top: 0,
            child: CustomPaint(
              size: Size(lado * 0.24, lado * 0.22),
              painter: const _CorazonContorno(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CorazonContorno extends CustomPainter {
  const _CorazonContorno();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.50, h * 0.90)
      ..cubicTo(w * -0.02, h * 0.46, w * 0.18, h * 0.02, w * 0.50, h * 0.34)
      ..cubicTo(w * 0.82, h * 0.02, w * 1.02, h * 0.46, w * 0.50, h * 0.90)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.4, w * 0.075)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.rosa,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RamoHojas extends CustomPainter {
  final bool haciaDerecha;
  const _RamoHojas({required this.haciaDerecha});

  void _hoja(
    Canvas canvas,
    double angulo,
    double largo,
    double grosor,
    Color color,
  ) {
    canvas.save();
    canvas.rotate(angulo);
    final hoja = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(grosor, -largo * 0.45, 0, -largo)
      ..quadraticBezierTo(-grosor * 0.72, -largo * 0.38, 0, 0)
      ..close();
    canvas.drawPath(hoja, Paint()..color = color);
    canvas.drawLine(
      Offset(0, -largo * 0.12),
      Offset(0, -largo * 0.78),
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(
      haciaDerecha ? size.width * 0.30 : size.width * 0.70,
      size.height * 0.28,
    );
    final base = haciaDerecha ? 0.42 : math.pi - 0.42;
    final dir = haciaDerecha ? 1.0 : -1.0;
    _hoja(
      canvas,
      base - dir * 0.58,
      size.height * 0.70,
      size.width * 0.16,
      const Color(0xFFF48FB1),
    );
    _hoja(
      canvas,
      base,
      size.height * 0.92,
      size.width * 0.18,
      AppColors.rosa,
    );
    _hoja(
      canvas,
      base + dir * 0.52,
      size.height * 0.58,
      size.width * 0.13,
      const Color(0xFFD81B60),
    );
  }

  @override
  bool shouldRepaint(covariant _RamoHojas oldDelegate) =>
      oldDelegate.haciaDerecha != haciaDerecha;
}

/// Apartado de la sección de misión («LO QUE HACEMOS» / «LO QUE QUEREMOS»):
/// la fotografía va arriba y el texto, centrado, debajo.
class _TarjetaMision extends StatelessWidget {
  final String titulo, texto, rutaImagen;
  final IconData iconoFallback;

  const _TarjetaMision({
    required this.titulo,
    required this.texto,
    required this.rutaImagen,
    required this.iconoFallback,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final muyCompacto = w < 185;
        final compacto = w < 260;

        final pad = muyCompacto ? 10.0 : (compacto ? 12.0 : 16.0);
        final tamTitulo = muyCompacto ? 11.0 : (compacto ? 12.5 : 15.5);
        final tamTexto = muyCompacto ? 11.0 : (compacto ? 12.5 : 14.5);
        final radio = compacto ? 18.0 : 24.0;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.rosaSuave.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(radio),
            border: Border.all(
              color: AppColors.bordeRosa.withValues(alpha: 0.7),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: muyCompacto ? 1 : 4 / 3,
                child: Image.asset(
                  rutaImagen,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.rosaClaro,
                    child: Icon(
                      iconoFallback,
                      color: AppColors.rosa,
                      size: muyCompacto ? 28 : 36,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 2),
                child: Column(
                  children: [
                    Text(
                      titulo.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: t.titleMedium?.copyWith(
                        fontFamily: 'Nunito',
                        fontSize: tamTitulo,
                        letterSpacing: muyCompacto ? 0.2 : 0.6,
                        fontWeight: FontWeight.w800,
                        color: AppColors.texto,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: muyCompacto ? 22 : 30,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: AppColors.rosa,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: muyCompacto ? 6 : 8),
                    Text(
                      texto,
                      textAlign: TextAlign.center,
                      style: t.bodyLarge?.copyWith(
                        fontSize: tamTexto,
                        height: muyCompacto ? 1.35 : 1.45,
                        color: AppColors.texto,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
