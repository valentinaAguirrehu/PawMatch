import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/seguimiento_apadrinamiento.dart';
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/screens/admin/apadrinamiento_form__follow_up.dart';
import 'package:paw_match/widgets/pet_card.dart';
import 'package:paw_match/widgets/star_rating_selector.dart';

/// Widget de Calendario de Próximos Seguimientos usando table_calendar.
class CalendarioSeguimientosWidget extends StatefulWidget {
  final List<ItemCalendarioSeguimiento> eventos;
  final VoidCallback onRecargar;

  const CalendarioSeguimientosWidget({
    super.key,
    required this.eventos,
    required this.onRecargar,
  });

  @override
  State<CalendarioSeguimientosWidget> createState() =>
      _CalendarioSeguimientosWidgetState();
}

class _CalendarioSeguimientosWidgetState
    extends State<CalendarioSeguimientosWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  String _mesNombre(int m) => _meses[(m - 1).clamp(0, 11)];

  @override
  void initState() {
    super.initState();
    _fijarPrimerPendiente();
  }

  @override
  void didUpdateWidget(covariant CalendarioSeguimientosWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventos.length != widget.eventos.length) {
      _fijarPrimerPendiente();
    }
  }

  void _fijarPrimerPendiente() {
    if (widget.eventos.isNotEmpty) {
      // Ordenamos por fecha de próximo seguimiento (la fecha más antigua entre los pendientes)
      final ordenados = List<ItemCalendarioSeguimiento>.from(widget.eventos)
        ..sort((a, b) => a.proximoSeguimiento.compareTo(b.proximoSeguimiento));
      final fechaMasAntigua = ordenados.first.proximoSeguimiento;
      _focusedDay = fechaMasAntigua;
      _selectedDay = fechaMasAntigua;
    } else {
      final ahora = DateTime.now();
      _focusedDay = ahora;
      _selectedDay = ahora;
    }
  }

  bool _mismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<ItemCalendarioSeguimiento> _eventosDelDia(DateTime day) {
    return widget.eventos.where((e) => _mismoDia(e.proximoSeguimiento, day)).toList();
  }

  List<ItemCalendarioSeguimiento> get _seguimientosVencidos {
    return widget.eventos.where((e) => e.esVencido).toList();
  }

  void _abrirFormularioSeguimiento(ItemCalendarioSeguimiento item) {
    // Convertir a Pet y SolicitudApadrinamiento para abrir el formulario
    final pet = Pet(
      id: item.idMascota,
      nombre: item.mascotaNombre,
      especie: item.mascotaEspecie,
      raza: item.mascotaRaza,
      edad: item.mascotaEdad,
      unidadEdad: item.mascotaUnidadEdad,
      foto: item.mascotaFotos is List && item.mascotaFotos.isNotEmpty
          ? item.mascotaFotos[0].toString()
          : item.mascotaFotos.toString(),
      estadoAdopcion: 'apadrinado',
    );

    final fotoStr = item.mascotaFotos is List && item.mascotaFotos.isNotEmpty
        ? item.mascotaFotos[0].toString()
        : item.mascotaFotos.toString();

    final solicitud = SolicitudApadrinamiento(
      id: item.idSolicitud,
      idMascota: item.idMascota,
      idUsuario: item.idPadrino,
      solicitanteNombres: item.padrinoNombre,
      solicitanteCorreo: item.padrinoCorreo,
      solicitanteTelefono: item.padrinoTelefono,
      mascotaNombre: item.mascotaNombre,
      mascotaFotos: fotoStr,
      mascotaEspecie: item.mascotaEspecie,
      mascotaRaza: item.mascotaRaza,
      mascotaEdad: item.mascotaEdad,
      tipoAporte: 'Aporte',
      frecuenciaAporte: 'mensual',
      motivacion: 'Apadrinamiento formalizado en seguimiento',
      estado: 'aprobada',
      fechaSolicitud: DateTime.now().toIso8601String(),
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApadrinamientoFormFollowUp(
          mascota: pet,
          solicitud: solicitud,
          onGuardadoExitoso: widget.onRecargar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seleccionados = _selectedDay == null ? <ItemCalendarioSeguimiento>[] : _eventosDelDia(_selectedDay!);
    final vencidos = _seguimientosVencidos;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        // Banner informativo de vencidos si existen
        if (vencidos.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade300, width: 1.2),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${vencidos.length} seguimiento(s) vencido(s)',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hay fechas límite pasadas sin nuevo seguimiento registrado.',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Tarjeta con el TableCalendar
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TableCalendar<ItemCalendarioSeguimiento>(
              firstDay: DateTime.utc(2023, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              locale: 'es_ES',
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              eventLoader: _eventosDelDia,
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: AppColors.rosa.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: AppColors.rosa,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                titleTextStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.texto,
                ),
                leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.rosa),
                rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.rosa),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppColors.rosa.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.rosa,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.texto,
                ),
                selectedTextStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppColors.rosa,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return null;
                  final tieneVencido = events.any((e) => e.esVencido);

                  return Positioned(
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: tieneVencido ? Colors.red.shade600 : AppColors.rosa,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${events.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Cabecera de la sección de eventos seleccionados
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDay == null
                  ? 'Seguimientos programados'
                  : 'Para el ${_selectedDay!.day} de ${_mesNombre(_selectedDay!.month)} de ${_selectedDay!.year}:',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.texto,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: seleccionados.isEmpty
                    ? Colors.grey.shade200
                    : AppColors.rosa.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${seleccionados.length} ${seleccionados.length == 1 ? 'pendiente' : 'pendientes'}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: seleccionados.isEmpty ? Colors.grey.shade700 : AppColors.rosa,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (seleccionados.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.event_available_rounded, size: 42, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'No hay seguimientos programados para este día.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
                ),
              ],
            ),
          )
        else
          ...seleccionados.map((item) {
            return _TarjetaEventoCalendario(
              item: item,
              onRegistrarSeguimiento: () => _abrirFormularioSeguimiento(item),
            );
          }),

        // Si hay vencidos y el día seleccionado no tiene, mostramos lista de vencidos para rápido acceso
        if (vencidos.isNotEmpty && seleccionados.isEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Seguimientos vencidos prioritarios:',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.red.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...vencidos.map((item) {
            return _TarjetaEventoCalendario(
              item: item,
              onRegistrarSeguimiento: () => _abrirFormularioSeguimiento(item),
            );
          }),
        ],
      ],
    );
  }
}

class _TarjetaEventoCalendario extends StatelessWidget {
  final ItemCalendarioSeguimiento item;
  final VoidCallback onRegistrarSeguimiento;

  const _TarjetaEventoCalendario({
    required this.item,
    required this.onRegistrarSeguimiento,
  });

  @override
  Widget build(BuildContext context) {
    final vencido = item.esVencido;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: vencido ? Colors.red.shade400 : const Color(0xFFF0E5EC),
          width: vencido ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: PetImage(
                      url: item.mascotaFotos is List && item.mascotaFotos.isNotEmpty
                          ? item.mascotaFotos[0].toString()
                          : item.mascotaFotos.toString(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.mascotaNombre,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                          if (vencido)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.shade400),
                              ),
                              child: Text(
                                'Vencido',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Padrino: ${item.padrinoNombre}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          StarRatingBadge(
                            rating: item.calificacionPromedio,
                            compacto: true,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Fecha: ${item.proximoSeguimiento.day}/${item.proximoSeguimiento.month}/${item.proximoSeguimiento.year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: vencido ? Colors.red.shade700 : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: vencido ? Colors.red.shade600 : AppColors.rosa,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: onRegistrarSeguimiento,
                icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                label: const Text(
                  'Realizar Seguimiento Ahora',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
