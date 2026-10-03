import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/logo_paw.dart';

import 'login_screen.dart';

/// Verde solo para el check de un campo válido. El resto usa [AppColors].
const _verdeOk = Color(0xFF2F9B6A);

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
      final nombre = usuario['nombres'] ?? _nombresCtrl.text.trim();
      _aviso(
        '¡Listo, $nombre! Tu cuenta ya está creada ${FeatureIcon.huella}',
        exito: true,
      );
    } catch (e) {
      if (!mounted) return;
      _aviso(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
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
    final texto = Theme.of(context).textTheme;
    final boton = texto.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    return Scaffold(
      backgroundColor: AppColors.blanco,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Encabezado(),
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    28,
                    28,
                    28,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Cuéntanos un poco de ti para encontrar a tu peludito ideal.',
                          style: texto.bodyMedium?.copyWith(
                            color: AppColors.texto.withValues(alpha: 0.62),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _CampoRegistro(
                          controller: _nombresCtrl,
                          icono: const FeatureIcon.persona(color: AppColors.rosa),
                          etiqueta: 'Nombres',
                          pista: 'Digite aquí su nombre',
                          teclado: TextInputType.name,
                          capitalizacion: TextCapitalization.words,
                          accion: TextInputAction.next,
                          validator: _requerido,
                        ),
                        const SizedBox(height: 16),
                        _CampoRegistro(
                          controller: _apellidosCtrl,
                          icono: const FeatureIcon.persona(color: AppColors.rosa),
                          etiqueta: 'Apellidos',
                          pista: 'Digite aquí sus apellidos',
                          teclado: TextInputType.name,
                          capitalizacion: TextCapitalization.words,
                          accion: TextInputAction.next,
                          validator: _requerido,
                        ),
                        const SizedBox(height: 16),
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
                        _FechaNacimiento(
                          fecha: _nacimiento,
                          error: _errorFecha,
                          onTap: _elegirFecha,
                        ),
                        const SizedBox(height: 16),
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
                        FilledButton.icon(
                          onPressed: _cargando ? null : _registrar,
                          icon: _cargando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: AppColors.blanco,
                                  ),
                                )
                              : const FeatureIcon.mascota(),
                          label: Text(
                            _cargando ? 'Creando cuenta…' : 'Crear cuenta',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            textStyle: boton,
                            disabledBackgroundColor: AppColors.rosa.withValues(
                              alpha: 0.55,
                            ),
                            disabledForegroundColor: AppColors.blanco,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '¿Ya tienes cuenta? ',
                              style: texto.bodyMedium?.copyWith(
                                color: AppColors.texto.withValues(alpha: 0.62),
                              ),
                            ),
                            TextButton(
                              onPressed: _cargando ? null : _irALogin,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Inicia sesión aquí',
                                style: TextStyle(fontWeight: FontWeight.w800),
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
      ),
    );
  }

  String? _requerido(String? valor) =>
      (valor == null || valor.trim().isEmpty) ? 'Requerido' : null;
}

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final puedeVolver = Navigator.canPop(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.rosa,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 28, 32),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: puedeVolver
                    ? IconButton(
                        tooltip: 'Volver',
                        onPressed: () => Navigator.maybePop(context),
                        icon: const FeatureIcon.volver(),
                        color: AppColors.blanco,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.blanco.withValues(
                            alpha: 0.18,
                          ),
                        ),
                      )
                    : const SizedBox(height: 48),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.blanco,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.texto.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const LogoPaw(tamano: 92),
              ),
              const SizedBox(height: 18),
              Text(
                'Crea tu cuenta ${FeatureIcon.huella}',
                textAlign: TextAlign.center,
                style: texto.headlineMedium?.copyWith(
                  color: AppColors.blanco,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Un hogar nuevo empieza con tu registro',
                textAlign: TextAlign.center,
                style: texto.titleMedium?.copyWith(
                  color: AppColors.blanco.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final enfocado = _foco.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.etiqueta,
          style: texto.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.texto,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: enfocado
                ? [
                    BoxShadow(
                      color: AppColors.rosa.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: TextFormField(
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
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: widget.pista,
              hintStyle: TextStyle(
                color: AppColors.texto.withValues(alpha: 0.38),
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixIcon: widget.icono,
              suffixIcon: _sufijo(),
              suffixIconConstraints: const BoxConstraints(
                minHeight: 48,
                minWidth: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sufijo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
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
              padding: const EdgeInsets.only(left: 4, right: 16),
              minimumSize: const Size(24, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: _oculto
                ? const FeatureIcon.ocultarContrasena(color: AppColors.rosa)
                : const FeatureIcon.mostrarContrasena(color: AppColors.rosa),
          ),
      ],
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
        ? 'Selecciona tu fecha'
        : '${elegida.day} ${_meses[elegida.month - 1]} ${elegida.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fecha de nacimiento',
          style: texto.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.texto,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: AppColors.rosaSuave,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: error == null ? AppColors.bordeRosa : Colors.red,
                  width: error == null ? 1 : 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        etiqueta,
                        style: TextStyle(
                          color: elegida == null
                              ? AppColors.texto.withValues(alpha: 0.38)
                              : AppColors.texto,
                          fontWeight: elegida == null
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (elegida != null) ...[
                      Text(
                        '${_edad(elegida)} años',
                        style: texto.bodySmall?.copyWith(
                          color: AppColors.texto.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const FeatureIcon.correcto(color: _verdeOk),
                      const SizedBox(width: 6),
                    ],
                    const FeatureIcon.calendario(color: AppColors.rosa),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: texto.bodySmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
