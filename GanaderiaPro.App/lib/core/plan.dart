// HU-58: uso del plan del rancho frente a sus límites (RN-11).
class UsoRecurso {
  const UsoRecurso({
    required this.recurso,
    required this.usados,
    this.limite,
    this.porcentaje,
    required this.cercaDelLimite,
    required this.lleno,
  });

  // Animales, Colaboradores o Socios.
  final String recurso;
  final int usados;
  // null: el plan no tiene límite para este recurso.
  final int? limite;
  final int? porcentaje;
  final bool cercaDelLimite;
  final bool lleno;

  factory UsoRecurso.fromJson(Map<String, dynamic> json) => UsoRecurso(
    recurso: json['recurso'] as String,
    usados: json['usados'] as int,
    limite: json['limite'] as int?,
    porcentaje: json['porcentaje'] as int?,
    cercaDelLimite: json['cercaDelLimite'] as bool,
    lleno: json['lleno'] as bool,
  );
}

class UsoPlan {
  const UsoPlan({required this.nombrePlan, this.planSiguiente, required this.recursos});

  final String nombrePlan;
  final String? planSiguiente;
  final List<UsoRecurso> recursos;

  UsoRecurso? de(String recurso) => recursos.where((r) => r.recurso == recurso).firstOrNull;

  factory UsoPlan.fromJson(Map<String, dynamic> json) => UsoPlan(
    nombrePlan: json['nombrePlan'] as String,
    planSiguiente: json['planSiguiente'] as String?,
    recursos: (json['recursos'] as List<dynamic>).map((r) => UsoRecurso.fromJson(r as Map<String, dynamic>)).toList(),
  );
}

const nombresDeRecurso = {'Animales': 'animales activos', 'Colaboradores': 'colaboradores', 'Socios': 'socios'};

// Texto del aviso al 90 % o al llegar al límite (null si no hace falta avisar).
String? avisoDeLimite(UsoPlan uso, String recurso) {
  final r = uso.de(recurso);
  if (r == null || r.limite == null || !(r.cercaDelLimite || r.lleno)) return null;
  final nombre = nombresDeRecurso[recurso] ?? recurso;
  final sugerencia = uso.planSiguiente == null ? '' : ' Para sumar más, pasate al plan ${uso.planSiguiente}.';
  return r.lleno
      ? 'Llegaste al límite de tu plan ${uso.nombrePlan}: ${r.usados} de ${r.limite} $nombre.$sugerencia'
      : 'Usaste ${r.usados} de ${r.limite} $nombre de tu plan ${uso.nombrePlan}.$sugerencia';
}
