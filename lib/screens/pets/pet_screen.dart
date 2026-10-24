import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/screens/admin/pets_form_screen.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/screens/pets/pet_detail_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';

/// Pantalla de mascotas: cabecera, filtros, búsqueda y tarjetas.
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
  String _edad = 'Todos'; // 'Todos', 'Cachorro', 'Adulto'
  /// 'Todas', 'Disponibles', 'Apadrinadas' o 'Adoptadas'.
  String _estado = 'Todas';

  int get _filtrosActivosCount {
    int c = 0;
    if (_especie != 'Todas' && _especie != 'Todos') c++;
    if (_sexo != 'Todos') c++;
    if (_tamano != 'Todos') c++;
    if (_edad != 'Todos' && _edad != 'Todas') c++;
    if (_estado != 'Todas') c++;
    return c;
  }

  void _limpiarFiltros() {
    setState(() {
      _especie = 'Todas';
      _sexo = 'Todos';
      _tamano = 'Todos';
      _edad = 'Todos';
      _estado = 'Todas';
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
      _estado = 'Todas';
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

      if (!_coincideEstado(p)) return false;

      if (_edad != 'Todos' && _edad != 'Todas') {
        if (_edad == 'Cachorro' && !p.esCachorro) return false;
        if (_edad == 'Adulto' && p.esCachorro) return false;
      }

      return true;
    }).toList();
  }

  /// Todas muestra los tres grupos. El resto deja solo el grupo elegido.
  bool _coincideEstado(Pet p) {
    return switch (_estado) {
      'Disponibles' => p.ordenEstadoListado == 0,
      'Apadrinadas' => p.ordenEstadoListado == 1,
      'Adoptadas' => p.ordenEstadoListado == 2,
      _ => true,
    };
  }

  Widget _barraEstado() {
    const opciones = ['Todas', 'Disponibles', 'Apadrinadas', 'Adoptadas'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: opciones.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final valor = opciones[i];
            final sel = _estado == valor;
            return GestureDetector(
              onTap: () => setState(() => _estado = valor),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? AppColors.rosa : Colors.white,
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
          },
        ),
      ),
    );
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
                (_edad != 'Todos' && _edad != 'Todas' ? 1 : 0) +
                (_estado != 'Todas' ? 1 : 0);

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

                    seccionTitulo('Estado'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Todas', 'Disponibles', 'Apadrinadas', 'Adoptadas'].map((estado) {
                        return chipFiltro(estado, _estado, (v) => _estado = v);
                      }).toList(),
                    ),

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
                      children: ['Todos', 'Cachorro', 'Adulto'].map((e) {
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

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await DialogoCerrarSesion.mostrar(context);
    if (!confirmar || !mounted) return;
    ApadrinamientoService.detenerMonitoreo();
    AdoptionService.detenerMonitoreo();
    Session.cerrar();
    Navegacion.ir(context, const WelcomeScreen());
  }

  Widget _seccionIntroTexto() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.bordeRosa.withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.rosa.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Detrás de cada mirada hay una historia que merece un final feliz. En este espacio encontrarás perritos rescatados que esperan la oportunidad de conocer el amor de una familia y comenzar una nueva etapa llena de cariño, seguridad y felicidad.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Adoptar es mucho más que abrirle las puertas de tu hogar a una mascota; es comprometerte a cuidarla, protegerla y acompañarla durante toda su vida. Cada uno de estos peluditos necesita tiempo, paciencia, atención veterinaria, una buena alimentación y paseos diarios que le permitan explorar y disfrutar del mundo que lo rodea.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Creemos que todos los animales merecen una vida digna, lejos del abandono y cerca del amor que siempre necesitaron. Por eso, buscamos personas dispuestas a brindarles un hogar seguro y permanente, donde sean tratados como parte de la familia y nunca como una responsabilidad pasajera.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 2.5,
                decoration: BoxDecoration(
                  color: AppColors.rosa.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tal vez no puedas cambiar la historia de todos, pero puedes transformar por completo la vida de uno. Conoce a nuestros peluditos, descubre sus personalidades y encuentra a ese compañero de cuatro patas que está esperando escribir una nueva historia contigo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraBusqueda() {
    return Padding(
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
    );
  }

  Widget _chipsActivos() {
    return Padding(
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
            if (_estado != 'Todas')
              _chipActivo(_estado, () => setState(() => _estado = 'Todas')),
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
    );
  }

  Widget _vistaError() {
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

  Widget _vistaVacia() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Intenta cambiar los filtros o el término de búsqueda.',
              textAlign: TextAlign.center,
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
    );
  }

  @override
  Widget build(BuildContext context) {
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
            BarraSuperior(
              iconoTitulo: Icons.favorite_rounded,
              titulo: 'Nuestros Peluditos',
              onCerrarSesion: _confirmarCerrarSesion,
            ),
            Expanded(
              child: FutureBuilder<List<Pet>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.done && snap.hasData) {
                    _listaVisible = snap.data;
                  }
                  final origen = snap.hasData ? snap.data : _listaVisible;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth >= 720 ? 3 : 2;
                          const crossAxisSpacing = 18.0;
                          const paddingHorizontal = 32.0;
                          final anchoCelda = (constraints.maxWidth -
                                  paddingHorizontal -
                                  crossAxisSpacing * (crossAxisCount - 1)) /
                              crossAxisCount;
                          const altoInfo = 176.0;
                          final childAspectRatio = anchoCelda / (anchoCelda + altoInfo);

                          Widget contenidoSliver;

                          if (origen == null) {
                            if (snap.connectionState != ConnectionState.done) {
                              contenidoSliver = const SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: CircularProgressIndicator(color: AppColors.rosa),
                                ),
                              );
                            } else if (snap.hasError) {
                              contenidoSliver = SliverFillRemaining(
                                hasScrollBody: false,
                                child: _vistaError(),
                              );
                            } else {
                              contenidoSliver = const SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: CircularProgressIndicator(color: AppColors.rosa),
                                ),
                              );
                            }
                          } else {
                            final pets = ordenarMascotasPorEstado(
                              _filtrar(_conRecienAgregada(origen)),
                            );
                            _programarIrAlInicio();

                            if (pets.isEmpty) {
                              contenidoSliver = SliverFillRemaining(
                                hasScrollBody: false,
                                child: _vistaVacia(),
                              );
                            } else {
                              contenidoSliver = SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  16,
                                  esAdmin ? 88 : 28,
                                ),
                                sliver: SliverGrid(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: crossAxisSpacing,
                                    mainAxisSpacing: 18,
                                    childAspectRatio: childAspectRatio,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) => PetCard(
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
                                    childCount: pets.length,
                                  ),
                                ),
                              );
                            }
                          }

                          return RefreshIndicator(
                            color: AppColors.rosa,
                            onRefresh: _recargar,
                            child: CustomScrollView(
                              controller: _scrollCtrl,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverToBoxAdapter(
                                  child: _seccionIntroTexto(),
                                ),
                                SliverToBoxAdapter(
                                  child: _barraBusqueda(),
                                ),
                                SliverToBoxAdapter(
                                  child: _barraEstado(),
                                ),
                                if (_filtrosActivosCount > 0)
                                  SliverToBoxAdapter(
                                    child: _chipsActivos(),
                                  ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 6),
                                ),
                                contenidoSliver,
                              ],
                            ),
                          );
                        },
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
