import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/enlaces.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/adoption/adoption_form_screen.dart';
import 'package:paw_match/screens/adoption/validacion_perfil_adopcion.dart';
import 'package:paw_match/screens/apadrinamiento/solicitud_apadrinamiento_dialog.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/dato_detalle.dart';
import 'package:paw_match/widgets/pet_card.dart'; // PetImage
import 'package:paw_match/widgets/tarjeta_blanca.dart';

/// Detalle de una mascota: foto circular, datos, descripción,
/// personalidad y los botones Adoptar / Apadrinar.
class PetDetailScreen extends StatefulWidget {
  final Pet pet;
  final VoidCallback? onAdoptar, onApadrinar;
  const PetDetailScreen({
    super.key,
    required this.pet,
    this.onAdoptar,
    this.onApadrinar,
  });

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  // La personalidad vive en otra tabla: se consulta la mascota completa.
  late Future<Pet> _completa = PetsService.obtener(widget.pet.id);
  SolicitudApadrinamiento? _miSolicitud;
  AdoptionRequest? _miAdopcion;

  @override
  void initState() {
    super.initState();
    _consultarMiSolicitud();
    _consultarMiAdopcion();
  }

  Future<void> _consultarMiSolicitud() async {
    if (Session.idUsuario == null) return;
    try {
      final lista = await ApadrinamientoService.listarMisSolicitudes(idMascota: widget.pet.id);
      if (mounted) {
        setState(() {
          _miSolicitud = lista.isNotEmpty ? lista.first : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _consultarMiAdopcion() async {
    if (Session.idUsuario == null) return;
    try {
      final lista = await AdoptionService.listMine(petId: widget.pet.id);
      if (!mounted) return;
      setState(() => _miAdopcion = lista.isEmpty ? null : lista.first);
    } catch (_) {}
  }

  Future<void> _abrirFormularioAdopcion() async {
    final listo = await perfilListoParaAdoptar(context);
    if (!listo || !mounted) return;
    final enviada = await AdoptionFormScreen.mostrar(context, pet: widget.pet);
    if (enviada == true && mounted) _consultarMiAdopcion();
  }

  void _verEstadoAdopcion() {
    final s = _miAdopcion;
    if (s == null) return;

    if (s.isApproved) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.verified, color: Colors.green, size: 48),
          title: Text('¡Adopción de ${widget.pet.nombre} aprobada!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📅 Fecha oficial de inicio: ${s.adoptionStartDateLabel ?? 'Activo'}',
              ),
              const SizedBox(height: 8),
              const Text(
                'La fundación aprobó tu solicitud. Coordina la entrega por el WhatsApp oficial.',
              ),
              if (s.hasObservations) ...[
                const SizedBox(height: 10),
                const Text(
                  'Observaciones de la fundación:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(s.observations!),
              ],
            ],
          ),
          actions: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              icon: const Icon(Icons.chat),
              label: const Text('Contactar por WhatsApp'),
              onPressed: () {
                Navigator.pop(ctx);
                final num = FundacionInfo.whatsappNumero.isNotEmpty
                    ? FundacionInfo.whatsappNumero
                    : '573136177747';
                final msg =
                    'Hola Fundación Maritza Arévalo, mi solicitud para adoptar a ${widget.pet.nombre} fue aprobada en Paw Match.';
                abrirEnlace(
                  context,
                  'https://wa.me/$num?text=${Uri.encodeComponent(msg)}',
                  nombre: 'WhatsApp',
                );
              },
            ),
          ],
        ),
      );
      return;
    }

    if (s.isPending) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.hourglass_top, color: Colors.orange, size: 48),
          title: const Text('Solicitud en revisión'),
          content: Text(
            s.petAdoptionStatus == 'adoptado'
                ? '${widget.pet.nombre} ya fue adoptado. La fundación aún debe cerrar tu solicitud.'
                : 'Tu solicitud para adoptar a ${widget.pet.nombre} fue enviada el ${s.requestedAtLabel}. Recibirás una notificación cuando sea revisada.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
          ],
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.info_outline, color: Colors.redAccent, size: 48),
        title: const Text('Solicitud rechazada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu solicitud anterior para adoptar a ${widget.pet.nombre} no fue aprobada.',
            ),
            const SizedBox(height: 10),
            const Text(
              'Motivo u observaciones:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(s.hasObservations ? s.observations! : 'No se especificó motivo.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          if (_puedeAdoptar)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: () {
                Navigator.pop(ctx);
                _abrirFormularioAdopcion();
              },
              child: const Text('Enviar nueva solicitud'),
            ),
        ],
      ),
    );
  }

  void _abrirFormularioApadrinar() {
    if (_estadoAdopcion == 'adoptado') return;
    SolicitudApadrinamientoDialog.mostrar(
      context,
      pet: widget.pet,
      onEnviadaExitosamente: _consultarMiSolicitud,
    );
  }

  Future<void> _verContrato(SolicitudApadrinamiento s) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await ApadrinamientoService.obtenerBytesContrato(s.id);
      if (!mounted) return;
      Navigator.pop(context);

      final esPdf = bytes.length >= 4 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46; // %PDF

      if (esPdf) {
        await Printing.layoutPdf(
          onLayout: (_) => bytes,
          name: 'Contrato_Apadrinamiento_${widget.pet.nombre}.pdf',
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text('Contrato de Apadrinamiento - ${widget.pet.nombre}'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al cargar contrato: $e'),
        ),
      );
    }
  }

  void _verEstadoSolicitud() {
    final s = _miSolicitud;
    if (s == null) return;

    if (s.esAprobada) {
      if (s.tieneContrato) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.stars, color: Colors.green, size: 48),
            title: Text('¡Eres Padrino Oficial de ${widget.pet.nombre}! 🎉'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📅 Fecha oficial de inicio: ${s.fechaInicioApadrinamiento ?? 'Activo'}'),
                const SizedBox(height: 8),
                const Text('Gracias por tu compromiso con la Fundación Maritza Arévalo.'),
                const SizedBox(height: 10),
                if (s.observaciones != null && s.observaciones!.trim().isNotEmpty) ...[
                  Text('Observaciones: ${s.observaciones}'),
                  const SizedBox(height: 10),
                ],
                const Text('Coordina directamente por el WhatsApp oficial de la fundación:'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                icon: const Icon(Icons.assignment_turned_in),
                label: const Text('Ver Contrato'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _verContrato(s);
                },
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                icon: const Icon(Icons.chat),
                label: const Text('WhatsApp'),
                onPressed: () {
                  Navigator.pop(ctx);
                  final num = FundacionInfo.whatsappNumero.isNotEmpty ? FundacionInfo.whatsappNumero : '573136177747';
                  final msg = 'Hola Fundación Maritza Arévalo, soy el padrino de ${widget.pet.nombre} y vengo de Paw Match.';
                  abrirEnlace(context, 'https://wa.me/$num?text=${Uri.encodeComponent(msg)}', nombre: 'WhatsApp');
                },
              ),
            ],
          ),
        );
      } else {
        // Aún no tiene contrato subido por el admin
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 48),
            title: const Text('¡Solicitud Aprobada! Falta 1 paso'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Tu solicitud para apadrinar a ${widget.pet.nombre} fue aprobada por la fundación!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.assignment_outlined, color: Colors.amber.shade900, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aún falta un paso: Debes esperar a que el administrador suba el contrato oficial de apadrinamiento firmado. Una vez lo suba, serás formalmente el padrino de ${widget.pet.nombre} y podrás consultarlo aquí.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.observaciones != null && s.observaciones!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Indicaciones de la fundación: ${s.observaciones}',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } else if (s.esCancelada) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 48),
          title: const Text('Apadrinamiento Cancelado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('El apadrinamiento para ${widget.pet.nombre} fue cancelado por la administración.'),
              const SizedBox(height: 10),
              const Text('Motivo de la cancelación:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  s.observaciones?.trim().isNotEmpty == true
                      ? s.observaciones!
                      : 'Sin motivo especificado.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: () {
                Navigator.pop(ctx);
                _abrirFormularioApadrinar();
              },
              child: const Text('Enviar Nueva Solicitud'),
            ),
          ],
        ),
      );
    } else if (s.esPendiente) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.hourglass_top, color: Colors.orange, size: 48),
          title: const Text('Solicitud en Revisión'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tu solicitud para apadrinar a ${widget.pet.nombre} fue enviada el ${s.fechaSolicitud}.'),
              const SizedBox(height: 10),
              const Text('Tu motivación registrada:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(s.motivacion, style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              const Text(
                'El administrador está evaluando tu solicitud y recibirás una notificación al ser aprobada.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
          ],
        ),
      );
    } else if (s.esRechazada) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.info_outline, color: Colors.redAccent, size: 48),
          title: const Text('Solicitud Rechazada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tu solicitud anterior para apadrinar a ${widget.pet.nombre} no fue aprobada.'),
              const SizedBox(height: 10),
              const Text('Motivo u observaciones:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(s.observaciones ?? 'No se especificó motivo.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: () {
                Navigator.pop(ctx);
                _abrirFormularioApadrinar();
              },
              child: const Text('Enviar Nueva Solicitud'),
            ),
          ],
        ),
      );
    }
  }

  static const _estados = {
    'disponible': 'Disponible',
    'en_proceso': 'En proceso',
    'adoptado': 'Adoptado',
  };

  String _t(String? v) => v?.trim() ?? '';

  String get _estadoAdopcion {
    final e = _t(widget.pet.estadoAdopcion);
    return e.isEmpty ? 'disponible' : e;
  }

  bool get _apadrinada => _t(widget.pet.estadoApadrinamiento) == 'apadrinado';
  bool get _puedeAdoptar => _estadoAdopcion == 'disponible';
  bool get _puedeApadrinar => !_apadrinada && _estadoAdopcion != 'adoptado';

  /// Fecha de ingreso a la Fundación. Lee `fechaIngreso` del modelo Pet si existe
  /// (DateTime o texto ISO); si el modelo aún no lo tiene, simplemente no se muestra.
  DateTime? get _fechaIngreso {
    try {
      final v = (widget.pet as dynamic).fechaIngreso;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
    } catch (_) {}
    return null;
  }

  /// PNG/WebP = foto sin fondo (recorte): se ve entera sobre el rosado.
  /// JPG = foto normal: llena el círculo, como un retrato.
  bool get _esRecorte {
    final f = _t(widget.pet.foto).toLowerCase();
    return f.endsWith('.png') || f.endsWith('.webp');
  }

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  List<DatoDetalle> get _datos {
    final p = widget.pet;
    final edad = p.edad;
    final fecha = _fechaIngreso;
    return [
      if (edad != null)
        DatoDetalle(
          icono: Icons.cake_outlined,
          etiqueta: 'Edad',
          valor: '$edad ${edad == 1 ? 'año' : 'años'}',
        ),
      if (_t(p.sexo).isNotEmpty)
        DatoDetalle(
          icono: Icons.pets, // huella en lugar del ícono hombre/mujer
          etiqueta: 'Sexo',
          valor: _t(p.sexo),
        ),
      if (_t(p.raza).isNotEmpty)
        DatoDetalle(
          icono: Icons.category_outlined,
          etiqueta: 'Raza',
          valor: _t(p.raza),
        ),
      if (_t(p.tamano).isNotEmpty)
        DatoDetalle(
          icono: Icons.straighten,
          etiqueta: 'Tamaño',
          valor: _t(p.tamano),
        ),
      DatoDetalle(
        icono: Icons.vaccines_outlined,
        etiqueta: 'Vacunas',
        valor: p.vacunas == true ? 'Al día' : 'Pendiente',
      ),
      DatoDetalle(
        icono: Icons.medical_services_outlined,
        etiqueta: 'Esterilizado',
        valor: p.esterilizado == true ? 'Sí' : 'No',
      ),
      if (fecha != null)
        DatoDetalle(
          icono: Icons.event_outlined,
          etiqueta: 'Ingreso',
          valor: _fecha(fecha),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pet;
    final t = Theme.of(context).textTheme;
    final descripcion = _t(p.descripcion);
    final subtitulo = [
      _t(p.especie),
      _t(p.raza),
    ].where((e) => e.isNotEmpty).join(' · ');

    return Scaffold(
      backgroundColor: AppColors.rosa,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  const BackButton(color: Colors.white),
                  Expanded(
                    child: Text(
                      'Detalle de la mascota',
                      textAlign: TextAlign.center,
                      style: t.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        _fotoCircular(),
                        const SizedBox(height: 16),
                        Text(
                          p.nombre,
                          textAlign: TextAlign.center,
                          style: t.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitulo.isNotEmpty)
                          Text(
                            subtitulo,
                            style: t.bodyLarge?.copyWith(color: Colors.white70),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _pildora(
                              _estados[_estadoAdopcion] ?? _estadoAdopcion,
                              Icons.pets,
                            ),
                            if (_apadrinada)
                              _pildora('Apadrinada', Icons.volunteer_activism),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TarjetaBlanca(
                          titulo: 'Datos',
                          icono: Icons.info_outline,
                          child: LayoutBuilder(
                            builder: (_, c) {
                              final ancho = (c.maxWidth - 10) / 2;
                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final d in _datos)
                                    SizedBox(width: ancho, child: d),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        TarjetaBlanca(
                          titulo: 'Sobre ${p.nombre}',
                          icono: Icons.notes,
                          child: Text(
                            descripcion.isEmpty
                                ? 'Aún no hay una descripción.'
                                : descripcion,
                            style: t.bodyLarge?.copyWith(height: 1.45),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TarjetaBlanca(
                          titulo: 'Personalidad',
                          icono: Icons.favorite_border,
                          child: _personalidad(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _acciones(),
          ],
        ),
      ),
    );
  }

  // Foto circular con aro blanco sobre el rosado de la pantalla.
  Widget _fotoCircular() => Container(
    width: 236,
    height: 236,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.rosa,
      border: Border.all(color: Colors.white, width: 7),
    ),
    child: ClipOval(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: PetImage(
          url: widget.pet.foto,
          fit: _esRecorte ? BoxFit.contain : BoxFit.cover,
        ),
      ),
    ),
  );

  Widget _pildora(String texto, IconData icono) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: AppColors.rosa),
        const SizedBox(width: 6),
        Text(
          texto,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.rosa),
        ),
      ],
    ),
  );

  // Personalidad: solo se muestran las etiquetas de los rasgos que destacan,
  // sin la escala de 1 a 5.
  //   valor 1-2 => texto del extremo bajo  (ej: "Muy tranquila")
  //   valor 4-5 => texto del extremo alto  (ej: "Muy activa")
  //   valor 3   => no se muestra (el rasgo no destaca)
  Widget _personalidad() => FutureBuilder<Pet>(
    future: _completa,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator(
          color: AppColors.rosa,
          backgroundColor: AppColors.rosaClaro,
        );
      }
      if (snap.hasError) {
        return Row(
          children: [
            const Expanded(child: Text('No se pudo cargar la personalidad.')),
            TextButton(
              onPressed: () => setState(
                () => _completa = PetsService.obtener(widget.pet.id),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        );
      }

      final valores = snap.data!.personalidad;
      if (valores.isEmpty) {
        return const Text('Aún no hay datos de personalidad.');
      }

      final chips = <Widget>[];
      for (final r in rasgosMascota) {
        final v = valores[r.clave];
        if (v == null || v == 3) continue;
        // El texto concuerda con el sexo: "Muy activo" / "Muy activa", etc.
        final texto = v <= 2
            ? r.minimoPara(widget.pet.sexo)
            : r.maximoPara(widget.pet.sexo);
        chips.add(_chipRasgo(r.icono, texto));
      }

      if (chips.isEmpty) {
        return const Text('Tiene una personalidad equilibrada.');
      }
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    },
  );

  Widget _chipRasgo(IconData icono, String texto) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.rosaClaro,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: AppColors.rosa),
        const SizedBox(width: 6),
        Text(texto, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );

  Widget _botonAdoptar() {
    final estilo = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    var etiqueta = switch (_estadoAdopcion) {
      'en_proceso' => 'En proceso',
      'adoptado' => 'Adoptado',
      _ => 'Adoptar',
    };
    var icono = Icons.pets;
    VoidCallback? accion = _puedeAdoptar
        ? (widget.onAdoptar ?? _abrirFormularioAdopcion)
        : null;
    Color? fondo;

    final mia = _miAdopcion;
    if (mia != null) {
      if (mia.isApproved) {
        etiqueta = 'Aprobada';
        icono = Icons.verified;
        accion = _verEstadoAdopcion;
        fondo = Colors.green.shade700;
      } else if (mia.isPending) {
        etiqueta = 'En revisión';
        icono = Icons.hourglass_top;
        accion = _verEstadoAdopcion;
        fondo = Colors.orange.shade700;
      } else if (mia.isRejected) {
        etiqueta = 'Rechazada';
        icono = Icons.info_outline;
        accion = _verEstadoAdopcion;
        fondo = Colors.redAccent.shade700;
      }
    }

    return Expanded(
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: fondo ?? Colors.white,
          foregroundColor: fondo == null ? AppColors.rosa : Colors.white,
          disabledBackgroundColor: Colors.white24,
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          textStyle: estilo,
        ),
        icon: Icon(icono),
        label: Text(etiqueta, overflow: TextOverflow.ellipsis),
        onPressed: accion,
      ),
    );
  }

  // Botones Adoptar / Apadrinar fijos abajo
  Widget _acciones() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Row(
            children: [
              _botonAdoptar(),
              const SizedBox(width: 12),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final sinApadrinamientoActivo =
                        _miSolicitud == null || _miSolicitud!.esRechazada;
                    if (_estadoAdopcion == 'adoptado' && sinApadrinamientoActivo) {
                      return _AvisoYaEnFamilia(
                        texto: widget.pet.mensajeFamiliaPara(Session.idUsuario),
                      );
                    }

                    String etiqueta = 'Apadrinar';
                    IconData icono = Icons.volunteer_activism;
                    VoidCallback? accion = _abrirFormularioApadrinar;
                    Color colorFondo = Colors.transparent;
                    Color colorTexto = Colors.white;

                    if (_miSolicitud != null) {
                      if (_miSolicitud!.esAprobada) {
                        if (_miSolicitud!.tieneContrato) {
                          etiqueta = 'Padrino Oficial';
                          icono = Icons.stars;
                          accion = _verEstadoSolicitud;
                          colorFondo = Colors.green.shade700;
                        } else {
                          etiqueta = 'Aprobada (Falta Contrato)';
                          icono = Icons.hourglass_top_rounded;
                          accion = _verEstadoSolicitud;
                          colorFondo = Colors.amber.shade800;
                        }
                      } else if (_miSolicitud!.esCancelada) {
                        etiqueta = 'Cancelada';
                        icono = Icons.highlight_off;
                        accion = _verEstadoSolicitud;
                        colorFondo = Colors.blueGrey.shade700;
                      } else if (_miSolicitud!.esPendiente) {
                        etiqueta = 'En Revisión';
                        icono = Icons.hourglass_top;
                        accion = _verEstadoSolicitud;
                        colorFondo = Colors.orange.shade700;
                      } else if (_miSolicitud!.esRechazada) {
                        etiqueta = 'Rechazada';
                        icono = Icons.info_outline;
                        accion = _verEstadoSolicitud;
                        colorFondo = Colors.redAccent.shade700;
                      }
                    } else if (_apadrinada) {
                      etiqueta = 'Apadrinada';
                      accion = null;
                    }

                    if (colorFondo != Colors.transparent) {
                      return FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: colorFondo,
                          foregroundColor: colorTexto,
                          minimumSize: const Size.fromHeight(54),
                          shape: const StadiumBorder(),
                          textStyle: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        icon: Icon(icono),
                        label: Text(etiqueta),
                        onPressed: accion,
                      );
                    }

                    return OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white54,
                        side: BorderSide(
                          color: _puedeApadrinar ? Colors.white : Colors.white38,
                          width: 1.5,
                        ),
                        minimumSize: const Size.fromHeight(54),
                        shape: const StadiumBorder(),
                        textStyle: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      icon: Icon(icono),
                      label: Text(etiqueta),
                      onPressed: _puedeApadrinar ? accion : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoYaEnFamilia extends StatelessWidget {
  final String texto;
  const _AvisoYaEnFamilia({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.rosa,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          height: 1.2,
        ),
      ),
    );
  }
}
