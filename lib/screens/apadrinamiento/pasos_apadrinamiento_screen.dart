import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';

/// Pantalla informativa previa al formulario de apadrinamiento.
/// Explica en qué consiste, cómo funciona, beneficios y requisitos,
/// exigiendo dos casillas obligatorias independientes para continuar.
class PasosApadrinamientoScreen extends StatefulWidget {
  final Pet pet;

  const PasosApadrinamientoScreen({
    super.key,
    required this.pet,
  });

  static Future<bool> mostrar(BuildContext context, {required Pet pet}) async {
    final seguir = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PasosApadrinamientoScreen(pet: pet),
      ),
    );
    return seguir == true;
  }

  @override
  State<PasosApadrinamientoScreen> createState() =>
      _PasosApadrinamientoScreenState();
}

class _PasosApadrinamientoScreenState extends State<PasosApadrinamientoScreen> {
  bool _aceptoCondiciones = false;

  bool get _puedeContinuar => _aceptoCondiciones;

  static const List<String> _requisitos = [
    'Brindar información personal verídica y actualizada.',
    'Cumplir de manera responsable con la modalidad de ayuda elegida.',
    'Respetar los canales de contacto y coordinación del albergue.',
    'Asumir el compromiso con respeto hacia las necesidades de la mascota.',
    'Aceptar el tratamiento de datos personales según la política de privacidad.',
  ];

  @override
  Widget build(BuildContext context) {
    final nombreMascota = widget.pet.nombre.trim().isNotEmpty
        ? widget.pet.nombre.trim()
        : 'la mascota';
    final sexo = (widget.pet.sexo ?? '').trim().toLowerCase();
    final visita = sexo.startsWith('m')
        ? 'Visitarlo en los horarios establecidos por el albergue.'
        : 'Visitarla en los horarios establecidos por el albergue.';
    final beneficios = [
      'Realizar aportes según tus posibilidades.',
      visita,
      'Contribuir a su bienestar emocional y socialización.',
      'Recibir actualizaciones periódicas sobre su evolución.',
      'Apoyar las necesidades de la mascota y del albergue.',
    ];

    final pasos = [
      (
        titulo: 'Paso 1. Registra tus datos',
        texto:
            'Completa el formulario con tu información personal, los datos de contacto y la modalidad de ayuda que deseas ofrecer para $nombreMascota.',
      ),
      (
        titulo: 'Paso 2. Formaliza tu compromiso',
        texto:
            'Una vez recibamos tu información, nos pondremos en contacto contigo para revisar los datos, resolver tus dudas y coordinar los detalles del apadrinamiento.',
      ),
      (
        titulo: 'Paso 3. Acompaña su evolución',
        texto:
            'Comienza a contribuir según la modalidad y la frecuencia acordadas. Podrás recibir actualizaciones sobre el bienestar de $nombreMascota y conocer los avances de su proceso.',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFDF0F3),
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera superior
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
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
                  ),
                  Expanded(
                    child: Text(
                      'Apadrinar a $nombreMascota',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E272E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ),

            // Contenido desplazable
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  // Sección 1: ¿En qué consiste el apadrinamiento?
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.bordeRosa),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.rosa.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.rosaSuave,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.volunteer_activism_rounded,
                                color: AppColors.rosa,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                '¿En qué consiste el apadrinamiento?',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E272E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'El apadrinamiento es un acto voluntario para contribuir al bienestar de $nombreMascota mientras encuentra un hogar definitivo.',
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tu apoyo te permitirá:',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E272E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final b in beneficios) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    color: AppColors.rosa,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    b,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Tu ayuda no solo beneficia a $nombreMascota, sino también a otros animales que esperan una familia. ¡Cada aporte cuenta!',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Sección 2: ¿Cómo funciona el apadrinamiento?
                  const Text(
                    '¿Cómo funciona el apadrinamiento?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E272E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < pasos.length; i++) ...[
                    _PasoApadrinamiento(
                      numero: i + 1,
                      titulo: pasos[i].titulo,
                      texto: pasos[i].texto,
                    ),
                    if (i < pasos.length - 1) const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 24),

                  // Sección 3: Requisitos y condiciones del apadrinamiento
                  const Text(
                    'Requisitos y condiciones del apadrinamiento',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E272E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final req in _requisitos) ...[
                    _RequisitoApadrinamiento(texto: req),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 16, 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _aceptoCondiciones = !_aceptoCondiciones),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _aceptoCondiciones,
                      activeColor: AppColors.rosa,
                      side: const BorderSide(color: AppColors.rosa, width: 1.6),
                      onChanged: (valor) => setState(() => _aceptoCondiciones = valor ?? false),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'He leído, comprendo el proceso y acepto los requisitos y condiciones del apadrinamiento.',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: AppColors.texto,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosa,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.rosa.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _puedeContinuar ? () => Navigator.pop(context, true) : null,
                  child: const Text(
                    'Continuar al formulario',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasoApadrinamiento extends StatelessWidget {
  final int numero;
  final String titulo;
  final String texto;

  const _PasoApadrinamiento({
    required this.numero,
    required this.titulo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.rosa,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E272E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequisitoApadrinamiento extends StatelessWidget {
  final String texto;

  const _RequisitoApadrinamiento({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.rosa,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E272E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
