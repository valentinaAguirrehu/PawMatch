import 'package:flutter/material.dart';

class MenuScreen extends StatefulWidget {
  final String nombre;

  const MenuScreen({super.key, required this.nombre});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _indice = 0;

  void _cerrarSesion() {
    // Vuelve a la primera pantalla (bienvenida)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final paginas = <Widget>[
      _Inicio(nombre: widget.nombre),
      const _Marcador(icono: Icons.pets, texto: 'Mascotas'),
      const _Marcador(icono: Icons.favorite, texto: 'Match'),
      const _Marcador(icono: Icons.volunteer_activism, texto: 'Apadrinar'),
      _Perfil(nombre: widget.nombre, onCerrarSesion: _cerrarSesion),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paw Match'),
        automaticallyImplyLeading: false,
      ),
      body: paginas[_indice],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.pets), label: 'Mascotas'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Match'),
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism),
            label: 'Apadrinar',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

class _Inicio extends StatelessWidget {
  final String nombre;
  const _Inicio({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '¡Hola, $nombre!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('¿Qué quieres hacer hoy?'),
        const SizedBox(height: 20),
        const _Tarjeta(
          icono: Icons.pets,
          titulo: 'Ver mascotas',
          detalle: 'Conoce a los peludos que buscan hogar',
        ),
        const _Tarjeta(
          icono: Icons.favorite,
          titulo: 'Encuentra tu match',
          detalle: 'Descubre qué mascota va con tu personalidad',
        ),
        const _Tarjeta(
          icono: Icons.volunteer_activism,
          titulo: 'Apadrinar',
          detalle: 'Apoya a una mascota sin adoptarla',
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;

  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icono, size: 32),
        title: Text(titulo),
        subtitle: Text(detalle),
      ),
    );
  }
}

class _Marcador extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Marcador({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 64),
          const SizedBox(height: 12),
          Text('$texto (próximamente)'),
        ],
      ),
    );
  }
}

class _Perfil extends StatelessWidget {
  final String nombre;
  final VoidCallback onCerrarSesion;
  const _Perfil({required this.nombre, required this.onCerrarSesion});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 12),
          Text(nombre, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onCerrarSesion,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
