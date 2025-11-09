// lib/api.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class API {
  static const String _endPoint = "https://149.50.143.81/cvrp/";

  static Future<Map<String, dynamic>> checkLogin(
    String user,
    String password,
  ) async {
    final url = Uri.parse(
      '${_endPoint}login.php?user=$user&password=$password',
    );
    final response = await http.get(url);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> createUser(
    String nombre,
    String apellido,
    String email,
    String user,
    String password,
  ) async {
    final url = Uri.parse(
      '${_endPoint}create_user.php?user=$user&password=$password&email=$email&nombre=$nombre&apellido=$apellido',
    );
    final response = await http.get(url);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> getUserInfo(String user) async {
    final url = Uri.parse('${_endPoint}user_info.php?user=$user');
    final response = await http.get(url);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>?> getDatosUsuarioLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(
      'userData',
    ); // Usamos la misma clave que en AuthService
    if (userDataString != null) {
      return json.decode(userDataString) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<List<dynamic>> getProductos() async {
    final url = Uri.parse('${_endPoint}get_productos.php');
    final response = await http.get(url);
    return json.decode(response.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> enviarPedido(
    Map<String, dynamic> pedidoData,
  ) async {
    final url = Uri.parse('${_endPoint}cargar_pedido.php');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(pedidoData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        print('Error del servidor: ${response.statusCode}');
        print('Respuesta del servidor: ${response.body}');
        try {
          return {
            'status': 'error',
            'message':
                json.decode(response.body)['message'] ??
                'Error desconocido del servidor',
          };
        } catch (_) {
          return {
            'status': 'error',
            'message': 'Respuesta inválida del servidor: ${response.body}',
          };
        }
      }
    } catch (e) {
      print('Error al enviar pedido: $e');
      return {'status': 'error', 'message': 'Error de conexión o formato: $e'};
    }
  }

  static Future<Map<String, dynamic>> crearProducto(
    Map<String, dynamic> productData,
  ) async {
    final url = Uri.parse('${_endPoint}crear_producto.php');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(productData),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Error de conexión: $e'};
    }
  }

  static Future<Map<String, dynamic>> actualizarProducto(
    String productId,
    Map<String, dynamic> productData,
  ) async {
    final url = Uri.parse('${_endPoint}actualizar_producto.php');
    try {
      final body = {
        ...productData,
        'id_producto': productId,
      };
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Error de conexión: $e'};
    }
  }

  static Future<Map<String, dynamic>> eliminarProducto(String productId) async {
    final url = Uri.parse('${_endPoint}eliminar_producto.php');
    try {
      final response = await http.delete(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({'id_producto': productId}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Error de conexión: $e'};
    }
  }

  static Future<List<dynamic>> getCategorias() async {
    final url = Uri.parse('${_endPoint}get_categorias.php');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception(
          'Error del servidor al obtener categorías: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error en getCategorias: $e');
      throw Exception('No se pudieron cargar las categorías.');
    }
  }

  static Future<List<dynamic>> getUnidadesPeso() async {
    final url = Uri.parse('${_endPoint}get_unidades_peso.php');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Error del servidor ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('No se pudieron cargar las unidades de peso: $e');
    }
  }

  static Future<List<dynamic>> getUnidadesDimension() async {
    final url = Uri.parse('${_endPoint}get_unidades_dimension.php');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Error del servidor ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('No se pudieron cargar las unidades de dimensión: $e');
    }
  }

  static Future<List<dynamic>> getPedidosPorEstado(List<String> estados) async {
    final estadosParam = estados.join(',');
    final url = Uri.parse('${_endPoint}get_pedidos.php?estados=$estadosParam');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Error del servidor ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('No se pudieron cargar los pedidos: $e');
    }
  }

  static Future<List<dynamic>> getRepartidoresDisponibles() async {
    final url = Uri.parse('${_endPoint}get_repartidores.php?tipo=Repartidor&estado=disponible');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Error del servidor ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('No se pudieron cargar los repartidores: $e');
    }
  }

  static Future<Map<String, dynamic>> generarRutas(
    List<String> pedidoIds,
    List<String> repartidorIds,
  ) async {
    final url = Uri.parse('${_endPoint}generar_rutas.php');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'pedido_ids': pedidoIds,
          'repartidor_ids': repartidorIds,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Error de conexión al generar rutas: $e',
      };
    }
  }

  static Future<List<dynamic>> getRutasAsignadas() async {
    final url = Uri.parse('${_endPoint}get_rutas.php?estados=Asignada,En Curso');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Error del servidor ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('No se pudieron cargar las rutas: $e');
    }
  }

  static Future<Map<String, dynamic>> getDetallesRuta(String rutaId) async {
    if (rutaId.isEmpty || int.tryParse(rutaId) == null || int.parse(rutaId) <= 0) {
      throw ArgumentError('ID de ruta inválido proporcionado.');
    }

    final url = Uri.parse('${_endPoint}get_ruta_detalle.php?id_ruta=$rutaId');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is Map<String, dynamic> && data.containsKey('status')) {
          if (data['status'] == 'success') {
            return data;
          } else {
            throw Exception(
              data['message'] ?? 'Error reportado por el servidor al obtener detalles.',
            );
          }
        } else {
          throw Exception('Respuesta JSON inesperada del servidor.');
        }
      } else {
        String errorMessage = 'Error del servidor (${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
            errorMessage += ': ${errorData['message']}';
          }
        } catch (_) {
        }
        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      print('Error de red en getDetallesRuta: $e');
      throw Exception('Error de red al obtener detalles de la ruta. Verifica tu conexión.');
    } catch (e) {
      print('Error en getDetallesRuta: $e');
      throw Exception('No se pudieron cargar los detalles de la ruta: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  static Future<Map<String, dynamic>> getAllConfiguraciones() async {
    final url = Uri.parse(
      '${_endPoint}get_configuracion.php',
    ); // Llama sin ?clave=...
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          throw Exception('Respuesta JSON no es un mapa.');
        }
      } else {
        throw Exception('Error del servidor ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getAllConfiguraciones: $e');
      return {
        'status': 'error',
        'message': 'No se pudo cargar la configuración: ${e.toString().replaceFirst("Exception: ", "")}',
        'configuraciones': [],
      };
    }
  }

  static Future<Map<String, dynamic>> actualizarConfiguracion(
    String clave,
    String nuevoValor,
  ) async {
    final url = Uri.parse('${API._endPoint}actualizar_configuracion.php');
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'clave': clave,
          'valor': nuevoValor,
        }),
      );
      final decodedResponse = json.decode(response.body);
      if (response.statusCode == 200) {
        if (decodedResponse is Map<String, dynamic>) {
          return decodedResponse;
        } else {
          throw Exception('Respuesta inesperada del servidor.');
        }
      } else {
        throw Exception(decodedResponse['message'] ?? 'Error ${response.statusCode} del servidor.');
      }
    } catch (e) {
      print('Error en actualizarConfiguracion: $e');
      throw Exception('Error de conexión o formato: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  static Future<Map<String, dynamic>> getMiRutaActiva(
    String repartidorId,
  ) async {
    final url = Uri.parse(
      '${API._endPoint}get_ruta_activa_repartidor.php?id_repartidor=$repartidorId',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          throw Exception('Respuesta JSON no es un mapa.');
        }
      } else {
        throw Exception('Error del servidor (${response.statusCode})');
      }
    } catch (e) {
      print('Error en getMiRutaActiva: $e');
      throw Exception('No se pudo cargar la ruta activa: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  static Future<List<dynamic>> getRutasPorRepartidor(
    String repartidorId,
    List<String> estados,
  ) async {
    if (repartidorId.isEmpty) {
      throw ArgumentError('ID de repartidor inválido.');
    }

    if (estados.isEmpty) {
      return [];
    }
    final estadosParam = estados.join(',');
    final url = Uri.parse(
      '${API._endPoint}get_rutas_repartidor.php?id_repartidor=$repartidorId&estados=$estadosParam',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['status'] == 'success') {
          return data['rutas'] as List<dynamic>? ?? [];
        } else if (data is List<dynamic>) {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Respuesta inválida del servidor.');
        }
      } else {
        throw Exception('Error del servidor (${response.statusCode})');
      }
    } catch (e) {
      print('Error en getRutasPorRepartidor: $e');
      throw Exception('No se pudieron cargar las rutas: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  static Future<Map<String, dynamic>> actualizarEstadoParada(
    String idRutaDetalle,
    String nuevoEstado, {
    String? motivo,
  }) async {
    final url = Uri.parse('${API._endPoint}actualizar_estado_parada.php');
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'id_ruta_detalle': idRutaDetalle,
          'nuevo_estado': nuevoEstado,
          'motivo_fallo': motivo, // Será null si no se provee
        }),
      );

      final decodedResponse = json.decode(response.body);
      if (response.statusCode == 200) {
        if (decodedResponse is Map<String, dynamic>) {
          return decodedResponse; // Devuelve la respuesta del PHP (ej: {'status':'success', 'message': '...'})
        } else {
          throw Exception('Respuesta inesperada del servidor.');
        }
      } else {
        // Error HTTP (400, 500, etc.)
        throw Exception(
          decodedResponse['message'] ??
              'Error ${response.statusCode} del servidor.',
        );
      }
    } catch (e) {
      print('Error en actualizarEstadoParada: $e');
      throw Exception(
        'Error de conexión o formato: ${e.toString().replaceFirst("Exception: ", "")}',
      );
    }
  }

  static Future<Map<String, dynamic>> getPedidoDetalles(String idPedido) async {
    // Valida el ID localmente antes de hacer la llamada
    if (idPedido.isEmpty ||
        int.tryParse(idPedido) == null ||
        int.parse(idPedido) <= 0) {
      throw ArgumentError('ID de pedido inválido proporcionado.');
    }

    // Construye la URL
    final url = Uri.parse(
      '${API._endPoint}get_pedido_detalles.php?id_pedido=$idPedido',
    );

    try {
      // Llama al script PHP
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Si el servidor responde OK
        final data = json.decode(response.body);

        // Comprueba el 'status' dentro del JSON devuelto por PHP
        if (data is Map<String, dynamic> && data['status'] == 'success') {
          // Devuelve el mapa completo, que incluye {'status': 'success', 'detalles': [...]}
          return data;
        } else {
          // Si el PHP devolvió {'status': 'error', 'message': '...'}
          throw Exception(
            data['message'] ?? 'Respuesta inválida del servidor.',
          );
        }
      } else {
        // Error de HTTP (ej: 404, 500)
        throw Exception('Error del servidor (${response.statusCode})');
      }
    } catch (e) {
      // Error de red, decodificación JSON, o excepciones de arriba
      print('Error en getPedidoDetalles: $e');
      throw Exception(
        'No se pudieron cargar los detalles del pedido: ${e.toString().replaceFirst("Exception: ", "")}',
      );
    }
  }

  static Future<Map<String, dynamic>> getAllUsuarios() async {
    final url = Uri.parse('${API._endPoint}get_usuarios.php');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['status'] == 'success') {
          return data;
        } else {
          throw Exception(
            data['message'] ?? 'Respuesta inválida del servidor.',
          );
        }
      } else {
        throw Exception('Error del servidor (${response.statusCode})');
      }
    } catch (e) {
      print('Error en getAllUsuarios: $e');
      throw Exception(
        'No se pudieron cargar los usuarios: ${e.toString().replaceFirst("Exception: ", "")}',
      );
    }
  }
}
