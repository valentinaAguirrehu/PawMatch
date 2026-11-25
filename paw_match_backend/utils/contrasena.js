const MENSAJE_CONTRASENA =
  'La contraseña debe tener mínimo 8 caracteres, al menos una mayúscula (A-Z), una minúscula (a-z), un número (0-9) y un carácter especial (@, #, $, %, &, *).';

function contrasenaInvalida(valor) {
  const pass = String(valor || '');
  return (
    pass.length < 8 ||
    !/[A-Z]/.test(pass) ||
    !/[a-z]/.test(pass) ||
    !/[0-9]/.test(pass) ||
    !/[@#$%&*]/.test(pass)
  );
}

module.exports = { MENSAJE_CONTRASENA, contrasenaInvalida };
