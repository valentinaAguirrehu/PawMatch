/// Misma exigencia en registro, recuperación, perfil y administradores.
String? validarContrasena(String? valor, {bool obligatoria = true}) {
  if (valor == null || valor.isEmpty) {
    return obligatoria ? 'Requerido' : null;
  }
  if (valor.length < 8) return 'Tener mínimo 8 caracteres.';
  if (!RegExp(r'[A-Z]').hasMatch(valor)) {
    return 'Contener al menos una letra mayúscula (A-Z).';
  }
  if (!RegExp(r'[a-z]').hasMatch(valor)) {
    return 'Contener al menos una letra minúscula (a-z).';
  }
  if (!RegExp(r'[0-9]').hasMatch(valor)) {
    return 'Contener al menos un número (0-9).';
  }
  if (!RegExp(r'[@#$%&*]').hasMatch(valor)) {
    return r'Contener al menos un carácter especial (@, #, $, %, &, *).';
  }
  return null;
}
