/// Respuesta guardada de las preguntas del seguimiento: 5 sí, 1 no, 3 puede mejorar.
String etiquetaRespuestaSeguimiento(int valor) {
  return switch (valor) {
    5 => 'Sí',
    1 => 'No',
    3 => 'Puede mejorar',
    _ => 'Sin respuesta',
  };
}

/// Un registro de seguimiento de una adopción formalizada.
class SeguimientoAdopcionItem {
  final String idSeguimiento;
  final String idSolicitud;
  final String adminNombre;
  final DateTime fechaSeguimiento;
  final int pesoSaludable;
  final int condicionSanitaria;
  final int entornoApto;
  final int comportamiento;
  final int compromisoVeterinario;
  final int disposicionAdoptante;
  final String? fotoEstado;
  final String? fotoEntorno;
  final String observaciones;
  final DateTime? proximoSeguimiento;
  final int calificacion;
  final bool cumplimiento;
  final int numeroSeguimiento;

  const SeguimientoAdopcionItem({
    required this.idSeguimiento,
    required this.idSolicitud,
    required this.adminNombre,
    required this.fechaSeguimiento,
    required this.pesoSaludable,
    required this.condicionSanitaria,
    required this.entornoApto,
    required this.comportamiento,
    required this.compromisoVeterinario,
    required this.disposicionAdoptante,
    this.fotoEstado,
    this.fotoEntorno,
    required this.observaciones,
    this.proximoSeguimiento,
    required this.calificacion,
    required this.cumplimiento,
    required this.numeroSeguimiento,
  });

