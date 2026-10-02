import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/catalogos.dart';
import '../../core/validaciones_animal.dart';
import '../../core/widgets/componentes.dart';
import '../shell/app_shell.dart';

// HU-20: edición de un animal. Devuelve true al guardar.
class EditarAnimalScreen extends StatefulWidget {
  const EditarAnimalScreen({super.key, required this.animal});

  final Animal animal;

  @override
  State<EditarAnimalScreen> createState() => _EditarAnimalScreenState();
}

class _EditarAnimalScreenState extends State<EditarAnimalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient();

  late final _arete = TextEditingController(text: widget.animal.arete);
  late final _nombre = TextEditingController(text: widget.animal.nombre ?? '');
  late final _pesoNacimiento = TextEditingController(text: _textoPeso(widget.animal.pesoNacimiento));
  late final _peso = TextEditingController(text: _textoPeso(widget.animal.peso));
  late final _observaciones = TextEditingController(text: widget.animal.observaciones ?? '');
  late String _sexo = widget.animal.sexo;
  late String _raza = widget.animal.raza;
  late String? _color = widget.animal.color;
  late DateTime? _nacimiento = widget.animal.fechaNacimiento;
  String? _errorNacimiento;
  bool _guardando = false;

  static String _textoPeso(double? peso) => peso == null ? '' : peso.toString();

  @override
  void dispose() {
    for (final c in [_arete, _nombre, _pesoNacimiento, _peso, _observaciones]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final errorFecha = validarFechaNacimiento(_nacimiento);
    setState(() => _errorNacimiento = errorFecha);
    final formularioValido = _formKey.currentState!.validate();
    if (!formularioValido || errorFecha != null) return;

    setState(() => _guardando = true);
    try {
      await _api.editarAnimal(
        widget.animal.id,
        DatosAnimal(
          arete: _arete.text.trim(),
          sexo: _sexo,
          raza: _raza,
          nombre: _nombre.text.trim().isEmpty ? null : _nombre.text.trim(),
          fechaNacimiento: _nacimiento,
          pesoNacimiento: leerPeso(_pesoNacimiento.text),
          peso: leerPeso(_peso.text),
          color: _color,
          observaciones: _observaciones.text.trim().isEmpty ? null : _observaciones.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor.')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AppShell(
      seccionActiva: '/ganado',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Volver'),
                  ),
                ),
                const SizedBox(height: 8),
                EncabezadoPantalla(titulo: 'Editar animal', subtitulo: 'Arete ${widget.animal.arete}'),
                const SizedBox(height: 24),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: LayoutBuilder(
                        builder: (context, restricciones) {
                          final dosColumnas = restricciones.maxWidth >= 560;
                          final ancho = dosColumnas ? (restricciones.maxWidth - 16) / 2 : restricciones.maxWidth;
                          Widget campo(String etiqueta, Widget hijo, {bool completo = false}) => SizedBox(
                            width: completo ? restricciones.maxWidth : ancho,
                            child: _Etiquetado(etiqueta: etiqueta, child: hijo),
                          );

                          return Wrap(
                            spacing: 16,
                            runSpacing: 18,
                            children: [
                              campo(
                                'Arete *',
                                TextFormField(controller: _arete, validator: validarArete),
                              ),
                              campo(
                                'Nombre',
                                TextFormField(
                                  controller: _nombre,
                                  decoration: const InputDecoration(hintText: 'Opcional'),
                                  validator: (v) => validarLargo(v, 100),
                                ),
                              ),
                              campo(
                                'Sexo *',
                                DropdownButtonFormField<String>(
                                  initialValue: _sexo,
                                  items: const [
                                    DropdownMenuItem(value: 'Hembra', child: Text('Hembra')),
                                    DropdownMenuItem(value: 'Macho', child: Text('Macho')),
                                  ],
                                  onChanged: (v) => setState(() => _sexo = v ?? _sexo),
                                ),
                              ),
                              campo(
                                'Raza *',
                                DropdownButtonFormField<String>(
                                  initialValue: _raza,
                                  isExpanded: true,
                                  items: [
                                    for (final r in opcionesCon(razasBovinas, _raza))
                                      DropdownMenuItem(value: r, child: Text(r)),
                                  ],
                                  validator: validarRaza,
                                  onChanged: (v) => setState(() => _raza = v ?? _raza),
                                ),
                              ),
                              campo(
                                'Fecha de nacimiento',
                                CampoFecha(
                                  valor: _nacimiento,
                                  errorText: _errorNacimiento,
                                  onChanged: (f) => setState(() {
                                    _nacimiento = f;
                                    _errorNacimiento = null;
                                  }),
                                ),
                              ),
                              campo(
                                'Color',
                                DropdownButtonFormField<String?>(
                                  initialValue: _color,
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<String?>(value: null, child: Text('Sin especificar')),
                                    for (final c in opcionesCon(coloresPelaje, _color))
                                      DropdownMenuItem<String?>(value: c, child: Text(c)),
                                  ],
                                  onChanged: (v) => setState(() => _color = v),
                                ),
                              ),
                              campo(
                                'Peso al nacer (kg)',
                                TextFormField(
                                  controller: _pesoNacimiento,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: validarPeso,
                                ),
                              ),
                              campo(
                                'Peso actual (kg)',
                                TextFormField(
                                  controller: _peso,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: validarPeso,
                                ),
                              ),
                              campo(
                                'Observaciones',
                                TextFormField(
                                  controller: _observaciones,
                                  maxLines: 3,
                                  decoration: const InputDecoration(hintText: 'Notas sobre el animal'),
                                  validator: (v) => validarLargo(v, 500),
                                ),
                                completo: true,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: tema.colorScheme.onPrimary),
                            )
                          : const Text('Guardar cambios'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiquetado extends StatelessWidget {
  const _Etiquetado({required this.etiqueta, required this.child});

  final String etiqueta;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(etiqueta, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      child,
    ],
  );
}
