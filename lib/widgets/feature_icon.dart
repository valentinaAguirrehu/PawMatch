import 'package:flutter/material.dart';

/// Iconos de la app. Las pantallas solo los llaman.
class FeatureIcon extends StatelessWidget {
  final IconData icono;
  final double tamano;
  final Color? color;

  const FeatureIcon({
    super.key,
    required this.icono,
    this.tamano = 24,
    this.color,
  });

  const FeatureIcon.mascota({super.key, this.tamano = 20, this.color})
    : icono = Icons.pets;

  const FeatureIcon.volver({super.key, this.tamano = 24, this.color})
    : icono = Icons.arrow_back_rounded;

  const FeatureIcon.correcto({super.key, this.tamano = 22, this.color})
    : icono = Icons.check_circle_rounded;

  const FeatureIcon.calendario({super.key, this.tamano = 24, this.color})
    : icono = Icons.calendar_month_outlined;

  const FeatureIcon.ocultarContrasena({super.key, this.tamano = 24, this.color})
    : icono = Icons.visibility_off_outlined;

  const FeatureIcon.mostrarContrasena({super.key, this.tamano = 24, this.color})
    : icono = Icons.visibility_outlined;

  const FeatureIcon.adopcion({super.key, this.tamano = 24, this.color})
    : icono = Icons.pets_outlined;

  const FeatureIcon.apadrinamiento({super.key, this.tamano = 24, this.color})
    : icono = Icons.volunteer_activism_outlined;

  const FeatureIcon.compatibilidad({super.key, this.tamano = 24, this.color})
    : icono = Icons.favorite_outline;

  const FeatureIcon.iniciarSesion({super.key, this.tamano = 20, this.color})
    : icono = Icons.login_rounded;

  const FeatureIcon.registrarse({super.key, this.tamano = 20, this.color})
    : icono = Icons.person_add_alt_1_outlined;

  const FeatureIcon.sobre({super.key, this.tamano = 24, this.color})
    : icono = Icons.email_outlined;

  const FeatureIcon.cerradura({super.key, this.tamano = 24, this.color})
    : icono = Icons.lock_outline;

  const FeatureIcon.pin({super.key, this.tamano = 24, this.color})
    : icono = Icons.pin_outlined;

  const FeatureIcon.restablecer({super.key, this.tamano = 24, this.color})
    : icono = Icons.lock_reset;

  const FeatureIcon.persona({super.key, this.tamano = 24, this.color})
    : icono = Icons.person_outline;

  const FeatureIcon.perfil({super.key, this.tamano = 24, this.color})
    : icono = Icons.account_circle_outlined;

  const FeatureIcon.editar({super.key, this.tamano = 24, this.color})
    : icono = Icons.edit_outlined;

  const FeatureIcon.direccion({super.key, this.tamano = 24, this.color})
    : icono = Icons.location_on_outlined;

  const FeatureIcon.documento({super.key, this.tamano = 24, this.color})
    : icono = Icons.badge_outlined;

  const FeatureIcon.telefono({super.key, this.tamano = 24, this.color})
    : icono = Icons.phone_outlined;

  const FeatureIcon.inicio({super.key, this.tamano = 24, this.color})
    : icono = Icons.home_rounded;

  const FeatureIcon.cerrarSesion({super.key, this.tamano = 24, this.color})
    : icono = Icons.logout;

  const FeatureIcon.gestionar({super.key, this.tamano = 24, this.color})
    : icono = Icons.edit_note;

  const FeatureIcon.buscar({super.key, this.tamano = 24, this.color})
    : icono = Icons.search;

  const FeatureIcon.apadrinar({super.key, this.tamano = 24, this.color})
    : icono = Icons.volunteer_activism;

  const FeatureIcon.sinConexion({super.key, this.tamano = 24, this.color})
    : icono = Icons.cloud_off;

  static const huella = '🐾';

  @override
  Widget build(BuildContext context) {
    return Icon(icono, size: tamano, color: color);
  }
}
