import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/services/personalidad_usuario_service.dart';
import 'package:paw_match/widgets/cuestionario_usuario.dart';
import 'package:paw_match/widgets/feature_icon.dart';

/// Consulta de las respuestas guardadas y edición con el cuestionario completo.
class PersonalityDetailScreen extends StatefulWidget {
  const PersonalityDetailScreen({super.key});

  @override
  State<PersonalityDetailScreen> createState() => _PersonalityDetailScreenState();
}

class _PersonalityDetailScreenState extends State<PersonalityDetailScreen> {
  late Map<String, double> _valores;
  late Map<String, double> _original;

  bool _cargando = true;
  bool _guardando = false;
  bool _editando = false;
  bool _tieneRegistro = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _valores = _mapaBase();
    _original = Map<String, double>.from(_valores);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargar();
    });
  }

  /// Mapa mutable nuevo. No se reutiliza el literal del campo: en web ese
  /// objeto deja de aceptar `[]=` después del await del guardado.
  static Map<String, double> _mapaBase() {
    final mapa = <String, double>{};
    for (final rasgo in rasgosMascota) {
      mapa[rasgo.clave] = 3;
    }
    return mapa;
  }

  Map<String, double> _mapaDesde(Map<String, num> origen) {
    final mapa = <String, double>{};
    for (final rasgo in rasgosMascota) {
      final bruto = origen[rasgo.clave];
      mapa[rasgo.clave] = (bruto ?? 3).toDouble().clamp(1, 5).toDouble();
    }
    return mapa;
  }

  double _valorDe(String clave) => _valores[clave] ?? 3;

  void _fijar(String clave, double valor) {
    final copia = Map<String, double>.from(_valores);
    copia[clave] = valor;
    setState(() => _valores = copia);
  }

  void _copiar(Map<String, int> guardados) {
    final nuevos = _mapaDesde(guardados);
    _valores = nuevos;
    _original = Map<String, double>.from(nuevos);
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final guardados = await PersonalidadUsuarioService.obtener();
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _tieneRegistro = guardados != null;
        if (guardados != null) _copiar(guardados);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _empezarEdicion() => setState(() => _editando = true);

  void _cancelar() {
    final restaurados = Map<String, double>.from(_original);
    setState(() {
      _valores = restaurados;
      _editando = false;
    });
  }

  Future<void> _guardar() async {
    final valores = <String, int>{};
    for (final rasgo in rasgosMascota) {
      valores[rasgo.clave] = _valorDe(rasgo.clave).round().clamp(1, 5);
    }

    setState(() => _guardando = true);
    try {
      if (_tieneRegistro) {
        await PersonalidadUsuarioService.actualizar(valores);
      } else {
        await PersonalidadUsuarioService.guardar(valores);
      }
      if (!mounted) return;

      final nuevos = _mapaDesde(valores);
      setState(() {
        _valores = nuevos;
        _original = Map<String, double>.from(nuevos);
        _guardando = false;
        _tieneRegistro = true;
        _editando = false;
      });
      if (!mounted) return;
      _aviso('Personalidad actualizada', exito: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _aviso(String texto, {bool exito = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: exito ? AppColors.rosa : AppColors.texto,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(texto),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puedeEditar = !_cargando && _error == null && !_editando;
    return PopScope(
      canPop: !_editando,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_editando || _guardando) return;
        _cancelar();
      },
      child: Scaffold(
        backgroundColor: AppColors.blanco,
        appBar: AppBar(
          title: const Text('Mi personalidad'),
          actions: [
            if (puedeEditar)
              TextButton.icon(
                onPressed: _empezarEdicion,
                icon: const FeatureIcon.editar(color: AppColors.rosa, tamano: 18),
                label: const Text('Editar'),
              ),
          ],
        ),
        body: _cuerpo(),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FeatureIcon.sinConexion(tamano: 40),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(_editando),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _editando ? _formulario() : _lectura(),
              ),
            ),
          ),
        ),
        if (_editando) _barraEdicion(),
      ],
    );
  }

  Widget _lectura() {
    if (!_tieneRegistro) {
      return const EncabezadoCuestionarioUsuario(
        titulo: 'Aún no hay respuestas ${FeatureIcon.huella}',
        detalle: 'Pulsa Editar para completar el cuestionario.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EncabezadoCuestionarioUsuario(
          titulo: '¡Así soy yo!',
          icono: FeatureIcon.compatibilidad(color: AppColors.rosa, tamano: 28),
          detalle: 'Cada detalle de tu personalidad nos ayuda a descubrir a esa huellita especial que encajará perfectamente en tu vida.',
        ),
        const SizedBox(height: 18),
        for (final r in rasgosMascota)
          _TarjetaRasgoLectura(
            rasgo: r,
            valor: _valorDe(r.clave).round(),
          ),
      ],
    );
  }

  Widget _formulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EncabezadoCuestionarioUsuario(),
        const SizedBox(height: 18),
        for (final r in rasgosMascota)
          TarjetaRasgoUsuario(
            rasgo: r,
            valor: _valorDe(r.clave),
            onChanged: _guardando ? null : (v) => _fijar(r.clave, v),
          ),
      ],
    );
  }

  Widget _barraEdicion() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.blanco,
        border: Border(top: BorderSide(color: AppColors.bordeRosa)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _guardando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.blanco,
                        ),
                      )
                    : const Text('Guardar cambios'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _guardando ? null : _cancelar,
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaRasgoLectura extends StatefulWidget {
  final Rasgo rasgo;
  final int valor;

  const _TarjetaRasgoLectura({required this.rasgo, required this.valor});

  @override
  State<_TarjetaRasgoLectura> createState() => _TarjetaRasgoLecturaState();
}

class _TarjetaRasgoLecturaState extends State<_TarjetaRasgoLectura> {
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
    final rasgo = widget.rasgo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedScale(
        scale: _pulsada ? 0.97 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _tocar,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: _elegida ? AppColors.rosaClaro : AppColors.rosaSuave,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _elegida ? AppColors.rosa : AppColors.bordeRosa,
                  width: _elegida ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  _burbujaEmoji(FeatureIcon.emojiRasgo(rasgo.clave)),
                  const SizedBox(width: 12),
                  _circulo(t),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rasgo.titulo,
                          style: t.titleSmall?.copyWith(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(rasgo.preguntaUsuario, style: t.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _burbujaEmoji(String emoji) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _elegida ? AppColors.blanco : AppColors.rosaClaro,
        shape: BoxShape.circle,
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
  }

  Widget _circulo(TextTheme t) {
    return AnimatedScale(
      scale: _elegida ? 1.08 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _elegida ? AppColors.rosa : AppColors.blanco,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.rosa, width: 2),
        ),
        child: Text(
          '${widget.valor}',
          style: t.titleLarge?.copyWith(
            color: _elegida ? AppColors.blanco : AppColors.rosa,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
