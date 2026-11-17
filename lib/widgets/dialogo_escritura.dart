import 'package:flutter/material.dart';

/// Diálogo para escribir un motivo u observación.
///
/// El campo queda dentro de la zona visible. Los botones van después,
/// así el teclado los tapa y aparecen al deslizar.
class DialogoEscritura extends StatefulWidget {
  final Widget titulo;
  final List<Widget> cuerpo;
  final List<Widget> acciones;
  final MainAxisAlignment alineacionAcciones;

  const DialogoEscritura({
    super.key,
    required this.titulo,
    required this.cuerpo,
    this.acciones = const [],
    this.alineacionAcciones = MainAxisAlignment.end,
  });

  @override
  State<DialogoEscritura> createState() => _DialogoEscrituraState();
}

class _DialogoEscrituraState extends State<DialogoEscritura> {
  final ScrollController _desplazamiento = ScrollController();

  @override
  void dispose() {
    _desplazamiento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final teclado = media.viewInsets.bottom;
    final arriba = media.padding.top + 12;
    final alto = (media.size.height - teclado - arriba - 12).clamp(180.0, media.size.height);

    return MediaQuery(
      data: media.removeViewInsets(removeBottom: true),
      child: Dialog(
        alignment: Alignment.topCenter,
        insetPadding: EdgeInsets.fromLTRB(16, arriba, 16, 12),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 480, maxHeight: alto),
          child: SingleChildScrollView(
            controller: _desplazamiento,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.titulo,
                const SizedBox(height: 14),
                ...widget.cuerpo,
                if (widget.acciones.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OverflowBar(
                    alignment: widget.alineacionAcciones,
                    spacing: 8,
                    overflowSpacing: 8,
                    children: widget.acciones,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Al enfocar el campo, lo deja completo al borde inferior de la zona visible.
/// Lo que esté después, como los botones, queda para el deslizamiento.
class ZonaCampo extends StatefulWidget {
  final Widget Function(FocusNode foco) builder;

  const ZonaCampo({super.key, required this.builder});

  @override
  State<ZonaCampo> createState() => _ZonaCampoState();
}

class _ZonaCampoState extends State<ZonaCampo> {
  late final FocusNode _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(_alCambiarFoco);
  }

  @override
  void dispose() {
    _foco.removeListener(_alCambiarFoco);
    _foco.dispose();
    super.dispose();
  }

  void _alCambiarFoco() {
    if (!_foco.hasFocus) return;
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(_foco);
}

const EdgeInsets rellenoCampoDialogo = EdgeInsets.fromLTRB(16, 28, 16, 4);
