import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/colaborador.dart';
import '../../core/formato.dart';
import '../../core/plan.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/plan_widgets.dart';
import '../colaboradores/colaboradores_screen.dart' show describirAcceso, mostrarEnlace, validarEmail, validarNombreColaborador;
import '../shell/app_shell.dart';

// HU-29 y HU-30: socios del rancho. Solo el propietario entra acá. Los socios
// tienen acceso de solo lectura (matriz de permisos, sección 5).
class SociosScreen extends StatefulWidget {
  const SociosScreen({super.key});

  @override
  State<SociosScreen> createState() => _SociosScreenState();
}

class _SociosScreenState extends State<SociosScreen> {
  final _api = ApiClient();
  late Future<List<Colaborador>> _socios = _api.listarSocios();
  // RN-11: aviso al 90 % del límite de socios.
  late Future<UsoPlan?> _usoPlan = _cargarUsoPlan();

  Future<UsoPlan?> _cargarUsoPlan() async {
    try {
      return await _api.obtenerUsoPlan();
    } catch (_) {
      return null;
    }
  }

  void _recargar() => setState(() {
    _socios = _api.listarSocios();
    _usoPlan = _cargarUsoPlan();
  });

  void _avisar(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));

  Future<void> _invitar() async {
    final creada = await showDialog<InvitacionCreada>(context: context, builder: (_) => const _FormularioSocio());
    if (creada == null || !mounted) return;
    _recargar();
    await mostrarEnlace(context, creada);
  }

  Future<void> _nuevoEnlace(Colaborador socio) async {
    try {
      final creada = await _api.regenerarInvitacionSocio(socio.id);
      if (!mounted) return;
      _recargar();
      await mostrarEnlace(context, creada);
    } on ApiException catch (e) {
      if (mounted) _avisar(e.mensaje);
    } catch (_) {
      if (mounted) _avisar('No se pudo conectar con el servidor.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AppShell(
      seccionActiva: '/socios',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoPantalla(
              titulo: 'Socios',
              subtitulo: 'Los socios consultan la información del rancho, pero no pueden modificarla.',
              acciones: [
                FilledButton.icon(
                  onPressed: _invitar,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Registrar socio'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<UsoPlan?>(
              future: _usoPlan,
              builder: (context, snapshot) => AvisoLimitePlan(uso: snapshot.data, recurso: 'Socios'),
            ),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<List<Colaborador>>(
                future: _socios,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(
                            snapshot.error is ApiException
                                ? (snapshot.error as ApiException).mensaje
                                : 'No se pudo conectar con el servidor.',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _recargar, child: const Text('Reintentar')),
                        ],
                      ),
                    );
                  }
                  final socios = snapshot.data!;
                  if (socios.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.handshake_outlined, size: 40, color: tema.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('Todavía no registraste socios', style: tema.textTheme.titleMedium),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _invitar,
                            icon: const Icon(Icons.person_add_alt),
                            label: const Text('Registrar al primero'),
                          ),
                        ],
                      ),
                    );
                  }
                  return _TablaSocios(socios: socios, onNuevoEnlace: _nuevoEnlace);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// HU-30: nombre, correo, estado y último acceso («dd/mm/aaaa hh:mm» o «Nunca»).
class _TablaSocios extends StatelessWidget {
  const _TablaSocios({required this.socios, required this.onNuevoEnlace});

  final List<Colaborador> socios;
  final void Function(Colaborador) onNuevoEnlace;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: tema.textTheme.labelLarge,
        columns: const [
          DataColumn(label: Text('Nombre')),
          DataColumn(label: Text('Correo')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Último acceso')),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final s in socios)
            DataRow(
              cells: [
                DataCell(Text(s.nombre)),
                DataCell(Text(s.email)),
                DataCell(_EstadoSocio(estado: s.estado)),
                DataCell(Text(describirAcceso(s.ultimoAcceso))),
                DataCell(
                  s.pendiente
                      ? Tooltip(
                          message: s.invitacionVence == null || s.invitacionVence!.isBefore(DateTime.now())
                              ? 'Invitación vencida'
                              : 'Invitación vence el ${formatearFecha(s.invitacionVence!)}',
                          child: BotonAccion(
                            icono: Icons.link,
                            tooltip: 'Generar nuevo enlace',
                            onPressed: () => onNuevoEnlace(s),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EstadoSocio extends StatelessWidget {
  const _EstadoSocio({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final color = switch (estado) {
      'Activo' => colores.primary,
      'Pendiente' => const Color(0xFFB7791F),
      _ => colores.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        estado,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FormularioSocio extends StatefulWidget {
  const _FormularioSocio();

  @override
  State<_FormularioSocio> createState() => _FormularioSocioState();
}

class _FormularioSocioState extends State<_FormularioSocio> {
  final _api = ApiClient();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  Map<String, String> _errores = {};
  String? _errorServidor;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final errorNombre = validarNombreColaborador(_nombre.text);
    final errorEmail = validarEmail(_email.text);
    setState(() {
      _errores = {
        if (errorNombre != null) 'nombre': errorNombre,
        if (errorEmail != null) 'email': errorEmail,
      };
      _errorServidor = null;
    });
    if (_errores.isNotEmpty) return;

    setState(() => _guardando = true);
    try {
      final creada = await _api.invitarSocio(nombre: _nombre.text.trim(), email: _email.text.trim());
      if (mounted) Navigator.of(context).pop(creada);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorServidor = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _errorServidor = 'No se pudo conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget etiqueta(String texto) =>
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(texto, style: tema.textTheme.labelLarge));

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.handshake_outlined, color: tema.colorScheme.primary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Registrar socio', style: tema.textTheme.titleLarge)),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              etiqueta('Nombre *'),
              TextField(
                controller: _nombre,
                autofocus: true,
                decoration: InputDecoration(hintText: 'Ej. Pedro Mamani', errorText: _errores['nombre']),
              ),
              const SizedBox(height: 16),
              etiqueta('Correo electrónico *'),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: 'pedro@correo.com', errorText: _errores['email']),
              ),
              const SizedBox(height: 8),
              Text(
                'Queda pendiente hasta que entre por primera vez con el enlace. Solo podrá consultar.',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              if (_errorServidor != null) ...[
                const SizedBox(height: 12),
                Text(_errorServidor!, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error)),
              ],
              const SizedBox(height: 24),
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
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Crear invitación'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
