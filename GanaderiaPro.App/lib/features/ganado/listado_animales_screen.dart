import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/catalogos.dart';
import '../../core/formato.dart';
import '../../core/route_observer.dart';
import '../../core/widgets/componentes.dart';
import '../shell/app_shell.dart';
import 'baja_animal_dialog.dart';
import 'carga_multiple_dialog.dart';
import 'editar_animal_screen.dart';
import 'ficha_animal_screen.dart';

class ListadoAnimalesScreen extends StatefulWidget {
  const ListadoAnimalesScreen({super.key});

  @override
  State<ListadoAnimalesScreen> createState() => _ListadoAnimalesScreenState();
}

class _ListadoAnimalesScreenState extends State<ListadoAnimalesScreen> with RouteAware {
  final _api = ApiClient();
  final _busqueda = TextEditingController();
  Timer? _espera;

  String? _sexo;
  // RN-04: por defecto se ven los Activos.
  String _estado = 'Activo';
  String? _raza;
  String? _categoria;

  List<Animal>? _animales;
  ResumenAnimales? _resumen;
  String? _error;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  // Se llama cada vez que esta pantalla vuelve a quedar visible (al volver
  // de la ficha o de editar), sin importar cómo se haya salido de ellas.
  @override
  void didPopNext() => _cargar();

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        _api.buscarAnimales(
          busqueda: _busqueda.text.trim(),
          sexo: _sexo,
          estado: _estado,
          raza: _raza,
          categoria: _categoria,
        ),
        _api.obtenerResumen(),
      ]);
      if (!mounted) return;
      setState(() {
        _animales = resultados[0] as List<Animal>;
        _resumen = resultados[1] as ResumenAnimales;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _buscarConEspera(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), _cargar);
  }

  void _avisar(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));

  Future<void> _agregar() async {
    final registrados = await abrirCargaMultiple(context);
    if (registrados == null || !mounted) return;
    _avisar(registrados == 1 ? 'Se registró 1 animal.' : 'Se registraron $registrados animales.');
    _cargar();
  }

  void _verFicha(Animal animal) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => FichaAnimalScreen(animalId: animal.id)));

  Future<void> _editar(Animal animal) async {
    final guardado = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => EditarAnimalScreen(animal: animal)));
    if (guardado == true && mounted) _avisar('Cambios guardados.');
  }

  // HU-54: la baja deja al animal fuera de los Activos sin borrarlo.
  Future<void> _darDeBaja(Animal animal) async {
    final actualizado = await abrirRegistroBaja(context, animal);
    if (actualizado == null || !mounted) return;
    _avisar('${animal.arete} quedó como ${actualizado.estado}.');
    _cargar();
  }

  Future<void> _eliminar(Animal animal) async {
    final confirmado = await confirmarEliminacion(context, animal);
    if (!confirmado || !mounted) return;
    try {
      await _api.eliminarAnimal(animal.id);
      if (!mounted) return;
      _avisar('Animal ${animal.arete} eliminado.');
      _cargar();
    } on ApiException catch (e) {
      if (mounted) _avisar(e.mensaje);
    } catch (_) {
      if (mounted) _avisar('No se pudo conectar con el servidor.');
    }
  }

  bool get _hayFiltros =>
      _busqueda.text.trim().isNotEmpty || _sexo != null || _raza != null || _categoria != null || _estado != 'Activo';

  @override
  Widget build(BuildContext context) {
    return AppShell(
      seccionActiva: '/ganado',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoPantalla(
              titulo: 'Gestión de animales',
              subtitulo: 'Administrá tu ganado y registrá información detallada.',
              acciones: [
                FilledButton.icon(
                  onPressed: _agregar,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar animales'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _tarjetasResumen(),
            const SizedBox(height: 24),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_filtros(), const Divider(height: 1), _contenido()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetasResumen() {
    final r = _resumen;
    final tarjetas = [
      TarjetaIndicador(etiqueta: 'Animales activos', valor: r?.activos, icono: Icons.monitor_heart_outlined),
      TarjetaIndicador(etiqueta: 'Hembras', valor: r?.hembras, icono: Icons.female),
      TarjetaIndicador(etiqueta: 'Machos', valor: r?.machos, icono: Icons.male),
      TarjetaIndicador(etiqueta: 'Vendidos', valor: r?.vendidos, icono: Icons.shopping_cart_outlined),
      TarjetaIndicador(etiqueta: 'Fallecidos', valor: r?.fallecidos, icono: Icons.heart_broken_outlined),
    ];

    return LayoutBuilder(
      builder: (context, restricciones) {
        const espacio = 16.0;
        final columnas = restricciones.maxWidth >= 1100 ? 5 : (restricciones.maxWidth >= 640 ? 3 : 2);
        final ancho = (restricciones.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [for (final t in tarjetas) SizedBox(width: ancho, child: t)],
        );
      },
    );
  }

  Widget _filtros() {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Listado de animales', style: tema.textTheme.titleLarge),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  controller: _busqueda,
                  onChanged: _buscarConEspera,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Buscar por identificación, nombre o raza…',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              _filtro<String?>(
                ancho: 200,
                valor: _categoria,
                opciones: {null: 'Todas las categorías', for (final c in categoriasAnimal.keys) c: c},
                descripciones: categoriasAnimal,
                onChanged: (v) => setState(() => _categoria = v),
              ),
              _filtro<String?>(
                ancho: 200,
                valor: _sexo,
                opciones: const {null: 'Todos los sexos', 'Hembra': 'Hembras', 'Macho': 'Machos'},
                onChanged: (v) => setState(() => _sexo = v),
              ),
              _filtro<String>(
                ancho: 170,
                valor: _estado,
                opciones: const {'Activo': 'Activos', 'Vendido': 'Vendidos', 'Fallecido': 'Fallecidos'},
                onChanged: (v) => setState(() => _estado = v ?? 'Activo'),
              ),
              _filtro<String?>(
                ancho: 200,
                valor: _raza,
                opciones: {null: 'Todas las razas', for (final r in razasBovinas) r: r},
                onChanged: (v) => setState(() => _raza = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filtro<T>({
    required double ancho,
    required T valor,
    required Map<T, String> opciones,
    required ValueChanged<T?> onChanged,
    // Texto de ayuda que se ve en la lista abierta, debajo de cada opción.
    Map<T, String>? descripciones,
  }) {
    final tema = Theme.of(context);
    return SizedBox(
      width: ancho,
      child: DropdownButtonFormField<T>(
        initialValue: valor,
        isExpanded: true,
        decoration: const InputDecoration(isDense: true),
        menuMaxHeight: 480,
        selectedItemBuilder: (_) => [
          for (final texto in opciones.values) Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        items: [
          for (final opcion in opciones.entries)
            DropdownMenuItem<T>(
              value: opcion.key,
              child: descripciones?[opcion.key] == null
                  ? Text(opcion.value)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(opcion.value),
                        Text(
                          descripciones![opcion.key]!,
                          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
            ),
        ],
        onChanged: (v) {
          onChanged(v);
          _cargar();
        },
      ),
    );
  }

  Widget _contenido() {
    final animales = _animales;

    if (_error != null && animales == null) {
      return _EstadoVacio(
        icono: Icons.cloud_off_outlined,
        titulo: _error!,
        accion: OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    }

    if (animales == null) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (animales.isEmpty) {
      return _hayFiltros
          ? const _EstadoVacio(icono: Icons.search_off, titulo: 'No hay animales que coincidan con la búsqueda.')
          : _EstadoVacio(
              icono: Icons.pets_outlined,
              titulo: 'No hay animales registrados aún',
              subtitulo: 'Cargá los primeros con «Agregar animales».',
              accion: FilledButton.icon(
                onPressed: _agregar,
                icon: const Icon(Icons.add),
                label: const Text('Agregar animales'),
              ),
            );
    }

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, restricciones) => restricciones.maxWidth >= 820
              ? _tabla(animales)
              : Column(children: [for (final a in animales) _tarjetaAnimal(a)]),
        ),
        if (_cargando) const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator(minHeight: 2)),
      ],
    );
  }

  Widget _tabla(List<Animal> animales) {
    final tema = Theme.of(context);
    final estiloEncabezado = tema.textTheme.labelMedium?.copyWith(
      letterSpacing: 1,
      fontWeight: FontWeight.w600,
      color: tema.colorScheme.onSurfaceVariant,
    );
    Widget encabezado(String texto, int flex) => Expanded(
      flex: flex,
      child: Text(texto.toUpperCase(), style: estiloEncabezado, maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    return Column(
      children: [
        Container(
          color: tema.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              encabezado('Identificación', 3),
              encabezado('Nombre', 3),
              encabezado('Categoría', 2),
              encabezado('Raza', 2),
              encabezado('Nacimiento', 2),
              encabezado('Peso', 2),
              encabezado('Estado', 2),
              SizedBox(width: 128, child: Text('ACCIONES', style: estiloEncabezado)),
            ],
          ),
        ),
        for (final animal in animales) ...[
          InkWell(
            onTap: () => _verFicha(animal),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(animal.arete, style: tema.textTheme.titleSmall)),
                  Expanded(flex: 3, child: Text(animal.nombre ?? '—', overflow: TextOverflow.ellipsis)),
                  Expanded(
                    flex: 2,
                    child: Align(alignment: Alignment.centerLeft, child: EtiquetaCategoria(animal.categoria)),
                  ),
                  Expanded(flex: 2, child: Text(animal.raza, overflow: TextOverflow.ellipsis)),
                  Expanded(
                    flex: 2,
                    child: Text(animal.fechaNacimiento == null ? '—' : formatearFecha(animal.fechaNacimiento!)),
                  ),
                  Expanded(flex: 2, child: Text(formatearPeso(animal.peso))),
                  Expanded(
                    flex: 2,
                    child: Align(alignment: Alignment.centerLeft, child: EtiquetaEstado(animal.estado)),
                  ),
                  SizedBox(width: 128, child: _acciones(animal)),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }

  Widget _tarjetaAnimal(Animal animal) {
    final tema = Theme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: () => _verFicha(animal),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(animal.arete, style: tema.textTheme.titleSmall),
                          if (animal.nombre != null) ...[
                            const SizedBox(width: 8),
                            Flexible(child: Text(animal.nombre!, overflow: TextOverflow.ellipsis)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${animal.raza} · ${animal.sexo} · ${formatearPeso(animal.peso)}',
                        style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [EtiquetaCategoria(animal.categoria), EtiquetaEstado(animal.estado)],
                      ),
                    ],
                  ),
                ),
                _acciones(animal),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _acciones(Animal animal) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BotonAccion(icono: Icons.edit_outlined, tooltip: 'Editar', onPressed: () => _editar(animal)),
      const SizedBox(width: 8),
      if (animal.activo) ...[
        BotonAccion(
          tooltip: 'Registrar baja',
          peligro: true,
          dibujo: (color) => IconoCalavera(color: color),
          onPressed: () => _darDeBaja(animal),
        ),
        const SizedBox(width: 8),
      ],
      BotonAccion(icono: Icons.delete_outline, tooltip: 'Eliminar', peligro: true, onPressed: () => _eliminar(animal)),
    ],
  );
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.icono, required this.titulo, this.subtitulo, this.accion});

  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Column(
        children: [
          Icon(icono, size: 40, color: tema.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(titulo, textAlign: TextAlign.center, style: tema.textTheme.titleMedium),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitulo!,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ],
          if (accion != null) ...[const SizedBox(height: 20), accion!],
        ],
      ),
    );
  }
}

// HU-21: confirmación antes de eliminar. Se usa desde el listado y la ficha.
Future<bool> confirmarEliminacion(BuildContext context, Animal animal) async {
  final respuesta = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('¿Eliminar el animal ${animal.arete}?'),
      content: const Text(
        'Esta acción es solo para corregir registros cargados por error y no se puede deshacer. '
        'Si el animal se vendió o murió, registrá una baja en su lugar.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return respuesta ?? false;
}
