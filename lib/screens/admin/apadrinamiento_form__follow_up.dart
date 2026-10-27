import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/seguimiento_apadrinamiento.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/seguimiento_apadrinamiento_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/star_rating_selector.dart';
import 'package:paw_match/widgets/tarjeta_seguimiento.dart';

/// Formulario para registrar el seguimiento de un apadrinamiento activo con revisión de aportes.
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

  // Fecha de seguimiento: fija por defecto a hoy
  final DateTime _fechaHoy = DateTime.now();

  // Calificación en estrellas (1 a 5, obligatoria)
  int _calificacion = 5;

  // Próximo seguimiento programado
  DateTime? _proximoSeguimiento;

  bool _guardando = false;
  late Future<List<SeguimientoApadrinamientoItem>> _historialFuture;

  // Control de ciclo actual y bloqueo si está en 3/3 sin evaluar
  bool _bloqueadoPorEvaluacionPendiente = false;

  // Estados de aportes comprometidos
  bool _aportaMonetarioPrometido = false;
  bool _recibioMonetario = true;
  String _medioMonetario = 'transferencia';
  final _montoRecibidoCtrl = TextEditingController();
  final _referenciaMonetarioCtrl = TextEditingController();
  final _observacionMonetarioCtrl = TextEditingController();

  bool _aportaEspeciePrometido = false;
  bool _recibioEspecie = true;
  final _detalleEspecieCtrl = TextEditingController();
  final _observacionEspecieCtrl = TextEditingController();

  bool _aportaOtroPrometido = false;
  bool _recibioOtro = true;
  final _detalleOtroCtrl = TextEditingController();
  final _observacionOtroCtrl = TextEditingController();

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  void initState() {
    super.initState();
    final sol = widget.solicitud;

    // Detectar qué aportes fueron comprometidos
    _aportaMonetarioPrometido = sol.aportaMonetario ||
        (sol.montoComprometido != null && sol.montoComprometido! > 0) ||
        (sol.montoAporte != null && sol.montoAporte! > 0) ||
        sol.tipoAporte.toLowerCase().contains('monetario');

    _aportaEspeciePrometido = sol.aportaEspecie ||
        (sol.detalleEspecie != null && sol.detalleEspecie!.trim().isNotEmpty) ||
        sol.tipoAporte.toLowerCase().contains('especie');

    _aportaOtroPrometido = sol.aportaOtro ||
        (sol.detalleOtro != null && sol.detalleOtro!.trim().isNotEmpty) ||
        sol.tipoAporte.toLowerCase().contains('otro');

    // Inicializar montos y detalles por defecto si aplican
    if (_aportaMonetarioPrometido) {
      final monto = sol.montoComprometido?.toStringAsFixed(0) ??
          sol.montoAporte?.toString() ??
          '';
      _montoRecibidoCtrl.text = monto;
    }
    if (_aportaEspeciePrometido && sol.detalleEspecie != null) {
      _detalleEspecieCtrl.text = sol.detalleEspecie!.trim();
    }
    if (_aportaOtroPrometido && sol.detalleOtro != null) {
      _detalleOtroCtrl.text = sol.detalleOtro!.trim();
    }

    _historialFuture =
        SeguimientoApadrinamientoService.obtenerHistorial(widget.solicitud.id)
          ..then((items) {
            if (!mounted) return;
            // Verificar si el ciclo actual completó 3 y no ha sido evaluado
            final total = items.length;
            if (total > 0 && total % 3 == 0) {
              final maxCiclo = (total + 2) ~/ 3;
              final yaEvaluado = sol.evaluacionesCiclos.any((e) => e.ciclo == maxCiclo);
              if (!yaEvaluado) {
                setState(() => _bloqueadoPorEvaluacionPendiente = true);
              }
            }
          });
  }

  @override
  void dispose() {
    _observacionesCtrl.dispose();
    _montoRecibidoCtrl.dispose();
    _referenciaMonetarioCtrl.dispose();
    _observacionMonetarioCtrl.dispose();
    _detalleEspecieCtrl.dispose();
    _observacionEspecieCtrl.dispose();
    _detalleOtroCtrl.dispose();
    _observacionOtroCtrl.dispose();
    super.dispose();
  }

  String _fechaTexto(DateTime fecha) =>
      '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';

  Future<void> _elegirProximoSeguimiento() async {
    // REGLA: El próximo seguimiento solo se elige desde el primer día del mes siguiente
    final primerDiaMesSiguiente =
        DateTime(_fechaHoy.year, _fechaHoy.month + 1, 1);
    final fechaInicial = (_proximoSeguimiento != null &&
            _proximoSeguimiento!.isAfter(primerDiaMesSiguiente))
        ? _proximoSeguimiento!
        : primerDiaMesSiguiente;

    final elegida = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: primerDiaMesSiguiente,
      lastDate: DateTime(_fechaHoy.year + 2, 12, 31),
      locale: const Locale('es', 'ES'),
      helpText: 'Seleccionar fecha del próximo seguimiento',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (elegida == null || !mounted) return;
    setState(() => _proximoSeguimiento = elegida);
  }

  Future<void> _guardar() async {
    if (_bloqueadoPorEvaluacionPendiente) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Primero debes evaluar al padrino para cerrar el ciclo actual antes de registrar un nuevo seguimiento.',
          ),
        ),
      );
      return;
    }

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

    // Comprobar si algún aporte fue marcado como NO recibido
    final hayMonetarioNoRecibido = _aportaMonetarioPrometido && !_recibioMonetario;
    final hayEspecieNoRecibido = _aportaEspeciePrometido && !_recibioEspecie;
    final hayOtroNoRecibido = _aportaOtroPrometido && !_recibioOtro;
    final algunAporteNoRecibido =
        hayMonetarioNoRecibido || hayEspecieNoRecibido || hayOtroNoRecibido;

    // REGLA CAMBIO 3: Si se pone 4 o 5 estrellas pero se marca un aporte como no recibido,
    // mostrar aviso suave ("Marcaste un aporte como no recibido, ¿quieres revisar la calificación?")
    if (_calificacion >= 4 && algunAporteNoRecibido) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.orange.shade800, size: 26),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Aporte no recibido',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
            ],
          ),
          content: const Text(
            'Marcaste un aporte como no recibido, ¿quieres revisar la calificación?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), // Revisar
              child: const Text('Revisar calificación'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: () => Navigator.pop(ctx, true), // Continuar
              child: const Text('Continuar de todos modos'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;
    }

    // Construir lista de aportes a enviar
    final List<SeguimientoAporteItem> listaAportes = [];

    if (_aportaMonetarioPrometido) {
      final comprometido =
          '\$${widget.solicitud.montoComprometido?.toStringAsFixed(0) ?? widget.solicitud.montoAporte ?? 0} ${widget.solicitud.periodicidad ?? widget.solicitud.frecuenciaAporte}';
      listaAportes.add(
        SeguimientoAporteItem(
          idAporte: '',
          idSeguimiento: '',
          tipo: 'monetario',
          comprometido: comprometido,
          recibido: _recibioMonetario,
          medio: _recibioMonetario ? _medioMonetario : null,
          montoRecibido: _recibioMonetario
              ? double.tryParse(_montoRecibidoCtrl.text.trim())
              : null,
          referencia: _recibioMonetario
              ? _referenciaMonetarioCtrl.text.trim()
              : null,
          observacion: !_recibioMonetario
              ? _observacionMonetarioCtrl.text.trim()
              : null,
        ),
      );
    }

    if (_aportaEspeciePrometido) {
      final comprometido = widget.solicitud.detalleEspecie ?? 'Aporte en especie';
      listaAportes.add(
        SeguimientoAporteItem(
          idAporte: '',
          idSeguimiento: '',
          tipo: 'especie',
          comprometido: comprometido,
          recibido: _recibioEspecie,
          detalleRecibido: _recibioEspecie
              ? _detalleEspecieCtrl.text.trim()
              : null,
          observacion: !_recibioEspecie
              ? _observacionEspecieCtrl.text.trim()
              : null,
        ),
      );
    }

    if (_aportaOtroPrometido) {
      final comprometido = widget.solicitud.detalleOtro ?? 'Otro tipo de ayuda';
      listaAportes.add(
        SeguimientoAporteItem(
          idAporte: '',
          idSeguimiento: '',
          tipo: 'otro',
          comprometido: comprometido,
          recibido: _recibioOtro,
          detalleRecibido: _recibioOtro
              ? _detalleOtroCtrl.text.trim()
              : null,
          observacion: !_recibioOtro
              ? _observacionOtroCtrl.text.trim()
              : null,
        ),
      );
    }

    setState(() => _guardando = true);
    try {
      final res = await SeguimientoApadrinamientoService.crearSeguimiento(
        idSolicitud: widget.solicitud.id,
        calificacion: _calificacion,
        cumplimiento: _calificacion >= 3,
        observaciones: _observacionesCtrl.text.trim(),
        proximoSeguimiento: _proximoSeguimiento,
        aportes: listaAportes,
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

  Widget _construirTarjetaAporteMonetario() {
    final sol = widget.solicitud;
    final comprometidoStr =
        '\$${sol.montoComprometido?.toStringAsFixed(0) ?? sol.montoAporte ?? 0} ${sol.periodicidad ?? sol.frecuenciaAporte}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _recibioMonetario ? const Color(0xFFF9FAFC) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _recibioMonetario ? const Color(0xFFE2E4EE) : Colors.red.shade300,
          width: _recibioMonetario ? 1 : 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payments_rounded,
                color: _recibioMonetario ? AppColors.rosa : Colors.red.shade700,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aporte monetario comprometido: $comprometidoStr',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('¿Se recibió el aporte monetario? *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Sí, recibido'),
                selected: _recibioMonetario,
                selectedColor: Colors.green.shade100,
                labelStyle: TextStyle(
                  color: _recibioMonetario ? Colors.green.shade900 : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) => setState(() => _recibioMonetario = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('No recibido'),
                selected: !_recibioMonetario,
                selectedColor: Colors.red.shade100,
                labelStyle: TextStyle(
                  color: !_recibioMonetario ? Colors.red.shade900 : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) => setState(() => _recibioMonetario = false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recibioMonetario) ...[
            DropdownButtonFormField<String>(
              value: _medioMonetario,
              decoration: _decoracion('Medio de pago'),
              items: const [
                DropdownMenuItem(value: 'transferencia', child: Text('Transferencia bancaria')),
                DropdownMenuItem(value: 'consignación', child: Text('Consignación')),
                DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                DropdownMenuItem(value: 'otro', child: Text('Otro medio')),
              ],
              onChanged: (v) => setState(() => _medioMonetario = v ?? 'transferencia'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _montoRecibidoCtrl,
              keyboardType: TextInputType.number,
              decoration: _decoracion('Monto recibido (\$)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _referenciaMonetarioCtrl,
              decoration: _decoracion('Referencia o comprobante (Opcional)'),
            ),
          ] else ...[
            TextFormField(
              controller: _observacionMonetarioCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Motivo u observación del no pago (Opcional)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirTarjetaAporteEspecie() {
    final sol = widget.solicitud;
    final comprometidoStr = sol.detalleEspecie ?? 'Concentrado, medicina o insumos';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _recibioEspecie ? const Color(0xFFF9FAFC) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _recibioEspecie ? const Color(0xFFE2E4EE) : Colors.red.shade300,
          width: _recibioEspecie ? 1 : 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_rounded,
                color: _recibioEspecie ? AppColors.rosa : Colors.red.shade700,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aporte en especie comprometido: $comprometidoStr',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('¿Se recibió el aporte en especie? *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Sí, recibido'),
                selected: _recibioEspecie,
                selectedColor: Colors.green.shade100,
                labelStyle: TextStyle(
                  color: _recibioEspecie ? Colors.green.shade900 : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) => setState(() => _recibioEspecie = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('No recibido'),
                selected: !_recibioEspecie,
                selectedColor: Colors.red.shade100,
                labelStyle: TextStyle(
                  color: !_recibioEspecie ? Colors.red.shade900 : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) => setState(() => _recibioEspecie = false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recibioEspecie) ...[
            TextFormField(
              controller: _detalleEspecieCtrl,
              decoration: _decoracion('Qué se recibió (ej. 1 bulto de alimento 15kg)'),
            ),
          ] else ...[
            TextFormField(
              controller: _observacionEspecieCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Motivo de no entrega (Opcional)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirTarjetaAporteOtro() {
    final sol = widget.solicitud;
    final comprometidoStr = sol.detalleOtro ?? 'Paseos, visitas o transporte';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _recibioOtro ? const Color(0xFFF9FAFC) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _recibioOtro ? const Color(0xFFE2E4EE) : Colors.red.shade300,
          width: _recibioOtro ? 1 : 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.volunteer_activism_rounded,
                color: _recibioOtro ? AppColors.rosa : Colors.red.shade700,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Otra ayuda comprometida: $comprometidoStr',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('¿Se cumplió la ayuda comprometida? *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Sí, cumplió'),
                selected: _recibioOtro,
                selectedColor: Colors.green.shade100,
                labelStyle: TextStyle(
                  color: _recibioOtro ? Colors.green.shade900 : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) => setState(() => _recibioOtro = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('No cumplió'),
                selected: !_recibioOtro,
                selectedColor: Colors.red.shade100,
                labelStyle: TextStyle(
                  color: !_recibioOtro ? Colors.red.shade900 : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) => setState(() => _recibioOtro = false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recibioOtro) ...[
            TextFormField(
              controller: _detalleOtroCtrl,
              decoration: _decoracion('En qué consistió la ayuda cumplida'),
            ),
          ] else ...[
            TextFormField(
              controller: _observacionOtroCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Motivo del no cumplimiento (Opcional)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mascota = widget.mascota;
    final solicitud = widget.solicitud;
    final tieneAportes =
        _aportaMonetarioPrometido || _aportaEspeciePrometido || _aportaOtroPrometido;

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
                  // Banner de advertencia si el ciclo actual está en 3/3 y falta evaluación
                  if (_bloqueadoPorEvaluacionPendiente)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade400, width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_clock_rounded, color: Colors.red.shade800, size: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ciclo completado (3/3)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Primero debes evaluar al padrino para cerrar el ciclo actual antes de registrar un nuevo seguimiento.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.red.shade900,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Tarjeta informativa de la mascota y padrino
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFFE2E4EE)),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.rosa.withValues(alpha: 0.15),
                            child: ClipOval(
                              child: mascota.foto != null && mascota.foto!.isNotEmpty
                                  ? Image.network(
                                      mascota.foto!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.pets, color: AppColors.rosa),
                                    )
                                  : const Icon(Icons.pets, color: AppColors.rosa),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mascota.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: AppColors.texto,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Padrino: ${solicitud.solicitanteNombreCompleto}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  solicitud.solicitanteCorreo,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Formulario de seguimiento
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFFE2E4EE)),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
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

                            // Fecha fija (hoy)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FD),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E4EE)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.today_rounded, color: AppColors.rosa),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Fecha de seguimiento (Fija)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        _fechaTexto(_fechaHoy),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
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
                                    child: const Text('Hoy',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

                            // SECCIÓN DE APORTES DEL PADRINO (CAMBIO 3)
                            if (tieneAportes) ...[
                              const Divider(height: 28),
                              const Text(
                                'Aportes del padrino',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Revisa los aportes acordados por el padrino para este periodo:',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 12),
                              if (_aportaMonetarioPrometido)
                                _construirTarjetaAporteMonetario(),
                              if (_aportaEspeciePrometido)
                                _construirTarjetaAporteEspecie(),
                              if (_aportaOtroPrometido)
                                _construirTarjetaAporteOtro(),
                              const Divider(height: 24),
                            ],

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

                            // Próximo seguimiento (Date Picker restringido desde el mes siguiente)
                            InkWell(
                              onTap: _elegirProximoSeguimiento,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _proximoSeguimiento != null
                                        ? AppColors.rosa
                                        : const Color(0xFFE2E4EE),
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
                                            'Próximo seguimiento programado (desde el mes siguiente)',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            _proximoSeguimiento == null
                                                ? 'Toca para elegir fecha en el calendario'
                                                : _fechaTexto(_proximoSeguimiento!),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: _proximoSeguimiento == null
                                                  ? Colors.grey
                                                  : AppColors.texto,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_proximoSeguimiento != null)
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                        onPressed: () =>
                                            setState(() => _proximoSeguimiento = null),
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
                                onPressed: (_guardando || _bloqueadoPorEvaluacionPendiente)
                                    ? null
                                    : _guardar,
                                child: _guardando
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text(
                                        'Guardar Seguimiento',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800, fontSize: 15),
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
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final items = snap.data ?? [];
                      if (items.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E4EE)),
                          ),
                          child: const Center(
                            child: Text(
                              'Aún no hay seguimientos registrados para este apadrinamiento.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: items
                            .map((seg) => TarjetaSeguimiento(seguimiento: seg))
                            .toList(),
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
