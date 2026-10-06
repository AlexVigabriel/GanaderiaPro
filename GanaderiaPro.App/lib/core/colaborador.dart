// HU-32: colaboradores del rancho y su invitación.

// Roles que se le pueden dar a un colaborador (valor del servidor → texto).
const rolesDeColaborador = {
  'Veterinario': 'Veterinario',
  'EncargadoCorrales': 'Encargado de corrales',
  'EncargadoIngreso': 'Encargado de ingreso',
};

const _nombresDeRol = {'Propietario': 'Propietario', 'Socio': 'Socio', ...rolesDeColaborador};

String nombreDeRol(String rol) => _nombresDeRol[rol] ?? rol;

class Colaborador {
  const Colaborador({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.estado,
    this.ultimoAcceso,
    this.invitacionVence,
  });

  final String id;
  final String nombre;
  final String email;
  final String rol;
  // Pendiente, Activo o Inactivo.
  final String estado;
  final DateTime? ultimoAcceso;
  final DateTime? invitacionVence;

  bool get pendiente => estado == 'Pendiente';
  bool get inactivo => estado == 'Inactivo';

  factory Colaborador.fromJson(Map<String, dynamic> json) {
    final acceso = json['ultimoAcceso'] as String?;
    final vence = json['invitacionVence'] as String?;
    return Colaborador(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
      rol: json['rol'] as String,
      estado: json['estado'] as String,
      ultimoAcceso: acceso == null ? null : DateTime.parse(acceso).toLocal(),
      invitacionVence: vence == null ? null : DateTime.parse(vence).toLocal(),
    );
  }
}

// Respuesta al invitar o generar un enlace nuevo: el código solo viene acá.
class InvitacionCreada {
  const InvitacionCreada({required this.colaborador, required this.codigo, required this.vence});

  final Colaborador colaborador;
  final String codigo;
  final DateTime vence;

  factory InvitacionCreada.fromJson(Map<String, dynamic> json) => InvitacionCreada(
    colaborador: Colaborador.fromJson(json['colaborador'] as Map<String, dynamic>),
    codigo: json['codigo'] as String,
    vence: DateTime.parse(json['vence'] as String).toLocal(),
  );
}

// Lo que ve el colaborador al abrir el enlace.
class DatosInvitacion {
  const DatosInvitacion({required this.rancho, required this.nombre, required this.email, required this.rol});

  final String rancho;
  final String nombre;
  final String email;
  final String rol;

  factory DatosInvitacion.fromJson(Map<String, dynamic> json) => DatosInvitacion(
    rancho: json['rancho'] as String,
    nombre: json['nombre'] as String,
    email: json['email'] as String,
    rol: json['rol'] as String,
  );
}

// Enlace que se manda al colaborador: abre la app en la pantalla de invitación.
String enlaceDeInvitacion(String codigo, {Uri? base}) {
  final b = base ?? Uri.base;
  // Fuera del navegador (por ejemplo, en pruebas) no hay origen web.
  final origen = b.scheme == 'http' || b.scheme == 'https' ? b.origin : '';
  return '$origen/#/invitacion?codigo=${Uri.encodeQueryComponent(codigo)}';
}
