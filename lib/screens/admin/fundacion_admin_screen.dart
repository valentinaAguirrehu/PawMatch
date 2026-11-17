import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/fundacion_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/fundacion_imagen.dart';

/// Pantalla del administrador para editar, modificar y eliminar la información
/// de la Fundación que se muestra en la página de bienvenida (WelcomeScreen).
class FundacionAdminScreen extends StatefulWidget {
  const FundacionAdminScreen({super.key});

  @override
  State<FundacionAdminScreen> createState() => _FundacionAdminScreenState();
}

class _FundacionAdminScreenState extends State<FundacionAdminScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _ciudadCtrl = TextEditingController(text: FundacionInfo.ciudad);
  late final _direccionCtrl = TextEditingController(text: FundacionInfo.direccion);
  late final _mapaUrlCtrl = TextEditingController(
    text: FundacionInfo.mapaUrlPersonalizado,
  );
  late final _descripcionCtrl = TextEditingController(text: FundacionInfo.historia);
  late final _misionCtrl = TextEditingController(text: FundacionInfo.mision);
  late final _visionCtrl = TextEditingController(text: FundacionInfo.vision);

  late final _telefonoCtrl = TextEditingController(text: FundacionInfo.whatsappNumero);
  late final _correoCtrl = TextEditingController(text: FundacionInfo.correo);

  late final _facebookCtrl = TextEditingController(
    text: FundacionInfo.redes['facebook'] ?? '',
  );
  late final _instagramCtrl = TextEditingController(
    text: FundacionInfo.redes['instagram'] ?? '',
  );
  late final _tiktokCtrl = TextEditingController(
    text: FundacionInfo.redes['tiktok'] ?? '',
  );

  late final _ayudaAdoptaTextoCtrl = TextEditingController(
    text: FundacionInfo.ayudaAdoptaTexto,
  );
  late final _ayudaApadrinaTextoCtrl = TextEditingController(
    text: FundacionInfo.ayudaApadrinaTexto,
  );
  late final _contactoTextoCtrl = TextEditingController(
    text: FundacionInfo.contactoTexto,
  );

  late final _rescatistaTextoCtrl = TextEditingController(
    text: FundacionInfo.rescatistaTexto,
  );

  // Imágenes (rutas existentes o nuevas subidas)
  late String _imagenPrincipal = FundacionInfo.imagenPrincipal;
  late String _fotoDenuncias = FundacionInfo.fotoDenuncias;
  late String _fotoRescatista = FundacionInfo.fotoRescatista;

  bool _cargando = true;
  bool _guardando = false;
  bool _intentoGuardar = false;
  final _clavesCampos = <String, GlobalKey>{};

  GlobalKey _claveDe(String etiqueta) =>
      _clavesCampos.putIfAbsent(etiqueta, GlobalKey.new);

  List<({String etiqueta, TextEditingController ctrl, bool obligatorio})> get _campos => [
        (etiqueta: 'Ciudad / Ubicación corta', ctrl: _ciudadCtrl, obligatorio: true),
        (etiqueta: 'Dirección completa', ctrl: _direccionCtrl, obligatorio: true),
        (etiqueta: 'URL personalizada de Google Maps', ctrl: _mapaUrlCtrl, obligatorio: false),
        (etiqueta: 'Descripción / Historia principal', ctrl: _descripcionCtrl, obligatorio: true),
        (etiqueta: 'Nuestra Misión', ctrl: _misionCtrl, obligatorio: true),
        (etiqueta: 'Nuestra Visión', ctrl: _visionCtrl, obligatorio: true),
        (etiqueta: 'Texto de tarjeta Adopta', ctrl: _ayudaAdoptaTextoCtrl, obligatorio: true),
        (etiqueta: 'Texto de tarjeta Apadrina', ctrl: _ayudaApadrinaTextoCtrl, obligatorio: true),
        (etiqueta: 'Mensaje de contacto / Donación', ctrl: _contactoTextoCtrl, obligatorio: true),
        (etiqueta: 'Teléfono / WhatsApp (solo dígitos con código de país)', ctrl: _telefonoCtrl, obligatorio: true),
        (etiqueta: 'Correo electrónico', ctrl: _correoCtrl, obligatorio: true),
        (etiqueta: 'Facebook URL', ctrl: _facebookCtrl, obligatorio: false),
        (etiqueta: 'Instagram URL', ctrl: _instagramCtrl, obligatorio: false),
        (etiqueta: 'TikTok URL', ctrl: _tiktokCtrl, obligatorio: false),
        (etiqueta: 'Texto / Trayectoria de la rescatista', ctrl: _rescatistaTextoCtrl, obligatorio: true),
      ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    await FundacionService.cargar();
    if (!mounted) return;
    _ciudadCtrl.text = FundacionInfo.ciudad;
    _direccionCtrl.text = FundacionInfo.direccion;
    _mapaUrlCtrl.text = FundacionInfo.mapaUrlPersonalizado;
    _descripcionCtrl.text = FundacionInfo.historia;
    _misionCtrl.text = FundacionInfo.mision;
    _visionCtrl.text = FundacionInfo.vision;
    _telefonoCtrl.text = FundacionInfo.whatsappNumero;
    _correoCtrl.text = FundacionInfo.correo;
    _facebookCtrl.text = FundacionInfo.redes['facebook'] ?? '';
    _instagramCtrl.text = FundacionInfo.redes['instagram'] ?? '';
    _tiktokCtrl.text = FundacionInfo.redes['tiktok'] ?? '';
    _ayudaAdoptaTextoCtrl.text = FundacionInfo.ayudaAdoptaTexto;
    _ayudaApadrinaTextoCtrl.text = FundacionInfo.ayudaApadrinaTexto;
    _contactoTextoCtrl.text = FundacionInfo.contactoTexto;
    _rescatistaTextoCtrl.text = FundacionInfo.rescatistaTexto;
    _imagenPrincipal = FundacionInfo.imagenPrincipal;
    _fotoDenuncias = FundacionInfo.fotoDenuncias;
    _fotoRescatista = FundacionInfo.fotoRescatista;
    setState(() => _cargando = false);
  }

  @override
  void dispose() {
    _ciudadCtrl.dispose();
    _direccionCtrl.dispose();
    _mapaUrlCtrl.dispose();
    _descripcionCtrl.dispose();
    _misionCtrl.dispose();
    _visionCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _facebookCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _ayudaAdoptaTextoCtrl.dispose();
    _ayudaApadrinaTextoCtrl.dispose();
    _contactoTextoCtrl.dispose();
    _rescatistaTextoCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (!confirmar || !mounted) return;
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    Session.cerrar();
    Navegacion.ir(context, const WelcomeScreen());
  }

  void _aviso(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.redAccent : AppColors.rosa,
      ),
    );
  }

  Future<String?> _seleccionarYSubirFoto(String titulo) async {
    ImageSource origen = ImageSource.gallery;
    final esCelular = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (esCelular) {
      final elegido = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Elegir de la galería'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Tomar una foto'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      if (elegido == null) return null;
      origen = elegido;
    }

    try {
      final x = await ImagePicker().pickImage(
        source: origen,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (x == null) return null;
      final bytes = await x.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _aviso('La imagen supera 5 MB. Elige una más liviana.', esError: true);
        return null;
      }
      _aviso('Subiendo imagen...');
      final ruta = await FundacionService.subirImagen(
        bytes,
        x.name.isEmpty ? 'fundacion.jpg' : x.name,
      );
      return ruta;
    } catch (e) {
      _aviso('Error al subir imagen: $e', esError: true);
      return null;
    }
  }

  Future<void> _guardar() async {
    setState(() => _intentoGuardar = true);
    if (!_formKey.currentState!.validate()) {
      final faltantes = _campos
          .where((campo) {
            final texto = campo.ctrl.text.trim();
            return (campo.obligatorio && texto.isEmpty) || texto.length > 300;
          })
          .map((campo) => campo.etiqueta)
          .toList();
      final contexto = faltantes.isEmpty
          ? null
          : _clavesCampos[faltantes.first]?.currentContext;
      if (contexto != null) {
        await Scrollable.ensureVisible(
          contexto,
          alignment: 0.05,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
      _aviso(
        faltantes.isEmpty
            ? 'Revisa los campos marcados en rojo'
            : faltantes.length == 1
                ? 'Completa el campo: ${faltantes.first}'
                : 'Completa estos campos: ${faltantes.join(', ')}',
        esError: true,
      );
      return;
    }
    setState(() => _guardando = true);

    final redes = <String, String>{};
    if (_facebookCtrl.text.trim().isNotEmpty) {
      redes['facebook'] = _facebookCtrl.text.trim();
    }
    if (_instagramCtrl.text.trim().isNotEmpty) {
      redes['instagram'] = _instagramCtrl.text.trim();
    }
    if (_tiktokCtrl.text.trim().isNotEmpty) {
      redes['tiktok'] = _tiktokCtrl.text.trim();
    }

    final datos = {
      'nombre': FundacionInfo.nombre,
      'ciudad': _ciudadCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim(),
      'mapa_url': _mapaUrlCtrl.text.trim(),
      'descripcion': _descripcionCtrl.text.trim(),
      'mision': _misionCtrl.text.trim(),
      'vision': _visionCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'correo': _correoCtrl.text.trim(),
      'logo': FundacionInfo.logo,
      'imagen_principal': _imagenPrincipal.trim(),
      'imagen_fondo': FundacionInfo.fotoFondoAyudas,
      'imagen_denuncias': _fotoDenuncias.trim(),
      'rescatista_nombre': FundacionInfo.rescatistaNombre,
      'rescatista_texto': _rescatistaTextoCtrl.text.trim(),
      'rescatista_foto': _fotoRescatista.trim(),
      'ayuda_adopta_titulo': FundacionInfo.ayudaAdoptaTitulo,
      'ayuda_adopta_texto': _ayudaAdoptaTextoCtrl.text.trim(),
      'ayuda_apadrina_titulo': FundacionInfo.ayudaApadrinaTitulo,
      'ayuda_apadrina_texto': _ayudaApadrinaTextoCtrl.text.trim(),
      'contacto_texto': _contactoTextoCtrl.text.trim(),
      'redes_sociales': redes,
    };

    try {
      await FundacionService.guardar(datos);
      _aviso('¡Información de la Fundación actualizada con éxito!');
    } catch (e) {
      _aviso(e.toString().replaceFirst('Exception: ', ''), esError: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  static const _rojo = Color(0xFFE11D48);

  InputDecoration _deco(String hint, {VoidCallback? onLimpiar}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.rosa, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: AppColors.rosaSuave,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: onLimpiar != null
            ? IconButton(
                tooltip: 'Eliminar / Vaciar',
                icon: const Icon(Icons.clear, size: 18, color: Colors.black45),
                onPressed: onLimpiar,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bordeRosa),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bordeRosa),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.rosa, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _rojo, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _rojo, width: 2),
        ),
        errorStyle: const TextStyle(color: _rojo, fontWeight: FontWeight.w600),
      );

  String? _validarTexto(String? valor, {bool obligatorio = true}) {
    final texto = valor?.trim() ?? '';
    if (obligatorio && texto.isEmpty) return 'Completa este campo';
    if (texto.length > 300) return 'Máximo 300 caracteres';
    return null;
  }

  Widget _texto({
    required String etiqueta,
    required TextEditingController controller,
    required String ejemplo,
    int lineas = 1,
    TextInputType teclado = TextInputType.text,
    bool obligatorio = true,
  }) {
    return KeyedSubtree(
      key: _claveDe(etiqueta),
      child: _campo(
      etiqueta,
      TextFormField(
        controller: controller,
        maxLength: 300,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        maxLines: lineas,
        keyboardType: teclado,
        decoration: _deco(
          ejemplo,
          onLimpiar: () => setState(() => controller.clear()),
        ),
        validator: (valor) => _validarTexto(valor, obligatorio: obligatorio),
      ),
    ),
    );
  }

  Widget _seccionTitulo(String titulo, IconData icono) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 12),
        child: Row(
          children: [
            Icon(icono, color: AppColors.rosa, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.texto,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _campo(String etiqueta, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                etiqueta,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            child,
          ],
        ),
      );

  Widget _tarjetaFoto({
    required String titulo,
    required String ruta,
    required VoidCallback onEliminar,
    required ValueChanged<String> onCambiada,
    double alto = 160,
    BoxFit fit = BoxFit.cover,
  }) {
    final tieneFoto = ruta.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.texto,
                  ),
                ),
              ),
              if (tieneFoto)
                TextButton.icon(
                  onPressed: onEliminar,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  label: const Text(
                    'Eliminar',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: alto,
              width: double.infinity,
              child: tieneFoto
                  ? FundacionImagen(ruta: ruta, fit: fit)
                  : const ColoredBox(
                      color: Colors.white,
                      child: Center(
                        child: Text(
                          'Sin imagen configurada',
                          style: TextStyle(color: Colors.black45, fontSize: 13),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              onPressed: () async {
                final nueva = await _seleccionarYSubirFoto(titulo);
                if (nueva != null) {
                  setState(() => onCambiada(nueva));
                }
              },
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(tieneFoto ? 'Cambiar imagen' : 'Subir imagen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rosa,
                side: const BorderSide(color: AppColors.rosa),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            BarraSuperior(
              iconoTitulo: Icons.edit_note_outlined,
              titulo: 'Información',
              onCerrarSesion: _confirmarCerrarSesion,
            ),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _formulario(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulario() {
    return Form(
      key: _formKey,
      autovalidateMode: _intentoGuardar
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // Banner informativo
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.rosaClaro,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.edit_note, color: AppColors.rosa, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Modifica o elimina la información que verán los usuarios en la pantalla de bienvenida.',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _seccionTitulo('Información general y Ubicación', Icons.business),
          _texto(
            etiqueta: 'Ciudad / Ubicación corta',
            controller: _ciudadCtrl,
            ejemplo: 'Ej: San Juan de Pasto, Nariño',
          ),
          _texto(
            etiqueta: 'Dirección completa',
            controller: _direccionCtrl,
            ejemplo: 'Ej: Pasto, Nariño',
          ),
          _texto(
            etiqueta: 'URL personalizada de Google Maps',
            controller: _mapaUrlCtrl,
            ejemplo: 'https://maps.google.com/?q=...',
            teclado: TextInputType.url,
            obligatorio: false,
          ),
          _texto(
            etiqueta: 'Descripción / Historia principal',
            controller: _descripcionCtrl,
            ejemplo: 'Historia de la fundación...',
            lineas: 4,
          ),

          _seccionTitulo('Misión y Visión', Icons.lightbulb_outline),
          _texto(
            etiqueta: 'Nuestra Misión',
            controller: _misionCtrl,
            ejemplo: 'Misión de la fundación...',
            lineas: 3,
          ),
          _texto(
            etiqueta: 'Nuestra Visión',
            controller: _visionCtrl,
            ejemplo: 'Visión de la fundación...',
            lineas: 3,
          ),

          _seccionTitulo('Sección "Encuéntranos y Ayúdanos"', Icons.volunteer_activism_outlined),
          _texto(
            etiqueta: 'Texto de tarjeta Adopta',
            controller: _ayudaAdoptaTextoCtrl,
            ejemplo: 'Encuentra un compañero...',
            lineas: 2,
          ),
          _texto(
            etiqueta: 'Texto de tarjeta Apadrina',
            controller: _ayudaApadrinaTextoCtrl,
            ejemplo: 'Contribuye a su cuidado...',
            lineas: 2,
          ),
          _texto(
            etiqueta: 'Mensaje de contacto / Donación',
            controller: _contactoTextoCtrl,
            ejemplo: 'Para coordinar una donación, contáctanos por WhatsApp.',
            lineas: 2,
          ),

          _seccionTitulo('Contacto y Redes Sociales', Icons.contact_phone_outlined),
          _texto(
            etiqueta: 'Teléfono / WhatsApp (solo dígitos con código de país)',
            controller: _telefonoCtrl,
            ejemplo: 'Ej: 573136177747',
            teclado: TextInputType.phone,
          ),
          _texto(
            etiqueta: 'Correo electrónico',
            controller: _correoCtrl,
            ejemplo: 'Ej: contacto@fundacion.org',
            teclado: TextInputType.emailAddress,
          ),
          _texto(
            etiqueta: 'Facebook URL',
            controller: _facebookCtrl,
            ejemplo: 'https://facebook.com/...',
            teclado: TextInputType.url,
            obligatorio: false,
          ),
          _texto(
            etiqueta: 'Instagram URL',
            controller: _instagramCtrl,
            ejemplo: 'https://instagram.com/...',
            teclado: TextInputType.url,
            obligatorio: false,
          ),
          _texto(
            etiqueta: 'TikTok URL',
            controller: _tiktokCtrl,
            ejemplo: 'https://tiktok.com/@...',
            teclado: TextInputType.url,
            obligatorio: false,
          ),

          _seccionTitulo('Sección "Nuestra rescatista"', Icons.person_pin_outlined),
          _texto(
            etiqueta: 'Texto / Trayectoria de la rescatista',
            controller: _rescatistaTextoCtrl,
            ejemplo: 'Labor de la rescatista...',
            lineas: 3,
          ),
          _tarjetaFoto(
            titulo: 'Foto de la rescatista',
            ruta: _fotoRescatista,
            alto: 180,
            onEliminar: () => setState(() => _fotoRescatista = ''),
            onCambiada: (ruta) => setState(() => _fotoRescatista = ruta),
          ),

          // 6. IMÁGENES DE LA BIENVENIDA
          _seccionTitulo('Imágenes de la bienvenida', Icons.image_outlined),
          _tarjetaFoto(
            titulo: 'Imagen principal (Círculo de inicio)',
            ruta: _imagenPrincipal,
            alto: 200,
            fit: BoxFit.contain,
            onEliminar: () => setState(() => _imagenPrincipal = ''),
            onCambiada: (ruta) => setState(() => _imagenPrincipal = ruta),
          ),
          _tarjetaFoto(
            titulo: 'Foto de Protección animal',
            ruta: _fotoDenuncias,
            alto: 200,
            onEliminar: () => setState(
              () => _fotoDenuncias = FundacionInfo.fotoDenunciasPredeterminada,
            ),
            onCambiada: (ruta) => setState(() => _fotoDenuncias = ruta),
          ),

          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rosa,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(
              _guardando ? 'Guardando cambios...' : 'Guardar información',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
