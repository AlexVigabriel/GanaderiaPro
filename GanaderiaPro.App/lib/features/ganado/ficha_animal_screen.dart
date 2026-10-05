import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/formato.dart';
import '../../core/widgets/componentes.dart';
import '../shell/app_shell.dart';
import 'baja_animal_dialog.dart';
import 'editar_animal_screen.dart';
import 'listado_animales_screen.dart';
import '../sanidad/vacunaciones_widgets.dart';
import 'pesajes_animal.dart';

// HU-19: ficha completa del animal.
class FichaAnimalScreen extends StatefulWidget {
  const FichaAnimalScreen({super.key, required this.animalId});

  final String animalId;

  @override
  State<FichaAnimalScreen> createState() => _FichaAnimalScreenState();
}

class _FichaAnimalScreenState extends State<FichaAnimalScreen> {
  final _api = ApiClient();
  late Future<Animal> _futuroAnimal;
  bool _eliminando = false;

  @override
  void initState() {
    super.initState();
    _futuroAnimal = _api.obtenerAnimal(widget.animalId);
  }

  // Con llaves: si setState recibe "() => x = futuro", devuelve ese Future y
  // Flutter corta la recarga (la pantalla quedaba sin actualizar).
  void _recargar() => setState(() {
    _futuroAnimal = _api.obtenerAnimal(widget.animalId);
  });

  void _avisar(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));

  Future<void> _editar(Animal animal) async {
    final guardado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => EditarAnimalScreen(animal: animal)));
    if (guardado == true && mounted) {
      _avisar('Cambios guardados.');
      _recargar();
    }
  }

  Future<void> _darDeBaja(Animal animal) async {
    final actualizado = await abrirRegistroBaja(context, animal);
    if (actualizado == null || !mounted) return;
    _avisar('${animal.arete} quedó como ${actualizado.estado}.');
    _recargar();
  }

  // HU-21: eliminar, solo para corregir registros cargados por error.
  Future<void> _eliminar(Animal animal) async {
    if (!await confirmarEliminacion(context, animal) || !mounted) return;

    setState(() => _eliminando = true);
    try {
      await _api.eliminarAnimal(animal.id);
      if (!mounted) return;
      _avisar('Animal ${animal.arete} eliminado.');
      // El listado se refresca solo al volver a quedar visible (RouteAware).
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) _avisar(e.mensaje);
    } catch (_) {
      if (mounted) _avisar('No se pudo conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      seccionActiva: '/ganado',
      body: FutureBuilder<Animal>(
        future: _futuroAnimal,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final mensaje = snapshot.error is ApiException
                ? (snapshot.error as ApiException).mensaje
                : 'No se pudo conectar con el servidor.';
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mensaje),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _recargar, child: const Text('Reintentar')),
                ],
              ),
            );
          }
          return _ficha(snapshot.data!);
        },
      ),
    );
  }

  Widget _ficha(Animal animal) {
    final tema = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Volver a Animales'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(animal.arete, style: tema.textTheme.headlineMedium),
                            EtiquetaCategoria(animal.categoria),
                            EtiquetaEstado(animal.estado),
                          ],
                        ),
                        if (animal.nombre != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            animal.nombre!,
                            style: tema.textTheme.titleMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  BotonAccion(
                    icono: Icons.edit_outlined,
                    tooltip: 'Editar',
                    onPressed: _eliminando ? null : () => _editar(animal),
                  ),
                  const SizedBox(width: 8),
                  if (animal.activo) ...[
                    BotonAccion(
                      tooltip: 'Registrar baja',
                      peligro: true,
                      dibujo: (color) => IconoCalavera(color: color),
                      onPressed: _eliminando ? null : () => _darDeBaja(animal),
                    ),
                    const SizedBox(width: 8),
                  ],
                  BotonAccion(
                    icono: Icons.delete_outline,
                    tooltip: 'Eliminar',
                    peligro: true,
                    onPressed: _eliminando ? null : () => _eliminar(animal),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Datos del animal', style: tema.textTheme.titleMedium),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, restricciones) {
                          final columnas = restricciones.maxWidth >= 720 ? 3 : (restricciones.maxWidth >= 440 ? 2 : 1);
                          final ancho = (restricciones.maxWidth - 24 * (columnas - 1)) / columnas;
                          final nacimiento = animal.fechaNacimiento;
                          final datos = <(String, String)>[
                            ('Sexo', animal.sexo),
                            if (animal.sexo == 'Macho') ('Castrado', animal.castrado ? 'Sí' : 'No'),
                            ('Raza', animal.raza),
                            ('Color', animal.color ?? '—'),
                            (
                              'Fecha de nacimiento',
                              nacimiento == null ? '—' : '${formatearFecha(nacimiento)} (${describirEdad(nacimiento)})',
                            ),
                            ('Peso al nacer', formatearPeso(animal.pesoNacimiento)),
                            ('Peso actual', formatearPeso(animal.peso)),
                            ('Registrado el', formatearFecha(animal.fechaRegistro.toLocal())),
                          ];
                          return Wrap(
                            spacing: 24,
                            runSpacing: 20,
                            children: [
                              for (final (etiqueta, valor) in datos)
                                SizedBox(width: ancho, child: _Dato(etiqueta: etiqueta, valor: valor)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TarjetaPesajes(animal: animal, onPesoActualizado: _recargar),
              const SizedBox(height: 16),
              TarjetaHistorialSanitario(animal: animal),
              if (!animal.activo) ...[
                const SizedBox(height: 16),
                _tarjetaBaja(animal, tema),
              ],
              if (animal.observaciones != null) ...[
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Observaciones', style: tema.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Text(animal.observaciones!),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// HU-54: datos de la venta o el fallecimiento.
Widget _tarjetaBaja(Animal animal, ThemeData tema) {
  final color = tema.colorScheme.error;
  return Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconoCalavera(color: color, tamano: 22),
              const SizedBox(width: 10),
              Text('Baja registrada', style: tema.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 48,
            runSpacing: 16,
            children: [
              _Dato(etiqueta: 'Motivo', valor: animal.estado == 'Vendido' ? 'Venta' : 'Fallecimiento'),
              _Dato(etiqueta: 'Fecha', valor: animal.fechaBaja == null ? '—' : formatearFecha(animal.fechaBaja!)),
              if (animal.textoCausaMuerte != null) _Dato(etiqueta: 'Causa de muerte', valor: animal.textoCausaMuerte!),
              if (animal.fechaNacimiento != null && animal.fechaBaja != null && animal.estado == 'Fallecido')
                _Dato(
                  etiqueta: 'Edad al morir',
                  valor: describirEdad(animal.fechaNacimiento!, hasta: animal.fechaBaja),
                ),
            ],
          ),
          if (animal.observacionBaja != null) ...[
            const SizedBox(height: 16),
            _Dato(etiqueta: 'Notas', valor: animal.observacionBaja!),
          ],
        ],
      ),
    ),
  );
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: tema.textTheme.labelSmall?.copyWith(
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(valor, style: tema.textTheme.bodyLarge),
      ],
    );
  }
}
