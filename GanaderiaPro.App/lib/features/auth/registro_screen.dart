import 'package:flutter/material.dart';

import '../../core/api_client.dart';

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
        arguments: 'Cuenta creada. Iniciá sesión con tus datos.',
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
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Correo *'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El correo es obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contrasenaController,
                decoration: const InputDecoration(labelText: 'Contraseña *'),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmarController,
                decoration: const InputDecoration(labelText: 'Confirmar contraseña *'),
                obscureText: true,
                // HU-08: confirmación debe coincidir con la contraseña.
                validator: (v) =>
                    (v != _contrasenaController.text) ? 'Las contraseñas no coinciden' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreRanchoController,
                decoration: const InputDecoration(labelText: 'Nombre del rancho *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El nombre del rancho es obligatorio' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _plan,
                decoration: const InputDecoration(labelText: 'Plan *'),
                items: const [
                  DropdownMenuItem(value: 'Basico', child: Text('Básico')),
                  DropdownMenuItem(value: 'Intermedio', child: Text('Intermedio')),
                  DropdownMenuItem(value: 'Superior', child: Text('Superior')),
                ],
                onChanged: (value) => setState(() => _plan = value ?? 'Basico'),
              ),
              const SizedBox(height: 24),
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
      ),
    );
  }
}
