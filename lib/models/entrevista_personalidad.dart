/// Pregunta real del formulario de personalidad, servida por el backend.
class PreguntaEntrevista {
  final int orden;
  final String id;
  final String titulo;
  final String pregunta;
  final String minimo;
  final String maximo;

  const PreguntaEntrevista({
    required this.orden,
    required this.id,
    required this.titulo,
    required this.pregunta,
    required this.minimo,
    required this.maximo,
  });

  factory PreguntaEntrevista.fromJson(Map<String, dynamic> json) {
    final id = (json['pregunta_id'] ?? '').toString().trim();
    final titulo = (json['titulo'] ?? '').toString().trim();
    final pregunta = (json['pregunta'] ?? '').toString().trim();
    final minimo = (json['minimo'] ?? '').toString().trim();
    final maximo = (json['maximo'] ?? '').toString().trim();
    final ordenRaw = json['orden'];
    final orden = ordenRaw is int ? ordenRaw : int.tryParse('$ordenRaw') ?? 0;
    if (id.isEmpty ||
        titulo.isEmpty ||
        pregunta.isEmpty ||
        minimo.isEmpty ||
        maximo.isEmpty) {
      throw const FormatException('pregunta');
    }
    return PreguntaEntrevista(
      orden: orden,
      id: id,
      titulo: titulo,
      pregunta: pregunta,
      minimo: minimo,
      maximo: maximo,
    );
  }
}

/// Respuesta ya interpretada. La puntuación solo existe si el asistente la asignó.
class RespuestaEntrevista {
  final String clave;
  final String respuestaOriginal;
  final int puntuacion;
  final String justificacion;
  final String mensaje;

  const RespuestaEntrevista({
    required this.clave,
    required this.respuestaOriginal,
    required this.puntuacion,
    required this.justificacion,
    required this.mensaje,
  });

  bool coincideCon(RespuestaEntrevista otra) {
    return clave == otra.clave &&
        puntuacion == otra.puntuacion &&
        respuestaOriginal == otra.respuestaOriginal;
  }

  RespuestaEntrevista conMensaje(String texto) {
    final limpio = texto.trim();
    return RespuestaEntrevista(
      clave: clave,
      respuestaOriginal: respuestaOriginal,
      puntuacion: puntuacion,
      justificacion: justificacion,
      mensaje: limpio.isEmpty ? mensaje : limpio,
    );
  }

  Map<String, dynamic> toJson() => {
        'clave': clave,
        'respuesta_original': respuestaOriginal,
        'puntuacion': puntuacion,
        'justificacion': justificacion,
        'mensaje': mensaje,
      };

  factory RespuestaEntrevista.fromJson(Map<String, dynamic> json) {
    final clave = (json['clave'] ?? json['pregunta_id'] ?? '').toString().trim();
    final texto = (json['respuesta_original'] ?? '').toString().trim();
    final notaRaw = json['puntuacion'];
    final puntuacion = notaRaw is int ? notaRaw : int.tryParse('$notaRaw');
    final justificacion = (json['justificacion'] ?? '').toString().trim();
    final mensaje = (json['mensaje'] ?? justificacion).toString().trim();
    if (clave.isEmpty ||
        texto.length < 2 ||
        puntuacion == null ||
        puntuacion < 1 ||
        puntuacion > 5 ||
        justificacion.length < 3) {
      throw const FormatException('respuesta');
    }
    return RespuestaEntrevista(
      clave: clave,
      respuestaOriginal: texto,
      puntuacion: puntuacion,
      justificacion: justificacion,
      mensaje: mensaje.isEmpty ? justificacion : mensaje,
    );
  }
}

/// Lo que devolvió el asistente. Si hace falta aclarar, no hay puntuación.
class InterpretacionEntrevista {
  final String preguntaId;
  final String respuestaOriginal;
  final int? puntuacion;
  final String? justificacion;
  final bool necesitaAclaracion;
  final String mensaje;

