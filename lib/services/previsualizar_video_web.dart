import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:web/web.dart' as web;

Future<void> mostrarDialogoPrevisualizarVideo(
  BuildContext context, {
  required String nombre,
  required Uint8List bytes,
  required int tamanoBytes,
}) async {
  String mime = 'video/mp4';
  final lower = nombre.toLowerCase();
  if (lower.endsWith('.webm')) {
    mime = 'video/webm';
  } else if (lower.endsWith('.mov')) {
    mime = 'video/quicktime';
  } else if (lower.endsWith('.avi')) {
    mime = 'video/x-msvideo';
  } else if (lower.endsWith('.3gp')) {
    mime = 'video/3gpp';
  } else if (lower.endsWith('.mkv')) {
    mime = 'video/x-matroska';
  }

  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final blobUrl = web.URL.createObjectURL(blob);
  final viewId = 'video-preview-${DateTime.now().microsecondsSinceEpoch}';

  final videoElement = web.HTMLVideoElement()
    ..src = blobUrl
    ..controls = true
    ..autoplay = true
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.borderRadius = '12px'
    ..style.backgroundColor = '#000000'
    ..style.objectFit = 'contain';

  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int _) => videoElement,
  );

  final mb = (tamanoBytes / (1024 * 1024)).toStringAsFixed(2);

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      final dialogWidth = size.width > 700 ? 640.0 : size.width * 0.92;
      final videoHeight = (dialogWidth * 9 / 16).clamp(220.0, 380.0);

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogWidth),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.rosaSuave,
                        child: Icon(Icons.videocam_rounded, color: AppColors.rosa),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$mb MB • Video cargado antes de enviar',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Cerrar',
                        onPressed: () {
                          videoElement.pause();
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: videoHeight,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.bordeRosa),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: HtmlElementView(viewType: viewId),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.rosa,
                          side: const BorderSide(color: AppColors.bordeRosa),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Abrir en pestaña completa'),
                        onPressed: () => web.window.open(blobUrl, '_blank'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.rosa,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          videoElement.pause();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Entendido / Cerrar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  videoElement.pause();
  web.URL.revokeObjectURL(blobUrl);
}
