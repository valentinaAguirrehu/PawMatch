import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/screens/admin/gpt_luna_mascota_screen.dart';
import 'package:paw_match/screens/admin/pets_form_screen.dart';
import 'package:paw_match/screens/auth/welcome_screen.dart';
import 'package:paw_match/screens/pets/pet_detail_screen.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/services/match_estado.dart';
import 'package:paw_match/services/match_service.dart';
import 'package:paw_match/services/navegacion.dart';
import 'package:paw_match/services/personalidad_usuario_service.dart';
import 'package:paw_match/services/pets_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:paw_match/widgets/barra_superior.dart';
import 'package:paw_match/widgets/dialogo_cerrar_sesion.dart';
import 'package:paw_match/widgets/pet_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pantalla de visualización de mascotas con buscador, filtros por categoría,
/// cuadrícula de dos columnas, etiqueta «NUEVO» por 48h, aviso de nuevas
/// coincidencias compatibles y sistema de Match en tiempo real.
class PetScreen extends StatefulWidget {
  const PetScreen({super.key});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  late Future<List<Pet>> _future = _cargarDatosIniciales();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  /// Respuestas reales del cuestionario de personalidad del usuario autenticado.
  Map<String, int>? _respuestasUsuario;

  /// ID de la primera mascota asignada como Match inicial del usuario (persistido en BD).
  String? _idMascotaMatchInicial;

  /// Notificaciones de nuevas coincidencias compatibles pendientes por mostrar en esta vista.
  List<NotificacionMatchMascota> _notificacionesPendientes = const [];

  /// IDs de mascotas marcadas como favoritas por el usuario actual.
  final Set<String> _favoritosIds = <String>{};

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
  /// Categorías horizontales: 'Todas', 'Disponibles', 'Apadrinadas' o 'Adopción'.
  String _estado = 'Todas';

  @override
  void initState() {
    super.initState();
    _respuestasUsuario = MatchEstado.instancia.respuestas;
    MatchEstado.instancia.addListener(_onMatchEstadoActualizado);
    PetsService.mascotasEnMemoria.addListener(_onMascotasMemoriaActualizadas);
    _cargarFavoritos();
  }

