import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/services/acuerdo_adopcion_pdf_service.dart';

/// Primera pantalla de la adopción: pasos y requisitos, antes del formulario.
class PasosAdopcionScreen extends StatefulWidget {
  const PasosAdopcionScreen({super.key});

  static Future<bool> mostrar(BuildContext context) async {
    final seguir = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PasosAdopcionScreen()),
    );
    return seguir == true;
  }

  @override
  State<PasosAdopcionScreen> createState() => _PasosAdopcionScreenState();
}

class _PasosAdopcionScreenState extends State<PasosAdopcionScreen> {
  bool _acepto = false;

  static const _pasos = [
    (
      titulo: 'Confirma la adopción de tu peludito',
      texto:
          'Estás a un paso de cambiarle la vida al amigo que elegiste. Revisa sus detalles y da inicio formal a su solicitud de adopción.',
    ),
    (
      titulo: 'Diligencia el formulario de adopción',
      texto:
          'Queremos saber un poco sobre ti, tu hogar y tu experiencia previa conviviendo con peluditos.',
    ),
    (
      titulo: 'Entrevista y visita domiciliaria',
      texto:
          'Realizaremos una breve entrevista y, de ser necesario, agendaremos una visita a tu vivienda para confirmar de que sea un entorno seguro.',
    ),
    (
      titulo: '¡Un nuevo integrante en la familia!',
      texto:
          'Al completar el proceso con éxito y firmar el contrato formal de adopción, le darás la bienvenida oficial a tu hogar.',
    ),
  ];

  static const _requisitos = AcuerdoAdopcionPdfService.requisitosImportantes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF0F3),
      body: SafeArea(
        child: Column(
          children: [
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
                  const Expanded(
                    child: Text(
                      'Pasos para adoptar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E272E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  for (var i = 0; i < _pasos.length; i++) ...[
                    _Paso(
                      numero: i + 1,
                      titulo: _pasos[i].titulo,
                      texto: _pasos[i].texto,
                    ),
                    if (i < _pasos.length - 1) const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 26),
                  const Text(
                    'Requisitos Importantes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E272E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final requisito in _requisitos) ...[
                    _Requisito(texto: requisito),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.rosaSuave,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.bordeRosa),
                    ),
                    child: const Text(
                      '“Adoptar va mucho más allá de dar un techo; es abrirle la puerta a un amor puro e incondicional que cambiará tu vida para siempre.”',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: AppColors.texto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 16, 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _acepto = !_acepto),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acepto,
                      activeColor: AppColors.rosa,
                      side: const BorderSide(color: AppColors.rosa, width: 1.6),
                      onChanged: (valor) => setState(() => _acepto = valor ?? false),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'He leído los términos de adopción y me comprometo a cumplir con todas las condiciones indicadas.',
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
                  onPressed: _acepto ? () => Navigator.pop(context, true) : null,
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

class _Paso extends StatelessWidget {
  final int numero;
  final String titulo;
  final String texto;

  const _Paso({
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
                fontWeight: FontWeight.w800,
                fontSize: 15,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E272E),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Colors.grey.shade700,
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

class _Requisito extends StatelessWidget {
  final String texto;

  const _Requisito({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordeRosa.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.rosa, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppColors.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
