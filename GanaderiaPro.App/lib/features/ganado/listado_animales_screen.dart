import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/almacen_local.dart';
import '../../core/api_client.dart';
import '../../core/catalogos.dart';
import '../../core/conexion.dart';
import '../../core/formato.dart';
import '../../core/pendientes.dart';
import '../../core/permisos.dart';
import '../../core/plan.dart';
import '../../core/validaciones_animal.dart';
import '../../core/sesion_actual.dart';
import '../../core/route_observer.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/plan_widgets.dart';
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
  // HU-58: solo el propietario ve el uso del plan.
  UsoPlan? _usoPlan;
  String? _error;
  bool _cargando = false;
  bool _enLinea = EstadoConexion.instancia.enLinea;

  @override
  void initState() {
    super.initState();
    EstadoConexion.instancia.addListener(_cambioConexion);
    RegistrosPendientes.instancia.addListener(_refrescar);
    _cargar();
  }

  int _cantidadPendientes = RegistrosPendientes.instancia.animales.length;

  void _refrescar() {
    if (!mounted) return;
    // HU-47: si bajó la cantidad, algunos llegaron al servidor: se recarga.
    final cantidad = RegistrosPendientes.instancia.animales.length;
    final sincronizados = cantidad < _cantidadPendientes;
    _cantidadPendientes = cantidad;
    setState(() {});
    if (sincronizados && _enLinea) _cargar();
  }

  // HU-47: corregir la identificación de un registro en conflicto y reenviarlo.
  Future<void> _corregir(AnimalPendiente p) async {
    final nueva = await showDialog<String>(context: context, builder: (_) => _CorregirConflicto(pendiente: p));
    if (nueva == null || !mounted) return;
    final d = p.datos;
    await RegistrosPendientes.instancia.corregir(
      p,
      DatosAnimal(
        arete: nueva,
        sexo: d.sexo,
        raza: d.raza,
        nombre: d.nombre,
        fechaNacimiento: d.fechaNacimiento,
        pesoNacimiento: d.pesoNacimiento,
        peso: d.peso,
        color: d.color,
        observaciones: d.observaciones,
        castrado: d.castrado,
      ),
    );
    if (mounted) _avisar(_enLinea ? 'Se reenvía $nueva.' : '$nueva se enviará al volver la conexión.');
  }

  Future<void> _descartar(AnimalPendiente p) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Descartar ${p.datos.arete}?'),
        content: const Text('Se borra de este dispositivo y no se envía al servidor. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    await RegistrosPendientes.instancia.descartar(p);
    if (mounted) _avisar('${p.datos.arete} descartado.');
  }

  Widget _accionesConflicto(AnimalPendiente p) => !_puedeEditar
      ? const SizedBox.shrink()
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BotonAccion(icono: Icons.edit_outlined, tooltip: 'Corregir y reenviar', onPressed: () => _corregir(p)),
            const SizedBox(width: 8),
            BotonAccion(
              icono: Icons.delete_outline,
              tooltip: 'Descartar',
              peligro: true,
              onPressed: () => _descartar(p),
            ),
          ],
        );

  // Al volver la conexión se recarga el listado del servidor.
  void _cambioConexion() {
    final volvio = !_enLinea && EstadoConexion.instancia.enLinea;
    _enLinea = EstadoConexion.instancia.enLinea;
    _refrescar();
    if (volvio && mounted) _cargar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    EstadoConexion.instancia.removeListener(_cambioConexion);
    RegistrosPendientes.instancia.removeListener(_refrescar);
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
      _cargarUsoPlan();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Se actualiza junto con el listado; si falla, simplemente no hay aviso.
  Future<void> _cargarUsoPlan() async {
    if (!SesionActual.instancia.puedeVer(Modulos.configuracion)) return;
    try {
      final uso = await _api.obtenerUsoPlan();
      if (mounted) setState(() => _usoPlan = uso);
    } catch (_) {}
  }

  void _buscarConEspera(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), _cargar);
  }

  void _avisar(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));

  Future<void> _agregar() async {
    final alta = await abrirCargaMultiple(context);
    if (alta == null || !mounted) return;
    if (alta.sinConexion > 0) {
      final n = alta.sinConexion;
      _avisar(
        n == 1
            ? 'Sin conexión: 1 animal quedó guardado en este dispositivo y se enviará al volver la conexión.'
            : 'Sin conexión: $n animales quedaron guardados en este dispositivo y se enviarán al volver la conexión.',
      );
    } else {
      final n = alta.registrados;
      _avisar(n == 1 ? 'Se registró 1 animal.' : 'Se registraron $n animales.');
    }
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
              soloConsulta: !_puedeEditar,
              acciones: [
                if (_puedeEditar)
                  FilledButton.icon(
                    onPressed: _agregar,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar animales'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            AvisoLimitePlan(uso: _usoPlan, recurso: 'Animales'),
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

  // Los pendientes son altas: solo entran en el listado de Activos.
  List<AnimalPendiente> get _pendientes {
    if (_estado != 'Activo' || _sexo != null || _raza != null || _categoria != null) return const [];
    final texto = _busqueda.text.trim().toUpperCase();
    return RegistrosPendientes.instancia.animales
        .where(
          (p) =>
              texto.isEmpty ||
              p.datos.arete.contains(texto) ||
              (p.datos.nombre?.toUpperCase().contains(texto) ?? false) ||
              p.datos.raza.toUpperCase().contains(texto),
        )
        .toList();
  }

  Widget _contenido() {
    final animales = _animales;
    final pendientes = _pendientes;

    // HU-45.1: sin conexión y sin el listado del servidor, se ven los
    // registros guardados en el dispositivo.
    if (_error != null && animales == null && !_enLinea && pendientes.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AvisoSoloPendientes(),
          LayoutBuilder(
            builder: (context, restricciones) => restricciones.maxWidth >= 820
                ? _tabla(const [], pendientes)
                : Column(children: [for (final p in pendientes) _tarjetaPendiente(p)]),
          ),
        ],
      );
    }

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

    if (animales.isEmpty && pendientes.isEmpty) {
      return _hayFiltros
          ? const _EstadoVacio(icono: Icons.search_off, titulo: 'No hay animales que coincidan con la búsqueda.')
          : _EstadoVacio(
              icono: Icons.pets_outlined,
              titulo: 'No hay animales registrados aún',
              subtitulo: _puedeEditar ? 'Cargá los primeros con «Agregar animales».' : null,
              accion: _puedeEditar
                  ? FilledButton.icon(
                      onPressed: _agregar,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar animales'),
                    )
                  : null,
            );
    }

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, restricciones) => restricciones.maxWidth >= 820
              ? _tabla(animales, pendientes)
              : Column(
                  children: [
                    for (final p in pendientes) _tarjetaPendiente(p),
                    for (final a in animales) _tarjetaAnimal(a),
                  ],
                ),
        ),
        if (_cargando) const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator(minHeight: 2)),
      ],
    );
  }

  Widget _tabla(List<Animal> animales, List<AnimalPendiente> pendientes) {
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
        for (final p in pendientes) ...[
          Container(
            color: EtiquetaPendiente.color.withValues(alpha: 0.04),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(p.datos.arete, style: tema.textTheme.titleSmall)),
                Expanded(flex: 3, child: Text(p.datos.nombre ?? '—', overflow: TextOverflow.ellipsis)),
                // La categoría la calcula el servidor al sincronizar.
                const Expanded(flex: 2, child: Text('—')),
                Expanded(flex: 2, child: Text(p.datos.raza, overflow: TextOverflow.ellipsis)),
                Expanded(
                  flex: 2,
                  child: Text(p.datos.fechaNacimiento == null ? '—' : formatearFecha(p.datos.fechaNacimiento!)),
                ),
                Expanded(flex: 2, child: Text(formatearPeso(p.datos.peso))),
                if (p.enConflicto) ...[
                  Expanded(
                    flex: 2,
                    child: Align(alignment: Alignment.centerLeft, child: EtiquetaConflicto(motivo: p.motivo ?? '')),
                  ),
                  SizedBox(width: 128, child: _accionesConflicto(p)),
                ] else ...[
                  // La etiqueta ocupa también el lugar de las acciones, que
                  // un pendiente no tiene.
                  const Expanded(
                    flex: 2,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(height: 24),
                        Positioned(left: 0, top: 0, child: EtiquetaPendiente()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 128),
                ],
              ],
            ),
          ),
          if (p.enConflicto) _MotivoConflicto(motivo: p.motivo ?? ''),
          const Divider(height: 1),
        ],
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

  Widget _tarjetaPendiente(AnimalPendiente p) {
    final tema = Theme.of(context);
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: EtiquetaPendiente.color.withValues(alpha: 0.04),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.datos.nombre == null ? p.datos.arete : '${p.datos.arete}  ${p.datos.nombre}',
                style: tema.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${p.datos.raza} · ${p.datos.sexo} · ${formatearPeso(p.datos.peso)}',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              if (p.enConflicto)
                Row(
                  children: [
                    EtiquetaConflicto(motivo: p.motivo ?? ''),
                    const Spacer(),
                    _accionesConflicto(p),
                  ],
                )
              else
                const EtiquetaPendiente(),
            ],
          ),
        ),
        if (p.enConflicto) _MotivoConflicto(motivo: p.motivo ?? ''),
        const Divider(height: 1),
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

  // HU-34: alta, edición, baja y eliminación son del módulo Ganado.
  bool get _puedeEditar => SesionActual.instancia.puedeEditar(Modulos.ganado);

  // RN-13: sin conexión solo se pueden dar altas; el resto se deshabilita.
  Widget _acciones(Animal animal) {
    if (!_puedeEditar) return const SizedBox.shrink();
    String ayuda(String accion) => _enLinea ? accion : '$accion · Requiere conexión';
    VoidCallback? siHayConexion(VoidCallback accion) => _enLinea ? accion : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BotonAccion(icono: Icons.edit_outlined, tooltip: ayuda('Editar'), onPressed: siHayConexion(() => _editar(animal))),
        const SizedBox(width: 8),
        if (animal.activo) ...[
          BotonAccion(
            tooltip: ayuda('Registrar baja'),
            peligro: true,
            dibujo: (color) => IconoCalavera(color: color),
            onPressed: siHayConexion(() => _darDeBaja(animal)),
          ),
          const SizedBox(width: 8),
        ],
        BotonAccion(
          icono: Icons.delete_outline,
          tooltip: ayuda('Eliminar'),
          peligro: true,
          onPressed: siHayConexion(() => _eliminar(animal)),
        ),
      ],
    );
  }
}

