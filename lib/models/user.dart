class User {
  final String id;
  final String nombres;
  final String apellidos;
  final String correo;
  final String telefono;
  final String direccion;
  final String documentoIdentidad;
  final DateTime? fechaNacimiento;
  final String? fotoPerfil;

  const User({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    this.telefono = '',
    this.direccion = '',
    this.documentoIdentidad = '',
    this.fechaNacimiento,
    this.fotoPerfil,
  });

  String get nombreCompleto {
    final completo = '$nombres $apellidos'.trim();
    return completo.isEmpty ? 'Sin nombre' : completo;
  }

  bool get fotoPendiente => fotoPerfil == null || fotoPerfil!.trim().isEmpty;

  bool get direccionPendiente => direccion.trim().isEmpty;

  bool get documentoPendiente => documentoIdentidad.trim().isEmpty;

  factory User.fromJson(Map<String, dynamic> json) {
    final nacimiento = json['fecha_nacimiento'];
    return User(
      id: json['id_usuario']?.toString() ?? '',
      nombres: (json['nombres'] ?? '').toString(),
      apellidos: (json['apellidos'] ?? '').toString(),
      correo: (json['correo'] ?? '').toString(),
      telefono: (json['telefono'] ?? '').toString(),
      direccion: (json['direccion'] ?? '').toString(),
      documentoIdentidad: (json['documento_identidad'] ?? '').toString(),
      fechaNacimiento: nacimiento == null
          ? null
          : DateTime.tryParse(nacimiento.toString()),
      fotoPerfil: json['foto_perfil']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'nombres': nombres,
    'apellidos': apellidos,
    'correo': correo,
    'telefono': telefono,
    'direccion': direccion,
    'documento_identidad': documentoIdentidad,
    'fecha_nacimiento': fechaNacimiento == null
        ? null
        : '${fechaNacimiento!.year.toString().padLeft(4, '0')}-'
              '${fechaNacimiento!.month.toString().padLeft(2, '0')}-'
              '${fechaNacimiento!.day.toString().padLeft(2, '0')}',
    'foto_perfil': fotoPerfil,
  };
}
