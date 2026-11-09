import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/navegacion.dart';

/// En Windows, macOS y Linux no hay cámara del sistema. Este delegado abre una captura propia.
void configurarCamaraEscritorio() {
  final instancia = ImagePickerPlatform.instance;
  if (instancia is CameraDelegatingImagePickerPlatform) {
    instancia.cameraDelegate = _EscritorioCamaraDelegate();
  }
}

class _EscritorioCamaraDelegate extends ImagePickerCameraDelegate {
  @override
  Future<XFile?> takePhoto({
    ImagePickerCameraDelegateOptions options =
        const ImagePickerCameraDelegateOptions(),
  }) {
    final nav = navegadorRaiz.currentState;
    if (nav == null) {
      throw StateError('No se pudo abrir la cámara.');
    }
    return nav.push<XFile>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CapturaCamaraPantalla(preferida: options.preferredCameraDevice),
      ),
    );
  }

  @override
  Future<XFile?> takeVideo({
    ImagePickerCameraDelegateOptions options =
        const ImagePickerCameraDelegateOptions(),
  }) async {
    return null;
  }
}

class _CapturaCamaraPantalla extends StatefulWidget {
  final CameraDevice preferida;

  const _CapturaCamaraPantalla({required this.preferida});

  @override
  State<_CapturaCamaraPantalla> createState() => _CapturaCamaraPantallaState();
}

class _CapturaCamaraPantallaState extends State<_CapturaCamaraPantalla> {
  CameraController? _control;
  List<CameraDescription> _camaras = [];
  int _indice = 0;
  bool _lista = false;
  bool _capturando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  int _indiceInicial(List<CameraDescription> camaras) {
    final buscada = widget.preferida == CameraDevice.front
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final i = camaras.indexWhere((c) => c.lensDirection == buscada);
    return i >= 0 ? i : 0;
  }

  Future<void> _abrir([int? indice]) async {
    final anterior = _control;
    _control = null;
    if (mounted) {
      setState(() => _lista = false);
    }
    await anterior?.dispose();

    try {
      if (_camaras.isEmpty) {
        _camaras = await availableCameras();
      }
      if (_camaras.isEmpty) {
        if (mounted) {
          setState(() => _error = 'No se encontró una cámara en este equipo.');
        }
        return;
      }
      final i = indice ?? _indiceInicial(_camaras);
      final ctrl = CameraController(
        _camaras[i],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _indice = i;
        _control = ctrl;
        _lista = true;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo abrir la cámara. Revisa el permiso del sistema.';
      });
    }
  }

  Future<void> _capturar() async {
    final ctrl = _control;
    if (ctrl == null || !ctrl.value.isInitialized || _capturando) return;
    setState(() => _capturando = true);
    try {
      final foto = await ctrl.takePicture();
      if (!mounted) return;
      Navigator.pop(context, foto);
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturando = false);
    }
  }

  @override
  void dispose() {
    _control?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _control;
    final error = _error;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppColors.blanco,
        title: const Text('Tomar foto'),
      ),
      body: error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.blanco, fontSize: 16),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _lista && ctrl != null
                      ? Center(child: CameraPreview(ctrl))
                      : const Center(
                          child: CircularProgressIndicator(color: AppColors.rosa),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_camaras.length > 1)
                        IconButton(
                          tooltip: 'Cambiar cámara',
                          onPressed: _lista && !_capturando
                              ? () => _abrir((_indice + 1) % _camaras.length)
                              : null,
                          icon: const Icon(
                            Icons.cameraswitch_outlined,
                            color: AppColors.blanco,
                            size: 28,
                          ),
                        ),
                      const SizedBox(width: 28),
                      Material(
                        color: AppColors.rosa,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _lista && !_capturando ? _capturar : null,
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: _capturando
                                ? const Padding(
                                    padding: EdgeInsets.all(22),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.6,
                                      color: AppColors.blanco,
                                    ),
                                  )
                                : const Icon(
                                    Icons.photo_camera_outlined,
                                    color: AppColors.blanco,
                                    size: 32,
                                  ),
                          ),
                        ),
                      ),
                      if (_camaras.length > 1) const SizedBox(width: 76),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
