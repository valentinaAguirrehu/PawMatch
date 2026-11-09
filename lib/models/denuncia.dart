class Denuncia {
  final String id;
  final String radicado;
  final String? idUsuario;
  final bool esAnonimo;
  final String? nombreReportante;
  final String? documentoReportante;
  final String? correoReportante;
  final String? telefonoReportante;
  final String? ciudadReportante;
  final String? barrioReportante;
  final String tipoReporte;
  final String tipoAnimal;
  final String ubicacionAnimal;
  final String ciudadCaso;
  final String fechaSituacion;
  final String peligroInmediato;
  final String descripcionCaso;
  final String? caracteristicasAnimal;
  final String? estadoSalud;
  final String? heridasVisibles;
  final String? condicionesAlimentacion;
  final String? condicionesLugar;
  final String? comportamientoAnimal;
  final String? dificultadMovilidad;
  final String? observacionesAdicionales;
  final bool aceptoPolitica;
  final String? versionPolitica;
  final String? fechaAutorizacion;
  final String estado;
  final bool leidoAdmin;
  final String? observacionesInternas;
  final String? accionesRealizadas;
  final String estadoCorreo;
  final String? errorCorreo;
  final String fechaCreacion;
  final String fechaActualizacion;
  final int totalArchivos;

  const Denuncia({
    required this.id,
    required this.radicado,
    this.idUsuario,
    this.esAnonimo = false,
    this.nombreReportante,
    this.documentoReportante,
    this.correoReportante,
    this.telefonoReportante,
    this.ciudadReportante,
    this.barrioReportante,
    required this.tipoReporte,
    required this.tipoAnimal,
    required this.ubicacionAnimal,
    required this.ciudadCaso,
    required this.fechaSituacion,
    this.peligroInmediato = 'no',
    required this.descripcionCaso,
    this.caracteristicasAnimal,
    this.estadoSalud,
    this.heridasVisibles,
    this.condicionesAlimentacion,
    this.condicionesLugar,
    this.comportamientoAnimal,
    this.dificultadMovilidad,
    this.observacionesAdicionales,
    this.aceptoPolitica = true,
    this.versionPolitica,
    this.fechaAutorizacion,
    this.estado = 'recibido',
    this.leidoAdmin = false,
    this.observacionesInternas,
    this.accionesRealizadas,
    this.estadoCorreo = 'pendiente',
    this.errorCorreo,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    this.totalArchivos = 0,
  });

  bool get esPeligroInmediato => peligroInmediato.toLowerCase() == 'si';

  String get estadoFormateado {
    switch (estado.toLowerCase()) {
      case 'recibido':
        return 'Recibido';
      case 'en_revision':
        return 'En revisión';
      case 'en_gestion':
        return 'En gestión';
      case 'derivado':
        return 'Derivado a otra entidad';
      case 'atendido':
        return 'Atendido';
      case 'cerrado':
        return 'Cerrado';
      default:
        return estado;
    }
  }

  factory Denuncia.fromJson(Map<String, dynamic> json) {
    return Denuncia(
      id: json['id_denuncia']?.toString() ?? '',
      radicado: json['radicado']?.toString() ?? '',
      idUsuario: json['id_usuario']?.toString(),
      esAnonimo: json['es_anonimo'] == true,
      nombreReportante: json['nombre_reportante']?.toString(),
      documentoReportante: json['documento_reportante']?.toString(),
      correoReportante: json['correo_reportante']?.toString(),
      telefonoReportante: json['telefono_reportante']?.toString(),
      ciudadReportante: json['ciudad_reportante']?.toString(),
      barrioReportante: json['barrio_reportante']?.toString(),
      tipoReporte: json['tipo_reporte']?.toString() ?? '',
      tipoAnimal: json['tipo_animal']?.toString() ?? '',
      ubicacionAnimal: json['ubicacion_animal']?.toString() ?? '',
      ciudadCaso: json['ciudad_caso']?.toString() ?? '',
      fechaSituacion: json['fecha_situacion']?.toString() ?? '',
      peligroInmediato: json['peligro_inmediato']?.toString() ?? 'no',
      descripcionCaso: json['descripcion_caso']?.toString() ?? '',
      caracteristicasAnimal: json['caracteristicas_animal']?.toString(),
      estadoSalud: json['estado_salud']?.toString(),
      heridasVisibles: json['heridas_visibles']?.toString(),
      condicionesAlimentacion: json['condiciones_alimentacion']?.toString(),
      condicionesLugar: json['condiciones_lugar']?.toString(),
      comportamientoAnimal: json['comportamiento_animal']?.toString(),
      dificultadMovilidad: json['dificultad_movilidad']?.toString(),
      observacionesAdicionales: json['observaciones_adicionales']?.toString(),
      aceptoPolitica: json['acepto_politica'] == true,
      versionPolitica: json['version_politica']?.toString(),
      fechaAutorizacion: json['fecha_autorizacion']?.toString(),
      estado: json['estado']?.toString() ?? 'recibido',
      leidoAdmin: json['leido_admin'] == true,
      observacionesInternas: json['observaciones_internas']?.toString(),
      accionesRealizadas: json['acciones_realizadas']?.toString(),
      estadoCorreo: json['estado_correo']?.toString() ?? 'pendiente',
      errorCorreo: json['error_correo']?.toString(),
      fechaCreacion: json['fecha_creacion']?.toString() ?? '',
      fechaActualizacion: json['fecha_actualizacion']?.toString() ?? '',
      totalArchivos: int.tryParse(json['total_archivos']?.toString() ?? '0') ?? 0,
    );
  }
}

