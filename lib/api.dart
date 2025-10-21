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
      '${_endPoint}login_user.php?user=$user&password=$password',
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
}
