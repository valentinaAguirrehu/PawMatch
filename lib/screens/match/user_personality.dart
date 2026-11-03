import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/entrevista_personalidad.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/screens/home/menu_screen.dart';
import 'package:paw_match/screens/match/revelacion_match.dart';
import 'package:paw_match/services/entrevista_personalidad_service.dart';
import 'package:paw_match/services/match_estado.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/personalidad_usuario_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/services/voz_entrevista.dart';
import 'package:paw_match/widgets/logo_paw.dart';

String _textoBienvenida(String? genero) {
  final cual = genero?.trim().toLowerCase() ?? '';
  final trato = cual == 'hombre'
      ? 'cómodo'
      : cual == 'mujer'
          ? 'cómoda'
          : 'cómoda o cómodo';
  return '¡Hola! Qué alegría tenerte por aquí. Soy el asistente de Paw Match '
      'y quiero conocerte un poquito mejor. Te haré algunas preguntas para '
      'encontrar al peludito ideal para ti. Puedes escribir o usar tu voz, '
      '¡como te sientas más $trato! La Fundación Maritza Arévalo agradece tu '
      'interés. ¡Comencemos! ✨';
}

/// Mismos tonos del hero de inicio: rosa luminoso, rosa medio y rosa Paw Match.
const _degradadoCabecera = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFFFA3C8),
    Color(0xFFF98BB8),
    Color(0xFFF772A9),
  ],
);

const _degradadoBoton = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFFFFA0C6),
    Color(0xFFF165A0),
    AppColors.rosa,
  ],
);

const _fondoPantalla = AppColors.rosaSuave;

List<BoxShadow> _sombraRosa({double blur = 16, double y = 6, double alpha = 0.16}) {
  return [
    BoxShadow(
      color: const Color(0xFFF772A9).withValues(alpha: alpha),
      blurRadius: blur,
      offset: Offset(0, y),
    ),
  ];
}

/// Tras iniciar sesión o registrarse: el cuestionario es obligatorio solo
/// cuando ese usuario todavía no tiene fila en `personalidadusuario`.
Future<void> abrirDestinoTrasAuth(BuildContext context) async {
  final id = Session.idUsuario;
  var mostrarCuestionario = false;
  // El administrador no responde el cuestionario: va directo al menú.
  if (!Session.isAdmin && id != null && id.isNotEmpty) {
    try {
      mostrarCuestionario = !await PersonalidadUsuarioService.existe(id);
    } catch (_) {
      mostrarCuestionario = true;
    }
  }
  if (!context.mounted) return;
  Navegacion.ir(
    context,
    mostrarCuestionario ? const UserPersonalityScreen() : const MenuScreen(),
  );
}

class UserPersonalityScreen extends StatefulWidget {
  const UserPersonalityScreen({super.key});

  @override
  State<UserPersonalityScreen> createState() => _UserPersonalityScreenState();
}

