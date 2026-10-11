import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/enlaces.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/core/layout.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/screens/auth/login_screen.dart';
import 'package:paw_match/screens/auth/registro_screen.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/widgets/bloque_landing.dart';
import 'package:paw_match/widgets/boton_landing.dart';
import 'package:paw_match/widgets/landing_barra.dart';
import 'package:paw_match/widgets/perrito_landing_card.dart';
import 'package:paw_match/widgets/redes_sociales.dart';
import 'package:paw_match/widgets/stat_logro.dart';
import 'package:paw_match/widgets/tarjeta_ayuda.dart';
import 'package:paw_match/widgets/titulo_landing.dart';

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

  @override
  void initState() {
    super.initState();
    _cargar();
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
    MaterialPageRoute(builder: (_) => const RegistroScreen()),
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
    final contenido = math.min(ancho, Layout.anchoMaximo) - 2 * pad;
    final m = _Medidas(
      escritorio,
      ancho,
      interior,
      contenido - 2 * interior,
      escritorio ? 40 : 28,
    );
    const separacion = SizedBox(height: 16);

    return Scaffold(
      backgroundColor: AppColors.rosaSuave,
      body: Column(
        children: [
          LandingBarra(onIniciarSesion: _irLogin, onRegistrarse: _irRegistro),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Layout.anchoMaximo,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 16, pad, 90),
                    child: Column(
                      children: [
                        _hero(m),
                        separacion,
                        _rescatista(m),
                        separacion,
                        _mision(m),
                        separacion,
                        _perritos(m),
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
    final t = Theme.of(context).textTheme;
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TituloLanding(
          texto: 'Conoce nuestra',
          acento: FundacionInfo.nombre,
          color: AppColors.texto,
          colorAcento: AppColors.rosa,
          tamano: m.tTitulo + 2,
        ),
        const SizedBox(height: 16),
        Text(
          'Nos encontramos ubicados en ${FundacionInfo.ciudad}.\n\n'
          '${FundacionInfo.historia}',
          style: t.bodyLarge?.copyWith(height: 1.55),
        ),
      ],
    );

    return BloqueLanding(
      color: Colors.white,
      padding: EdgeInsets.all(m.interior),
      child: m.escritorio
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: textos),
                const SizedBox(width: 32),
                Expanded(flex: 5, child: _heroImagen(340)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [textos, const SizedBox(height: 28), _heroImagen(300)],
            ),
    );
  }

  /// Imagen de presentación de la Fundación, sin fotos de mascotas de la base de datos.
  Widget _heroImagen(double alto) {
    return SizedBox(
      height: alto,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: alto * 0.92,
            height: alto * 0.92,
            decoration: const BoxDecoration(
              color: AppColors.rosa,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(
            width: alto * 0.74,
            height: alto * 0.86,
            child: ClipOval(
              child: Image.asset(
                'assets/fundacion/Maritzanimada.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: AppColors.rosaClaro,
                  child: Center(
                    child: Icon(
                      Icons.volunteer_activism,
                      color: AppColors.rosa,
                      size: 80,
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

  // ───────────── 2. Nuestra misión ─────────────
  Widget _mision(_Medidas m) {
    final t = Theme.of(context).textTheme;
    const que = _ColumnaTexto(
      titulo: 'Lo que hacemos',
      texto: FundacionInfo.mision,
    );
    const queremos = _ColumnaTexto(
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
              ? const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: que),
                    SizedBox(width: 40),
                    Expanded(child: queremos),
                  ],
                )
              : const Column(children: [que, SizedBox(height: 24), queremos]),
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
    final foto = Image.asset(
      FundacionInfo.fotoRescatista,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: AppColors.rosaClaro,
        child: Center(
          child: Icon(
            Icons.volunteer_activism,
            size: 64,
            color: AppColors.rosa,
          ),
        ),
      ),
    );

    final panel = Container(
      color: AppColors.rosaClaro,
      padding: EdgeInsets.all(m.interior),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'NUESTRA RESCATISTA',
            style: t.headlineSmall?.copyWith(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            FundacionInfo.rescatistaNombre,
            style: t.titleLarge?.copyWith(
              color: AppColors.rosa,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            FundacionInfo.rescatistaTexto,
            style: t.bodyLarge?.copyWith(height: 1.55, color: AppColors.texto),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: m.escritorio
          ? SizedBox(
              height: 380,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: foto),
                  Expanded(child: panel),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 260, child: foto),
                panel,
              ],
            ),
    );
  }

  // ───────────── Logros (datos reales de la base de datos) ─────────────
  Widget _logros(_Medidas m) {
    String v(int n) => _cargando ? '…' : (_error ? '–' : '$n');
    final adoptados = _pets.where((p) => p.estadoAdopcion == 'adoptado').length;
    final disponibles = _pets
        .where((p) => p.estadoAdopcion == 'disponible')
        .length;
    final apadrinados = _pets
        .where((p) => p.estadoApadrinamiento == 'apadrinado')
        .length;

    const sep = 12.0;

    final items = [
      StatLogro(
        icono: Icons.pets,
        valor: v(_pets.length),
        etiqueta: 'Perritos que hemos ayudado',
      ),
      StatLogro(
        icono: Icons.home_outlined,
        valor: v(disponibles),
        etiqueta: 'Esperando un hogar',
      ),
      StatLogro(
        icono: Icons.favorite_outline,
        valor: v(adoptados),
        etiqueta: 'Adopciones logradas',
      ),
      StatLogro(
        icono: Icons.volunteer_activism,
        valor: v(apadrinados),
        etiqueta: 'Perritos apadrinados',
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'NUESTROS LOGROS',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: m.tTitulo,
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnas = constraints.maxWidth >= 800 ? 4 : 2;
            final anchoTarjeta =
                (constraints.maxWidth - sep * (columnas - 1)) / columnas;
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
    );
  }

  // ───────────── Perritos en adopción ─────────────
  Widget _perritos(_Medidas m) {
    final perros = _pets
        .where((p) => p.especie.toLowerCase() == 'perro')
        .where((p) => p.estadoAdopcion == 'disponible')
        .take(4)
        .toList();

    final columnas = m.escritorio ? 4 : (m.ancho >= Layout.tablet ? 3 : 2);
    const sep = 14.0;
    final w = (m.anchoInterior - sep * (columnas - 1)) / columnas;

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
      cuerpo = Wrap(
        spacing: sep,
        runSpacing: sep,
        alignment: WrapAlignment.center,
        children: [
          for (final p in perros)
            SizedBox(
              width: w,
              height: 440,
              child: PerritoLandingCard(
                pet: p,
                paraAdopcion: true,
                onTap: () => _pedirCuenta(pet: p, adopcion: true),
              ),
            ),
        ],
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

  // ───────────── 6. Ayuda y contacto ─────────────
  Widget _ayuda(_Medidas m) {
    final columnas = m.ancho >= Layout.tablet ? 2 : 1;
    const sep = 14.0;
    final w = (m.anchoInterior - sep * (columnas - 1)) / columnas;

    final tarjetas = [
      TarjetaAyuda(
        icono: Icons.home_outlined,
        titulo: 'Adopta',
        texto:
            'Encuentra un compañero que encaje contigo y dale un hogar lleno de cariño.',
      ),
      TarjetaAyuda(
        icono: Icons.volunteer_activism,
        titulo: 'Apadrina',
        texto:
            'Contribuye a su cuidado mientras esperan encontrar una familia permanente.',
      ),
    ];

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: SizedBox(
            width: double.infinity,
            height: m.escritorio ? 350 : 460,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  FundacionInfo.fotoFondoAyudas,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: AppColors.rosa),
                ),
                ColoredBox(color: AppColors.rosa.withValues(alpha: 0.82)),
                Padding(
                  padding: EdgeInsets.all(m.interior),
                  child: Center(child: _logros(m)),
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
              Wrap(
                spacing: sep,
                runSpacing: sep,
                alignment: WrapAlignment.center,
                children: [
                  for (final tarjeta in tarjetas)
                    SizedBox(width: w, height: 220, child: tarjeta),
                ],
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
        const SizedBox(height: 14),
        BotonLanding(
          texto: 'Abrir ubicación en Google Maps',
          relleno: false,
          onPressed: () =>
              abrirEnlace(context, FundacionInfo.mapaUrl, nombre: 'el mapa'),
        ),
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
        Text(
          'Para coordinar una donación, contáctanos por WhatsApp.',
          style: t.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 14),
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
