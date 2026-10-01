import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../shell/app_shell.dart';

class RegistrarAnimalScreen extends StatefulWidget {
  const RegistrarAnimalScreen({super.key});

  @override
  State<RegistrarAnimalScreen> createState() => _RegistrarAnimalScreenState();
}

class _RegistrarAnimalScreenState extends State<RegistrarAnimalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiClient = ApiClient();

  final _areteController = TextEditingController();
  final _razaController = TextEditingController();
  final _pesoController = TextEditingController();
  String _sexo = 'Hembra';
  bool _guardando = false;

  @override
  void dispose() {
    _areteController.dispose();
    _razaController.dispose();
    _pesoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      await _apiClient.registrarAnimal(
        arete: _areteController.text.trim(),
        sexo: _sexo,
        raza: _razaController.text.trim(),
        peso: _pesoController.text.trim().isEmpty
            ? null
            : double.parse(_pesoController.text.trim()),
      );

      if (!mounted) return;
      // El SnackBar se muestra en la pantalla de destino (listado), no acá:
      // si se muestra justo antes de un pop(), la pantalla se cierra antes
      // de que llegue a aparecer.
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      seccionActiva: '/ganado',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Registrar animal', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: _areteController,
                decoration: const InputDecoration(labelText: 'Arete *'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'El arete es obligatorio' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('sexo-dropdown'),
                initialValue: _sexo,
                decoration: const InputDecoration(labelText: 'Sexo *'),
                items: const [
                  DropdownMenuItem(value: 'Hembra', child: Text('Hembra')),
                  DropdownMenuItem(value: 'Macho', child: Text('Macho')),
                ],
                onChanged: (value) => setState(() => _sexo = value ?? 'Hembra'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _razaController,
                decoration: const InputDecoration(labelText: 'Raza *'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'La raza es obligatoria' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pesoController,
                decoration: const InputDecoration(labelText: 'Peso (kg)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  return double.tryParse(value.trim()) == null ? 'Ingresá un número válido' : null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
