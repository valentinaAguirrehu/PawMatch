import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/services/fundacion_service.dart';
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

  late final _nombreCtrl = TextEditingController(text: FundacionInfo.nombre);
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

  late final _ayudaAdoptaTituloCtrl = TextEditingController(
    text: FundacionInfo.ayudaAdoptaTitulo,
  );
  late final _ayudaAdoptaTextoCtrl = TextEditingController(
    text: FundacionInfo.ayudaAdoptaTexto,
  );
  late final _ayudaApadrinaTituloCtrl = TextEditingController(
    text: FundacionInfo.ayudaApadrinaTitulo,
  );
  late final _ayudaApadrinaTextoCtrl = TextEditingController(
    text: FundacionInfo.ayudaApadrinaTexto,
  );
  late final _contactoTextoCtrl = TextEditingController(
    text: FundacionInfo.contactoTexto,
  );

  late final _rescatistaNombreCtrl = TextEditingController(
    text: FundacionInfo.rescatistaNombre,
  );
  late final _rescatistaTextoCtrl = TextEditingController(
    text: FundacionInfo.rescatistaTexto,
  );

  // Imágenes (rutas existentes o nuevas subidas)
  late String _logo = FundacionInfo.logo;
  late String _imagenPrincipal = FundacionInfo.imagenPrincipal;
  late String _fotoFondo = FundacionInfo.fotoFondoAyudas;
  late String _fotoRescatista = FundacionInfo.fotoRescatista;

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    await FundacionService.cargar();
    if (!mounted) return;
    _nombreCtrl.text = FundacionInfo.nombre;
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
    _ayudaAdoptaTituloCtrl.text = FundacionInfo.ayudaAdoptaTitulo;
    _ayudaAdoptaTextoCtrl.text = FundacionInfo.ayudaAdoptaTexto;
    _ayudaApadrinaTituloCtrl.text = FundacionInfo.ayudaApadrinaTitulo;
    _ayudaApadrinaTextoCtrl.text = FundacionInfo.ayudaApadrinaTexto;
    _contactoTextoCtrl.text = FundacionInfo.contactoTexto;
    _rescatistaNombreCtrl.text = FundacionInfo.rescatistaNombre;
    _rescatistaTextoCtrl.text = FundacionInfo.rescatistaTexto;
    _logo = FundacionInfo.logo;
    _imagenPrincipal = FundacionInfo.imagenPrincipal;
    _fotoFondo = FundacionInfo.fotoFondoAyudas;
    _fotoRescatista = FundacionInfo.fotoRescatista;
    setState(() => _cargando = false);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
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
    _ayudaAdoptaTituloCtrl.dispose();
    _ayudaAdoptaTextoCtrl.dispose();
    _ayudaApadrinaTituloCtrl.dispose();
    _ayudaApadrinaTextoCtrl.dispose();
    _contactoTextoCtrl.dispose();
    _rescatistaNombreCtrl.dispose();
    _rescatistaTextoCtrl.dispose();
    super.dispose();
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
    if (!_formKey.currentState!.validate()) return;
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
      'nombre': _nombreCtrl.text.trim(),
      'ciudad': _ciudadCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim(),
      'mapa_url': _mapaUrlCtrl.text.trim(),
      'descripcion': _descripcionCtrl.text.trim(),
      'mision': _misionCtrl.text.trim(),
      'vision': _visionCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'correo': _correoCtrl.text.trim(),
      'logo': _logo.trim(),
      'imagen_principal': _imagenPrincipal.trim(),
      'imagen_fondo': _fotoFondo.trim(),
      'rescatista_nombre': _rescatistaNombreCtrl.text.trim(),
      'rescatista_texto': _rescatistaTextoCtrl.text.trim(),
      'rescatista_foto': _fotoRescatista.trim(),
      'ayuda_adopta_titulo': _ayudaAdoptaTituloCtrl.text.trim(),
      'ayuda_adopta_texto': _ayudaAdoptaTextoCtrl.text.trim(),
      'ayuda_apadrina_titulo': _ayudaApadrinaTituloCtrl.text.trim(),
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

  InputDecoration _deco(String hint, {VoidCallback? onLimpiar}) => InputDecoration(
        hintText: hint,
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
      );

  Widget _seccionTitulo(String titulo, IconData icono) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 12),
        child: Row(
          children: [
            Icon(icono, color: AppColors.rosa, size: 22),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.texto,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.texto,
                ),
              ),
              if (tieneFoto)
                TextButton.icon(
                  onPressed: onEliminar,
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
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
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

          // 1. INFORMACIÓN GENERAL Y UBICACIÓN
          _seccionTitulo('Información general y Ubicación', Icons.business),
          _campo(
            'Nombre de la Fundación *',
            TextFormField(
              controller: _nombreCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco('Ej: Fundación Maritza Arévalo'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'El nombre es obligatorio'
                  : null,
            ),
          ),
          _campo(
            'Ciudad / Ubicación corta',
            TextFormField(
              controller: _ciudadCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco(
                'Ej: San Juan de Pasto, Nariño',
                onLimpiar: () => setState(() => _ciudadCtrl.clear()),
              ),
            ),
          ),
          _campo(
            'Dirección completa',
            TextFormField(
              controller: _direccionCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco(
                'Ej: Pasto, Nariño',
                onLimpiar: () => setState(() => _direccionCtrl.clear()),
              ),
            ),
          ),
          _campo(
            'URL personalizada de Google Maps (deja vacío para buscar por dirección)',
            TextFormField(
              controller: _mapaUrlCtrl,
              decoration: _deco(
                'https://maps.google.com/?q=...',
                onLimpiar: () => setState(() => _mapaUrlCtrl.clear()),
              ),
            ),
          ),
          _campo(
            'Descripción / Historia principal',
            TextFormField(
              controller: _descripcionCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco(
                'Historia de la fundación...',
                onLimpiar: () => setState(() => _descripcionCtrl.clear()),
              ),
              maxLines: 4,
              validator: (v) => (v != null && v.length > 500)
                  ? 'Máximo 500 caracteres'
                  : null,
            ),
          ),

          // 2. MISIÓN Y VISIÓN
          _seccionTitulo('Misión y Visión', Icons.lightbulb_outline),
          _campo(
            'Nuestra Misión',
            TextFormField(
              controller: _misionCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco(
                'Misión de la fundación...',
                onLimpiar: () => setState(() => _misionCtrl.clear()),
              ),
              maxLines: 3,
              validator: (v) => (v != null && v.length > 500)
                  ? 'Máximo 500 caracteres'
                  : null,
            ),
          ),
          _campo(
            'Nuestra Visión',
            TextFormField(
              controller: _visionCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco(
                'Visión de la fundación...',
                onLimpiar: () => setState(() => _visionCtrl.clear()),
              ),
              maxLines: 3,
              validator: (v) => (v != null && v.length > 500)
                  ? 'Máximo 500 caracteres'
                  : null,
            ),
          ),

          // 3. SECCIÓN ENCUÉNTRANOS Y AYÚDANOS
          _seccionTitulo('Sección "Encuéntranos y Ayúdanos"', Icons.volunteer_activism_outlined),
          _campo(
            'Título de tarjeta Adopta',
            TextFormField(
              controller: _ayudaAdoptaTituloCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco(
                'Ej: Adopta',
                onLimpiar: () => setState(() => _ayudaAdoptaTituloCtrl.clear()),
              ),
            ),
          ),
          _campo(
            'Texto de tarjeta Adopta',
            TextFormField(
              controller: _ayudaAdoptaTextoCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco(
                'Encuentra un compañero...',
                onLimpiar: () => setState(() => _ayudaAdoptaTextoCtrl.clear()),
              ),
              maxLines: 2,
              validator: (v) => (v != null && v.length > 500)
                  ? 'Máximo 500 caracteres'
                  : null,
            ),
          ),
          _campo(
            'Título de tarjeta Apadrina',
            TextFormField(
              controller: _ayudaApadrinaTituloCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco(
                'Ej: Apadrina',
                onLimpiar: () => setState(() => _ayudaApadrinaTituloCtrl.clear()),
              ),
            ),
          ),
          _campo(
            'Texto de tarjeta Apadrina',
            TextFormField(
              controller: _ayudaApadrinaTextoCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco(
                'Contribuye a su cuidado...',
                onLimpiar: () => setState(() => _ayudaApadrinaTextoCtrl.clear()),
              ),
              maxLines: 2,
              validator: (v) => (v != null && v.length > 500)
                  ? 'Máximo 500 caracteres'
                  : null,
            ),
          ),
          _campo(
            'Mensaje de contacto / Donación',
            TextFormField(
              controller: _contactoTextoCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco(
                'Para coordinar una donación, contáctanos por WhatsApp.',
                onLimpiar: () => setState(() => _contactoTextoCtrl.clear()),
              ),
              maxLines: 2,
              validator: (v) => (v != null && v.length > 500)
                  ? 'Máximo 500 caracteres'
                  : null,
            ),
          ),

          // 4. CONTACTO Y REDES
          _seccionTitulo('Contacto y Redes Sociales', Icons.contact_phone_outlined),
          _campo(
            'Teléfono / WhatsApp (solo dígitos con código de país)',
            TextFormField(
              controller: _telefonoCtrl,
              decoration: _deco(
                'Ej: 573136177747',
                onLimpiar: () => setState(() => _telefonoCtrl.clear()),
              ),
              keyboardType: TextInputType.phone,
            ),
          ),
          _campo(
            'Correo electrónico',
            TextFormField(
              controller: _correoCtrl,
              decoration: _deco(
                'Ej: contacto@fundacion.org',
                onLimpiar: () => setState(() => _correoCtrl.clear()),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          _campo(
            'Facebook URL',
            TextFormField(
              controller: _facebookCtrl,
              decoration: _deco(
                'https://facebook.com/...',
                onLimpiar: () => setState(() => _facebookCtrl.clear()),
              ),
            ),
          ),
          _campo(
            'Instagram URL',
            TextFormField(
              controller: _instagramCtrl,
              decoration: _deco(
                'https://instagram.com/...',
                onLimpiar: () => setState(() => _instagramCtrl.clear()),
              ),
            ),
          ),
          _campo(
            'TikTok URL',
            TextFormField(
              controller: _tiktokCtrl,
              decoration: _deco(
                'https://tiktok.com/@...',
                onLimpiar: () => setState(() => _tiktokCtrl.clear()),
              ),
            ),
          ),

          // 5. NUESTRA RESCATISTA
          _seccionTitulo('Sección "Nuestra rescatista"', Icons.person_pin_outlined),
          _campo(
            'Nombre de la rescatista',
            TextFormField(
              controller: _rescatistaNombreCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco(
                'Ej: Maritza Arévalo',
                onLimpiar: () => setState(() => _rescatistaNombreCtrl.clear()),
              ),
            ),
          ),
          _campo(
            'Texto / Trayectoria de la rescatista',
            TextFormField(
              controller: _rescatistaTextoCtrl,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: _deco(
                'Labor de la rescatista...',
                onLimpiar: () => setState(() => _rescatistaTextoCtrl.clear()),
              ),
              maxLines: 3,
              validator: (v) => (v != null && v.length > 500)
                  ? 'Máximo 500 caracteres'
                  : null,
            ),
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
            titulo: 'Logo de la Fundación',
            ruta: _logo,
            alto: 120,
            fit: BoxFit.contain,
            onEliminar: () => setState(() => _logo = ''),
            onCambiada: (ruta) => setState(() => _logo = ruta),
          ),
          _tarjetaFoto(
            titulo: 'Imagen principal (Círculo de inicio)',
            ruta: _imagenPrincipal,
            alto: 200,
            fit: BoxFit.contain,
            onEliminar: () => setState(() => _imagenPrincipal = ''),
            onCambiada: (ruta) => setState(() => _imagenPrincipal = ruta),
          ),
          _tarjetaFoto(
            titulo: 'Imagen de fondo de logros',
            ruta: _fotoFondo,
            alto: 160,
            onEliminar: () => setState(() => _fotoFondo = ''),
            onCambiada: (ruta) => setState(() => _fotoFondo = ruta),
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
