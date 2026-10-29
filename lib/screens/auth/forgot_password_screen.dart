import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/services/recuperacion_service.dart';
import 'package:paw_match/widgets/feature_icon.dart';

/// Recuperar contraseña en dos pasos:
///   1) escribir el correo y recibir un código
///   2) escribir el código y la contraseña nueva
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _codigo = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();

  int _paso = 1;
  bool _cargando = false;

  @override
  void dispose() {
    _correo.dispose();
    _codigo.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.texto,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(texto),
      ),
    );
  }

  String _mensaje(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _enviarCodigo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await RecuperacionService.solicitarCodigo(_correo.text);
      if (!mounted) return;
      setState(() => _paso = 2);
      _aviso('Si el correo está registrado, te enviamos un código');
    } catch (e) {
      if (mounted) _aviso(_mensaje(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarContrasena() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await RecuperacionService.restablecer(
        correo: _correo.text,
        codigo: _codigo.text,
        nuevaContrasena: _nueva.text,
      );
      if (!mounted) return;
      _aviso('Contraseña actualizada. Ya puedes iniciar sesión');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _aviso(_mensaje(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final paso1 = _paso == 1;
    final puedeVolver = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final esMovil = constraints.maxWidth < 600;
            final topPadding = esMovil ? MediaQuery.paddingOf(context).top : 0.0;
            final bottomPadding = esMovil ? MediaQuery.paddingOf(context).bottom : 0.0;

            return ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HeaderOndulado(
                            puedeVolver: puedeVolver,
                            topPadding: topPadding,
                            esMovil: esMovil,
                          ),
                          const SizedBox(height: 32),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: esMovil ? 24 : 32,
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        paso1
                                            ? '¿Olvidaste tu contraseña?'
                                            : 'Crea una contraseña nueva',
                                        textAlign: TextAlign.center,
                                        style: t.headlineSmall?.copyWith(
                                          color: AppColors.texto,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        paso1
                                            ? 'Escribe tu correo y te enviaremos un código de 6 dígitos.'
                                            : 'Escribe el código que llegó a ${_correo.text.trim()} (vence en 15 minutos).',
                                        textAlign: TextAlign.center,
                                        style: t.bodyMedium?.copyWith(
                                          color: AppColors.texto.withValues(alpha: 0.58),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 26),
                                      if (paso1) ...[
                                        _CampoRecuperacion(
                                          controller: _correo,
                                          icono: const FeatureIcon.sobre(color: AppColors.rosa),
                                          etiqueta: 'Correo electrónico',
                                          teclado: TextInputType.emailAddress,
                                          accion: TextInputAction.done,
                                          onEnviar: _enviarCodigo,
                                          validator: (v) =>
                                              (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                                        ),
                                        const SizedBox(height: 24),
                                        _BotonGradiente(
                                          texto: 'Enviar código',
                                          cargando: _cargando,
                                          onPressed: _enviarCodigo,
                                        ),
                                      ] else ...[
                                        _CampoRecuperacion(
                                          controller: _codigo,
                                          icono: const FeatureIcon.pin(color: AppColors.rosa),
                                          etiqueta: 'Código de 6 dígitos',
                                          teclado: TextInputType.number,
                                          accion: TextInputAction.next,
                                          validator: (v) => (v == null || v.trim().length != 6)
                                              ? 'Ingresa los 6 dígitos'
                                              : null,
                                        ),
                                        const SizedBox(height: 14),
                                        _CampoRecuperacion(
                                          controller: _nueva,
                                          icono: const FeatureIcon.cerradura(color: AppColors.rosa),
                                          etiqueta: 'Contraseña nueva',
                                          esContrasena: true,
                                          accion: TextInputAction.next,
                                          validator: (v) =>
                                              (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                                        ),
                                        const SizedBox(height: 14),
                                        _CampoRecuperacion(
                                          controller: _confirmar,
                                          icono: const FeatureIcon.restablecer(color: AppColors.rosa),
                                          etiqueta: 'Repite la contraseña',
                                          esContrasena: true,
                                          accion: TextInputAction.done,
                                          onEnviar: _cambiarContrasena,
                                          validator: (v) =>
                                              v != _nueva.text ? 'Las contraseñas no coinciden' : null,
                                        ),
                                        const SizedBox(height: 24),
                                        _BotonGradiente(
                                          texto: 'Cambiar contraseña',
                                          cargando: _cargando,
                                          onPressed: _cambiarContrasena,
                                        ),
                                        const SizedBox(height: 18),
                                        Center(
                                          child: TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppColors.rosa,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 2,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            onPressed: _cargando
                                                ? null
                                                : () => setState(() => _paso = 1),
                                            child: const Text(
                                              'Pedir otro código',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: esMovil ? (bottomPadding + 24) : 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderOndulado extends StatelessWidget {
  final bool puedeVolver;
  final double topPadding;
  final bool esMovil;

  const _HeaderOndulado({
    required this.puedeVolver,
    required this.topPadding,
    required this.esMovil,
  });

  @override
  Widget build(BuildContext context) {
    final alturaTotal = esMovil ? (215.0 + topPadding) : 230.0;
    final alturaClip = esMovil ? (185.0 + topPadding) : 195.0;
    final topLogo = esMovil ? (96.0 + topPadding) : 100.0;

    return SizedBox(
      height: alturaTotal,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          ClipPath(
            clipper: _WaveHeaderClipper(),
            child: Container(
              height: alturaClip,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFA3C8),
                    Color(0xFFF772A9),
                    AppColors.rosa,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -24 + topPadding,
                    left: 20,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40 + topPadding,
                    left: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10 + topPadding,
                    right: -25,
                    child: Container(
                      width: 135,
                      height: 135,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 75 + topPadding,
                    right: 65,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  if (puedeVolver)
                    Positioned(
                      top: 14 + topPadding,
                      left: 16,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.maybePop(context),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: topLogo,
            left: 0,
            right: 0,
            child: Center(child: _buildLogoConHalo()),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoConHalo() {
    return Container(
      width: 124,
      height: 124,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.90),
          width: 3.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.28),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(3),
        child: ClipOval(
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.pets, size: 54, color: AppColors.rosa),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.72);
    path.cubicTo(
      size.width * 0.22,
      size.height * 0.95,
      size.width * 0.42,
      size.height * 0.76,
      size.width * 0.52,
      size.height * 0.78,
    );
    path.cubicTo(
      size.width * 0.64,
      size.height * 0.81,
      size.width * 0.82,
      size.height * 0.64,
      size.width,
      size.height * 0.75,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BotonGradiente extends StatelessWidget {
  final String texto;
  final bool cargando;
  final VoidCallback onPressed;

  const _BotonGradiente({
    required this.texto,
    required this.cargando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFA0C6),
            Color(0xFFF165A0),
            AppColors.rosa,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.38),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: cargando ? null : onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: cargando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pets, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        texto,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CampoRecuperacion extends StatefulWidget {
  final TextEditingController controller;
  final Widget icono;
  final String etiqueta;
  final bool esContrasena;
  final TextInputType? teclado;
  final String? Function(String?)? validator;
  final TextInputAction? accion;
  final VoidCallback? onEnviar;

  const _CampoRecuperacion({
    required this.controller,
    required this.icono,
    required this.etiqueta,
    this.esContrasena = false,
    this.teclado,
    this.validator,
    this.accion,
    this.onEnviar,
  });

  @override
  State<_CampoRecuperacion> createState() => _CampoRecuperacionState();
}

class _CampoRecuperacionState extends State<_CampoRecuperacion> {
  late bool _oculto = widget.esContrasena;

  OutlineInputBorder _borde([Color? color, double ancho = 1.2]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
          color: color ?? const Color(0xFFF2BED6),
          width: ancho,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _oculto,
      keyboardType: widget.teclado,
      textInputAction: widget.accion,
      onFieldSubmitted: widget.onEnviar == null ? null : (_) => widget.onEnviar!(),
      validator: widget.validator,
      style: const TextStyle(
        color: AppColors.texto,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: widget.etiqueta,
        hintStyle: TextStyle(
          color: AppColors.texto.withValues(alpha: 0.42),
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xFFFCF9FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: widget.icono,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
        suffixIcon: widget.esContrasena
            ? IconButton(
                tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => _oculto = !_oculto),
                icon: _oculto
                    ? const FeatureIcon.ocultarContrasena(color: AppColors.rosa)
                    : const FeatureIcon.mostrarContrasena(color: AppColors.rosa),
              )
            : null,
        errorStyle: const TextStyle(
          color: Color(0xFFE53935),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        border: _borde(),
        enabledBorder: _borde(),
        focusedBorder: _borde(AppColors.rosa, 1.8),
        errorBorder: _borde(const Color(0xFFE53935), 1.5),
        focusedErrorBorder: _borde(const Color(0xFFE53935), 1.8),
      ),
    );
  }
}
