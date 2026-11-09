/** Edad que se muestra, calculada desde la fecha de nacimiento. */

function sqlEdad(alias = 'm') {
  const fecha = `${alias}.fecha_nacimiento`;
  const intervalo = `AGE(CURRENT_DATE, ${fecha})`;
  return `CASE
    WHEN ${fecha} IS NULL THEN ${alias}.edad
    WHEN ${intervalo} < INTERVAL '1 year' THEN (
      EXTRACT(YEAR FROM ${intervalo}) * 12 + EXTRACT(MONTH FROM ${intervalo})
    )::int
    ELSE EXTRACT(YEAR FROM ${intervalo})::int
  END`;
}

function sqlUnidadEdad(alias = 'm') {
  const fecha = `${alias}.fecha_nacimiento`;
  return `CASE
    WHEN ${fecha} IS NULL THEN ${alias}.unidad_edad
    WHEN AGE(CURRENT_DATE, ${fecha}) < INTERVAL '1 year' THEN 'meses'
    ELSE 'anos'
  END`;
}

function leerFechaNacimiento(valor, { obligatoria = true } = {}) {
  if (valor == null || String(valor).trim() === '') {
    if (!obligatoria) return { fecha: null, edad: null, unidad: null };
    return { error: 'La fecha de nacimiento es obligatoria' };
  }
  const texto = String(valor).slice(0, 10);
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(texto);
  if (!match) return { error: 'La fecha de nacimiento no es válida' };
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const fecha = new Date(Date.UTC(year, month - 1, day));
  if (
    fecha.getUTCFullYear() !== year ||
    fecha.getUTCMonth() !== month - 1 ||
    fecha.getUTCDate() !== day
  ) {
    return { error: 'La fecha de nacimiento no es válida' };
  }
  const hoy = new Date();
  const hoyUtc = Date.UTC(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());
  if (fecha.getTime() > hoyUtc) {
    return { error: 'La fecha de nacimiento no puede ser futura' };
  }
  const limite = new Date(Date.UTC(hoy.getFullYear() - 35, hoy.getMonth(), hoy.getDate()));
  if (fecha.getTime() < limite.getTime()) {
    return { error: 'La mascota no puede tener más de 35 años' };
  }
  let years = hoy.getFullYear() - year;
  let months = hoy.getMonth() + 1 - month;
  if (hoy.getDate() < day) months -= 1;
  if (months < 0) {
    years -= 1;
    months += 12;
  }
  if (years < 0) years = 0;
  return {
    fecha: texto,
    edad: years < 1 ? months : years,
    unidad: years < 1 ? 'meses' : 'anos',
  };
}

module.exports = { sqlEdad, sqlUnidadEdad, leerFechaNacimiento };
