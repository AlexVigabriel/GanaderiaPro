// HU-12: indicadores generales del rancho (GET /api/tablero/resumen).
class ResumenTablero {
  const ResumenTablero({
    required this.animalesActivos,
    required this.machosActivos,
    required this.hembrasActivas,
    required this.vacunados,
    required this.vacunacionesPendientes,
    required this.proximasAParir,
    required this.fallecidosDelAnio,
    required this.corralesActivos,
  });

  final int animalesActivos;
  final int machosActivos;
  final int hembrasActivas;
  final int vacunados;
  final int vacunacionesPendientes;
  final int proximasAParir;
  final int fallecidosDelAnio;
  final int corralesActivos;

  factory ResumenTablero.fromJson(Map<String, dynamic> json) => ResumenTablero(
        animalesActivos: json['animalesActivos'] as int,
        machosActivos: json['machosActivos'] as int,
        hembrasActivas: json['hembrasActivas'] as int,
        vacunados: json['vacunados'] as int,
        vacunacionesPendientes: json['vacunacionesPendientes'] as int,
        proximasAParir: json['proximasAParir'] as int,
        fallecidosDelAnio: json['fallecidosDelAnio'] as int,
        corralesActivos: json['corralesActivos'] as int,
      );
}
