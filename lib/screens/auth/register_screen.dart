import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/screens/match/user_personality.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/feature_icon.dart';

import 'login_screen.dart';

/// Verde solo para el check de un campo válido. El resto usa [AppColors].
const _verdeOk = Color(0xFF2F9B6A);

/// Misma separación del borde derecho para el visto y el ojo de la contraseña.
const _margenFilo = 12.0;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombresCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();

  DateTime? _nacimiento;
  bool _fechaTocada = false;
  bool _intentoEnviar = false;
  bool _cargando = false;

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  void _aviso(String texto, {bool exito = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: exito ? AppColors.rosa : AppColors.texto,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(texto),
      ),
    );
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate:
          _nacimiento ?? DateTime(ahora.year - 18, ahora.month, ahora.day),
      firstDate: DateTime(ahora.year - 100),
      lastDate: ahora,
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (!mounted) return;
    setState(() {
      _fechaTocada = true;
      if (elegida != null) _nacimiento = elegida;
    });
  }

  String? get _errorFecha {
    if (_nacimiento != null) return null;
    if (_fechaTocada || _intentoEnviar) return 'Requerido';
    return null;
  }

  Future<void> _registrar() async {
    final formularioOk = _formKey.currentState!.validate();
    setState(() => _intentoEnviar = true);
    if (!formularioOk || _nacimiento == null) return;

    setState(() => _cargando = true);

    try {
      final usuario = await ApiService.registrarUsuario(
        nombres: _nombresCtrl.text.trim(),
        apellidos: _apellidosCtrl.text.trim(),
        correo: _correoCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        contrasena: _contrasenaCtrl.text,
        fechaNacimiento: _nacimiento!,
      );

      if (!mounted) return;
      Session.iniciar(usuario);
      await abrirDestinoTrasAuth(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      _aviso(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _irALogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
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
                          // Encabezado ondulado con degradado y logo con halo centrado
                          _HeaderOndulado(
                            puedeVolver: puedeVolver,
                            topPadding: topPadding,
                            esMovil: esMovil,
                          ),

                          const SizedBox(height: 32),

                          // Formulario centrado y adaptado para PC y móvil
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
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
                                        '¡Únete a la familia!',
                                        textAlign: TextAlign.center,
                                        style: t.headlineSmall?.copyWith(
                                          color: AppColors.texto,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 22),

                                      // Nombres
                                      _CampoRegistro(
                                        controller: _nombresCtrl,
                                        icono: const FeatureIcon.persona(color: AppColors.rosa),
                                        etiqueta: 'Nombres',
                                        pista: 'Digite aquí su nombre',
                                        teclado: TextInputType.name,
                                        capitalizacion: TextCapitalization.words,
                                        accion: TextInputAction.next,
                                        validator: _requerido,
                                        mostrarVisto: false,
                                      ),
                                      const SizedBox(height: 16),

                                      // Apellidos
                                      _CampoRegistro(
                                        controller: _apellidosCtrl,
                                        icono: const FeatureIcon.persona(color: AppColors.rosa),
                                        etiqueta: 'Apellidos',
                                        pista: 'Digite aquí sus apellidos',
                                        teclado: TextInputType.name,
                                        capitalizacion: TextCapitalization.words,
                                        accion: TextInputAction.next,
                                        validator: _requerido,
                                        mostrarVisto: false,
                                      ),
                                      const SizedBox(height: 16),

                                      // Correo electrónico
                                      _CampoRegistro(
                                        controller: _correoCtrl,
                                        icono: const FeatureIcon.sobre(color: AppColors.rosa),
                                        etiqueta: 'Correo electrónico',
                                        pista: 'Digite aquí su correo electrónico',
                                        teclado: TextInputType.emailAddress,
                                        accion: TextInputAction.next,
                                        validator: (v) => (v == null || !v.contains('@'))
                                            ? 'Correo inválido'
                                            : null,
                                      ),
                                      const SizedBox(height: 16),

                                      // Teléfono
                                      _CampoRegistro(
                                        controller: _telefonoCtrl,
                                        icono: const FeatureIcon.telefono(color: AppColors.rosa),
                                        etiqueta: 'Teléfono',
                                        pista: 'Digite aquí su número de teléfono',
                                        teclado: TextInputType.phone,
                                        accion: TextInputAction.next,
                                        validator: (v) {
                                          final digitos =
                                              v?.replaceAll(RegExp(r'\D'), '') ?? '';
                                          if (digitos.length < 10) return 'Mínimo 10 dígitos';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      // Fecha de nacimiento
                                      _FechaNacimiento(
                                        fecha: _nacimiento,
                                        error: _errorFecha,
                                        onTap: _elegirFecha,
                                      ),
                                      const SizedBox(height: 16),

                                      // Contraseña
                                      _CampoRegistro(
                                        controller: _contrasenaCtrl,
                                        icono: const FeatureIcon.cerradura(color: AppColors.rosa),
                                        etiqueta: 'Contraseña',
                                        pista: 'Mínimo 6 caracteres',
                                        esContrasena: true,
                                        accion: TextInputAction.done,
                                        onEnviar: _registrar,
                                        validator: (v) => (v == null || v.length < 6)
                                            ? 'Mínimo 6 caracteres'
                                            : null,
                                      ),
                                      const SizedBox(height: 28),

                                      // Botón Crear cuenta con degradado rosado
                                      _BotonGradienteRegistro(
                                        cargando: _cargando,
                                        onPressed: _registrar,
                                      ),
                                      const SizedBox(height: 18),

                                      // Enlace a Iniciar sesión
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            '¿Ya tienes cuenta? ',
                                            style: TextStyle(
                                              color: AppColors.texto.withValues(alpha: 0.65),
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppColors.rosa,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 2,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            onPressed: _cargando ? null : _irALogin,
                                            child: const Text(
                                              'Inicia sesión aquí',
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

  String? _requerido(String? valor) =>
      (valor == null || valor.trim().isEmpty) ? 'Requerido' : null;
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
    final alturaTotal = esMovil ? (176.0 + topPadding) : 190.0;
    final alturaClip = esMovil ? (146.0 + topPadding) : 155.0;
    final topLogo = esMovil ? (56.0 + topPadding) : 60.0;

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

class _CampoRegistro extends StatefulWidget {
  final TextEditingController controller;
  final Widget icono;
  final String etiqueta;
  final String pista;
  final bool esContrasena;
  final TextInputType? teclado;
  final TextCapitalization capitalizacion;
  final TextInputAction? accion;
  final String? Function(String?)? validator;
  final VoidCallback? onEnviar;
  final bool mostrarVisto;

  const _CampoRegistro({
    required this.controller,
    required this.icono,
    required this.etiqueta,
    required this.pista,
    this.esContrasena = false,
    this.teclado,
    this.capitalizacion = TextCapitalization.none,
    this.accion,
    this.validator,
    this.onEnviar,
    this.mostrarVisto = true,
  });

  @override
  State<_CampoRegistro> createState() => _CampoRegistroState();
}

class _CampoRegistroState extends State<_CampoRegistro> {
  final _campoKey = GlobalKey<FormFieldState<String>>();
  late final FocusNode _foco = FocusNode()..addListener(_refrescar);
  bool _oculto = true;
  bool _valido = false;
  bool _tuvoFoco = false;

  @override
  void initState() {
    super.initState();
    _oculto = widget.esContrasena;
    widget.controller.addListener(_revisar);
  }

  @override
  void dispose() {
    _foco.removeListener(_refrescar);
    _foco.dispose();
    widget.controller.removeListener(_revisar);
    super.dispose();
  }

  void _refrescar() {
    if (!mounted) return;
    if (_foco.hasFocus) {
      _tuvoFoco = true;
    } else if (_tuvoFoco) {
      _campoKey.currentState?.validate();
    }
    setState(() {});
  }

  void _revisar() {
    final valor = widget.controller.text;
    final ok = valor.trim().isNotEmpty && widget.validator?.call(valor) == null;
    if (ok != _valido && mounted) setState(() => _valido = ok);
  }

  OutlineInputBorder _borde([Color? color, double ancho = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(
          color: color ?? const Color(0xFFF2BED6),
          width: ancho,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.etiqueta,
            style: texto.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.texto,
            ),
          ),
        ),
        TextFormField(
          key: _campoKey,
          controller: widget.controller,
          focusNode: _foco,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          obscureText: widget.esContrasena && _oculto,
          keyboardType: widget.teclado,
          textCapitalization: widget.capitalizacion,
          textInputAction: widget.accion,
          autocorrect: !widget.esContrasena,
          enableSuggestions: !widget.esContrasena,
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
            hintText: widget.pista,
            hintStyle: TextStyle(
              color: AppColors.texto.withValues(alpha: 0.38),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: const Color(0xFFFCF9FA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 15,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: widget.icono,
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            suffixIcon: _sufijo(),
            suffixIconConstraints: const BoxConstraints(minHeight: 44, minWidth: 0),
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
        ),
      ],
    );
  }

  Widget? _sufijo() {
    if (!widget.mostrarVisto && !widget.esContrasena) return null;

    return Padding(
      padding: const EdgeInsets.only(right: _margenFilo),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.mostrarVisto)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutBack,
              child: _valido
                  ? const FeatureIcon.correcto(
                      key: ValueKey('ok'),
                      color: _verdeOk,
                    )
                  : const SizedBox(key: ValueKey('vacio'), width: 22, height: 22),
            ),
          if (widget.esContrasena)
            IconButton(
              tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: () => setState(() => _oculto = !_oculto),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.only(left: 4),
                minimumSize: const Size(24, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: _oculto
                  ? const FeatureIcon.ocultarContrasena(color: AppColors.rosa)
                  : const FeatureIcon.mostrarContrasena(color: AppColors.rosa),
            ),
        ],
      ),
    );
  }
}

class _FechaNacimiento extends StatelessWidget {
  final DateTime? fecha;
  final String? error;
  final VoidCallback onTap;

  const _FechaNacimiento({
    required this.fecha,
    required this.onTap,
    this.error,
  });

  static const _meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  int _edad(DateTime f) {
    final hoy = DateTime.now();
    var edad = hoy.year - f.year;
    final aunNoCumple =
        hoy.month < f.month || (hoy.month == f.month && hoy.day < f.day);
    if (aunNoCumple) edad--;
    return edad;
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final elegida = fecha;
    final etiqueta = elegida == null
        ? 'Selecciona tu fecha de nacimiento'
        : '${elegida.day} ${_meses[elegida.month - 1]} ${elegida.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Fecha de nacimiento',
            style: texto.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.texto,
            ),
          ),
        ),
        Material(
          color: const Color(0xFFFCF9FA),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: error == null
                      ? const Color(0xFFF2BED6)
                      : const Color(0xFFE53935),
                  width: error == null ? 1.2 : 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, _margenFilo, 14),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 2, right: 10),
                      child: FeatureIcon.calendario(color: AppColors.rosa),
                    ),
                    Expanded(
                      child: Text(
                        etiqueta,
                        style: TextStyle(
                          color: elegida == null
                              ? AppColors.texto.withValues(alpha: 0.38)
                              : AppColors.texto,
                          fontSize: 14,
                          fontWeight: elegida == null
                              ? FontWeight.w400
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (elegida != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.rosaSuave,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_edad(elegida)} años',
                          style: const TextStyle(
                            color: AppColors.rosa,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const FeatureIcon.correcto(color: _verdeOk),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              error!,
              style: const TextStyle(
                color: Color(0xFFE53935),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BotonGradienteRegistro extends StatelessWidget {
  final bool cargando;
  final VoidCallback? onPressed;

  const _BotonGradienteRegistro({
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
                        'Crear cuenta',
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
