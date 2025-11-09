import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart'; // Necesario si usas Colors, etc.
import 'dart:convert'; // Para jsonDecode
import 'api.dart'; // Para llamar a la API

// Clase para manejar la configuración de la aplicación
class Configuracion {
  // --- Valores de Configuración ---
  // Mapa para almacenar la configuración cargada
  static Map<String, dynamic> _configValues = {};

  // --- Depósito ---
  // Coordenadas por defecto si la carga falla
  static const LatLng _defaultDepositoLatLng = LatLng(
    -24.789100,
    -65.410600,
  ); // Salta Centro

  // Getter para obtener las coordenadas del depósito
  static LatLng get depositoLatLng {
    final valueString =
        _configValues['deposito_ubicacion']?['valor'] as String?;
    if (valueString != null) {
      try {
        final coords = jsonDecode(valueString);
        final lat = coords['lat'] as double?;
        final lng = coords['lng'] as double?;
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      } catch (e) {
        print("Error decodificando coordenadas del depósito: $e");
      }
    }
    // Devuelve el valor por defecto si no se pudo cargar o decodificar
    print("Usando coordenadas de depósito por defecto.");
    return _defaultDepositoLatLng;
  }

  // --- Carga de Configuración ---
  // Flag para asegurar que la carga se haga una sola vez
  static bool _isLoaded = false;
  static bool _isLoading = false; // Para evitar cargas concurrentes

  // Método para cargar TODA la configuración (idealmente llamar al inicio de la app)
  static Future<void> cargarConfiguracionInicial() async {
    // Evita cargas múltiples
    if (_isLoaded || _isLoading) return;

    _isLoading = true;
    print("Iniciando carga de configuración..."); // Log

    try {
      // Llama al script PHP sin clave para obtener todas las configuraciones editables (o todas si prefieres)
      final response = await API
          .getAllConfiguraciones(); // Necesitas crear esta función en api.dart

      if (response['status'] == 'success' &&
          response['configuraciones'] is List) {
        final List configuraciones = response['configuraciones'];
        // Convierte la lista en un mapa usando 'clave' como key
        _configValues = {
          for (var config in configuraciones)
            if (config is Map<String, dynamic> && config['clave'] != null)
              config['clave']: config,
        };
        _isLoaded = true;
        print(
          "Configuración cargada exitosamente (${_configValues.length} valores).",
        ); // Log
      } else {
        print(
          "Respuesta inválida al cargar configuración: ${response['message'] ?? 'Formato incorrecto'}",
        ); // Log
        _configValues = {}; // Resetea por si acaso
      }
    } catch (e) {
      print("Error crítico al cargar la configuración inicial: $e"); // Log
      // Mantiene _isLoaded en false para posible reintento
      _configValues = {}; // Asegura que esté vacío en caso de error
    } finally {
      _isLoading = false;
    }
  }

  // Método para obtener un valor específico (con conversión opcional)
  static T? getValor<T>(String clave, {T? defaultValue}) {
    final config = _configValues[clave];
    if (config == null || config['valor'] == null) {
      print(
        "Advertencia: Configuración '$clave' no encontrada, usando default.",
      );
      return defaultValue;
    }

    String valorStr = config['valor'].toString();
    String? tipoDato = config['tipo_dato'] as String?;

    try {
      // Intenta convertir según el tipo_dato
      switch (tipoDato) {
        case 'integer':
          return int.tryParse(valorStr) as T? ?? defaultValue;
        case 'float':
          return double.tryParse(valorStr) as T? ?? defaultValue;
        case 'boolean':
          return (valorStr == '1' || valorStr.toLowerCase() == 'true') as T? ??
              defaultValue;
        case 'json_array':
        case 'json_object': // O podrías tener json_object
          return jsonDecode(valorStr) as T? ?? defaultValue;
        case 'enum_string':
        case 'string':
        default:
          return valorStr as T? ?? defaultValue;
      }
    } catch (e) {
      print(
        "Error convirtiendo configuración '$clave' (valor: '$valorStr', tipo: $tipoDato): $e",
      );
      return defaultValue;
    }
  }
}

// --- Extensión para API.dart (o crear la función directamente allí) ---
// Es mejor poner esto DENTRO de la clase API en api.dart

extension ConfiguracionAPI on API {
  static const String _endPoint = "https://149.50.143.81/cvrp/";
}
