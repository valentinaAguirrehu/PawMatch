import 'package:flutter/foundation.dart';

/// Datos de la Fundación mostrados en la página de inicio.
///
/// Se cargan desde la tabla `informacionfundacion` (ver [FundacionService]) y el
/// administrador los edita en Gestionar → Información de la fundación.
/// Los valores de abajo solo se usan mientras carga o si el servidor no responde.
class FundacionInfo {
  FundacionInfo._();

  /// Aumenta cada vez que llegan datos nuevos; las pantallas lo escuchan
  /// para redibujarse.
  static final cambios = ValueNotifier<int>(0);

  static String nombre = 'Fundación Maritza Arévalo';
  static String ciudad = 'San Juan de Pasto, Nariño';
  static const resumen =
      'Rescatamos perros en condiciones de vulnerabilidad en San Juan de Pasto';

  /// Columna `descripcion`.
  static String historia =
      'La Fundación Maritza Arévalo ha asumido un papel importante frente al abandono y '
      'maltrato de perros en San Juan de Pasto. Rescata perros en condiciones de '
      'vulnerabilidad, les brinda atención, recuperación y un espacio seguro mientras '
      'se gestiona su proceso de adopción o apadrinamiento.';

  static String mision =
      'Rescatar perros en condiciones de vulnerabilidad, brindarles atención, '
      'recuperación y un espacio seguro mientras encuentran un hogar responsable '
      'a través de la adopción o el apadrinamiento.';

  static String vision =
      'Aquí va la visión oficial de la Fundación (texto pendiente).';

  // ───────── Nuestra rescatista ─────────
  static String rescatistaNombre = 'Maritza Arévalo';
  static String rescatistaTexto =
      'Maritza Arévalo acompaña la labor de la Fundación en San Juan de Pasto: '
      'rescatar perros en condiciones de vulnerabilidad, brindarles atención y '
      'ayudarlos a encontrar un hogar responsable.';

  // ───────── Imágenes (ruta de assets o /uploads/fundacion/...) ─────────
  static String logo = 'assets/images/logo.png';
  static String imagenPrincipal = 'assets/fundacion/Maritzanimada.jpg';
  static String fotoRescatista = 'assets/fundacion/maitza.jpeg';
  static String fotoFondoAyudas = '';

  // ───────── Contacto y Ubicación ─────────
  /// Columna `telefono`: país + número, solo dígitos. Ejemplo Colombia: 573001234567
  static String whatsappNumero = '573136177747';
  static const whatsappMensaje =
      'Hola, vengo de la app Paw Match y quiero más información sobre la fundación';
  static String correo = '';
  static String direccion = 'Pasto, Nariño';

  /// URL personalizada de Google Maps (si se especifica en BD, se usa directamente)
  static String mapaUrlPersonalizado = '';

  // ───────── Sección Encuéntranos y Ayúdanos ─────────
  static String ayudaAdoptaTitulo = 'Adopta';
  static String ayudaAdoptaTexto =
      'Encuentra un compañero que encaje contigo y dale un hogar lleno de cariño.';
  static String ayudaApadrinaTitulo = 'Apadrina';
  static String ayudaApadrinaTexto =
      'Contribuye a su cuidado mientras esperan encontrar una familia permanente.';
  static String contactoTexto =
      'Para coordinar una donación, contáctanos por WhatsApp.';

  /// Columna `redes_sociales` (JSON): facebook, instagram, tiktok.
  static Map<String, String> redes = {
    'facebook': 'https://www.facebook.com/maritzaarevalogatos',
    'instagram': 'https://www.instagram.com/fundacion_maritza_arevalo/',
  };

  static String get facebookUrl => redes['facebook'] ?? '';
  static String get instagramUrl => redes['instagram'] ?? '';

  // ───────── Imágenes de la galería ─────────
  /// Carpeta de assets donde están las fotos de la Fundación.
  static const carpetaImagenes = 'assets/fundacion/';