  const InterpretacionEntrevista({
    required this.preguntaId,
    required this.respuestaOriginal,
    required this.puntuacion,
    required this.justificacion,
    required this.necesitaAclaracion,
    required this.mensaje,
  });

  bool get lista {
    final nota = puntuacion;
    final porque = justificacion?.trim() ?? '';
    return !necesitaAclaracion &&
        nota != null &&
        nota >= 1 &&
        nota <= 5 &&
        porque.length >= 3 &&
        mensaje.trim().length >= 2;
  }

  factory InterpretacionEntrevista.fromJson(Map<String, dynamic> json) {
    final necesita = json['necesita_aclaracion'] == true;
    final notaRaw = json['puntuacion'];
    final nota = notaRaw is int ? notaRaw : int.tryParse('${notaRaw ?? ''}');
    return InterpretacionEntrevista(
      preguntaId: (json['pregunta_id'] ?? '').toString(),
      respuestaOriginal: (json['respuesta_original'] ?? '').toString(),
      puntuacion: necesita ? null : nota,
      justificacion: necesita ? null : json['justificacion']?.toString(),
      necesitaAclaracion: necesita,
      mensaje: (json['mensaje'] ?? '').toString().trim(),
    );
  }
}

class TurnoEntrevista {
  final String rol;
  final String texto;

  const TurnoEntrevista({required this.rol, required this.texto});

  Map<String, dynamic> toJson() => {'rol': rol, 'texto': texto};

  factory TurnoEntrevista.fromJson(Map<String, dynamic> json) {
    final rol = json['rol'] == 'asistente' ? 'asistente' : 'usuario';
    return TurnoEntrevista(
      rol: rol,
      texto: (json['texto'] ?? '').toString(),
    );
  }
}

/// Progreso local de la conversación. Las puntuaciones definitivas viven en el servidor.
class BorradorEntrevista {
  final List<RespuestaEntrevista> confirmadas;
  final RespuestaEntrevista? pendiente;
  final String claveActual;
  final String borradorTexto;
  final List<TurnoEntrevista> turnos;

  const BorradorEntrevista({
    required this.confirmadas,
    required this.pendiente,
    required this.claveActual,
    required this.borradorTexto,
    required this.turnos,
  });

  Map<String, dynamic> toJson() => {
        'confirmadas': confirmadas.map((r) => r.toJson()).toList(),
        'pendiente': pendiente?.toJson(),
        'clave_actual': claveActual,
        'borrador_texto': borradorTexto,
        'turnos': turnos.map((t) => t.toJson()).toList(),
      };

  factory BorradorEntrevista.fromJson(Map<String, dynamic> json) {
    List<RespuestaEntrevista> leerLista(dynamic raw) {
      if (raw is! List) return [];
      final lista = <RespuestaEntrevista>[];
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          lista.add(RespuestaEntrevista.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {}
      }
      return lista;
    }

    RespuestaEntrevista? pendiente;
    final crudo = json['pendiente'];
    if (crudo is Map) {
      try {
        pendiente = RespuestaEntrevista.fromJson(Map<String, dynamic>.from(crudo));
      } catch (_) {
        pendiente = null;
      }
    }

    final turnos = <TurnoEntrevista>[];
    final crudos = json['turnos'];
    if (crudos is List) {
      for (final item in crudos) {
        if (item is! Map) continue;
        final turno = TurnoEntrevista.fromJson(Map<String, dynamic>.from(item));
        if (turno.texto.trim().isNotEmpty) turnos.add(turno);
      }
    }

    return BorradorEntrevista(
      confirmadas: leerLista(json['confirmadas']),
      pendiente: pendiente,
      claveActual: (json['clave_actual'] ?? '').toString(),
      borradorTexto: (json['borrador_texto'] ?? '').toString(),
      turnos: turnos,
    );
  }
}
