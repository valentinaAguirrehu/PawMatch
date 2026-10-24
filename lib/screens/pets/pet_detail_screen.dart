import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/enlaces.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/admin/pets_form_screen.dart';
import 'package:paw_match/screens/adoption/adoption_form_screen.dart';
import 'package:paw_match/screens/adoption/pasos_adopcion_screen.dart';
import 'package:paw_match/screens/adoption/validacion_perfil_adopcion.dart';
import 'package:paw_match/screens/apadrinamiento/solicitud_apadrinamiento_dialog.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/acuerdo_adopcion_pdf_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Detalle de una mascota inspirado en el diseño de referencia:
/// cabecera con lienzo pastel decorado, foto prominente de la mascota,
/// tarjeta deslizable blanca con atributos organizados, descripción y botones de acción.
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
  late Pet _pet = widget.pet;
  late Future<Pet> _completa = PetsService.obtener(widget.pet.id);
  SolicitudApadrinamiento? _miSolicitud;
  AdoptionRequest? _miAdopcion;
  bool _descargandoActa = false;

  @override
  void initState() {
    super.initState();
    _consultarMiSolicitud();
    _consultarMiAdopcion();
  }

  Future<void> _consultarMiSolicitud() async {
    if (Session.idUsuario == null) return;
    try {
      final lista = await ApadrinamientoService.listarMisSolicitudes(idMascota: _pet.id);
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
      final lista = await AdoptionService.listMine(petId: _pet.id);
      if (!mounted) return;
      setState(() => _miAdopcion = lista.isEmpty ? null : lista.first);
    } catch (_) {}
  }

  Future<void> _descargarActa(AdoptionRequest solicitud) async {
    if (_descargandoActa) return;
    setState(() => _descargandoActa = true);
    try {
      final fecha = DateTime.tryParse(solicitud.requestedAt.replaceFirst(' ', 'T')) ??
          DateTime.now();
      final fotos = await Future.wait([
        _traerFoto(AdoptionService.fetchIdCard(solicitud.id)),
        _traerFoto(AdoptionService.fetchUtilityBill(solicitud.id)),
      ]);
      final cedula = fotos[0];
      final recibo = fotos[1];
      final bytes = await AcuerdoAdopcionPdfService.generarPdfBytes(
        DatosActaAdopcion(
          idSolicitud: solicitud.id,
          nombreUsuario: solicitud.applicantFullName,
          documentoUsuario: solicitud.applicantIdNumber.trim().isEmpty
              ? null
              : solicitud.applicantIdNumber.trim(),
          correoUsuario: solicitud.applicantEmail.trim().isNotEmpty
              ? solicitud.applicantEmail.trim()
              : Session.correo,
          telefonoUsuario: solicitud.applicantPhone.trim().isEmpty
              ? null
              : solicitud.applicantPhone.trim(),
          direccionUsuario: solicitud.applicantAddress.trim().isEmpty
              ? null
              : solicitud.applicantAddress.trim(),
          tipoVivienda: solicitud.housingType,
          tienePatio: solicitud.hasYard ?? false,
          tieneNinos: solicitud.hasChildren ?? false,
          tieneOtrasMascotas: solicitud.hasOtherPets ?? false,
          otrasMascotas: solicitud.otherPets,
          tiempoDisponible: solicitud.availableTime,
          experienciaPrevia: solicitud.previousExperience ?? false,
          motivacion: solicitud.additionalInfo,
          nombreMascota: _pet.nombre,
          especieMascota: _pet.especie,
          razaMascota: _pet.raza,
          edadMascota: _pet.edadTexto,
          sexoMascota: _pet.sexo,
          fechaAceptacion: fecha,
          aceptoTerminos: true,
          fotoCedula: cedula,
          fotoRecibo: recibo,
        ),
      );
      await AcuerdoAdopcionPdfService.descargarYGuardarPdf(
        bytes: bytes,
        nombreMascota: _pet.nombre,
      );
      if (!mounted) return;
      final fotosOk = cedula != null && recibo != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fotosOk
                ? 'Descargando el acta con la cédula y el recibo...'
                : 'Acta descargada. No se pudo anexar la cédula o el recibo.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo descargar el acta: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _descargandoActa = false);
    }
  }

  Future<Uint8List?> _traerFoto(Future<Uint8List> carga) async {
    try {
      return await carga;
    } catch (_) {
      return null;
    }
  }

  Widget _tarjetaActa(AdoptionRequest solicitud) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: AppColors.rosa, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Acta de compromiso',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    Text(
                      'Documento de tu solicitud de adopción.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rosa,
                side: const BorderSide(color: AppColors.rosa, width: 1.4),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _descargandoActa ? null : () => _descargarActa(solicitud),
              icon: _descargandoActa
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rosa),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: const Text('Descargar acta'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFormularioAdopcion() async {
    final listo = await perfilListoParaAdoptar(context);
    if (!listo || !mounted) return;
    final seguir = await PasosAdopcionScreen.mostrar(context);
    if (!seguir || !mounted) return;
    final enviada = await AdoptionFormScreen.mostrar(context, pet: _pet);
    if (enviada == true && mounted) _consultarMiAdopcion();
  }

  void _verEstadoAdopcion() {
    final s = _miAdopcion;
    if (s == null) return;

    if (s.isApproved) {
      if (s.hasContract) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.verified, color: Colors.green, size: 48),
            title: Text('¡Adopción de ${_pet.nombre} aprobada!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📅 Fecha oficial de inicio: ${s.adoptionStartDateLabel ?? 'Activo'}'),
                const SizedBox(height: 8),
                const Text(
                  'El contrato de adopción ya está disponible. Puedes verlo y descargarlo, y coordinar la entrega por WhatsApp.',
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
                style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                icon: const Icon(Icons.assignment_turned_in),
                label: const Text('Ver contrato'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _verContratoAdopcion(s);
                },
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                icon: const Icon(Icons.chat),
                label: const Text('WhatsApp'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _whatsappAdopcion();
                },
              ),
            ],
          ),
        );
      } else {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 48),
            title: const Text('Pendiente subir contrato de adopción'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu solicitud para adoptar a ${_pet.nombre} fue aprobada.',
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
                  child: Text(
                    'Pendiente subir contrato de adopción. Debes esperar a que el administrador suba el contrato firmado. Cuando lo haga, podrás verlo y descargarlo aquí.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                      height: 1.35,
                    ),
                  ),
                ),
                if (s.hasObservations) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Indicaciones de la fundación: ${s.observations}',
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
                ? '${_pet.nombre} ya fue adoptado. La fundación aún debe cerrar tu solicitud.'
                : 'Tu solicitud para adoptar a ${_pet.nombre} fue enviada el ${s.requestedAtLabel}. Recibirás una notificación cuando sea revisada.',
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
              'Tu solicitud anterior para adoptar a ${_pet.nombre} no fue aprobada.',
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
      pet: _pet,
      onEnviadaExitosamente: _consultarMiSolicitud,
    );
  }

  void _whatsappAdopcion() {
    final num = FundacionInfo.whatsappNumero.isNotEmpty
        ? FundacionInfo.whatsappNumero
        : '573136177747';
    final msg =
        'Hola Fundación Maritza Arévalo, mi solicitud para adoptar a ${_pet.nombre} fue aprobada en Paw Match.';
    abrirEnlace(
      context,
      'https://wa.me/$num?text=${Uri.encodeComponent(msg)}',
      nombre: 'WhatsApp',
    );
  }

  Future<void> _verContratoAdopcion(AdoptionRequest solicitud) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await AdoptionService.fetchContract(solicitud.id);
      if (!mounted) return;
      Navigator.pop(context);

      final esPdf = bytes.length >= 4 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46;

      if (esPdf) {
        await Printing.layoutPdf(
          onLayout: (_) => bytes,
          name: 'Contrato_Adopcion_${_pet.nombre}.pdf',
        );
        return;
      }

      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text('Contrato de adopción - ${_pet.nombre}'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
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
          name: 'Contrato_Apadrinamiento_${_pet.nombre}.pdf',
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
              title: Text('Contrato de Apadrinamiento - ${_pet.nombre}'),
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
            title: Text('¡Eres Padrino Oficial de ${_pet.nombre}! 🎉'),
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
                  final msg = 'Hola Fundación Maritza Arévalo, soy el padrino de ${_pet.nombre} y vengo de Paw Match.';
                  abrirEnlace(context, 'https://wa.me/$num?text=${Uri.encodeComponent(msg)}', nombre: 'WhatsApp');
                },
              ),
            ],
          ),
        );
      } else {
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
                  '¡Tu solicitud para apadrinar a ${_pet.nombre} fue aprobada por la fundación!',
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
                          'Aún falta un paso: Debes esperar a que el administrador suba el contrato oficial de apadrinamiento firmado. Una vez lo suba, serás formalmente el padrino de ${_pet.nombre} y podrás consultarlo aquí.',
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
              Text('El apadrinamiento para ${_pet.nombre} fue cancelado por la administración.'),
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
              Text('Tu solicitud para apadrinar a ${_pet.nombre} fue enviada el ${s.fechaSolicitud}.'),
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
              Text('Tu solicitud anterior para apadrinar a ${_pet.nombre} no fue aprobada.'),
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

  String _t(String? v) => v?.trim() ?? '';

  String get _estadoAdopcion {
    final e = _t(_pet.estadoAdopcion);
    return e.isEmpty ? 'disponible' : e;
  }

  bool get _apadrinada => _t(_pet.estadoApadrinamiento) == 'apadrinado';
  bool get _puedeAdoptar => _estadoAdopcion == 'disponible';
  bool get _puedeApadrinar => !_apadrinada && _estadoAdopcion != 'adoptado';

  bool get _esRecorte {
    final f = _t(_pet.foto).toLowerCase();
    return f.contains('.png') || f.contains('.webp');
  }

  Future<void> _editarMascotaAdmin() async {
    final guardado = await Navigator.push<Pet>(
      context,
      MaterialPageRoute(builder: (_) => PetsFormScreen(pet: _pet)),
    );
    if (guardado != null && mounted) {
      try {
        final actualizada = await PetsService.obtener(_pet.id);
        if (mounted) {
          setState(() {
            _pet = actualizada;
            _completa = Future.value(actualizada);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datos de la mascota actualizados exitosamente')),
          );
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _completa = PetsService.obtener(_pet.id);
          });
        }
      }
    }
  }

  Future<void> _eliminarMascotaAdmin() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar mascota'),
        content: Text(
          '¿Seguro que quieres eliminar a ${_pet.nombre}? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      await PetsService.eliminar(_pet.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_pet.nombre} fue eliminada')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _mostrarOpciones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (Session.esAdmin) ...[
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: AppColors.rosa),
                  title: const Text('Modificar datos de la mascota'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _editarMascotaAdmin();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                  title: Text(
                    'Eliminar mascota',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _eliminarMascotaAdmin();
                  },
                ),
                const Divider(),
              ],
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
                title: const Text('Contactar a la Fundación por WhatsApp'),
                onTap: () {
                  Navigator.pop(ctx);
                  final num = FundacionInfo.whatsappNumero.isNotEmpty
                      ? FundacionInfo.whatsappNumero
                      : '573136177747';
                  final msg = 'Hola Fundación Maritza Arévalo, me interesa información sobre ${_pet.nombre}.';
                  abrirEnlace(context, 'https://wa.me/$num?text=${Uri.encodeComponent(msg)}', nombre: 'WhatsApp');
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.rosa),
                title: const Text('Sobre la Fundación Maritza Arévalo'),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text(FundacionInfo.nombre),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📍 ${FundacionInfo.ciudad}'),
                          const SizedBox(height: 6),
                          Text('📱 WhatsApp: +57 ${FundacionInfo.whatsappNumero}'),
                          const SizedBox(height: 10),
                          const Text('Dedicados al rescate, rehabilitación y reubicación responsable de animales en situación de vulnerabilidad.'),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cerrar')),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verFotoCompleta(BuildContext context) {
    final url = _pet.foto;
    if (url == null || url.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(_pet.nombre),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                urlFoto(url),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFotoMascota(BuildContext context) {
    final url = _pet.foto;
    if (url == null || url.isEmpty) {
      return Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.pets, size: 60, color: AppColors.rosaSuave),
      );
    }

    final imageWidget = Image.network(
      urlFoto(url),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(Icons.pets, size: 60, color: AppColors.rosa),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const Center(
              child: CircularProgressIndicator(color: AppColors.rosa, strokeWidth: 2),
            ),
    );

    if (_esRecorte) {
      return GestureDetector(
        onTap: () => _verFotoCompleta(context),
        child: imageWidget,
      );
    }

    return GestureDetector(
      onTap: () => _verFotoCompleta(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.rosa.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: imageWidget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _pet;
    final descripcion = _t(p.descripcion);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF0F3), // Fondo rosado suave
      body: Stack(
        children: [
          // ───────── LIENZO ROSADO SUAVE DECORADO CON FOTO DE LA MASCOTA ─────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 400,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF5F7), // Rosado pastel muy suave
                    Color(0xFFFCE4EC), // Rosado cálido suave
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Huellitas y destellos decorativos en el fondo estilo imagen de referencia
                  Positioned(
                    left: 28,
                    top: 110,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Icon(
                        Icons.pets_rounded,
                        size: 32,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 32,
                    top: 100,
                    child: Transform.rotate(
                      angle: 0.25,
                      child: Icon(
                        Icons.pets_rounded,
                        size: 26,
                        color: Colors.white.withValues(alpha: 0.50),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 68,
                    top: 175,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                  ),
                  Positioned(
                    right: 56,
                    top: 165,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 22,
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                  ),
                  Positioned(
                    left: 54,
                    top: 80,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                  Positioned(
                    right: 80,
                    top: 65,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),

                  // Foto de la mascota destacada completa en el centro
                  Positioned(
                    top: 75,
                    bottom: 15,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 310),
                        child: _buildFotoMascota(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ───────── CONTENIDO DESLIZABLE BLANCO (ESTILO REFERENCIA) ─────────
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 385),
              child: Container(
                constraints: const BoxConstraints(minHeight: 500),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre de la mascota en tipografía oscura destacada
                      Text(
                        p.nombre,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E272E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Ubicación y Fundación con pin
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 17,
                            color: AppColors.rosa,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${FundacionInfo.nombre} · ${FundacionInfo.ciudad}',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ───────── SECCIÓN: SOBRE LA MASCOTA (IGUAL A FOTO 2) ─────────
                      Text(
                        'Sobre ${_pet.nombre}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E272E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        descripcion.isEmpty
                            ? 'Hermoso ${p.especie.toLowerCase()} rescatado con amor por la Fundación Maritza Arévalo. Es cariñoso, sociable y está esperando a una familia responsable que le brinde un futuro lleno de protección y felicidad.'
                            : descripcion,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.5,
                          color: Colors.grey.shade700,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ───────── CUADRÍCULA 2x2 EN ROSADO (IGUAL A LA FOTO 2) ─────────
                      Row(
                        children: [
                          Expanded(
                            child: _tarjetaDato(
                              'Edad:',
                              p.edad == null
                                  ? 'no registrada'
                                  : p.edadTexto.toLowerCase(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _tarjetaDato(
                              'Sexo:',
                              (_t(p.sexo).isEmpty ? 'no registrado' : p.sexo!).toLowerCase(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _tarjetaDato(
                              'Tamaño:',
                              (_t(p.tamano).isEmpty ? 'mediano' : p.tamano!).toLowerCase(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _tarjetaDato(
                              'Especie:',
                              p.especie.toLowerCase(),
                            ),
                          ),
                        ],
                      ),

                      // ───────── SECCIÓN: PERSONALIDAD Y COMPORTAMIENTO (ARRIBA DE BOTONES) ─────────
                      const SizedBox(height: 22),
                      const Text(
                        'Personalidad y Comportamiento',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E272E),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _personalidad(),

                      // Contrato disponible si es padrino
                      if (_miAdopcion != null && _miAdopcion!.hasContract) ...[
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.assignment_turned_in, color: Colors.green, size: 28),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Contrato oficial de adopción firmado y disponible.',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _verContratoAdopcion(_miAdopcion!),
                                child: const Text('Ver'),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_miSolicitud != null && _miSolicitud!.tieneContrato) ...[
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.assignment_turned_in, color: Colors.green, size: 28),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Contrato oficial de apadrinamiento firmado y registrado.',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _verContrato(_miSolicitud!),
                                child: const Text('Ver'),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 26),

                      // ───────── BOTONES DE ACCIÓN (DE ÚLTIMO) ─────────
                      _botonesAccion(p),

                      const SizedBox(height: 14),

                      // Texto explicativo al final
                      Text(
                        'Al enviar la solicitud estarás manifestando tu interés para que nuestro equipo te contacte y así evaluar juntos la adopción de ${_pet.nombre}.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ───────── CABECERA FIJA (ATRÁS, TÍTULO Y OPCIONES) ─────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: const Color(0xFFFFF5F7),
              elevation: 2,
              shadowColor: Colors.black26,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            size: 26,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          '¡Más sobre mí!',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E272E),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _mostrarOpciones(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            size: 22,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  // Tarjeta de dato individual redondeada en rosado suave (igual a foto de referencia)
  Widget _tarjetaDato(String etiqueta, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.bordeRosa.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.rosa,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E2A2C),
            ),
          ),
        ],
      ),
    );
  }

  void _compartirMascota() {
    final texto =
        '¡Conoce a ${_pet.nombre} en Paw Match! Está buscando una familia o padrino en la Fundación Maritza Arévalo 🐾';
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.rosa,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('¡Información de ${_pet.nombre} copiada al portapapeles!')),
          ],
        ),
      ),
    );
  }

  Widget _botonesAccion(Pet p) {
    if (Session.esAdmin) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300, width: 1.5),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Eliminar', overflow: TextOverflow.ellipsis),
              onPressed: _eliminarMascotaAdmin,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rosa,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                elevation: 2,
              ),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Modificar datos', overflow: TextOverflow.ellipsis),
              onPressed: _editarMascotaAdmin,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final esEstrecho = constraints.maxWidth < 460;

        // 1. Botón Adoptar
        var etiquetaAdoptar = switch (_estadoAdopcion) {
          'en_proceso' => 'En proceso',
          'adoptado' => 'Adoptado',
          _ => 'Adoptar a ${p.nombre}',
        };
        var iconoAdoptar = Icons.favorite_rounded;
        VoidCallback? accionAdoptar = _puedeAdoptar
            ? (widget.onAdoptar ?? _abrirFormularioAdopcion)
            : null;
        Color? fondoAdoptar;

        final mia = _miAdopcion;
        if (mia != null) {
          if (mia.isApproved) {
            if (mia.hasContract) {
              etiquetaAdoptar = 'Ver contrato';
              iconoAdoptar = Icons.assignment_turned_in;
              accionAdoptar = _verEstadoAdopcion;
              fondoAdoptar = Colors.green.shade700;
            } else {
              etiquetaAdoptar = 'Falta contrato';
              iconoAdoptar = Icons.hourglass_top_rounded;
              accionAdoptar = _verEstadoAdopcion;
              fondoAdoptar = Colors.amber.shade800;
            }
          } else if (mia.isPending) {
            etiquetaAdoptar = 'En revisión';
            iconoAdoptar = Icons.hourglass_top;
            accionAdoptar = _verEstadoAdopcion;
            fondoAdoptar = Colors.orange.shade700;
          } else if (mia.isRejected) {
            etiquetaAdoptar = 'Rechazada';
            iconoAdoptar = Icons.info_outline;
            accionAdoptar = _verEstadoAdopcion;
            fondoAdoptar = Colors.redAccent.shade700;
          }
        }

        final botonAdoptar = FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: fondoAdoptar ?? AppColors.rosa,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade500,
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            elevation: 1,
          ),
          icon: Icon(iconoAdoptar, size: 17),
          label: Text(etiquetaAdoptar, maxLines: 1, overflow: TextOverflow.ellipsis),
          onPressed: accionAdoptar,
        );

        // Con la solicitud en revisión no se ofrece apadrinar ni compartir.
        if (mia != null && mia.isPending) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: botonAdoptar),
              const SizedBox(height: 12),
              _tarjetaActa(mia),
            ],
          );
        }

        // 2. Botón Apadrinar
        Widget botonApadrinar;
        final sinApadrinamientoActivo = _miSolicitud == null || _miSolicitud!.esRechazada;
        if (_estadoAdopcion == 'adoptado' && sinApadrinamientoActivo) {
          botonApadrinar = _AvisoYaEnFamilia(texto: _pet.mensajeFamiliaPara(Session.idUsuario));
        } else {
          String etiquetaApadrinar = 'Apadrinar a ${p.nombre}';
          VoidCallback? accionApadrinar = _abrirFormularioApadrinar;
          Color colorFondoApadrinar = Colors.white;
          Color colorTextoApadrinar = AppColors.rosa;
          Color colorBordeApadrinar = AppColors.rosa;

          if (_miSolicitud != null) {
            if (_miSolicitud!.esAprobada) {
              if (_miSolicitud!.tieneContrato) {
                etiquetaApadrinar = 'Padrino Oficial';
                accionApadrinar = _verEstadoSolicitud;
                colorFondoApadrinar = Colors.green.shade700;
                colorTextoApadrinar = Colors.white;
                colorBordeApadrinar = Colors.green.shade700;
              } else {
                etiquetaApadrinar = 'Falta Contrato';
                accionApadrinar = _verEstadoSolicitud;
                colorFondoApadrinar = Colors.amber.shade800;
                colorTextoApadrinar = Colors.white;
                colorBordeApadrinar = Colors.amber.shade800;
              }
            } else if (_miSolicitud!.esCancelada) {
              etiquetaApadrinar = 'Cancelada';
              accionApadrinar = _verEstadoSolicitud;
              colorFondoApadrinar = Colors.blueGrey.shade700;
              colorTextoApadrinar = Colors.white;
              colorBordeApadrinar = Colors.blueGrey.shade700;
            } else if (_miSolicitud!.esPendiente) {
              etiquetaApadrinar = 'En Revisión';
              accionApadrinar = _verEstadoSolicitud;
              colorFondoApadrinar = Colors.orange.shade700;
              colorTextoApadrinar = Colors.white;
              colorBordeApadrinar = Colors.orange.shade700;
            } else if (_miSolicitud!.esRechazada) {
              etiquetaApadrinar = 'Rechazada';
              accionApadrinar = _verEstadoSolicitud;
              colorFondoApadrinar = Colors.redAccent.shade700;
              colorTextoApadrinar = Colors.white;
              colorBordeApadrinar = Colors.redAccent.shade700;
            }
          } else if (_apadrinada) {
            etiquetaApadrinar = 'Apadrinada';
            accionApadrinar = null;
            colorBordeApadrinar = Colors.grey.shade300;
            colorTextoApadrinar = Colors.grey.shade400;
          }

          if (colorFondoApadrinar != Colors.white) {
            botonApadrinar = FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorFondoApadrinar,
                foregroundColor: colorTextoApadrinar,
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              onPressed: accionApadrinar,
              child: Text(etiquetaApadrinar, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          } else {
            botonApadrinar = OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: colorTextoApadrinar,
                backgroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade400,
                side: BorderSide(
                  color: _puedeApadrinar ? colorBordeApadrinar : Colors.grey.shade300,
                  width: 1.5,
                ),
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              onPressed: _puedeApadrinar ? accionApadrinar : null,
              child: Text(etiquetaApadrinar, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }
        }

        // 3. Botón Compartir
        final botonCompartir = OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.rosa,
            backgroundColor: AppColors.rosaSuave,
            side: const BorderSide(color: AppColors.bordeRosa, width: 1.2),
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
          icon: const Icon(Icons.share_outlined, size: 17, color: AppColors.rosa),
          label: const Text('Compartir', maxLines: 1, overflow: TextOverflow.ellipsis),
          onPressed: _compartirMascota,
        );

        if (esEstrecho) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(flex: 3, child: botonAdoptar),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: botonApadrinar),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: botonCompartir),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 4, child: botonAdoptar),
            const SizedBox(width: 10),
            Expanded(flex: 4, child: botonApadrinar),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: botonCompartir),
          ],
        );
      },
    );
  }

  Widget _personalidad() => FutureBuilder<Pet>(
    future: _completa,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.rosa, strokeWidth: 2),
        );
      }
      if (snap.hasError) {
        return Row(
          children: [
            const Expanded(child: Text('No se pudo cargar la personalidad.')),
            TextButton(
              onPressed: () => setState(
                () => _completa = PetsService.obtener(_pet.id),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        );
      }

      final valores = snap.data!.personalidad;
      if (valores.isEmpty) {
        return const Text('Aún no hay datos de personalidad registrados.');
      }

      final chips = <Widget>[];
      for (final r in rasgosMascota) {
        final v = valores[r.clave];
        if (v == null || v == 3) continue;
        final texto = v <= 2
            ? r.minimoPara(_pet.sexo)
            : r.maximoPara(_pet.sexo);
        chips.add(_chipRasgo(r.icono, texto));
      }

      if (chips.isEmpty) {
        return const Text('Tiene una personalidad dócil y equilibrada.');
      }
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    },
  );

  Widget _chipRasgo(IconData icono, String texto) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFFDF2F4),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.rosa.withValues(alpha: 0.15)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 15, color: AppColors.rosa),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(
            color: Color(0xFF2D3436),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _AvisoYaEnFamilia extends StatelessWidget {
  final String texto;
  const _AvisoYaEnFamilia({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.rosaClaro,
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        border: Border.all(color: AppColors.rosa.withValues(alpha: 0.3)),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.rosa,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
          height: 1.2,
        ),
      ),
    );
  }
}
