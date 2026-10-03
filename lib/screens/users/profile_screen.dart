import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/user.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/pet_card.dart';

const _pendiente = 'Sin completar';
const _colorPendiente = Color(0xFFC62828);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombresCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _documentoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  User? _usuario;
  DateTime? _nacimiento;
  Uint8List? _fotoNueva;
  String _fotoNombre = 'perfil.jpg';
  bool _editando = false;
  bool _cargando = true;
  String? _error;

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargar();
    });
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _documentoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final id = Session.idUsuario;
    if (id == null || id.isEmpty) {
      setState(() {
        _cargando = false;
        _error = 'No hay una sesión activa';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final usuario = await ApiService.obtenerUsuario(id);
      if (!mounted) return;
      _aplicar(usuario);
      setState(() => _cargando = false);
    } catch (e) {
      if (!mounted) return;
      final mensaje = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _cargando = false;
        _error = mensaje;
      });
      _aviso(mensaje);
    }
  }

  void _aplicar(User usuario) {
    _usuario = usuario;
    _fotoNueva = null;
    _llenar(usuario);
    Session.nombre = usuario.nombres;
    Session.apellidos = usuario.apellidos;
    Session.correo = usuario.correo;
    Session.telefono = usuario.telefono;
  }

  void _llenar(User usuario) {
    _nombresCtrl.text = usuario.nombres;
    _apellidosCtrl.text = usuario.apellidos;
    _correoCtrl.text = usuario.correo;
    _telefonoCtrl.text = usuario.telefono;
    _documentoCtrl.text = usuario.documentoIdentidad;
    _direccionCtrl.text = usuario.direccion;
    _nacimiento = usuario.fechaNacimiento;
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

  void _empezarEdicion() => setState(() => _editando = true);

  void _cancelar() {
    final usuario = _usuario;
    if (usuario != null) _llenar(usuario);
    setState(() {
      _editando = false;
      _fotoNueva = null;
    });
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _nacimiento ?? DateTime(ahora.year - 18, ahora.month, ahora.day),
      firstDate: DateTime(ahora.year - 100),
      lastDate: ahora,
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (elegida != null && mounted) setState(() => _nacimiento = elegida);
  }

  Future<void> _elegirFoto() async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) _aviso('La foto supera los 5 MB. Elige una más liviana.');
        return;
      }
      setState(() {
        _fotoNueva = bytes;
        _fotoNombre = archivo.name.isEmpty ? 'perfil.jpg' : archivo.name;
        _editando = true;
      });
    } catch (e) {
      if (mounted) _aviso('No se pudo abrir la foto: $e');
    }
  }

  Future<void> _guardar() async {
    final usuario = _usuario;
    if (usuario == null || !_formKey.currentState!.validate()) return;
    if (_nacimiento == null) {
      _aviso('La fecha de nacimiento es obligatoria');
      return;
    }

    setState(() => _cargando = true);
    try {
      var foto = usuario.fotoPerfil;
      final nueva = _fotoNueva;
      if (nueva != null) {
        foto = await ApiService.subirFotoPerfil(nueva, _fotoNombre);
      }

      final actualizado = await ApiService.actualizarUsuario(
        User(
          id: usuario.id,
          nombres: _nombresCtrl.text.trim(),
          apellidos: _apellidosCtrl.text.trim(),
          correo: _correoCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim(),
          documentoIdentidad: _documentoCtrl.text.trim(),
          fechaNacimiento: _nacimiento,
          fotoPerfil: foto,
        ),
      );
      if (!mounted) return;
      _aplicar(actualizado);
      setState(() {
        _cargando = false;
        _editando = false;
      });
      _aviso('Perfil actualizado', exito: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      _aviso(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _fecha(DateTime fecha) =>
      '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';

  @override
  Widget build(BuildContext context) {
    if (_cargando && _usuario == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final usuario = _usuario;
    if (usuario == null) {
      return _ErrorPerfil(
        mensaje: _error ?? 'No se pudo cargar el perfil',
        onReintentar: _cargar,
      );
    }

    final texto = Theme.of(context).textTheme;
    final fotoPendiente = usuario.fotoPendiente && _fotoNueva == null;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _EncabezadoPerfil(
            nombre: usuario.nombreCompleto,
            correo: usuario.correo,
            fotoNueva: _fotoNueva,
            fotoPerfil: usuario.fotoPerfil,
            pendiente: fotoPendiente,
            cargando: _cargando,
            onFoto: _elegirFoto,
          ),
          const SizedBox(height: 22),
          Text(
            'Tu información',
            style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (_editando) ...[
            _campo(
              controller: _nombresCtrl,
              etiqueta: 'Nombres',
              icono: const FeatureIcon.persona(color: AppColors.rosa),
              validator: _requerido,
              capitalizacion: TextCapitalization.words,
            ),
            _campo(
              controller: _apellidosCtrl,
              etiqueta: 'Apellidos',
              icono: const FeatureIcon.persona(color: AppColors.rosa),
              validator: _requerido,
              capitalizacion: TextCapitalization.words,
            ),
            _campo(
              controller: _correoCtrl,
              etiqueta: 'Correo electrónico',
              icono: const FeatureIcon.sobre(color: AppColors.rosa),
              teclado: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Correo inválido' : null,
            ),
            _campo(
              controller: _telefonoCtrl,
              etiqueta: 'Teléfono',
              icono: const FeatureIcon.telefono(color: AppColors.rosa),
              teclado: TextInputType.phone,
              validator: (v) {
                final digitos = v?.replaceAll(RegExp(r'\D'), '') ?? '';
                if (digitos.length < 10) return 'Mínimo 10 dígitos';
                return null;
              },
            ),
            _FechaCampo(
              fecha: _nacimiento,
              texto: _nacimiento == null ? 'Selecciona tu fecha' : _fecha(_nacimiento!),
              onTap: _cargando ? null : _elegirFecha,
            ),
            _campo(
              controller: _documentoCtrl,
              etiqueta: 'Documento de identidad (cédula)',
              icono: const FeatureIcon.documento(color: AppColors.rosa),
              teclado: TextInputType.number,
            ),
            _campo(
              controller: _direccionCtrl,
              etiqueta: 'Dirección',
              icono: const FeatureIcon.direccion(color: AppColors.rosa),
              capitalizacion: TextCapitalization.sentences,
            ),
          ] else ...[
            _Dato(
              icono: const FeatureIcon.documento(color: AppColors.rosa),
              etiqueta: 'Documento de identidad',
              valor: usuario.documentoPendiente ? _pendiente : usuario.documentoIdentidad,
              pendiente: usuario.documentoPendiente,
            ),            
            _Dato(
              icono: const FeatureIcon.sobre(color: AppColors.rosa),
              etiqueta: 'Correo electrónico',
              valor: usuario.correo,
            ),
            _Dato(
              icono: const FeatureIcon.calendario(color: AppColors.rosa),
              etiqueta: 'Fecha de nacimiento',
              valor: usuario.fechaNacimiento == null
                  ? ''
                  : _fecha(usuario.fechaNacimiento!),
            ),
            _Dato(
              icono: const FeatureIcon.telefono(color: AppColors.rosa),
              etiqueta: 'Teléfono',
              valor: usuario.telefono,
            ),
            _Dato(
              icono: const FeatureIcon.direccion(color: AppColors.rosa),
              etiqueta: 'Dirección',
              valor: usuario.direccionPendiente ? _pendiente : usuario.direccion,
              pendiente: usuario.direccionPendiente,
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _cargando ? null : (_editando ? _guardar : _empezarEdicion),
            icon: _cargando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.blanco,
                    ),
                  )
                : const FeatureIcon.editar(color: AppColors.blanco, tamano: 20),
            label: Text(_editando ? 'Guardar cambios' : 'Editar información'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          ),
          if (_editando) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _cargando ? null : _cancelar,
              child: const Text('Cancelar'),
            ),
          ],
        ],
      ),
    );
  }

  String? _requerido(String? valor) =>
      (valor == null || valor.trim().isEmpty) ? 'Requerido' : null;

  Widget _campo({
    required TextEditingController controller,
    required String etiqueta,
    required Widget icono,
    String? Function(String?)? validator,
    TextInputType? teclado,
    TextCapitalization capitalizacion = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: !_cargando,
        validator: validator,
        keyboardType: teclado,
        textCapitalization: capitalizacion,
        decoration: InputDecoration(labelText: etiqueta, prefixIcon: icono),
      ),
    );
  }
}

