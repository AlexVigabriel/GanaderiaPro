import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/colaborador.dart';
import 'auth_layout.dart';

// HU-32: el colaborador abre el enlace, ve a qué rancho lo invitaron y con
// qué rol, y elige su contraseña (RN-03). Después inicia sesión.
class AceptarInvitacionScreen extends StatefulWidget {
  const AceptarInvitacionScreen({super.key, required this.codigo});

  final String codigo;

  @override
  State<AceptarInvitacionScreen> createState() => _AceptarInvitacionScreenState();
}

// Mismas reglas que el servidor (RN-03 y confirmación igual).
String? validarContrasenaNueva(String? valor) {
  final v = valor ?? '';
  if (v.isEmpty) return 'La contraseña es obligatoria';
  if (v.length < 8 || !v.contains(RegExp(r'[A-Za-z]')) || !v.contains(RegExp(r'[0-9]'))) {
    return 'Mínimo 8 caracteres, con letra y número';
  }
  return null;
}

class _AceptarInvitacionScreenState extends State<AceptarInvitacionScreen> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _contrasena = TextEditingController();
  final _confirmar = TextEditingController();
  late final Future<DatosInvitacion> _invitacion = _api.obtenerInvitacion(widget.codigo);
  bool _guardando = false;

  @override
  void dispose() {
    _contrasena.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _aceptar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await _api.aceptarInvitacion(widget.codigo, contrasena: _contrasena.text, confirmar: _confirmar.text);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
        arguments: 'Listo: ya podés iniciar sesión con tu correo y tu contraseña.',
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor.')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DatosInvitacion>(
      future: _invitacion,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AuthLayout(
            subtitulo: 'Revisando tu invitación…',
            formulario: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          );
        }

        if (snapshot.hasError) {
          final mensaje = snapshot.error is ApiException
              ? (snapshot.error as ApiException).mensaje
              : 'No se pudo conectar con el servidor.';
          return AuthLayout(
            subtitulo: 'Invitación no disponible',
            formulario: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(mensaje, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
                  child: const Text('Ir a iniciar sesión'),
                ),
              ],
            ),
          );
        }

        final datos = snapshot.data!;
        final tema = Theme.of(context);
        return AuthLayout(
          subtitulo: '${datos.nombre}, te invitaron a ${datos.rancho} como ${nombreDeRol(datos.rol)}.',
          formulario: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoConEtiqueta(
                  etiqueta: 'Correo electrónico',
                  child: TextFormField(
                    initialValue: datos.email,
                    enabled: false,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline)),
                  ),
                ),
                CampoConEtiqueta(
                  etiqueta: 'Elegí tu contraseña',
                  child: CampoContrasena(
                    controller: _contrasena,
                    hintText: 'Tu contraseña',
                    helperText: 'Mínimo 8 caracteres, con letra y número',
                    validator: validarContrasenaNueva,
                  ),
                ),
                CampoConEtiqueta(
                  etiqueta: 'Confirmar contraseña',
                  child: CampoContrasena(
                    controller: _confirmar,
                    hintText: 'Repetí tu contraseña',
                    validator: (v) => v != _contrasena.text ? 'Las contraseñas no coinciden' : null,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _guardando ? null : _aceptar,
                  child: _guardando
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: tema.colorScheme.onPrimary),
                        )
                      : const Text('Aceptar invitación'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
