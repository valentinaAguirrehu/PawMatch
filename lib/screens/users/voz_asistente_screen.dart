import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/services/voz_asistente_service.dart';

/// Selector de la voz de OpenAI que usa el asistente.
class VozAsistenteScreen extends StatefulWidget {
  const VozAsistenteScreen({super.key});

  @override
  State<VozAsistenteScreen> createState() => _VozAsistenteScreenState();
}

class _VozAsistenteScreenState extends State<VozAsistenteScreen> {
  final AudioPlayer _reproductor = AudioPlayer();
  String _elegida = VozAsistenteService.defecto;
  String _guardada = VozAsistenteService.defecto;
  String? _escuchando;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _reproductor.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final voz = await VozAsistenteService.vozGuardada();
    if (!mounted) return;
    setState(() {
      _elegida = voz;
      _guardada = voz;
      _cargando = false;
    });
  }

  void _elegir(VozAsistente voz) {
    setState(() => _elegida = voz.id);
  }

  Future<void> _guardar() async {
    if (_guardando || _elegida == _guardada) return;
    setState(() => _guardando = true);
    try {
      await VozAsistenteService.guardar(_elegida);
      if (!mounted) return;
      setState(() => _guardada = _elegida);
      _aviso('Voz guardada. El asistente la usará en todos los formularios.');
    } catch (e) {
      if (!mounted) return;
      _aviso(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _previsualizar(VozAsistente voz) async {
    if (_escuchando != null) return;
    setState(() {
      _elegida = voz.id;
      _escuchando = voz.id;
    });
    try {
      final Uint8List audio = await VozAsistenteService.probar(voz.id);
      await _reproductor.stop();
      await _reproductor.play(BytesSource(audio, mimeType: 'audio/mpeg'));
    } catch (e) {
      if (!mounted) return;
      _aviso(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _escuchando = null);
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.rosa,
        content: Text(texto),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.rosaSuave,
      appBar: AppBar(
        backgroundColor: AppColors.rosa,
        foregroundColor: Colors.white,
        title: const Text('Voz del asistente'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.rosa))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    children: [
                      const Text(
                        'Elige cómo quieres que te hable el asistente. Escucha una muestra y pulsa Guardar para usarla en todos los formularios.',
                        style: TextStyle(color: AppColors.texto, height: 1.35),
                      ),
                      const SizedBox(height: 14),
                      for (final voz in VozAsistenteService.voces)
                        _TarjetaVoz(
                          voz: voz,
                          seleccionada: voz.id == _elegida,
                          guardada: voz.id == _guardada,
                          escuchando: _escuchando == voz.id,
                          ocupada: _escuchando != null,
                          onElegir: () => _elegir(voz),
                          onEscuchar: () => _previsualizar(voz),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: FilledButton(
                      onPressed: _elegida == _guardada || _guardando ? null : _guardar,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosa,
                        disabledBackgroundColor: AppColors.rosaClaro,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: AppColors.texto,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _guardando
                            ? 'Guardando...'
                            : _elegida == _guardada
                                ? 'Voz guardada'
                                : 'Guardar voz',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Botón del perfil. Muestra la voz guardada y se actualiza al guardar otra.
class BotonElegirVoz extends StatefulWidget {
  const BotonElegirVoz({super.key});

  @override
  State<BotonElegirVoz> createState() => _BotonElegirVozState();
}

class _BotonElegirVozState extends State<BotonElegirVoz> {
  @override
  void initState() {
    super.initState();
    VozAsistenteService.vozGuardada();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: VozAsistenteService.vozActual,
      builder: (context, id, _) {
        return OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VozAsistenteScreen()),
          ),
          icon: const Icon(Icons.record_voice_over_rounded, color: AppColors.rosa),
          label: Text('Elegir voz · ${VozAsistenteService.nombre(id)}'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        );
      },
    );
  }
}

/// Nombre de la voz guardada, para las barras del asistente.
class MarcaVozAsistente extends StatelessWidget {
  const MarcaVozAsistente({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: VozAsistenteService.vozActual,
      builder: (context, id, _) {
        return Tooltip(
          message: 'Voz del asistente',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
            ),
            child: Text(
              VozAsistenteService.nombre(id),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TarjetaVoz extends StatelessWidget {
  const _TarjetaVoz({
    required this.voz,
    required this.seleccionada,
    required this.guardada,
    required this.escuchando,
    required this.ocupada,
    required this.onElegir,
    required this.onEscuchar,
  });

  final VozAsistente voz;
  final bool seleccionada;
  final bool guardada;
  final bool escuchando;
  final bool ocupada;
  final VoidCallback onElegir;
  final VoidCallback onEscuchar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onElegir,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: seleccionada ? AppColors.rosa : AppColors.bordeRosa,
                width: seleccionada ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  seleccionada
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: AppColors.rosa,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voz.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.texto,
                        ),
                      ),
                      Text(
                        [
                          voz.detalle,
                          if (voz.id == VozAsistenteService.defecto) 'recomendada',
                          if (guardada) 'guardada',
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.texto, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Escuchar ${voz.nombre}',
                  onPressed: ocupada ? null : onEscuchar,
                  icon: escuchando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.rosa,
                          ),
                        )
                      : const Icon(Icons.volume_up_rounded, color: AppColors.rosa),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
