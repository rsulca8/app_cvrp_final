// lib/models/pedido_model.dart

class Pedido {
  final String idPedido;
  final String idUsuario;
  final DateTime fechaHoraPedido;
  final String estado;
  final double totalPedido;
  final String direccionEntrega;
  final String nombreCliente; // Añadido para mostrar en la lista
  final String apellidoCliente; // Añadido

  // Puedes añadir más campos si los necesitas (lat, lng, email, telefono, etc.)

  Pedido({
    required this.idPedido,
    required this.idUsuario,
    required this.fechaHoraPedido,
    required this.estado,
    required this.totalPedido,
    required this.direccionEntrega,
    required this.nombreCliente,
    required this.apellidoCliente,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) {
    return Pedido(
      idPedido: json['id_pedido'].toString(), // Asegurar que sea String
      idUsuario: json['id_usuario'].toString(),
      // Parsea la fecha (ajusta el formato si es diferente en tu API)
      fechaHoraPedido:
          DateTime.tryParse(json['fecha_hora_pedido'] ?? '') ?? DateTime.now(),
      estado: json['estado'] ?? 'Desconocido',
      totalPedido:
          double.tryParse(json['total_pedido']?.toString() ?? '0.0') ?? 0.0,
      direccionEntrega: json['direccion_entrega'] ?? 'N/A',
      nombreCliente: json['nombre_cliente'] ?? '', // Campo de la tabla Pedidos
      apellidoCliente:
          json['apellido_cliente'] ?? '', // Campo de la tabla Pedidos
    );
  }

  // Método útil para mostrar el nombre completo
  String get nombreCompletoCliente => '$nombreCliente $apellidoCliente'.trim();
}

// Modelo simple para Repartidor (puedes crear un UserModel más completo si quieres)
class Repartidor {
  final String idUsuario;
  final String nombre;
  final String apellido;
  // Puedes añadir 'disponible', 'vehiculo', etc.

  Repartidor({
    required this.idUsuario,
    required this.nombre,
    required this.apellido,
  });

  factory Repartidor.fromJson(Map<String, dynamic> json) {
    return Repartidor(
      idUsuario: json['id_usuario'].toString(),
      nombre: json['nombre'] ?? 'Sin nombre',
      apellido: json['apellido'] ?? '',
    );
  }
  String get nombreCompleto => '$nombre $apellido'.trim();
}
