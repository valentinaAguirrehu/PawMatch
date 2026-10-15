import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/screens/users/personality_detail.dart';
import 'package:paw_match/services/match_estado.dart';
import 'package:paw_match/services/match_service.dart';
import 'package:paw_match/widgets/cuestionario_usuario.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Las tres mascotas con mayor compatibilidad con la persona en sesión.
class PerfectMatchScreen extends StatefulWidget {
  const PerfectMatchScreen({super.key});

  @override
  State<PerfectMatchScreen> createState() => _PerfectMatchScreenState();
}

class _PerfectMatchScreenState extends State<PerfectMatchScreen> {
  late Future<RankingMatch> _future;

  @override
  void initState() {
    super.initState();
    MatchEstado.instancia.addListener(_alActualizarPersonalidad);
    _future = MatchService.mejores();
  }

  @override
  void dispose() {
    MatchEstado.instancia.removeListener(_alActualizarPersonalidad);
    super.dispose();
  }

  void _alActualizarPersonalidad() {
    if (!mounted) return;
    _cargar();
  }

  Future<void> _cargar() async {
    final futuro = MatchService.mejores();
    setState(() => _future = futuro);
    await futuro.catchError(
      (_) => const RankingMatch(
        tienePersonalidad: false,
        nombreUsuario: '',
        usuario: {},
        mejores: [],
      ),
    );
  }

