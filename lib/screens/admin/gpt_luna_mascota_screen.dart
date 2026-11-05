import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/screens/match/dog_personality.dart';
import 'package:paw_match/services/entrevista_mascota_luna_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/screens/users/voz_asistente_screen.dart';
import 'package:paw_match/services/voz_asistente_service.dart';
import 'package:paw_match/services/voz_entrevista.dart';
import 'package:paw_match/widgets/logo_paw.dart';

enum _FaseRegistroLuna {
  conversacion,
  revision,
  fotografia,
}

/// Asistente conversacional con GPT Luna (`gpt-6-luna` configurado en `.env`)
/// para que el administrador registre mascotas hablando o escribiendo,
/// revise/edite la ficha estructurada y agregue la fotografía al final.
class GptLunaMascotaScreen extends StatefulWidget {
  const GptLunaMascotaScreen({super.key});

  @override
  State<GptLunaMascotaScreen> createState() => _GptLunaMascotaScreenState();
}

class _GptLunaMascotaScreenState extends State<GptLunaMascotaScreen>
    with SingleTickerProviderStateMixin {
  final VozEntrevista _voz = VozEntrevista();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  late final AnimationController _pulsoMic;

  _FaseRegistroLuna _fase = _FaseRegistroLuna.conversacion;

  final List<MensajeChatLuna> _mensajes = <MensajeChatLuna>[];
  FichaMascotaLuna _ficha = const FichaMascotaLuna();
  List<String> _camposFaltantes = const <String>[];
  bool _guardadoEnBd = false;
  String? _mensajePendienteReintento;
  String? _errorGuardadoTurno;

  bool _cargandoTurno = true;
  bool _grabandoVoz = false;
  bool _transcribiendoVoz = false;
  bool _deteniendoMic = false;
  bool _aceptaParcialVoz = false;
  Timer? _timerLimiteVoz;

  // Controladores para la Ficha de Revisión y Confirmación (Fase 2)
  final GlobalKey<FormState> _formRevisionKey = GlobalKey<FormState>();
  final TextEditingController _revNombre = TextEditingController();
  final TextEditingController _revRaza = TextEditingController();
  final TextEditingController _revDescripcion = TextEditingController();
  final TextEditingController _revDetalleSalud = TextEditingController();
  String _revEspecie = 'Perro';
  String _revSexo = 'Macho';
  String _revTamano = 'Mediano';
  DateTime _revFechaNacimiento = DateTime(DateTime.now().year - 1, DateTime.now().month, DateTime.now().day);
  bool _revPersonalidadEnProceso = false;
  List<String> _revEstadosSalud = <String>[opcionSinNecesidades];
  final DogPersonalityController _revPersonalidadCtrl = DogPersonalityController();

  // Controladores para la Fotografía Final (Fase 3)
  Uint8List? _fotoBytes;
  String _fotoNombre = 'mascota.jpg';
  String? _fotoRutaServidor;
  bool _subiendoFoto = false;
  String? _errorSubidaFoto;
  bool _guardandoMascota = false;

  static const List<String> _especies = ['Perro', 'Gato', 'Otro'];
  static const List<String> _sexos = ['Macho', 'Hembra'];
  static const List<String> _tamanos = ['Pequeño', 'Mediano', 'Grande'];
  static const List<String> _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  void initState() {
    super.initState();
    _pulsoMic = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _voz.alCambiarEstadoReproduccion = () {
      if (mounted) setState(() {});
    };
    unawaited(VozAsistenteService.vozGuardada());
    _iniciarConversacion();
  }

  @override
  void dispose() {
    _timerLimiteVoz?.cancel();
    _pulsoMic.dispose();
    _inputCtrl.dispose();
    _chatScrollCtrl.dispose();
    _revNombre.dispose();
    _revRaza.dispose();
    _revDescripcion.dispose();
    _revDetalleSalud.dispose();
    _revPersonalidadCtrl.dispose();
    _voz.cerrar();
    super.dispose();
  }

  void _aviso(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFFB91C1C) : AppColors.rosa,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(texto),
      ),
    );
  }

  void _desplazarChatAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollCtrl.hasClients) return;
      _chatScrollCtrl.animateTo(
        _chatScrollCtrl.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  String _construirSaludoRespaldoSegunGenero() {
    final g = Session.genero.trim().toLowerCase();
    if (g == 'mujer' || g == 'femenino' || g == 'f') {
      return '¡Hola! 💗 ¡Estoy lista para ayudarte a registrar un nuevo peludito en Paw Match! Para comenzar, cuéntame, ¿cómo se llama nuestro peludito, qué edad tiene, es perrito o gatito, qué sexo tiene y qué tamaño es? 🐾 Puedes escribirme o contarme todo lo que sepas hablando por el micrófono.';
    }
    if (g == 'hombre' || g == 'masculino' || g == 'm') {
      return '¡Hola! 💗 ¡Estoy listo para ayudarte a registrar un nuevo peludito en Paw Match! Para comenzar, cuéntame, ¿cómo se llama nuestro peludito, qué edad tiene, es perrito o gatito, qué sexo tiene y qué tamaño es? 🐾 Puedes escribirme o contarme todo lo que sepas hablando por el micrófono.';
    }
    return '¡Hola! 💗 Estoy aquí para ayudarte a registrar un nuevo peludito en Paw Match. Para comenzar, cuéntame, ¿cómo se llama nuestro peludito, qué edad tiene, es perrito o gatito, qué sexo tiene y qué tamaño es? 🐾 Puedes escribirme o contarme todo lo que sepas hablando por el micrófono.';
  }

  Future<void> _iniciarConversacion({bool reiniciar = false}) async {
    await _voz.callar();
    setState(() {
      _cargandoTurno = true;
      _errorGuardadoTurno = null;
      _mensajePendienteReintento = null;
      if (reiniciar) {
        _mensajes.clear();
        _ficha = const FichaMascotaLuna();
        _camposFaltantes = const [];
        _fase = _FaseRegistroLuna.conversacion;
      }
    });
    try {
      final resp = await EntrevistaMascotaLunaService.enviarTurno(
        ficha: reiniciar ? const FichaMascotaLuna() : _ficha,
        historial: const [],
        mensaje: '',
        reiniciar: reiniciar,
      );
      if (!mounted) return;
      setState(() {
        _ficha = resp.ficha;
        _camposFaltantes = resp.camposFaltantes;
        _guardadoEnBd = resp.guardadoEnBd;
        _mensajes.clear();
        if (resp.historialGuardado.isNotEmpty) {
          _mensajes.addAll(resp.historialGuardado);
        } else {
          _mensajes.add(MensajeChatLuna(rol: 'asistente', texto: resp.mensaje));
        }
        _cargandoTurno = false;
      });
      _desplazarChatAlFinal();
      if (_mensajes.isNotEmpty) {
        final idxUltimo = _mensajes.length - 1;
        unawaited(
          _voz.hablar(
            _mensajes[idxUltimo].texto,
            idMensaje: 'msg_$idxUltimo',
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final saludoRespaldo = _construirSaludoRespaldoSegunGenero();
      setState(() {
        _mensajes.clear();
        _mensajes.add(
          MensajeChatLuna(rol: 'asistente', texto: saludoRespaldo),
        );
        _cargandoTurno = false;
      });
      unawaited(_voz.hablar(saludoRespaldo, idMensaje: 'msg_0'));
    }
  }

  Future<void> _alternarLecturaVoz() async {
    final nuevo = !_voz.vozActiva;
    setState(() => _voz.vozActiva = nuevo);
    if (!nuevo) {
      await _voz.callar();
    } else if (_voz.estaEnPausa) {
      unawaited(_voz.continuar());
    } else if (_mensajes.isNotEmpty) {
      final idx = _mensajes.lastIndexWhere((m) => m.rol == 'asistente');
      if (idx != -1) {
        unawaited(
          _voz.hablar(_mensajes[idx].texto, idMensaje: 'msg_$idx'),
        );
      }
    }
  }

  Future<void> _cambiarVelocidadVoz(double velocidad) async {
    await _voz.cambiarVelocidad(velocidad);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _alternarVelocidadCiclica() async {
    await _voz.siguienteVelocidad();
    if (!mounted) return;
    setState(() {});
  }

  // ---------------- Micrófono (Reconocimiento de Voz) ----------------

  Future<void> _alternarMicrofono() async {
    if (_cargandoTurno || _transcribiendoVoz) return;
    if (_grabandoVoz) {
      await _detenerMicrofono();
      return;
    }

    _aceptaParcialVoz = true;
    final textoPrevio = _inputCtrl.text.trim();
    try {
      await _voz.empezar(
        alCambiar: (reconocido) {
          if (!mounted || !_aceptaParcialVoz) return;
          final combinado = textoPrevio.isEmpty
              ? reconocido
              : '$textoPrevio $reconocido';
          _inputCtrl.value = TextEditingValue(
            text: combinado,
            selection: TextSelection.collapsed(offset: combinado.length),
          );
          setState(() {});
        },
      );
      if (!mounted) {
        _aceptaParcialVoz = false;
        await _voz.detener();
        return;
      }
      setState(() => _grabandoVoz = true);
      _pulsoMic.repeat(reverse: true);
      _timerLimiteVoz?.cancel();
      _timerLimiteVoz = Timer(
        const Duration(seconds: 60),
        _detenerMicrofono,
      );
    } catch (e) {
      _aceptaParcialVoz = false;
      if (!mounted) return;
      _aviso(
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  Future<void> _detenerMicrofono() async {
    if (_deteniendoMic || (!_grabandoVoz && !_transcribiendoVoz)) return;
    _deteniendoMic = true;
    _aceptaParcialVoz = false;
    _timerLimiteVoz?.cancel();
    final eraArchivo = _voz.usaArchivo;

    if (mounted) {
      setState(() {
        _grabandoVoz = false;
        _transcribiendoVoz = eraArchivo;
      });
      _pulsoMic.stop();
      _pulsoMic.value = 0;
    }

    try {
      final transcrito = await _voz.detener();
      if (!mounted) return;
      if (transcrito.trim().isNotEmpty) {
        final actual = _inputCtrl.text.trim();
        final nuevoTexto = eraArchivo && actual.isNotEmpty
            ? '$actual ${transcrito.trim()}'
            : (actual.isNotEmpty && !eraArchivo ? actual : transcrito.trim());
        _inputCtrl.value = TextEditingValue(
          text: nuevoTexto,
          selection: TextSelection.collapsed(offset: nuevoTexto.length),
        );
        setState(() {});
      } else if (eraArchivo) {
        _aviso(
          'No se entendió el audio. Puedes intentar de nuevo o escribir tu respuesta.',
          error: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _aviso(
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      _deteniendoMic = false;
      if (mounted) {
        setState(() => _transcribiendoVoz = false);
      }
    }
  }

  // ---------------- Envío de Mensaje al Asistente de Paw Match ----------------

  Future<void> _enviarMensaje({String? reintentoTexto}) async {
    if (_grabandoVoz) {
      await _detenerMicrofono();
    }
    final esReintento = reintentoTexto != null;
    final texto = (reintentoTexto ?? _inputCtrl.text).trim();
    if (texto.isEmpty || _cargandoTurno) return;

    await _voz.callar();
    setState(() {
      if (!esReintento) {
        _inputCtrl.clear();
        _mensajes.add(MensajeChatLuna(rol: 'usuario', texto: texto));
      }
      _errorGuardadoTurno = null;
      _mensajePendienteReintento = null;
      _cargandoTurno = true;
    });
    _desplazarChatAlFinal();

    try {
      final resp = await EntrevistaMascotaLunaService.enviarTurno(
        ficha: _ficha,
        historial: _mensajes,
        mensaje: texto,
      );
      if (!mounted) return;
      setState(() {
        _ficha = resp.ficha;
        _camposFaltantes = resp.camposFaltantes;
        _guardadoEnBd = resp.guardadoEnBd;
        _mensajes.add(MensajeChatLuna(rol: 'asistente', texto: resp.mensaje));
        _cargandoTurno = false;
      });
      final idxNuevo = _mensajes.length - 1;
      _desplazarChatAlFinal();
      unawaited(_voz.hablar(resp.mensaje, idMensaje: 'msg_$idxNuevo'));

      if (resp.entrevistaCompletada) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted && _fase == _FaseRegistroLuna.conversacion) {
          _irAFaseRevision();
        }
      }
    } catch (e) {
      if (!mounted) return;
      final msgError = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _cargandoTurno = false;
        _mensajePendienteReintento = texto;
        _errorGuardadoTurno = msgError;
      });
      _aviso(
        '$msgError Puedes tocar «Reintentar» para guardar tu respuesta.',
        error: true,
      );
    }
  }

  // ---------------- Paso a Ficha de Revisión Editable (Fase 2) ----------------

  void _irAFaseRevision() {
    _voz.callar();
    _revNombre.text = _ficha.nombre ?? '';
    _revEspecie = _especies.contains(_ficha.especie)
        ? _ficha.especie!
        : 'Perro';
    _revSexo = _sexos.contains(_ficha.sexo) ? _ficha.sexo! : 'Macho';
    _revTamano = _tamanos.contains(_ficha.tamano) ? _ficha.tamano! : 'Mediano';
    _revRaza.text = _ficha.raza ?? 'Mestizo';
    _revFechaNacimiento = _ficha.calcularFechaNacimiento();
    _revDescripcion.text = _ficha.descripcion ?? '';
    _revDetalleSalud.text = _ficha.detalleSalud ?? '';

    final estados = List<String>.from(_ficha.estadosSalud);
    if (estados.isEmpty) {
      estados.add(opcionSinNecesidades);
    }
    _revEstadosSalud = estados;

    _revPersonalidadEnProceso =
        _ficha.esCachorroEnProceso == true ||
        _ficha.personalidadDefinida == false;

    for (final r in rasgosMascota) {
      final v = _ficha.personalidad[r.clave];
      _revPersonalidadCtrl.actualizar(
        r.clave,
        (v ?? 3).clamp(1, 5).toDouble(),
      );
    }

    setState(() => _fase = _FaseRegistroLuna.revision);
  }

  // ---------------- Paso a Fotografía al Final (Fase 3) ----------------

  Future<void> _confirmarRevisionEIrAFotografia() async {
    if (!_formRevisionKey.currentState!.validate()) return;
    if (_revEstadosSalud.isEmpty) {
      _aviso('Selecciona al menos un estado de salud.', error: true);
      return;
    }

    final meses = Pet.mesesEntre(_revFechaNacimiento, DateTime.now());
    final anos = meses ~/ 12;
    final tieneNecesidades = _revEstadosSalud.any(
      opcionesNecesidadesPendientes.contains,
    );

    final fichaConfirmada = FichaMascotaLuna(
      nombre: _revNombre.text.trim(),
      especie: _revEspecie,
      sexo: _revSexo,
      edad: anos >= 1 ? anos : (meses <= 0 ? 1 : meses),
      unidadEdad: anos >= 1 ? 'anos' : 'meses',
      raza: _revRaza.text.trim().isEmpty ? 'Desconocida' : _revRaza.text.trim(),
      tamano: _revTamano,
      esCachorroEnProceso: _revPersonalidadEnProceso,
      personalidadDefinida: !_revPersonalidadEnProceso,
      personalidad: _revPersonalidadEnProceso
          ? const {}
          : _revPersonalidadCtrl.personalidad,
      estadosSalud: _revEstadosSalud,
      vacunas: _revEstadosSalud.contains('Vacunación al día.'),
      esterilizado: _revEstadosSalud.contains('Esterilización realizada.'),
      detalleSalud: tieneNecesidades && _revDetalleSalud.text.trim().isNotEmpty
          ? _revDetalleSalud.text.trim()
          : null,
      descripcion: _revDescripcion.text.trim(),
      saludConsultada: true,
      historiaConsultada: true,
    );

    try {
      await EntrevistaMascotaLunaService.guardarBorradorRevision(
        ficha: fichaConfirmada,
        historial: _mensajes,
        pasoActual: 'fotografia',
      );
    } catch (_) {
      // Si falla la sincronización del borrador intermedio, continuamos igual con los datos en memoria
    }

    const mensajeFoto =
        '¡Perfecto! Ahora solo nos falta una fotico para completar su perfil. 🐾';

    if (!mounted) return;
    setState(() {
      _ficha = fichaConfirmada;
      _guardadoEnBd = true;
      if (_mensajes.isEmpty || _mensajes.last.texto != mensajeFoto) {
        _mensajes.add(
          const MensajeChatLuna(rol: 'asistente', texto: mensajeFoto),
        );
      }
      _fase = _FaseRegistroLuna.fotografia;
    });
    unawaited(_voz.hablar(mensajeFoto, idMensaje: 'msg_foto_final'));
  }

  Future<void> _seleccionarFotografia() async {
    ImageSource origen = ImageSource.gallery;
    final esMovil = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (esMovil) {
      final elegido = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.rosa),
                title: const Text('Seleccionar de la galería'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: AppColors.rosa),
                title: const Text('Tomar una fotografía'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      if (elegido == null) return;
      origen = elegido;
    }

    try {
      final archivo = await ImagePicker().pickImage(
        source: origen,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 78,
      );
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _aviso('La fotografía supera los 5 MB. Elige una más liviana.', error: true);
        return;
      }

      // 1. Mostrar vista previa inmediata en memoria
      setState(() {
        _fotoBytes = bytes;
        _fotoNombre = archivo.name.isEmpty ? 'mascota.jpg' : archivo.name;
        _fotoRutaServidor = null;
        _errorSubidaFoto = null;
      });

      // 2. Subir inmediatamente con indicador de progreso
      await _subirFotografiaAlServidor();
    } catch (e) {
      _aviso('No se pudo abrir la fotografía: $e', error: true);
    }
  }

  Future<String?> _subirFotografiaAlServidor() async {
    final bytes = _fotoBytes;
    if (bytes == null) return null;
    if (_fotoRutaServidor != null && _fotoRutaServidor!.isNotEmpty) {
      return _fotoRutaServidor;
    }

    setState(() {
      _subiendoFoto = true;
      _errorSubidaFoto = null;
    });

    try {
      final ruta = await PetsService.subirFoto(bytes, _fotoNombre);
      if (mounted) {
        setState(() {
          _fotoRutaServidor = ruta;
          _subiendoFoto = false;
          _errorSubidaFoto = null;
        });
      }
      return ruta;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        setState(() {
          _subiendoFoto = false;
          _errorSubidaFoto = msg;
        });
      }
      return null;
    }
  }

  Future<void> _guardarMascotaCompleta() async {
    if (_fotoBytes == null) {
      _aviso('Selecciona una fotografía para completar el perfil.', error: true);
      return;
    }
    if (_guardandoMascota || _subiendoFoto) return;

    setState(() => _guardandoMascota = true);
    try {
      // Asegurar que la fotografía se guardó correctamente en el servidor
      String? rutaConfirmada = _fotoRutaServidor;
      if (rutaConfirmada == null || _errorSubidaFoto != null) {
        rutaConfirmada = await _subirFotografiaAlServidor();
      }
      if (rutaConfirmada == null || rutaConfirmada.isEmpty) {
        throw Exception(
          _errorSubidaFoto ??
              'No se pudo confirmar el guardado de la fotografía. Reintenta subirla.',
        );
      }

      final meses = Pet.mesesEntre(_revFechaNacimiento, DateTime.now());
      final anos = meses ~/ 12;
      final tieneNecesidades = _revEstadosSalud.any(
        opcionesNecesidadesPendientes.contains,
      );

      final nuevaMascota = Pet(
        id: '',
        nombre: _revNombre.text.trim(),
        especie: _revEspecie,
        raza: _revRaza.text.trim().isEmpty ? 'Mestizo' : _revRaza.text.trim(),
        fechaNacimiento: _revFechaNacimiento,
        edad: anos >= 1 ? anos : (meses <= 0 ? 1 : meses),
        unidadEdad: anos >= 1 ? 'anos' : 'meses',
        sexo: _revSexo,
        tamano: _revTamano,
        descripcion: _revDescripcion.text.trim(),
        esterilizado: _revEstadosSalud.contains('Esterilización realizada.'),
        vacunas: _revEstadosSalud.contains('Vacunación al día.'),
        foto: rutaConfirmada,
        estadoAdopcion: 'disponible',
        estadoApadrinamiento: 'disponible',
        estadosSalud: _revEstadosSalud,
        detalleSalud: tieneNecesidades && _revDetalleSalud.text.trim().isNotEmpty
            ? _revDetalleSalud.text.trim()
            : null,
        personalidadDefinida: !_revPersonalidadEnProceso,
        personalidad: _revPersonalidadEnProceso
            ? const {}
            : _revPersonalidadCtrl.personalidad,
      );

      final creada = await PetsService.crear(nuevaMascota);
      if (!mounted) return;
      _aviso('¡"${creada.nombre}" se registró exitosamente en Paw Match! 🐾');
      Navigator.pop(context, creada);
    } catch (e) {
      if (mounted) {
        _aviso(
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _guardandoMascota = false);
      }
    }
  }

  // ---------------- Construcción de la Interfaz ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4F9),
      body: SafeArea(
        child: Column(
          children: [
            _cabeceraLuna(),
            _barraFases(),
            Expanded(
              child: switch (_fase) {
                _FaseRegistroLuna.conversacion => _vistaConversacion(),
                _FaseRegistroLuna.revision => _vistaRevisionEditable(),
                _FaseRegistroLuna.fotografia => _vistaFotografiaFinal(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabeceraLuna() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF7EB6),
            AppColors.rosa,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () {
              if (_fase == _FaseRegistroLuna.fotografia) {
                setState(() => _fase = _FaseRegistroLuna.revision);
              } else if (_fase == _FaseRegistroLuna.revision) {
                setState(() => _fase = _FaseRegistroLuna.conversacion);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Center(child: LogoPaw(tamano: 30)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Asistente de Paw Match 🐾',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  switch (_fase) {
                    _FaseRegistroLuna.conversacion =>
                      'Registro inteligente de mascotas',
                    _FaseRegistroLuna.revision =>
                      'Registro inteligente de mascotas · Revisar ficha',
                    _FaseRegistroLuna.fotografia =>
                      'Registro inteligente de mascotas · Fotografía',
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Nuevo registro desde cero',
            onPressed: _cargandoTurno
                ? null
                : () => _iniciarConversacion(reiniciar: true),
            icon: const Icon(
              Icons.restart_alt_rounded,
              color: Colors.white,
            ),
          ),
          const MarcaVozAsistente(),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _alternarVelocidadCiclica,
            child: Tooltip(
              message: 'Cambiar velocidad de voz (X1, X1.5, X2, X3)',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  _voz.etiquetaVelocidad.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: _voz.vozActiva ? 'Silenciar voz' : 'Activar voz',
            onPressed: _alternarLecturaVoz,
            icon: Icon(
              _voz.vozActiva ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraFases() {
    Widget paso(int num, String titulo, _FaseRegistroLuna f) {
      final activo = _fase == f;
      final completado = _fase.index > f.index;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (f == _FaseRegistroLuna.conversacion) {
              setState(() => _fase = _FaseRegistroLuna.conversacion);
            } else if (f == _FaseRegistroLuna.revision) {
              _irAFaseRevision();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: activo
                  ? AppColors.rosa
                  : (completado ? AppColors.rosaClaro : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: activo || completado
                    ? AppColors.rosa
                    : const Color(0xFFF8C6DC),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: activo
                      ? Colors.white
                      : (completado ? AppColors.rosa : const Color(0xFFFCE4EF)),
                  child: completado
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : Text(
                          '$num',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: activo ? AppColors.rosa : AppColors.texto,
                          ),
                        ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: activo ? Colors.white : AppColors.texto,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          paso(1, 'Conversar', _FaseRegistroLuna.conversacion),
          const SizedBox(width: 6),
          paso(2, 'Revisar ficha', _FaseRegistroLuna.revision),
          const SizedBox(width: 6),
          paso(3, 'Fotografía', _FaseRegistroLuna.fotografia),
        ],
      ),
    );
  }

  // ---------------- VISTA FASE 1: CONVERSACIÓN ----------------

  Widget _vistaConversacion() {
    return Column(
      children: [
        _resumenDatosCapturados(),
        Expanded(
          child: ListView.builder(
            controller: _chatScrollCtrl,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            itemCount: _mensajes.length + (_cargandoTurno ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _mensajes.length) {
                return _burbujaPensando();
              }
              final msg = _mensajes[index];
              return _burbujaMensaje(msg, idMensaje: 'msg_$index');
            },
          ),
        ),
        _barraEntradaVozYTexto(),
      ],
    );
  }

  Widget _resumenDatosCapturados() {
    final porcentaje = _ficha.porcentajeProgreso;
    final nombreMascota = _ficha.nombre?.trim() ?? '';
    final tituloProgreso = nombreMascota.isNotEmpty
        ? 'Conociendo a $nombreMascota 🐾'
        : 'Conociendo a nuestro nuevo peludito 🐾';

    final chips = <String>[
      if (_ficha.nombre != null) '🐾 ${_ficha.nombre}',
      if (_ficha.especie != null) _ficha.especie!,
      if (_ficha.sexo != null) _ficha.sexo!,
      if (_ficha.edad != null)
        '${_ficha.edad} ${_ficha.unidadEdad == "meses" ? "meses" : "años"}',
      if (_ficha.tamano != null) _ficha.tamano!,
      if (_ficha.raza != null) _ficha.raza!,
      if (_ficha.esCachorroEnProceso == true ||
          _ficha.personalidadDefinida == false)
        '🍼 Personalidad en proceso'
      else if (_ficha.personalidad.isNotEmpty)
        '💖 Personalidad',
      if (_ficha.saludConsultada) '🩺 Salud lista',
      if (_ficha.historiaConsultada) '📖 Historia lista',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF8C6DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tituloProgreso,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.texto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$porcentaje% de información recopilada',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.rosa,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.rosaClaro,
                  foregroundColor: AppColors.rosa,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _irAFaseRevision,
                icon: const Icon(Icons.fact_check_outlined, size: 15),
                label: Text(
                  _camposFaltantes.isEmpty && _ficha.nombre != null
                      ? 'Confirmar ficha'
                      : 'Ver ficha',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: porcentaje / 100.0,
              minHeight: 6,
              backgroundColor: const Color(0xFFFCE4EF),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.rosa),
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in chips)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.rosaSuave,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.bordeRosa),
                      ),
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.rosa,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _burbujaMensaje(MensajeChatLuna msg, {String? idMensaje}) {
    final esLuna = msg.rol == 'asistente';
    final idMsg = idMensaje ?? 'msg_${msg.texto.hashCode}';
    final esMensajeActivo = _voz.idMensajeActual == idMsg;
    final reproduciendoEste =
        esMensajeActivo && _voz.estado == EstadoReproduccionVoz.reproduciendo;
    final pausadoEste =
        esMensajeActivo && _voz.estado == EstadoReproduccionVoz.pausado;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            esLuna ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (esLuna) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: reproduciendoEste ? AppColors.rosa : AppColors.bordeRosa,
                  width: reproduciendoEste ? 2 : 1,
                ),
              ),
              child: const Center(child: LogoPaw(tamano: 24)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                gradient: esLuna
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFF6FB3), AppColors.rosa],
                      ),
                color: esLuna ? Colors.white : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(esLuna ? 6 : 20),
                  bottomRight: Radius.circular(esLuna ? 20 : 6),
                ),
                border: esLuna
                    ? Border.all(
                        color: reproduciendoEste
                            ? AppColors.rosa
                            : const Color(0xFFF8C6DC),
                        width: reproduciendoEste ? 1.6 : 1.2,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rosa.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (esLuna)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Flexible(
                            child: Text(
                              'Asistente de Paw Match 🐾',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.rosa,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          for (final vel in VozEntrevista.velocidadesDisponibles)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: GestureDetector(
                                onTap: () => _cambiarVelocidadVoz(vel),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _voz.multiplicadorVelocidad == vel
                                        ? AppColors.rosa
                                        : AppColors.rosaSuave,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _voz.multiplicadorVelocidad == vel
                                          ? AppColors.rosa
                                          : AppColors.bordeRosa,
                                    ),
                                  ),
                                  child: Text(
                                    vel == 1.0
                                        ? 'X1'
                                        : (vel == 1.5
                                              ? 'X1.5'
                                              : (vel == 2.0 ? 'X2' : 'X3')),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: _voz.multiplicadorVelocidad == vel
                                          ? Colors.white
                                          : AppColors.rosa,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Text(
                    msg.texto,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.38,
                      fontWeight: FontWeight.w600,
                      color: esLuna ? const Color(0xFF1F2937) : Colors.white,
                    ),
                  ),
                  if (esLuna) ...[
                    const SizedBox(height: 10),
                    _controlesReproduccionMensaje(
                      idMensaje: idMsg,
                      texto: msg.texto,
                      reproduciendoEste: reproduciendoEste,
                      pausadoEste: pausadoEste,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlesReproduccionMensaje({
    required String idMensaje,
    required String texto,
    required bool reproduciendoEste,
    required bool pausadoEste,
  }) {
    final finalizadoEste = _voz.esFinalizado(idMensaje);
    final progreso = _voz.progresoDeMensaje(idMensaje);
    final porcentaje = (progreso * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reproduciendoEste || pausadoEste || finalizadoEste) ...[
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: reproduciendoEste
                        ? progreso.clamp(0.04, 1.0)
                        : progreso.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: const Color(0xFFFCE4EF),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.rosa,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$porcentaje%',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.rosa,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (reproduciendoEste) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDCEB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      size: 14,
                      color: AppColors.rosa,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reproduciendo · ${_voz.etiquetaVelocidad}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.rosa,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _voz.pausar(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.rosaSuave,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bordeRosa),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pause_rounded,
                        size: 14,
                        color: AppColors.rosa,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Pausar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.rosa,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (pausadoEste) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDCEB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'En pausa · ${_voz.etiquetaVelocidad}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.rosa,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _voz.continuar(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.rosa,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '▶ Continuar (${_voz.etiquetaVelocidad})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ] else if (finalizadoEste) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE4EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: AppColors.rosa,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Finalizado',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.rosa,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Botón 🔊 Volver a escuchar siempre visible en cada mensaje del asistente
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _voz.volverAEscuchar(
                idMensaje: idMensaje,
                texto: texto,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.rosaSuave,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bordeRosa),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.volume_up_rounded,
                      size: 14,
                      color: AppColors.rosa,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Volver a escuchar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.rosa,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _burbujaPensando() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bordeRosa),
            ),
            child: const Center(child: LogoPaw(tamano: 24)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF8C6DC)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.rosa,
                    ),
                  ),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Guardando y preparando la siguiente pregunta... 🐾',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.rosa,
                      ),
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

  Widget _barraEntradaVozYTexto() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF8C6DC))),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_mensajePendienteReintento != null && !_cargandoTurno)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFB91C1C),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorGuardadoTurno ??
                          'No se pudo guardar tu última respuesta en la base de datos.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _enviarMensaje(
                      reintentoTexto: _mensajePendienteReintento,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          if (_grabandoVoz || _transcribiendoVoz)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4EF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.rosa),
              ),
              child: Row(
                children: [
                  Icon(
                    _transcribiendoVoz
                        ? Icons.auto_awesome_rounded
                        : Icons.mic_rounded,
                    color: AppColors.rosa,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _transcribiendoVoz
                          ? 'Transcribiendo tu voz a texto...'
                          : 'Escuchando... Habla ahora y toca el micrófono para finalizar. Puedes corregir el texto antes de enviarlo.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9D174D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Botón de micrófono para hablar con GPT Luna
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.12).animate(_pulsoMic),
                child: GestureDetector(
                  onTap: _alternarMicrofono,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _grabandoVoz
                          ? const Color(0xFFE11D48)
                          : const Color(0xFFFFDCEB),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _grabandoVoz
                            ? const Color(0xFFE11D48)
                            : AppColors.rosa,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      _grabandoVoz ? Icons.stop_rounded : Icons.mic_rounded,
                      color: _grabandoVoz ? Colors.white : AppColors.rosa,
                      size: 23,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Campo de texto editable (para escribir o corregir lo dictado por voz)
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: AppColors.rosaSuave,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.bordeRosa, width: 1.2),
                  ),
                  child: TextField(
                    controller: _inputCtrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _enviarMensaje(),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText:
                          'Escribe o usa el micrófono para responder paso a paso...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botón para enviar mensaje
              GestureDetector(
                onTap: (_inputCtrl.text.trim().isEmpty || _cargandoTurno)
                    ? null
                    : _enviarMensaje,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: (_inputCtrl.text.trim().isEmpty || _cargandoTurno)
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFFF6FB3), AppColors.rosa],
                          ),
                    color: (_inputCtrl.text.trim().isEmpty || _cargandoTurno)
                        ? const Color(0xFFF3E8EE)
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: (_inputCtrl.text.trim().isEmpty || _cargandoTurno)
                        ? const Color(0xFF9CA3AF)
                        : Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- VISTA FASE 2: RESUMEN Y CONFIRMACIÓN EDITABLE ----------------

  void _toggleEstadoSaludRevision(String opcion) {
    setState(() {
      if (_revEstadosSalud.contains(opcion)) {
        _revEstadosSalud.remove(opcion);
      } else {
        if (opcion == 'Requiere vacunación.') {
          _revEstadosSalud.remove('Vacunación al día.');
          _revEstadosSalud.remove(opcionSinNecesidades);
        } else if (opcion == 'Vacunación al día.') {
          _revEstadosSalud.remove('Requiere vacunación.');
        } else if (opcion == 'Requiere esterilización.') {
          _revEstadosSalud.remove('Esterilización realizada.');
          _revEstadosSalud.remove(opcionSinNecesidades);
        } else if (opcion == 'Esterilización realizada.') {
          _revEstadosSalud.remove('Requiere esterilización.');
        } else if (opcionesNecesidadesPendientes.contains(opcion)) {
          _revEstadosSalud.remove(opcionSinNecesidades);
        } else if (opcion == opcionSinNecesidades) {
          _revEstadosSalud.removeWhere(opcionesNecesidadesPendientes.contains);
        }
        _revEstadosSalud.add(opcion);
      }
      if (_revEstadosSalud.isEmpty) {
        _revEstadosSalud.add(opcionSinNecesidades);
      }
    });
  }

  Future<void> _elegirFechaRevision() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _revFechaNacimiento.isAfter(hoy) ? hoy : _revFechaNacimiento,
      firstDate: DateTime(hoy.year - 35, hoy.month, hoy.day),
      lastDate: hoy,
      helpText: 'Fecha de nacimiento aproximada o exacta',
    );
    if (elegida == null || !mounted) return;
    setState(() {
      _revFechaNacimiento = DateTime(elegida.year, elegida.month, elegida.day);
    });
  }

  InputDecoration _decoCampo(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.rosaSuave,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.bordeRosa),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.bordeRosa),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.rosa, width: 2),
    ),
  );

  Widget _vistaRevisionEditable() {
    final tieneNecesidades = _revEstadosSalud.any(
      opcionesNecesidadesPendientes.contains,
    );

    return Form(
      key: _formRevisionKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.bordeRosa, width: 1.4),
            ),
            child: const Row(
              children: [
                Icon(Icons.fact_check_rounded, color: AppColors.rosa, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Revisa los datos organizados por el asistente de Paw Match. Puedes editar o corregir cualquier campo antes de confirmar.',
                    style: TextStyle(
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF8C6DC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Datos básicos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.texto,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nombre *',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _revNombre,
                  maxLength: 50,
                  decoration: _decoCampo('Nombre de la mascota'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    if (v.trim().length > 50) {
                      return 'Máximo 50 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Especie *',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _revEspecie,
                            decoration: _decoCampo(''),
                            items: _especies
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _revEspecie = v ?? 'Perro'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sexo *',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _revSexo,
                            decoration: _decoCampo(''),
                            items: _sexos
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _revSexo = v ?? 'Macho'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tamaño *',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _revTamano,
                            decoration: _decoCampo(''),
                            items: _tamanos
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _revTamano = v ?? 'Mediano'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Raza',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _revRaza,
                            maxLength: 50,
                            decoration: _decoCampo('Ej: Mestizo'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fecha de nacimiento / Edad calculada *',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _elegirFechaRevision,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.rosaSuave,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.bordeRosa),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: AppColors.rosa,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_revFechaNacimiento.day} ${_meses[_revFechaNacimiento.month - 1]} ${_revFechaNacimiento.year} · Edad: ${Pet.textoEdad(_revFechaNacimiento, DateTime.now())}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.texto,
                            ),
                          ),
                        ),
                        const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.rosa),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Salud
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF8C6DC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2. Salud y procedimientos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.texto,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: opcionesEstadoSalud.map((opcion) {
                    final sel = _revEstadosSalud.contains(opcion);
                    return FilterChip(
                      selected: sel,
                      selectedColor: AppColors.rosaClaro,
                      checkmarkColor: AppColors.rosa,
                      label: Text(
                        opcion,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                          color: sel ? AppColors.rosa : const Color(0xFF374151),
                        ),
                      ),
                      onSelected: (_) => _toggleEstadoSaludRevision(opcion),
                    );
                  }).toList(),
                ),
                if (tieneNecesidades) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Condiciones especiales o notas veterinarias',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _revDetalleSalud,
                    maxLines: 2,
                    maxLength: 300,
                    decoration: _decoCampo(
                      'Detalle de tratamiento, medicamentos o cuidados...',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Historia y observaciones
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF8C6DC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '3. Historia de rescate y observaciones',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.texto,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _revDescripcion,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: _decoCampo(
                    'Historia de rescate y observaciones para adoptantes y padrinos...',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Personalidad conectada al Sistema Match
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF8C6DC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '4. Personalidad para el sistema Match',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.texto,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.rosa,
                  title: const Text(
                    'Bebé en proceso / Personalidad en desarrollo',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.texto,
                    ),
                  ),
                  subtitle: const Text(
                    'Actívalo si es un cachorro o mascota cuya personalidad aún está en desarrollo.',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  value: _revPersonalidadEnProceso,
                  onChanged: (v) =>
                      setState(() => _revPersonalidadEnProceso = v),
                ),
                if (!_revPersonalidadEnProceso) ...[
                  const Divider(height: 16),
                  DogPersonality(
                    controller: _revPersonalidadCtrl,
                    sexo: _revSexo,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rosa,
                    side: const BorderSide(color: AppColors.rosa, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () =>
                      setState(() => _fase = _FaseRegistroLuna.conversacion),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text(
                    'Seguir conversando',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosa,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _confirmarRevisionEIrAFotografia,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text(
                    'Confirmar y agregar foto',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- VISTA FASE 3: SOLICITUD DE FOTOGRAFÍA AL FINAL ----------------

  Widget _vistaFotografiaFinal() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // Burbuja del asistente con el mensaje exacto requerido
        _burbujaMensaje(
          const MensajeChatLuna(
            rol: 'asistente',
            texto:
                '¡Perfecto! Ahora solo nos falta una fotico para completar su perfil. 🐾',
          ),
          idMensaje: 'msg_foto_final',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF8C6DC), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: AppColors.rosa.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Fotografía de ${_revNombre.text.trim().isEmpty ? "la mascota" : _revNombre.text.trim()}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.texto,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _seleccionarFotografia,
                child: Container(
                  height: 270,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5FA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.rosa.withValues(alpha: 0.45),
                      width: 1.6,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_fotoBytes != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.memory(
                            _fotoBytes!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        )
                      else
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: const BoxDecoration(
                                color: AppColors.rosaClaro,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_a_photo_rounded,
                                size: 34,
                                color: AppColors.rosa,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Toca aquí para seleccionar la fotografía',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.texto,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Vista previa inmediata · JPG, PNG o WebP',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      if (_subiendoFoto)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            color: Colors.black.withValues(alpha: 0.65),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Subiendo fotografía al servidor...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_fotoRutaServidor != null)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF166534),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Fotografía verificada',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_errorSubidaFoto != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFB91C1C),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No se pudo subir la imagen: $_errorSubidaFoto',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _subiendoFoto
                            ? null
                            : _subirFotografiaAlServidor,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ],
              if (_fotoBytes != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: _subiendoFoto ? null : _seleccionarFotografia,
                    icon: const Icon(Icons.photo_camera_back_rounded, size: 18),
                    label: const Text('Cambiar fotografía'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosa,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: (_fotoBytes == null ||
                        _subiendoFoto ||
                        _guardandoMascota)
                    ? null
                    : _guardarMascotaCompleta,
                icon: _guardandoMascota
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.pets_rounded),
                label: Text(
                  _guardandoMascota
                      ? 'Guardando mascota...'
                      : 'Confirmar imagen y guardar mascota',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
