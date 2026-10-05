import 'package:flutter/material.dart';

import '../plan.dart';

// HU-58: franja de aviso cuando el uso llega al 90 % o al límite del plan.
class AvisoLimitePlan extends StatelessWidget {
  const AvisoLimitePlan({super.key, required this.uso, required this.recurso});

  final UsoPlan? uso;
  final String recurso;

  @override
  Widget build(BuildContext context) {
    final texto = uso == null ? null : avisoDeLimite(uso!, recurso);
    if (texto == null) return const SizedBox.shrink();

    final tema = Theme.of(context);
    final lleno = uso!.de(recurso)!.lleno;
    final color = lleno ? tema.colorScheme.error : const Color(0xFFB7791F);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(lleno ? Icons.block : Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: tema.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// HU-58: tarjeta "Tu plan" del tablero: uso de cada recurso con su barra.
class TarjetaPlan extends StatelessWidget {
  const TarjetaPlan({super.key, required this.uso});

  final UsoPlan uso;

  static const _titulos = {'Animales': 'Animales activos', 'Colaboradores': 'Colaboradores', 'Socios': 'Socios'};

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: tema.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Tu plan ${uso.nombrePlan}', style: tema.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 20),
            for (final r in uso.recursos) ...[
              _FilaUso(titulo: _titulos[r.recurso] ?? r.recurso, uso: r),
              const SizedBox(height: 16),
            ],
            if (uso.planSiguiente != null)
              Text(
                '¿Necesitás más? El plan ${uso.planSiguiente} amplía estos límites.',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaUso extends StatelessWidget {
  const _FilaUso({required this.titulo, required this.uso});

  final String titulo;
  final UsoRecurso uso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = uso.lleno
        ? tema.colorScheme.error
        : (uso.cercaDelLimite ? const Color(0xFFB7791F) : tema.colorScheme.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(titulo, style: tema.textTheme.bodyMedium)),
            Text(
              uso.limite == null ? '${uso.usados} · sin límite' : '${uso.usados} / ${uso.limite}',
              style: tema.textTheme.titleSmall?.copyWith(color: uso.limite == null ? null : color),
            ),
          ],
        ),
        if (uso.limite != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ((uso.porcentaje ?? 0) / 100).clamp(0, 1).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: tema.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ],
    );
  }
}
