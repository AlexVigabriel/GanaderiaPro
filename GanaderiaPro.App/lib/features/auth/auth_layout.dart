import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

enum SeccionAuth { iniciarSesion, crearCuenta }

// Pantallas de acceso (login y registro). Siempre en modo oscuro, como
// portada de la marca: panel de presentación en pantallas anchas y la
// tarjeta del formulario.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.seccion,
    required this.subtitulo,
    required this.formulario,
  });

  final SeccionAuth seccion;
  final String subtitulo;
  final Widget formulario;

  static const double _anchoTarjeta = 440;
  static const double _anchoConPanel = 960;
  // Celulares: márgenes menores y selector sin íconos para que entre en un renglón.
  static const double _anchoCompacto = 420;

  void _cambiarSeccion(BuildContext context, SeccionAuth nueva) {
    if (nueva == seccion) return;
    // Reemplaza en vez de apilar: ir y volver entre las dos pestañas no
    // debe dejar pantallas acumuladas detrás.
    Navigator.of(
      context,
    ).pushReplacementNamed(nueva == SeccionAuth.iniciarSesion ? '/login' : '/registro');
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;

    return Theme(
      data: AppTheme.oscuro,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: AppTheme.verdeNoche,
          body: Stack(
            children: [
              const Positioned.fill(child: _FondoAuth()),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                    child: ancho >= _anchoConPanel
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1120),
                            child: Row(
                              children: [
                                const Expanded(child: _PanelMarca()),
                                const SizedBox(width: 64),
                                SizedBox(
                                  width: _anchoTarjeta,
                                  child: _tarjeta(context, compacto: false),
                                ),
                              ],
                            ),
                          )
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: _anchoTarjeta),
                            child: _tarjeta(context, compacto: ancho < _anchoCompacto),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(BuildContext context, {required bool compacto}) {
    final tema = Theme.of(context);
    final textoSecundario = tema.textTheme.bodyMedium?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    final lateral = compacto ? 20.0 : 32.0;
    final radio = BorderRadius.circular(24);

    // Tarjeta translúcida: deja ver el fondo desenfocado.
    return ClipRRect(
      borderRadius: radio,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(lateral, 32, lateral, 28),
          decoration: BoxDecoration(
            color: tema.colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: radio,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Logotipo(),
              const SizedBox(height: 8),
              Text(
                'Gestión ganadera para tu rancho',
                textAlign: TextAlign.center,
                style: textoSecundario,
              ),
              const SizedBox(height: 24),
              SegmentedButton<SeccionAuth>(
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: SeccionAuth.iniciarSesion,
                    label: const Text('Iniciar sesión'),
                    icon: compacto ? null : const Icon(Icons.login),
                  ),
                  ButtonSegment(
                    value: SeccionAuth.crearCuenta,
                    label: const Text('Crear cuenta'),
                    icon: compacto ? null : const Icon(Icons.person_add_alt),
                  ),
                ],
                selected: {seccion},
                onSelectionChanged: (seleccion) => _cambiarSeccion(context, seleccion.first),
              ),
              const SizedBox(height: 20),
              Text(subtitulo, textAlign: TextAlign.center, style: textoSecundario),
              const SizedBox(height: 20),
              formulario,
            ],
          ),
        ),
      ),
    );
  }
}

// Etiqueta arriba del campo, en vez de flotando adentro.
class CampoConEtiqueta extends StatelessWidget {
  const CampoConEtiqueta({super.key, required this.etiqueta, required this.child});

  final String etiqueta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            etiqueta,
            style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Logotipo extends StatelessWidget {
  const _Logotipo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.verdeBrillante,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.verdeBrillante.withValues(alpha: 0.35),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(Icons.grass, color: AppTheme.verdeNoche),
        ),
        const SizedBox(width: 12),
        Text(
          'GanaderíaPro',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

// Presentación de la marca, al costado de la tarjeta en pantallas anchas.
class _PanelMarca extends StatelessWidget {
  const _PanelMarca();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    const verde = AppTheme.verdeBrillante;
    final titular = textos.displayMedium?.copyWith(height: 1.05, letterSpacing: -1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(width: 40, height: 2, color: verde),
            const SizedBox(width: 16),
            Text(
              'GESTIÓN GANADERA INTELIGENTE',
              style: textos.labelLarge?.copyWith(letterSpacing: 4, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text('Tu rancho,', style: titular?.copyWith(color: Colors.white)),
        Text('bajo control.', style: titular?.copyWith(color: verde)),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'Registrá tu ganado, seguí su sanidad y organizá tus corrales desde un solo lugar, '
            'incluso sin señal en el campo.',
            style: textos.bodyLarge?.copyWith(color: Colors.white70, height: 1.6),
          ),
        ),
        const SizedBox(height: 32),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Rasgo(icono: Icons.cloud_off_outlined, texto: 'Funciona sin señal'),
            _Rasgo(icono: Icons.vaccines_outlined, texto: 'Control sanitario'),
            _Rasgo(icono: Icons.fence, texto: 'Corrales y potreros'),
          ],
        ),
      ],
    );
  }
}

class _Rasgo extends StatelessWidget {
  const _Rasgo({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppTheme.verdeBrillante.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.verdeBrillante.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: AppTheme.verdeBrillante),
          const SizedBox(width: 8),
          Text(texto, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

// Fondo: degradado verde noche, dos resplandores suaves y líneas finas.
class _FondoAuth extends StatelessWidget {
  const _FondoAuth();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B2417), AppTheme.verdeNoche, Color(0xFF04100A)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(top: -180, left: -140, child: _Resplandor(tamano: 460, intensidad: 0.20)),
        Positioned(bottom: -220, right: -160, child: _Resplandor(tamano: 560, intensidad: 0.14)),
        Positioned.fill(child: CustomPaint(painter: _LineasFinas())),
      ],
    );
  }
}

class _Resplandor extends StatelessWidget {
  const _Resplandor({required this.tamano, required this.intensidad});

  final double tamano;
  final double intensidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppTheme.verdeBrillante.withValues(alpha: intensidad),
            AppTheme.verdeBrillante.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _LineasFinas extends CustomPainter {
  const _LineasFinas();

  @override
  void paint(Canvas canvas, Size size) {
    for (final fraccion in const [0.08, 0.52, 0.94]) {
      final x = size.width * fraccion;
      final rect = Rect.fromLTWH(x, 0, 1, size.height);
      final pincel = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.verdeBrillante.withValues(alpha: 0),
            AppTheme.verdeBrillante.withValues(alpha: 0.12),
            AppTheme.verdeBrillante.withValues(alpha: 0),
          ],
        ).createShader(rect);
      canvas.drawRect(rect, pincel);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
