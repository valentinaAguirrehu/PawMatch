import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/screens/admin/pets_form_screen.dart';
import 'package:paw_match/screens/adoption/adoption_requests_admin_screen.dart';
import 'package:paw_match/screens/adoption/my_adoptions_screen.dart';
import 'package:paw_match/screens/apadrinamiento/apadrinamiento_admin_screen.dart';
import 'package:paw_match/screens/apadrinamiento/mis_apadrinamientos_screen.dart';
import 'package:paw_match/screens/pets/pet_detail_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Pantalla moderna de mascotas con diseño inspirado en la referencia:
/// cabecera con ubicación y notificaciones, tarjeta de filtros superior,
/// barra de búsqueda y tarjetas de mascotas.
class PetScreen extends StatefulWidget {
  const PetScreen({super.key});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  late Future<List<Pet>> _future = PetsService.listar();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  /// Mascota recién creada: se muestra primera aunque el listado tarde en refrescarse.
  Pet? _recienAgregada;
  bool _irAlInicio = false;

  /// Último listado ya mostrado, para no tapar la pantalla con el indicador al refrescar.
  List<Pet>? _listaVisible;
  String _busqueda = '';
  String _especie = 'Todas';
  String _sexo = 'Todos'; // 'Todos', 'Macho', 'Hembra'
  String _tamano = 'Todos'; // 'Todos', 'Pequeño', 'Mediano', 'Grande'
  String _edad = 'Todos'; // 'Todos', 'Cachorro', 'Joven', 'Adulto', 'Senior'

  int get _filtrosActivosCount {
    int c = 0;
    if (_especie != 'Todas' && _especie != 'Todos') c++;
    if (_sexo != 'Todos') c++;
    if (_tamano != 'Todos') c++;
    if (_edad != 'Todos' && _edad != 'Todas') c++;
    return c;
  }

