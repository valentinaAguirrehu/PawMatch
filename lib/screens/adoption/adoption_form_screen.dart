import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Formulario para solicitar la adopción de una mascota.
class AdoptionFormScreen extends StatefulWidget {
  final Pet pet;

  const AdoptionFormScreen({super.key, required this.pet});

  @override
  State<AdoptionFormScreen> createState() => _AdoptionFormScreenState();
}

class _AdoptionFormScreenState extends State<AdoptionFormScreen> {
  static const _viviendas = ['Casa', 'Apartamento', 'Finca', 'Habitación'];
  static const _tiempos = [
    'Menos de 2 horas al día',
    'De 2 a 4 horas al día',
    'Más de 4 horas al día',
    'Estoy en casa todo el día',
  ];

  final _otrasCtrl = TextEditingController();
  final _infoCtrl = TextEditingController();

  int _paso = 0;
  bool _revisando = true;
  bool _enviando = false;
  String? _error;

  String? _vivienda;
  bool? _patio;
  bool? _ninos;
  bool? _otrasMascotas;
  String? _tiempo;
  bool? _experiencia;

  Uint8List? _cedulaBytes;
  String? _cedulaNombre;
  Uint8List? _reciboBytes;
  String? _reciboNombre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revisarSiPuedeEnviar());
  }

  @override
  void dispose() {
    _otrasCtrl.dispose();
    _infoCtrl.dispose();
    super.dispose();
  }

  Future<void> _revisarSiPuedeEnviar() async {
    final estado = widget.pet.estadoAdopcion.toLowerCase();
    if (estado == 'adoptado' || estado == 'en_proceso') {
      _avisarYSalir(
        estado == 'adoptado'
            ? '${widget.pet.nombre} ya fue adoptado.'
            : '${widget.pet.nombre} ya tiene un proceso de adopción en curso.',
      );
      return;
    }

    try {
      final lista = await AdoptionService.listMine(petId: widget.pet.id);
      if (!mounted) return;
      final activa = lista.where((s) => s.isPending || s.isApproved);
      if (activa.isNotEmpty) {
        final solicitud = activa.first;
        _avisarYSalir(
          solicitud.isApproved
              ? 'Ya tienes una adopción aprobada para ${widget.pet.nombre}.'
              : 'Ya enviaste una solicitud para ${widget.pet.nombre}. Está pendiente de revisión.',
        );
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _revisando = false);
  }

  void _avisarYSalir(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    Navigator.pop(context);
  }

  String? _validarPaso() {
    if (_paso == 0) {
      if (_vivienda == null) return 'Elige el tipo de vivienda.';
      if (_patio == null) return 'Indica si la vivienda tiene patio.';
      if (_ninos == null) return 'Indica si hay niños en el hogar.';
      if (_otrasMascotas == null) return 'Indica si tienes otras mascotas.';
      if (_otrasMascotas == true && _otrasCtrl.text.trim().isEmpty) {
        return 'Describe las otras mascotas del hogar.';
      }
      if (_otrasCtrl.text.trim().length > 200) {
        return 'La descripción de las otras mascotas no puede pasar de 200 caracteres.';
      }
    }
    if (_paso == 1) {
      if (_tiempo == null) return 'Indica cuánto tiempo puedes dedicarle.';
      if (_experiencia == null) return 'Indica si has tenido mascotas antes.';
      if (_infoCtrl.text.trim().length < 20) {
        return 'Cuéntanos un poco más (mínimo 20 caracteres).';
      }
    }
    if (_paso == 2) {
      if (_cedulaBytes == null) return 'Adjunta la foto de tu cédula.';
      if (_reciboBytes == null) return 'Adjunta la foto de un recibo de servicio público.';
    }
    return null;
  }

  void _continuar() {
    final error = _validarPaso();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _paso += 1;
    });
  }

  Future<void> _elegirFoto({required bool cedula}) async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.rosa),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.rosa),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null || !mounted) return;

    try {
      final archivo = await ImagePicker().pickImage(
        source: origen,
        imageQuality: 85,
      );
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      final nombre = archivo.name.trim().isEmpty
          ? (cedula ? 'cedula.jpg' : 'recibo.jpg')
          : archivo.name;
      if (!mounted) return;
      setState(() {
        _error = null;
        if (cedula) {
          _cedulaBytes = bytes;
          _cedulaNombre = nombre;
        } else {
          _reciboBytes = bytes;
          _reciboNombre = nombre;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la imagen: $e')),
      );
    }
  }

  Future<void> _enviar() async {
    final error = _validarPaso();
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      await AdoptionService.submit(
        petId: widget.pet.id,
        housingType: _vivienda!,
        hasYard: _patio!,
        hasChildren: _ninos!,
        hasOtherPets: _otrasMascotas!,
        otherPets: _otrasCtrl.text.trim(),
        availableTime: _tiempo!,
        previousExperience: _experiencia!,
        additionalInfo: _infoCtrl.text.trim(),
        idCardBytes: _cedulaBytes!,
        idCardName: _cedulaNombre!,
        utilityBillBytes: _reciboBytes!,
        utilityBillName: _reciboNombre!,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 52),
          title: const Text('Solicitud enviada'),
          content: Text(
            'Tu solicitud para adoptar a ${widget.pet.nombre} ha sido enviada a la Fundación Maritza Arévalo.\n\n'
            'El administrador revisará tus respuestas y datos. Cuando haya una decisión, recibirás una notificación y podrás ver las observaciones en Mis adopciones.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      final mensaje = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text(mensaje)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_enviando,
      child: Scaffold(
        appBar: AppBar(title: Text('Adoptar a ${widget.pet.nombre}')),
        body: _revisando
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    children: [
                      _Pasos(paso: _paso),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          children: [
                            _MascotaResumen(pet: widget.pet),
                            const SizedBox(height: 16),
                            if (_paso == 0) ..._pasoHogar(t),
                            if (_paso == 1) ..._pasoExperiencia(t),
                            if (_paso == 2) ..._pasoDocumentos(t),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _botones(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  List<Widget> _pasoHogar(TextTheme t) => [
    Text(
      'Cuéntanos sobre tu hogar',
      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 14),
    _Opciones(
      titulo: '¿En qué tipo de vivienda vives?',
      opciones: _viviendas,
      valor: _vivienda,
      onChanged: (v) => setState(() => _vivienda = v),
    ),
    const SizedBox(height: 16),
    _SiNo(
      titulo: '¿La vivienda tiene patio o zona verde?',
      valor: _patio,
      onChanged: (v) => setState(() => _patio = v),
    ),
    const SizedBox(height: 16),
    _SiNo(
      titulo: '¿Viven niños en el hogar?',
      valor: _ninos,
      onChanged: (v) => setState(() => _ninos = v),
    ),
    const SizedBox(height: 16),
    _SiNo(
      titulo: '¿Tienes otras mascotas actualmente?',
      valor: _otrasMascotas,
      onChanged: (v) => setState(() => _otrasMascotas = v),
    ),
    if (_otrasMascotas == true) ...[
      const SizedBox(height: 12),
      TextField(
        controller: _otrasCtrl,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: '¿Cuáles?',
          hintText: 'Por ejemplo: un gato adulto y un perro pequeño',
          border: OutlineInputBorder(),
        ),
      ),
    ],
  ];

  List<Widget> _pasoExperiencia(TextTheme t) => [
    Text(
      'Tu tiempo y experiencia',
      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 14),
    _Opciones(
      titulo: '¿Cuánto tiempo al día puedes dedicarle?',
      opciones: _tiempos,
      valor: _tiempo,
      onChanged: (v) => setState(() => _tiempo = v),
    ),
    const SizedBox(height: 16),
    _SiNo(
      titulo: '¿Has tenido mascotas antes?',
      valor: _experiencia,
      onChanged: (v) => setState(() => _experiencia = v),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: _infoCtrl,
      minLines: 4,
      maxLines: 7,
      maxLength: 2000,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: '¿Por qué quieres adoptar a ${widget.pet.nombre}?',
        hintText: 'Cuéntanos cómo sería su día a día en tu hogar.',
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
    ),
  ];

  List<Widget> _pasoDocumentos(TextTheme t) => [
    Text(
      'Documentos de verificación',
      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 6),
    Text(
      'Estas fotos solo las puede ver el personal de la fundación.',
      style: t.bodyMedium?.copyWith(color: Colors.black54),
    ),
    const SizedBox(height: 14),
    _FotoCampo(
      titulo: 'Foto de la cédula',
      bytes: _cedulaBytes,
      onElegir: () => _elegirFoto(cedula: true),
    ),
    const SizedBox(height: 14),
    _FotoCampo(
      titulo: 'Foto de un recibo de servicio público',
      bytes: _reciboBytes,
      onElegir: () => _elegirFoto(cedula: false),
    ),
  ];

  Widget _botones() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            if (_paso > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _enviando ? null : () => setState(() {
                    _paso -= 1;
                    _error = null;
                  }),
                  child: const Text('Atrás'),
                ),
              ),
            if (_paso > 0) const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosa,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _enviando ? null : (_paso < 2 ? _continuar : _enviar),
                child: _enviando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_paso < 2 ? 'Continuar' : 'Enviar solicitud'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pasos extends StatelessWidget {
  final int paso;
  const _Pasos({required this.paso});

  @override
  Widget build(BuildContext context) {
    const etiquetas = ['Hogar', 'Experiencia', 'Documentos'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          for (var i = 0; i < etiquetas.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= paso ? AppColors.rosa : AppColors.bordeRosa,
                ),
              ),
            Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: i <= paso ? AppColors.rosa : AppColors.rosaClaro,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i <= paso ? Colors.white : AppColors.rosa,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  etiquetas[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: i == paso ? AppColors.rosa : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MascotaResumen extends StatelessWidget {
  final Pet pet;
  const _MascotaResumen({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: PetImage(url: pet.foto),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  [
                    pet.especie,
                    if ((pet.raza ?? '').isNotEmpty) pet.raza!,
                    pet.edadTexto,
                  ].join(' · '),
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Opciones extends StatelessWidget {
  final String titulo;
  final List<String> opciones;
  final String? valor;
  final ValueChanged<String> onChanged;

  const _Opciones({
    required this.titulo,
    required this.opciones,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opcion in opciones)
              ChoiceChip(
                label: Text(opcion),
                selected: valor == opcion,
                selectedColor: AppColors.rosa,
                labelStyle: TextStyle(
                  color: valor == opcion ? Colors.white : AppColors.texto,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => onChanged(opcion),
              ),
          ],
        ),
      ],
    );
  }
}

class _SiNo extends StatelessWidget {
  final String titulo;
  final bool? valor;
  final ValueChanged<bool> onChanged;

  const _SiNo({
    required this.titulo,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Sí'),
              selected: valor == true,
              selectedColor: AppColors.rosa,
              labelStyle: TextStyle(
                color: valor == true ? Colors.white : AppColors.texto,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => onChanged(true),
            ),
            ChoiceChip(
              label: const Text('No'),
              selected: valor == false,
              selectedColor: AppColors.rosa,
              labelStyle: TextStyle(
                color: valor == false ? Colors.white : AppColors.texto,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}

class _FotoCampo extends StatelessWidget {
  final String titulo;
  final Uint8List? bytes;
  final VoidCallback onElegir;

  const _FotoCampo({
    required this.titulo,
    required this.bytes,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes!, height: 160, fit: BoxFit.cover),
            )
          else
            Container(
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.rosaSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_a_photo_outlined, color: AppColors.rosa, size: 32),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onElegir,
            icon: const Icon(Icons.image_outlined),
            label: Text(bytes == null ? 'Adjuntar imagen' : 'Cambiar imagen'),
          ),
        ],
      ),
    );
  }
}
