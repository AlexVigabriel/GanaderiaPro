import 'package:flutter/material.dart';

import '../formato.dart';
import '../validaciones_animal.dart';

// Botón cuadrado de ícono para acciones de una fila (editar, duplicar,
// eliminar). El de eliminar se marca como peligroso y se pone rojo al
// pasar el mouse.
class BotonAccion extends StatefulWidget {
  const BotonAccion({
    super.key,
    this.icono,
    required this.tooltip,
    required this.onPressed,
    this.peligro = false,
    this.activo = false,
    this.dibujo,
  }) : assert(icono != null || dibujo != null);

  final IconData? icono;
  // Para íconos que Material no trae (por ejemplo, la calavera de la baja).
  final Widget Function(Color color)? dibujo;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool peligro;
  final bool activo;

  @override
  State<BotonAccion> createState() => _BotonAccionState();
}

class _BotonAccionState extends State<BotonAccion> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final resaltado = widget.activo || _encima;
    final acento = widget.peligro ? colores.error : colores.primary;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() => _encima = false),
        child: Material(
          color: resaltado ? acento.withValues(alpha: 0.08) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: resaltado ? acento.withValues(alpha: 0.45) : colores.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onPressed,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: widget.dibujo?.call(resaltado ? acento : colores.onSurfaceVariant) ??
                    Icon(widget.icono, size: 18, color: resaltado ? acento : colores.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Campo de solo lectura que abre un calendario. No deja elegir fechas
// futuras (RN-14) ni de hace más de 25 años.
class CampoFecha extends StatelessWidget {
  const CampoFecha({
    super.key,
    required this.valor,
    required this.onChanged,
    this.hint = 'dd/mm/aaaa',
    this.errorText,
    this.denso = false,
    this.titulo = 'Fecha de nacimiento',
    this.primeraFecha,
    this.ultimaFecha,
  });

  final DateTime? valor;
  final String titulo;
  // Fecha más antigua que se puede elegir; por defecto, hace 25 años.
  final DateTime? primeraFecha;
  // Fecha más reciente que se puede elegir; por defecto, hoy (RN-14). La
  // próxima dosis de una vacuna sí puede ser futura.
  final DateTime? ultimaFecha;
  final ValueChanged<DateTime?> onChanged;
  final String hint;
  final String? errorText;
  final bool denso;

  Future<void> _elegir(BuildContext context) async {
    final hoy = fechaDeHoy();
    final minima = primeraFecha ?? fechaNacimientoMinima();
    final maxima = ultimaFecha ?? hoy;
    final sugerida = hoy.isAfter(maxima) ? maxima : (hoy.isBefore(minima) ? minima : hoy);
    final inicial = valor == null || valor!.isAfter(maxima) || valor!.isBefore(minima) ? sugerida : valor!;
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: minima,
      lastDate: maxima,
      helpText: titulo,
    );
    if (elegida != null) onChanged(elegida);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _elegir(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        isEmpty: valor == null,
        decoration: InputDecoration(
          hintText: hint,
          hintMaxLines: 1,
          errorText: errorText,
          errorMaxLines: 2,
          isDense: denso,
          suffixIconConstraints: denso ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
          suffixIcon: valor == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  tooltip: 'Borrar fecha',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(valor == null ? '' : formatearFecha(valor!)),
      ),
    );
  }
}

class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.estado, {super.key});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final (color, texto) = switch (estado) {
      'Activo' => (colores.primary, 'Activo'),
      'Vendido' => (const Color(0xFFB7791F), 'Vendido'),
      'Fallecido' => (colores.error, 'Fallecido'),
      _ => (colores.onSurfaceVariant, estado),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// HU-54: calavera para registrar la baja de un animal. Material no trae
// este ícono, así que se dibuja con trazos en una grilla de 24 x 24.
class IconoCalavera extends StatelessWidget {
  const IconoCalavera({super.key, required this.color, this.tamano = 18});

  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(tamano), painter: _PintorCalavera(color));
}

class _PintorCalavera extends CustomPainter {
  _PintorCalavera(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final relleno = Paint()..color = color;

    final craneo = Path()..addOval(const Rect.fromLTWH(4, 2.5, 16, 14.5));
    final mandibula = Path()
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, 14, 8, 7), const Radius.circular(1.8)));
    canvas.drawPath(Path.combine(PathOperation.union, craneo, mandibula), trazo);

    canvas.drawCircle(const Offset(9.2, 10.2), 2.1, relleno);
    canvas.drawCircle(const Offset(14.8, 10.2), 2.1, relleno);
    canvas.drawPath(
      Path()
        ..moveTo(12, 12.8)
        ..lineTo(10.9, 14.8)
        ..lineTo(13.1, 14.8)
        ..close(),
      relleno,
    );
    for (final x in const [10.7, 13.3]) {
      canvas.drawLine(Offset(x, 17.6), Offset(x, 20.4), trazo..strokeWidth = 1.3);
    }
  }

  @override
  bool shouldRepaint(_PintorCalavera anterior) => anterior.color != color;
}

// HU-74: categoría del animal (Ternero, Vaquillona, Novillo, etc.).
class EtiquetaCategoria extends StatelessWidget {
  const EtiquetaCategoria(this.categoria, {super.key});

  final String? categoria;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final sinCategoria = categoria == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: sinCategoria ? Colors.transparent : tema.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: sinCategoria ? Border.all(color: tema.colorScheme.outlineVariant) : null,
      ),
      child: Text(
        categoria ?? 'Sin categoría',
        style: tema.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: sinCategoria ? tema.colorScheme.onSurfaceVariant : tema.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

// HU-67: tarjeta de conteo (etiqueta, número grande e ícono).
class TarjetaIndicador extends StatelessWidget {
  const TarjetaIndicador({super.key, required this.etiqueta, required this.valor, required this.icono});

  final String etiqueta;
  final int? valor;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: LayoutBuilder(
        // En tarjetas angostas (celular) el ícono no entra junto a la etiqueta.
        builder: (context, restricciones) {
          final conIcono = restricciones.maxWidth >= 190;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etiqueta.toUpperCase(),
                        style: tema.textTheme.labelMedium?.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        valor?.toString() ?? '—',
                        style: tema.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                if (conIcono)
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tema.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icono, size: 22, color: tema.colorScheme.primary),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Título de pantalla con su bajada y acciones a la derecha.
class EncabezadoPantalla extends StatelessWidget {
  const EncabezadoPantalla({super.key, required this.titulo, this.subtitulo, this.acciones = const []});

  final String titulo;
  final String? subtitulo;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      spacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titulo, style: tema.textTheme.headlineMedium),
            if (subtitulo != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitulo!,
                style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
        if (acciones.isNotEmpty) Wrap(spacing: 12, runSpacing: 12, children: acciones),
      ],
    );
  }
}
