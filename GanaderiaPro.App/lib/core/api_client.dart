import 'dart:convert';

import 'package:http/http.dart' as http;

import 'animal.dart';
import 'sesion_actual.dart';

class ApiException implements Exception {
  ApiException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

class ApiClient {
  ApiClient({this.baseUrl = 'http://localhost:5199'});

  final String baseUrl;

  Map<String, String> get _headersAutenticados {
    final token = SesionActual.instancia.token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> registrarCuenta({
    required String nombre,
    required String email,
    required String contrasena,
    required String confirmarContrasena,
    required String nombreRancho,
    required String plan,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/registrar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'email': email,
        'contrasena': contrasena,
        'confirmarContrasena': confirmarContrasena,
        'nombreRancho': nombreRancho,
        'plan': plan,
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo crear la cuenta.');
    }
  }

  Future<void> iniciarSesion({required String email, required String contrasena}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/iniciar-sesion'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'contrasena': contrasena}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo iniciar sesión.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    SesionActual.instancia.guardar(
      token: data['token'] as String,
      nombreRancho: data['nombreRancho'] as String,
      nombreUsuario: data['nombreUsuario'] as String,
    );
  }

  Future<Animal> registrarAnimal({
    required String arete,
    required String sexo,
    required String raza,
    double? peso,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/animales'),
      headers: _headersAutenticados,
      body: jsonEncode({
        'arete': arete,
        'sexo': sexo,
        'raza': raza,
        'peso': peso,
      }),
    );

    if (response.statusCode == 201) {
      return Animal.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo registrar el animal.');
  }

  Future<List<Animal>> buscarAnimales({
    String? busqueda,
    String? estado,
    String? sexo,
    String? raza,
  }) async {
    final query = <String, String>{};
    if (busqueda != null && busqueda.isNotEmpty) query['busqueda'] = busqueda;
    if (estado != null) query['estado'] = estado;
    if (sexo != null) query['sexo'] = sexo;
    if (raza != null && raza.isNotEmpty) query['raza'] = raza;

    final uri = Uri.parse(
      '$baseUrl/api/animales',
    ).replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: _headersAutenticados);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((json) => Animal.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    throw ApiException('No se pudo cargar el listado de animales.');
  }

  String? _extraerMensajeError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['mensaje'] as String?;
    } catch (_) {
      return null;
    }
  }
}
