// lib/api.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class API {
  static const String _endPoint = "https://149.50.143.81/cvrp/";

  // NOTA IMPORTANTE: Tu servidor parece usar un certificado SSL auto-firmado.
  // En producción, deberías usar un certificado válido. Para desarrollo,
  // necesitarás configurar Flutter para que acepte certificados "malos".
  // Esto se hace creando un archivo `lib/http_override.dart` y llamándolo
  // desde main.dart. Te mostraré cómo al final.

  // Reemplaza fetch con http.get y devuelve un Map<String, dynamic>
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

  // AsyncStorage -> SharedPreferences
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

    // json.decode convierte el array JSON directamente en una List<dynamic> de Dart.
    return json.decode(response.body) as List<dynamic>;
  }

  // // Petición POST con cuerpo y headers
  // static Future<String> enviarPedido(
  //   Map<String, dynamic> encabezado,
  //   List<dynamic> detalles,
  // ) async {
  //   final url = Uri.parse('${_endPoint}enviar_pedido.php');

  //   final body = {...encabezado, 'detalles': detalles};

  //   final response = await http.post(
  //     url,
  //     headers: {"Content-Type": "application/json"},
  //     body: json.encode(body),
  //   );

  //   // Devuelve el texto de la respuesta, igual que tu código original
  //   return response.body;
  // }

  static Future<Map<String, dynamic>> enviarPedido(
    Map<String, dynamic> pedidoData,
  ) async {
    // Apunta al nuevo script PHP
    final url = Uri.parse('${_endPoint}cargar_pedido.php');

    try {
      final response = await http.post(
        url,
        headers: {
          // Indicamos que estamos enviando JSON
          "Content-Type": "application/json",
        },
        // Codificamos todo el mapa 'pedidoData' como un string JSON
        body: json.encode(pedidoData),
      );

      // Decodificamos la respuesta JSON del servidor PHP
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Asume que PHP devuelve {"status": "success", "message": "...", "id_pedido": ...}
        return json.decode(response.body);
      } else {
        // Si el servidor devuelve un error (ej: 400, 500)
        print('Error del servidor: ${response.statusCode}');
        print('Respuesta del servidor: ${response.body}');
        // Intentamos decodificar si hay un mensaje de error JSON
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
      // Error de red o al codificar/decodificar
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
      // Devuelve la respuesta del servidor (ej: éxito o error)
      return json.decode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Error de conexión: $e'};
    }
  }

  static Future<Map<String, dynamic>> actualizarProducto(
    String productId,
    Map<String, dynamic> productData,
  ) async {
    // Añadimos el ID al cuerpo o a la URL según tu API
    final url = Uri.parse(
      '${_endPoint}actualizar_producto.php',
    ); // Podrías pasar el ID en la URL también
    try {
      final body = {
        ...productData,
        'id_producto': productId, // Incluye el ID para identificar el producto
      };
      final response = await http.put(
        // Usamos PUT para actualizar
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
        // Usamos DELETE
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({'id_producto': productId}), // Envía el ID
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Error de conexión: $e'};
    }
  }

  static Future<List<dynamic>> getCategorias() async {
    final url = Uri.parse(
      '${_endPoint}get_categorias.php',
    ); // Asegúrate que el script exista
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
    final url = Uri.parse(
      '${_endPoint}get_unidades_dimension.php',
    ); // Script PHP necesario
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

  // Obtiene pedidos filtrando por uno o más estados
  static Future<List<dynamic>> getPedidosPorEstado(List<String> estados) async {
    // Convierte la lista de estados en un string para la URL, ej: "Pendiente,En Proceso"
    final estadosParam = estados.join(',');
    final url = Uri.parse('${_endPoint}get_pedidos.php?estados=$estadosParam');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // Asume que devuelve un array de objetos Pedido
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Error del servidor ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('No se pudieron cargar los pedidos: $e');
    }
  }

  // Obtiene usuarios que son repartidores (y quizás disponibles)
  static Future<List<dynamic>> getRepartidoresDisponibles() async {
    // Podrías añadir filtros extra si tienes un estado 'disponible'
    final url = Uri.parse(
      '${_endPoint}get_repartidores.php?tipo=Repartidor&estado=disponible',
    ); // Ejemplo
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // Asume que devuelve un array de objetos Usuario (Repartidor)
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Error del servidor ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('No se pudieron cargar los repartidores: $e');
    }
  }

  // Envía los IDs seleccionados para generar rutas
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
      // Asume que devuelve una respuesta JSON indicando éxito/error o las rutas generadas
      return json.decode(response.body);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Error de conexión al generar rutas: $e',
      };
    }
  }
}
