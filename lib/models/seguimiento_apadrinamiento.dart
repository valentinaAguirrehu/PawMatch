/// Modelo de datos para el módulo de Seguimiento de Apadrinamiento.
class SeguimientoApadrinamientoItem {
  final String idSeguimiento;
  final String idSolicitud;
  final String idAdministrador;
  final String adminNombre;
  final DateTime fechaSeguimiento;
  final bool cumplimiento;
  final String observaciones;
  final DateTime? proximoSeguimiento;
  final int calificacion;
  final bool correoAlertaEnviado;
  final DateTime? createdAt;

  const SeguimientoApadrinamientoItem({
    required this.idSeguimiento,
    required this.idSolicitud,
    required this.idAdministrador,
    required this.adminNombre,
    required this.fechaSeguimiento,
    required this.cumplimiento,
    required this.observaciones,
    this.proximoSeguimiento,
    required this.calificacion,
    required this.correoAlertaEnviado,
    this.createdAt,
  });

  factory SeguimientoApadrinamientoItem.fromJson(Map<String, dynamic> json) {
    DateTime parseFecha(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    DateTime? parseFechaOpcional(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    final adminNom = [
      (json['admin_nombres'] ?? json['nombres'] ?? '').toString().trim(),
      (json['admin_apellidos'] ?? json['apellidos'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    return SeguimientoApadrinamientoItem(
      idSeguimiento: (json['id_seguimiento_apadrinacion'] ?? json['id'] ?? '').toString(),
      idSolicitud: (json['id_solicitud_apadrinamiento'] ?? '').toString(),
      idAdministrador: (json['id_administrador'] ?? '').toString(),
      adminNombre: adminNom.isNotEmpty ? adminNom : 'Administrador',
      fechaSeguimiento: parseFecha(json['fecha_seguimiento']),
      cumplimiento: json['cumplimiento'] == true || json['cumplimiento'] == 'true',
      observaciones: (json['observaciones'] ?? '').toString(),
      proximoSeguimiento: parseFechaOpcional(json['proximo_seguimiento']),
      calificacion: int.tryParse(json['calificacion']?.toString() ?? '5') ?? 5,
      correoAlertaEnviado: json['correo_alerta_enviado'] == true || json['correo_alerta_enviado'] == 'true',
      createdAt: parseFechaOpcional(json['created_at']),
    );
  }
}

/// Resumen de un apadrinamiento activo para la vista de seguimiento.
class ApadrinamientoActivoSeguimiento {
  final String idSolicitud;
  final String estado;
  final String estadoApadrinamiento;
  final int? montoAporte;
  final String frecuenciaAporte;
  final String tipoAporte;
  final String? detalleEspecie;
  final DateTime? fechaInicio;
  final String? contratoArchivo;

  // Mascota
  final String idMascota;
  final String mascotaNombre;
  final dynamic mascotaFotos;
  final String mascotaEspecie;
  final String mascotaRaza;
  final int mascotaEdad;
  final String mascotaUnidadEdad;

  // Padrino
  final String idPadrino;
  final String padrinoNombre;
  final String padrinoCorreo;
  final String padrinoTelefono;
  final String? padrinoFoto;
  final bool padrinoBloqueado;
  final double calificacionPromedio;
  final int totalSeguimientos;

  // Último seguimiento
  final DateTime? ultimoSeguimientoFecha;
  final int? ultimoSeguimientoCalificacion;
  final bool? ultimoSeguimientoCumplimiento;
  final String? ultimoSeguimientoObservaciones;
  final DateTime? proximoSeguimientoFecha;

  // Regla de incumplimientos
  final bool tieneTresIncumplimientos;
  final bool ultimoCorreoAlertaEnviado;

  // Cancelación
  final String? motivoCancelacion;
  final DateTime? fechaCancelacion;

  const ApadrinamientoActivoSeguimiento({
    required this.idSolicitud,
    required this.estado,
    required this.estadoApadrinamiento,
    this.montoAporte,
    required this.frecuenciaAporte,
    required this.tipoAporte,
    this.detalleEspecie,
    this.fechaInicio,
    this.contratoArchivo,
    this.motivoCancelacion,
    this.fechaCancelacion,
    required this.idMascota,
    required this.mascotaNombre,
    required this.mascotaFotos,
    required this.mascotaEspecie,
    required this.mascotaRaza,
    required this.mascotaEdad,
    required this.mascotaUnidadEdad,
    required this.idPadrino,
    required this.padrinoNombre,
    required this.padrinoCorreo,
    required this.padrinoTelefono,
    this.padrinoFoto,
    required this.padrinoBloqueado,
    required this.calificacionPromedio,
    required this.totalSeguimientos,
    this.ultimoSeguimientoFecha,
    this.ultimoSeguimientoCalificacion,
    this.ultimoSeguimientoCumplimiento,
    this.ultimoSeguimientoObservaciones,
    this.proximoSeguimientoFecha,
    required this.tieneTresIncumplimientos,
    required this.ultimoCorreoAlertaEnviado,
  });

  String get resumenMascota {
    final partes = [
      mascotaEspecie,
      if (mascotaRaza.isNotEmpty) mascotaRaza,
      '$mascotaEdad $mascotaUnidadEdad',
    ];
    return partes.join(' · ');
  }

  String get resumenAporte {
    if (montoAporte != null && montoAporte! > 0) {
      return '\$$montoAporte · $frecuenciaAporte';
    }
    if (detalleEspecie != null && detalleEspecie!.trim().isNotEmpty) {
      return '$tipoAporte ($detalleEspecie)';
    }
    return tipoAporte;
  }

  bool get proximoSeguimientoVencido {
    if (proximoSeguimientoFecha == null) return false;
    final hoy = DateTime.now();
    final fechaHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final proximo = DateTime(
      proximoSeguimientoFecha!.year,
      proximoSeguimientoFecha!.month,
      proximoSeguimientoFecha!.day,
    );
    return proximo.isBefore(fechaHoy);
  }

  factory ApadrinamientoActivoSeguimiento.fromJson(Map<String, dynamic> json) {
    DateTime? parseFecha(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    final nombreCompleto = [
      (json['usuario_nombres'] ?? json['nombres'] ?? '').toString().trim(),
      (json['usuario_apellidos'] ?? json['apellidos'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    return ApadrinamientoActivoSeguimiento(
      idSolicitud: (json['id_solicitud_apadrinamiento'] ?? '').toString(),
      estado: (json['estado'] ?? 'aprobada').toString(),
      estadoApadrinamiento: (json['estado_apadrinamiento'] ?? 'activa').toString(),
      montoAporte: int.tryParse(json['monto_aporte']?.toString() ?? ''),
      frecuenciaAporte: (json['frecuencia_aporte'] ?? 'mensual').toString(),
      tipoAporte: (json['tipo_aporte'] ?? 'Aporte monetario.').toString(),
      detalleEspecie: json['detalle_especie']?.toString(),
      fechaInicio: parseFecha(json['fecha_inicio_apadrinamiento']),
      contratoArchivo: json['contrato_apadrinamiento_archivo']?.toString(),
      idMascota: (json['id_mascota'] ?? '').toString(),
      mascotaNombre: (json['mascota_nombre'] ?? json['nombre'] ?? '').toString(),
      mascotaFotos: json['mascota_fotos'] ?? json['fotos'] ?? '',
      mascotaEspecie: (json['mascota_especie'] ?? json['especie'] ?? 'Perro').toString(),
      mascotaRaza: (json['mascota_raza'] ?? json['raza'] ?? 'Mestiza').toString(),
      mascotaEdad: int.tryParse(json['mascota_edad']?.toString() ?? '1') ?? 1,
      mascotaUnidadEdad: (json['mascota_unidad_edad'] ?? json['unidad_edad'] ?? 'años').toString(),
      idPadrino: (json['id_usuario'] ?? '').toString(),
      padrinoNombre: nombreCompleto.isNotEmpty ? nombreCompleto : 'Padrino',
      padrinoCorreo: (json['usuario_correo'] ?? json['correo'] ?? '').toString(),
      padrinoTelefono: (json['usuario_telefono'] ?? json['telefono'] ?? '').toString(),
      padrinoFoto: json['usuario_foto']?.toString(),
      padrinoBloqueado: json['usuario_bloqueado'] == true || json['bloqueado_apadrinar'] == true,
      calificacionPromedio: double.tryParse(json['calificacion_promedio']?.toString() ?? '0') ?? 0.0,
      totalSeguimientos: int.tryParse(json['total_seguimientos']?.toString() ?? '0') ?? 0,
      ultimoSeguimientoFecha: parseFecha(json['ultimo_seguimiento_fecha']),
      ultimoSeguimientoCalificacion: int.tryParse(json['ultimo_seguimiento_calificacion']?.toString() ?? ''),
      ultimoSeguimientoCumplimiento: json['ultimo_seguimiento_cumplimiento'] == null
          ? null
          : (json['ultimo_seguimiento_cumplimiento'] == true || json['ultimo_seguimiento_cumplimiento'] == 'true'),
      ultimoSeguimientoObservaciones: json['ultimo_seguimiento_observaciones']?.toString(),
      proximoSeguimientoFecha: parseFecha(json['proximo_seguimiento_fecha']),
      tieneTresIncumplimientos: json['tiene_tres_incumplimientos'] == true || json['tiene_tres_incumplimientos'] == 'true',
      ultimoCorreoAlertaEnviado: json['ultimo_correo_enviado'] == true || json['ultimo_correo_enviado'] == 'true',
      motivoCancelacion: json['motivo_cancelacion']?.toString(),
      fechaCancelacion: parseFecha(json['fecha_cancelacion']),
    );
  }
}

/// Elemento para el calendario de seguimientos.
class ItemCalendarioSeguimiento {
  final String idSeguimiento;
  final String idSolicitud;
  final DateTime proximoSeguimiento;
  final DateTime? fechaUltimoSeguimiento;
  final bool esVencido;
  final bool? ultimoCumplimiento;
  final int? ultimaCalificacion;
  final String? ultimasObservaciones;

  // Mascota
  final String idMascota;
  final String mascotaNombre;
  final dynamic mascotaFotos;
  final String mascotaEspecie;
  final String mascotaRaza;
  final int mascotaEdad;
  final String mascotaUnidadEdad;

  // Padrino
  final String idPadrino;
  final String padrinoNombre;
  final String padrinoCorreo;
  final String padrinoTelefono;
  final double calificacionPromedio;
  final bool tieneTresIncumplimientos;

  const ItemCalendarioSeguimiento({
    required this.idSeguimiento,
    required this.idSolicitud,
    required this.proximoSeguimiento,
    this.fechaUltimoSeguimiento,
    required this.esVencido,
    this.ultimoCumplimiento,
    this.ultimaCalificacion,
    this.ultimasObservaciones,
    required this.idMascota,
    required this.mascotaNombre,
    required this.mascotaFotos,
    required this.mascotaEspecie,
    required this.mascotaRaza,
    required this.mascotaEdad,
    required this.mascotaUnidadEdad,
    required this.idPadrino,
    required this.padrinoNombre,
    required this.padrinoCorreo,
    required this.padrinoTelefono,
    required this.calificacionPromedio,
    required this.tieneTresIncumplimientos,
  });

  factory ItemCalendarioSeguimiento.fromJson(Map<String, dynamic> json) {
    DateTime parseFecha(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    DateTime? parseFechaOpcional(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    final nombreCompleto = [
      (json['usuario_nombres'] ?? json['nombres'] ?? '').toString().trim(),
      (json['usuario_apellidos'] ?? json['apellidos'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final proximo = parseFecha(json['proximo_seguimiento']);
    final hoy = DateTime.now();
    final fechaHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final proximoDia = DateTime(proximo.year, proximo.month, proximo.day);

    return ItemCalendarioSeguimiento(
      idSeguimiento: (json['id_seguimiento_apadrinacion'] ?? '').toString(),
      idSolicitud: (json['id_solicitud_apadrinamiento'] ?? '').toString(),
      proximoSeguimiento: proximo,
      fechaUltimoSeguimiento: parseFechaOpcional(json['fecha_ultimo_seguimiento']),
      esVencido: json['es_vencido'] == true || proximoDia.isBefore(fechaHoy),
      ultimoCumplimiento: json['ultimo_cumplimiento'] == null ? null : (json['ultimo_cumplimiento'] == true),
      ultimaCalificacion: int.tryParse(json['ultima_calificacion']?.toString() ?? ''),
      ultimasObservaciones: json['ultimas_observaciones']?.toString(),
      idMascota: (json['id_mascota'] ?? '').toString(),
      mascotaNombre: (json['mascota_nombre'] ?? '').toString(),
      mascotaFotos: json['mascota_fotos'] ?? '',
      mascotaEspecie: (json['mascota_especie'] ?? 'Perro').toString(),
      mascotaRaza: (json['mascota_raza'] ?? 'Mestiza').toString(),
      mascotaEdad: int.tryParse(json['mascota_edad']?.toString() ?? '1') ?? 1,
      mascotaUnidadEdad: (json['mascota_unidad_edad'] ?? 'años').toString(),
      idPadrino: (json['id_usuario'] ?? '').toString(),
      padrinoNombre: nombreCompleto.isNotEmpty ? nombreCompleto : 'Padrino',
      padrinoCorreo: (json['usuario_correo'] ?? '').toString(),
      padrinoTelefono: (json['usuario_telefono'] ?? '').toString(),
      calificacionPromedio: double.tryParse(json['calificacion_promedio']?.toString() ?? '0') ?? 0.0,
      tieneTresIncumplimientos: json['tiene_tres_incumplimientos'] == true,
    );
  }
}

/// Resumen estadístico del padrino para su perfil y cabeceras.
class ResumenPadrino {
  final String idUsuario;
  final String nombres;
  final String apellidos;
  final bool bloqueadoApadrinar;
  final double calificacionPromedio;
  final int totalSeguimientos;
  final bool tieneAlerta;
  final List<dynamic> solicitudesConAlerta;

  const ResumenPadrino({
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.bloqueadoApadrinar,
    required this.calificacionPromedio,
    required this.totalSeguimientos,
    required this.tieneAlerta,
    required this.solicitudesConAlerta,
  });

  factory ResumenPadrino.fromJson(Map<String, dynamic> json) {
    return ResumenPadrino(
      idUsuario: (json['id_usuario'] ?? '').toString(),
      nombres: (json['nombres'] ?? '').toString(),
      apellidos: (json['apellidos'] ?? '').toString(),
      bloqueadoApadrinar: json['bloqueado_apadrinar'] == true,
      calificacionPromedio: double.tryParse(json['calificacion_promedio']?.toString() ?? '0') ?? 0.0,
      totalSeguimientos: int.tryParse(json['total_seguimientos']?.toString() ?? '0') ?? 0,
      tieneAlerta: json['tiene_alerta'] == true,
      solicitudesConAlerta: (json['solicitudes_con_alerta'] as List?) ?? [],
    );
  }
}
