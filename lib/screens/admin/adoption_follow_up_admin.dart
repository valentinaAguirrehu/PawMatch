import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/seguimiento_adopcion.dart';
import 'package:paw_match/models/seguimiento_apadrinamiento.dart';
import 'package:paw_match/screens/admin/adoption_form__follow_up.dart';
import 'package:paw_match/screens/admin/cancelacion_adopcion_form.dart';
import 'package:paw_match/screens/adoption/adoption_detail_admin_screen.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/compartir_acta_whatsapp.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/reporte_adopcion_pdf_service.dart';
import 'package:paw_match/services/seguimiento_adopcion_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/calendario_seguimientos.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';
import 'package:paw_match/widgets/star_rating_selector.dart';

/// Seguimiento administrativo de adopciones con contrato: lista y calendario.
class AdoptionFollowUpAdminScreen extends StatefulWidget {
  const AdoptionFollowUpAdminScreen({super.key});

  @override
  State<AdoptionFollowUpAdminScreen> createState() => _AdoptionFollowUpAdminScreenState();
}

class _AdoptionFollowUpAdminScreenState extends State<AdoptionFollowUpAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<AdopcionActivaSeguimiento>> _futureActivas;
  late Future<List<ItemCalendarioSeguimiento>> _futureCalendario;
  late Future<Map<String, AdoptionRequest>> _futureSolicitudes;
  List<AdopcionActivaSeguimiento> _activas = [];
  String _busqueda = '';
  bool _verCanceladas = false;

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _cargarTodo() {
    _futureActivas = SeguimientoAdopcionService.listarActivas();
    _futureCalendario = SeguimientoAdopcionService.obtenerCalendario();
    _futureSolicitudes = AdoptionService.listForAdmin().then((lista) {
      return {for (final solicitud in lista) solicitud.id: solicitud};
    });
    _futureActivas.then((lista) {
      if (mounted) _activas = lista;
    }).catchError((_) {});
  }

  Future<void> _recargar() async {
    setState(_cargarTodo);
    await Future.wait([
      _futureActivas.catchError((_) => <AdopcionActivaSeguimiento>[]),
      _futureCalendario.catchError((_) => <ItemCalendarioSeguimiento>[]),
      _futureSolicitudes.catchError((_) => <String, AdoptionRequest>{}),
    ]);
  }

  List<AdopcionActivaSeguimiento> _filtrar(List<AdopcionActivaSeguimiento> todas) {
    final consulta = _busqueda.trim().toLowerCase();
    if (consulta.isEmpty) return todas;
    return todas.where((item) {
      return item.mascotaNombre.toLowerCase().contains(consulta) ||
          item.adoptanteNombre.toLowerCase().contains(consulta);
    }).toList();
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (!confirmar || !mounted) return;
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    Session.cerrar();
    Navegacion.ir(context, const WelcomeScreen());
  }

  Widget _conBarra(Widget contenido, {VoidCallback? onVolver}) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            BarraSuperior(
              iconoTitulo: Icons.favorite_rounded,
              titulo: 'Seguimiento',
              onCerrarSesion: _confirmarCerrarSesion,
              onVolver: onVolver,
            ),
            Expanded(child: contenido),
          ],
        ),
      ),
    );
  }

  Pet _mascotaDe(AdopcionActivaSeguimiento item) {
    return Pet(
      id: item.idMascota,
      nombre: item.mascotaNombre,
      especie: item.mascotaEspecie,
      raza: item.mascotaRaza,
      edad: item.mascotaEdad,
      unidadEdad: item.mascotaUnidadEdad,
      foto: item.fotoPrincipal,
      estadoAdopcion: 'adoptado',
    );
  }

  AdoptionRequest _solicitudDe(AdopcionActivaSeguimiento item, Map<String, AdoptionRequest> porId) {
    final guardada = porId[item.idSolicitud];
    if (guardada != null) return guardada;
    final partes = item.adoptanteNombre.split(' ');
    return AdoptionRequest(
      id: item.idSolicitud,
      userId: item.idAdoptante,
      petId: item.idMascota,
      applicantFirstName: partes.isEmpty ? item.adoptanteNombre : partes.first,
      applicantLastName: partes.length > 1 ? partes.skip(1).join(' ') : '',
      applicantEmail: item.adoptanteCorreo,
      applicantPhone: item.adoptanteTelefono,
      petName: item.mascotaNombre,
      petSpecies: item.mascotaEspecie,
      petBreed: item.mascotaRaza,
      petAge: item.mascotaEdad,
      petPhoto: item.fotoPrincipal ?? '',
      status: item.estado,
      adoptionStartDate: item.fechaInicio?.toIso8601String().split('T').first,
      contractFile: item.contratoArchivo,
    );
  }

  void _realizarSeguimiento(
    AdopcionActivaSeguimiento item,
    Map<String, AdoptionRequest> porId,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdoptionFormFollowUp(
          mascota: _mascotaDe(item),
          solicitud: _solicitudDe(item, porId),
          numeroSiguiente: item.totalSeguimientos + 1,
          onGuardadoExitoso: _recargar,
        ),
      ),
    );
  }

  void _abrirDesdeCalendario(ItemCalendarioSeguimiento evento) {
    _futureActivas.then((activas) {
      _activas = activas;
      AdopcionActivaSeguimiento? encontrada;
      for (final activa in activas) {
        if (activa.idSolicitud == evento.idSolicitud) {
          encontrada = activa;
          break;
        }
      }
      if (!mounted) return;
      if (encontrada == null) {
        _abrirFormularioCalendario(evento);
        return;
      }
      final item = encontrada;
      _futureSolicitudes.then((porId) {
        if (!mounted) return;
        _realizarSeguimiento(item, porId);
      }, onError: (_) {
        if (!mounted) return;
        _realizarSeguimiento(item, const {});
      });
    }).catchError((_) {
      if (!mounted) return;
      _abrirFormularioCalendario(evento);
    });
  }

  void _abrirFormularioCalendario(ItemCalendarioSeguimiento evento) {

    final pet = Pet(
      id: evento.idMascota,
      nombre: evento.mascotaNombre,
      especie: evento.mascotaEspecie,
      raza: evento.mascotaRaza,
      edad: evento.mascotaEdad,
      unidadEdad: evento.mascotaUnidadEdad,
      foto: evento.mascotaFotos is List && evento.mascotaFotos.isNotEmpty
          ? evento.mascotaFotos.first.toString()
          : evento.mascotaFotos.toString(),
      estadoAdopcion: 'adoptado',
    );
    final partes = evento.padrinoNombre.split(' ');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdoptionFormFollowUp(
          mascota: pet,
          solicitud: AdoptionRequest(
            id: evento.idSolicitud,
            userId: evento.idPadrino,
            petId: evento.idMascota,
            applicantFirstName: partes.isEmpty ? evento.padrinoNombre : partes.first,
            applicantLastName: partes.length > 1 ? partes.skip(1).join(' ') : '',
            applicantEmail: evento.padrinoCorreo,
            applicantPhone: evento.padrinoTelefono,
            petName: evento.mascotaNombre,
            status: 'aprobada',
          ),
          onGuardadoExitoso: _recargar,
        ),
      ),
    );
  }

  Future<void> _verDetalles(
    AdopcionActivaSeguimiento item,
    Map<String, AdoptionRequest> porId,
  ) async {
    final solicitud = porId[item.idSolicitud];
    if (solicitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el detalle de esta adopción')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => _conBarra(
          onVolver: () => Navigator.pop(ctx),
          AdoptionDetailAdminScreen(
            request: solicitud,
            enPagina: true,
            onCambioEstado: (_) {
              Navigator.pop(context);
              _recargar();
            },
          ),
        ),
      ),
    );
  }

  void _verHistorial(AdopcionActivaSeguimiento item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.45,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FD),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Historial de ${item.mascotaNombre}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                              ),
                              Text(
                                'Adoptante: ${item.adoptanteNombre}',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        StarRatingBadge(
                          rating: item.calificacionPromedio,
                          totalSeguimientos: item.totalSeguimientos,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder<List<SeguimientoAdopcionItem>>(
                      future: SeguimientoAdopcionService.obtenerHistorial(item.idSolicitud),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              snap.error.toString().replaceFirst('Exception: ', ''),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        final lista = List<SeguimientoAdopcionItem>.from(snap.data ?? [])
                          ..sort((a, b) => b.numeroSeguimiento.compareTo(a.numeroSeguimiento));
                        final calificacionNegativa = lista.any(
                          (seg) => seg.calificacion == 1 || seg.calificacion == 2,
                        );
                        if (lista.isEmpty) {
                          return ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                            children: [
                              if (!item.adopcionCancelada)
                                _botonCancelar(item, habilitado: false),
                              const SizedBox(height: 24),
                              Text(
                                'No se han registrado seguimientos para esta adopción.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          );
                        }
                        return ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: [
                            if (!item.adopcionCancelada) ...[
                              _botonCancelar(item, habilitado: calificacionNegativa),
                              const SizedBox(height: 10),
                            ],
                            _barraReporte(context, item, lista),
                            const SizedBox(height: 12),
                            Text(
                              lista.length == 1
                                  ? 'Seguimiento 1'
                                  : 'Seguimientos 1 a ${lista.length}',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.texto),
                            ),
                            const SizedBox(height: 8),
                            ...lista.map(_tarjetaHistorial),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Uint8List?> _bytesReporte(
    BuildContext ctx,
    AdopcionActivaSeguimiento adopcion,
    List<SeguimientoAdopcionItem> seguimientos,
  ) async {
    final navegador = Navigator.of(ctx, rootNavigator: true);
    var dialogoCerrado = false;
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).whenComplete(() => dialogoCerrado = true);
    await Future<void>.delayed(Duration.zero);
    try {
      CancelacionAdopcion? cancelacion;
      if (adopcion.adopcionCancelada) {
        cancelacion = await SeguimientoAdopcionService.obtenerCancelacion(adopcion.idSolicitud);
      }
      return await ReporteAdopcionPdfService.construir(
        adopcion: adopcion,
        seguimientos: seguimientos,
        cancelacion: cancelacion,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return null;
    } finally {
      if (!dialogoCerrado) navegador.pop();
    }
  }

  void _verMotivo(AdopcionActivaSeguimiento item) {
    final futuro = SeguimientoAdopcionService.obtenerCancelacion(item.idSolicitud);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          maxChildSize: 0.95,
          minChildSize: 0.45,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FD),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: FutureBuilder<CancelacionAdopcion>(
                future: futuro,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError || snap.data == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          snap.error?.toString().replaceFirst('Exception: ', '') ??
                              'No se pudo cargar el motivo',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final datos = snap.data!;
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Text(
                        'Cancelación de ${item.mascotaNombre}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registró: ${datos.adminNombre}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      _datoCancelacion('Fecha de cancelación', _formatearFecha(datos.fechaCancelacion)),
                      _datoCancelacion('Motivo', datos.motivo),
                      _datoCancelacion('Observación', datos.observacion),
                      _datoCancelacion(
                        'Cuenta del adoptante',
                        datos.inhabilitarCuenta ? 'Inhabilitada' : 'Se mantiene activa',
                      ),
                      if (datos.foto1 != null || datos.foto2 != null) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Fotografías',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.texto),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (datos.foto1 != null)
                              _miniFoto(datos.foto1!, _nombreEvidencia(datos.foto1!, 1)),
                            if (datos.foto1 != null && datos.foto2 != null) const SizedBox(width: 8),
                            if (datos.foto2 != null)
                              _miniFoto(datos.foto2!, _nombreEvidencia(datos.foto2!, 2)),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _abrirCancelacion(AdopcionActivaSeguimiento item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CancelacionAdopcionForm(
          idSolicitud: item.idSolicitud,
          nombreMascota: item.mascotaNombre,
          fotoMascota: item.fotoPrincipal,
          adoptanteNombre: item.adoptanteNombre,
          inicioTexto: _fechaCorta(item.fechaInicio),
          totalSeguimientos: item.totalSeguimientos,
          onGuardadoExitoso: () {
            Navigator.of(context).pop();
            _recargar();
          },
        ),
      ),
    );
  }

  Widget _botonCancelar(AdopcionActivaSeguimiento item, {required bool habilitado}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: habilitado ? AppColors.rosa : Colors.grey.shade400,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          if (!habilitado) {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                content: const Text(
                  'Se habilitará esta opción cuando se califique de forma negativa al adoptante',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            );
            return;
          }
          _abrirCancelacion(item);
        },
        child: const Text(
          'Cancelar Adopción',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _barraReporte(
    BuildContext ctx,
    AdopcionActivaSeguimiento item,
    List<SeguimientoAdopcionItem> lista,
  ) {
    final boton = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E5EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: AppColors.rosa, size: 22),
              SizedBox(width: 8),
              Text(
                'Reporte de Seguimiento',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: boton.copyWith(
                    foregroundColor: const WidgetStatePropertyAll(AppColors.rosa),
                    side: const WidgetStatePropertyAll(BorderSide(color: AppColors.rosa)),
                  ),
                  onPressed: () async {
                    final bytes = await _bytesReporte(ctx, item, lista);
                    if (bytes == null) return;
                    await Printing.layoutPdf(
                      onLayout: (_) async => bytes,
                      name: ReporteAdopcionPdfService.nombreArchivo(item.mascotaNombre),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const FittedBox(child: Text('Ver')),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton.icon(
                  style: boton.copyWith(
                    backgroundColor: const WidgetStatePropertyAll(AppColors.rosa),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  ),
                  onPressed: () async {
                    final bytes = await _bytesReporte(ctx, item, lista);
                    if (bytes == null) return;
                    await Printing.sharePdf(
                      bytes: bytes,
                      filename: ReporteAdopcionPdfService.nombreArchivo(item.mascotaNombre),
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 15),
                  label: const FittedBox(child: Text('Descargar')),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  style: boton.copyWith(
                    foregroundColor: const WidgetStatePropertyAll(AppColors.rosa),
                    side: const WidgetStatePropertyAll(BorderSide(color: AppColors.rosa)),
                  ),
                  onPressed: () async {
                    final bytes = await _bytesReporte(ctx, item, lista);
                    if (bytes == null || !ctx.mounted) return;
                    final total = lista.length;
                    final abrio = await compartirActaPorWhatsApp(
                      bytes: bytes,
                      nombreArchivo: ReporteAdopcionPdfService.nombreArchivo(item.mascotaNombre),
                      mensaje:
                          'Hola, te comparto el reporte de seguimiento de adopción de ${item.mascotaNombre} '
                          '($total ${total == 1 ? 'visita registrada' : 'visitas registradas'}).',
                    );
                    if (!mounted || abrio) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No se pudo adjuntar el PDF. Ábrelo desde el celular para compartirlo con el documento.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 15),
                  label: const FittedBox(child: Text('Compartir')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datoCancelacion(String etiqueta, String valor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0E5EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 3),
          Text(valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.texto)),
        ],
      ),
    );
  }

  Widget _miniFoto(String ruta, String nombre) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _abrirFoto(ruta, nombre),
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Image.network(
              urlFoto(ruta),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFF4F4F4),
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _abrirFoto(String ruta, String nombre) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) {
        var descargando = false;
        return StatefulBuilder(
          builder: (ctx, setDialogo) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(ctx).height * 0.68,
                          maxWidth: 520,
                        ),
                        child: Image.network(
                          urlFoto(ruta),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Colors.white,
                            child: SizedBox(
                              height: 180,
                              child: Center(child: Icon(Icons.broken_image_outlined, size: 40)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosa,
                      minimumSize: const Size(180, 44),
                    ),
                    onPressed: descargando
                        ? null
                        : () async {
                            setDialogo(() => descargando = true);
                            await _descargarFoto(ruta, nombre);
                            if (ctx.mounted) setDialogo(() => descargando = false);
                          },
                    icon: descargando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      'Descargar foto',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _descargarFoto(String ruta, String nombre) async {
    try {
      final res = await http.get(Uri.parse(urlFoto(ruta)));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw Exception('No se pudo descargar la foto');
      }
      final ext = nombre.contains('.') ? nombre.split('.').last.toLowerCase() : 'jpg';
      final mime = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'bmp' => 'image/bmp',
        _ => 'image/jpeg',
      };
      await FilePicker.saveFile(
        fileName: nombre,
        bytes: res.bodyBytes,
        mimeType: mime,
        dialogTitle: 'Descargar foto',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  String _nombreEvidencia(String ruta, int numero) {
    final limpia = ruta.split('?').first;
    final ext = limpia.contains('.') ? limpia.split('.').last.toLowerCase() : 'jpg';
    final segura = RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext) ? ext : 'jpg';
    return 'Cancelacion_foto_$numero.$segura';
  }

  String _nombreFoto(String ruta, int numero, String etiqueta) {
    final limpia = ruta.split('?').first;
    final ext = limpia.contains('.') ? limpia.split('.').last.toLowerCase() : 'jpg';
    final segura = RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext) ? ext : 'jpg';
    return 'Seguimiento_${numero}_$etiqueta.$segura';
  }

  Widget _tarjetaHistorial(SeguimientoAdopcionItem seg) {
    final alerta = !seg.cumplimiento || seg.calificacion <= 2;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alerta ? Colors.red.shade200 : const Color(0xFFF0E5EC),
          width: alerta ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.rosa.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Seguimiento ${seg.numeroSeguimiento}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    color: AppColors.rosa,
                  ),
                ),
              ),
              const Spacer(),
              StarRatingBadge(rating: seg.calificacion.toDouble(), compacto: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatearFecha(seg.fechaSeguimiento),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Peso: ${seg.pesoSaludable}/5 · Salud: ${seg.condicionSanitaria}/5\n'
            'Entorno: ${seg.entornoApto}/5 · Conducta: ${seg.comportamiento}/5\n'
            'Vacunas: ${etiquetaRespuestaSeguimiento(seg.compromisoVeterinario)} · '
            'Trato: ${etiquetaRespuestaSeguimiento(seg.disposicionAdoptante)}',
            style: TextStyle(fontSize: 12.5, height: 1.35, color: Colors.grey.shade800),
          ),
          if (seg.fotoEstado != null || (seg.fotoEntorno != null && seg.fotoEntorno!.isNotEmpty)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (seg.fotoEstado != null && seg.fotoEstado!.isNotEmpty)
                  _miniFoto(seg.fotoEstado!, _nombreFoto(seg.fotoEstado!, seg.numeroSeguimiento, 'estado')),
                if (seg.fotoEntorno != null && seg.fotoEntorno!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _miniFoto(seg.fotoEntorno!, _nombreFoto(seg.fotoEntorno!, seg.numeroSeguimiento, 'entorno')),
                ],
              ],
            ),
          ],
          if (seg.observaciones.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(seg.observaciones, style: const TextStyle(fontSize: 13)),
          ],
          if (seg.proximoSeguimiento != null) ...[
            const SizedBox(height: 6),
            Text(
              'Próximo: ${_formatearFecha(seg.proximoSeguimiento)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.texto),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Registró: ${seg.adminNombre}',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin registro';
    return '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';
  }

  String _fechaCorta(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return _conBarra(
      Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0E5EC)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.rosa,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.rosa,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: [
                Tab(
                  icon: const Icon(Icons.list_alt_rounded),
                  text: _verCanceladas ? 'Adopciones Canceladas' : 'Adopciones activas',
                ),
                const Tab(icon: Icon(Icons.calendar_month_rounded), text: 'Próximos seguimientos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _construirPestanaLista(),
                _construirPestanaCalendario(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirPestanaLista() {
    return FutureBuilder<List<AdopcionActivaSeguimiento>>(
      future: _futureActivas,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorCarga(
            mensaje: 'No pudimos cargar las adopciones en seguimiento',
            detalle: snap.error.toString().replaceFirst('Exception: ', ''),
            onReintentar: _recargar,
          );
        }

        final mascotas = _filtrar(snap.data ?? [])
            .where((item) => item.adopcionCancelada == _verCanceladas)
            .toList();
        return FutureBuilder<Map<String, AdoptionRequest>>(
          future: _futureSolicitudes,
          builder: (context, solSnap) {
            final porId = solSnap.data ?? const <String, AdoptionRequest>{};
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: TextField(
                    onChanged: (valor) => setState(() => _busqueda = valor),
                    decoration: InputDecoration(
                      hintText: 'Buscar mascota o adoptante...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.rosa),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFF0E5EC)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFF0E5EC)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${mascotas.length} '
                        '${_verCanceladas ? (mascotas.length == 1 ? 'adopción cancelada' : 'adopciones canceladas') : (mascotas.length == 1 ? 'adopción activa' : 'adopciones activas')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.texto,
                          fontSize: 13.5,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () => setState(() => _verCanceladas = !_verCanceladas),
                        icon: Icon(
                          _verCanceladas ? Icons.favorite_rounded : Icons.heart_broken_rounded,
                          size: 16,
                          color: AppColors.rosa,
                        ),
                        label: Text(
                          _verCanceladas ? 'Ver Activas' : 'Ver Canceladas',
                          style: const TextStyle(fontSize: 12, color: AppColors.rosa),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _recargar,
                    child: mascotas.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 80),
                              _Vacio(
                                texto: _verCanceladas
                                    ? 'No hay adopciones canceladas.'
                                    : 'No hay adopciones activas con el contrato de adopción subido.',
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: mascotas.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = mascotas[index];
                              return _TarjetaAdopcion(
                                item: item,
                                formatearFecha: _formatearFecha,
                                onVerDetalles: () => _verDetalles(item, porId),
                                onSeguimiento: item.adopcionCancelada
                                    ? () => _verMotivo(item)
                                    : () => _realizarSeguimiento(item, porId),
                                onVerHistorial: () => _verHistorial(item),
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _construirPestanaCalendario() {
    return FutureBuilder<List<ItemCalendarioSeguimiento>>(
      future: _futureCalendario,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorCarga(
            mensaje: 'Error al cargar el calendario de seguimientos',
            detalle: snap.error.toString().replaceFirst('Exception: ', ''),
            onReintentar: _recargar,
          );
        }
        return CalendarioSeguimientosWidget(
          eventos: snap.data ?? [],
          onRecargar: _recargar,
          etiquetaPersona: 'Adoptante',
          onAbrirEvento: _abrirDesdeCalendario,
        );
      },
    );
  }
}

class _TarjetaAdopcion extends StatelessWidget {
  final AdopcionActivaSeguimiento item;
  final String Function(DateTime?) formatearFecha;
  final VoidCallback onVerDetalles;
  final VoidCallback? onSeguimiento;
  final VoidCallback onVerHistorial;

  const _TarjetaAdopcion({
    required this.item,
    required this.formatearFecha,
    required this.onVerDetalles,
    required this.onSeguimiento,
    required this.onVerHistorial,
  });

  @override
  Widget build(BuildContext context) {
    final proximoVencido = item.proximoSeguimientoVencido;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: proximoVencido ? Colors.orange.shade300 : const Color(0xFFF2E4EC),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: PetImage(url: item.fotoPrincipal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.mascotaNombre,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
                            ),
                          ),
                          StarRatingBadge(
                            rating: item.calificacionPromedio,
                            totalSeguimientos: item.totalSeguimientos,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (item.adopcionCancelada) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.rosaSuave,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.rosa),
                          ),
                          child: const Text(
                            'Adopción Cancelada',
                            style: TextStyle(
                              color: AppColors.rosa,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        item.resumenMascota,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Adoptante: ${item.adoptanteNombre}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.texto,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!item.adopcionCancelada)
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFECEFF5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Seguimientos realizados: ${item.totalSeguimientos}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: AppColors.texto,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (!item.adopcionCancelada)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFECEFF5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 5),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Último seguimiento',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey),
                            ),
                            Text(
                              formatearFecha(item.ultimoSeguimientoFecha),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.alarm,
                          size: 15,
                          color: proximoVencido ? Colors.red.shade700 : Colors.purple.shade400,
                        ),
                        const SizedBox(width: 5),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              proximoVencido ? 'Próximo (¡Vencido!)' : 'Próximo seguimiento',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: proximoVencido ? Colors.red.shade700 : Colors.grey,
                                fontWeight: proximoVencido ? FontWeight.w700 : FontWeight.normal,
                              ),
                            ),
                            Text(
                              formatearFecha(item.proximoSeguimientoFecha),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: proximoVencido ? Colors.red.shade900 : AppColors.texto,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rosa,
                      side: const BorderSide(color: AppColors.rosa),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onVerHistorial,
                    child: const Text(
                      'Historial',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: item.adopcionCancelada ? 1 : 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: onSeguimiento == null ? Colors.grey.shade400 : AppColors.rosa,
                      disabledBackgroundColor: Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onSeguimiento,
                    child: Text(
                      item.adopcionCancelada ? 'Ver Motivo' : 'Realizar seguimiento',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onVerDetalles,
                child: const Text(
                  'Ver detalles de adopción',
                  style: TextStyle(color: AppColors.rosa, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final String texto;

  const _Vacio({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Icon(Icons.pets_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  final String mensaje;
  final String detalle;
  final VoidCallback onReintentar;

  const _ErrorCarga({
    required this.mensaje,
    required this.detalle,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.rosa),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
