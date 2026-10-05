import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/colaborador.dart';
import '../../core/formato.dart';
import '../../core/widgets/componentes.dart';
import '../shell/app_shell.dart';

// HU-32: colaboradores del rancho. Solo el propietario entra acá.
class ColaboradoresScreen extends StatefulWidget {
  const ColaboradoresScreen({super.key});

  @override
  State<ColaboradoresScreen> createState() => _ColaboradoresScreenState();
}

class _ColaboradoresScreenState extends State<ColaboradoresScreen> {
  final _api = ApiClient();
  late Future<List<Colaborador>> _colaboradores = _api.listarColaboradores();

  void _recargar() => setState(() {
    _colaboradores = _api.listarColaboradores();
  });

  void _avisar(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));

  Future<void> _ejecutar(Future<void> Function() accion, String exito) async {
    try {
      await accion();
      if (!mounted) return;
      _avisar(exito);
      _recargar();
    } on ApiException catch (e) {
      if (mounted) _avisar(e.mensaje);
    } catch (_) {
      if (mounted) _avisar('No se pudo conectar con el servidor.');
    }
  }

  Future<void> _invitar() async {
    final creada = await showDialog<InvitacionCreada>(context: context, builder: (_) => const _FormularioInvitacion());
    if (creada == null || !mounted) return;
    _recargar();
    await mostrarEnlace(context, creada);
  }

  Future<void> _nuevoEnlace(Colaborador c) async {
    try {
      final creada = await _api.regenerarInvitacion(c.id);
      if (!mounted) return;
      _recargar();
      await mostrarEnlace(context, creada);
    } on ApiException catch (e) {
      if (mounted) _avisar(e.mensaje);
    } catch (_) {
      if (mounted) _avisar('No se pudo conectar con el servidor.');
    }
  }

  Future<void> _cambiarRol(Colaborador c) async {
    final rol = await showDialog<String>(context: context, builder: (_) => _CambioRol(colaborador: c));
    if (rol == null || rol == c.rol) return;
    await _ejecutar(
      () => _api.cambiarRolColaborador(c.id, rol),
      '${c.nombre} ahora es ${nombreDeRol(rol)}. Tiene que volver a iniciar sesión.',
    );
  }

  Future<void> _cambiarEstado(Colaborador c) async {
    if (!c.inactivo) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('¿Desactivar a ${c.nombre}?'),
          content: const Text(
            'No va a poder iniciar sesión y se cierran sus sesiones abiertas. '
            'Podés volver a activarlo cuando quieras.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (confirmado != true) return;
    }
    await _ejecutar(
      () => _api.cambiarEstadoColaborador(c.id, activo: c.inactivo),
      c.inactivo ? '${c.nombre} fue reactivado.' : '${c.nombre} fue desactivado.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AppShell(
      seccionActiva: '/colaboradores',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoPantalla(
              titulo: 'Colaboradores',
              subtitulo: 'Invitá a tu equipo y elegí qué puede hacer cada uno según su rol.',
              acciones: [
                FilledButton.icon(
                  onPressed: _invitar,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Invitar colaborador'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<List<Colaborador>>(
                future: _colaboradores,
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
                  final colaboradores = snapshot.data!;
                  if (colaboradores.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.group_outlined, size: 40, color: tema.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('Todavía no invitaste colaboradores', style: tema.textTheme.titleMedium),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _invitar,
                            icon: const Icon(Icons.person_add_alt),
                            label: const Text('Invitar al primero'),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final c in colaboradores)
                        _FilaColaborador(
                          colaborador: c,
                          onCambiarRol: () => _cambiarRol(c),
                          onCambiarEstado: () => _cambiarEstado(c),
                          onNuevoEnlace: () => _nuevoEnlace(c),
                        ),
                    ],
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

// "dd/mm/aaaa hh:mm" o "Nunca".
String describirAcceso(DateTime? acceso) {
  if (acceso == null) return 'Nunca';
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${formatearFecha(acceso)} ${dos(acceso.hour)}:${dos(acceso.minute)}';
}

class _FilaColaborador extends StatelessWidget {
  const _FilaColaborador({
    required this.colaborador,
    required this.onCambiarRol,
    required this.onCambiarEstado,
    required this.onNuevoEnlace,
  });

  final Colaborador colaborador;
  final VoidCallback onCambiarRol;
  final VoidCallback onCambiarEstado;
  final VoidCallback onNuevoEnlace;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = colaborador;
    final suave = tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant);
    final detalle = c.pendiente
        ? (c.invitacionVence == null || c.invitacionVence!.isBefore(DateTime.now())
              ? 'Invitación vencida'
              : 'Invitación vence el ${formatearFecha(c.invitacionVence!)}')
        : 'Último acceso: ${describirAcceso(c.ultimoAcceso)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tema.colorScheme.outlineVariant))),
      child: Opacity(
        opacity: c.inactivo ? 0.6 : 1,
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: tema.colorScheme.primary.withValues(alpha: 0.10),
              foregroundColor: tema.colorScheme.primary,
              child: Text(iniciales(c.nombre), style: tema.textTheme.labelLarge),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(c.nombre, style: tema.textTheme.titleSmall),
                      _Chip(texto: nombreDeRol(c.rol), color: tema.colorScheme.secondary),
                      _Chip(texto: c.estado, color: _colorEstado(c.estado, tema.colorScheme)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${c.email} · $detalle', style: suave),
                ],
              ),
            ),
            if (c.pendiente) ...[
              BotonAccion(icono: Icons.link, tooltip: 'Generar nuevo enlace', onPressed: onNuevoEnlace),
              const SizedBox(width: 8),
            ],
            if (!c.inactivo) ...[
              BotonAccion(icono: Icons.edit_outlined, tooltip: 'Cambiar rol', onPressed: onCambiarRol),
              const SizedBox(width: 8),
            ],
            BotonAccion(
              icono: c.inactivo ? Icons.person_outline : Icons.person_off_outlined,
              tooltip: c.inactivo ? 'Reactivar' : 'Desactivar',
              peligro: !c.inactivo,
              onPressed: onCambiarEstado,
            ),
          ],
        ),
      ),
    );
  }

  static Color _colorEstado(String estado, ColorScheme colores) => switch (estado) {
    'Activo' => colores.primary,
    'Pendiente' => const Color(0xFFB7791F),
    _ => colores.onSurfaceVariant,
  };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      texto,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

