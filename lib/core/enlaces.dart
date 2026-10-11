import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre un enlace (web, WhatsApp, redes, mapa). Si aún no está configurado, avisa.
Future<void> abrirEnlace(BuildContext context, String? url, {String nombre = 'el enlace'}) async {
  final mensajero = ScaffoldMessenger.of(context);
  if (url == null || url.isEmpty) {
    mensajero.showSnackBar(SnackBar(content: Text('El enlace de $nombre aún no está configurado')));
    return;
  }
  try {
    final abrio = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!abrio) mensajero.showSnackBar(SnackBar(content: Text('No se pudo abrir $nombre')));
  } catch (_) {
    mensajero.showSnackBar(SnackBar(content: Text('No se pudo abrir $nombre')));
  }
}
