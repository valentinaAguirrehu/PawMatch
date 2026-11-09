/// Modelo de datos para un aporte revisado en un seguimiento.
class SeguimientoAporteItem {
  final String idAporte;
  final String idSeguimiento;
  final String tipo; // 'monetario', 'especie', 'otro'
  final String? comprometido;
  final bool recibido;
  final String? medio; // 'efectivo', 'transferencia', 'consignación', 'otro'
  final double? montoRecibido;
  final String? referencia;
  final String? detalleRecibido;
  final String? observacion;

  const SeguimientoAporteItem({
    required this.idAporte,
    required this.idSeguimiento,
    required this.tipo,
    this.comprometido,
    required this.recibido,
    this.medio,
    this.montoRecibido,
    this.referencia,
    this.detalleRecibido,
    this.observacion,
  });

  factory SeguimientoAporteItem.fromJson(Map<String, dynamic> json) {
    return SeguimientoAporteItem(
      idAporte: (json['id_aporte'] ?? '').toString(),
      idSeguimiento: (json['id_seguimiento_apadrinacion'] ?? '').toString(),
      tipo: (json['tipo'] ?? 'monetario').toString(),
      comprometido: json['comprometido']?.toString(),
      recibido: json['recibido'] == true || json['recibido'] == 'true',
      medio: json['medio']?.toString(),
      montoRecibido: double.tryParse(json['monto_recibido']?.toString() ?? ''),
      referencia: json['referencia']?.toString(),
      detalleRecibido: json['detalle_recibido']?.toString(),
      observacion: json['observacion']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo': tipo,
      'comprometido': comprometido,
      'recibido': recibido,
      'medio': medio,
      'monto_recibido': montoRecibido,
      'referencia': referencia,
      'detalle_recibido': detalleRecibido,
      'observacion': observacion,
    };
  }
}

/// Modelo para una evaluación formal de ciclo (cerrado con 3 seguimientos).
class CicloEvaluacionItem {
  final String idEvaluacion;
  final int ciclo;
  final double promedio;
  final String puntuacion; // 'buen', 'regular', 'mal'
  final String decision; // 'continuar', 'cancelar'
  final String? nota;
  final String? idAdministrador;
  final String adminNombre;
  final DateTime fechaDecision;
  bool vistoPorUsuario;
  DateTime? fechaVistaUsuario;

  CicloEvaluacionItem({
    required this.idEvaluacion,
    required this.ciclo,
    required this.promedio,
    required this.puntuacion,
    required this.decision,
    this.nota,
    this.idAdministrador,
    required this.adminNombre,
    required this.fechaDecision,
    required this.vistoPorUsuario,
    this.fechaVistaUsuario,
  });

  factory CicloEvaluacionItem.fromJson(Map<String, dynamic> json) {
    DateTime parseFecha(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    final adminNom = [
      (json['admin_nombres'] ?? '').toString().trim(),
      (json['admin_apellidos'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    return CicloEvaluacionItem(
      idEvaluacion: (json['id_evaluacion'] ?? '').toString(),
      ciclo: int.tryParse(json['ciclo']?.toString() ?? '1') ?? 1,
      promedio: double.tryParse(json['promedio']?.toString() ?? '0') ?? 0.0,
      puntuacion: (json['puntuacion'] ?? 'buen').toString(),
      decision: (json['decision'] ?? 'continuar').toString(),
      nota: json['nota']?.toString(),
      idAdministrador: json['id_administrador']?.toString(),
      adminNombre: adminNom.isNotEmpty ? adminNom : 'Administrador',
      fechaDecision: parseFecha(json['fecha_decision']),
      vistoPorUsuario: json['visto_por_usuario'] == true || json['visto_por_usuario'] == 'true',
      fechaVistaUsuario: json['fecha_vista_usuario'] != null ? DateTime.tryParse(json['fecha_vista_usuario'].toString()) : null,
    );
  }

  String get clasificacionTexto {
    switch (puntuacion.toLowerCase()) {
      case 'buen':
        return 'BUEN APADRINANTE';
      case 'regular':
        return 'APADRINANTE REGULAR';
      case 'mal':
        return 'MAL APADRINANTE';
      default:
        return promedio >= 4.0
            ? 'BUEN APADRINANTE'
            : (promedio >= 3.0 ? 'APADRINANTE REGULAR' : 'MAL APADRINANTE');
    }
  }
}

/// Modelo de datos para un seguimiento individual.
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
  final int numeroSeguimiento;
  final int ciclo;
  final DateTime? createdAt;
  final List<SeguimientoAporteItem> aportes;

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
    required this.numeroSeguimiento,
    required this.ciclo,
    this.createdAt,
    this.aportes = const [],
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

    final numSeg = int.tryParse(json['numero_seguimiento']?.toString() ?? '1') ?? 1;
    final cicloCalc = int.tryParse(json['ciclo']?.toString() ?? '') ?? ((numSeg + 2) ~/ 3);

    List<SeguimientoAporteItem> listaAportes = [];
    if (json['aportes'] is List) {
      listaAportes = (json['aportes'] as List)
          .map((a) => SeguimientoAporteItem.fromJson(a as Map<String, dynamic>))
          .toList();
    }

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
      numeroSeguimiento: numSeg,
      ciclo: cicloCalc,
      createdAt: parseFechaOpcional(json['created_at']),
      aportes: listaAportes,
    );
  }
}

/// Resumen de un apadrinamiento activo para la vista de seguimiento administrativo.
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