// Mismas reglas que el servidor.
String? validarNombreColaborador(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'El nombre es obligatorio';
  if (texto.length > 150) return 'Hasta 150 caracteres';
  return null;
}

String? validarEmail(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'El correo es obligatorio';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)) return 'Ingresá un correo válido';
  return null;
}

class _FormularioInvitacion extends StatefulWidget {
  const _FormularioInvitacion();

  @override
  State<_FormularioInvitacion> createState() => _FormularioInvitacionState();
}

class _FormularioInvitacionState extends State<_FormularioInvitacion> {
  final _api = ApiClient();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  String? _rol;
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
    setState(() {
      _errores = {
        'nombre': ?validarNombreColaborador(_nombre.text),
        'email': ?validarEmail(_email.text),
        if (_rol == null) 'rol': 'Elegí el rol',
      };
      _errorServidor = null;
    });
    if (_errores.isNotEmpty) return;

    setState(() => _guardando = true);
    try {
      final creada = await _api.invitarColaborador(nombre: _nombre.text.trim(), email: _email.text.trim(), rol: _rol!);
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
                  Icon(Icons.person_add_alt, color: tema.colorScheme.primary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Invitar colaborador', style: tema.textTheme.titleLarge)),
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
                decoration: InputDecoration(hintText: 'Ej. Laura Rojas', errorText: _errores['nombre']),
              ),
              const SizedBox(height: 16),
              etiqueta('Correo electrónico *'),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: 'laura@correo.com', errorText: _errores['email']),
              ),
              const SizedBox(height: 16),
              etiqueta('Rol *'),
              DropdownButtonFormField<String>(
                initialValue: _rol,
                isExpanded: true,
                decoration: InputDecoration(hintText: 'Elegir rol', errorText: _errores['rol']),
                items: [
                  for (final r in rolesDeColaborador.entries) DropdownMenuItem(value: r.key, child: Text(r.value)),
                ],
                onChanged: (v) => setState(() {
                  _rol = v;
                  _errores.remove('rol');
                }),
              ),
              const SizedBox(height: 8),
              Text(
                'Vas a obtener un enlace para mandarle. Con él elige su contraseña; vence en 7 días.',
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

class _CambioRol extends StatefulWidget {
  const _CambioRol({required this.colaborador});

  final Colaborador colaborador;

  @override
  State<_CambioRol> createState() => _CambioRolState();
}

class _CambioRolState extends State<_CambioRol> {
  late String _rol = widget.colaborador.rol;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Rol de ${widget.colaborador.nombre}'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<String>(
            groupValue: _rol,
            onChanged: (v) => setState(() => _rol = v ?? _rol),
            child: Column(
              children: [
                for (final r in rolesDeColaborador.entries)
                  RadioListTile<String>(value: r.key, title: Text(r.value), contentPadding: EdgeInsets.zero),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Al cambiar el rol se cierran sus sesiones: tiene que volver a iniciar sesión.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      FilledButton(onPressed: () => Navigator.of(context).pop(_rol), child: const Text('Guardar')),
    ],
  );
}

// Muestra el enlace de invitación para copiarlo y mandarlo (no hay correo).
Future<void> mostrarEnlace(BuildContext context, InvitacionCreada creada) {
  final enlace = enlaceDeInvitacion(creada.codigo);
  return showDialog<void>(
    context: context,
    builder: (context) {
      final tema = Theme.of(context);
      return AlertDialog(
        icon: Icon(Icons.link, color: tema.colorScheme.primary, size: 30),
        title: Text('Enlace para ${creada.colaborador.nombre}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Mandale este enlace por WhatsApp o correo. Sirve una sola vez y vence el '
                '${formatearFecha(creada.vence)}. Por seguridad, después no se puede volver a ver: '
                'si se pierde, generá uno nuevo.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tema.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tema.colorScheme.outlineVariant),
                ),
                child: SelectableText(enlace, style: tema.textTheme.bodySmall),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: enlace));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enlace copiado.')));
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar enlace'),
          ),
        ],
      );
    },
  );
}
