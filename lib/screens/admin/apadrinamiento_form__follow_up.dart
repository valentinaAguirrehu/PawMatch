import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/seguimiento_apadrinamiento.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/reporte_padrino_pdf_service.dart';
import 'package:paw_match/services/seguimiento_apadrinamiento_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';
import 'package:paw_match/widgets/star_rating_selector.dart';
import 'package:paw_match/widgets/tarjeta_seguimiento.dart';

/// Formulario para registrar el seguimiento de un apadrinamiento activo.
class ApadrinamientoFormFollowUp extends StatefulWidget {
  final Pet mascota;
  final SolicitudApadrinamiento solicitud;
  final VoidCallback? onGuardadoExitoso;

  const ApadrinamientoFormFollowUp({
    super.key,
    required this.mascota,
    required this.solicitud,
    this.onGuardadoExitoso,
  });

  @override
  State<ApadrinamientoFormFollowUp> createState() =>
      _ApadrinamientoFormFollowUpState();
}

class _ApadrinamientoFormFollowUpState
    extends State<ApadrinamientoFormFollowUp> {
  final _formKey = GlobalKey<FormState>();
  final _observacionesCtrl = TextEditingController();

  // Fecha de seguimiento: fija por defecto a hoy (no editable)
  final DateTime _fechaHoy = DateTime.now();

  // Calificación en estrellas (1 a 5, obligatoria)
  int _calificacion = 5;

  // Próximo seguimiento programado
  DateTime? _proximoSeguimiento;

  bool _guardando = false;
  late Future<List<SeguimientoApadrinamientoItem>> _historialFuture;

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  void initState() {
    super.initState();
    _historialFuture =
        SeguimientoApadrinamientoService.obtenerHistorial(widget.solicitud.id);
  }

  @override
  void dispose() {
    _observacionesCtrl.dispose();
    super.dispose();
  }

  String _fechaTexto(DateTime fecha) =>
      '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';

  Future<void> _elegirProximoSeguimiento() async {
    final manana = DateTime.now().add(const Duration(days: 1));
    final elegida = await showDatePicker(
      context: context,
      initialDate: _proximoSeguimiento ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: manana,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('es', 'ES'),
      helpText: 'Seleccionar fecha del próximo seguimiento',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (elegida == null || !mounted) return;
    setState(() => _proximoSeguimiento = elegida);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_calificacion < 1 || _calificacion > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Por favor califica con al menos 1 estrella.'),
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final res = await SeguimientoApadrinamientoService.crearSeguimiento(
        idSolicitud: widget.solicitud.id,
        calificacion: _calificacion,
        cumplimiento: _calificacion >= 3,
        observaciones: _observacionesCtrl.text.trim(),
        proximoSeguimiento: _proximoSeguimiento,
      );

      if (!mounted) return;

      final tieneTres = res['tieneTresIncumplimientos'] == true;
      final correoEnviado = res['correoAlertaEnviado'] == true;

      if (tieneTres) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Alerta de Incumplimiento',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Este padrino ha acumulado 3 seguimientos consecutivos con incumplimiento (calificación ≤ 2 o incumplimiento).',
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.email_outlined, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          correoEnviado
                              ? 'Se envió automáticamente un correo de advertencia al padrino.'
                              : 'Notificación de alerta generada.',
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.rosa,
            content: Text('Seguimiento de ${widget.mascota.nombre} registrado con éxito'),
          ),
        );
      }

      widget.onGuardadoExitoso?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (!confirmar || !mounted) return;
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    Session.cerrar();
    Navegacion.ir(context, const WelcomeScreen());
  }

  InputDecoration _decoracion(String etiqueta) {
    return InputDecoration(
      labelText: etiqueta,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E4EE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E4EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.rosa, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mascota = widget.mascota;
    final solicitud = widget.solicitud;
    final aporte = solicitud.montoAporte == null
        ? solicitud.tipoAporte
        : '\$${solicitud.montoAporte} · ${solicitud.frecuenciaAporte}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            BarraSuperior(
              iconoTitulo: Icons.rate_review_rounded,
              titulo: 'Registrar Seguimiento',
              onVolver: () => Navigator.of(context).pop(),
              onCerrarSesion: _confirmarCerrarSesion,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  // Tarjeta informativa de la mascota y padrino
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 68,
                              height: 68,
                              child: PetImage(url: mascota.foto),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mascota.nombre,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Padrino: ${solicitud.solicitanteNombreCompleto}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Aporte: $aporte',
                                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Formulario principal
                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Datos del nuevo seguimiento',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.texto,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Fecha del seguimiento (Hoy, no editable)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_clock_outlined, size: 20, color: Colors.grey),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Fecha de seguimiento (automática)',
                                        style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        _fechaTexto(_fechaHoy),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                          color: AppColors.texto,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Hoy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Calificación con 5 estrellas tocables (Obligatoria)
                            const Text(
                              'Calificación del padrino *',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Toca las estrellas para evaluar el cumplimiento (1 a 5)',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: StarRatingSelector(
                                rating: _calificacion,
                                starSize: 38,
                                mostrarEtiqueta: true,
                                onRatingChanged: (nuevaCalificacion) {
                                  setState(() {
                                    _calificacion = nuevaCalificacion;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Observaciones
                            TextFormField(
                              controller: _observacionesCtrl,
                              maxLines: 3,
                              decoration: _decoracion('Observaciones del seguimiento'),
                              validator: (valor) {
                                if (_calificacion <= 2 && (valor == null || valor.trim().isEmpty)) {
                                  return 'Por favor explica en las observaciones el motivo de la baja calificación.';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 18),

                            // Próximo seguimiento (Date Picker)
                            InkWell(
                              onTap: _elegirProximoSeguimiento,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _proximoSeguimiento != null ? AppColors.rosa : const Color(0xFFE2E4EE),
                                    width: _proximoSeguimiento != null ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.event_rounded, color: AppColors.rosa),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Próximo seguimiento programado',
                                            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            _proximoSeguimiento == null
                                                ? 'Toca para elegir fecha en el calendario'
                                                : _fechaTexto(_proximoSeguimiento!),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: _proximoSeguimiento == null ? Colors.grey : AppColors.texto,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_proximoSeguimiento != null)
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                        onPressed: () => setState(() => _proximoSeguimiento = null),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Botón Guardar
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.rosa,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _guardando ? null : _guardar,
                                child: _guardando
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text(
                                        'Guardar Seguimiento',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sección de historial previo de seguimientos
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Historial de seguimientos anteriores',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.texto,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  FutureBuilder<List<SeguimientoApadrinamientoItem>>(
                    future: _historialFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      final items = snap.data ?? [];
                      if (items.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Aún no se han registrado seguimientos para esta apadrinación.',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'El reporte se habilita a partir de 3 seguimientos (0/3)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: items.length >= 3
                                ? FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.rosa,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                    ),
                                    onPressed: () {
                                      ReportePadrinoPdfService.generarYDescargarReporte(
                                        padrinoNombre: widget.solicitud.solicitanteNombreCompleto,
                                        padrinoCorreo: widget.solicitud.solicitanteCorreo,
                                        padrinoTelefono: widget.solicitud.solicitanteTelefono,
                                        mascotaNombre: widget.mascota.nombre,
                                        mascotaEspecie: widget.mascota.especie,
                                        mascotaRaza: widget.mascota.raza,
                                        mascotaEdad: '${widget.mascota.edad} ${widget.mascota.unidadEdad}',
                                        seguimientos: items,
                                        estadoApadrinamiento: widget.solicitud.estado,
                                      );
                                    },
                                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                                    label: const Text(
                                      'Descargar reporte PDF',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade700),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'El reporte se habilita a partir de 3 seguimientos (${items.length}/3)',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          ...items.map((it) => TarjetaSeguimiento(seguimiento: it)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
