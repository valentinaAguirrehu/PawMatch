import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/user.dart';
import 'package:paw_match/screens/users/profile_screen.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';

/// Revisa el perfil antes de abrir la solicitud de adopción.
/// Devuelve true solo cuando todos los datos ya están completos.
Future<bool> perfilListoParaAdoptar(BuildContext context) async {
  final id = Session.idUsuario;
  if (id == null || id.isEmpty) {
    _aviso(context, 'No hay una sesión activa');
    return false;
  }

  final navegador = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  late final User usuario;
  try {
    usuario = await ApiService.obtenerUsuario(id);
  } catch (e) {
    navegador.pop();
    if (context.mounted) {
      _aviso(context, e.toString().replaceFirst('Exception: ', ''));
    }
    return false;
  }

  navegador.pop();
  if (!context.mounted) return false;
  if (usuario.perfilCompleto) return true;

  final completar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.assignment_late_outlined,
        color: AppColors.rosa,
        size: 48,
      ),
      title: const Text('Información pendiente'),
      content: Text(
        'Tienes información pendiente por llenar en tu perfil antes de '
        'continuar con la solicitud de adopción.\n\n'
        'Falta: ${usuario.datosPendientes.join(', ')}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rosa),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Completar perfil'),
        ),
      ],
    ),
  );

  if (completar == true && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Editar perfil')),
          body: const ProfileScreen(iniciarEnEdicion: true),
        ),
      ),
    );
  }
  return false;
}

void _aviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
}
