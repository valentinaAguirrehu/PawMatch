import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/denuncia.dart';
import 'package:paw_match/services/denuncias_service.dart';
import 'package:paw_match/services/previsualizar_video.dart';

class DenunciaDetalleAdminScreen extends StatefulWidget {
  final String idDenuncia;

  const DenunciaDetalleAdminScreen({super.key, required this.idDenuncia});

  @override
  State<DenunciaDetalleAdminScreen> createState() => _DenunciaDetalleAdminScreenState();
}

class _DenunciaDetalleAdminScreenState extends State<DenunciaDetalleAdminScreen> {
  bool _cargando = true;
  String? _error;
  DenunciaDetalle? _detalle;
  bool _actualizando = false;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final res = await DenunciasService.obtenerDetalle(widget.idDenuncia);
      if (!mounted) return;
      setState(() {
        _detalle = res;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _cargando = false;
      });
    }
  }

  Future<void> _dialogoCambiarEstado() async {
    if (_detalle == null) return;
    final denuncia = _detalle!.denuncia;

    String nuevoEstado = denuncia.estado;
    final ctrlObservaciones = TextEditingController(text: denuncia.observacionesInternas ?? '');
    final ctrlAcciones = TextEditingController(text: denuncia.accionesRealizadas ?? '');

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: AppColors.rosa),
                SizedBox(width: 10),
                Text('Gestionar Caso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estado del caso:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: nuevoEstado,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.rosaSuave,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.bordeRosa)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'recibido', child: Text('Recibido')),
                      DropdownMenuItem(value: 'en_revision', child: Text('En revisión')),
                      DropdownMenuItem(value: 'en_gestion', child: Text('En gestión')),
                      DropdownMenuItem(value: 'derivado', child: Text('Derivado a otra entidad')),
                      DropdownMenuItem(value: 'atendido', child: Text('Atendido')),
                      DropdownMenuItem(value: 'cerrado', child: Text('Cerrado')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => nuevoEstado = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Observaciones internas:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrlObservaciones,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Anotaciones privadas del equipo...',
                      filled: true,
                      fillColor: AppColors.rosaSuave,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.bordeRosa)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Acciones realizadas:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrlAcciones,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Ej. Se visitó el lugar, se coordinó con rescate, etc.',
                      filled: true,
                      fillColor: AppColors.rosaSuave,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.bordeRosa)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar cambios'),
              ),
            ],
          );
        },
      ),
    );

    if (guardado == true) {
      setState(() => _actualizando = true);
      try {
        await DenunciasService.actualizarEstado(
          id: widget.idDenuncia,
          nuevoEstado: nuevoEstado,
          observacionesInternas: ctrlObservaciones.text.trim(),
          accionesRealizadas: ctrlAcciones.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estado y gestión actualizados correctamente')),
          );
        }
        await _cargarDetalle();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        if (mounted) setState(() => _actualizando = false);
      }
    }
  }

  Future<void> _reintentarCorreo() async {
    setState(() => _actualizando = true);
    try {
      await DenunciasService.reintentarCorreo(widget.idDenuncia);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correo de notificación reenviado con éxito')),
        );
      }
      await _cargarDetalle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reenviar correo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  Future<void> _verVideoCompleto(DenunciaArchivo archivo) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.rosa),
      ),
    );
    try {
      final bytes = await DenunciasService.descargarArchivoBytes(widget.idDenuncia, archivo.id);
      if (!mounted) return;
      Navigator.pop(context);
      mostrarDialogoPrevisualizarVideo(
        context,
        nombre: archivo.nombreOriginal,
        bytes: bytes,
        tamanoBytes: archivo.tamanoBytes,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar video: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _verImagenCompleta(DenunciaArchivo archivo) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder(
                future: DenunciasService.descargarArchivoBytes(widget.idDenuncia, archivo.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 300,
                      width: 300,
                      child: Center(child: CircularProgressIndicator(color: Colors.white)),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return SizedBox(
                      height: 200,
                      width: 250,
                      child: Center(
                        child: Text('Error cargando imagen: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  }
                  return InteractiveViewer(
                    child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                  );
                },
              ),
            ),
            IconButton(
              icon: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.close, color: Colors.white)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.rosa)),
      );
    }

    if (_error != null || _detalle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de Denuncia')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error ?? 'No se encontró la denuncia'),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                onPressed: _cargarDetalle,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final d = _detalle!.denuncia;
    final archivos = _detalle!.archivos;
    final historial = _detalle!.historial;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F9),
      appBar: AppBar(
        title: Text(d.radicado, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.rosa)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.rosa),
            tooltip: 'Recargar',
            onPressed: _cargarDetalle,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner de peligro inmediato si aplica
            if (d.esPeligroInmediato) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent, width: 2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ALERTA: PELIGRO INMEDIATO REPORTADO', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 14)),
                          SizedBox(height: 4),
                          Text('El denunciante indicó riesgo inminente para la vida o integridad del animal.', style: TextStyle(fontSize: 12.5, color: Color(0xFFB71C1C))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. Cabecera y Estado
            _tarjeta(
              titulo: 'Estado y Gestión Actual',
              icono: Icons.label_important_outline_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _chipEstado(d.estado),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.rosa,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Actualizar estado', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: _actualizando ? null : _dialogoCambiarEstado,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _filaDato('Fecha de recepción:', d.fechaCreacion.isNotEmpty ? d.fechaCreacion.substring(0, 10) : 'N/A'),
                  _filaDato('Última actualización:', d.fechaActualizacion.isNotEmpty ? d.fechaActualizacion.substring(0, 10) : 'N/A'),
                  if (d.observacionesInternas != null && d.observacionesInternas!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Observaciones internas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.rosaSuave,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(d.observacionesInternas!, style: const TextStyle(fontSize: 13, color: AppColors.texto)),
                    ),
                  ],
                  if (d.accionesRealizadas != null && d.accionesRealizadas!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Acciones realizadas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(d.accionesRealizadas!, style: const TextStyle(fontSize: 13, color: Color(0xFF2E7D32))),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Información del Caso
            _tarjeta(
              titulo: 'Detalle de la Denuncia',
              icono: Icons.info_outline_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _filaDato('Tipo de reporte:', d.tipoReporte),
                  _filaDato('Animal reportado:', d.tipoAnimal),
                  _filaDato('Ciudad:', d.ciudadCaso),
                  _filaDato('Ubicación exacta:', d.ubicacionAnimal),
                  _filaDato('Tiempo de la situación:', d.fechaSituacion),
                  _filaDato('¿Peligro inmediato?:', d.esPeligroInmediato ? 'Sí' : (d.peligroInmediato == 'no_seguro' ? 'No estoy seguro' : 'No')),
                  const SizedBox(height: 12),
                  const Text('Descripción de los hechos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(d.descripcionCaso, style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.texto)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Estado físico y de salud del animal
            _tarjeta(
              titulo: 'Estado y Condiciones del Animal',
              icono: Icons.pets_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _filaDato('Características físicas:', d.caracteristicasAnimal?.isNotEmpty == true ? d.caracteristicasAnimal! : 'No especificado'),
                  _filaDato('Estado de salud aparente:', d.estadoSalud?.isNotEmpty == true ? d.estadoSalud! : 'No especificado'),
                  _filaDato('Heridas visibles:', d.heridasVisibles?.isNotEmpty == true ? d.heridasVisibles! : 'Ninguna reportada'),
                  _filaDato('Dificultad de movilidad:', d.dificultadMovilidad?.isNotEmpty == true ? d.dificultadMovilidad! : 'Normal'),
                  _filaDato('Condiciones del lugar:', d.condicionesLugar?.isNotEmpty == true ? d.condicionesLugar! : 'No especificadas'),
                  if (d.observacionesAdicionales?.isNotEmpty == true)
                    _filaDato('Observaciones adicionales:', d.observacionesAdicionales!),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. Datos del Reportante
            _tarjeta(
              titulo: 'Datos de la Persona que Reporta',
              icono: Icons.person_outline_rounded,
              child: d.esAnonimo
                  ? Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.visibility_off_rounded, color: Colors.amber, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Este caso fue enviado de forma ANÓNIMA. No se registraron datos de contacto personales.',
                              style: TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _filaDato('Nombre completo:', d.nombreReportante ?? 'No informado'),
                        if (d.documentoReportante?.isNotEmpty == true)
                          _filaDato('Documento de identidad:', d.documentoReportante!),
                        _filaDato('Teléfono de contacto:', d.telefonoReportante ?? 'No informado'),
                        _filaDato('Correo electrónico:', d.correoReportante ?? 'No informado'),
                        _filaDato('Ciudad de residencia:', d.ciudadReportante ?? 'No informada'),
                        if (d.barrioReportante?.isNotEmpty == true)
                          _filaDato('Barrio:', d.barrioReportante!),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // 5. Evidencias fotográficas y en video
            _tarjeta(
              titulo: 'Evidencias Adjuntas (${archivos.length})',
              icono: Icons.photo_library_outlined,
              child: archivos.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No se adjuntaron fotografías ni videos para esta denuncia.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    )
                  : Column(
                      children: [
                        for (final a in archivos)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.rosaSuave,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.bordeRosa),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: Icon(a.esVideo ? Icons.videocam_rounded : Icons.photo_rounded, color: AppColors.rosa),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.nombreOriginal, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(
                                        '${(a.tamanoBytes / (1024 * 1024)).toStringAsFixed(2)} MB • ${a.esVideo ? "Video" : "Imagen"}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                if (a.esVideo)
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.rosa,
                                    ),
                                    onPressed: () => _verVideoCompleto(a),
                                    child: const Text('Ver video'),
                                  )
                                else
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.rosa,
                                    ),
                                    onPressed: () => _verImagenCompleta(a),
                                    child: const Text('Ver foto'),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // 6. Estado de Notificación por Correo
            _tarjeta(
              titulo: 'Notificación al Administrador',
              icono: Icons.email_outlined,
              child: Row(
                children: [
                  Icon(
                    d.estadoCorreo == 'enviado' ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: d.estadoCorreo == 'enviado' ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      d.estadoCorreo == 'enviado'
                          ? 'Correo de aviso enviado exitosamente al administrador.'
                          : 'Pendiente o con error en el envío automático.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (d.estadoCorreo != 'enviado')
                    TextButton(
                      onPressed: _actualizando ? null : _reintentarCorreo,
                      child: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.rosa)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 7. Historial de Seguimiento
            _tarjeta(
              titulo: 'Historial de Cambios y Seguimiento',
              icono: Icons.history_rounded,
              child: historial.isEmpty
                  ? const Text('Sin historial registrado.', style: TextStyle(color: Colors.grey))
                  : Column(
                      children: [
                        for (final h in historial)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.circle, size: 10, color: AppColors.rosa),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${h.estadoNuevo.toUpperCase()} • ${h.fecha.isNotEmpty ? h.fecha.substring(0, 16).replaceAll("T", " ") : ""}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                      ),
                                      if (h.nombreAdmin != null && h.nombreAdmin!.isNotEmpty)
                                        Text('Por: ${h.nombreAdmin}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                                      if (h.observacion != null && h.observacion!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(h.observacion!, style: const TextStyle(fontSize: 12.5, color: AppColors.texto)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta({required String titulo, required IconData icono, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.bordeRosa.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: AppColors.rosa, size: 22),
              const SizedBox(width: 10),
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.texto)),
            ],
          ),
          const Divider(height: 24, color: AppColors.bordeRosa),
          child,
        ],
      ),
    );
  }

  Widget _filaDato(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          ),
          Expanded(
            child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.texto)),
          ),
        ],
      ),
    );
  }

  Widget _chipEstado(String estado) {
    Color fondo;
    Color texto;
    String nombre = estado;

    switch (estado.toLowerCase()) {
      case 'recibido':
        fondo = const Color(0xFFE3F2FD);
        texto = const Color(0xFF1565C0);
        nombre = 'Recibido';
        break;
      case 'en_revision':
        fondo = const Color(0xFFFFF3E0);
        texto = const Color(0xFFE65100);
        nombre = 'En revisión';
        break;
      case 'en_gestion':
        fondo = const Color(0xFFF3E5F5);
        texto = const Color(0xFF7B1FA2);
        nombre = 'En gestión';
        break;
      case 'derivado':
        fondo = const Color(0xFFECEFF1);
        texto = const Color(0xFF455A64);
        nombre = 'Derivado a otra entidad';
        break;
      case 'atendido':
        fondo = const Color(0xFFE8F5E9);
        texto = const Color(0xFF2E7D32);
        nombre = 'Atendido';
        break;
      case 'cerrado':
        fondo = const Color(0xFFFFEBEE);
        texto = const Color(0xFFC62828);
        nombre = 'Cerrado';
        break;
      default:
        fondo = AppColors.rosaSuave;
        texto = AppColors.rosa;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Text(nombre, style: TextStyle(color: texto, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}
