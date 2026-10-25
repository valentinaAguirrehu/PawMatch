import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> mostrarDialogoPrevisualizarVideo(
  BuildContext context, {
  required String nombre,
  required Uint8List bytes,
  required int tamanoBytes,
}) async {
  String? filePath;
  try {
    final tempDir = await Directory.systemTemp.createTemp('paw_video_');
    final sanitizedName = nombre.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final tempFile = File('${tempDir.path}/$sanitizedName');
    await tempFile.writeAsBytes(bytes);
    filePath = tempFile.path;

    final uri = Uri.file(filePath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  } catch (_) {}

  if (!context.mounted) return;

  final mb = (tamanoBytes / (1024 * 1024)).toStringAsFixed(2);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.videocam_rounded, color: AppColors.rosa, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.rosaSuave,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Tamaño: $mb MB • Video cargado',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.rosa, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'El video ha sido cargado correctamente en memoria y se envió la orden al reproductor del sistema.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          if (filePath != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosa,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Volver a reproducir en el reproductor'),
                onPressed: () {
                  final uri = Uri.file(filePath!);
                  launchUrl(uri);
                },
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
