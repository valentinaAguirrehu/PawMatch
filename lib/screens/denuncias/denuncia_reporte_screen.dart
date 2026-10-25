import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/layout.dart';
import 'package:paw_match/services/denuncias_service.dart';
import 'package:paw_match/services/previsualizar_video.dart';
import 'package:paw_match/widgets/bloque_landing.dart';

class DenunciaReporteScreen extends StatefulWidget {
  const DenunciaReporteScreen({super.key});

  @override
  State<DenunciaReporteScreen> createState() => _DenunciaReporteScreenState();
}

class _DenunciaReporteScreenState extends State<DenunciaReporteScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Datos del reportante
  bool _esAnonimo = false;
  final _ctrlNombre = TextEditingController();
  final _ctrlDocumento = TextEditingController();
  final _ctrlCorreo = TextEditingController();
  final _ctrlTelefono = TextEditingController();
  final _ctrlCiudadReportante = TextEditingController(text: 'Pasto');
  final _ctrlBarrioReportante = TextEditingController();

  // 2. Información del caso
  String _tipoReporte = 'Sospecha de maltrato animal';
  String _tipoAnimal = 'Perro';
  final _ctrlUbicacion = TextEditingController();
  final _ctrlCiudadCaso = TextEditingController(text: 'San Juan de Pasto');
  final _ctrlFechaSituacion = TextEditingController();
  String _peligroInmediato = 'no'; // 'si', 'no', 'no_seguro'
  final _ctrlDescripcion = TextEditingController();

  // 3. Descripción física y estado del animal
  final _ctrlCaracteristicas = TextEditingController();
  final _ctrlEstadoSalud = TextEditingController();
  final _ctrlHeridasVisibles = TextEditingController();
  final _ctrlDificultadMovilidad = TextEditingController();
  final _ctrlCondicionesLugar = TextEditingController();
  final _ctrlObservaciones = TextEditingController();

  // 4. Evidencias seleccionadas
  final List<({Uint8List bytes, String nombre, int tamano})> _archivosSeleccionados = [];

  // 5. Protección de datos
  bool _aceptoPolitica = false;

  bool _enviando = false;

  final List<String> _opcionesTipoReporte = [
    'Sospecha de maltrato animal',
    'Abandono de animal',
    'Animal con heridas visibles o enfermo',
    'Posible negligencia en sus cuidados',
    'Animal que necesita atención veterinaria urgente',
    'Otra situación que afecta el bienestar animal',
  ];

  final List<String> _opcionesTipoAnimal = [
    'Perro',
    'Gato',
    'Otro animal',
  ];

  @override
  void dispose() {
    _ctrlNombre.dispose();
    _ctrlDocumento.dispose();
    _ctrlCorreo.dispose();
    _ctrlTelefono.dispose();
    _ctrlCiudadReportante.dispose();
    _ctrlBarrioReportante.dispose();
    _ctrlUbicacion.dispose();
    _ctrlCiudadCaso.dispose();
    _ctrlFechaSituacion.dispose();
    _ctrlDescripcion.dispose();
    _ctrlCaracteristicas.dispose();
    _ctrlEstadoSalud.dispose();
    _ctrlHeridasVisibles.dispose();
    _ctrlDificultadMovilidad.dispose();
    _ctrlCondicionesLugar.dispose();
    _ctrlObservaciones.dispose();
    super.dispose();
  }

  Future<void> _seleccionarArchivos() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'avi', 'mkv', '3gp', 'webm'],
      );

      if (files.isEmpty) return;

      int rechazados = 0;
      for (final f in files) {
        final bytes = await f.xFile.readAsBytes();
        final size = bytes.length;
        if (size > 25 * 1024 * 1024) {
          rechazados++;
          continue;
        }

        if (_archivosSeleccionados.length >= 10) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Se permite un máximo de 10 archivos de evidencia.')),
            );
          }
          break;
        }

        final yaExiste = _archivosSeleccionados.any((a) => a.nombre == f.name);
        if (!yaExiste) {
          setState(() {
            _archivosSeleccionados.add((
              bytes: bytes,
              nombre: f.name,
              tamano: size,
            ));
          });
        }
      }

      if (rechazados > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$rechazados archivo(s) superaron el límite de 25MB y no fueron agregados.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron seleccionar los archivos: $e')),
        );
      }
    }
  }

  void _eliminarArchivo(int index) {
    setState(() {
      _archivosSeleccionados.removeAt(index);
    });
  }

  void _mostrarPoliticaPrivacidad() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: AppColors.rosa),
            SizedBox(width: 10),
            Expanded(child: Text('Tratamiento de Datos Personales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'En cumplimiento de la normativa legal de protección de datos personales (Ley 1581 de 2012 de la República de Colombia), la Fundación Maritza Arévalo y el sistema Paw Match informan:\n\n'
            '1. FINALIDAD DEL TRATAMIENTO: Los datos personales recopilados a través de este formulario serán utilizados única y exclusivamente para recibir, verificar, gestionar y realizar el seguimiento respectivo al caso de presunto maltrato, abandono o riesgo animal reportado.\n\n'
            '2. CONFIDENCIALIDAD: Sus datos de contacto no serán compartidos públicamente ni divulgados a terceras personas no autorizadas. En caso de reporte anónimo, la información del caso será gestionada preservando el anonimato del denunciante.\n\n'
            '3. DERECHOS DEL TITULAR: Como titular de la información, usted tiene derecho a conocer, actualizar y rectificar sus datos personales mediante comunicación a los canales oficiales de la organización.\n\n'
            '4. ALCANCE: El envío del reporte no constituye una denuncia formal ante autoridades judiciales ni garantiza atención de emergencia en tiempo real.',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.texto),
          ),
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

  Future<void> _enviarReporte() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos requeridos en el formulario.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!_aceptoPolitica) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar la política de tratamiento de datos personales para continuar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final res = await DenunciasService.enviarDenuncia(
        esAnonimo: _esAnonimo,
        nombreReportante: _ctrlNombre.text,
        documentoReportante: _ctrlDocumento.text,
        correoReportante: _ctrlCorreo.text,
        telefonoReportante: _ctrlTelefono.text,
        ciudadReportante: _ctrlCiudadReportante.text,
        barrioReportante: _ctrlBarrioReportante.text,
        tipoReporte: _tipoReporte,
        tipoAnimal: _tipoAnimal,
        ubicacionAnimal: _ctrlUbicacion.text,
        ciudadCaso: _ctrlCiudadCaso.text,
        fechaSituacion: _ctrlFechaSituacion.text,
        peligroInmediato: _peligroInmediato,
        descripcionCaso: _ctrlDescripcion.text,
        caracteristicasAnimal: _ctrlCaracteristicas.text,
        estadoSalud: _ctrlEstadoSalud.text,
        heridasVisibles: _ctrlHeridasVisibles.text,
        dificultadMovilidad: _ctrlDificultadMovilidad.text,
        condicionesLugar: _ctrlCondicionesLugar.text,
        observacionesAdicionales: _ctrlObservaciones.text,
        aceptoPolitica: _aceptoPolitica,
        archivos: _archivosSeleccionados.map((a) => (bytes: a.bytes, nombre: a.nombre)).toList(),
      );

      if (!mounted) return;
      setState(() => _enviando = false);

      final String radicado = res['radicado']?.toString() ?? 'DEN-REGISTRADA';
      _mostrarDialogoExito(radicado);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Error al enviar'),
            ],
          ),
          content: Text(
            'Ocurrió un inconveniente al enviar tu denuncia: ${e.toString().replaceAll('Exception: ', '')}\n\nTus datos no se han perdido, por favor revisa la información e intenta de nuevo.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
  }

  void _mostrarDialogoExito(String radicado) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.rosaClaro,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.rosa, size: 54),
            ),
            const SizedBox(height: 18),
            const Text(
              '¡Gracias por ayudarnos a proteger a los animales!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.texto),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tu reporte ha sido recibido correctamente. La información será revisada para evaluar la situación y determinar los pasos que puedan seguirse según las características del caso y la disponibilidad de atención.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.45),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.rosaSuave,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.bordeRosa),
              ),
              child: Column(
                children: [
                  const Text('NÚMERO DE REFERENCIA / RADICADO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        radicado,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.rosa, letterSpacing: 1),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.rosa),
                        tooltip: 'Copiar radicado',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: radicado));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Radicado copiado al portapapeles')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nota: Este envío no constituye una orden judicial ni garantiza el rescate inmediato. Conserva tu número de radicado para cualquier consulta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rosa,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Vuelve al WelcomeScreen
              },
              child: const Text('Entendido y volver al inicio', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final escritorio = ancho >= Layout.escritorio;
    final pad = escritorio ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.rosaSuave,
      appBar: AppBar(
        title: const Text('Reportes y Denuncias', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.rosa),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Layout.anchoMaximo),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // =========================================================
                    // 2. SECCIÓN INFORMATIVA: ¿Cuándo puedes reportar un caso?
                    // =========================================================
                    _seccionInformativa(escritorio),

                    const SizedBox(height: 20),

                    // =========================================================
                    // 3. SECCIÓN: Antes de enviar tu reporte
                    // =========================================================
                    _seccionOrientaciones(escritorio),

                    const SizedBox(height: 24),

                    // =========================================================
                    // 4. FORMULARIO: Cuéntanos qué está pasando
                    // =========================================================
                    _seccionFormulario(escritorio),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Componente Sección Informativa
  // ─────────────────────────────────────────────────────────────
  Widget _seccionInformativa(bool escritorio) {
    return BloqueLanding(
      color: Colors.white,
      padding: EdgeInsets.all(escritorio ? 32 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.rosaClaro,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.volunteer_activism_rounded, color: AppColors.rosa, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Ayúdanos a proteger a quienes no tienen voz',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.texto,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Cada animal merece vivir con dignidad, cuidado y respeto. Si conoces una situación en la que un animal esté sufriendo maltrato, haya sido abandonado o se encuentre en condiciones que pongan en riesgo su bienestar, puedes compartir la información con nosotros.\n\n'
            'Tu reporte nos ayudará a conocer lo que está sucediendo, evaluar la situación y determinar qué alternativas de atención pueden estar disponibles. Cuantos más detalles relevantes puedas proporcionar, mejor podremos comprender el caso.\n\n'
            'Si cuentas con fotografías, videos u otros elementos que permitan documentar lo ocurrido, podrás adjuntarlos al formulario, siempre que puedas obtenerlos de forma segura.',
            style: TextStyle(fontSize: 14.5, height: 1.55, color: AppColors.texto),
          ),
          const SizedBox(height: 22),
          const Text(
            'Tipos de situaciones que puedes reportar:',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.rosa),
          ),
          const SizedBox(height: 12),
          _itemSituacion(Icons.report_problem_rounded, 'Sospecha de maltrato animal.'),
          _itemSituacion(Icons.pets_rounded, 'Abandono de perros, gatos u otros animales.'),
          _itemSituacion(Icons.healing_rounded, 'Animales con heridas visibles o en condiciones de salud preocupantes.'),
          _itemSituacion(Icons.medical_services_rounded, 'Animales que podrían necesitar atención veterinaria urgente.'),
          _itemSituacion(Icons.warning_amber_rounded, 'Animales que permanecen en condiciones inadecuadas de cuidado.'),
          _itemSituacion(Icons.info_outline_rounded, 'Otras situaciones que puedan afectar el bienestar animal.'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.rosaSuave,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.bordeRosa),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_rounded, color: AppColors.rosa, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aclaración importante: El envío de un reporte no garantiza automáticamente un rescate, atención inmediata ni la admisión del animal. Cada situación debe evaluarse según sus características, los recursos disponibles y los criterios de atención de la organización.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemSituacion(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: AppColors.rosa, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 14, color: AppColors.texto))),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Componente Sección Orientaciones
  // ─────────────────────────────────────────────────────────────
  Widget _seccionOrientaciones(bool escritorio) {
    return BloqueLanding(
      color: Colors.white,
      padding: EdgeInsets.all(escritorio ? 32 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Antes de enviar tu reporte',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.texto),
          ),
          const SizedBox(height: 16),
          _tarjetaOrientacion(
            icono: Icons.edit_note_rounded,
            titulo: 'Proporciona información clara',
            detalle: 'Describe lo ocurrido, la ubicación del animal, las condiciones que observaste y, si lo sabes, desde cuándo sucede la situación. Procura que la información sea lo más precisa posible.',
          ),
          const SizedBox(height: 12),
          _tarjetaOrientacion(
            icono: Icons.camera_alt_rounded,
            titulo: 'Aporta evidencias de forma segura',
            detalle: 'Puedes adjuntar fotografías o videos que ayuden a comprender el caso. No te expongas a situaciones peligrosas, no confrontes a posibles responsables ni ingreses a propiedades privadas para conseguir evidencias.',
          ),
          const SizedBox(height: 12),
          _tarjetaOrientacion(
            icono: Icons.emergency_rounded,
            colorIcono: Colors.redAccent,
            colorFondo: const Color(0xFFFFF0F2),
            titulo: 'Si el animal está en peligro inmediato',
            detalle: 'Si observas lesiones graves, peligro inminente o una situación que requiere atención urgente, contacta también a las autoridades competentes o a los servicios de emergencia correspondientes (Línea 123 o Policía Ambiental). El formulario no sustituye los canales oficiales de atención urgente.',
          ),
          const SizedBox(height: 12),
          _tarjetaOrientacion(
            icono: Icons.fact_check_rounded,
            titulo: 'Sobre la atención de los casos',
            detalle: 'La organización revisará la información recibida y determinará las posibles acciones según su capacidad de atención. Cuando corresponda y existan datos verificados, podrá orientar al reportante hacia entidades competentes u otras alternativas de ayuda. No podemos garantizar rescates en todos los casos ni resultados específicos.',
          ),
        ],
      ),
    );
  }

  Widget _tarjetaOrientacion({
    required IconData icono,
    required String titulo,
    required String detalle,
    Color colorIcono = AppColors.rosa,
    Color colorFondo = AppColors.rosaSuave,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordeRosa.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(icono, color: colorIcono, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.texto)),
                const SizedBox(height: 4),
                Text(detalle, style: const TextStyle(fontSize: 13, height: 1.45, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Componente Formulario Completo
  // ─────────────────────────────────────────────────────────────
  Widget _seccionFormulario(bool escritorio) {
    return BloqueLanding(
      color: Colors.white,
      padding: EdgeInsets.all(escritorio ? 32 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cuéntanos qué está pasando',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.texto),
          ),
          const SizedBox(height: 6),
          const Text(
            'Diligencia los siguientes campos para que podamos evaluar la situación de manera responsable.',
            style: TextStyle(fontSize: 13.5, color: Colors.black54),
          ),
          const Divider(height: 36, color: AppColors.bordeRosa),

          // 4.1. Información de la persona que reporta
          _subtituloGrupo('1. Información de la persona que reporta'),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('Deseo reportar de forma anónima', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
            subtitle: const Text('Oculta tu nombre e identidad en el registro'),
            value: _esAnonimo,
            activeThumbColor: AppColors.rosa,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _esAnonimo = val),
          ),
          if (!_esAnonimo) ...[
            const SizedBox(height: 12),
            _campoTexto(
              controller: _ctrlNombre,
              label: 'Nombre y apellidos *',
              icono: Icons.person_outline_rounded,
              validator: (v) => _esAnonimo ? null : ((v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null),
            ),
            const SizedBox(height: 14),
            _filaResponsive(
              escritorio: escritorio,
              izquierda: _campoTexto(
                controller: _ctrlDocumento,
                label: 'Documento de identidad (opcional)',
                icono: Icons.badge_outlined,
              ),
              derecha: _campoTexto(
                controller: _ctrlTelefono,
                label: 'Número de contacto (teléfono) *',
                icono: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => _esAnonimo ? null : ((v == null || v.trim().isEmpty) ? 'Ingresa tu teléfono' : null),
              ),
            ),
            const SizedBox(height: 14),
            _campoTexto(
              controller: _ctrlCorreo,
              label: 'Correo electrónico *',
              icono: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (_esAnonimo) return null;
                if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                if (!v.contains('@') || !v.contains('.')) return 'Ingresa un correo válido';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _filaResponsive(
              escritorio: escritorio,
              izquierda: _campoTexto(
                controller: _ctrlCiudadReportante,
                label: 'Ciudad o municipio de residencia *',
                icono: Icons.location_city_rounded,
                validator: (v) => _esAnonimo ? null : ((v == null || v.trim().isEmpty) ? 'Ingresa la ciudad' : null),
              ),
              derecha: _campoTexto(
                controller: _ctrlBarrioReportante,
                label: 'Barrio de residencia (opcional)',
                icono: Icons.home_work_outlined,
              ),
            ),
          ],

          const Divider(height: 40, color: AppColors.bordeRosa),

          // 4.2. Información del caso
          _subtituloGrupo('2. Información del caso'),
          const SizedBox(height: 14),

          // Selector tipo de reporte
          DropdownButtonFormField<String>(
            initialValue: _tipoReporte,
            decoration: _decoracionCampo(label: 'Tipo de situación reportada *', icono: Icons.warning_amber_rounded),
            isExpanded: true,
            items: _opcionesTipoReporte.map((op) => DropdownMenuItem(value: op, child: Text(op, style: const TextStyle(fontSize: 13.5)))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _tipoReporte = val);
            },
          ),
          const SizedBox(height: 14),

          // Selector tipo de animal
          DropdownButtonFormField<String>(
            initialValue: _tipoAnimal,
            decoration: _decoracionCampo(label: 'Tipo de animal *', icono: Icons.pets_rounded),
            items: _opcionesTipoAnimal.map((op) => DropdownMenuItem(value: op, child: Text(op))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _tipoAnimal = val);
            },
          ),
          const SizedBox(height: 14),

          _filaResponsive(
            escritorio: escritorio,
            izquierda: _campoTexto(
              controller: _ctrlCiudadCaso,
              label: 'Ciudad o municipio donde ocurre el caso *',
              icono: Icons.location_city_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Indica la ciudad del caso' : null,
            ),
            derecha: _campoTexto(
              controller: _ctrlFechaSituacion,
              label: 'Fecha o tiempo aproximado * (ej. Hoy, Hace 3 días)',
              icono: Icons.calendar_today_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Indica cuándo ocurrió' : null,
            ),
          ),
          const SizedBox(height: 14),

          _campoTexto(
            controller: _ctrlUbicacion,
            label: 'Ubicación exacta del animal * (Dirección, barrio o punto de referencia)',
            icono: Icons.place_rounded,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Indica la ubicación del animal' : null,
          ),
          const SizedBox(height: 16),

          // ¿El animal está en peligro inmediato?
          const Text('¿El animal está en peligro inmediato? *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chipPeligro(
                valor: 'si',
                etiqueta: 'Sí, peligro alto',
                icono: Icons.warning_rounded,
                colorActivo: Colors.redAccent,
              ),
              _chipPeligro(
                valor: 'no',
                etiqueta: 'No',
                icono: Icons.check_circle_outline,
                colorActivo: AppColors.rosa,
              ),
              _chipPeligro(
                valor: 'no_seguro',
                etiqueta: 'No estoy seguro',
                icono: Icons.help_outline_rounded,
                colorActivo: Colors.orange,
              ),
            ],
          ),

          // Aviso destacado si seleccionó "Sí"
          if (_peligroInmediato == 'si') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_rounded, color: Colors.red, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '¡ATENCIÓN! Situación de peligro inmediato detectada',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Si el animal tiene heridas graves, riesgo inminente de muerte o maltrato violento en curso, por favor contacta de inmediato a las autoridades competentes:\n'
                    '• Línea Nacional de Emergencias: 123\n'
                    '• Policía Ambiental y Ecológica\n'
                    'Este formulario no garantiza una respuesta inmediata en el lugar.',
                    style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFFB71C1C)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          _campoTexto(
            controller: _ctrlDescripcion,
            label: 'Descripción detallada de lo sucedido *',
            icono: Icons.description_rounded,
            maxLines: 4,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Describe lo ocurrido' : null,
          ),

          const Divider(height: 40, color: AppColors.bordeRosa),

          // 4.3. Descripción física y estado del animal
          _subtituloGrupo('3. Cuéntanos cómo se encuentra el animal'),
          const SizedBox(height: 6),
          const Text('Completa los campos que conozcas (puedes omitir los que desconozcas).', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
          const SizedBox(height: 14),

          _campoTexto(
            controller: _ctrlCaracteristicas,
            label: 'Color, tamaño y características físicas (raza aproximada, pelaje, etc.)',
            icono: Icons.palette_outlined,
          ),
          const SizedBox(height: 14),

          _filaResponsive(
            escritorio: escritorio,
            izquierda: _campoTexto(
              controller: _ctrlEstadoSalud,
              label: 'Estado de salud aparente (desnutrido, débil, etc.)',
              icono: Icons.health_and_safety_outlined,
            ),
            derecha: _campoTexto(
              controller: _ctrlHeridasVisibles,
              label: 'Presencia de heridas o lesiones visibles',
              icono: Icons.healing_outlined,
            ),
          ),
          const SizedBox(height: 14),

          _filaResponsive(
            escritorio: escritorio,
            izquierda: _campoTexto(
              controller: _ctrlDificultadMovilidad,
              label: 'Dificultad para caminar o desplazarse',
              icono: Icons.directions_walk_rounded,
            ),
            derecha: _campoTexto(
              controller: _ctrlCondicionesLugar,
              label: 'Condiciones del lugar (amarrado, intemperie, etc.)',
              icono: Icons.roofing_rounded,
            ),
          ),
          const SizedBox(height: 14),
          _campoTexto(
            controller: _ctrlObservaciones,
            label: 'Otras observaciones importantes',
            icono: Icons.notes_rounded,
          ),

          const Divider(height: 40, color: AppColors.bordeRosa),

          // 4.4. Adjunta evidencias del caso
          _subtituloGrupo('4. Adjunta evidencias del caso'),
          const SizedBox(height: 6),
          const Text(
            '“Si tienes fotografías o videos que ayuden a documentar lo ocurrido, puedes adjuntarlos aquí. Asegúrate de que correspondan al caso reportado y recuerda que tu seguridad es lo más importante.”',
            style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Text(
            'Formatos permitidos: JPG, JPEG, PNG, WEBP, MP4, MOV, WEBM. Máximo 25MB por archivo (hasta 10 archivos).',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.rosa,
              side: const BorderSide(color: AppColors.rosa, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Seleccionar fotografías o videos', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _seleccionarArchivos,
          ),

          if (_archivosSeleccionados.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Archivos listos para enviar (${_archivosSeleccionados.length}/10):',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _archivosSeleccionados.length; i++)
              _itemArchivoAdjunto(_archivosSeleccionados[i], i),
          ],

          const Divider(height: 40, color: AppColors.bordeRosa),

          // 5. Protección de datos personales
          _subtituloGrupo('5. Protección de tus datos personales'),
          const SizedBox(height: 8),
          const Text(
            '“Los datos que proporciones serán tratados para recibir, evaluar y gestionar tu reporte, establecer contacto cuando sea necesario y realizar el seguimiento correspondiente. La información será utilizada de acuerdo con la política de tratamiento de datos personales de la organización y la normativa aplicable.”',
            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.45),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.policy_rounded, size: 18, color: AppColors.rosa),
              label: const Text('Ver política de privacidad y protección de datos', style: TextStyle(color: AppColors.rosa, fontWeight: FontWeight.bold)),
              onPressed: _mostrarPoliticaPrivacidad,
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _aceptoPolitica,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.rosa,
            title: const Text(
              'Declaro que he leído la política de tratamiento de datos personales y autorizo el uso de la información proporcionada para las finalidades descritas, conforme a dicha política. *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onChanged: (val) => setState(() => _aceptoPolitica = val ?? false),
          ),

          const SizedBox(height: 28),

          // 6. Botón Enviar reporte
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rosa,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              icon: _enviando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.send_rounded),
              label: Text(
                _enviando ? 'Enviando reporte...' : 'Enviar reporte',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              onPressed: _enviando ? null : _enviarReporte,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtituloGrupo(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.rosa),
    );
  }

  void _mostrarPrevisualizacionVideo(({Uint8List bytes, String nombre, int tamano}) archivo) {
    mostrarDialogoPrevisualizarVideo(
      context,
      nombre: archivo.nombre,
      bytes: archivo.bytes,
      tamanoBytes: archivo.tamano,
    );
  }

  void _mostrarPrevisualizacionFoto(({Uint8List bytes, String nombre, int tamano}) archivo) {
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
              child: InteractiveViewer(
                child: Image.memory(archivo.bytes, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemArchivoAdjunto(({Uint8List bytes, String nombre, int tamano}) archivo, int index) {
    final kb = (archivo.tamano / 1024).toStringAsFixed(1);
    final mb = (archivo.tamano / (1024 * 1024)).toStringAsFixed(2);
    final tamanoTexto = archivo.tamano > 1024 * 1024 ? '$mb MB' : '$kb KB';
    final nombreLower = archivo.nombre.toLowerCase();
    final esVideo = nombreLower.endsWith('.mp4') ||
        nombreLower.endsWith('.mov') ||
        nombreLower.endsWith('.webm') ||
        nombreLower.endsWith('.avi') ||
        nombreLower.endsWith('.3gp') ||
        nombreLower.endsWith('.mkv');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  esVideo ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                  color: AppColors.rosa,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      archivo.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$tamanoTexto • ${esVideo ? "Video listo para enviar" : "Fotografía lista para enviar"}',
                      style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                tooltip: 'Eliminar archivo',
                onPressed: () => _eliminarArchivo(index),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: esVideo
                ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rosa,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.rosa, width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 20, color: AppColors.rosa),
                    label: const Text(
                      'Ver video cargado',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    onPressed: () => _mostrarPrevisualizacionVideo(archivo),
                  )
                : OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rosa,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.rosa, width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.visibility_rounded, size: 18, color: AppColors.rosa),
                    label: const Text(
                      'Ver foto cargada',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    onPressed: () => _mostrarPrevisualizacionFoto(archivo),
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoracionCampo({required String label, required IconData icono}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13.5, color: Colors.black54),
      prefixIcon: Icon(icono, color: AppColors.rosa, size: 22),
      filled: true,
      fillColor: AppColors.rosaSuave,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.bordeRosa)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.bordeRosa)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.rosa, width: 2)),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: _decoracionCampo(label: label, icono: icono),
    );
  }

  Widget _filaResponsive({required Widget izquierda, required Widget derecha, required bool escritorio}) {
    if (escritorio) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: izquierda),
          const SizedBox(width: 14),
          Expanded(child: derecha),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        izquierda,
        const SizedBox(height: 14),
        derecha,
      ],
    );
  }

  Widget _chipPeligro({
    required String valor,
    required String etiqueta,
    required IconData icono,
    required Color colorActivo,
  }) {
    final bool seleccionado = _peligroInmediato == valor;
    return ChoiceChip(
      avatar: Icon(icono, size: 18, color: seleccionado ? Colors.white : colorActivo),
      label: Text(etiqueta),
      selected: seleccionado,
      selectedColor: colorActivo,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: seleccionado ? Colors.white : AppColors.texto,
        fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(color: seleccionado ? colorActivo : AppColors.bordeRosa),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        if (val) setState(() => _peligroInmediato = valor);
      },
    );
  }
}


