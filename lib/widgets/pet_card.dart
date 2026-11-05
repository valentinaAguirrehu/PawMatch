import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/rasgos.dart';
import '../models/pet.dart';
import '../services/api_service.dart';
import '../services/session.dart';

/// En la BD la foto se guarda como ruta relativa (/uploads/mascotas/x.jpg).
/// Aquí se le antepone el servidor (así funciona en emulador, celular y web).
String urlFoto(String ruta) {
  if (ruta.startsWith('http')) return ruta;
  final host = ApiService.baseUrl.replaceFirst(RegExp(r'/api$'), '');
  return '$host$ruta';
}

/// Foto de la mascota con un ícono de respaldo si no hay foto o falla la carga.
/// Por defecto usa `BoxFit.contain` y centrado sobre fondo rosa pastel / blanco
/// para que la mascota se vea completa sin recortar cabeza, cuerpo ni patas.
/// Incluye caché en memoria para que las fotos recién subidas se muestren al instante.
class PetImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final Color backgroundColor;

  /// Caché en memoria de fotografías recién subidas para visualización inmediata (0 ms)
  /// y evitar descargar varias veces la misma imagen.
  static final Map<String, Uint8List> _cacheMemoria = <String, Uint8List>{};

  static String _claveNormalizada(String ruta) {
    final limpia = ruta.trim();
    if (limpia.isEmpty) return '';
    return urlFoto(limpia);
  }

  /// Guarda los bytes de una foto recién subida asociada a su ruta en el servidor.
  static void guardarEnCacheMemoria(String? ruta, Uint8List bytes) {
    if (ruta == null || ruta.trim().isEmpty || bytes.isEmpty) return;
    final clave = _claveNormalizada(ruta);
    if (clave.isEmpty) return;
    if (_cacheMemoria.length > 60) {
      _cacheMemoria.remove(_cacheMemoria.keys.first);
    }
    _cacheMemoria[clave] = bytes;
    _cacheMemoria[ruta.trim()] = bytes;
  }

  static Uint8List? obtenerDeCacheMemoria(String? ruta) {
    if (ruta == null || ruta.trim().isEmpty) return null;
    return _cacheMemoria[ruta.trim()] ??
        _cacheMemoria[_claveNormalizada(ruta)];
  }

  const PetImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.backgroundColor = const Color(0xFFFFF5FA),
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.rosaSuave,
      child: const Center(
        child: Icon(
          Icons.pets_rounded,
          size: 36,
          color: AppColors.rosa,
        ),
      ),
    );
    if (url == null || url!.isEmpty) return placeholder;

    final enMemoria = obtenerDeCacheMemoria(url);
    if (enMemoria != null) {
      return Container(
        color: backgroundColor,
        alignment: Alignment.center,
        child: Image.memory(
          enMemoria,
          fit: fit,
          alignment: Alignment.center,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => placeholder,
        ),
      );
    }

    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Image.network(
        urlFoto(url!),
        fit: fit,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.rosa,
                ),
              ),
      ),
    );
  }
}

