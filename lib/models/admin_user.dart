class AdminUser {
  final String id;
  final String nombres;
  final String apellidos;
  final String correo;
  final String telefono;
  final String documentoIdentidad;
  final String? fotoPerfil;
  final String rol;
  final String estadoCuenta;
  final String? motivoInactivacion;
  final DateTime? fechaInactivacion;
  final String? administradorInactivacion;
  final DateTime? fechaRegistro;

  const AdminUser({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    required this.telefono,
    this.documentoIdentidad = '',
    this.fotoPerfil,
    required this.rol,
    required this.estadoCuenta,
    this.motivoInactivacion,
    this.fechaInactivacion,
    this.administradorInactivacion,
    required this.fechaRegistro,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  bool get activo => estadoCuenta == 'activo';

  String? get fechaRegistroLabel {
    final fecha = fechaRegistro?.toLocal();
    if (fecha == null) return null;
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}';
  }

  String? get fechaInactivacionLabel {
    final fecha = fechaInactivacion?.toLocal();
    if (fecha == null) return null;
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id_usuario']?.toString() ?? '',
    nombres: (json['nombres'] ?? '').toString(),
    apellidos: (json['apellidos'] ?? '').toString(),
    correo: (json['correo'] ?? '').toString(),
    telefono: (json['telefono'] ?? '').toString(),
    documentoIdentidad: (json['documento_identidad'] ?? '').toString(),
    fotoPerfil: _foto(json['foto_perfil']),
    rol: (json['rol'] ?? 'usuario').toString(),
    estadoCuenta: (json['estado_cuenta'] ?? 'activo').toString(),
    motivoInactivacion: _texto(json['motivo_inactivacion']),
    fechaInactivacion: json['fecha_inactivacion'] == null
        ? null
        : DateTime.tryParse(json['fecha_inactivacion'].toString()),
    administradorInactivacion: _texto(json['administrador_inactivacion']),
    fechaRegistro: json['fecha_registro'] == null
        ? null
        : DateTime.tryParse(json['fecha_registro'].toString()),
  );

  static String? _foto(dynamic value) {
    final texto = value?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

  static String? _texto(dynamic value) {
    final texto = value?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }
}