class _EncabezadoPerfil extends StatelessWidget {
  final String nombre;
  final String correo;
  final Uint8List? fotoNueva;
  final String? fotoPerfil;
  final bool pendiente;
  final bool cargando;
  final VoidCallback onFoto;

  const _EncabezadoPerfil({
    required this.nombre,
    required this.correo,
    required this.fotoNueva,
    required this.fotoPerfil,
    required this.pendiente,
    required this.cargando,
    required this.onFoto,
  });

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final nueva = fotoNueva;
    final ruta = fotoPerfil;
    Widget foto;
    if (nueva != null) {
      foto = Image.memory(nueva, fit: BoxFit.cover);
    } else if (ruta != null && ruta.trim().isNotEmpty) {
      foto = Image.network(
        urlFoto(ruta),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _FotoVacia(),
      );
    } else {
      foto = const _FotoVacia();
    }

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 54,
              backgroundColor: AppColors.rosaSuave,
              child: ClipOval(
                child: SizedBox(width: 108, height: 108, child: foto),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: IconButton.filled(
                tooltip: 'Cambiar foto',
                onPressed: cargando ? null : onFoto,
                icon: const FeatureIcon.editar(color: AppColors.blanco, tamano: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          nombre,
          textAlign: TextAlign.center,
          style: texto.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (pendiente) ...[
          const SizedBox(height: 6),
          Text(
            'Foto de perfil: $_pendiente',
            style: texto.bodySmall?.copyWith(
              color: _colorPendiente,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _FotoVacia extends StatelessWidget {
  const _FotoVacia();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.rosaSuave,
      child: Center(
        child: FeatureIcon.perfil(tamano: 48, color: AppColors.rosa),
      ),
    );
  }
}

class _FechaCampo extends StatelessWidget {
  final DateTime? fecha;
  final String texto;
  final VoidCallback? onTap;

  const _FechaCampo({required this.fecha, required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Fecha de nacimiento',
            prefixIcon: FeatureIcon.calendario(color: AppColors.rosa),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: fecha == null
                  ? AppColors.texto.withValues(alpha: 0.45)
                  : AppColors.texto,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final Widget icono;
  final String etiqueta;
  final String valor;
  final bool pendiente;

  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.pendiente = false,
  });

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Row(
        children: [
          icono,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: texto.bodySmall?.copyWith(
                    color: AppColors.texto.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  valor,
                  style: texto.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: pendiente ? _colorPendiente : AppColors.texto,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPerfil extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _ErrorPerfil({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FeatureIcon.sinConexion(tamano: 40),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center),
            TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
