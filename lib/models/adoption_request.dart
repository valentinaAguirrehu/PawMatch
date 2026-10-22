/// Una respuesta del formulario de adopción, lista para mostrarla.
class AdoptionAnswer {
  final String question;
  final String answer;

  const AdoptionAnswer({required this.question, required this.answer});
}

/// Solicitud guardada en la tabla `solicitudadopcion`.
class AdoptionRequest {
  final String id;
  final String userId;
  final String petId;
  final String housingType;
  final bool? hasYard;
  final bool? hasChildren;
  final bool? hasOtherPets;
  final String otherPets;
  final String availableTime;
  final bool? previousExperience;
  final String additionalInfo;
  final bool hasIdPhoto;
  final bool hasUtilityBill;
  final String requestedAt;
  final String status;
  final String? observations;
  final String? statusUpdatedAt;
  final String? adoptionStartDate;
  final bool readByAdmin;
  final bool readByUser;
  final String? contractFile;
  final String? contractStatus;
  final String? contractUploadedAt;
  final String? reviewerId;

  final String applicantFirstName;
  final String applicantLastName;
  final String applicantEmail;
  final String applicantPhone;
  final String applicantAddress;
  final String applicantIdNumber;

  final String petName;
  final String petSpecies;
  final String petBreed;
  final int? petAge;
  final String petPhoto;
  final String petAdoptionStatus;

  const AdoptionRequest({
    required this.id,
    required this.userId,
    required this.petId,
    this.housingType = '',
    this.hasYard,
    this.hasChildren,
    this.hasOtherPets,
    this.otherPets = '',
    this.availableTime = '',
    this.previousExperience,
    this.additionalInfo = '',
    this.hasIdPhoto = false,
    this.hasUtilityBill = false,
    this.requestedAt = '',
    this.status = 'pendiente',
    this.observations,
    this.statusUpdatedAt,
    this.adoptionStartDate,
    this.readByAdmin = false,
    this.readByUser = true,
    this.contractFile,
    this.contractStatus,
    this.contractUploadedAt,
    this.reviewerId,
    this.applicantFirstName = '',
    this.applicantLastName = '',
    this.applicantEmail = '',
    this.applicantPhone = '',
    this.applicantAddress = '',
    this.applicantIdNumber = '',
    this.petName = '',
    this.petSpecies = '',
    this.petBreed = '',
    this.petAge,
    this.petPhoto = '',
    this.petAdoptionStatus = '',
  });

  bool get isPending => status == 'pendiente';
  bool get isApproved => status == 'aprobada';
  bool get isRejected => status == 'rechazada';

  bool get hasContract =>
      contractFile != null && contractFile!.trim().isNotEmpty;

  /// Aprobada y a la espera de que el administrador cargue el contrato.
  bool get contractPending => isApproved && !hasContract;

  String get statusLabel {
    if (status == 'aprobada' && !hasContract) {
      return 'Pendiente subir contrato de adopción';
    }
    return switch (status) {
      'aprobada' => 'Aprobada',
      'rechazada' => 'Rechazada',
      'cancelada' => 'Cancelada',
      _ => 'Pendiente',
    };
  }

  String? get contractUploadedAtLabel {
    final texto = contractUploadedAt?.trim() ?? '';
    if (texto.isEmpty) return null;
    return _fecha(texto);
  }

  String get applicantFullName {
    final nombre = '$applicantFirstName $applicantLastName'.trim();
    return nombre.isEmpty ? 'Solicitante' : nombre;
  }

  String get petAgeLabel {
    if (petAge == null) return 'Edad no registrada';
    return petAge == 1 ? '1 año' : '$petAge años';
  }

  String get petSummary {
    final partes = [
      petSpecies,
      if (petBreed.isNotEmpty) petBreed else 'Mestizo',
      petAgeLabel,
    ].where((p) => p.isNotEmpty);
    return partes.join(' · ');
  }

  /// Fecha `YYYY-MM-DD HH:mm` mostrada como `dd/MM/yyyy HH:mm`.
  String get requestedAtLabel => _fecha(requestedAt);
  String? get statusUpdatedAtLabel =>
      statusUpdatedAt == null ? null : _fecha(statusUpdatedAt!);

  /// Fecha `YYYY-MM-DD` mostrada como `dd/MM/yyyy`.
  String? get adoptionStartDateLabel {
    final texto = adoptionStartDate?.trim() ?? '';
    if (texto.isEmpty) return null;
    final fecha = texto.split('-');
    if (fecha.length != 3) return texto;
    return '${fecha[2]}/${fecha[1]}/${fecha[0]}';
  }

  bool get hasObservations => (observations ?? '').trim().isNotEmpty;

