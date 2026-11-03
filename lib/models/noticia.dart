/// Modelo de Noticia de la Fundación
class Noticia {
  final String id;
  final String titulo;
  final String contenido;
  final String? imagen;
  final String lugar;
  final String fecha; // 'YYYY-MM-DD'
  final String? fechaCreacion;
  final String? idAdministrador;
  final int totalLikes;
  final bool dioLike;

  const Noticia({
    required this.id,
    required this.titulo,
    required this.contenido,
    this.imagen,
    this.lugar = 'Fundación Maritza Arévalo',
    required this.fecha,
    this.fechaCreacion,
    this.idAdministrador,
    this.totalLikes = 0,
    this.dioLike = false,
  });

  factory Noticia.fromJson(Map<String, dynamic> j) {
    String rawLugar = (j['lugar'] as String?)?.trim() ?? '';
    if (rawLugar.isEmpty) {
      rawLugar = 'Fundación Maritza Arévalo';
    } else {
      rawLugar = rawLugar.replaceAll(RegExp(r',?\s*Cali', caseSensitive: false), '').trim();
      if (rawLugar.isEmpty) rawLugar = 'Fundación Maritza Arévalo';
    }

    return Noticia(
      id: j['id_noticia'] as String,
      titulo: (j['titulo'] ?? '') as String,
      contenido: (j['contenido'] ?? '') as String,
      imagen: j['imagen'] as String?,
      lugar: rawLugar,
      fecha: (j['fecha'] ?? '') as String,
      fechaCreacion: j['fecha_creacion'] as String?,
      idAdministrador: j['id_administrador'] as String?,
      totalLikes: (j['total_likes'] as num?)?.toInt() ?? 0,
      dioLike: j['dio_like'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'titulo': titulo,
    'contenido': contenido,
    'imagen': imagen,
    'lugar': lugar,
    'fecha': fecha,
  };

  Noticia copyWith({
    String? id,
    String? titulo,
    String? contenido,
    String? imagen,
    String? lugar,
    String? fecha,
    String? fechaCreacion,
    String? idAdministrador,
    int? totalLikes,
    bool? dioLike,
  }) {
    return Noticia(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      contenido: contenido ?? this.contenido,
      imagen: imagen ?? this.imagen,
      lugar: lugar ?? this.lugar,
      fecha: fecha ?? this.fecha,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      idAdministrador: idAdministrador ?? this.idAdministrador,
      totalLikes: totalLikes ?? this.totalLikes,
      dioLike: dioLike ?? this.dioLike,
    );
  }

  String get fechaFormateada {
    if (fecha.isEmpty) return '';
    try {
      final partes = fecha.split('-');
      if (partes.length == 3) {
        final anio = partes[0];
        final mesNum = int.tryParse(partes[1]) ?? 1;
        final dia = partes[2];
        const meses = [
          'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
          'jul.', 'ago.', 'sep.', 'oct.', 'nov.', 'dic.'
        ];
        final mes = (mesNum >= 1 && mesNum <= 12) ? meses[mesNum - 1] : '';
        return '$dia $mes $anio';
      }
    } catch (_) {}
    return fecha;
  }
}
