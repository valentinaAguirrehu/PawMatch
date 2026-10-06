import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Campo blanco con ícono, para las pantallas de fondo rosado.
/// Si `esContrasena` es true, agrega el ojo para mostrar u ocultar.
class CampoAuth extends StatefulWidget {
  final TextEditingController controller;
  final IconData icono;
  final String etiqueta;
  final bool esContrasena;
  final TextInputType? teclado;
  final String? Function(String?)? validator;
  final TextInputAction? accion;
  final VoidCallback? onEnviar;
  final bool soloLectura;
  final VoidCallback? onTap;

  const CampoAuth({
    super.key,
    required this.controller,
    required this.icono,
    required this.etiqueta,
    this.esContrasena = false,
    this.teclado,
    this.validator,
    this.accion,
    this.onEnviar,
    this.soloLectura = false,
    this.onTap,
  });

  @override
  State<CampoAuth> createState() => _CampoAuthState();
}

class _CampoAuthState extends State<CampoAuth> {
  late bool _oculto = widget.esContrasena;

  OutlineInputBorder _borde([Color? color, double ancho = 0]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: ancho),
      );

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _oculto,
    readOnly: widget.soloLectura,
    onTap: widget.onTap,
    keyboardType: widget.teclado,
    textInputAction: widget.accion,
    onFieldSubmitted: widget.onEnviar == null
        ? null
        : (_) => widget.onEnviar!(),
    validator: widget.validator,
    style: const TextStyle(color: AppColors.texto),
    decoration: InputDecoration(
      hintText: widget.etiqueta,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(widget.icono, color: AppColors.rosa),
      suffixIcon: widget.esContrasena
          ? IconButton(
              tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
              icon: Icon(
                _oculto
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.rosa,
              ),
              onPressed: () => setState(() => _oculto = !_oculto),
            )
          : null,
      // Los errores van en blanco: el rojo no se lee sobre el fondo rosado
      errorStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      border: _borde(),
      enabledBorder: _borde(),
      focusedBorder: _borde(AppColors.bordeRosa, 2),
      errorBorder: _borde(Colors.white, 2),
      focusedErrorBorder: _borde(Colors.white, 2),
    ),
  );
}