/// Etiqueta con el estado de adopción (solo rosado y blanco).
class EstadoChip extends StatelessWidget {
  final String estado;
  const EstadoChip({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (Color letra, Color fondo) = switch (estado) {
      'disponible' => (Colors.white, AppColors.rosa),
      'en_proceso' => (AppColors.rosa, AppColors.rosaClaro),
      _ => (AppColors.texto.withValues(alpha: 0.6), AppColors.rosaSuave),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiquetaEstadoAdopcion(estado),
        style: TextStyle(
          color: letra,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Tarjeta de mascota con distribución vertical:
/// - Fotografía en la parte superior ocupando todo el ancho de la tarjeta (`BoxFit.contain`).
/// - Insignia «NUEVO» en la esquina superior izquierda de la fotografía (visible durante 48h reales).
/// - Insignia de porcentaje de Match en la esquina superior derecha de la fotografía
///   (rosado intenso para la mayor compatibilidad, rosado suave para las demás).
/// - Debajo de la fotografía: Nombre + sexo, Edad + tamaño, Personalidad (o etiqueta en proceso)
///   y botón «Ver perfil >» en la parte inferior.
class PetCard extends StatelessWidget {
  final Pet pet;
  final VoidCallback onTap;
  final double? porcentajeMatch;
  final bool esMejorMatch;
  final bool esMatchInicial;
  final bool esFavorito;
  final VoidCallback? onToggleFavorito;
  final bool ocultarMatch;

  const PetCard({
    super.key,
    required this.pet,
    required this.onTap,
    this.porcentajeMatch,
    this.esMejorMatch = false,
    this.esMatchInicial = false,
    this.esFavorito = false,
    this.onToggleFavorito,
    this.ocultarMatch = false,
  });

  /// Verifica si la mascota realmente tiene personalidad registrada en la base de datos.
  bool get _tienePersonalidadRegistrada {
    if (!pet.personalidadDefinida) return false;
    if (pet.personalidad.isEmpty) return false;
    for (final r in rasgosMascota) {
      final v = pet.personalidad[r.clave];
      if (v is num && v >= 1 && v <= 5) return true;
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null && parsed >= 1 && parsed <= 5) return true;
      }
    }
    return false;
  }

  /// Construye el resumen real de personalidad o descripción sin inventar datos.
  String _textoPersonalidadReal() {
    final desc = (pet.descripcion ?? '').trim();
    if (desc.isNotEmpty) return desc;

    final frases = <String>[];
    for (final r in rasgosMascota) {
      final raw = pet.personalidad[r.clave];
      final int? val = raw is int
          ? raw
          : (raw is num ? raw.round() : int.tryParse(raw?.toString() ?? ''));
      if (val == null) continue;
      if (val >= 4) {
        frases.add(r.maximoPara(pet.sexo));
      } else if (val <= 2) {
        frases.add(r.minimoPara(pet.sexo));
      }
      if (frases.length >= 2) break;
    }
    if (frases.isNotEmpty) {
      return '${frases.join(' • ')}.';
    }
    return 'Personalidad equilibrada y cariñosa.';
  }

  String _textoEdadTarjeta(bool tienePersonalidad, {required bool esAdmin}) {
    if (esAdmin) {
      if (pet.edad == null && pet.fechaNacimiento == null) {
        return pet.esCachorro ? 'Cachorro' : 'Sin edad';
      }
      return pet.edadTexto;
    }
    if (!tienePersonalidad && pet.edad == null && pet.fechaNacimiento == null) {
      return pet.esCachorro ? 'Bebé' : 'En proceso';
    }
    if (!tienePersonalidad && pet.esCachorro) {
      return 'Bebé';
    }
    if (pet.edad == null && pet.fechaNacimiento == null) {
      return 'En proceso';
    }
    return pet.edadTexto;
  }

  String _textoTamano() {
    final t = (pet.tamano ?? '').trim();
    if (t.isEmpty) return 'Mediano';
    return t[0].toUpperCase() + t.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final tienePersonalidad = _tienePersonalidadRegistrada;
    final sexoRaw = (pet.sexo ?? '').trim().toLowerCase();
    final esMacho = sexoRaw.startsWith('m');
    final esHembra = sexoRaw.startsWith('h');
    final esVistaAdmin = ocultarMatch || Session.esAdmin;
    final destacada = !esVistaAdmin && (esMejorMatch || esMatchInicial);

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 175.0;
        final compacto = ancho < 185;
        final muyCompacto = ancho < 155;
        final pad = muyCompacto ? 8.5 : (compacto ? 10.0 : 12.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: destacada
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFD8EB),
                          Color(0xFFFFEAF4),
                          Color(0xFFFFF4F9),
                        ],
                      )
                    : null,
                color: destacada ? null : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: destacada
                      ? AppColors.rosa
                      : const Color(0xFFF8C6DC),
                  width: destacada ? 2.0 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rosa.withValues(
                      alpha: destacada ? 0.22 : 0.08,
                    ),
                    blurRadius: destacada ? 16 : 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Fotografía en la parte superior ocupando todo el ancho de la tarjeta
                        Expanded(
                          flex: 52,
                          child: Container(
                            decoration: BoxDecoration(
                              color: destacada
                                  ? Colors.white.withValues(alpha: 0.94)
                                  : const Color(0xFFFFF5FA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: destacada
                                    ? AppColors.rosa.withValues(alpha: 0.40)
                                    : const Color(0xFFFCE4EF),
                                width: 1.2,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Imagen completa centrada con object-fit: contain
                                Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: PetImage(
                                    url: pet.foto,
                                    fit: BoxFit.contain,
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),

                                // Esquina superior izquierda: Insignia «NUEVO» (visible durante 48 horas reales)
                                if (pet.esNuevo)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: _InsigniaNuevo(compacto: compacto),
                                  ),

                                // Esquina superior derecha:
                                // - Usuario: Porcentaje real de Match
                                // - Administrador: Estado administrativo (Disponible, En proceso, Apadrinada, Adoptada)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: ancho * (pet.esNuevo ? 0.54 : 0.78),
                                    ),
                                    child: esVistaAdmin
                                        ? _InsigniaEstadoAdmin(
                                            pet: pet,
                                            compacto: compacto,
                                          )
                                        : _InsigniaMatch(
                                            porcentaje: porcentajeMatch,
                                            esMejorMatch: esMejorMatch,
                                            esMatchInicial: esMatchInicial,
                                            compacto: compacto,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: muyCompacto ? 6 : 8),

                        // 2. Debajo de la fotografía: Nombre completo + Sexo
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  pet.nombre,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: muyCompacto
                                        ? 15.0
                                        : (compacto ? 16.0 : 17.0),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1F2937),
                                    height: 1.15,
                                  ),
                                ),
                                if (esMacho || esHembra) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    esMacho
                                        ? Icons.male_rounded
                                        : Icons.female_rounded,
                                    size: muyCompacto ? 16 : 18,
                                    color: esMacho
                                        ? const Color(0xFF3B82F6)
                                        : AppColors.rosa,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: muyCompacto ? 4 : 5),

