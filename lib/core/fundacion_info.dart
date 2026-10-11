/// Datos de la Fundación mostrados en la página de inicio.
/// Todo lo marcado con TODO debes completarlo con los datos oficiales.
class FundacionInfo {
  FundacionInfo._();

  static const nombre = 'Fundación Maritza Arévalo';
  static const ciudad = 'San Juan de Pasto, Nariño';
  static const resumen =
      'Rescatamos perros en condiciones de vulnerabilidad en San Juan de Pasto';

  // TODO: agrega aquí la historia real (año de fundación, quién la inició, hitos...).
  static const historia =
      'La Fundación Maritza Arévalo ha asumido un papel importante frente al abandono y '
      'maltrato de perros en San Juan de Pasto. Rescata perros en condiciones de '
      'vulnerabilidad, les brinda atención, recuperación y un espacio seguro mientras '
      'se gestiona su proceso de adopción o apadrinamiento.';

  static const mision =
      'Rescatar perros en condiciones de vulnerabilidad, brindarles atención, '
      'recuperación y un espacio seguro mientras encuentran un hogar responsable '
      'a través de la adopción o el apadrinamiento.';

  // TODO: reemplazar por la visión oficial.
  static const vision =
      'Aquí va la visión oficial de la Fundación (texto pendiente).';

  // ───────── Nuestra rescatista ─────────
  static const rescatistaNombre = 'Maritza Arévalo';
  static const rescatistaTexto =
      'Maritza Arévalo acompaña la labor de la Fundación en San Juan de Pasto: '
      'rescatar perros en condiciones de vulnerabilidad, brindarles atención y '
      'ayudarlos a encontrar un hogar responsable.';
  static const fotoRescatista = 'assets/fundacion/maitza.jpeg';
  static const fotoFondoAyudas = 'assets/fundacion/bebe.jpg';

  // ───────── Contacto (TODO: completar) ─────────
  /// País + número, solo dígitos. Ejemplo Colombia: 573001234567
  static const whatsappNumero = '573136177747';
  static const whatsappMensaje =
      'Hola, vengo de la app Paw Match y quiero más información sobre la fundación';
  static const facebookUrl = 'https://www.facebook.com/maritzaarevalogatos';
  static const instagramUrl =
      'https://www.instagram.com/fundacion_maritza_arevalo/';
  static const direccion =
      'Pasto, Nariño'; // TODO: dirección exacta del refugio

  // ───────── Imágenes ─────────
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

  static String get mapaUrl =>
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$nombre $direccion')}';
}
