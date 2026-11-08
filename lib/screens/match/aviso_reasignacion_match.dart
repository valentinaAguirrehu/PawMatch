import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/services/match_service.dart';

final Set<String> _avisosEnCurso = <String>{};

/// Muestra una sola vez el aviso de que el Match Ideal fue adoptado
/// y ya hay un peludito nuevo asignado.
Future<void> mostrarAvisoReasignacionMatch(
  BuildContext context, {
  required String? idAviso,
  required String? nombreAnterior,
}) async {
  final id = idAviso?.trim() ?? '';
  final nombre = nombreAnterior?.trim() ?? '';
  if (id.isEmpty || nombre.isEmpty) return;
  if (!_avisosEnCurso.add(id)) return;
  if (!context.mounted) {
    _avisosEnCurso.remove(id);
    return;
  }

  final mensaje =
      '¡Nos alegra contarle que $nombre ya fue adoptado y hoy vive en un hogar feliz! '
      'Para continuar con su búsqueda, le hemos conectado con un nuevo peludito que comparte una gran compatibilidad contigo.';

  try {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: const Icon(Icons.favorite_rounded, color: AppColors.rosa, size: 36),
          title: const Text(
            'Tu Match Ideal encontró hogar',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          content: Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, height: 1.4, color: Color(0xFF3D3338)),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rosa,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
    await MatchService.marcarAvisoReasignacionVisto(id);
  } catch (_) {
    _avisosEnCurso.remove(id);
  }
}
