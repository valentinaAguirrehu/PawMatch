import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/services/pets_service.dart';

class DogPersonalityController extends ChangeNotifier {
  final Map<String, double> _valores = {
    for (final r in rasgosMascota) r.clave: 3,
  };

  bool _cargando = false;
  bool _disposed = false;

  bool get cargando => _cargando;

  double valorDe(String clave) => _valores[clave] ?? 3;

  Map<String, int> get personalidad => {
    for (final r in rasgosMascota) r.clave: _valores[r.clave]!.round(),
  };

  void actualizar(String clave, double valor) {
    if (!_valores.containsKey(clave)) return;
    _valores[clave] = valor;
    _notificar();
  }

  Future<String?> cargar(String mascotaId) async {
    _cargando = true;
    _notificar();
    String? error;
    try {
      final completa = await PetsService.obtener(mascotaId);
      for (final entrada in completa.personalidad.entries) {
        if (!_valores.containsKey(entrada.key)) continue;
        final numero = switch (entrada.value) {
          int n => n,
          double n => n.round(),
          String texto => int.tryParse(texto),
          _ => null,
        };
        if (numero == null) continue;
        _valores[entrada.key] = numero.clamp(1, 5).toDouble();
      }
    } catch (_) {
      error = 'No se pudo cargar la personalidad actual';
    } finally {
      _cargando = false;
      _notificar();
    }
    return error;
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Cuestionario de 1 a 5. Devuelve los valores al guardar, o null si se cancela.
Future<Map<String, int>?> pedirPersonalidadMascota(
  BuildContext context, {
  String? sexo,
}) {
  return showDialog<Map<String, int>>(
    context: context,
    builder: (_) => _DialogoAsignarPersonalidad(sexo: sexo),
  );
}

class _DialogoAsignarPersonalidad extends StatefulWidget {
  final String? sexo;
  const _DialogoAsignarPersonalidad({this.sexo});

  @override
  State<_DialogoAsignarPersonalidad> createState() =>
      _DialogoAsignarPersonalidadState();
}

class _DialogoAsignarPersonalidadState
    extends State<_DialogoAsignarPersonalidad> {
  final _controller = DogPersonalityController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height * 0.62;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Asignar personalidad'),
      content: SizedBox(
        width: 520,
        height: alto,
        child: SingleChildScrollView(
          child: DogPersonality(controller: _controller, sexo: widget.sexo),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
          onPressed: () => Navigator.pop(context, _controller.personalidad),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class DogPersonality extends StatefulWidget {
  final DogPersonalityController controller;

  final String? mascotaId;
  final String? sexo;

  const DogPersonality({
    super.key,
    required this.controller,
    this.mascotaId,
    this.sexo,
  });

  @override
  State<DogPersonality> createState() => _DogPersonalityState();
}

class _DogPersonalityState extends State<DogPersonality> {
  @override
  void initState() {
    super.initState();
    final id = widget.mascotaId;
    if (id == null || id.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.cargar(id).then((error) {
        if (!mounted || error == null) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _contenido(),
    );
  }

  Widget _contenido() {
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personalidad',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Evalúa a la mascota de 1 a 5 en cada rasgo. Estas respuestas se '
          'usan para calcular el match con los adoptantes.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        if (controller.cargando)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(color: AppColors.rosa),
          ),
        const SizedBox(height: 8),
        for (final r in rasgosMascota)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            decoration: BoxDecoration(
              color: AppColors.rosaSuave,
              border: Border.all(color: AppColors.bordeRosa),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(r.icono, size: 18, color: AppColors.rosa),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.titulo,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      controller.valorDe(r.clave).round().toString(),
                      style: const TextStyle(
                        color: AppColors.rosa,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  r.preguntaMascotaPara(widget.sexo),
                  style: const TextStyle(fontSize: 13),
                ),
                Slider(
                  value: controller.valorDe(r.clave),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: AppColors.rosa,
                  label: controller.valorDe(r.clave).round().toString(),
                  onChanged: controller.cargando
                      ? null
                      : (v) => controller.actualizar(r.clave, v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '1 · ${r.minimoPara(widget.sexo)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '5 · ${r.maximoPara(widget.sexo)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
      ],
    );
  }
}
