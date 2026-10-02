import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import 'auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiClient = ApiClient();

  final _emailController = TextEditingController();
  final _contrasenaController = TextEditingController();
  bool _ingresando = false;
  bool _mensajeInicialMostrado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si se llega acá después de crear una cuenta (RegistroScreen la pasa
    // como argumento de la ruta), se muestra una sola vez.
    if (!_mensajeInicialMostrado) {
      _mensajeInicialMostrado = true;
      final mensaje = ModalRoute.of(context)?.settings.arguments as String?;
      if (mensaje != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _ingresando = true);

    try {
      await _apiClient.iniciarSesion(
        email: _emailController.text.trim(),
        contrasena: _contrasenaController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on ApiException catch (e) {
      // HU-09: mensaje genérico, igual si el correo no existe o la
      // contraseña es incorrecta — no se distingue cuál dato falló.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor.')));
    } finally {
      if (mounted) setState(() => _ingresando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      seccion: SeccionAuth.iniciarSesion,
      subtitulo: 'Ingresá a tu cuenta',
      formulario: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              etiqueta: 'Contraseña',
              child: CampoContrasena(
                controller: _contrasenaController,
                hintText: 'Tu contraseña',
                validator: (v) => (v == null || v.isEmpty) ? 'La contraseña es obligatoria' : null,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _ingresando ? null : _iniciarSesion,
              child: _ingresando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ingresar'),
            ),
          ],
        ),
      ),
    );
  }
}
