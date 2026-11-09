import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/widgets/punto_inicio.dart';

/// Acordeón: toca un punto y se despliega su explicación.
class AcordeonInicio extends StatefulWidget {
  final List<PuntoInicio> items;

  const AcordeonInicio({super.key, required this.items});

  @override
  State<AcordeonInicio> createState() => _AcordeonInicioState();
}

class _AcordeonInicioState extends State<AcordeonInicio> {
  int _abierto = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < widget.items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ItemAcordeon(
              punto: widget.items[i],
              abierto: i == _abierto,
              onTap: () => setState(() => _abierto = i == _abierto ? -1 : i),
            ),
          ),
      ],
    );
  }
}

class _ItemAcordeon extends StatelessWidget {
  final PuntoInicio punto;
  final bool abierto;
  final VoidCallback onTap;

  const _ItemAcordeon({
    required this.punto,
    required this.abierto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: abierto ? AppColors.rosa : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: abierto ? AppColors.rosa : AppColors.bordeRosa,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: abierto
                            ? Colors.white.withValues(alpha: 0.2)
                            : AppColors.rosaSuave,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        punto.icono,
                        size: 21,
                        color: abierto ? Colors.white : AppColors.rosa,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        punto.titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: abierto ? Colors.white : AppColors.texto,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: abierto ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: abierto ? Colors.white : AppColors.rosa,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: abierto
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(52, 10, 6, 2),
                          child: Text(
                            punto.texto,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
