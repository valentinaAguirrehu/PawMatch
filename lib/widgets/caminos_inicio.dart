import 'package:flutter/material.dart';
import 'package:paw_match/widgets/fila_punto.dart';
import 'package:paw_match/widgets/foto_tarjeta.dart';

const _rosa = Color(0xFFEF4FA0);

class _Camino {
  final String etiqueta;
  final String titulo;
  final String texto;
  final String asset;
  final List<(IconData, String, String)> puntos;

  const _Camino({
    required this.etiqueta,
    required this.titulo,
    required this.texto,
    required this.asset,
    required this.puntos,
  });
}

const _caminos = [
  _Camino(
    etiqueta: 'Adoptar',
    titulo: 'Una segunda oportunidad',
    texto:
        'Adoptar es salvar dos vidas: la del animal que acoges y la del próximo rescatado que ocupará su lugar en el refugio.',
    asset: 'assets/images/inicio/familia.jpg',
    puntos: [
      (
        Icons.favorite_rounded,
        'Amor incondicional',
        'Los animales rescatados crean un vínculo único con quienes les abren su hogar.'
      ),
      (
        Icons.loop_rounded,
        'Rompes el ciclo del abandono',
        'Elegir adoptar frente a comprar impulsa el bienestar colectivo.'
      ),
      (
        Icons.home_rounded,
        'Un nuevo miembro en la familia',
        'Alegría, compañía sincera y momentos inolvidables.'
      ),
    ],
  ),
  _Camino(
    etiqueta: 'Apadrinar',
    titulo: 'Sé su ángel guardián',
    texto:
        'Si no puedes adoptar ahora, ¡está bien! Apadrina a un animal mientras encuentra hogar o vive en el refugio.',
    asset: 'assets/images/inicio/juntos.jpg',
    puntos: [
      (
        Icons.restaurant_rounded,
        'Tu aporte mensual cubre',
        'Alimentación, atención médica, vacunas y un espacio seguro.'
      ),
      (
        Icons.photo_camera_rounded,
        'Un vínculo real',
        'Recibes noticias y fotos del progreso de tu ahijado.'
      ),
      (
        Icons.favorite_border_rounded,
        'Amor a la distancia',
        'Puedes visitarlo y acompañar su recuperación.'
      ),
    ],
  ),
];

/// Una sola sección con pestañas para Adoptar / Apadrinar.
class CaminosInicio extends StatefulWidget {
  final VoidCallback onVerMatch;
  const CaminosInicio({super.key, required this.onVerMatch});

  @override
  State<CaminosInicio> createState() => _CaminosInicioState();
}

class _CaminosInicioState extends State<CaminosInicio> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final c = _caminos[_i];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Cómo quieres ayudar?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2B2B2B),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: List.generate(_caminos.length, (idx) {
                final activo = idx == _i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _i = idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: activo ? _rosa : Colors.transparent,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _caminos[idx].etiqueta,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: activo ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Column(
              key: ValueKey(_i),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  c.texto,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                FotoTarjeta(
                  asset: c.asset,
                  alto: 190,
                  pie: _i == 0 ? 'Toca para conocer a tu alma gemela' : null,
                  onTap: _i == 0 ? widget.onVerMatch : null,
                ),
                const SizedBox(height: 16),
                for (var k = 0; k < c.puntos.length; k++)
                  FilaPunto(
                    icono: c.puntos[k].$1,
                    titulo: c.puntos[k].$2,
                    texto: c.puntos[k].$3,
                    ultimo: k == c.puntos.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