class DenunciaArchivo {
  final String id;
  final String idDenuncia;
  final String nombreOriginal;
  final String nombreGuardado;
  final String? tipoMime;
  final int tamanoBytes;
  final bool esVideo;
  final String fechaSubida;

  const DenunciaArchivo({
    required this.id,
    required this.idDenuncia,
    required this.nombreOriginal,
    required this.nombreGuardado,
    this.tipoMime,
    this.tamanoBytes = 0,
    this.esVideo = false,
    required this.fechaSubida,
  });

  factory DenunciaArchivo.fromJson(Map<String, dynamic> json) {
    return DenunciaArchivo(
      id: json['id_archivo']?.toString() ?? '',
      idDenuncia: json['id_denuncia']?.toString() ?? '',
      nombreOriginal: json['nombre_original']?.toString() ?? '',
      nombreGuardado: json['nombre_guardado']?.toString() ?? '',
      tipoMime: json['tipo_mime']?.toString(),
      tamanoBytes: int.tryParse(json['tamano_bytes']?.toString() ?? '0') ?? 0,
      esVideo: json['es_video'] == true,
      fechaSubida: json['fecha_subida']?.toString() ?? '',
    );
  }
}

class DenunciaHistorial {
  final String id;
  final String? nombreAdmin;
  final String? estadoAnterior;
  final String estadoNuevo;
  final String? observacion;
  final String fecha;

  const DenunciaHistorial({
    required this.id,
    this.nombreAdmin,
    this.estadoAnterior,
    required this.estadoNuevo,
    this.observacion,
    required this.fecha,
  });

  factory DenunciaHistorial.fromJson(Map<String, dynamic> json) {
    return DenunciaHistorial(
      id: json['id_historial']?.toString() ?? '',
      nombreAdmin: json['nombre_admin']?.toString(),
      estadoAnterior: json['estado_anterior']?.toString(),
      estadoNuevo: json['estado_nuevo']?.toString() ?? '',
      observacion: json['observacion']?.toString(),
      fecha: json['fecha']?.toString() ?? '',
    );
  }
}

class DenunciaDetalle {
  final Denuncia denuncia;
  final List<DenunciaArchivo> archivos;
  final List<DenunciaHistorial> historial;

  const DenunciaDetalle({
    required this.denuncia,
    required this.archivos,
    required this.historial,
  });

  factory DenunciaDetalle.fromJson(Map<String, dynamic> json) {
    final d = Denuncia.fromJson(json);
    final List listArchivos = (json['archivos'] as List?) ?? [];
    final List listHistorial = (json['historial'] as List?) ?? [];

    return DenunciaDetalle(
      denuncia: d,
      archivos: listArchivos.map((a) => DenunciaArchivo.fromJson(a as Map<String, dynamic>)).toList(),
      historial: listHistorial.map((h) => DenunciaHistorial.fromJson(h as Map<String, dynamic>)).toList(),
    );
  }
}
