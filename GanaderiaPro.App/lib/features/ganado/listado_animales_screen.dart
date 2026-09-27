import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../shell/app_shell.dart';
import 'registrar_animal_screen.dart';

class ListadoAnimalesScreen extends StatefulWidget {
  const ListadoAnimalesScreen({super.key});

  @override
  State<ListadoAnimalesScreen> createState() => _ListadoAnimalesScreenState();
}

class _ListadoAnimalesScreenState extends State<ListadoAnimalesScreen> {
  final _apiClient = ApiClient();
  final _busquedaController = TextEditingController();

  late Future<List<Animal>> _futuroAnimales;
  String? _sexoSeleccionado;
  String? _estadoSeleccionado;

  @override
  void initState() {
    super.initState();
    _futuroAnimales = _cargar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<List<Animal>> _cargar() {
    return _apiClient.buscarAnimales(
      busqueda: _busquedaController.text.trim(),
      sexo: _sexoSeleccionado,
      estado: _estadoSeleccionado,
    );
  }

  void _buscar() {
    setState(() => _futuroAnimales = _cargar());
  }

  Future<void> _irARegistrar() async {
    final creado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const RegistrarAnimalScreen()));
    if (creado == true) {
      _buscar();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Animal registrado correctamente')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Ganado', style: Theme.of(context).textTheme.headlineSmall),
                ),
                FilledButton.icon(
                  onPressed: _irARegistrar,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar animal'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _busquedaController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por arete',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                DropdownButton<String?>(
                  value: _sexoSeleccionado,
                  hint: const Text('Sexo'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(value: 'Hembra', child: Text('Hembra')),
                    DropdownMenuItem(value: 'Macho', child: Text('Macho')),
                  ],
                  onChanged: (value) {
                    setState(() => _sexoSeleccionado = value);
                    _buscar();
                  },
                ),
                DropdownButton<String?>(
                  value: _estadoSeleccionado,
                  hint: const Text('Estado'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Activos')),
                    DropdownMenuItem(value: 'Vendido', child: Text('Vendidos')),
                    DropdownMenuItem(value: 'Fallecido', child: Text('Fallecidos')),
                  ],
                  onChanged: (value) {
                    setState(() => _estadoSeleccionado = value);
                    _buscar();
                  },
                ),
                IconButton(
                  onPressed: _buscar,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Animal>>(
                future: _futuroAnimales,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final animales = snapshot.data ?? [];
                  if (animales.isEmpty) {
                    return const Center(child: Text('No hay animales registrados todavía.'));
                  }
                  // Tabla base para HU-17 (búsqueda/filtro). Lazcano suma acá
                  // "última vacuna" y "acciones" (HU-18) y navegación a la
                  // ficha (HU-19) cuando lleguen a esa parte.
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Arete')),
                        DataColumn(label: Text('Sexo')),
                        DataColumn(label: Text('Raza')),
                        DataColumn(label: Text('Peso (kg)')),
                        DataColumn(label: Text('Estado')),
                      ],
                      rows: animales
                          .map(
                            (animal) => DataRow(
                              cells: [
                                DataCell(Text(animal.arete)),
                                DataCell(Text(animal.sexo)),
                                DataCell(Text(animal.raza)),
                                DataCell(Text(animal.peso?.toStringAsFixed(1) ?? '-')),
                                DataCell(Text(animal.estado)),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
