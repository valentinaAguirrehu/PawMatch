import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/auth/forgot_password_screen.dart';
import 'package:paw_match/screens/auth/register_screen.dart';
import 'package:paw_match/screens/match/user_personality.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/feature_icon.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();

  bool _cargando = false;
  bool _recordarContrasena = true;

  @override
  void initState() {
    super.initState();
    _cargarCredenciales();
  }

  Future<void> _cargarCredenciales() async {
    final creds = await Session.obtenerCredencialesRecordadas();
    if (!mounted) return;
    setState(() {
      _recordarContrasena = creds.recordar;
      if (creds.recordar) {
        if (creds.correo.isNotEmpty) _correoCtrl.text = creds.correo;
        if (creds.contrasena.isNotEmpty) _contrasenaCtrl.text = creds.contrasena;
      }
    });
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      final usuario = await ApiService.iniciarSesion(
        correo: _correoCtrl.text.trim(),
        contrasena: _contrasenaCtrl.text,
      );

      if (!mounted) return;

      // Guarda o elimina las credenciales según la preferencia seleccionada
      await Session.guardarCredenciales(
        recordar: _recordarContrasena,
        correo: _correoCtrl.text.trim(),
        contrasena: _contrasenaCtrl.text,
      );

      if (!mounted) return;

      // Guarda quién inició sesión (id, nombre y rol) para usarlo en la app
      Session.iniciar(usuario);

      // Cuestionario solo la primera vez; si ya existe, va al inicio.
      await abrirDestinoTrasAuth(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.texto,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
              // Quita la barra de desplazamiento gris en Web y móvil
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Encabezado ondulado de ancho completo con logo central
                          _HeaderOndulado(
                            puedeVolver: puedeVolver,
                            topPadding: topPadding,
                            esMovil: esMovil,
                          ),

                          const SizedBox(height: 32),

                          // Formulario centrado con ancho óptimo
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
                                        'Iniciar sesión',
                                        textAlign: TextAlign.center,
                                        style: t.headlineSmall?.copyWith(
                                          color: AppColors.texto,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Ingresa tu correo y contraseña para continuar',
                                        textAlign: TextAlign.center,
                                        style: t.bodyMedium?.copyWith(
                                          color: AppColors.texto.withValues(alpha: 0.58),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 26),

                                      // Campo Correo
                                      _CampoLogin(
                                        controller: _correoCtrl,
                                        icono: const FeatureIcon.sobre(color: AppColors.rosa),
                                        etiqueta: 'Correo electrónico',
                                        teclado: TextInputType.emailAddress,
                                        accion: TextInputAction.next,
                                        validator: (v) =>
                                            (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                                      ),
                                      const SizedBox(height: 14),

                                      // Campo Contraseña
                                      _CampoLogin(
                                        controller: _contrasenaCtrl,
                                        icono: const FeatureIcon.cerradura(color: AppColors.rosa),
                                        etiqueta: 'Contraseña',
                                        esContrasena: true,
                                        accion: TextInputAction.done,
                                        onEnviar: _iniciarSesion,
                                        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                                      ),
                                      const SizedBox(height: 10),

                                      // Fila Recordar contraseña y Olvidaste tu contraseña
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              setState(() => _recordarContrasena = !_recordarContrasena);
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: Checkbox(
                                                      value: _recordarContrasena,
                                                      activeColor: AppColors.rosa,
                                                      checkColor: Colors.white,
                                                      side: const BorderSide(
                                                        color: Color(0xFFF2BED6),
                                                        width: 1.8,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      onChanged: (val) {
                                                        setState(() => _recordarContrasena = val ?? false);
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Recordar contraseña',
                                                    style: TextStyle(
                                                      color: AppColors.texto.withValues(alpha: 0.78),
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppColors.rosa,
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const ForgotPasswordScreen(),
                                              ),
                                            ),
                                            child: const Text(
                                              '¿Olvidaste tu contraseña?',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),

                                      // Botón Iniciar sesión con gradiente rosado
                                      _BotonGradienteLogin(
                                        cargando: _cargando,
                                        onPressed: _iniciarSesion,
                                      ),
                                      const SizedBox(height: 18),

                                      // Link Regístrate
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            '¿No tienes cuenta? ',
                                            style: TextStyle(
                                              color: AppColors.texto.withValues(alpha: 0.65),
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppColors.rosa,
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                            ),
                                            child: const Text(
                                              'Regístrate',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
          // Fondo ondulado con gradiente rosado que ocupa el ancho completo
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
                    Color(0xFFFFA3C8), // rosa luminoso
                    Color(0xFFF772A9), // rosa intermedio
                    AppColors.rosa,    // rosa Paw Match (#ED4F9D)
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Burbuja bokeh superior izquierda
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
                  // Burbuja bokeh medio izquierda
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
                  // Burbuja bokeh derecha
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
                  // Burbuja bokeh centro-derecha suave
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

                  // Botón volver (si se puede regresar)
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

          // Logo Paw Match centrado con aro halo que intersecta la onda
          Positioned(
            top: topLogo,
            left: 0,
            right: 0,
            child: Center(
              child: _buildLogoConHalo(),
            ),
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

    // Curva fluida en S de izquierda a derecha
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

class _BotonGradienteLogin extends StatelessWidget {
  final bool cargando;
  final VoidCallback onPressed;

  const _BotonGradienteLogin({
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
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pets, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Iniciar sesión',
                        style: TextStyle(
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

class _CampoLogin extends StatefulWidget {
  final TextEditingController controller;
  final Widget icono;
  final String etiqueta;
  final bool esContrasena;
  final TextInputType? teclado;
  final String? Function(String?)? validator;
  final TextInputAction? accion;
  final VoidCallback? onEnviar;

  const _CampoLogin({
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
  State<_CampoLogin> createState() => _CampoLoginState();
}

class _CampoLoginState extends State<_CampoLogin> {
  late bool _oculto = widget.esContrasena;

  OutlineInputBorder _borde([Color? color, double ancho = 1.2]) =>
      OutlineInputBorder(
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
      onFieldSubmitted: widget.onEnviar == null
          ? null
          : (_) => widget.onEnviar!(),
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
