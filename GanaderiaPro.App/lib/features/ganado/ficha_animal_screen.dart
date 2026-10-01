import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../shell/app_shell.dart';
import 'editar_animal_screen.dart';

class FichaAnimalScreen extends StatefulWidget {
  const FichaAnimalScreen({super.key, required this.animalId});

  final String animalId;

  @override
  State<FichaAnimalScreen> createState() => _FichaAnimalScreenState();
}

class _FichaAnimalScreenState extends State<FichaAnimalScreen> {
  final _apiClient = ApiClient();
  late Future<Animal> _futuroAnimal;
  bool _eliminando = false;

  @override
  void initState() {
    super.initState();
    _futuroAnimal = _apiClient.obtenerAnimal(widget.animalId);
  }

  void _recargar() {
    setState(() => _futuroAnimal = _apiClient.obtenerAnimal(widget.animalId));
  }

  Future<void> _editar(Animal animal) async {
    final editado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => EditarAnimalScreen(animal: animal)));

    if (editado == true) {
      _recargar();
    }
  }

  Future<void> _confirmarEliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar animal'),
        content: const Text(
          'Esta acción solo debería usarse para corregir un registro hecho por error. ¿Confirmás que querés eliminarlo?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmado != true) return;

    setState(() => _eliminando = true);

    try {
      await _apiClient.eliminarAnimal(widget.animalId);
      if (!mounted) return;
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final animal = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text('Ficha del animal', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                _campo('Arete', animal.arete),
                _campo('Sexo', animal.sexo),
                _campo('Raza', animal.raza),
                _campo('Peso', animal.peso != null ? '${animal.peso} kg' : 'Sin registrar'),
                _campo('Estado', animal.estado),
                _campo('Fecha de registro', animal.fechaRegistro.toLocal().toString()),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editar(animal),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _eliminando ? null : _confirmarEliminar,
                        style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _campo(String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: Theme.of(context).textTheme.labelMedium),
        Text(valor, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