  List<AdoptionAnswer> get answers => [
    AdoptionAnswer(question: 'Tipo de vivienda', answer: _texto(housingType)),
    AdoptionAnswer(
      question: '¿Tiene patio o zona verde?',
      answer: _siNo(hasYard),
    ),
    AdoptionAnswer(
      question: '¿Hay niños en el hogar?',
      answer: _siNo(hasChildren),
    ),
    AdoptionAnswer(
      question: '¿Tiene otras mascotas?',
      answer: _siNo(hasOtherPets),
    ),
    if (hasOtherPets == true)
      AdoptionAnswer(question: 'Otras mascotas', answer: _texto(otherPets)),
    AdoptionAnswer(
      question: 'Tiempo disponible al día',
      answer: _texto(availableTime),
    ),
    AdoptionAnswer(
      question: '¿Ha tenido mascotas antes?',
      answer: _siNo(previousExperience),
    ),
    AdoptionAnswer(
      question: '¿Por qué quiere adoptar y cómo será el día a día?',
      answer: _texto(additionalInfo),
    ),
  ];

  factory AdoptionRequest.fromJson(Map<String, dynamic> json) {
    return AdoptionRequest(
      id: json['id_solicitud_adopcion']?.toString() ?? '',
      userId: json['id_usuario']?.toString() ?? '',
      petId: json['id_mascota']?.toString() ?? '',
      housingType: json['tipo_vivienda']?.toString() ?? '',
      hasYard: _bool(json['tiene_patio']),
      hasChildren: _bool(json['tiene_ninos']),
      hasOtherPets: _bool(json['tiene_mascotas']),
      otherPets: json['otras_mascotas']?.toString() ?? '',
      availableTime: json['tiempo_disponible']?.toString() ?? '',
      previousExperience: _bool(json['experiencia_previa']),
      additionalInfo: json['informacion_adicional']?.toString() ?? '',
      hasIdPhoto: json['tiene_foto_cedula'] == true,
      hasUtilityBill: json['tiene_foto_recibo'] == true,
      requestedAt: json['fecha_solicitud']?.toString() ?? '',
      status: json['estado']?.toString() ?? 'pendiente',
      observations: _opcional(json['observaciones']),
      statusUpdatedAt: json['fecha_actualizacion_estado']?.toString(),
      adoptionStartDate: _opcional(json['fecha_inicio_adopcion']),
      readByAdmin: json['leido_admin'] == true || json['leido_admin'] == 'true',
      readByUser: json['leido_usuario'] == true || json['leido_usuario'] == 'true',
      contractFile: _opcional(json['contrato_adopcion_archivo']),
      contractStatus: _opcional(json['contrato_adopcion_estado']),
      contractUploadedAt: _opcional(json['contrato_adopcion_subido_en']),
      reviewerId: json['id_administrador_revisor']?.toString(),
      applicantFirstName: json['solicitante_nombres']?.toString() ?? '',
      applicantLastName: json['solicitante_apellidos']?.toString() ?? '',
      applicantEmail: json['solicitante_correo']?.toString() ?? '',
      applicantPhone: json['solicitante_telefono']?.toString() ?? '',
      applicantAddress: json['solicitante_direccion']?.toString() ?? '',
      applicantIdNumber: json['solicitante_cedula']?.toString() ?? '',
      petName: json['mascota_nombre']?.toString() ?? '',
      petSpecies: json['mascota_especie']?.toString() ?? '',
      petBreed: json['mascota_raza']?.toString() ?? '',
      petAge: json['mascota_edad'] == null
          ? null
          : int.tryParse(json['mascota_edad'].toString()),
      petPhoto: json['mascota_fotos']?.toString() ?? '',
      petAdoptionStatus: json['mascota_estado_adopcion']?.toString() ?? '',
    );
  }

  static bool? _bool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final texto = value.toString().toLowerCase();
    if (texto == 'true' || texto == 't' || texto == '1') return true;
    if (texto == 'false' || texto == 'f' || texto == '0') return false;
    return null;
  }

  static String _siNo(bool? value) => switch (value) {
    true => 'Sí',
    false => 'No',
    null => 'Sin respuesta',
  };

  static String? _opcional(dynamic value) {
    final texto = value?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

  static String _texto(String value) =>
      value.trim().isEmpty ? 'Sin respuesta' : value.trim();

  static String _fecha(String raw) {
    final texto = raw.trim();
    if (texto.length < 16) return texto;
    final partes = texto.split(' ');
    if (partes.length < 2) return texto;
    final fecha = partes[0].split('-');
    if (fecha.length != 3) return texto;
    final hora = partes[1].length >= 5 ? partes[1].substring(0, 5) : partes[1];
    return '${fecha[2]}/${fecha[1]}/${fecha[0]} $hora';
  }
}