                        // 3. Edad y Tamaño
                        Row(
                          children: [
                            Icon(
                              Icons.pets_rounded,
                              size: muyCompacto ? 12 : 13.5,
                              color: AppColors.rosa,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _textoEdadTarjeta(
                                  tienePersonalidad,
                                  esAdmin: esVistaAdmin,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: muyCompacto ? 11.0 : 12.0,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4B5563),
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Transform.rotate(
                              angle: -0.6,
                              child: Icon(
                                Icons.local_offer_outlined,
                                size: muyCompacto ? 12 : 13.5,
                                color: AppColors.rosa,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                _textoTamano(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: muyCompacto ? 11.0 : 12.0,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4B5563),
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: muyCompacto ? 5 : 6),

                        // 4. Personalidad cuando esté registrada o etiqueta en proceso
                        SizedBox(
                          height: muyCompacto ? 40 : 44,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: tienePersonalidad
                                ? Text(
                                    _textoPersonalidadReal(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: muyCompacto ? 10.5 : 11.5,
                                      height: 1.25,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF4B5563),
                                    ),
                                  )
                                : _EtiquetaSinPersonalidad(
                                    esCachorro: pet.esCachorro,
                                    muyCompacto: muyCompacto,
                                  ),
                          ),
                        ),

                        // 5. Botón «Ver perfil >» en la parte inferior
                        SizedBox(height: muyCompacto ? 6 : 8),
                        _botonVerPerfil(muyCompacto: muyCompacto),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Destellos decorativos en la esquina superior derecha para el Mejor Match (#1)
            if (!esVistaAdmin && esMejorMatch)
              const Positioned(
                top: -6,
                right: -4,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CustomPaint(painter: _DestellosMejorMatchPainter()),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _botonVerPerfil({required bool muyCompacto}) {
    if (pet.estaAdoptada) {
      final esMia = pet.adoptadaPor(Session.idUsuario);
      return Container(
        height: muyCompacto ? 30 : 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.rosaClaro,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.bordeRosa),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              esMia ? Icons.favorite_rounded : Icons.home_rounded,
              size: 13,
              color: AppColors.rosa,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                esMia ? 'En tu familia · Ver perfil' : 'Adoptado · Ver perfil',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.rosa,
                  fontWeight: FontWeight.w800,
                  fontSize: muyCompacto ? 10.5 : 11.5,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: AppColors.rosa,
            ),
          ],
        ),
      );
    }

    return Container(
      height: muyCompacto ? 31 : 35,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFFF6FB3),
            AppColors.rosa,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ver perfil',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: muyCompacto ? 11.8 : 12.8,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
            size: muyCompacto ? 16 : 18,
          ),
        ],
      ),
    );
  }
}