  @override
  void dispose() {
    MatchEstado.instancia.removeListener(_onMatchEstadoActualizado);
    PetsService.mascotasEnMemoria.removeListener(_onMascotasMemoriaActualizadas);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onMascotasMemoriaActualizadas() {
    if (!mounted) return;
    final enMemoria = PetsService.mascotasEnMemoria.value;
    if (enMemoria == null) return;
    setState(() {
      _listaVisible = enMemoria;
    });
  }

  void _onMatchEstadoActualizado() {
    if (!mounted) return;
    setState(() {
      _respuestasUsuario = MatchEstado.instancia.respuestas;
    });
    _sincronizarMatchYNotificaciones();
  }

  String get _claveFavoritos =>
      'favoritos_mascotas_${Session.idUsuario ?? "anon"}';

  Future<void> _cargarFavoritos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardados = prefs.getStringList(_claveFavoritos) ?? const <String>[];
      if (!mounted) return;
      setState(() {
        _favoritosIds
          ..clear()
          ..addAll(guardados);
      });
    } catch (_) {}
  }

  Future<void> _alternarFavorito(String idMascota) async {
    setState(() {
      if (_favoritosIds.contains(idMascota)) {
        _favoritosIds.remove(idMascota);
      } else {
        _favoritosIds.add(idMascota);
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _claveFavoritos,
        _favoritosIds.toList(),
      );
    } catch (_) {}
  }

  Future<void> _sincronizarMatchYNotificaciones() async {
    if (Session.esAdmin || Session.idUsuario == null) return;
    try {
      final sync = await MatchService.sincronizar();
      if (!mounted) return;
      final pendientes = sync.notificaciones
          .where((n) => !n.mostradaEnMascotas && !n.leida)
          .toList();
      setState(() {
        _idMascotaMatchInicial = sync.idMascotaMatchInicial;
        _notificacionesPendientes = pendientes;
      });
    } catch (_) {}
  }

  Future<List<Pet>> _cargarDatosIniciales() async {
    final futureMascotas = PetsService.listar();
    if (!Session.esAdmin && Session.idUsuario != null) {
      try {
        final actual =
            MatchEstado.instancia.respuestas ??
            await PersonalidadUsuarioService.obtener();
        if (actual != null) {
          _respuestasUsuario = actual;
        }
        final sync = await MatchService.sincronizar();
        _idMascotaMatchInicial = sync.idMascotaMatchInicial;
        _notificacionesPendientes = sync.notificaciones
            .where((n) => !n.mostradaEnMascotas && !n.leida)
            .toList();
        if (mounted) {
          setState(() {});
        }
      } catch (_) {}
    }
    return futureMascotas;
  }

  Future<void> _descartarNotificacionCoincidencia(
    NotificacionMatchMascota notif,
  ) async {
    setState(() {
      _notificacionesPendientes = _notificacionesPendientes
          .where((n) => n.idMascota != notif.idMascota)
          .toList();
    });
    await MatchService.marcarNotificacionLeida(
      idMascota: notif.idMascota,
      idNotificacion: notif.idNotificacion,
    );
  }

  Future<void> _abrirMascotaDesdeNotificacion(
    NotificacionMatchMascota notif,
    List<Pet> mascotasCargadas,
  ) async {
    setState(() {
      _notificacionesPendientes = _notificacionesPendientes
          .where((n) => n.idMascota != notif.idMascota)
          .toList();
    });
    await MatchService.marcarNotificacionLeida(
      idMascota: notif.idMascota,
      idNotificacion: notif.idNotificacion,
    );

    Pet? encontrada;
    for (final p in mascotasCargadas) {
      if (p.id == notif.idMascota) {
        encontrada = p;
        break;
      }
    }
    if (encontrada == null) {
      try {
        encontrada = await PetsService.obtener(notif.idMascota);
      } catch (_) {}
    }
    if (encontrada == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PetDetailScreen(pet: encontrada!)),
    );
    if (mounted) _recargar();
  }

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

  Future<void> _recargar() async {
    setState(() => _future = _cargarDatosIniciales());
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

  /// Muestra las dos opciones al administrador:
  /// 1) Agregar mascota con asistente virtual
  /// 2) Agregar mascota mediante formulario tradicional
  Future<void> _abrirFormularioNuevaMascota() async {
    final modo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Text(
                  '¿Cómo deseas registrar la mascota?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.texto,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Elige el método que prefieras para agregar un nuevo peludito.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                // Opción 1: Agregar mascota con asistente virtual
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.pop(ctx, 'luna'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFDCEB), Color(0xFFFFF2F8)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.rosa, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: AppColors.rosa,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Agregar mascota con asistente virtual',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.texto,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Conversa por micrófono o escribiendo para registrar a tu nuevo peludito',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.rosa,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Opción 2: Agregar mascota mediante formulario tradicional
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.pop(ctx, 'formulario'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.rosaSuave,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.bordeRosa,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            color: AppColors.rosa,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Agregar mascota mediante formulario tradicional',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.texto,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Completa manualmente los campos de información de tu mascota',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.rosa,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (modo == null || !mounted) return;

    final Pet? creada = await Navigator.push<Pet>(
      context,
      MaterialPageRoute(
        builder: (_) => modo == 'luna'
            ? const GptLunaMascotaScreen()
            : const PetsFormScreen(),
      ),
    );
    if (creada == null || !mounted) return;
    setState(() {
      _recienAgregada = creada;
      if (_listaVisible != null) {
        _listaVisible = [
          creada,
          ..._listaVisible!.where((p) => p.id != creada.id),
        ];
      }
      _irAlInicio = true;
      _searchCtrl.clear();
      _busqueda = '';
      _especie = 'Todas';
      _sexo = 'Todos';
      _tamano = 'Todos';
      _edad = 'Todos';
      _estado = 'Todas';
    });
    _programarIrAlInicio();
  }

  /// Calcula el porcentaje real de compatibilidad entre el usuario y la mascota
  /// usando `MatchService`. Si la mascota no tiene personalidad definida o
  /// faltan respuestas del usuario, devuelve `null` (nunca inventa porcentajes).
  double? _calcularPorcentajeMatch(Pet pet) {
    final usuario = MatchEstado.instancia.respuestas ?? _respuestasUsuario;
    if (usuario == null || usuario.isEmpty) return null;

    final mapaMascota = pet.personalidad;
    if (!pet.personalidadDefinida || mapaMascota.isEmpty) {
      return null;
    }

    // Cálculo completo con los 9 rasgos oficiales de MatchService.
    final exacto = MatchService.calcular(usuario, mapaMascota);
    if (exacto != null) return exacto.$1;

    // Si la mascota tiene rasgos parciales válidos en su registro real,
    // calculamos el promedio usando exactamente la misma fórmula de MatchService.
    double suma = 0;
    int rasgosValidos = 0;
    for (final rasgo in rasgosMascota) {
      final valorUsuario = usuario[rasgo.clave];
      final rawMascota = mapaMascota[rasgo.clave];
      final valorMascota = rawMascota is int
          ? rawMascota
          : (rawMascota is num
                ? rawMascota.round()
                : int.tryParse('${rawMascota ?? ''}'));
      if (valorUsuario == null || valorMascota == null) continue;
      if (valorMascota < 1 || valorMascota > 5) continue;
      final diferencia = (valorUsuario - valorMascota).abs().clamp(0, 4);
      suma += 1 - (diferencia / 4);
      rasgosValidos++;
    }

    if (rasgosValidos == 0) return null;
    return (((suma / rasgosValidos) * 10000).round() / 100)
        .clamp(0, 100)
        .toDouble();
  }

  /// Ordena las mascotas:
  /// - Si es ADMINISTRADOR: ordena por estado administrativo sin calcular ni mostrar Match.
  /// - Si es USUARIO: ordena automáticamente de mayor a menor porcentaje de compatibilidad.
  List<_ItemMascotaMatch> _ordenarPorCompatibilidad(List<Pet> pets) {
    if (Session.esAdmin) {
      return ordenarMascotasPorEstado(pets)
          .map((p) => _ItemMascotaMatch(pet: p, match: null))
          .toList();
    }

    final conMatch = pets
        .map((p) => _ItemMascotaMatch(pet: p, match: _calcularPorcentajeMatch(p)))
        .toList();

    conMatch.sort((a, b) {
      final ma = a.match;
      final mb = b.match;
      if (ma != null && mb != null) {
        final cmp = mb.compareTo(ma); // Mayor a menor porcentaje de Match
        if (cmp != 0) return cmp;
      } else if (ma != null && mb == null) {
        return -1;
      } else if (ma == null && mb != null) {
        return 1;
      }

      // Desempate por estado (Disponibles -> Apadrinadas -> Adoptadas) y por ID.
      final porEstado = a.pet.ordenEstadoListado.compareTo(
        b.pet.ordenEstadoListado,
      );
      if (porEstado != 0) return porEstado;
      return b.pet.id.compareTo(a.pet.id);
    });

    return conMatch;
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

  /// Todas muestra todos los grupos. El resto filtra según la categoría seleccionada.
  bool _coincideEstado(Pet p) {
    return switch (_estado) {
      'Disponibles' => p.ordenEstadoListado == 0,
      'Apadrinadas' => p.ordenEstadoListado == 1,
      'Adopción' || 'Adoptadas' => p.ordenEstadoListado == 2 || p.estaAdoptada,
      _ => true,
    };
  }

  /// Notificación de nueva mascota altamente compatible dentro de la vista de mascotas.
  /// Solo aparece cuando se detecta una nueva coincidencia no mostrada/leída aún.
  Widget _bannerNuevaCoincidencia(
    NotificacionMatchMascota notif,
    List<Pet> mascotasCargadas,
  ) {
    final pct = notif.porcentajeEntero;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFDCEB),
              Color(0xFFFFF0F7),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.rosa,
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.rosa.withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    '¡Tenemos una nueva coincidencia! 💗',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF9D174D),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _descartarNotificacionCoincidencia(notif),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.rosa,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Esta mascota acaba de llegar a Paw Match y tiene una compatibilidad muy alta contigo. ¡Conócela!',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF8C6DC)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: PetImage(
                        url: notif.fotoMascota,
                        fit: BoxFit.contain,
                        backgroundColor: const Color(0xFFFFF5FA),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notif.nombreMascota,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.rosa,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$pct% Match',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosa,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () =>
                        _abrirMascotaDesdeNotificacion(notif, mascotasCargadas),
                    child: const Text(
                      'Ver perfil',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
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

  /// Buscador «Buscar por nombre o raza...» acompañado del botón de filtros
  /// (debajo del encabezado único «Nuestros Peluditos» de BarraSuperior).
  Widget _seccionBuscadorYFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Row(
        children: [
          // Buscador con texto «Buscar por nombre o raza...»
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _busqueda.isNotEmpty
                      ? AppColors.rosa
                      : const Color(0xFFF8C4DC),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rosa.withValues(alpha: 0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o raza...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
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
                            size: 18,
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
                    vertical: 11,
                    horizontal: 6,
                  ),
                ),
                onChanged: (v) => setState(() => _busqueda = v.trim()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Botón de filtros con icono de ajustes
          GestureDetector(
            onTap: _mostrarModalFiltros,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _filtrosActivosCount > 0
                    ? AppColors.rosa
                    : const Color(0xFFFFD8EA),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _filtrosActivosCount > 0
                      ? AppColors.rosa
                      : const Color(0xFFF9B8D4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rosa.withValues(
                      alpha: _filtrosActivosCount > 0 ? 0.28 : 0.12,
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
                    size: 21,
                    color: _filtrosActivosCount > 0
                        ? Colors.white
                        : AppColors.rosa,
                  ),
                  if (_filtrosActivosCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        child: Center(
                          child: Text(
                            '$_filtrosActivosCount',
                            style: const TextStyle(
                              color: AppColors.rosa,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
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

  /// Categorías horizontales: Todas, Disponibles, Apadrinadas y Adopción.
  Widget _barraEstado() {
    const opciones = ['Todas', 'Disponibles', 'Apadrinadas', 'Adopción'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: SizedBox(
        height: 36,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compacto = constraints.maxWidth < 390;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(opciones.length, (i) {
                    final valor = opciones[i];
                    final sel = _estado == valor;
                    return Padding(
                      padding: EdgeInsets.only(
                        right: i < opciones.length - 1 ? 6 : 0,
                      ),
                      child: GestureDetector(
                        onTap: () => setState(() => _estado = valor),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(
                            horizontal: compacto ? 12 : 15,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: sel
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFF6FB3),
                                      AppColors.rosa,
                                    ],
                                  )
                                : null,
                            color: sel ? null : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? AppColors.rosa
                                  : const Color(0xFFF8C4DC),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.rosa.withValues(
                                  alpha: sel ? 0.25 : 0.06,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            valor,
                            style: TextStyle(
                              fontSize: compacto ? 12.0 : 12.5,
                              fontWeight:
                                  sel ? FontWeight.w800 : FontWeight.w600,
                              color: sel
                                  ? Colors.white
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _grillaMascotas({
    required List<_ItemMascotaMatch> items,
    required int crossAxisCount,
    required double crossAxisSpacing,
    required double mainAxisExtent,
    required EdgeInsets padding,
    required String? idMejorMatch,
  }) {
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: 14,
          mainAxisExtent: mainAxisExtent,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final item = items[i];
            final pet = item.pet;
            final esAdmin = Session.esAdmin;
            final esMejor =
                !esAdmin &&
                idMejorMatch != null &&
                pet.id == idMejorMatch &&
                item.match != null;
            final esInicial =
                !esAdmin &&
                _idMascotaMatchInicial != null &&
                pet.id == _idMascotaMatchInicial;

            return PetCard(
              pet: pet,
              porcentajeMatch: esAdmin ? null : item.match,
              esMejorMatch: esMejor,
              esMatchInicial: esInicial,
              ocultarMatch: esAdmin,
              esFavorito: _favoritosIds.contains(pet.id),
              onToggleFavorito: () => _alternarFavorito(pet.id),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PetDetailScreen(pet: pet),
                  ),
                );
                if (!mounted) return;
                if (PetsService.mascotasEnMemoria.value != null) {
                  setState(() {
                    _listaVisible = PetsService.mascotasEnMemoria.value;
                  });
                } else {
                  _recargar();
                }
              },
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _chipActivo(String label, VoidCallback onClear) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
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
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.rosa,
            ),
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
            final activeInModal =
                (_especie != 'Todas' && _especie != 'Todos' ? 1 : 0) +
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

            Widget chipFiltro(
              String valor,
              String actual,
              ValueChanged<String> onSelected,
            ) {
              final sel = actual.toLowerCase() == valor.toLowerCase();
              return GestureDetector(
                onTap: () {
                  setModalState(() => onSelected(valor));
                  setState(() => onSelected(valor));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
                        const Icon(
                          Icons.tune_rounded,
                          color: AppColors.rosa,
                          size: 22,
                        ),
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

                    seccionTitulo('Categoría'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Todas',
                        'Disponibles',
                        'Apadrinadas',
                        'Adopción',
                      ].map((estado) {
                        return chipFiltro(estado, _estado, (v) => _estado = v);
                      }).toList(),
                    ),

                    seccionTitulo('Especie'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Todas', 'Perro', 'Gato', 'Otro'].map((esp) {
                        return chipFiltro(esp, _especie, (v) => _especie = v);
                      }).toList(),
                    ),

                    seccionTitulo('Sexo'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Todos', 'Macho', 'Hembra'].map((s) {
                        return chipFiltro(s, _sexo, (v) => _sexo = v);
                      }).toList(),
                    ),

                    seccionTitulo('Tamaño'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Todos', 'Pequeño', 'Mediano', 'Grande'].map((
                        t,
                      ) {
                        return chipFiltro(t, _tamano, (v) => _tamano = v);
                      }).toList(),
                    ),

                    seccionTitulo('Edad'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Todos', 'Cachorro', 'Adulto'].map((e) {
                        return chipFiltro(e, _edad, (v) => _edad = v);
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

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

  Widget _chipsActivos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
      child: SizedBox(
        height: 30,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
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
            if (_filtrosActivosCount > 0 ||
                _busqueda.isNotEmpty ||
                _especie != 'Todas') ...[
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
      backgroundColor: const Color(0xFFFFF0F6),
      floatingActionButton: esAdmin
          ? FloatingActionButton.extended(
              onPressed: _abrirFormularioNuevaMascota,
              icon: const Icon(Icons.add),
              label: const Text('Agregar mascota'),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE6F1),
              Color(0xFFFFF2F8),
              Color(0xFFFFF7FA),
            ],
          ),
        ),
        child: SafeArea(
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
                    if (snap.connectionState == ConnectionState.done &&
                        snap.hasData) {
                      _listaVisible ??= snap.data;
                    }
                    final origen =
                        PetsService.mascotasEnMemoria.value ??
                        _listaVisible ??
                        snap.data;

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Cuadrícula de DOS COLUMNAS en móvil, adaptable a tablets y computadores
                            final int crossAxisCount =
                                constraints.maxWidth >= 1040
                                    ? 4
                                    : (constraints.maxWidth >= 700 ? 3 : 2);
                            final double crossAxisSpacing =
                                constraints.maxWidth < 400 ? 10.0 : 14.0;
                            final double mainAxisExtent =
                                constraints.maxWidth < 380 ? 314.0 : 326.0;

                            Widget contenidoSliver;

                            if (origen == null) {
                              if (snap.connectionState !=
                                  ConnectionState.done) {
                                contenidoSliver = const SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.rosa,
                                    ),
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
                                    child: CircularProgressIndicator(
                                      color: AppColors.rosa,
                                    ),
                                  ),
                                );
                              }
                            } else {
                              final filtradas = _filtrar(
                                _conRecienAgregada(origen),
                              );
                              final ordenadas = _ordenarPorCompatibilidad(
                                filtradas,
                              );
                              _programarIrAlInicio();

                              if (ordenadas.isEmpty) {
                                contenidoSliver = SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: _vistaVacia(),
                                );
                              } else {
                                // Identificar la mascota con el mayor porcentaje de compatibilidad (#1 Mejor Match)
                                String? idMejorMatch;
                                if (ordenadas.first.match != null) {
                                  idMejorMatch = ordenadas.first.pet.id;
                                }

                                final inferior = esAdmin ? 88.0 : 28.0;
                                contenidoSliver = _grillaMascotas(
                                  items: ordenadas,
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: crossAxisSpacing,
                                  mainAxisExtent: mainAxisExtent,
                                  idMejorMatch: idMejorMatch,
                                  padding: EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    12,
                                    inferior,
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
                                    child: _seccionBuscadorYFiltros(),
                                  ),
                                  SliverToBoxAdapter(
                                    child: _barraEstado(),
                                  ),
                                  if (_filtrosActivosCount > 0)
                                    SliverToBoxAdapter(
                                      child: _chipsActivos(),
                                    ),
                                  if (!esAdmin &&
                                      _notificacionesPendientes.isNotEmpty)
                                    SliverToBoxAdapter(
                                      child: _bannerNuevaCoincidencia(
                                        _notificacionesPendientes.first,
                                        origen ?? const <Pet>[],
                                      ),
                                    ),
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 4),
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
      ),
    );
  }
}

class _ItemMascotaMatch {
  final Pet pet;
  final double? match;

  const _ItemMascotaMatch({
    required this.pet,
    required this.match,
  });
}
