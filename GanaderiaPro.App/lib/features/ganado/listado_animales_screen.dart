import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/route_observer.dart';
import '../shell/app_shell.dart';
import 'ficha_animal_screen.dart';
import 'registrar_animal_screen.dart';

class ListadoAnimalesScreen extends StatefulWidget {
  const ListadoAnimalesScreen({super.key});

  @override
  State<ListadoAnimalesScreen> createState() => _ListadoAnimalesScreenState();
}

class _ListadoAnimalesScreenState extends State<ListadoAnimalesScreen> with RouteAware {
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Se llama cada vez que esta pantalla vuelve a quedar visible después de
    // que se cierra algo apilado encima (registrar, ver ficha, editar,
    // eliminar) — sin importar cómo se haya salido de esa pantalla.
    _buscar();
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
    // El refresco del listado al volver lo maneja didPopNext() — acá solo
    // nos ocupamos del mensaje de confirmación.
    final creado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const RegistrarAnimalScreen()));
    if (creado == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Animal registrado correctamente')));
    }
  }

  Future<void> _verFicha(Animal animal) async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => FichaAnimalScreen(animalId: animal.id)));
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      seccionActiva: '/ganado',
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
                  // La columna "última vacuna" del backlog original queda
                  // pendiente hasta que exista el módulo de Sanidad (Sprint 2).
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
                              onSelectChanged: (_) => _verFicha(animal),
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