/// Insignia «NUEVO» en la esquina superior izquierda de la fotografía
/// (visible únicamente durante las primeras 48 horas desde su creación en la BD).
class _InsigniaNuevo extends StatelessWidget {
  final bool compacto;

  const _InsigniaNuevo({required this.compacto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 7 : 9,
        vertical: compacto ? 3.5 : 4.5,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF4D94),
            Color(0xFFED4F9D),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: compacto ? 10 : 11.5,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            'NUEVO',
            style: TextStyle(
              fontSize: compacto ? 9.5 : 10.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Insignia superior derecha de porcentaje de compatibilidad (Match):
/// - La mascota con mayor compatibilidad tiene una insignia rosada más intensa.
/// - Las demás tienen insignias rosadas suaves.
class _InsigniaMatch extends StatelessWidget {
  final double? porcentaje;
  final bool esMejorMatch;
  final bool esMatchInicial;
  final bool compacto;

  const _InsigniaMatch({
    required this.porcentaje,
    required this.esMejorMatch,
    this.esMatchInicial = false,
    required this.compacto,
  });

  @override
  Widget build(BuildContext context) {
    final tieneValor = porcentaje != null;
    final valorEntero = porcentaje?.round().clamp(0, 100) ?? 0;
    final intensa = esMejorMatch || esMatchInicial;

    final Color fondo = intensa
        ? AppColors.rosa
        : const Color(0xFFFFDCEB).withValues(alpha: 0.96);
    final Color borde = intensa
        ? Colors.white
        : const Color(0xFFF8BBD6);
    final Color colorTexto = intensa
        ? Colors.white
        : const Color(0xFFBE185D);
    final Color colorIcono = intensa
        ? Colors.white
        : AppColors.rosa;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 7.5 : 9.5,
        vertical: compacto ? 3.5 : 4.5,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borde, width: intensa ? 1.4 : 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: intensa ? 0.30 : 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tieneValor ? Icons.favorite_rounded : Icons.auto_awesome_outlined,
              size: compacto ? 11 : 12.5,
              color: colorIcono,
            ),
            const SizedBox(width: 3.5),
            Text(
              tieneValor ? '$valorEntero% Match' : 'Compatibilidad en proceso',
              maxLines: 1,
              style: TextStyle(
                fontSize: tieneValor
                    ? (compacto ? 10.5 : 11.5)
                    : (compacto ? 9.0 : 10.0),
                fontWeight: FontWeight.w800,
                color: colorTexto,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Insignia administrativa mostrada únicamente cuando ingresa un ADMINISTRADOR:
/// muestra el estado administrativo real de la mascota (Disponible, En proceso,
/// Apadrinada o Adoptada) en lugar de porcentajes o etiquetas de Match.
class _InsigniaEstadoAdmin extends StatelessWidget {
  final Pet pet;
  final bool compacto;

  const _InsigniaEstadoAdmin({
    required this.pet,
    required this.compacto,
  });

  @override
  Widget build(BuildContext context) {
    final String etiqueta;
    final IconData icono;
    final Color fondo;
    final Color borde;
    final Color colorTexto;

    if (pet.estaAdoptada) {
      etiqueta = 'Adoptada';
      icono = Icons.home_rounded;
      fondo = const Color(0xFFDCFCE7);
      borde = const Color(0xFF86EFAC);
      colorTexto = const Color(0xFF166534);
    } else if (pet.estadoAdopcion.trim().toLowerCase() == 'en_proceso') {
      etiqueta = 'En proceso';
      icono = Icons.hourglass_top_rounded;
      fondo = const Color(0xFFFEF3C7);
      borde = const Color(0xFFFCD34D);
      colorTexto = const Color(0xFF92400E);
    } else if (pet.estaApadrinada) {
      etiqueta = 'Apadrinada';
      icono = Icons.volunteer_activism_rounded;
      fondo = const Color(0xFFFFDCEB);
      borde = const Color(0xFFF8BBD6);
      colorTexto = const Color(0xFF9D174D);
    } else {
      etiqueta = 'Disponible';
      icono = Icons.check_circle_rounded;
      fondo = AppColors.rosa;
      borde = Colors.white;
      colorTexto = Colors.white;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 7.5 : 9.5,
        vertical: compacto ? 3.5 : 4.5,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borde, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: compacto ? 11 : 12.5,
              color: colorTexto,
            ),
            const SizedBox(width: 3.5),
            Text(
              etiqueta,
              maxLines: 1,
              style: TextStyle(
                fontSize: compacto ? 10.2 : 11.2,
                fontWeight: FontWeight.w800,
                color: colorTexto,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta visual inferior cuando la mascota aún no tiene personalidad registrada:
/// - Cachorro: «Bebé en proceso» (Aún no tiene personalidad definida.)
/// - Otra mascota: «Mascota en proceso de encontrar personalidad»
class _EtiquetaSinPersonalidad extends StatelessWidget {
  final bool esCachorro;
  final bool muyCompacto;

  const _EtiquetaSinPersonalidad({
    required this.esCachorro,
    required this.muyCompacto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: muyCompacto ? 7 : 9,
        vertical: muyCompacto ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDCEB).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF9B8D4),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (esCachorro)
            SizedBox(
              width: muyCompacto ? 17 : 20,
              height: muyCompacto ? 17 : 20,
              child: const CustomPaint(painter: _BiberonPainter()),
            )
          else
            Icon(
              Icons.pets_rounded,
              size: muyCompacto ? 16 : 18,
              color: AppColors.rosa,
            ),
          SizedBox(width: muyCompacto ? 6 : 7),
          Expanded(
            child: esCachorro
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bebé en proceso',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: muyCompacto ? 9.8 : 10.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F2937),
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Aún no tiene personalidad definida.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: muyCompacto ? 8.6 : 9.3,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4B5563),
                          height: 1.12,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Mascota en proceso de encontrar personalidad',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: muyCompacto ? 9.2 : 10.0,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF374151),
                      height: 1.15,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Dibuja los 3 destellos rosados en la esquina superior derecha del Mejor Match.
class _DestellosMejorMatchPainter extends CustomPainter {
  const _DestellosMejorMatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.rosa
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.55),
      Offset(size.width * 0.15, size.height * 0.10),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.48, size.height * 0.65),
      Offset(size.width * 0.78, size.height * 0.18),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.58, size.height * 0.82),
      Offset(size.width * 0.95, size.height * 0.58),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dibuja el ícono de biberón rosado (idéntico al diseño de «Bebé en proceso»).
class _BiberonPainter extends CustomPainter {
  const _BiberonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(0.55);
    canvas.translate(-size.width / 2, -size.height / 2);

    final w = size.width;
    final h = size.height;

    final relleno = Paint()
      ..color = AppColors.rosa.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final trazo = Paint()
      ..color = AppColors.rosa
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.28, h * 0.36, w * 0.44, h * 0.52),
      Radius.circular(w * 0.10),
    );
    canvas.drawRRect(cuerpo, relleno);
    canvas.drawRRect(cuerpo, trazo);

    final anillo = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.24, h * 0.27, w * 0.52, h * 0.10),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(anillo, Paint()..color = AppColors.rosa);

    final tetina = Path()
      ..moveTo(w * 0.38, h * 0.27)
      ..quadraticBezierTo(w * 0.38, h * 0.10, w * 0.50, h * 0.10)
      ..quadraticBezierTo(w * 0.62, h * 0.10, w * 0.62, h * 0.27);
    canvas.drawPath(tetina, trazo);

    canvas.drawLine(
      Offset(w * 0.38, h * 0.52),
      Offset(w * 0.50, h * 0.52),
      trazo,
    );
    canvas.drawLine(
      Offset(w * 0.38, h * 0.66),
      Offset(w * 0.54, h * 0.66),
      trazo,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
