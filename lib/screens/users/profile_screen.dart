import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/user.dart';
import 'package:paw_match/screens/adoption/my_adoptions_screen.dart';
import 'package:paw_match/screens/apadrinamiento/mis_apadrinamientos_screen.dart';
import 'package:paw_match/screens/users/personality_detail.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/services/seguimiento_apadrinamiento_service.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/pet_card.dart';
import 'package:paw_match/widgets/star_rating_selector.dart';

const _pendiente = 'Sin completar';
const _colorPendiente = Color(0xFFC62828);

class ProfileScreen extends StatefulWidget {
  /// Abre el formulario de edición en cuanto carga el perfil.
  final bool iniciarEnEdicion;

  /// Si se indica, la pantalla muestra su propia barra ("Mi Perfil" + salir).
  final VoidCallback? onCerrarSesion;

  const ProfileScreen({
    super.key,
    this.iniciarEnEdicion = false,
    this.onCerrarSesion,
  });

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
  final _claveKey = GlobalKey<FormState>();
  final _claveCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  User? _usuario;
  DateTime? _nacimiento;
  Uint8List? _fotoNueva;
  String _fotoNombre = 'perfil.jpg';
  bool _editando = false;
  bool _cambiandoClave = false;
  bool _ocultarClave = true;
  bool _ocultarConfirmar = true;
  bool _guardandoClave = false;
  bool _guardandoFoto = false;
  bool _cargando = true;
  String? _error;
  double? _calificacionPadrino;
  int _totalSeguimientosPadrino = 0;

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  void initState() {
    super.initState();
    _editando = widget.iniciarEnEdicion;
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
    _claveCtrl.dispose();
    _confirmarCtrl.dispose();
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

      // Cargar calificación promedio como padrino
      SeguimientoApadrinamientoService.obtenerResumenPadrino(usuario.id).then((resumen) {
        if (mounted && resumen != null) {
          setState(() {
            _calificacionPadrino = resumen.calificacionPromedio;
            _totalSeguimientosPadrino = resumen.totalSeguimientos;
          });
        }
      }).catchError((_) {});

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
    Session.documentoIdentidad = usuario.documentoIdentidad;
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
    final usuario = _usuario;
    if (usuario == null || _guardandoFoto) return;
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
      final nombre = archivo.name.isEmpty ? 'perfil.jpg' : archivo.name;
      setState(() {
        _fotoNueva = bytes;
        _fotoNombre = nombre;
        _guardandoFoto = true;
      });

      final ruta = await ApiService.subirFotoPerfil(bytes, nombre);
      final actualizado = await ApiService.actualizarUsuario(
        User(
          id: usuario.id,
          nombres: usuario.nombres,
          apellidos: usuario.apellidos,
          correo: usuario.correo,
          telefono: usuario.telefono,
          direccion: usuario.direccion,
          documentoIdentidad: usuario.documentoIdentidad,
          fechaNacimiento: usuario.fechaNacimiento,
          fotoPerfil: ruta,
        ),
      );
      if (!mounted) return;
      setState(() {
        _usuario = actualizado;
        _fotoNueva = null;
        _guardandoFoto = false;
      });
      _aviso('Foto de perfil actualizada', exito: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardandoFoto = false);
      _aviso(e.toString().replaceFirst('Exception: ', ''));
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

  void _abrirCambioClave() => setState(() => _cambiandoClave = true);

  void _cerrarCambioClave() {
    _claveCtrl.clear();
    _confirmarCtrl.clear();
    setState(() {
      _cambiandoClave = false;
      _ocultarClave = true;
      _ocultarConfirmar = true;
    });
  }

  Future<void> _guardarClave() async {
    final usuario = _usuario;
    if (usuario == null || !_claveKey.currentState!.validate()) return;

    setState(() => _guardandoClave = true);
    try {
      await ApiService.cambiarContrasena(
        id: usuario.id,
        contrasena: _claveCtrl.text,
      );
      if (!mounted) return;
      _cerrarCambioClave();
      setState(() => _guardandoClave = false);
      _aviso('Contraseña actualizada', exito: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardandoClave = false);
      _aviso(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _fecha(DateTime fecha) =>
      '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';

  @override
  Widget build(BuildContext context) {
    final cerrarSesion = widget.onCerrarSesion;
    final barra = cerrarSesion == null
        ? null
        : BarraSuperior(
            iconoTitulo: Icons.person_rounded,
            titulo: 'Mi Perfil',
            onCerrarSesion: cerrarSesion,
          );

    Widget contenido;
    if (_cargando && _usuario == null) {
      contenido = const Center(child: CircularProgressIndicator());
    } else {
      final usuario = _usuario;
      contenido = usuario == null
          ? _ErrorPerfil(
              mensaje: _error ?? 'No se pudo cargar el perfil',
              onReintentar: _cargar,
            )
          : _cuerpo(usuario);
    }

    if (barra == null) return contenido;

    return Column(
      children: [
        SafeArea(bottom: false, child: barra),
        Expanded(child: contenido),
      ],
    );
  }

  Widget _cuerpo(User usuario) {

    final texto = Theme.of(context).textTheme;
    final fotoPendiente = usuario.fotoPendiente && _fotoNueva == null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          _EncabezadoPerfil(
            nombre: usuario.nombreCompleto,
            correo: usuario.correo,
            fotoNueva: _fotoNueva,
            fotoPerfil: usuario.fotoPerfil,
            pendiente: fotoPendiente,
            cargando: _cargando || _guardandoFoto,
            calificacionPadrino: _calificacionPadrino,
            totalSeguimientosPadrino: _totalSeguimientosPadrino,
            onFoto: _elegirFoto,
          ),
          if (!Session.isAdmin && !_editando) ...[
            const SizedBox(height: 18),
            Text(
              'Mis Solicitudes',
              style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _TarjetaSolicitud(
                      icono: Icons.pets,
                      titulo: 'Mis Adopciones',
                      subtitulo: 'Estado y contrato',
                      onTap: () {
                        AdoptionService.marcarLeidasUsuario();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyAdoptionsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TarjetaSolicitud(
                      icono: Icons.volunteer_activism,
                      titulo: 'Mis Apadrinamientos',
                      subtitulo: 'Estado y contratos',
                      onTap: () {
                        ApadrinamientoService.marcarLeidasUsuario();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MisApadrinamientosScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              etiqueta: 'Dirección Completa y detallada',
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
        ),
        if (!Session.isAdmin) ...[
          const SizedBox(height: 28),
          Text(
            'Personalidad',
            style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PersonalityDetailScreen()),
            ),
            icon: const FeatureIcon.compatibilidad(color: AppColors.rosa),
            label: const Text('Mi personalidad'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          ),
        ],
        const SizedBox(height: 28),
      Text(
        'Contraseña',
        style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      if (!_cambiandoClave)
        OutlinedButton.icon(
          onPressed: _guardandoClave ? null : _abrirCambioClave,
          icon: const FeatureIcon.cerradura(color: AppColors.rosa),
          label: const Text('Modificar contraseña'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        )
      else
        Form(
          key: _claveKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _clave(
                controller: _claveCtrl,
                etiqueta: 'Nueva contraseña',
                oculta: _ocultarClave,
                onVer: () => setState(() => _ocultarClave = !_ocultarClave),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              _clave(
                controller: _confirmarCtrl,
                etiqueta: 'Confirmar contraseña',
                oculta: _ocultarConfirmar,
                onVer: () => setState(() => _ocultarConfirmar = !_ocultarConfirmar),
                validator: (v) =>
                    v != _claveCtrl.text ? 'Las contraseñas no coinciden' : null,
              ),
              FilledButton(
                onPressed: _guardandoClave ? null : _guardarClave,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                child: _guardandoClave
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.blanco,
                        ),
                      )
                    : const Text('Actualizar contraseña'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _guardandoClave ? null : _cerrarCambioClave,
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
    ],
    );
  }

  Widget _clave({
    required TextEditingController controller,
    required String etiqueta,
    required bool oculta,
    required VoidCallback onVer,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: !_guardandoClave,
        obscureText: oculta,
        validator: validator,
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: const FeatureIcon.cerradura(color: AppColors.rosa),
          suffixIcon: IconButton(
            tooltip: oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
            onPressed: onVer,
            icon: oculta
                ? const FeatureIcon.ocultarContrasena(color: AppColors.rosa)
                : const FeatureIcon.mostrarContrasena(color: AppColors.rosa),
          ),
        ),
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

class _TarjetaSolicitud extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _TarjetaSolicitud({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.rosaSuave,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bordeRosa),
          boxShadow: [
            BoxShadow(
              color: AppColors.rosa.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.rosaClaro,
              radius: 20,
              child: Icon(icono, color: AppColors.rosa, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
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
  final double? calificacionPadrino;
  final int totalSeguimientosPadrino;
  final VoidCallback onFoto;

  const _EncabezadoPerfil({
    required this.nombre,
    required this.correo,
    required this.fotoNueva,
    required this.fotoPerfil,
    required this.pendiente,
    required this.cargando,
    this.calificacionPadrino,
    this.totalSeguimientosPadrino = 0,
    required this.onFoto,
  });

  Widget _construirFoto() {
    final nueva = fotoNueva;
    final ruta = fotoPerfil;
    if (nueva != null) {
      return Image.memory(nueva, fit: BoxFit.cover);
    }
    if (ruta != null && ruta.trim().isNotEmpty) {
      return Image.network(
        urlFoto(ruta),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _FotoVacia(),
      );
    }
    return const _FotoVacia();
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Column(
      children: [
        GestureDetector(
          onTap: () => _abrirFoto(context),
          child: Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.rosaSuave,
              boxShadow: [
                BoxShadow(
                  color: AppColors.rosa.withValues(alpha: 0.55),
                  blurRadius: 22,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _construirFoto(),
                  if (cargando)
                    const ColoredBox(
                      color: Color(0x66FFFFFF),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: AppColors.rosa,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              nombre,
              textAlign: TextAlign.center,
              style: texto.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (calificacionPadrino != null && calificacionPadrino! > 0)
              StarRatingBadge(
                rating: calificacionPadrino!,
                totalSeguimientos: totalSeguimientosPadrino,
                compacto: true,
              ),
          ],
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

  void _abrirFoto(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.rosa.withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 280,
                    height: 280,
                    child: _construirFoto(),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: cargando
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        onFoto();
                      },
                icon: const FeatureIcon.editar(color: AppColors.blanco, tamano: 18),
                label: const Text('Editar foto'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosa,
                  foregroundColor: AppColors.blanco,
                  minimumSize: const Size(180, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
