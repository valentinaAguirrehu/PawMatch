import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/denuncia.dart';
import 'package:paw_match/screens/admin/denuncia_detalle_admin_screen.dart';
import 'package:paw_match/services/denuncias_service.dart';

class DenunciasAdminScreen extends StatefulWidget {
  const DenunciasAdminScreen({super.key});

  @override
  State<DenunciasAdminScreen> createState() => _DenunciasAdminScreenState();
}

class _DenunciasAdminScreenState extends State<DenunciasAdminScreen> {
  final TextEditingController _ctrlBusqueda = TextEditingController();
  String _filtroEstado = 'todos';
  bool _cargando = true;
  String? _error;
  List<Denuncia> _denuncias = [];

  final List<({String label, String value})> _pestanas = const [
    (label: 'Todas', value: 'todos'),
    (label: 'Recibidas', value: 'recibido'),
    (label: 'En revisión', value: 'en_revision'),
    (label: 'En gestión', value: 'en_gestion'),
    (label: 'Atendidas', value: 'atendido'),
    (label: 'Cerradas', value: 'cerrado'),
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ctrlBusqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final lista = await DenunciasService.listarParaAdmin(
        estado: _filtroEstado == 'todos' ? null : _filtroEstado,
        query: _ctrlBusqueda.text.trim().isEmpty ? null : _ctrlBusqueda.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _denuncias = lista;
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
        nombre = 'Derivado';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
      child: Text(nombre, style: TextStyle(color: texto, fontWeight: FontWeight.bold, fontSize: 11.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F9),
      appBar: AppBar(
        title: const Text('Denuncias de Maltrato Animal', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.rosa),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.rosa),
            onPressed: _cargar,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _ctrlBusqueda,
              onSubmitted: (_) => _cargar(),
              decoration: InputDecoration(
                hintText: 'Buscar por radicado, ciudad, denunciante...',
                hintStyle: const TextStyle(fontSize: 13.5),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.rosa),
                suffixIcon: _ctrlBusqueda.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _ctrlBusqueda.clear();
                          _cargar();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.rosaSuave,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Pestañas de filtros
          Container(
            height: 46,
            color: Colors.white,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _pestanas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final p = _pestanas[i];
                final seleccionada = _filtroEstado == p.value;
                return ChoiceChip(
                  label: Text(p.label, style: TextStyle(fontWeight: seleccionada ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
                  selected: seleccionada,
                  selectedColor: AppColors.rosa,
                  backgroundColor: AppColors.rosaSuave,
                  labelStyle: TextStyle(color: seleccionada ? Colors.white : AppColors.texto),
                  side: BorderSide(color: seleccionada ? AppColors.rosa : AppColors.bordeRosa),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _filtroEstado = p.value);
                      _cargar();
                    }
                  },
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.bordeRosa),

          // Lista de denuncias
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: AppColors.rosa))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(_error!),
                            const SizedBox(height: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                              onPressed: _cargar,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _denuncias.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 54, color: AppColors.rosa),
                                  SizedBox(height: 14),
                                  Text(
                                    'No hay denuncias en esta categoría',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Las denuncias que reporten los usuarios aparecerán aquí.',
                                    style: TextStyle(fontSize: 13, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.rosa,
                            onRefresh: _cargar,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                              itemCount: _denuncias.length,
                              itemBuilder: (context, i) {
                                final d = _denuncias[i];
                                return _tarjetaDenuncia(d);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaDenuncia(Denuncia d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: d.esPeligroInmediato ? Colors.redAccent : AppColors.bordeRosa.withValues(alpha: 0.6),
          width: d.esPeligroInmediato ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DenunciaDetalleAdminScreen(idDenuncia: d.id)),
            );
            _cargar();
            DenunciasService.actualizarConteo();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila superior: Radicado + Estado + Badge Nuevo
                Row(
                  children: [
                    Text(
                      d.radicado,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.rosa),
                    ),
                    if (!d.leidoAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('NUEVO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ],
                    const Spacer(),
                    _chipEstado(d.estado),
                  ],
                ),

                // Alerta de peligro inmediato si aplica
                if (d.esPeligroInmediato) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_rounded, color: Colors.red, size: 16),
                        SizedBox(width: 6),
                        Text('¡PELIGRO INMEDIATO REPORTADO!', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.red, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                Text(
                  d.tipoReporte,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.texto),
                ),
                const SizedBox(height: 4),
                Text(
                  '${d.tipoAnimal} • ${d.ciudadCaso}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  d.descripcionCaso,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const Divider(height: 20, color: AppColors.rosaSuave),

                // Pie de tarjeta: evidencias, reportante, fecha
                Row(
                  children: [
                    Icon(Icons.attach_file_rounded, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${d.totalArchivos} evidencia${d.totalArchivos != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        d.esAnonimo ? 'Anónimo' : (d.nombreReportante ?? 'Reportante'),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      d.fechaCreacion.isNotEmpty ? d.fechaCreacion.substring(0, 10) : '',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
