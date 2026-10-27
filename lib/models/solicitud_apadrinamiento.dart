class SolicitudApadrinamiento {
  final String id;
  final String idUsuario;
  final String idMascota;
  final String fechaSolicitud;
  final int? montoAporte;
  final String frecuenciaAporte;
  final String tipoAporte;
  final String? detalleEspecie;
  final String motivacion;
  final String estado;
  final String? observaciones;
  final String? fechaActualizacionEstado;
  final String? documentoIdentidadArchivo;
  final String? contratoArchivo;
  final bool acuerdoResponsabilidad;
  final String? fechaAcuerdoResponsabilidad;
  final String? fechaInicioApadrinamiento;
  final bool leidoAdmin;
  final bool leidoUsuario;
  final int vecesRechazada;
  final String estadoCorreo;
  final String? fechaVerificacionCorreo;
  final bool aceptoRequisitos;
  final String? fechaAceptacionRequisitos;
  final String estadoApadrinamiento;
  final String? motivoCancelacion;
  final DateTime? fechaCancelacion;

  // Datos agregados del solicitante
  final String solicitanteNombres;
  final String solicitanteApellidos;
  final String solicitanteCorreo;
  final String solicitanteTelefono;
  final String solicitanteDireccion;
  final String solicitanteCedula;

  // Datos agregados de la mascota
  final String mascotaNombre;
  final String mascotaEspecie;
  final String mascotaRaza;
  final int? mascotaEdad;
  final String mascotaFotos;

  const SolicitudApadrinamiento({
    required this.id,
    required this.idUsuario,
    required this.idMascota,
    required this.fechaSolicitud,
    this.montoAporte,
    this.frecuenciaAporte = 'mensual',
    this.tipoAporte = 'Aporte monetario.',
    this.detalleEspecie,
    required this.motivacion,
    required this.estado,
    this.observaciones,
    this.fechaActualizacionEstado,
    this.documentoIdentidadArchivo,
    this.contratoArchivo,
    this.acuerdoResponsabilidad = false,
    this.fechaAcuerdoResponsabilidad,
    this.fechaInicioApadrinamiento,
    this.leidoAdmin = false,
    this.leidoUsuario = true,
    this.vecesRechazada = 1,
    this.estadoCorreo = 'pendiente',
    this.fechaVerificacionCorreo,
    this.aceptoRequisitos = true,
    this.fechaAceptacionRequisitos,
    this.estadoApadrinamiento = 'activa',
    this.motivoCancelacion,
    this.fechaCancelacion,
    this.solicitanteNombres = '',
    this.solicitanteApellidos = '',
    this.solicitanteCorreo = '',
    this.solicitanteTelefono = '',
    this.solicitanteDireccion = '',
    this.solicitanteCedula = '',
    this.mascotaNombre = '',
    this.mascotaEspecie = '',
    this.mascotaRaza = '',
    this.mascotaEdad,
    this.mascotaFotos = '',
  });

  bool get esCorreoConfirmado => estadoCorreo.toLowerCase() == 'confirmado';
  String get correoEstadoTexto =>
      esCorreoConfirmado ? 'Correo confirmado' : 'Correo pendiente de confirmación';

  String get mascotaEdadTexto {
    if (mascotaEdad == null) return 'Edad no registrada';
    return mascotaEdad == 1 ? '1 año' : '$mascotaEdad años';
  }

  String get solicitanteNombreCompleto {
    final c = '$solicitanteNombres $solicitanteApellidos'.trim();
    return c.isEmpty ? 'Solicitante' : c;
  }

  String get nombreCompleto => solicitanteNombreCompleto;
  String get documentoIdentidad => solicitanteCedula;
  String get correo => solicitanteCorreo;
  String get telefono => solicitanteTelefono;
  String? get archivoCedula => documentoIdentidadArchivo;
  String get detalleAporte => motivacion;
  DateTime get fechaCreacion =>
      DateTime.tryParse(fechaSolicitud.replaceFirst(' ', 'T')) ?? DateTime.now();

  bool get esPendiente => estado == 'pendiente';
  bool get esAprobada => estado == 'aprobada';
  bool get esRechazada => estado == 'rechazada';
  bool get esCancelada => estado == 'cancelada';
  bool get tieneContrato =>
      contratoArchivo != null && contratoArchivo!.trim().isNotEmpty;

  factory SolicitudApadrinamiento.fromJson(Map<String, dynamic> json) {
    return SolicitudApadrinamiento(
      id: json['id_solicitud_apadrinamiento']?.toString() ?? '',
      idUsuario: json['id_usuario']?.toString() ?? '',
      idMascota: json['id_mascota']?.toString() ?? '',
      fechaSolicitud: json['fecha_solicitud']?.toString() ?? '',
      montoAporte: json['monto_aporte'] != null ? int.tryParse(json['monto_aporte'].toString()) : null,
      frecuenciaAporte: json['frecuencia_aporte']?.toString() ?? 'mensual',
      tipoAporte: json['tipo_aporte']?.toString() ?? 'Aporte monetario.',
      detalleEspecie: json['detalle_especie']?.toString(),
      motivacion: (json['informacion_adicional'] ?? json['motivacion'] ?? '').toString(),
      estado: json['estado']?.toString() ?? 'pendiente',
      observaciones: json['observaciones']?.toString(),
      fechaActualizacionEstado: json['fecha_actualizacion_estado']?.toString(),
      documentoIdentidadArchivo: json['documento_identidad_archivo']?.toString(),
      contratoArchivo: json['contrato_apadrinamiento_archivo']?.toString(),
      acuerdoResponsabilidad: json['acuerdo_responsabilidad'] == true || json['acuerdo_responsabilidad'] == 'true',
      fechaAcuerdoResponsabilidad: json['fecha_acuerdo_responsabilidad']?.toString(),
      fechaInicioApadrinamiento: json['fecha_inicio_apadrinamiento']?.toString(),
      leidoAdmin: json['leido_admin'] == true || json['leido_admin'] == 'true',
      leidoUsuario: json['leido_usuario'] == true || json['leido_usuario'] == 'true',
      vecesRechazada: json['veces_rechazada'] != null
          ? (int.tryParse(json['veces_rechazada'].toString()) ?? 1)
          : 1,
      estadoCorreo: json['estado_correo']?.toString() ?? 'pendiente',
      fechaVerificacionCorreo: json['fecha_verificacion_correo']?.toString(),
      aceptoRequisitos: json['acepto_requisitos'] == null ||
          json['acepto_requisitos'] == true ||
          json['acepto_requisitos'] == 'true',
      fechaAceptacionRequisitos: json['fecha_aceptacion_requisitos']?.toString(),
      solicitanteNombres: json['solicitante_nombres']?.toString() ?? '',
      solicitanteApellidos: json['solicitante_apellidos']?.toString() ?? '',
      solicitanteCorreo: json['solicitante_correo']?.toString() ?? '',
      solicitanteTelefono: json['solicitante_telefono']?.toString() ?? '',
      solicitanteDireccion: json['solicitante_direccion']?.toString() ?? '',
      solicitanteCedula: json['solicitante_cedula']?.toString() ?? '',
      mascotaNombre: json['mascota_nombre']?.toString() ?? '',
      mascotaEspecie: json['mascota_especie']?.toString() ?? '',
      mascotaRaza: json['mascota_raza']?.toString() ?? '',
      mascotaEdad: json['mascota_edad'] != null ? int.tryParse(json['mascota_edad'].toString()) : null,
      mascotaFotos: json['mascota_fotos']?.toString() ?? '',
      estadoApadrinamiento: json['estado_apadrinamiento']?.toString() ?? 'activa',
      motivoCancelacion: json['motivo_cancelacion']?.toString(),
      fechaCancelacion: json['fecha_cancelacion'] != null ? DateTime.tryParse(json['fecha_cancelacion'].toString()) : null,
    );
  }
}
