import 'dart:convert';

import 'package:http/http.dart' as http;

import 'animal.dart';
import 'cerrar_sesion.dart';
import 'colaborador.dart';
import 'conexion.dart';
import 'corral.dart';
import 'plan.dart';
import 'sanidad.dart';
import 'sesion_actual.dart';

class ApiException implements Exception {
  ApiException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

class ApiClient {
  ApiClient({this.baseUrl = urlServidor});

  final String baseUrl;
  final _http = ClienteConSesion();

  Map<String, String> get _headersAutenticados {
    final token = SesionActual.instancia.token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // HU-52: invalida el token en el servidor. Si falla la red, la sesión se
  // cierra igual en la app.
  Future<void> cerrarSesion() async {
    await _http
        .post(Uri.parse('$baseUrl/api/auth/cerrar-sesion'), headers: _headersAutenticados)
        .timeout(const Duration(seconds: 5));
  }

  Future<void> registrarCuenta({
    required String nombre,
    required String email,
    required String contrasena,
    required String confirmarContrasena,
    required String nombreRancho,
    required String plan,
  }) async {
    final response = await _http.post(
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
    final response = await _http.post(
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
      rol: data['rol'] as String? ?? 'Propietario',
      permisos: (data['permisos'] as Map<String, dynamic>?)?.map((modulo, nivel) => MapEntry(modulo, nivel as String)),
    );
  }

  // HU-66: carga múltiple. Las filas rechazadas vuelven con su número
  // (empezando en 1, en el mismo orden en que se enviaron) y el motivo.
  Future<ResultadoCarga> registrarLote(List<DatosAnimal> filas) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/api/animales/lote'),
      headers: _headersAutenticados,
      body: jsonEncode(filas.map((f) => f.toJson()).toList()),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudieron registrar los animales.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ResultadoCarga(
      registrados: (data['registrados'] as List<dynamic>).length,
      rechazados: (data['rechazados'] as List<dynamic>)
          .map((r) => r as Map<String, dynamic>)
          .map((r) => FilaRechazada(fila: r['fila'] as int, motivo: r['motivo'] as String))
          .toList(),
    );
  }

  Future<ResumenAnimales> obtenerResumen() async {
    final response = await _http.get(Uri.parse('$baseUrl/api/animales/resumen'), headers: _headersAutenticados);

    if (response.statusCode == 200) {
      return ResumenAnimales.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException('No se pudo cargar el resumen de animales.');
  }

  Future<Animal> obtenerAnimal(String id) async {
    final response = await _http.get(Uri.parse('$baseUrl/api/animales/$id'), headers: _headersAutenticados);

    if (response.statusCode == 200) {
      return Animal.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo cargar el animal.');
  }

  Future<Animal> editarAnimal(String id, DatosAnimal datos) async {
    final response = await _http.put(
      Uri.parse('$baseUrl/api/animales/$id'),
      headers: _headersAutenticados,
      body: jsonEncode(datos.toJson()),
    );

    if (response.statusCode == 200) {
      return Animal.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo editar el animal.');
  }

  // HU-54: baja desde la calavera (solo animales activos).
  Future<Animal> registrarBaja(String id, DatosEstado datos) =>
      _enviarEstado(_http.post, '$baseUrl/api/animales/$id/baja', datos);

  // HU-54: cambio de estado desde Editar (incluye volver a Activo).
  Future<Animal> cambiarEstado(String id, DatosEstado datos) =>
      _enviarEstado(_http.put, '$baseUrl/api/animales/$id/estado', datos);

  Future<Animal> _enviarEstado(
    Future<http.Response> Function(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) metodo,
    String url,
    DatosEstado datos,
  ) async {
    final response = await metodo(Uri.parse(url), headers: _headersAutenticados, body: jsonEncode(datos.toJson()));

    if (response.statusCode == 200) {
      return Animal.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo cambiar el estado del animal.');
  }

  // HU-55: historial de pesajes, del más reciente al más antiguo.
  Future<List<Pesaje>> listarPesajes(String animalId) async {
    final response = await _http.get(Uri.parse('$baseUrl/api/animales/$animalId/pesajes'), headers: _headersAutenticados);

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>)
          .map((json) => Pesaje.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo cargar el historial de pesajes.');
  }

  Future<void> registrarPesaje(String animalId, {required double peso, required DateTime fecha, String? observacion}) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/api/animales/$animalId/pesajes'),
      headers: _headersAutenticados,
      body: jsonEncode({'peso': peso, 'fecha': DatosAnimal.fechaIso(fecha), 'observacion': observacion}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo registrar el pesaje.');
    }
  }

  Future<void> editarPesaje(
    String animalId,
    String pesajeId, {
    required double peso,
    required DateTime fecha,
    String? observacion,
  }) async {
    final response = await _http.put(
      Uri.parse('$baseUrl/api/animales/$animalId/pesajes/$pesajeId'),
      headers: _headersAutenticados,
      body: jsonEncode({'peso': peso, 'fecha': DatosAnimal.fechaIso(fecha), 'observacion': observacion}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo editar el pesaje.');
    }
  }

  Future<void> eliminarPesaje(String animalId, String pesajeId) async {
    final response = await _http.delete(
      Uri.parse('$baseUrl/api/animales/$animalId/pesajes/$pesajeId'),
      headers: _headersAutenticados,
    );

    if (response.statusCode != 200) {
      throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo eliminar el pesaje.');
    }
  }

  // ---- HU-58: uso del plan (solo el propietario)
  Future<UsoPlan> obtenerUsoPlan() async {
    final response = await _http.get(Uri.parse('$baseUrl/api/plan/uso'), headers: _headersAutenticados);
    if (response.statusCode == 200) {
      return UsoPlan.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo cargar el uso del plan.');
  }

  // ---- HU-32: Colaboradores e invitaciones
  Future<List<Colaborador>> listarColaboradores() async {
    final response = await _http.get(Uri.parse('$baseUrl/api/colaboradores'), headers: _headersAutenticados);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>)
          .map((json) => Colaborador.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudieron cargar los colaboradores.');
  }

  Future<InvitacionCreada> invitarColaborador({required String nombre, required String email, required String rol}) =>
      _enviarInvitacion(
        _http.post(
          Uri.parse('$baseUrl/api/colaboradores'),
          headers: _headersAutenticados,
          body: jsonEncode({'nombre': nombre, 'email': email, 'rol': rol}),
        ),
      );

  Future<InvitacionCreada> regenerarInvitacion(String colaboradorId) => _enviarInvitacion(
    _http.post(Uri.parse('$baseUrl/api/colaboradores/$colaboradorId/invitacion'), headers: _headersAutenticados),
  );

  Future<InvitacionCreada> _enviarInvitacion(Future<http.Response> pedido) async {
    final response = await pedido;
    if (response.statusCode == 200) {
      return InvitacionCreada.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo generar la invitación.');
  }

  Future<void> cambiarRolColaborador(String colaboradorId, String rol) => _enviarColaborador(
    _http.put(
      Uri.parse('$baseUrl/api/colaboradores/$colaboradorId/rol'),
      headers: _headersAutenticados,
      body: jsonEncode({'rol': rol}),
    ),
  );

  Future<void> cambiarEstadoColaborador(String colaboradorId, {required bool activo}) => _enviarColaborador(
    _http.post(
      Uri.parse('$baseUrl/api/colaboradores/$colaboradorId/${activo ? 'activar' : 'desactivar'}'),
      headers: _headersAutenticados,
    ),
  );

  Future<void> _enviarColaborador(Future<http.Response> pedido) async {
    final response = await pedido;
    if (response.statusCode != 200) {
      throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo actualizar el colaborador.');
    }
  }

  // Público: el colaborador todavía no tiene sesión.
  Future<DatosInvitacion> obtenerInvitacion(String codigo) async {
    final response = await _http.get(Uri.parse('$baseUrl/api/invitaciones/${Uri.encodeComponent(codigo)}'));
    if (response.statusCode == 200) {
      return DatosInvitacion.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ApiException(_extraerMensajeError(response.body) ?? 'El enlace no es válido.');
  }

  Future<void> aceptarInvitacion(String codigo, {required String contrasena, required String confirmar}) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/api/invitaciones/${Uri.encodeComponent(codigo)}/aceptar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contrasena': contrasena, 'confirmarContrasena': confirmar}),
    );
    if (response.statusCode != 204) {
      throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo aceptar la invitación.');
    }
  }

  // ---- HU-23 / HU-24: Corrales
  Future<List<Corral>> listarCorrales({bool incluirInactivos = false}) async {
    final uri = Uri.parse('$baseUrl/api/corrales').replace(
      queryParameters: incluirInactivos ? {'incluirInactivos': 'true'} : null,
    );
    final response = await _http.get(uri, headers: _headersAutenticados);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>)
          .map((json) => Corral.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw ApiException('No se pudieron cargar los corrales.');
  }

  Future<Corral> crearCorral({required String nombre, required int capacidad, List<String> animalIds = const []}) =>
      _enviarCorral(
        _http.post(
          Uri.parse('$baseUrl/api/corrales'),
          headers: _headersAutenticados,
          body: jsonEncode({'nombre': nombre, 'capacidad': capacidad, 'animalIds': animalIds}),
        ),
        'No se pudo crear el corral.',
      );

  Future<Corral> editarCorral(String id, {required String nombre, required int capacidad}) => _enviarCorral(
    _http.put(
      Uri.parse('$baseUrl/api/corrales/$id'),
      headers: _headersAutenticados,
      body: jsonEncode({'nombre': nombre, 'capacidad': capacidad}),
    ),
    'No se pudo editar el corral.',
  );

  Future<Corral> cambiarEstadoCorral(String id, {required bool activo}) => _enviarCorral(
    _http.post(
      Uri.parse('$baseUrl/api/corrales/$id/${activo ? 'activar' : 'desactivar'}'),
      headers: _headersAutenticados,
    ),
    'No se pudo cambiar el estado del corral.',
  );

  // Cambia el corral del animal; null lo deja sin corral.
  Future<void> asignarCorral(String animalId, String? corralId) async {
    final response = await _http.put(
      Uri.parse('$baseUrl/api/animales/$animalId/corral'),
      headers: _headersAutenticados,
      body: jsonEncode({'corralId': corralId}),
    );
    if (response.statusCode != 204) {
      throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo cambiar el corral.');
    }
  }

  Future<Corral> _enviarCorral(Future<http.Response> pedido, String mensajeError) async {
    final response = await pedido;
    if (response.statusCode == 200) {
      return Corral.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ApiException(_extraerMensajeError(response.body) ?? mensajeError);
  }

  // ---- HU-26: Sanidad
  Future<List<Vacuna>> listarVacunas() async {
    final response = await _http.get(Uri.parse('$baseUrl/api/vacunas'), headers: _headersAutenticados);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>)
          .map((json) => Vacuna.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw ApiException('No se pudo cargar la lista de vacunas.');
  }

  Future<List<Vacunacion>> listarVacunaciones({String? animalId}) async {
    final ruta = animalId == null ? '$baseUrl/api/vacunaciones' : '$baseUrl/api/animales/$animalId/vacunaciones';
    final response = await _http.get(Uri.parse(ruta), headers: _headersAutenticados);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>)
          .map((json) => Vacunacion.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudieron cargar las vacunaciones.');
  }

  // HU-27
  Future<ResumenSanidad> obtenerResumenSanidad() async {
    final response = await _http.get(Uri.parse('$baseUrl/api/sanidad/resumen'), headers: _headersAutenticados);
    if (response.statusCode == 200) {
      return ResumenSanidad.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ApiException('No se pudieron cargar los indicadores de sanidad.');
  }

  Future<List<Pendiente>> listarPendientes() async {
    final response = await _http.get(Uri.parse('$baseUrl/api/vacunaciones/pendientes'), headers: _headersAutenticados);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>)
          .map((json) => Pendiente.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw ApiException('No se pudieron cargar las vacunaciones pendientes.');
  }

  Future<VerificacionVacunacion> verificarVacunacion(List<String> animalIds, DatosVacunacion datos) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/api/vacunaciones/verificar'),
      headers: _headersAutenticados,
      body: jsonEncode({'animalIds': animalIds, ...datos.toJson()}),
    );
    if (response.statusCode == 200) {
      return VerificacionVacunacion.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo revisar la vacunación.');
  }

  // Una misma aplicación para uno o varios animales. [confirmado]: el usuario
  // ya vio los avisos de vacunas programadas o recientes.
  Future<int> registrarVacunacion(List<String> animalIds, DatosVacunacion datos, {bool confirmado = false}) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/api/vacunaciones'),
      headers: _headersAutenticados,
      body: jsonEncode({'animalIds': animalIds, ...datos.toJson(), 'confirmado': confirmado}),
    );
    if (response.statusCode == 200) return (jsonDecode(response.body) as List<dynamic>).length;
    throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo registrar la vacunación.');
  }

  Future<void> editarVacunacion(String id, DatosVacunacion datos) async {
    final response = await _http.put(
      Uri.parse('$baseUrl/api/vacunaciones/$id'),
      headers: _headersAutenticados,
      body: jsonEncode(datos.toJson()),
    );
    if (response.statusCode != 200) {
      throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo editar la vacunación.');
    }
  }

  Future<void> eliminarVacunacion(String id) async {
    final response = await _http.delete(Uri.parse('$baseUrl/api/vacunaciones/$id'), headers: _headersAutenticados);
    if (response.statusCode != 204) {
      throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo eliminar la vacunación.');
    }
  }

  Future<void> eliminarAnimal(String id) async {
    final response = await _http.delete(Uri.parse('$baseUrl/api/animales/$id'), headers: _headersAutenticados);

    if (response.statusCode != 204) {
      throw ApiException(_extraerMensajeError(response.body) ?? 'No se pudo eliminar el animal.');
    }
  }

  Future<List<Animal>> buscarAnimales({
    String? busqueda,
    String? estado,
    String? sexo,
    String? raza,
    String? categoria,
  }) async {
    final query = <String, String>{};
    if (busqueda != null && busqueda.isNotEmpty) query['busqueda'] = busqueda;
    if (estado != null) query['estado'] = estado;
    if (sexo != null) query['sexo'] = sexo;
    if (raza != null && raza.isNotEmpty) query['raza'] = raza;
    if (categoria != null) query['categoria'] = categoria;

    final uri = Uri.parse(
      '$baseUrl/api/animales',
    ).replace(queryParameters: query.isEmpty ? null : query);

    final response = await _http.get(uri, headers: _headersAutenticados);

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
