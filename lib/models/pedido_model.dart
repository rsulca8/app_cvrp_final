// lib/models/pedido_model.dart
import 'dart:convert';

import 'package:intl/intl.dart';

class Pedido {
  final String idPedido;
  final String idUsuario;
  final DateTime fechaHoraPedido;
  final String estado;
  final double totalPedido;
  final String direccionEntrega;
  final String nombreCliente;
  final String apellidoCliente;

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
    DateTime parsedDate;
    try {
      parsedDate = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).parse(json['fecha_hora_pedido'] ?? '');
    } catch (e) {
      print(
        "Error parseando fecha_hora_pedido: ${json['fecha_hora_pedido']} - $e",
      );
      parsedDate = DateTime.now();
    }

    return Pedido(
      idPedido: json['id_pedido']?.toString() ?? 'N/A',
      idUsuario: json['id_usuario']?.toString() ?? 'N/A',
      fechaHoraPedido: parsedDate,
      estado: json['estado'] ?? 'Desconocido',
      totalPedido:
          double.tryParse(json['total_pedido']?.toString() ?? '0.0') ?? 0.0,
      direccionEntrega: json['direccion_entrega'] ?? 'N/A',
      nombreCliente: json['nombre_cliente'] ?? '',
      apellidoCliente: json['apellido_cliente'] ?? '',
    );
  }

  String get nombreCompletoCliente => '$nombreCliente $apellidoCliente'.trim();
}

class Repartidor {
  final String idUsuario;
  final String nombre;
  final String apellido;

  Repartidor({
    required this.idUsuario,
    required this.nombre,
    required this.apellido,
  });

  factory Repartidor.fromJson(Map<String, dynamic> json) {
    return Repartidor(
      idUsuario: json['id_usuario']?.toString() ?? 'N/A',
      nombre: json['nombre'] ?? 'Sin nombre',
      apellido: json['apellido'] ?? '',
    );
  }
  String get nombreCompleto => '$nombre $apellido'.trim();
}

class Ruta {
  final String idRuta;
  final String idRepartidor;
  final DateTime fechaHoraCreacion;
  final String estadoRuta;
  final double? distanciaTotalMetros;
  final int? duracionTotalSegundos;
  final String repartidorNombre;
  final String repartidorApellido;
  // --- ¡NUEVO! Geometría ---
  // Puede ser String (JSON) o ya un Map si PHP lo decodifica
  final dynamic geometriaGeojson;
  // --- Fin Nuevo ---

  Ruta({
    required this.idRuta,
    required this.idRepartidor,
    required this.fechaHoraCreacion,
    required this.estadoRuta,
    this.distanciaTotalMetros,
    this.duracionTotalSegundos,
    required this.repartidorNombre,
    required this.repartidorApellido,
    this.geometriaGeojson, // <-- Añadir al constructor
  });

  factory Ruta.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).parse(json['fecha_hora_creacion'] ?? '');
    } catch (e) {
      parsedDate = DateTime.now();
    }

    // Intenta decodificar geometría si es un string JSON
    dynamic geoJsonData = json['geometria_geojson'];
    if (geoJsonData is String) {
      try {
        geoJsonData = jsonDecode(geoJsonData);
      } catch (_) {
        print(
          "Advertencia: geometria_geojson no es JSON válido para ruta ${json['id_ruta']}",
        );
        geoJsonData = null; // Asigna null si no se puede decodificar
      }
    }

    return Ruta(
      idRuta: json['id_ruta']?.toString() ?? 'N/A',
      idRepartidor: json['id_repartidor']?.toString() ?? 'N/A',
      fechaHoraCreacion: parsedDate,
      estadoRuta: json['estado_ruta'] ?? 'Desconocido',
      distanciaTotalMetros: double.tryParse(
        json['distancia_total_metros']?.toString() ?? '',
      ),
      duracionTotalSegundos: int.tryParse(
        json['duracion_total_segundos']?.toString() ?? '',
      ),
      repartidorNombre: json['repartidor_nombre'] ?? 'Repartidor',
      repartidorApellido: json['repartidor_apellido'] ?? 'N/A',
      geometriaGeojson: geoJsonData, // <-- Asignar geometría
    );
  }

  String get nombreCompletoRepartidor =>
      '$repartidorNombre $repartidorApellido'.trim();

  String get distanciaFormateada {
    /* ... sin cambios ... */
    if (distanciaTotalMetros == null) return 'N/A';
    if (distanciaTotalMetros! < 1000)
      return '${distanciaTotalMetros!.toStringAsFixed(0)} m';
    return '${(distanciaTotalMetros! / 1000).toStringAsFixed(1)} km';
  }

  String get duracionFormateada {
    /* ... sin cambios ... */
    if (duracionTotalSegundos == null) return 'N/A';
    final duration = Duration(seconds: duracionTotalSegundos!);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    if (duration.inHours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes} min';
    }
  }
}