  Future<void> _abrirCuestionario() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PersonalityDetailScreen()));
  }

  /// Placeholder hasta conectar las solicitudes de adopción y apadrinamiento.
  void _accionPendiente(String accion, String nombre) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.rosa,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text('$accion a $nombre estará disponible pronto'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: FutureBuilder<RankingMatch>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (snap.hasError) return _error();
          return _contenido(snap.data!);
        },
      ),
    );
  }

  Widget _error() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        const Center(
          child: FeatureIcon.sinConexion(tamano: 40, color: AppColors.rosa),
        ),
        const SizedBox(height: 8),
        const Text('No pudimos calcular tu match', textAlign: TextAlign.center),
        Center(
          child: TextButton(
            onPressed: _cargar,
            child: const Text('Reintentar'),
          ),
        ),
      ],
    );
  }

  Widget _contenido(RankingMatch ranking) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EncabezadoCuestionarioUsuario(
                  titulo: '¡Tu Alma Gemela Ideal!',
                  icono: FeatureIcon.compatibilidad(
                    color: AppColors.rosa,
                    tamano: 28,
                  ),
                  detalle:
                      'Comparamos tus respuestas con la personalidad de cada mascota para '
                      'encontrar a quien mejor conecta con tu corazón.',
                ),
                const SizedBox(height: 22),
                if (!ranking.tienePersonalidad)
                  _vacio(
                    'Aún no conocemos cómo eres ${FeatureIcon.huella}',
                    'Completa el cuestionario y te mostramos a tus tres '
                        'mascotas más compatibles.',
                    accion: 'Completar mi personalidad',
                    onPressed: _abrirCuestionario,
                  )
                else if (ranking.mejores.isEmpty)
                  _vacio(
                    'Todavía no hay mascotas registradas para hacer una linda conexión contigo',
                    'Cuando la fundación ingrese a nuevas mascotas, aquí '
                        'verás tu match perfecto.',
                  )
                else
                  _ranking(ranking),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ranking(RankingMatch ranking) {
    final destacado = ranking.mejores.first;
    final siguientes = ranking.mejores.skip(1).toList();
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tu match perfecto ${FeatureIcon.huella}',
          textAlign: TextAlign.center,
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _TarjetaDestacada(
          key: ValueKey(destacado.mascota.id),
          match: destacado,
          nombreUsuario: ranking.nombreUsuario,
          usuario: ranking.usuario,
          onAdoptar: () =>
              _accionPendiente('Adoptar', destacado.mascota.nombre),
          onApadrinar: () =>
              _accionPendiente('Apadrinar', destacado.mascota.nombre),
        ),
        if (siguientes.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            'También podrían ser tu compañero',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, limites) {
              final ladoALado =
                  limites.maxWidth >= 560 && siguientes.length > 1;
              final tarjetas = [
                for (var i = 0; i < siguientes.length; i++)
                  _TarjetaSecundaria(
                    key: ValueKey(siguientes[i].mascota.id),
                    puesto: i + 2,
                    match: siguientes[i],
                    nombreUsuario: ranking.nombreUsuario,
                    usuario: ranking.usuario,
                    onAdoptar: () => _accionPendiente(
                      'Adoptar',
                      siguientes[i].mascota.nombre,
                    ),
                    onApadrinar: () => _accionPendiente(
                      'Apadrinar',
                      siguientes[i].mascota.nombre,
                    ),
                  ),
              ];
              if (!ladoALado) {
                return Column(
                  children: [
                    for (var i = 0; i < tarjetas.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      tarjetas[i],
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < tarjetas.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: tarjetas[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _vacio(
    String titulo,
    String detalle, {
    String? accion,
    VoidCallback? onPressed,
  }) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Column(
        children: [
          const FeatureIcon.compatibilidad(color: AppColors.rosa, tamano: 36),
          const SizedBox(height: 10),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: Colors.black54),
          ),
          if (accion != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onPressed, child: Text(accion)),
          ],
        ],
      ),
    );
  }
}

class _TarjetaDestacada extends StatefulWidget {
  final CompatibilidadMatch match;
  final String nombreUsuario;
  final Map<String, int> usuario;
  final VoidCallback onAdoptar;
  final VoidCallback onApadrinar;

  const _TarjetaDestacada({
    super.key,
    required this.match,
    required this.nombreUsuario,
    required this.usuario,
    required this.onAdoptar,
    required this.onApadrinar,
  });

  @override
  State<_TarjetaDestacada> createState() => _TarjetaDestacadaState();
}

class _TarjetaDestacadaState extends State<_TarjetaDestacada> {
  bool _abierta = false;
  bool _pulsada = false;

  void _tocar() {
    setState(() {
      _pulsada = true;
      _abierta = !_abierta;
    });
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _pulsada = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pet = widget.match.mascota;
    final porcentaje = widget.match.porcentajeEntero;

    return AnimatedScale(
      scale: _pulsada ? 0.98 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _abierta ? AppColors.rosa : AppColors.bordeRosa,
              width: _abierta ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: _tocar,
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    _medalla(porcentaje),
                    const SizedBox(height: 14),
                    Text(
                      pet.nombre,
                      textAlign: TextAlign.center,
                      style: t.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.texto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitulo(pet),
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$porcentaje% de compatibilidad',
                      style: t.titleMedium?.copyWith(
                        color: AppColors.rosa,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _afinidades(),
                    const SizedBox(height: 6),
                    Text(
                      _abierta
                          ? 'Toca para ocultar el detalle'
                          : 'Toca para ver por qué combinan',
                      style: t.bodySmall?.copyWith(color: Colors.black45),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _abierta
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _ComparacionPersonalidad(
                          nombreUsuario: widget.nombreUsuario,
                          nombreMascota: pet.nombre,
                          usuario: widget.usuario,
                          personalidad: pet.personalidad,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 14),
              _BotonesMatch(
                onAdoptar: widget.onAdoptar,
                onApadrinar: widget.onApadrinar,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _medalla(int porcentaje) {
    final foto = (widget.match.mascota.foto ?? '').toLowerCase();
    final recorte = foto.endsWith('.png') || foto.endsWith('.webp');

    return SizedBox(
      width: 176,
      height: 176,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: porcentaje / 100),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, valor, _) => SizedBox(
              width: 176,
              height: 176,
              child: CircularProgressIndicator(
                value: valor,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                color: AppColors.rosa,
                backgroundColor: AppColors.bordeRosa,
              ),
            ),
          ),
          Container(
            width: 146,
            height: 146,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.rosaClaro,
              border: Border.all(color: AppColors.blanco, width: 4),
            ),
            child: ClipOval(
              child: PetImage(
                url: widget.match.mascota.foto,
                fit: recorte ? BoxFit.contain : BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.rosa,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FeatureIcon.compatibilidad(
                    color: AppColors.blanco,
                    tamano: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$porcentaje%',
                    style: const TextStyle(
                      color: AppColors.blanco,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _afinidades() {
    final claves = widget.match.rasgosOrdenados.take(3);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final clave in claves)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.rosaClaro,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${FeatureIcon.emojiRasgo(clave)} ${_tituloRasgo(clave)}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
      ],
    );
  }
}

class _TarjetaSecundaria extends StatefulWidget {
  final int puesto;
  final CompatibilidadMatch match;
  final String nombreUsuario;
  final Map<String, int> usuario;
  final VoidCallback onAdoptar;
  final VoidCallback onApadrinar;

  const _TarjetaSecundaria({
    super.key,
    required this.puesto,
    required this.match,
    required this.nombreUsuario,
    required this.usuario,
    required this.onAdoptar,
    required this.onApadrinar,
  });

  @override
  State<_TarjetaSecundaria> createState() => _TarjetaSecundariaState();
}

class _TarjetaSecundariaState extends State<_TarjetaSecundaria> {
  bool _elegida = false;
  bool _pulsada = false;

  void _tocar() {
    setState(() {
      _pulsada = true;
      _elegida = !_elegida;
    });
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _pulsada = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pet = widget.match.mascota;
    final porcentaje = widget.match.porcentajeEntero;
    final foto = (pet.foto ?? '').toLowerCase();
    final recorte = foto.endsWith('.png') || foto.endsWith('.webp');

    return AnimatedScale(
      scale: _pulsada ? 0.97 : 1,
      duration: const Duration(milliseconds: 140),
      child: Material(
        color: _elegida ? AppColors.rosaClaro : AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _elegida ? AppColors.rosa : AppColors.bordeRosa,
              width: _elegida ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _tocar,
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: ColoredBox(
                          color: AppColors.rosaClaro,
                          child: PetImage(
                            url: pet.foto,
                            fit: recorte ? BoxFit.contain : BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${widget.puesto}',
                            style: t.labelMedium?.copyWith(
                              color: AppColors.rosa,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            pet.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _subtitulo(pet),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall?.copyWith(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _porcentaje(t, porcentaje),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _elegida
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _ComparacionPersonalidad(
                          nombreUsuario: widget.nombreUsuario,
                          nombreMascota: pet.nombre,
                          usuario: widget.usuario,
                          personalidad: pet.personalidad,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 12),
              _BotonesMatch(
                compactos: true,
                onAdoptar: widget.onAdoptar,
                onApadrinar: widget.onApadrinar,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _porcentaje(TextTheme t, int porcentaje) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _elegida ? AppColors.rosa : AppColors.blanco,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.rosa, width: 2),
      ),
      child: Text(
        '$porcentaje%',
        style: t.labelLarge?.copyWith(
          color: _elegida ? AppColors.blanco : AppColors.rosa,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BotonesMatch extends StatelessWidget {
  final VoidCallback onAdoptar;
  final VoidCallback onApadrinar;
  final bool compactos;

  const _BotonesMatch({
    required this.onAdoptar,
    required this.onApadrinar,
    this.compactos = false,
  });

  @override
  Widget build(BuildContext context) {
    final alto = compactos ? 42.0 : 48.0;
    final texto = TextStyle(
      fontSize: compactos ? 13 : 15,
      fontWeight: FontWeight.w700,
    );

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onAdoptar,
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(alto),
              textStyle: texto,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: FeatureIcon.adopcion(
              color: AppColors.blanco,
              tamano: compactos ? 16 : 18,
            ),
            label: const Text('Adoptar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onApadrinar,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(alto),
              textStyle: texto,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: FeatureIcon.apadrinar(
              color: AppColors.rosa,
              tamano: compactos ? 16 : 18,
            ),
            label: const Text('Apadrinar'),
          ),
        ),
      ],
    );
  }
}

String _subtitulo(Pet pet) {
  final especie = pet.especie.trim();
  final sexo = _sexo(pet);
  final partes = <String>[
    if (especie.isNotEmpty) especie,
    if (sexo != null) sexo,
    if (pet.edad != null) pet.edadTexto,
  ];
  if (partes.isEmpty) return 'Compañero por conocer';
  return partes.join(' · ');
}

/// Macho o Hembra, tal como está guardado en `Mascota.sexo`.
String? _sexo(Pet pet) {
  final sexo = (pet.sexo ?? '').trim().toLowerCase();
  return switch (sexo) {
    'macho' => 'Macho',
    'hembra' => 'Hembra',
    '' => null,
    _ => pet.sexo!.trim(),
  };
}

/// Un rasgo, con el nombre real de la persona y de la mascota en corazones.
class _ComparacionPersonalidad extends StatefulWidget {
  final String nombreUsuario;
  final String nombreMascota;
  final Map<String, int> usuario;
  final Map<String, dynamic> personalidad;

  const _ComparacionPersonalidad({
    required this.nombreUsuario,
    required this.nombreMascota,
    required this.usuario,
    required this.personalidad,
  });

  @override
  State<_ComparacionPersonalidad> createState() =>
      _ComparacionPersonalidadState();
}

class _ComparacionPersonalidadState extends State<_ComparacionPersonalidad> {
  String? _elegida;

  void _tocar(String clave) {
    setState(() => _elegida = _elegida == clave ? null : clave);
  }

  @override
  Widget build(BuildContext context) {
    final filas = <Widget>[];
    for (final rasgo in rasgosMascota) {
      final valorUsuario = widget.usuario[rasgo.clave];
      final valorMascota = _entero(widget.personalidad[rasgo.clave]);
      if (valorUsuario == null || valorMascota == null) continue;
      filas.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TarjetaRasgoMatch(
            rasgo: rasgo,
            nombreUsuario: widget.nombreUsuario,
            nombreMascota: widget.nombreMascota,
            valorUsuario: _enEscala(valorUsuario),
            valorMascota: _enEscala(valorMascota),
            elegida: _elegida == rasgo.clave,
            onTap: () => _tocar(rasgo.clave),
          ),
        ),
      );
    }
    if (filas.isEmpty) {
      return const Text('Aún no hay rasgos para comparar.');
    }
    return Column(children: filas);
  }
}

class _TarjetaRasgoMatch extends StatelessWidget {
  final Rasgo rasgo;
  final String nombreUsuario;
  final String nombreMascota;
  final int valorUsuario;
  final int valorMascota;
  final bool elegida;
  final VoidCallback onTap;

  const _TarjetaRasgoMatch({
    required this.rasgo,
    required this.nombreUsuario,
    required this.nombreMascota,
    required this.valorUsuario,
    required this.valorMascota,
    required this.elegida,
    required this.onTap,
  });

  bool get _coinciden => valorUsuario == valorMascota;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final marcada = elegida || _coinciden;
    return AnimatedScale(
      scale: elegida ? 1.02 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Material(
        color: marcada ? AppColors.rosaClaro : AppColors.blanco,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: marcada ? AppColors.rosa : AppColors.bordeRosa,
                width: marcada ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      FeatureIcon.emojiRasgo(rasgo.clave),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rasgo.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.texto,
                        ),
                      ),
                    ),
                    if (_coinciden) const _ChipCoinciden(),
                  ],
                ),
                const SizedBox(height: 10),
                _fila(t, nombreUsuario, valorUsuario, deLaPersona: true),
                const SizedBox(height: 6),
                _fila(t, nombreMascota, valorMascota, deLaPersona: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fila(
    TextTheme t,
    String nombre,
    int valor, {
    required bool deLaPersona,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.labelLarge?.copyWith(
              color: deLaPersona ? AppColors.rosa : AppColors.texto,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _EscalaCorazones(valor: valor),
      ],
    );
  }
}

class _ChipCoinciden extends StatelessWidget {
  const _ChipCoinciden();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.blanco,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Text(
        '¡Coinciden! ✨',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.rosa,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Cinco corazones: ❤️ por cada punto y 🤍 hasta completar la escala.
class _EscalaCorazones extends StatelessWidget {
  final int valor;

  const _EscalaCorazones({required this.valor});

  @override
  Widget build(BuildContext context) {
    final llenos = valor.clamp(0, 5);
    return Semantics(
      label: '$llenos de 5',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.55, end: 1),
              duration: Duration(milliseconds: 220 + (i * 60)),
              curve: Curves.easeOutBack,
              builder: (context, escala, child) =>
                  Transform.scale(scale: escala, child: child),
              child: Padding(
                padding: const EdgeInsets.only(left: 1),
                child: Text(
                  i < llenos ? '❤️' : '🤍',
                  style: const TextStyle(fontSize: 16, height: 1.1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _tituloRasgo(String clave) {
  for (final rasgo in rasgosMascota) {
    if (rasgo.clave == clave) return rasgo.titulo;
  }
  return clave;
}

int? _entero(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) return int.tryParse(raw);
  return null;
}

int _enEscala(int valor) {
  if (valor < 0) return 0;
  if (valor > 5) return 5;
  return valor;
}
