import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/seguimiento_adopcion_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';
import 'package:paw_match/widgets/star_rating_selector.dart';

/// Formulario para registrar el seguimiento de una adopción ya formalizada.
class AdoptionFormFollowUp extends StatefulWidget {
  final Pet mascota;
  final AdoptionRequest solicitud;
  final VoidCallback? onGuardadoExitoso;
  final int? numeroSiguiente;

  const AdoptionFormFollowUp({
    super.key,
    required this.mascota,
    required this.solicitud,
    this.onGuardadoExitoso,
    this.numeroSiguiente,
  });

  @override
  State<AdoptionFormFollowUp> createState() => _AdoptionFormFollowUpState();
}

class _AdoptionFormFollowUpState extends State<AdoptionFormFollowUp> {
  final _formKey = GlobalKey<FormState>();
  final _alertasCtrl = TextEditingController();

  DateTime _fecha = DateTime.now();
  DateTime? _proximo;
  int _calificacion = 0;
  int _peso = 0;
  int _salud = 0;
  int _entorno = 0;
  int _conducta = 0;
  int _veterinario = 0;
  int _disposicion = 0;
  Uint8List? _fotoEstado;
  String? _nombreFotoEstado;
  Uint8List? _fotoEntorno;
  String? _nombreFotoEntorno;
  bool _guardando = false;

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  void dispose() {
    _alertasCtrl.dispose();
    super.dispose();
  }

  String _fechaTexto(DateTime fecha) =>
      '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';

