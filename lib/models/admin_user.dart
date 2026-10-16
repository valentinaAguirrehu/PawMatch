class AdminUser {
  final String id;
  final String nombres;
  final String apellidos;
  final String correo;
  final String telefono;
  final String rol;
  final String estadoCuenta;
  final DateTime? fechaRegistro;

  const AdminUser({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    required this.telefono,
    required this.rol,
    required this.estadoCuenta,
    required this.fechaRegistro,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  bool get activo => estadoCuenta == 'activo';

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id_usuario']?.toString() ?? '',
    nombres: (json['nombres'] ?? '').toString(),
    apellidos: (json['apellidos'] ?? '').toString(),
    correo: (json['correo'] ?? '').toString(),
    telefono: (json['telefono'] ?? '').toString(),
    rol: (json['rol'] ?? 'usuario').toString(),
    estadoCuenta: (json['estado_cuenta'] ?? 'activo').toString(),
    fechaRegistro: json['fecha_registro'] == null
        ? null
        : DateTime.tryParse(json['fecha_registro'].toString()),
  );
}
