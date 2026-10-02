import 'package:flutter/material.dart';

// Identidad visual de toda la app. Las pantallas no definen colores ni
// formas propias: las toman de acá, así un cambio se aplica en todas.
class AppTheme {
  AppTheme._();

  static const Color verdeNoche = Color(0xFF07150E);
  static const Color verdeBosque = Color(0xFF0E3B24);
  static const Color verdePrincipal = Color(0xFF1A7F4B);
  static const Color verdeBrillante = Color(0xFF3DDC84);

  static const String _fuenteTitulos = 'Montserrat';
  static const double _radio = 12;

  static ThemeData get claro {
    final colores = ColorScheme.fromSeed(
      seedColor: verdePrincipal,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      primary: verdePrincipal,
      onPrimary: Colors.white,
      surface: Colors.white,
    );
    return _construir(
      colores,
      fondo: const Color(0xFFF3F6F3),
      barra: verdeBosque,
      textoBarra: Colors.white,
    );
  }

  static ThemeData get oscuro {
    final colores = ColorScheme.fromSeed(
      seedColor: verdeBrillante,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      primary: verdeBrillante,
      onPrimary: verdeNoche,
      surface: const Color(0xFF0D2016),
    );
    return _construir(
      colores,
      fondo: verdeNoche,
      barra: const Color(0xFF0D2016),
      textoBarra: Colors.white,
    );
  }

  static ThemeData _construir(
    ColorScheme colores, {
    required Color fondo,
    required Color barra,
    required Color textoBarra,
  }) {
    final base = ThemeData(useMaterial3: true, colorScheme: colores);
    final textos = _textos(base.textTheme);
    final esquinas = BorderRadius.circular(_radio);
    const pildora = StadiumBorder();
    const tamanoBoton = Size(64, 48);
    const relleno = EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    final textoBoton = textos.labelLarge;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colores,
      scaffoldBackgroundColor: fondo,
      textTheme: textos,
      appBarTheme: AppBarThemeData(
        backgroundColor: barra,
        foregroundColor: textoBarra,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: textos.titleLarge?.copyWith(color: textoBarra),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: colores.surface),
      listTileTheme: ListTileThemeData(
        selectedColor: colores.primary,
        selectedTileColor: colores.primary.withValues(alpha: 0.10),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: tamanoBoton,
          padding: relleno,
          shape: pildora,
          textStyle: textoBoton,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: tamanoBoton,
          padding: relleno,
          shape: pildora,
          textStyle: textoBoton,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: tamanoBoton,
          padding: relleno,
          shape: pildora,
          textStyle: textoBoton,
          side: BorderSide(color: colores.primary, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: pildora, textStyle: textoBoton),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(pildora),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          textStyle: WidgetStatePropertyAll(textoBoton),
          side: WidgetStatePropertyAll(BorderSide(color: colores.outlineVariant)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (estados) => estados.contains(WidgetState.selected) ? colores.primary : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (estados) => estados.contains(WidgetState.selected)
                ? colores.onPrimary
                : colores.onSurfaceVariant,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colores.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: esquinas),
        enabledBorder: OutlineInputBorder(
          borderRadius: esquinas,
          borderSide: BorderSide(color: colores.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: esquinas,
          borderSide: BorderSide(color: colores.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colores.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colores.outlineVariant),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(colores.primaryContainer),
        headingTextStyle: textos.titleSmall?.copyWith(color: colores.onPrimaryContainer),
        dataRowColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.hovered)
              ? colores.surfaceContainerHigh
              : colores.surface,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: esquinas),
      ),
    );
  }

  // Montserrat solo en títulos y botones; el texto corrido queda con la
  // fuente por defecto, que se lee mejor en tablas y formularios.
  static TextTheme _textos(TextTheme base) {
    TextStyle? titulo(TextStyle? estilo, FontWeight peso) =>
        estilo?.copyWith(fontFamily: _fuenteTitulos, fontWeight: peso);

    return base.copyWith(
      displayLarge: titulo(base.displayLarge, FontWeight.w800),
      displayMedium: titulo(base.displayMedium, FontWeight.w800),
      displaySmall: titulo(base.displaySmall, FontWeight.w800),
      headlineLarge: titulo(base.headlineLarge, FontWeight.w700),
      headlineMedium: titulo(base.headlineMedium, FontWeight.w700),
      headlineSmall: titulo(base.headlineSmall, FontWeight.w700),
      titleLarge: titulo(base.titleLarge, FontWeight.w700),
      // titleMedium queda con la fuente por defecto: Flutter lo usa para el
      // valor de las listas desplegables, que deben verse igual que los campos.
      titleSmall: titulo(base.titleSmall, FontWeight.w600),
      labelLarge: titulo(base.labelLarge, FontWeight.w600),
    );
  }
}