  // Aportes comprometidos
  final bool aportaMonetario;
  final double? montoComprometido;
  final String? periodicidad;
  final bool aportaEspecie;
  final bool aportaOtro;
  final String? detalleOtro;

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

  // Ciclos
  final int cicloActual;
  final int seguimientosEnCiclo;
  final bool evaluacionPendiente;
  final double promedioCicloActual;
  final List<CicloEvaluacionItem> evaluacionesCiclos;

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

  // Evaluación del administrador
  final String? decisionAdmin;
  final String? notaDecision;
  final String? idAdminDecision;
  final DateTime? fechaDecision;
  final String? adminDecisionNombre;

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
    this.aportaMonetario = true,
    this.montoComprometido,
    this.periodicidad,
    this.aportaEspecie = false,
    this.aportaOtro = false,
    this.detalleOtro,
    this.motivoCancelacion,
    this.fechaCancelacion,
    this.decisionAdmin,
    this.notaDecision,
    this.idAdminDecision,
    this.fechaDecision,
    this.adminDecisionNombre,
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
    required this.cicloActual,
    required this.seguimientosEnCiclo,
    required this.evaluacionPendiente,
    required this.promedioCicloActual,
    this.evaluacionesCiclos = const [],
    this.ultimoSeguimientoFecha,
    this.ultimoSeguimientoCalificacion,
    this.ultimoSeguimientoCumplimiento,
    this.ultimoSeguimientoObservaciones,
    this.proximoSeguimientoFecha,
    required this.tieneTresIncumplimientos,
    required this.ultimoCorreoAlertaEnviado,
  });

  bool get esMalPadrino => (evaluacionPendiente ? promedioCicloActual : calificacionPromedio) < 3.0;
  bool get esBuenPadrino => (evaluacionPendiente ? promedioCicloActual : calificacionPromedio) >= 4.0;
  bool get esPadrinoRegular =>
      (evaluacionPendiente ? promedioCicloActual : calificacionPromedio) >= 3.0 &&
      (evaluacionPendiente ? promedioCicloActual : calificacionPromedio) < 4.0;

  String get resumenMascota {
    final partes = [
      mascotaEspecie,
      if (mascotaRaza.isNotEmpty) mascotaRaza,
      '$mascotaEdad $mascotaUnidadEdad',
    ];
    return partes.join(' · ');
  }

  String get resumenAporte {
    if (montoComprometido != null && montoComprometido! > 0) {
      return '\$${montoComprometido!.toStringAsFixed(0)} · ${periodicidad ?? frecuenciaAporte}';
    }
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

    List<CicloEvaluacionItem> listaEvs = [];
    if (json['evaluaciones_ciclos'] is List) {
      listaEvs = (json['evaluaciones_ciclos'] as List)
          .map((e) => CicloEvaluacionItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final cicloAct = int.tryParse(json['ciclo_actual']?.toString() ?? '1') ?? 1;
    final segsEnCiclo = int.tryParse(json['seguimientos_en_ciclo']?.toString() ?? '0') ?? 0;
    final evalPend = json['evaluacion_pendiente'] == true || json['evaluacion_pendiente'] == 'true';
    final promCicloAct = double.tryParse(json['promedio_ciclo_actual']?.toString() ?? '0') ?? 0.0;

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
      aportaMonetario: json['aporta_monetario'] == null || json['aporta_monetario'] == true || json['aporta_monetario'] == 'true',
      montoComprometido: double.tryParse(json['monto_comprometido']?.toString() ?? json['monto_aporte']?.toString() ?? ''),
      periodicidad: json['periodicidad']?.toString() ?? json['frecuencia_aporte']?.toString(),
      aportaEspecie: json['aporta_especie'] == true || json['aporta_especie'] == 'true',
      aportaOtro: json['aporta_otro'] == true || json['aporta_otro'] == 'true',
      detalleOtro: json['detalle_otro']?.toString(),
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
      cicloActual: cicloAct,
      seguimientosEnCiclo: segsEnCiclo,
      evaluacionPendiente: evalPend,
      promedioCicloActual: promCicloAct,
      evaluacionesCiclos: listaEvs,
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
      decisionAdmin: json['decision_admin']?.toString(),
      notaDecision: json['nota_decision']?.toString(),
      idAdminDecision: json['id_admin_decision']?.toString(),
      fechaDecision: parseFecha(json['fecha_decision']),
      adminDecisionNombre: [
        (json['admin_decision_nombres'] ?? '').toString().trim(),
        (json['admin_decision_apellidos'] ?? '').toString().trim(),
      ].where((s) => s.isNotEmpty).join(' ').trim().isEmpty
          ? null
          : [
              (json['admin_decision_nombres'] ?? '').toString().trim(),
              (json['admin_decision_apellidos'] ?? '').toString().trim(),
            ].where((s) => s.isNotEmpty).join(' ').trim(),
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
