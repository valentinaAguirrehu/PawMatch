import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/core/layout.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/screens/auth/login_screen.dart';
import 'package:paw_match/screens/auth/registro_screen.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/widgets/bloque_landing.dart';
import 'package:paw_match/widgets/boton_landing.dart';
import 'package:paw_match/widgets/chip_seleccion.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/landing_barra.dart';
import 'package:paw_match/widgets/pet_card.dart'; // PetImage
import 'package:paw_match/widgets/perrito_landing_card.dart';
import 'package:paw_match/widgets/stat_logro.dart';
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

/// Página de inicio (antes de iniciar sesión): quiénes somos, logros y perritos.
/// Arriba siempre están los botones de Iniciar sesión y Registrarse.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  List<Pet> _pets = [];
  bool _cargando = true;
  bool _error = false;
  bool _paraAdopcion = true; // false = para apadrinar

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

  bool _esRecorte(String? foto) {
    final f = (foto ?? '').toLowerCase();
    return f.endsWith('.png') || f.endsWith('.webp'); // sin fondo: se ve entera
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
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return Padding(
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
                    padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
                    child: Column(
                      children: [
                        _hero(m),
                        const SizedBox(height: 16),
                        _quienesSomos(m),
                        const SizedBox(height: 16),
                        _logros(m),
                        const SizedBox(height: 16),
                        _perritos(m),
                        const SizedBox(height: 16),
                        _cta(m),
                        const SizedBox(height: 24),
                        Text(
                          '© ${DateTime.now().year} Paw Match · ${FundacionInfo.nombre} · San Juan de Pasto',
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
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TituloLanding(
          texto: 'Conoce a quienes',
          acento: 'esperan un hogar',
          color: Colors.white,
          tamano: m.tTitulo + 4,
        ),
        const SizedBox(height: 16),
        Text(
          '${FundacionInfo.resumen}. Adopta o apadrina a un peludito de la ${FundacionInfo.nombre} y haz la diferencia hoy.',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        const _Punto(
          titulo: 'Adopción',
          texto:
              'Dale a un peludito la oportunidad de tener un hogar lleno de amor.',
        ),
        const SizedBox(height: 14),
        const _Punto(
          titulo: 'Apadrinamiento',
          texto: 'Apoya su cuidado mientras espera una familia, sin adoptarlo.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            BotonLanding(
              texto: 'Quiero adoptar',
              sobreRosa: true,
              onPressed: () => _pedirCuenta(adopcion: true),
            ),
            BotonLanding(
              texto: 'Quiero apadrinar',
              sobreRosa: true,
              relleno: false,
              onPressed: () => _pedirCuenta(adopcion: false),
            ),
          ],
        ),
      ],
    );

    return BloqueLanding(
      color: AppColors.rosa,
      padding: EdgeInsets.all(m.interior),
      child: m.escritorio
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: textos),
                const SizedBox(width: 32),
                Expanded(flex: 5, child: _collage(260)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [textos, const SizedBox(height: 24), _collage(170)],
            ),
    );
  }

  /// Dos fotos de perritos reales; si aún no hay, el logo.
  Widget _collage(double alto) {
    final conFoto = _pets
        .where((p) => (p.foto ?? '').isNotEmpty)
        .take(2)
        .toList();
    if (conFoto.isEmpty) {
      return Center(
        child: Container(
          width: alto,
          height: alto,
          padding: EdgeInsets.all(alto * 0.12),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.pets, size: alto * 0.4, color: AppColors.rosa),
            ),
          ),
        ),
      );
    }

    Widget foto(Pet p) => Container(
      height: alto,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: PetImage(
        url: p.foto,
        fit: _esRecorte(p.foto) ? BoxFit.contain : BoxFit.cover,
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: foto(conFoto[0])),
        if (conFoto.length > 1) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: foto(conFoto[1]),
            ),
          ),
        ],
      ],
    );
  }

  // ───────────── 2. Quiénes somos ─────────────
  Widget _quienesSomos(_Medidas m) {
    const mision = _TarjetaTexto(
      icono: Icons.flag_outlined,
      titulo: 'Misión',
      texto: FundacionInfo.mision,
    );
    const vision = _TarjetaTexto(
      icono: Icons.visibility_outlined,
      titulo: 'Visión',
      texto: FundacionInfo.vision,
    );
    return BloqueLanding(
      color: Colors.white,
      padding: EdgeInsets.all(m.interior),
      child: Column(
        children: [
          TituloLanding(
            texto: 'Conoce',
            acento: 'quiénes somos',
            color: AppColors.rosa,
            tamano: m.tTitulo,
            alineacion: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            '${FundacionInfo.nombre}. ${FundacionInfo.resumen}.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          m.escritorio
              ? const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: mision),
                    SizedBox(width: 16),
                    Expanded(child: vision),
                  ],
                )
              : const Column(children: [mision, SizedBox(height: 16), vision]),
        ],
      ),
    );
  }

  // ───────────── 3. Nuestros logros (datos reales de la base de datos) ─────────────
  Widget _logros(_Medidas m) {
    String v(int n) => _cargando ? '…' : (_error ? '–' : '$n');
    final adoptados = _pets.where((p) => p.estadoAdopcion == 'adoptado').length;
    final disponibles = _pets
        .where((p) => p.estadoAdopcion == 'disponible')
        .length;
    final apadrinados = _pets
        .where((p) => p.estadoApadrinamiento == 'apadrinado')
        .length;

    final columnas = m.escritorio ? 4 : 2;
    const sep = 12.0;
    final w = (m.anchoInterior - sep * (columnas - 1)) / columnas;

    final items = [
      StatLogro(
        icono: Icons.pets,
        valor: v(_pets.length),
        etiqueta: 'Perritos registrados',
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

    return BloqueLanding(
      color: Colors.white,
      padding: EdgeInsets.all(m.interior),
      child: Column(
        children: [
          TituloLanding(
            texto: 'Nuestros',
            acento: 'logros',
            color: AppColors.rosa,
            tamano: m.tTitulo,
            alineacion: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: sep,
            runSpacing: sep,
            alignment: WrapAlignment.center,
            children: [for (final s in items) SizedBox(width: w, child: s)],
          ),
        ],
      ),
    );
  }

  // ───────────── 4. Conoce a nuestros perritos ─────────────
  Widget _perritos(_Medidas m) {
    final perros = _pets
        .where((p) => p.especie.toLowerCase() == 'perro')
        .where(
          (p) => _paraAdopcion
              ? p.estadoAdopcion == 'disponible'
              : p.estadoApadrinamiento == 'disponible',
        )
        .take(m.escritorio ? 8 : 6)
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
              child: PerritoLandingCard(
                pet: p,
                paraAdopcion: _paraAdopcion,
                onTap: () => _pedirCuenta(pet: p, adopcion: _paraAdopcion),
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
            color: AppColors.rosa,
            tamano: m.tTitulo,
            alineacion: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ChipSeleccion(
                texto: 'Para adoptar',
                icono: const FeatureIcon.mascota(tamano: 18),
                seleccionado: _paraAdopcion,
                onTap: () => setState(() => _paraAdopcion = true),
              ),
              ChipSeleccion(
                texto: 'Para apadrinar',
                icono: const FeatureIcon.apadrinar(tamano: 18),
                seleccionado: !_paraAdopcion,
                onTap: () => setState(() => _paraAdopcion = false),
              ),
            ],
          ),
          const SizedBox(height: 20),
          cuerpo,
          const SizedBox(height: 20),
          BotonLanding(
            texto: _paraAdopcion ? 'Quiero adoptar' : 'Quiero apadrinar',
            relleno: false,
            onPressed: () => _pedirCuenta(adopcion: _paraAdopcion),
          ),
        ],
      ),
    );
  }

  // ───────────── 5. Llamado a crear cuenta ─────────────
  Widget _cta(_Medidas m) => BloqueLanding(
    color: AppColors.rosa,
    padding: EdgeInsets.all(m.interior),
    child: Column(
      children: [
        TituloLanding(
          texto: 'Crea tu cuenta y encuentra a',
          acento: 'tu compañero ideal',
          color: Colors.white,
          tamano: m.tTitulo,
          alineacion: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Regístrate gratis, descubre qué peludito encaja con tu estilo de vida '
          'y empieza el proceso de adopción o apadrinamiento.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            BotonLanding(
              texto: 'Registrarse',
              sobreRosa: true,
              onPressed: _irRegistro,
            ),
            BotonLanding(
              texto: 'Iniciar sesión',
              sobreRosa: true,
              relleno: false,
              onPressed: _irLogin,
            ),
          ],
        ),
      ],
    ),
  );
}

/// Punto con huella: título y texto cortos (sobre fondo rosado).
class _Punto extends StatelessWidget {
  final String titulo, texto;
  const _Punto({required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Icon(Icons.pets, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              texto,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Tarjeta rosada con ícono, título y texto (Misión / Visión).
class _TarjetaTexto extends StatelessWidget {
  final IconData icono;
  final String titulo, texto;
  const _TarjetaTexto({
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.rosaClaro,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, color: AppColors.rosa),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.texto,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          texto,
          style: const TextStyle(height: 1.5, color: AppColors.texto),
        ),
      ],
    ),
  );
}