  void _limpiarFiltros() {
    setState(() {
      _especie = 'Todas';
      _sexo = 'Todos';
      _tamano = 'Todos';
      _edad = 'Todos';
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _recargar() async {
    setState(() => _future = PetsService.listar());
    await _future.catchError((_) => <Pet>[]);
  }

  /// Deja la mascota nueva al inicio y limpia filtros que podrían ocultarla.
  List<Pet> _conRecienAgregada(List<Pet> pets) {
    final nueva = _recienAgregada;
    if (nueva == null) return pets;
    final resto = pets.where((p) => p.id != nueva.id);
    final guardada = pets.where((p) => p.id == nueva.id);
    return [guardada.isEmpty ? nueva : guardada.first, ...resto];
  }

  void _programarIrAlInicio() {
    if (!_irAlInicio) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_irAlInicio || !_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(0);
      _irAlInicio = false;
    });
  }

  /// Abre el formulario existente de alta. Solo se ofrece al administrador.
  Future<void> _abrirFormularioNuevaMascota() async {
    final creada = await Navigator.push<Pet>(
      context,
      MaterialPageRoute(builder: (_) => const PetsFormScreen()),
    );
    if (creada == null || !mounted) return;
    setState(() {
      _recienAgregada = creada;
      _irAlInicio = true;
      _searchCtrl.clear();
      _busqueda = '';
      _especie = 'Todas';
      _sexo = 'Todos';
      _tamano = 'Todos';
      _edad = 'Todos';
    });
    await _recargar();
    _programarIrAlInicio();
  }

  List<Pet> _filtrar(List<Pet> pets) {
    return pets.where((p) {
      final esp = p.especie.toLowerCase();
      final coincideEspecie = switch (_especie) {
        'Todas' => true,
        'Todos' => true,
        'Otro' => esp != 'perro' && esp != 'gato',
        _ => esp == _especie.toLowerCase(),
      };
      if (!coincideEspecie) return false;

      final q = _busqueda.toLowerCase();
      final coincideTexto = q.isEmpty ||
          p.nombre.toLowerCase().contains(q) ||
          (p.raza ?? '').toLowerCase().contains(q);
      if (!coincideTexto) return false;

      if (_sexo != 'Todos') {
        final sex = (p.sexo ?? '').trim().toLowerCase();
        if (sex != _sexo.toLowerCase()) return false;
      }

      if (_tamano != 'Todos') {
        final tam = (p.tamano ?? '').trim().toLowerCase();
        final objetivo = _tamano.toLowerCase();
        if (objetivo.startsWith('peque') && !tam.startsWith('peque')) return false;
        if (objetivo.startsWith('med') && !tam.startsWith('med')) return false;
        if (objetivo.startsWith('gran') && !tam.startsWith('gran')) return false;
      }

      if (_edad != 'Todos' && _edad != 'Todas') {
        final edad = p.edad;
        if (edad == null) return false;
        final enMeses = p.unidadEdad == 'meses' || p.unidadEdad == 'mes';
        switch (_edad) {
          case 'Cachorro':
            if (enMeses) {
              if (edad > 12) return false;
            } else {
              if (edad > 1) return false;
            }
            break;
          case 'Joven':
            if (enMeses) {
              if (edad <= 12 || edad > 36) return false;
            } else {
              if (edad < 1 || edad > 3) return false;
            }
            break;
          case 'Adulto':
            if (enMeses) return false;
            if (edad < 4 || edad > 7) return false;
            break;
          case 'Senior':
            if (enMeses) return false;
            if (edad < 8) return false;
            break;
        }
      }

      return true;
    }).toList();
  }

  Widget _chipActivo(String label, VoidCallback onClear) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: AppColors.rosa,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.rosa),
          ),
        ],
      ),
    );
  }

  void _mostrarModalFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeInModal = (_especie != 'Todas' && _especie != 'Todos' ? 1 : 0) +
                (_sexo != 'Todos' ? 1 : 0) +
                (_tamano != 'Todos' ? 1 : 0) +
                (_edad != 'Todos' && _edad != 'Todas' ? 1 : 0);

            Widget seccionTitulo(String titulo) {
              return Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
              );
            }

            Widget chipFiltro(String valor, String actual, ValueChanged<String> onSelected) {
              final sel = actual.toLowerCase() == valor.toLowerCase();
              return GestureDetector(
                onTap: () {
                  setModalState(() => onSelected(valor));
                  setState(() => onSelected(valor));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.rosa : AppColors.rosaSuave,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? AppColors.rosa : AppColors.bordeRosa,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    valor,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                      color: sel ? Colors.white : AppColors.texto,
                    ),
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: AppColors.rosa, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Filtrar Mascotas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.texto,
                          ),
                        ),
                        const Spacer(),
                        if (activeInModal > 0)
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _limpiarFiltros();
                              });
                            },
                            child: const Text(
                              'Limpiar',
                              style: TextStyle(
                                color: AppColors.rosa,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 18),

                    // Especie
                    seccionTitulo('Especie'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Todas', 'Perro', 'Gato', 'Otro'].map((esp) {
                        return chipFiltro(esp, _especie, (v) => _especie = v);
                      }).toList(),
                    ),

                    // Sexo
                    seccionTitulo('Sexo'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Todos', 'Macho', 'Hembra'].map((s) {
                        return chipFiltro(s, _sexo, (v) => _sexo = v);
                      }).toList(),
                    ),

                    // Tamaño
                    seccionTitulo('Tamaño'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Todos', 'Pequeño', 'Mediano', 'Grande'].map((t) {
                        return chipFiltro(t, _tamano, (v) => _tamano = v);
                      }).toList(),
                    ),

                    // Edad
                    seccionTitulo('Edad'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Todos', 'Cachorro', 'Joven', 'Adulto', 'Senior'].map((e) {
                        return chipFiltro(e, _edad, (v) => _edad = v);
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Botón Aplicar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.rosa,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Aplicar Filtros',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarMenuSolicitudes(BuildContext context) {
    final bool esAdmin = Session.esAdmin;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  esAdmin ? Icons.inbox_outlined : Icons.assignment_outlined,
                  color: AppColors.rosa,
                ),
                const SizedBox(width: 8),
                Text(
                  esAdmin ? 'Solicitudes Recibidas' : 'Mis Solicitudes',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              leading: const CircleAvatar(
                backgroundColor: AppColors.rosaClaro,
                child: Icon(Icons.volunteer_activism, color: AppColors.rosa),
              ),
              title: Text(
                esAdmin ? 'Solicitudes de Apadrinamiento' : 'Mis Apadrinamientos',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                esAdmin
                    ? 'Revisar solicitudes enviadas por usuarios'
                    : 'Consulta estado de apadrinamiento y contratos',
              ),
              trailing: ValueListenableBuilder<int>(
                valueListenable: esAdmin
                    ? ApadrinamientoService.noLeidasAdmin
                    : ApadrinamientoService.noLeidasUsuario,
                builder: (context, count, child) => count > 0
                    ? Badge(label: Text('$count'), backgroundColor: Colors.redAccent)
                    : const Icon(Icons.chevron_right),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => esAdmin
                        ? const ApadrinamientoAdminScreen()
                        : const MisApadrinamientosScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              leading: const CircleAvatar(
                backgroundColor: AppColors.rosaClaro,
                child: Icon(Icons.pets, color: AppColors.rosa),
              ),
              title: Text(
                esAdmin ? 'Solicitudes de Adopción' : 'Mis Adopciones',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                esAdmin
                    ? 'Revisar solicitudes enviadas por usuarios'
                    : 'Consulta si tu adopción fue aprobada',
              ),
              trailing: ValueListenableBuilder<int>(
                valueListenable: esAdmin
                    ? AdoptionService.noLeidasAdmin
                    : AdoptionService.noLeidasUsuario,
                builder: (context, count, child) => count > 0
                    ? Badge(label: Text('$count'), backgroundColor: Colors.redAccent)
                    : const Icon(Icons.chevron_right),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => esAdmin
                        ? const AdoptionRequestsAdminScreen()
                        : const MyAdoptionsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool puedeVolver = Navigator.canPop(context);

    final bool esAdmin = Session.esAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      floatingActionButton: esAdmin
          ? FloatingActionButton.extended(
              onPressed: _abrirFormularioNuevaMascota,
              icon: const Icon(Icons.add),
              label: const Text('Agregar mascota'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // ───────── ENCABEZADO SUPERIOR (ESTILO REFERENCIA) ─────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Row(
                children: [
                  // Botón Volver o Avatar del Usuario
                  if (puedeVolver)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.rosa.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.pets, color: AppColors.rosa, size: 22),
                      ),
                    ),

                  const SizedBox(width: 12),

                  // Ubicación central con pin (como en la imagen de referencia)
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: AppColors.rosa,
                            ),
                            const SizedBox(width: 4),
                            const Flexible(
                              child: Text(
                                'Fundación Maritza Arévalo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Campanita de notificaciones (estilo botón circular blanco con sombra)
                  GestureDetector(
                    onTap: () => _mostrarMenuSolicitudes(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          Session.esAdmin
                              ? ApadrinamientoService.noLeidasAdmin
                              : ApadrinamientoService.noLeidasUsuario,
                          Session.esAdmin
                              ? AdoptionService.noLeidasAdmin
                              : AdoptionService.noLeidasUsuario,
                        ]),
                        builder: (context, child) {
                          final total = Session.esAdmin
                              ? (ApadrinamientoService.noLeidasAdmin.value +
                                  AdoptionService.noLeidasAdmin.value)
                              : (ApadrinamientoService.noLeidasUsuario.value +
                                  AdoptionService.noLeidasUsuario.value);
                          return Badge(
                            isLabelVisible: total > 0,
                            label: Text('$total'),
                            backgroundColor: Colors.redAccent,
                            child: const Icon(
                              Icons.notifications_outlined,
                              size: 20,
                              color: AppColors.rosa,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ───────── BARRA DE BÚSQUEDA Y BOTÓN DE FILTRO A SU LADO ─────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _busqueda.isNotEmpty
                              ? AppColors.rosa
                              : AppColors.bordeRosa.withValues(alpha: 0.8),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.rosa.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o raza...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13.5,
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 12, right: 8),
                            child: Icon(
                              Icons.search_rounded,
                              color: AppColors.rosa,
                              size: 21,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 42,
                            minHeight: 24,
                          ),
                          suffixIcon: _busqueda.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 19,
                                    color: AppColors.rosa,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _searchCtrl.clear();
                                      _busqueda = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13,
                            horizontal: 6,
                          ),
                        ),
                        onChanged: (v) => setState(() => _busqueda = v.trim()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _mostrarModalFiltros,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _filtrosActivosCount > 0 ? AppColors.rosa : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _filtrosActivosCount > 0
                              ? AppColors.rosa
                              : AppColors.bordeRosa.withValues(alpha: 0.9),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.rosa.withValues(
                              alpha: _filtrosActivosCount > 0 ? 0.28 : 0.06,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 22,
                            color: _filtrosActivosCount > 0 ? Colors.white : AppColors.rosa,
                          ),
                          if (_filtrosActivosCount > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Center(
                                  child: Text(
                                    '$_filtrosActivosCount',
                                    style: const TextStyle(
                                      color: AppColors.rosa,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_filtrosActivosCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (_especie != 'Todas' && _especie != 'Todos')
                        _chipActivo(_especie, () => setState(() => _especie = 'Todas')),
                      if (_sexo != 'Todos')
                        _chipActivo(_sexo, () => setState(() => _sexo = 'Todos')),
                      if (_tamano != 'Todos')
                        _chipActivo(_tamano, () => setState(() => _tamano = 'Todos')),
                      if (_edad != 'Todos' && _edad != 'Todas')
                        _chipActivo(_edad, () => setState(() => _edad = 'Todos')),
                      GestureDetector(
                        onTap: _limpiarFiltros,
                        child: Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Borrar filtros',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 4),

            // ───────── LISTA DE TARJETAS DE MASCOTAS ─────────
            Expanded(
              child: FutureBuilder<List<Pet>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.done && snap.hasData) {
                    _listaVisible = snap.data;
                  }
                  final origen = snap.hasData ? snap.data : _listaVisible;
                  if (origen == null) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.rosa),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                            const SizedBox(height: 10),
                            const Text(
                              'No pudimos cargar las mascotas',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
                              onPressed: _recargar,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      );
                    }
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.rosa),
                    );
                  }

                  final pets = _conRecienAgregada(_filtrar(origen));
                  _programarIrAlInicio();

                  if (pets.isEmpty) {
                    return RefreshIndicator(
                      color: AppColors.rosa,
                      onRefresh: _recargar,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 100),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppColors.rosaSuave,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.rosa.withValues(alpha: 0.12),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.pets_rounded,
                                    size: 36,
                                    color: AppColors.rosa,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No encontramos mascotas con este criterio',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3436),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Intenta cambiar los filtros o el término de búsqueda.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                                if (_filtrosActivosCount > 0 || _busqueda.isNotEmpty || _especie != 'Todas') ...[
                                  const SizedBox(height: 14),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.rosa,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _limpiarFiltros();
                                      setState(() => _busqueda = '');
                                    },
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    label: const Text('Limpiar todos los filtros'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.rosa,
                    onRefresh: _recargar,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth >= 720
                                ? 3
                                : (constraints.maxWidth >= 480 ? 2 : 1);
                            return GridView.builder(
                              controller: _scrollCtrl,
                              primary: false,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                16,
                                10,
                                16,
                                esAdmin ? 88 : 28,
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 18,
                                mainAxisSpacing: 18,
                                childAspectRatio: crossAxisCount == 1 ? 0.95 : 0.82,
                              ),
                              itemCount: pets.length,
                              itemBuilder: (_, i) => PetCard(
                                pet: pets[i],
                                onTap: () async {
                                  final cambio = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PetDetailScreen(pet: pets[i]),
                                    ),
                                  );
                                  if (cambio == true && mounted) {
                                    _recargar();
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