  /// Archivos cuyo nombre contenga alguna de estas palabras NO se muestran en la galería.
  static const excluirEnImagenes = ['logo', 'icon', 'icono'];

  // ───────── Enlaces derivados ─────────
  static bool get _whatsappValido =>
      RegExp(r'^\d{10,15}$').hasMatch(whatsappNumero);

  static String get whatsappUrl => _whatsappValido
      ? 'https://wa.me/$whatsappNumero?text=${Uri.encodeComponent(whatsappMensaje)}'
      : '';

  static String get correoUrl => correo.isEmpty ? '' : 'mailto:$correo';

  static String get mapaUrl {
    final personalizada = mapaUrlPersonalizado.trim();
    if (personalizada.isNotEmpty) return personalizada;
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$nombre $direccion $ciudad')}';
  }

  /// Copia en memoria la fila recibida de GET /api/fundacion.
  /// Un campo vacío (NULL) significa que el administrador lo eliminó.
  static void aplicar(Map<String, dynamic> data) {
    String t(String clave) => (data[clave] ?? '').toString().trim();

    nombre = t('nombre').isEmpty ? nombre : t('nombre');
    historia = t('descripcion');
    mision = t('mision');
    vision = t('vision');
    direccion = t('direccion');
    ciudad = t('ciudad');
    whatsappNumero = t('telefono');
    correo = t('correo');
    logo = t('logo');
    imagenPrincipal = t('imagen_principal');
    final fondo = t('imagen_fondo');
    fotoFondoAyudas = fondo == 'assets/fundacion/bebe.jpg' ? '' : fondo;
    rescatistaNombre = t('rescatista_nombre');
    rescatistaTexto = t('rescatista_texto');
    fotoRescatista = t('rescatista_foto');
    mapaUrlPersonalizado = t('mapa_url');

    final adoptaTit = t('ayuda_adopta_titulo');
    ayudaAdoptaTitulo = adoptaTit.isEmpty ? 'Adopta' : adoptaTit;
    ayudaAdoptaTexto = t('ayuda_adopta_texto');

    final apadrinaTit = t('ayuda_apadrina_titulo');
    ayudaApadrinaTitulo = apadrinaTit.isEmpty ? 'Apadrina' : apadrinaTit;
    ayudaApadrinaTexto = t('ayuda_apadrina_texto');

    final conTxt = t('contacto_texto');
    contactoTexto = conTxt.isEmpty
        ? 'Para coordinar una donación, contáctanos por WhatsApp.'
        : conTxt;

    final crudo = data['redes_sociales'];
    final nuevas = <String, String>{};
    if (crudo is Map) {
      crudo.forEach((k, v) {
        final red = k.toString().toLowerCase();
        if (red == 'youtube') return; // Se excluye youtube
        final url = (v ?? '').toString().trim();
        if (url.isNotEmpty) nuevas[red] = url;
      });
    }
    redes = nuevas;

    cambios.value++;
  }

  /// Datos actuales en el mismo formato que espera PUT /api/fundacion.
  static Map<String, dynamic> aJson() => {
    'nombre': nombre,
    'descripcion': historia,
    'mision': mision,
    'vision': vision,
    'direccion': direccion,
    'ciudad': ciudad,
    'telefono': whatsappNumero,
    'correo': correo,
    'logo': logo,
    'imagen_principal': imagenPrincipal,
    'imagen_fondo': fotoFondoAyudas,
    'rescatista_nombre': rescatistaNombre,
    'rescatista_texto': rescatistaTexto,
    'rescatista_foto': fotoRescatista,
    'mapa_url': mapaUrlPersonalizado,
    'ayuda_adopta_titulo': ayudaAdoptaTitulo,
    'ayuda_adopta_texto': ayudaAdoptaTexto,
    'ayuda_apadrina_titulo': ayudaApadrinaTitulo,
    'ayuda_apadrina_texto': ayudaApadrinaTexto,
    'contacto_texto': contactoTexto,
    'redes_sociales': Map<String, String>.from(redes),
  };
}
