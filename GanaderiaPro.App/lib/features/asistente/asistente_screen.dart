import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/asistente.dart';
import '../../core/widgets/componentes.dart';
import '../shell/app_shell.dart';

// HU-36.1 y HU-38: asistente de consultas. Responde un catálogo de preguntas
// sobre los datos del rancho; si falta un dato, dice quién debe cargarlo.
class AsistenteScreen extends StatefulWidget {
  const AsistenteScreen({super.key});

  @override
  State<AsistenteScreen> createState() => _AsistenteScreenState();
}

class _Mensaje {
  const _Mensaje.usuario(this.texto) : deUsuario = true, respuesta = null;
  const _Mensaje.asistente(RespuestaAsistente this.respuesta) : deUsuario = false, texto = '';

  final bool deUsuario;
  final String texto;
  final RespuestaAsistente? respuesta;
}

class _AsistenteScreenState extends State<AsistenteScreen> {
  final _api = ApiClient();
  final _pregunta = TextEditingController();
  final _scroll = ScrollController();
  final _mensajes = <_Mensaje>[];
  late final Future<List<String>> _ejemplos = _api.listarEjemplosAsistente().catchError((_) => <String>[]);
  bool _esperando = false;

  @override
  void dispose() {
    _pregunta.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _enviar([String? texto]) async {
    final pregunta = (texto ?? _pregunta.text).trim();
    if (pregunta.isEmpty || _esperando) return;

    setState(() {
      _mensajes.add(_Mensaje.usuario(pregunta));
      _pregunta.clear();
      _esperando = true;
    });
    _bajar();

    RespuestaAsistente respuesta;
    try {
      respuesta = await _api.consultarAsistente(pregunta);
    } on ApiException catch (e) {
      respuesta = RespuestaAsistente(respuesta: e.mensaje, reconocida: true, sinDatos: false);
    } catch (_) {
      respuesta = const RespuestaAsistente(
        respuesta: 'No se pudo conectar con el servidor.',
        reconocida: true,
        sinDatos: false,
      );
    }
    if (!mounted) return;
    setState(() {
      _mensajes.add(_Mensaje.asistente(respuesta));
      _esperando = false;
    });
    _bajar();
  }

  void _bajar() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AppShell(
      seccionActiva: '/asistente',
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EncabezadoPantalla(
              titulo: 'Asistente',
              subtitulo: 'Preguntá por los datos de tu rancho sin recorrer los módulos.',
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: _mensajes.isEmpty
                    ? _Bienvenida(ejemplos: _ejemplos, onElegir: _enviar)
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.all(20),
                        itemCount: _mensajes.length + (_esperando ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          if (i == _mensajes.length) {
                            return const Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          final m = _mensajes[i];
                          return m.deUsuario
                              ? _Burbuja(texto: m.texto, deUsuario: true)
                              : _RespuestaBurbuja(respuesta: m.respuesta!, onElegir: _enviar);
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pregunta,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _enviar(),
                    decoration: const InputDecoration(hintText: 'Ej. ¿Cuántas hembras hay en el corral Norte?'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  tooltip: 'Enviar',
                  onPressed: _esperando ? null : _enviar,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(backgroundColor: tema.colorScheme.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  const _Bienvenida({required this.ejemplos, required this.onElegir});

  final Future<List<String>> ejemplos;
  final void Function(String) onElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.forum_outlined, size: 36, color: tema.colorScheme.primary),
          const SizedBox(height: 12),
          Text('¿Qué querés saber?', style: tema.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Estas son las preguntas que entiendo. Tocá una o escribí la tuya.',
            style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<String>>(
            future: ejemplos,
            builder: (context, snapshot) => _Ejemplos(ejemplos: snapshot.data ?? const [], onElegir: onElegir),
          ),
        ],
      ),
    );
  }
}

class _Ejemplos extends StatelessWidget {
  const _Ejemplos({required this.ejemplos, required this.onElegir});

  final List<String> ejemplos;
  final void Function(String) onElegir;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final e in ejemplos) ActionChip(label: Text(e), onPressed: () => onElegir(e))],
  );
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.texto, required this.deUsuario, this.color});

  final String texto;
  final bool deUsuario;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final fondo = color ?? (deUsuario ? tema.colorScheme.primary : tema.colorScheme.surfaceContainerHigh);
    return Align(
      alignment: deUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(16)),
          child: Text(
            texto,
            style: tema.textTheme.bodyMedium?.copyWith(color: deUsuario ? tema.colorScheme.onPrimary : null),
          ),
        ),
      ),
    );
  }
}

class _RespuestaBurbuja extends StatelessWidget {
  const _RespuestaBurbuja({required this.respuesta, required this.onElegir});

  final RespuestaAsistente respuesta;
  final void Function(String) onElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Burbuja(
          texto: respuesta.respuesta,
          deUsuario: false,
          // HU-38: un dato faltante se destaca para que se note.
          color: respuesta.sinDatos ? tema.colorScheme.errorContainer : null,
        ),
        if (!respuesta.reconocida && respuesta.ejemplos.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Ejemplos(ejemplos: respuesta.ejemplos, onElegir: onElegir),
        ],
      ],
    );
  }
}