  factory SeguimientoAdopcionItem.fromJson(Map<String, dynamic> json) {
    final adminNom = [
      (json['admin_nombres'] ?? '').toString().trim(),
      (json['admin_apellidos'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    final numSeg = int.tryParse(json['numero_seguimiento']?.toString() ?? '1') ?? 1;

    return SeguimientoAdopcionItem(
      idSeguimiento: (json['id_seguimiento_adopcion'] ?? '').toString(),
      idSolicitud: (json['id_solicitud_adopcion'] ?? '').toString(),
      adminNombre: adminNom.isNotEmpty ? adminNom : 'Administrador',
      fechaSeguimiento: DateTime.tryParse(json['fecha_seguimiento']?.toString() ?? '') ?? DateTime.now(),
      pesoSaludable: int.tryParse(json['peso_saludable']?.toString() ?? '') ?? 0,
      condicionSanitaria: int.tryParse(json['condicion_sanitaria']?.toString() ?? '') ?? 0,
      entornoApto: int.tryParse(json['entorno_apto']?.toString() ?? '') ?? 0,
      comportamiento: int.tryParse(json['comportamiento']?.toString() ?? '') ?? 0,
      compromisoVeterinario: int.tryParse(json['compromiso_veterinario']?.toString() ?? '') ?? 0,
      disposicionAdoptante: int.tryParse(json['disposicion_adoptante']?.toString() ?? '') ?? 0,
      fotoEstado: json['foto_estado']?.toString(),
      fotoEntorno: json['foto_entorno']?.toString(),
      observaciones: (json['observaciones'] ?? '').toString(),
      proximoSeguimiento: DateTime.tryParse(
        (json['proxima_fecha_seguimiento'] ?? json['proximo_seguimiento'])?.toString() ?? '',
      ),
      calificacion: int.tryParse(json['calificacion']?.toString() ?? '5') ?? 5,
      cumplimiento: json['cumplimiento'] == true || json['cumplimiento'] == 'true',
      numeroSeguimiento: numSeg,
    );
  }
}

/// Formulario guardado cuando se cancela una adopción.
class CancelacionAdopcion {
  final DateTime fechaCancelacion;
  final String motivo;
  final String observacion;
  final String? foto1;
  final String? foto2;
  final bool inhabilitarCuenta;
  final String adminNombre;

  const CancelacionAdopcion({
    required this.fechaCancelacion,
    required this.motivo,
    required this.observacion,
    this.foto1,
    this.foto2,
    required this.inhabilitarCuenta,
    required this.adminNombre,
  });

  factory CancelacionAdopcion.fromJson(Map<String, dynamic> json) {
    final admin = [
      (json['admin_nombres'] ?? '').toString().trim(),
      (json['admin_apellidos'] ?? '').toString().trim(),
    ].where((parte) => parte.isNotEmpty).join(' ');
    String? foto(dynamic valor) {
      final texto = valor?.toString().trim() ?? '';
      if (texto.isEmpty || texto == 'null') return null;
      return texto;
    }

    return CancelacionAdopcion(
      fechaCancelacion: DateTime.tryParse(json['fecha_cancelacion']?.toString() ?? '') ?? DateTime.now(),
      motivo: (json['motivo'] ?? '').toString(),
      observacion: (json['observacion'] ?? '').toString(),
      foto1: foto(json['foto_1']),
      foto2: foto(json['foto_2']),
      inhabilitarCuenta: json['inhabilitar_cuenta'] == true || json['inhabilitar_cuenta'] == 'true',
      adminNombre: admin.isNotEmpty ? admin : 'Administrador',
    );
  }
}

/// Adopción activa con contrato, lista para el panel de seguimiento.
class AdopcionActivaSeguimiento {
  final String idSolicitud;
  final String estado;
  final DateTime? fechaInicio;
  final String? contratoArchivo;

  final String idMascota;
  final String mascotaNombre;
  final dynamic mascotaFotos;
  final String mascotaEspecie;
  final String mascotaRaza;
  final int mascotaEdad;
  final String mascotaUnidadEdad;

  final String idAdoptante;
  final String adoptanteNombre;
  final String adoptanteCedula;
  final String adoptanteCorreo;
  final String adoptanteTelefono;
  final String adoptanteDireccion;

  final double calificacionPromedio;
  final int totalSeguimientos;

  final DateTime? ultimoSeguimientoFecha;
  final int? ultimoSeguimientoCalificacion;
  final DateTime? proximoSeguimientoFecha;
  final String estadoSeguimiento;

  const AdopcionActivaSeguimiento({
    required this.idSolicitud,
    required this.estado,
    this.fechaInicio,
    this.contratoArchivo,
    required this.idMascota,
    required this.mascotaNombre,
    required this.mascotaFotos,
    required this.mascotaEspecie,
    required this.mascotaRaza,
    required this.mascotaEdad,
    required this.mascotaUnidadEdad,
    required this.idAdoptante,
    required this.adoptanteNombre,
    this.adoptanteCedula = '',
    required this.adoptanteCorreo,
    required this.adoptanteTelefono,
    this.adoptanteDireccion = '',
    required this.calificacionPromedio,
    required this.totalSeguimientos,
    this.ultimoSeguimientoFecha,
    this.ultimoSeguimientoCalificacion,
    this.proximoSeguimientoFecha,
    this.estadoSeguimiento = 'activa',
  });

  bool get adopcionCancelada => estadoSeguimiento == 'cancelada';

  String get edadTexto {
    final unidad = mascotaUnidadEdad.trim().toLowerCase();
    if (unidad == 'mes' || unidad == 'meses') {
      return mascotaEdad == 1 ? '1 mes' : '$mascotaEdad meses';
    }
    return mascotaEdad == 1 ? '1 año' : '$mascotaEdad años';
  }

  String get resumenMascota {
    return [
      mascotaEspecie,
      if (mascotaRaza.isNotEmpty) mascotaRaza,
      edadTexto,
    ].join(' · ');
  }

  String? get fotoPrincipal {
    if (mascotaFotos is List && mascotaFotos.isNotEmpty) {
      return mascotaFotos.first.toString();
    }
    final texto = mascotaFotos?.toString() ?? '';
    if (texto.isEmpty || texto == 'null') return null;
    return texto;
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

  factory AdopcionActivaSeguimiento.fromJson(Map<String, dynamic> json) {
    DateTime? parseFecha(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    final nombreCompleto = [
      (json['usuario_nombres'] ?? '').toString().trim(),
      (json['usuario_apellidos'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    return AdopcionActivaSeguimiento(
      idSolicitud: (json['id_solicitud_adopcion'] ?? '').toString(),
      estado: (json['estado'] ?? 'aprobada').toString(),
      fechaInicio: parseFecha(json['fecha_inicio_adopcion']),
      contratoArchivo: json['contrato_adopcion_archivo']?.toString(),
      idMascota: (json['id_mascota'] ?? '').toString(),
      mascotaNombre: (json['mascota_nombre'] ?? '').toString(),
      mascotaFotos: json['mascota_fotos'] ?? '',
      mascotaEspecie: (json['mascota_especie'] ?? 'Perro').toString(),
      mascotaRaza: (json['mascota_raza'] ?? '').toString(),
      mascotaEdad: int.tryParse(json['mascota_edad']?.toString() ?? '1') ?? 1,
      mascotaUnidadEdad: (json['mascota_unidad_edad'] ?? 'años').toString(),
      idAdoptante: (json['id_usuario'] ?? '').toString(),
      adoptanteNombre: nombreCompleto.isNotEmpty ? nombreCompleto : 'Adoptante',
      adoptanteCedula: (json['usuario_cedula'] ?? '').toString(),
      adoptanteCorreo: (json['usuario_correo'] ?? '').toString(),
      adoptanteTelefono: (json['usuario_telefono'] ?? '').toString(),
      adoptanteDireccion: (json['usuario_direccion'] ?? '').toString(),
      calificacionPromedio: double.tryParse(json['calificacion_promedio']?.toString() ?? '0') ?? 0,
      totalSeguimientos: int.tryParse(json['total_seguimientos']?.toString() ?? '0') ?? 0,
      ultimoSeguimientoFecha: parseFecha(json['ultimo_seguimiento_fecha']),
      ultimoSeguimientoCalificacion: int.tryParse(json['ultimo_seguimiento_calificacion']?.toString() ?? ''),
      proximoSeguimientoFecha: parseFecha(json['proximo_seguimiento_fecha']),
      estadoSeguimiento: (json['estado_seguimiento'] ?? 'activa').toString(),
    );
  }
}