class _MotivoConflicto extends StatelessWidget {
  const _MotivoConflicto({required this.motivo});

  final String motivo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      width: double.infinity,
      color: tema.colorScheme.error.withValues(alpha: 0.05),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: tema.colorScheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$motivo Corregí la identificación o descartalo.',
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// HU-47: pide la identificación nueva de un registro en conflicto.
class _CorregirConflicto extends StatefulWidget {
  const _CorregirConflicto({required this.pendiente});

  final AnimalPendiente pendiente;

  @override
  State<_CorregirConflicto> createState() => _CorregirConflictoState();
}

class _CorregirConflictoState extends State<_CorregirConflicto> {
  late final _arete = TextEditingController(text: widget.pendiente.datos.arete);
  String? _error;

  @override
  void dispose() {
    _arete.dispose();
    super.dispose();
  }

  void _guardar() {
    final arete = normalizarIdentificacion(_arete.text);
    final error = validarArete(_arete.text) ??
        (RegistrosPendientes.instancia.contieneArete(arete, excepto: widget.pendiente.idLocal)
            ? 'Ya está pendiente de sincronizar'
            : null);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(arete);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Corregir identificación'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.pendiente.motivo ?? ''),
            const SizedBox(height: 16),
            TextField(
              controller: _arete,
              autofocus: true,
              inputFormatters: formatoIdentificacion,
              decoration: InputDecoration(labelText: 'Identificación', errorText: _error),
              onSubmitted: (_) => _guardar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Guardar y reenviar')),
      ],
    );
  }
}

class _AvisoSoloPendientes extends StatelessWidget {
  const _AvisoSoloPendientes();

  @override
  Widget build(BuildContext context) {
    const color = EtiquetaPendiente.color;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sin conexión: se muestran solo los registros pendientes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
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