class _UserPersonalityScreenState extends State<UserPersonalityScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final VozEntrevista _voz = VozEntrevista();
  final TextEditingController _campo = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final AnimationController _pulso;

  List<PreguntaEntrevista> _preguntas = [];
  List<RespuestaEntrevista> _confirmadas = [];
  RespuestaEntrevista? _pendiente;
  List<TurnoEntrevista> _turnos = [];

  bool _cargando = true;
  bool _guardando = false;
  bool _procesando = false;
  bool _grabando = false;
  bool _transcribiendo = false;
  bool _resumen = false;
  bool _soltando = false;
  bool _aceptaVoz = false;
  int _indice = 0;
  String? _error;
  Timer? _limiteGrabacion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cargar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _limiteGrabacion?.cancel();
    _campo.dispose();
    _scroll.dispose();
    _pulso.dispose();
    _voz.cerrar();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _persistir();
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final id = Session.idUsuario;
      if (id == null || id.isEmpty) {
        throw Exception('No hay una sesión activa');
      }
      try {
        if (await PersonalidadUsuarioService.existe(id)) {
          if (!mounted) return;
          Navegacion.ir(context, const MenuScreen());
          return;
        }
      } catch (_) {}

      final preguntas = await EntrevistaPersonalidadService.preguntas();
      final local = await EntrevistaPersonalidadService.leerBorradorLocal();
      final remotas = await EntrevistaPersonalidadService.borradores();
      final voz = await EntrevistaPersonalidadService.vozActiva();
      if (!mounted) return;

      _voz.vozActiva = voz;
      _preguntas = preguntas;
      _aplicarProgreso(remotas, local);
      setState(() => _cargando = false);
      _hablarInicio(local);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = _textoError(e);
      });
    }
  }

  void _aplicarProgreso(
    List<RespuestaEntrevista> remotas,
    BorradorEntrevista? local,
  ) {
    final porClave = {for (final respuesta in remotas) respuesta.clave: respuesta};
    final confirmadas = <RespuestaEntrevista>[];
    RespuestaEntrevista? pendiente;

    if (local != null) {
      for (final guardada in local.confirmadas) {
        final remota = porClave[guardada.clave];
        if (remota != null && remota.coincideCon(guardada)) {
          confirmadas.add(remota.conMensaje(guardada.mensaje));
        }
      }
      final localPendiente = local.pendiente;
      if (localPendiente != null) {
        final remota = porClave[localPendiente.clave];
        if (remota != null && remota.coincideCon(localPendiente)) {
          pendiente = remota.conMensaje(localPendiente.mensaje);
        }
      }
    }

    for (final pregunta in _preguntas) {
      final remota = porClave[pregunta.id];
      if (remota == null) continue;
      final yaEsta = confirmadas.any((r) => r.clave == pregunta.id) ||
          pendiente?.clave == pregunta.id;
      if (!yaEsta) confirmadas.add(remota.conMensaje(remota.justificacion));
    }

    _confirmadas = confirmadas;
    _pendiente = pendiente;
    final faltante = _primerFaltante(confirmadas);
    _resumen = faltante == null;
    if (_resumen) {
      _indice = 0;
      _turnos = [];
      _campo.clear();
      return;
    }

    if (pendiente != null) {
      _indice = _preguntas.indexWhere((p) => p.id == pendiente!.clave);
      _turnos = [];
      _campo.clear();
      return;
    }

    _indice = faltante ?? 0;
    final clave = _preguntas[_indice].id;
    final sirve = local != null && local.claveActual == clave;
    _turnos = sirve ? local.turnos : [];
    _campo.text = sirve ? local.borradorTexto : '';
  }

  void _hablarInicio(BorradorEntrevista? local) {
    if (!_voz.vozActiva || _preguntas.isEmpty) return;
    if (_resumen) {
      _voz.hablar('Revisa tus respuestas antes de guardarlas.');
      return;
    }
    final reanudar = _confirmadas.isNotEmpty ||
        _pendiente != null ||
        _turnos.isNotEmpty ||
        (local?.borradorTexto.trim().isNotEmpty ?? false);
    final pregunta = _preguntas[_indice].pregunta;
    _voz.hablar(
      reanudar ? pregunta : '${_textoBienvenida(Session.genero)} $pregunta',
    );
  }

  int? _primerFaltante(List<RespuestaEntrevista> confirmadas) {
    for (var i = 0; i < _preguntas.length; i++) {
      final id = _preguntas[i].id;
      if (!confirmadas.any((r) => r.clave == id)) return i;
    }
    return null;
  }

  Future<void> _persistir() async {
    if (_cargando || _preguntas.isEmpty || _error != null) return;
    try {
      await EntrevistaPersonalidadService.guardarBorradorLocal(
        BorradorEntrevista(
          confirmadas: _confirmadas,
          pendiente: _pendiente,
          claveActual: _resumen ? '' : _preguntas[_indice].id,
          borradorTexto: _campo.text,
          turnos: _turnos,
        ),
      );
    } catch (_) {}
  }

  Future<void> _alternarVoz() async {
    final activa = !_voz.vozActiva;
    setState(() => _voz.vozActiva = activa);
    await EntrevistaPersonalidadService.guardarVoz(activa);
    if (!activa) {
      await _voz.callar();
      return;
    }
    if (_preguntas.isEmpty) return;
    if (_resumen) {
      _voz.hablar('Revisa tus respuestas antes de guardarlas.');
    } else if (_pendiente == null) {
      _voz.hablar(_preguntas[_indice].pregunta);
    }
  }

  Future<void> _alternarMic() async {
    if (_procesando || _transcribiendo || _pendiente != null || _resumen) return;
    if (_grabando) {
      await _detenerMic();
      return;
    }
    _aceptaVoz = true;
    try {
      await _voz.empezar(alCambiar: (texto) {
        if (!mounted || !_aceptaVoz) return;
        _campo.value = TextEditingValue(
          text: texto,
          selection: TextSelection.collapsed(offset: texto.length),
        );
      });
      if (!mounted) {
        _aceptaVoz = false;
        await _voz.detener();
        return;
      }
      setState(() => _grabando = true);
      _pulso.repeat(reverse: true);
      _limiteGrabacion?.cancel();
      _limiteGrabacion = Timer(const Duration(seconds: 60), _detenerMic);
    } catch (e) {
      _aceptaVoz = false;
      if (!mounted) return;
      _aviso(_textoError(e));
    }
  }

  Future<void> _detenerMic() async {
    if (_soltando || (!_grabando && !_transcribiendo)) return;
    _soltando = true;
    _aceptaVoz = false;
    _limiteGrabacion?.cancel();
    final eraArchivo = _voz.usaArchivo;
    if (mounted) {
      setState(() {
        _grabando = false;
        _transcribiendo = eraArchivo;
      });
      _pulso.stop();
      _pulso.value = 0;
    }
    try {
      final texto = await _voz.detener();
      if (!mounted) return;
      if (texto.trim().isNotEmpty) {
        _campo.text = texto.trim();
        _campo.selection = TextSelection.collapsed(offset: _campo.text.length);
      } else if (eraArchivo) {
        _aviso('No se entendió el audio. Intenta otra vez o escribe tu respuesta.');
      }
    } catch (e) {
      if (mounted) _aviso(_textoError(e));
    } finally {
      _soltando = false;
      if (mounted) setState(() => _transcribiendo = false);
      _persistir();
    }
  }

  Future<void> _enviar() async {
    if (_procesando || _grabando || _transcribiendo || _pendiente != null) return;
    final fragmento = _campo.text.trim();
    if (fragmento.length < 2) {
      _aviso('Cuéntame un poco más para poder interpretarlo.');
      return;
    }
    final previos = _turnos.where((t) => t.rol == 'usuario').map((t) => t.texto);
    final completo = [...previos, fragmento].join('\n\n');
    if (completo.length > 2000) {
      _aviso('La respuesta es demasiado larga. Resúmela un poco.');
      return;
    }

    setState(() => _procesando = true);
    await _voz.callar();
    try {
      final interpretacion = await EntrevistaPersonalidadService.interpretar(
        clave: _preguntas[_indice].id,
        respuesta: completo,
        contexto: [
          for (final turno in _turnos) {'rol': turno.rol, 'texto': turno.texto},
        ],
      );
      if (!mounted) return;
      if (interpretacion.necesitaAclaracion || !interpretacion.lista) {
        setState(() {
          _procesando = false;
          _turnos = [
            ..._turnos,
            TurnoEntrevista(rol: 'usuario', texto: fragmento),
            TurnoEntrevista(rol: 'asistente', texto: interpretacion.mensaje),
          ];
          _campo.clear();
        });
        _persistir();
        _voz.hablar(interpretacion.mensaje);
        _alFinal();
        return;
      }

      final nota = interpretacion.puntuacion;
      final porque = interpretacion.justificacion?.trim() ?? '';
      if (nota == null || porque.length < 3) {
        throw Exception('El asistente no asignó una puntuación válida.');
      }
      setState(() {
        _procesando = false;
        _pendiente = RespuestaEntrevista(
          clave: _preguntas[_indice].id,
          respuestaOriginal: interpretacion.respuestaOriginal.trim(),
          puntuacion: nota,
          justificacion: porque,
          mensaje: interpretacion.mensaje,
        );
        _turnos = [];
        _campo.clear();
      });
      _persistir();
      _voz.hablar(interpretacion.mensaje);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      _aviso(_textoError(e));
    }
  }

  void _continuar() {
    final lista = _pendiente;
    if (lista == null || _procesando) return;
    setState(() {
      _confirmadas.removeWhere((r) => r.clave == lista.clave);
      _confirmadas.add(lista);
      _pendiente = null;
      _turnos = [];
      _campo.clear();
      final siguiente = _primerFaltante(_confirmadas);
      if (siguiente == null) {
        _resumen = true;
      } else {
        _indice = siguiente;
        _resumen = false;
      }
    });
    _persistir();
    if (_resumen) {
      _voz.hablar('Revisa tus respuestas antes de guardarlas.');
    } else {
      _alFinal();
      _voz.hablar(_preguntas[_indice].pregunta);
    }
  }

  Future<void> _corregir(RespuestaEntrevista respuesta) async {
    if (_procesando || _guardando || _grabando) return;
    setState(() => _procesando = true);
    await _voz.callar();
    try {
      await EntrevistaPersonalidadService.eliminar(respuesta.clave);
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _pendiente = null;
        _confirmadas.removeWhere((r) => r.clave == respuesta.clave);
        _turnos = [];
        _resumen = false;
        _indice = _preguntas.indexWhere((p) => p.id == respuesta.clave);
        _campo.text = _ultimaParte(respuesta.respuestaOriginal);
      });
      _persistir();
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      _aviso(_textoError(e));
    }
  }

  Future<void> _guardar() async {
    if (_guardando || _confirmadas.length != _preguntas.length) return;
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Center(
          child: Text(
            '¡A un paso de encontrar a tu peludito ideal! 💕',
            textAlign: TextAlign.center,
          ),
        ),
        content: const Text(
          'Tus respuestas están listas. ¿Deseas guardarlas para descubrir '
          'qué perrito tiene el match perfecto contigo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (aceptar != true || !mounted) return;

    final valores = <String, int>{
      for (final respuesta in _confirmadas) respuesta.clave: respuesta.puntuacion,
    };
    for (final pregunta in _preguntas) {
      final nota = valores[pregunta.id];
      if (nota == null || nota < 1 || nota > 5) {
        _aviso('Falta una respuesta de la entrevista.');
        return;
      }
    }

    setState(() => _guardando = true);
    try {
      final remotos = await EntrevistaPersonalidadService.borradores();
      String textoGuardado(RespuestaEntrevista respuesta) {
        for (final remoto in remotos) {
          if (remoto.clave != respuesta.clave) continue;
          if (remoto.puntuacion != respuesta.puntuacion) continue;
          if (remoto.justificacion.trim() != respuesta.justificacion.trim()) continue;
          return remoto.respuestaOriginal;
        }
        return respuesta.respuestaOriginal;
      }

      await PersonalidadUsuarioService.guardar(
        valores,
        respuestas: [
          for (final respuesta in _confirmadas)
            {
              'clave': respuesta.clave,
              'respuesta_original': textoGuardado(respuesta),
              'puntuacion': respuesta.puntuacion,
              'justificacion': respuesta.justificacion,
            },
        ],
      );
      await EntrevistaPersonalidadService.borrarBorradorLocal();
      MatchEstado.instancia.publicar(valores);
      if (!mounted) return;
      Navegacion.ir(context, const RevelacionMatchScreen());
    } catch (e) {
      if (!mounted) return;
      final mensaje = _textoError(e);
      if (mensaje.contains('Ya registraste')) {
        await EntrevistaPersonalidadService.borrarBorradorLocal();
        if (!mounted) return;
        Navegacion.ir(context, const RevelacionMatchScreen());
        return;
      }
      setState(() => _guardando = false);
      _aviso(mensaje);
    }
  }

  void _alFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      // Con reverse, el inicio del desplazamiento es el borde de abajo.
      _scroll.jumpTo(_scroll.position.minScrollExtent);
    });
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  String _textoError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  IconData _icono(String clave) {
    for (final rasgo in rasgosMascota) {
      if (rasgo.clave == clave) return rasgo.icono;
    }
    return Icons.pets;
  }

  String _etiqueta(PreguntaEntrevista pregunta, int nota) {
    switch (nota) {
      case 1:
        return pregunta.minimo;
      case 2:
        return 'Cerca de: ${pregunta.minimo}';
      case 4:
        return 'Cerca de: ${pregunta.maximo}';
      case 5:
        return pregunta.maximo;
      default:
        return 'Intermedio';
    }
  }

  PreguntaEntrevista? _preguntaDe(String clave) {
    for (final pregunta in _preguntas) {
      if (pregunta.id == clave) return pregunta;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _fondoPantalla,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            _cabecera(),
            Expanded(
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      children: [
                        Expanded(
                          child: _cargando || _error != null || _resumen
                              ? _cuerpo()
                              : _entrevista(),
                        ),
                        if (!_cargando && _error == null && _resumen)
                          _barraConfirmar(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecera() {
    return ClipPath(
      clipper: const _OndaCabecera(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: _degradadoCabecera),
        child: Stack(
          children: [
            const Positioned(
              top: -28,
              left: -18,
              child: _BurbujaDecorativa(tamano: 120, alpha: 0.20),
            ),
            const Positioned(
              top: 4,
              right: -40,
              child: _BurbujaDecorativa(tamano: 148, alpha: 0.16),
            ),
            const Positioned(
              top: 42,
              right: 120,
              child: _BurbujaDecorativa(tamano: 58, alpha: 0.12),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      children: [
                        _encabezado(),
                        if (!_cargando && _error == null) _progreso(),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const LogoPaw(tamano: 40),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paw Match',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Entrevista de personalidad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _voz.vozActiva
                ? 'Silenciar la lectura'
                : 'Leer las preguntas en voz alta',
            onPressed: _cargando || _error != null ? null : _alternarVoz,
            icon: Icon(
              _voz.vozActiva ? Icons.volume_up : Icons.volume_off,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progreso() {
    final total = _preguntas.length;
    final hechas = _confirmadas.length.clamp(0, total);
    final texto = _resumen ? 'Revisión final' : 'Pregunta ${_indice + 1} de $total';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : hechas / total,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.35),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: AppColors.rosa));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    return _listaResumen();
  }

  /// La pregunta y la respuesta quedan pegadas abajo. Si no caben, se desplaza
  /// desde ahí y no desde el saludo de arriba.
  Widget _entrevista() {
    return LayoutBuilder(
      builder: (context, limites) {
        return SingleChildScrollView(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: limites.maxHeight - 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ..._burbujasHistorial(),
                _tarjetaPregunta(),
                _panel(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Si la persona aclaró varias veces, en pantalla queda solo el último mensaje.
  String _ultimaParte(String texto) {
    final partes = texto
        .split(RegExp(r'\n\s*\n'))
        .map((parte) => parte.trim())
        .where((parte) => parte.isNotEmpty)
        .toList();
    if (partes.isEmpty) return texto.trim();
    return partes.last;
  }

  List<Widget> _burbujasHistorial() {
    final burbujas = <Widget>[
      _burbuja(_textoBienvenida(Session.genero), usuario: false),
    ];
    RespuestaEntrevista? ultima;
    PreguntaEntrevista? preguntaUltima;
    for (final pregunta in _preguntas) {
      if (pregunta.id == _preguntas[_indice].id) continue;
      for (final item in _confirmadas) {
        if (item.clave != pregunta.id) continue;
        ultima = item;
        preguntaUltima = pregunta;
      }
    }
    if (ultima != null && preguntaUltima != null) {
      burbujas.add(_burbuja(_ultimaParte(ultima.respuestaOriginal), usuario: true));
      burbujas.add(
        _burbuja(
          '${ultima.mensaje}\n\nPuntuación ${ultima.puntuacion} de 5 · ${_etiqueta(preguntaUltima, ultima.puntuacion)}',
          usuario: false,
        ),
      );
    }
    for (final turno in _turnos) {
      burbujas.add(_burbuja(turno.texto, usuario: turno.rol == 'usuario'));
    }
    return burbujas;
  }

  Widget _burbuja(String texto, {required bool usuario}) {
    return Align(
      alignment: usuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: usuario ? null : Colors.white,
          gradient: usuario ? _degradadoBoton : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _sombraRosa(blur: 12, y: 4, alpha: 0.14),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: usuario ? AppColors.blanco : AppColors.texto,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _tarjetaPregunta() {
    final pregunta = _preguntas[_indice];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _sombraRosa(blur: 18, y: 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icono(pregunta.id), color: AppColors.rosa, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pregunta.titulo,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(pregunta.pregunta, style: const TextStyle(height: 1.35)),
        ],
      ),
    );
  }

  Widget _panel() {
    if (_pendiente != null) return _panelListo(_pendiente!);
    return _panelCaptura();
  }

  Widget _panelCaptura() {
    final ocupado = _procesando || _transcribiendo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        children: [
          if (_grabando || _transcribiendo || _procesando)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  if (_grabando)
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.85, end: 1).animate(_pulso),
                      child: const Icon(Icons.circle, color: AppColors.rosa, size: 12),
                    )
                  else
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rosa),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _grabando
                        ? 'Escuchando…'
                        : _transcribiendo
                            ? 'Transcribiendo tu voz…'
                            : 'Interpretando tu respuesta…',
                    style: const TextStyle(color: AppColors.rosa, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _botonMic(),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _campo,
                  enabled: !ocupado && !_grabando,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu respuesta si no deseas usar el micrófono',
                    filled: true,
                    fillColor: Colors.white,
                    hintStyle: const TextStyle(color: Color(0xFF8A8084), fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.bordeRosa, width: 1.4),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => _persistir(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _botonGradiente(
            texto: 'Enviar respuesta',
            onPressed: ocupado || _grabando ? null : _enviar,
          ),
        ],
      ),
    );
  }

  Widget _botonGradiente({
    required String texto,
    required VoidCallback? onPressed,
    Widget? indicador,
  }) {
    final activo = onPressed != null;
    return Opacity(
      opacity: activo ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: _degradadoBoton,
          boxShadow: activo ? _sombraRosa(blur: 16, y: 8, alpha: 0.32) : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              height: 52,
              width: double.infinity,
              alignment: Alignment.center,
              child: indicador ??
                  Text(
                    texto,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonMic() {
    final activo = _grabando;
    return Tooltip(
      message: activo ? 'Detener' : 'Responder con la voz',
      child: Material(
        color: activo ? AppColors.rosa : Colors.white,
        elevation: activo ? 0 : 3,
        shadowColor: const Color(0xFFF772A9).withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _procesando || _transcribiendo ? null : _alternarMic,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              activo ? Icons.stop : Icons.mic,
              color: activo ? AppColors.blanco : AppColors.rosa,
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelListo(RespuestaEntrevista respuesta) {
    final pregunta = _preguntaDe(respuesta.clave);
    final etiqueta = pregunta == null
        ? '${respuesta.puntuacion} de 5'
        : '${respuesta.puntuacion} de 5 · ${_etiqueta(pregunta, respuesta.puntuacion)}';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _sombraRosa(blur: 18, y: 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(respuesta.mensaje, style: const TextStyle(height: 1.35)),
          const SizedBox(height: 6),
          Text(
            _ultimaParte(respuesta.respuestaOriginal),
            style: const TextStyle(color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            'Puntuación $etiqueta',
            style: const TextStyle(
              color: AppColors.rosa,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _procesando ? null : () => _corregir(respuesta),
                  child: const Text('Corregir'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _botonGradiente(
                  texto: 'Continuar',
                  onPressed: _procesando ? null : _continuar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _listaResumen() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        const Text(
          'Así entendí tus respuestas. Si alguna no refleja lo que quisiste decir, corrígela antes de guardar.',
          style: TextStyle(height: 1.35),
        ),
        const SizedBox(height: 12),
        for (final pregunta in _preguntas)
          if (_respuestaDe(pregunta.id) != null)
            _tarjetaResumen(pregunta, _respuestaDe(pregunta.id)!),
      ],
    );
  }

  RespuestaEntrevista? _respuestaDe(String clave) {
    for (final respuesta in _confirmadas) {
      if (respuesta.clave == clave) return respuesta;
    }
    return null;
  }

  Widget _tarjetaResumen(PreguntaEntrevista pregunta, RespuestaEntrevista respuesta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _sombraRosa(blur: 14, y: 6, alpha: 0.14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pregunta.titulo,
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.texto),
          ),
          const SizedBox(height: 4),
          Text(pregunta.pregunta, style: const TextStyle(fontSize: 13.5, height: 1.3)),
          const SizedBox(height: 8),
          Text(
            _ultimaParte(respuesta.respuestaOriginal),
            style: const TextStyle(height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            'Puntuación ${respuesta.puntuacion} de 5 · ${_etiqueta(pregunta, respuesta.puntuacion)}',
            style: const TextStyle(color: AppColors.rosa, fontWeight: FontWeight.w800),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _guardando || _procesando ? null : () => _corregir(respuesta),
              child: const Text('Corregir'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraConfirmar() {
    final completa = _confirmadas.length == _preguntas.length && _preguntas.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: _botonGradiente(
        texto: 'Confirmar y guardar',
        onPressed: !completa || _guardando ? null : _guardar,
        indicador: _guardando
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : null,
      ),
    );
  }
}

class _BurbujaDecorativa extends StatelessWidget {
  final double tamano;
  final double alpha;

  const _BurbujaDecorativa({required this.tamano, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      ),
    );
  }
}

/// Onda inferior, del mismo corte suave que el hero de la pantalla de inicio.
class _OndaCabecera extends CustomClipper<Path> {
  const _OndaCabecera();

  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 22)
      ..cubicTo(
        size.width * 0.22,
        size.height - 4,
        size.width * 0.48,
        size.height - 40,
        size.width * 0.68,
        size.height - 18,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height - 2,
        size.width * 0.92,
        size.height - 26,
        size.width,
        size.height - 12,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
