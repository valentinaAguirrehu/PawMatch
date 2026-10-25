import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Formulario para registrar el seguimiento de un apadrinamiento ya formalizado.
class ApadrinamientoFormFollowUp extends StatefulWidget {
  final Pet mascota;
  final SolicitudApadrinamiento solicitud;

  const ApadrinamientoFormFollowUp({
    super.key,
    required this.mascota,
    required this.solicitud,
  });

  @override
  State<ApadrinamientoFormFollowUp> createState() =>
      _ApadrinamientoFormFollowUpState();
}

class _ApadrinamientoFormFollowUpState extends State<ApadrinamientoFormFollowUp> {
  final _formKey = GlobalKey<FormState>();
  final _observacionesCtrl = TextEditingController();

  static const _medios = [
    'Visita domiciliaria',
    'WhatsApp',
    'Llamada telefónica',
  ];
  static const _estados = ['Bien', 'Regular', 'Requiere atención'];
  static const _adaptaciones = ['Buena', 'En proceso', 'Con dificultades'];

  DateTime _fecha = DateTime.now();
  DateTime? _proximo;
  String? _medio;
  String? _estado;
  String? _adaptacion;

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  void dispose() {
    _observacionesCtrl.dispose();
    super.dispose();
  }

  String _fechaTexto(DateTime fecha) =>
      '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';

  String _inicio() {
    final texto = widget.solicitud.fechaInicioApadrinamiento?.trim() ?? '';
    if (texto.isEmpty) return 'Sin fecha';
    final partes = texto.split(' ').first.split('-');
    if (partes.length != 3) return texto;
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  Future<void> _elegirFecha({required bool proximo}) async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: proximo ? (_proximo ?? ahora) : _fecha,
      firstDate: proximo ? DateTime(ahora.year, ahora.month, ahora.day) : DateTime(ahora.year - 2),
      lastDate: proximo ? DateTime(ahora.year + 2) : ahora,
      helpText: proximo ? 'Próximo seguimiento' : 'Fecha del seguimiento',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (elegida == null || !mounted) return;
    setState(() {
      if (proximo) {
        _proximo = elegida;
      } else {
        _fecha = elegida;
      }
    });
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.rosa,
        content: Text('Seguimiento de ${widget.mascota.nombre} registrado'),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (!confirmar || !mounted) return;
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    Session.cerrar();
    Navegacion.ir(context, const WelcomeScreen());
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
              iconoTitulo: Icons.favorite_rounded,
              titulo: 'Formulario',
              onCerrarSesion: _confirmarCerrarSesion,
              onVolver: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.rosaSuave,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.bordeRosa),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: PetImage(url: mascota.foto),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mascota.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Padrino: ${solicitud.solicitanteNombreCompleto}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.texto),
                                ),
                                Text(
                                  'Inicio: ${_inicio()}',
                                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                                ),
                                Text(
                                  'Aporte: $aporte',
                                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _FechaCampo(
                      etiqueta: 'Fecha del seguimiento',
                      valor: _fechaTexto(_fecha),
                      onTap: () => _elegirFecha(proximo: false),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _medio,
                      decoration: _decoracion('Medio de contacto'),
                      items: [
                        for (final medio in _medios)
                          DropdownMenuItem(value: medio, child: Text(medio)),
                      ],
                      onChanged: (valor) => setState(() => _medio = valor),
                      validator: (valor) =>
                          valor == null ? 'Elige cómo se hizo el seguimiento' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _estado,
                      decoration: _decoracion('Estado de la mascota'),
                      items: [
                        for (final estado in _estados)
                          DropdownMenuItem(value: estado, child: Text(estado)),
                      ],
                      onChanged: (valor) => setState(() => _estado = valor),
                      validator: (valor) =>
                          valor == null ? 'Indica cómo se encuentra la mascota' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _adaptacion,
                      decoration: _decoracion('Adaptación al hogar'),
                      items: [
                        for (final adaptacion in _adaptaciones)
                          DropdownMenuItem(value: adaptacion, child: Text(adaptacion)),
                      ],
                      onChanged: (valor) => setState(() => _adaptacion = valor),
                      validator: (valor) =>
                          valor == null ? 'Indica cómo se está adaptando' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _observacionesCtrl,
                      minLines: 4,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoracion('Observaciones del seguimiento'),
                      validator: (valor) {
                        if (valor == null || valor.trim().length < 10) {
                          return 'Escribe al menos una breve observación';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _FechaCampo(
                      etiqueta: 'Próximo seguimiento',
                      valor: _proximo == null ? 'Opcional' : _fechaTexto(_proximo!),
                      onTap: () => _elegirFecha(proximo: true),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosa,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _guardar,
                      child: const Text(
                        'Guardar seguimiento',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoracion(String etiqueta) {
    return InputDecoration(
      labelText: etiqueta,
      filled: true,
      fillColor: AppColors.rosaSuave,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _FechaCampo extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final VoidCallback onTap;

  const _FechaCampo({
    required this.etiqueta,
    required this.valor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.rosaSuave,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: AppColors.rosa, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiqueta,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    Text(
                      valor,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.texto,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
