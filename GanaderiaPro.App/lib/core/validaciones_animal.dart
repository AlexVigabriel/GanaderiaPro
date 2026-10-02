// Las mismas reglas que valida el servidor (AnimalService). Se repiten acá
// solo para avisar antes de enviar; el servidor siempre vuelve a validar.
const double pesoMaximoKg = 1500;

String? validarArete(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'El arete es obligatorio';
  if (texto.length > 50) return 'Hasta 50 caracteres';
  return null;
}

String? validarRaza(String? valor) =>
    (valor == null || valor.trim().isEmpty) ? 'La raza es obligatoria' : null;

String? validarSexo(String? valor) => (valor == null || valor.isEmpty) ? 'Elegí el sexo' : null;

// RN-14: no se registran fechas futuras.
String? validarFechaNacimiento(DateTime? fecha) {
  if (fecha == null) return null;
  final hoy = DateTime.now();
  final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
  return fecha.isAfter(soloHoy) ? 'La fecha de nacimiento no puede ser futura' : null;
}

String? validarPeso(String? valor) {
  final texto = valor?.trim().replaceAll(',', '.') ?? '';
  if (texto.isEmpty) return null;
  final peso = double.tryParse(texto);
  if (peso == null) return 'Ingresá un número';
  if (peso <= 0 || peso > pesoMaximoKg) return 'Debe ser mayor que 0 y de hasta 1500 kg';
  return null;
}

String? validarLargo(String? valor, int maximo) =>
    (valor != null && valor.trim().length > maximo) ? 'Hasta $maximo caracteres' : null;

double? leerPeso(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));
