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
        if (posicion.dy <= altoPantalla * 0.92 && (posicion.dy + renderBox.size.height) >= 0) {
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
    final ancho = MediaQuery.sizeOf(context).width;
    final escritorio = ancho >= Layout.escritorio;
    final pad = escritorio ? 24.0 : 16.0;
    final interior = escritorio ? 40.0 : 22.0;
    final contenido = math.max(0.0, math.min(ancho, Layout.anchoMaximo) - 2 * pad);
    final anchoInterior = math.max(0.0, contenido - 2 * interior);
    final m = _Medidas(
      escritorio,
      ancho,
      interior,
      anchoInterior,
      escritorio ? 40 : 28,
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
              builder: (context, _, _) => NotificationListener<ScrollNotification>(
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
                            padding: EdgeInsets.fromLTRB(pad, 16, pad, 90),
                            child: Column(
                              children: [
                          if (FundacionInfo.rescatistaNombre.isNotEmpty ||
                              FundacionInfo.rescatistaTexto.isNotEmpty ||
                              FundacionInfo.fotoRescatista.isNotEmpty) ...[
                            _rescatista(m),
                            separacion,
                          ],
                          _mision(m),
                          separacion,
                          _perritos(m),
                          separacion,
                          _denuncias(m),
                          separacion,
                          KeyedSubtree(key: _kAyuda, child: _ayuda(m)),
                          const SizedBox(height: 12),
                          Text(
                            '© ${DateTime.now().year} Paw Match · ${FundacionInfo.nombre} · ${FundacionInfo.ciudad}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
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

  // ───────────── 1. Presentación ─────────────
  Widget _hero(_Medidas m) {
    final enFila = m.ancho >= 800;
    final lado = enFila
        ? (m.escritorio ? 280.0 : 220.0)
        : math.min(230.0, math.max(170.0, m.ancho * 0.52));
    final pad = m.escritorio ? 36.0 : 22.0;
    final compacto = !enFila;

    final detalle = _heroDetalle(compacto: compacto);
    final retrato = _RetratoHero(lado: lado);
    final cuerpo = enFila
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: detalle),
              const SizedBox(width: 28),
              retrato,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              detalle,
              const SizedBox(height: 18),
              Center(child: retrato),
            ],
          );

    return Column(
      children: [
        Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _FondoHeroPainter()),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 6, pad, 52),
              child: _heroTitulo(compacto: compacto),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 6, pad, 8),
          child: cuerpo,
        ),
      ],
    );
  }

  /// Nombre de la fundación, centrado y sobre el degradado corto.
  Widget _heroTitulo({required bool compacto}) {
    final nombre = FundacionInfo.nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
    final tamTitulo = compacto ? 34.0 : 46.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CONOCE NUESTRA',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontFamily: 'Nunito',
            fontSize: compacto ? 12 : 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.8,
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
              height: 1.05,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }

  /// Ciudad, descripción e imagen siguen saliendo de la base de datos.
  Widget _heroDetalle({required bool compacto}) {
    final ciudad = FundacionInfo.ciudad.trim();
    final historia = FundacionInfo.historia.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ciudad.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.location_on,
                  color: AppColors.rosa,
                  size: compacto ? 18 : 22,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'En ${ciudad.endsWith('.') ? ciudad.substring(0, ciudad.length - 1) : ciudad}.',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                    fontSize: compacto ? 14.5 : 16.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        if (historia.isNotEmpty) ...[
          if (ciudad.isNotEmpty) SizedBox(height: compacto ? 8 : 10),
          Text(
            historia,
            style: TextStyle(
              color: const Color(0xFF6E676A),
              fontSize: compacto ? 14.5 : 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  // ───────────── 2. Nuestra misión ─────────────
  Widget _mision(_Medidas m) {
    final t = Theme.of(context).textTheme;
    final que = _ColumnaTexto(
      titulo: 'Lo que hacemos',
      texto: FundacionInfo.mision,
    );
    final queremos = _ColumnaTexto(
      titulo: 'Lo que queremos',
      texto: FundacionInfo.vision,
    );
    return BloqueLanding(
      color: Colors.white,
      padding: EdgeInsets.all(m.interior),
      child: Column(
        children: [
          Text(
            'TRABAJANDO EN PRO DE LOS ANIMALES',
            textAlign: TextAlign.center,
            style: t.labelLarge?.copyWith(
              letterSpacing: 2.5,
              color: AppColors.rosa,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'NUESTRA MISIÓN',
            textAlign: TextAlign.center,
            style: t.headlineMedium?.copyWith(
              fontSize: m.tTitulo + 4,
              fontWeight: FontWeight.w800,
              color: AppColors.texto,
            ),
          ),
          const SizedBox(height: 28),
          m.escritorio
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: que),
                    const SizedBox(width: 40),
                    Expanded(child: queremos),
                  ],
                )
              : Column(children: [que, const SizedBox(height: 24), queremos]),
          const SizedBox(height: 28),
          BotonLanding(
            texto: '¿Cómo ayudar?',
            onPressed: () => _bajarA(_kAyuda),
          ),
        ],
      ),
    );
  }

  // ───────────── 3. Nuestra rescatista ─────────────
  Widget _rescatista(_Medidas m) {
    final t = Theme.of(context).textTheme;
    final esMovil = m.ancho < 700;

    final foto = FundacionImagen(
      ruta: FundacionInfo.fotoRescatista,
      fit: BoxFit.cover,
      icono: Icons.volunteer_activism,
      tamanoIcono: esMovil ? 44 : 64,
    );

    final panel = Container(
      color: AppColors.rosaClaro,
      padding: EdgeInsets.all(esMovil ? 14.0 : m.interior),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'NUESTRA RESCATISTA',
            style: (esMovil ? t.labelLarge : t.headlineSmall)?.copyWith(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: esMovil ? 11 : null,
              letterSpacing: esMovil ? 1.0 : null,
            ),
          ),
          SizedBox(height: esMovil ? 4 : 8),
          Text(
            FundacionInfo.rescatistaNombre,
            style: (esMovil ? t.titleMedium : t.titleLarge)?.copyWith(
              color: AppColors.rosa,
              fontWeight: FontWeight.w800,
              fontSize: esMovil ? 15 : null,
            ),
          ),
          SizedBox(height: esMovil ? 6 : 14),
          Text(
            FundacionInfo.rescatistaTexto,
            style: (esMovil ? t.bodyMedium : t.bodyLarge)?.copyWith(
              fontSize: esMovil ? 12 : null,
              height: esMovil ? 1.4 : 1.55,
              color: AppColors.texto,
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(esMovil ? 20 : 32),
      child: SizedBox(
        height: esMovil ? 220 : 380,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: esMovil ? 4 : 5, child: foto),
            Expanded(flex: esMovil ? 6 : 5, child: panel),
          ],
        ),
      ),
    );
  }

  // ───────────── Logros (datos reales de la base de datos) ─────────────
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

    const sep = 14.0;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.60),
                width: 1.2,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                SizedBox(width: 8),
                Text(
                  'HUELLITAS QUE DEJAN MARCA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 8),
          Text(
            'Cada número representa una vida transformada con amor',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth.isFinite
                  ? math.max(0.0, constraints.maxWidth)
                  : 0.0;
              if (maxW <= 0) return const SizedBox.shrink();
              final columnas = maxW >= 800 ? 4 : (maxW >= 340 ? 2 : 1);
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
        .take(4)
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
      padding: EdgeInsets.all(m.interior),
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
          const SizedBox(height: 24),
          cuerpo,
        ],
      ),
    );
  }

  // ───────────── Sección Denuncias y Protección Animal ─────────────
  Widget _denuncias(_Medidas m) {
    final t = Theme.of(context).textTheme;
    final esMovil = m.ancho < 700;

    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: esMovil ? 8 : 12,
            vertical: esMovil ? 3 : 5,
          ),
          decoration: BoxDecoration(
            color: AppColors.rosaSuave,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.bordeRosa),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: esMovil ? 12 : 15, color: AppColors.rosa),
              SizedBox(width: esMovil ? 4 : 6),
              Text(
                'PROTECCIÓN ANIMAL',
                style: TextStyle(
                  fontSize: esMovil ? 9.5 : 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.rosa,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: esMovil ? 8 : 14),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Ayúdanos a ',
              style: TextStyle(
                fontSize: esMovil ? 16 : (m.escritorio ? 28 : 22),
                fontWeight: FontWeight.w800,
                color: AppColors.texto,
                height: 1.2,
              ),
            ),
            Text(
              'proteger a los animales',
              style: TextStyle(
                fontSize: esMovil ? 16 : (m.escritorio ? 28 : 22),
                fontWeight: FontWeight.w800,
                color: AppColors.rosa,
                height: 1.2,
              ),
            ),
          ],
        ),
        SizedBox(height: esMovil ? 8 : 14),
        Text(
          'Si conoces una situación en la que un animal esté sufriendo maltrato, haya sido abandonado o se encuentre en condiciones que pongan en riesgo su bienestar, cuéntanos lo que sucede. Tu voz puede marcar la diferencia y salvar una vida.',
          style: (esMovil ? t.bodyMedium : t.bodyLarge)?.copyWith(
            fontSize: esMovil ? 12 : null,
            height: esMovil ? 1.4 : 1.55,
          ),
        ),
        SizedBox(height: esMovil ? 12 : 24),
        BotonLanding(
          texto: 'Reportar un caso',
          expandido: false,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DenunciaReporteScreen()),
            );
          },
        ),
      ],
    );

    final double tamanoImagen = esMovil
        ? math.min(145.0, math.max(100.0, m.ancho * 0.28))
        : (m.escritorio ? 320.0 : 220.0);

    final imagen = ClipRRect(
      borderRadius: BorderRadius.circular(esMovil ? 18 : 28),
      child: Container(
        color: AppColors.rosaSuave,
        width: tamanoImagen,
        height: tamanoImagen,
        child: Image.asset(
          'assets/images/denuncias_hero.jpg',
          fit: BoxFit.cover,
        ),
      ),
    );

    return BloqueLanding(
      color: Colors.white,
      padding: EdgeInsets.all(esMovil ? 16.0 : m.interior),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: textos),
          SizedBox(width: esMovil ? 12 : 32),
          imagen,
        ],
      ),
    );
  }

  // ───────────── 6. Ayuda y contacto ─────────────
  Widget _ayuda(_Medidas m) {
    final tarjetas = [
      TarjetaAyuda(
        icono: Icons.home_outlined,
        titulo: FundacionInfo.ayudaAdoptaTitulo,
        texto: FundacionInfo.ayudaAdoptaTexto,
      ),
      TarjetaAyuda(
        icono: Icons.volunteer_activism,
        titulo: FundacionInfo.ayudaApadrinaTitulo,
        texto: FundacionInfo.ayudaApadrinaTexto,
      ),
    ];

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: m.escritorio ? 350 : 0),
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
                          Color(0xFFFDCADA), // rosa empolvado suave
                          Color(0xFFF9B0CE), // rosa pastel intermedio
                          Color(0xFFF396BF), // rosa tierno delicado
                        ],
                      ),
                    ),
                  ),
                ),
                // Burbujas bokeh decorativas en tonos blancos y rosa suave
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
                Positioned(
                  top: 30,
                  right: 220,
                  child: Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: m.interior,
                    vertical: m.escritorio ? 40 : 32,
                  ),
                  child: _logros(m),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        BloqueLanding(
          color: AppColors.rosaClaro,
          padding: EdgeInsets.all(m.interior),
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
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth.isFinite
                      ? math.max(0.0, constraints.maxWidth)
                      : 0.0;
                  if (maxW <= 0) return const SizedBox.shrink();
                  final columnas = maxW >= Layout.tablet ? 2 : 1;
                  const sep = 14.0;
                  final w = math.max(
                    0.0,
                    (maxW - sep * (columnas - 1)) / columnas,
                  );
                  return Wrap(
                    spacing: sep,
                    runSpacing: sep,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final tarjeta in tarjetas)
                        SizedBox(width: w, child: tarjeta),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              _contactoContenido(m),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────── 7. Dónde encontrarnos ─────────────
  Widget _contactoContenido(_Medidas m) {
    final t = Theme.of(context).textTheme;
    final ubicacion = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on_outlined, color: AppColors.rosa),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'UBICACIÓN',
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.texto,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${FundacionInfo.nombre}\n${FundacionInfo.direccion}\n${FundacionInfo.ciudad}',
          style: t.bodyLarge?.copyWith(height: 1.5),
        ),
        if (FundacionInfo.mapaUrl.isNotEmpty) ...[
          const SizedBox(height: 14),
          BotonLanding(
            texto: 'Abrir ubicación en Google Maps',
            relleno: false,
            onPressed: () =>
                abrirEnlace(context, FundacionInfo.mapaUrl, nombre: 'el mapa'),
          ),
        ],
      ],
    );

    final donar = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.card_giftcard, color: AppColors.rosa),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'CONTACTO Y REDES',
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.texto,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (FundacionInfo.contactoTexto.isNotEmpty) ...[
          Text(
            FundacionInfo.contactoTexto,
            style: t.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
        ],
        const RedesSociales(conTexto: true),
      ],
    );

    return m.escritorio
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ubicacion),
              const SizedBox(width: 40),
              Expanded(child: donar),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [ubicacion, const SizedBox(height: 24), donar],
          );
  }
}

/// Degradado rosado con burbujas y onda blanca, como la pantalla de inicio.
class _FondoHeroPainter extends CustomPainter {
  const _FondoHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final base = size.height;
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

    canvas.drawRect(rect, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipPath(rosa);
    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFFA3C8),
        Color(0xFFF98BB8),
        Color(0xFFFDE4EF),
      ],
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
    canvas.restore();

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
    final alto = lado * 1.26;
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

/// Columna de la sección de misión: título en mayúsculas y texto.
class _ColumnaTexto extends StatelessWidget {
  final String titulo, texto;
  const _ColumnaTexto({required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo.toUpperCase(),
          style: t.titleMedium?.copyWith(
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
            color: AppColors.texto,
          ),
        ),
        const SizedBox(height: 10),
        Text(texto, style: t.bodyLarge?.copyWith(height: 1.7)),
      ],
    );
  }
}
