import 'dart:convert';

import 'package:http/http.dart' as http;

import 'animal.dart';

class ApiException implements Exception {
  ApiException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

class ApiClient {
  ApiClient({this.baseUrl = 'http://localhost:5199'});

  final String baseUrl;

  Future<Animal> registrarAnimal({
    required String arete,
    required String sexo,
    required String raza,
    double? peso,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/animales'),
      headers: {'Content-Type': 'application/json'},
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

    final response = await http.get(uri);

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
