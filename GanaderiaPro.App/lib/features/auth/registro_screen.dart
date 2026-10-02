import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import 'auth_layout.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiClient = ApiClient();

  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _confirmarController = TextEditingController();
  final _nombreRanchoController = TextEditingController();
  // HU-05: si se llega acá desde el sitio público con un plan elegido
  // (ej. "?plan=Intermedio"), se usa como selección inicial.
  late String _plan = _planDesdeUrl();
  bool _guardando = false;

  static String _planDesdeUrl() {
    const planesValidos = {'Basico', 'Intermedio', 'Superior'};
    final planUrl = Uri.base.queryParameters['plan'];
    return planesValidos.contains(planUrl) ? planUrl! : 'Basico';
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _contrasenaController.dispose();
    _confirmarController.dispose();
    _nombreRanchoController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      await _apiClient.registrarCuenta(
        nombre: _nombreController.text.trim(),
        email: _emailController.text.trim(),
        contrasena: _contrasenaController.text,
        confirmarContrasena: _confirmarController.text,
        nombreRancho: _nombreRanchoController.text.trim(),
        plan: _plan,
      );

      if (!mounted) return;
      // Se navega explícitamente a Login en vez de hacer pop(): esta
      // pantalla puede ser la raíz de la app (si se llega por un link
      // externo, como desde el sitio público), y ahí no hay nada debajo
      // para "volver". El mensaje se pasa como argumento porque mostrarlo
      // acá, justo antes de navegar, no llega a verse.
      Navigator.of(context).pushReplacementNamed(
        '/login',
        arguments: 'Registro exitoso. Tu prueba gratuita de 10 días ya empezó: iniciá sesión con tus datos.',
      );
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
    return AuthLayout(
      seccion: SeccionAuth.crearCuenta,
      subtitulo: 'Registrate y empezá tu prueba gratuita de 10 días',
      formulario: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoConEtiqueta(
              etiqueta: 'Nombre del rancho',
              child: TextFormField(
                controller: _nombreRanchoController,
                decoration: const InputDecoration(
                  hintText: 'Estancia La Esperanza',
                  prefixIcon: Icon(Icons.agriculture_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El nombre del rancho es obligatorio' : null,
              ),
            ),
            CampoConEtiqueta(
              etiqueta: 'Tu nombre',
              child: TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  hintText: 'Juan Pérez',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
              ),
            ),
            CampoConEtiqueta(
              etiqueta: 'Correo electrónico',
              child: TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'tu@correo.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El correo es obligatorio' : null,
              ),
            ),
            CampoConEtiqueta(
              etiqueta: 'Plan',
              child: DropdownButtonFormField<String>(
                initialValue: _plan,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.workspace_premium_outlined)),
                items: const [
                  DropdownMenuItem(value: 'Basico', child: Text('Básico')),
                  DropdownMenuItem(value: 'Intermedio', child: Text('Intermedio')),
                  DropdownMenuItem(value: 'Superior', child: Text('Superior')),
                ],
                onChanged: (value) => setState(() => _plan = value ?? 'Basico'),
              ),
            ),
            CampoConEtiqueta(
              etiqueta: 'Contraseña',
              child: TextFormField(
                controller: _contrasenaController,
                decoration: const InputDecoration(
                  hintText: 'Tu contraseña',
                  helperText: 'Mínimo 8 caracteres, con letra y número',
                  helperMaxLines: 2,
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
                  final tieneLetra = v.contains(RegExp(r'[A-Za-z]'));
                  final tieneNumero = v.contains(RegExp(r'[0-9]'));
                  if (v.length < 8 || !tieneLetra || !tieneNumero) {
                    return 'Mínimo 8 caracteres, con letra y número';
                  }
                  return null;
                },
              ),
            ),
            CampoConEtiqueta(
              etiqueta: 'Confirmar contraseña',
              child: TextFormField(
                controller: _confirmarController,
                decoration: const InputDecoration(
                  hintText: 'Repetí tu contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                // HU-08: confirmación debe coincidir con la contraseña.
                validator: (v) =>
                    (v != _contrasenaController.text) ? 'Las contraseñas no coinciden' : null,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _guardando ? null : _registrar,
              child: _guardando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