  Future<void> _elegirFecha({required bool proximo}) async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: proximo ? (_proximo ?? ahora) : _fecha,
      firstDate: proximo ? DateTime(ahora.year, ahora.month, ahora.day) : DateTime(ahora.year - 2),
      lastDate: proximo ? DateTime(ahora.year + 2) : ahora,
      helpText: proximo ? 'Próximo seguimiento' : 'Fecha del seguimiento',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (elegida == null || !mounted) return;
    setState(() {
      if (proximo) {
        _proximo = elegida;
      } else {
        _fecha = elegida;
      }
    });
  }

  Future<void> _elegirFoto({required bool estado, required ImageSource origen}) async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: origen,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (archivo == null || !mounted) return;
      final bytes = await archivo.readAsBytes();
      if (!mounted) return;
      final nombre = archivo.name.trim().isEmpty ? 'foto.jpg' : archivo.name;
      setState(() {
        if (estado) {
          _fotoEstado = bytes;
          _nombreFotoEstado = nombre;
        } else {
          _fotoEntorno = bytes;
          _nombreFotoEntorno = nombre;
        }
      });
    } catch (_) {
      if (!mounted) return;
      _aviso(
        origen == ImageSource.camera
            ? 'No se pudo abrir la cámara. Revisa el permiso o elige la foto desde la galería.'
            : 'No se pudo abrir la imagen.',
      );
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _guardando) return;
    if (_calificacion < 1) {
      _aviso('Califica al adoptante de 1 a 5 estrellas');
      return;
    }
    final estrellas = {
      'peso y pelaje': _peso,
      'condición sanitaria': _salud,
      'espacio donde vive': _entorno,
      'comportamiento': _conducta,
    };
    for (final entrada in estrellas.entries) {
      if (entrada.value < 1) {
        _aviso('Califica de 1 a 5 estrellas: ${entrada.key}');
        return;
      }
    }
    final respuestas = {
      'compromiso veterinario': _veterinario,
      'disposición del adoptante': _disposicion,
    };
    for (final entrada in respuestas.entries) {
      if (entrada.value < 1) {
        _aviso('Responde Sí, No o Puede mejorar: ${entrada.key}');
        return;
      }
    }
    if (_fotoEstado == null) {
      _aviso('La foto del estado general del perrito es obligatoria');
      return;
    }
    if (_proximo == null) {
      _aviso('Elige la fecha del próximo seguimiento');
      return;
    }

    setState(() => _guardando = true);
    try {
      final res = await SeguimientoAdopcionService.crearSeguimiento(
        idSolicitud: widget.solicitud.id,
        calificacion: _calificacion,
        observaciones: _alertasCtrl.text,
        fechaSeguimiento: _fecha,
        proximoSeguimiento: _proximo!,
        pesoSaludable: _peso,
        condicionSanitaria: _salud,
        entornoApto: _entorno,
        comportamiento: _conducta,
        compromisoVeterinario: _veterinario,
        disposicionAdoptante: _disposicion,
        fotoEstado: _fotoEstado!,
        nombreFotoEstado: _nombreFotoEstado ?? 'estado.jpg',
        fotoEntorno: _fotoEntorno,
        nombreFotoEntorno: _nombreFotoEntorno,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.rosa,
          content: Text(res['mensaje']?.toString() ?? 'Seguimiento de ${widget.mascota.nombre} registrado'),
        ),
      );
      widget.onGuardadoExitoso?.call();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (!confirmar || !mounted) return;
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    Session.cerrar();
    Navegacion.ir(context, const WelcomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    final mascota = widget.mascota;
    final solicitud = widget.solicitud;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            BarraSuperior(
              iconoTitulo: Icons.favorite_rounded,
              titulo: 'Formulario',
              onCerrarSesion: _confirmarCerrarSesion,
              onVolver: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _encabezado(mascota, solicitud),
                    const SizedBox(height: 16),
                    _FechaCampo(
                      etiqueta: 'Fecha del seguimiento',
                      valor: _fechaTexto(_fecha),
                      onTap: () => _elegirFecha(proximo: false),
                    ),
                    const SizedBox(height: 18),
                    const _TituloSeccion('1. Estado físico y nutricional'),
                    _PreguntaPuntaje(
                      pregunta:
                          '¿El perrito se encuentra en un peso saludable, con buen pelaje y sin signos de desnutrición o delgadez?',
                      puntaje: _peso,
                      estrellas: true,
                      onChanged: (valor) => setState(() => _peso = valor),
                    ),
                    _PreguntaPuntaje(
                      pregunta:
                          '¿El animal se observa limpio, sano, sin heridas, parásitos (pulgas/garrapatas), secreciones o signos de enfermedad?',
                      puntaje: _salud,
                      estrellas: true,
                      onChanged: (valor) => setState(() => _salud = valor),
                    ),
                    const _TituloSeccion('2. Entorno y bienestar'),
                    _PreguntaPuntaje(
                      pregunta:
                          '¿El espacio donde vive es apto, seguro, limpio, protegido de la lluvia/sol y con acceso constante a agua fresca?',
                      puntaje: _entorno,
                      estrellas: true,
                      onChanged: (valor) => setState(() => _entorno = valor),
                    ),
                    _PreguntaPuntaje(
                      pregunta:
                          '¿Se observa al perrito confiado, tranquilo y sin muestras de temor excesivo o agresividad hacia la nueva familia?',
                      puntaje: _conducta,
                      estrellas: true,
                      onChanged: (valor) => setState(() => _conducta = valor),
                    ),
                    const _TituloSeccion('3. Compromiso del adoptante'),
                    _PreguntaPuntaje(
                      pregunta:
                          '¿El adoptante ha cumplido con el esquema de vacunación, desparasitación y/o cita de esterilización pendiente?',
                      puntaje: _veterinario,
                      onChanged: (valor) => setState(() => _veterinario = valor),
                    ),
                    _PreguntaPuntaje(
                      pregunta:
                          '¿Se evidencia buena disposición, trato afectuoso y responsabilidad por parte del adoptante para cubrir las necesidades del perrito?',
                      puntaje: _disposicion,
                      onChanged: (valor) => setState(() => _disposicion = valor),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _alertasCtrl,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoracion(
                        'Observación general',
                      ).copyWith(
                        hintText:
                            'Describe cómo se encuentra la mascota en esta visita.',
                      ),
                      validator: (valor) {
                        if (valor == null || valor.trim().length < 3) {
                          return 'Escribe una observación general';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    const _TituloSeccion('Calificación del adoptante'),
                    const SizedBox(height: 6),
                    const Text(
                      'Califica el compromiso general del adoptante en esta visita.',
                      style: TextStyle(fontSize: 13, color: AppColors.texto),
                    ),
                    const SizedBox(height: 6),
                    StarRatingSelector(
                      rating: _calificacion,
                      mostrarEtiqueta: true,
                      onRatingChanged: (valor) => setState(() => _calificacion = valor),
                    ),
                    const SizedBox(height: 18),
                    const _TituloSeccion('Registro fotográfico'),
                    const SizedBox(height: 8),
                    _FotoCampo(
                      titulo: 'Foto 1 · Estado general',
                      ayuda: 'Cuerpo entero del perrito, donde se aprecie su condición física. Obligatoria.',
                      bytes: _fotoEstado,
                      obligatoria: true,
                      onGaleria: () => _elegirFoto(estado: true, origen: ImageSource.gallery),
                      onCamara: () => _elegirFoto(estado: true, origen: ImageSource.camera),
                      onQuitar: () => setState(() {
                        _fotoEstado = null;
                        _nombreFotoEstado = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    _FotoCampo(
                      titulo: 'Foto 2 · Entorno',
                      ayuda: 'Área donde duerme, come o pasa la mayor parte del tiempo. Opcional.',
                      bytes: _fotoEntorno,
                      obligatoria: false,
                      onGaleria: () => _elegirFoto(estado: false, origen: ImageSource.gallery),
                      onCamara: () => _elegirFoto(estado: false, origen: ImageSource.camera),
                      onQuitar: () => setState(() {
                        _fotoEntorno = null;
                        _nombreFotoEntorno = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    const _TituloSeccion('Próximo seguimiento'),
                    const SizedBox(height: 8),
                    _FechaCampo(
                      etiqueta: 'Fecha del próximo seguimiento',
                      valor: _proximo == null ? 'Elige una fecha' : _fechaTexto(_proximo!),
                      onTap: () => _elegirFecha(proximo: true),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosa,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Guardar seguimiento',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado(Pet mascota, AdoptionRequest solicitud) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 64, height: 64, child: PetImage(url: mascota.foto)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mascota.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  'Adoptante: ${solicitud.applicantFullName}',
                  style: const TextStyle(fontSize: 13, color: AppColors.texto),
                ),
                Text(
                  'Inicio: ${solicitud.adoptionStartDateLabel ?? 'Sin fecha'}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                ),
                if (widget.numeroSiguiente != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Seguimiento ${widget.numeroSiguiente}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.rosa),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoracion(String etiqueta) {
    return InputDecoration(
      labelText: etiqueta,
      alignLabelWithHint: true,
      filled: true,
      fillColor: AppColors.rosaSuave,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;
  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.texto),
      ),
    );
  }
}

class _PreguntaPuntaje extends StatelessWidget {
  final String pregunta;
  final int puntaje;
  final bool estrellas;
  final ValueChanged<int> onChanged;

  const _PreguntaPuntaje({
    required this.pregunta,
    required this.puntaje,
    required this.onChanged,
    this.estrellas = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0E5EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pregunta, style: const TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.texto)),
          const SizedBox(height: 8),
          if (estrellas)
            StarRatingSelector(
              rating: puntaje,
              starSize: 30,
              onRatingChanged: onChanged,
            )
          else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opcion in const [
                (5, 'Sí'),
                (1, 'No'),
                (3, 'Puede mejorar'),
              ])
                ChoiceChip(
                  label: Text(opcion.$2),
                  selected: puntaje == opcion.$1,
                  selectedColor: AppColors.rosa.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: puntaje == opcion.$1 ? AppColors.rosa : AppColors.texto,
                  ),
                  side: BorderSide(
                    color: puntaje == opcion.$1 ? AppColors.rosa : const Color(0xFFE4D5DE),
                  ),
                  onSelected: (_) => onChanged(opcion.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FotoCampo extends StatelessWidget {
  final String titulo;
  final String ayuda;
  final Uint8List? bytes;
  final bool obligatoria;
  final VoidCallback onGaleria;
  final VoidCallback onCamara;
  final VoidCallback onQuitar;

  const _FotoCampo({
    required this.titulo,
    required this.ayuda,
    required this.bytes,
    required this.obligatoria,
    required this.onGaleria,
    required this.onCamara,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: obligatoria && bytes == null ? AppColors.rosa.withValues(alpha: 0.45) : const Color(0xFFF0E5EC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(ayuda, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                onPressed: onGaleria,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(bytes == null ? 'Galería' : 'Cambiar'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rosa,
                  side: const BorderSide(color: AppColors.rosa),
                ),
                onPressed: onCamara,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Tomar foto'),
              ),
              if (bytes != null) TextButton(onPressed: onQuitar, child: const Text('Quitar')),
            ],
          ),
        ],
      ),
    );
  }
}

class _FechaCampo extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final VoidCallback onTap;

  const _FechaCampo({
    required this.etiqueta,
    required this.valor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.rosaSuave,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: AppColors.rosa, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etiqueta, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    Text(valor, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.texto)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
