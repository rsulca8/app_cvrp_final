// lib/screens/repartidor/ruta_pedido_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_geojson/flutter_map_geojson.dart'; // Para GeoJSON
import 'dart:convert';
import 'package:provider/provider.dart'; // Para obtener el ID del repartidor

import '../../models/pedido_model.dart';
import '../../api.dart';
import '../../auth_service.dart'; // Para obtener ID del repartidor
import '../../configuracion.dart'; // Para depósito

class RutaPedidoScreen extends StatefulWidget {
  static const routeName = '/repartidor/ruta';

  @override
  _RutaPedidoScreenState createState() => _RutaPedidoScreenState();
}

class _RutaPedidoScreenState extends State<RutaPedidoScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>?
  _rutaData; // Datos de la ruta (incluye 'ruta' y 'detalles')
  String _infoMessage = ''; // Para "No hay ruta asignada"

  // Estados del Mapa
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  LatLng _initialCenter = LatLng(-24.7891, -65.4106); // Salta Centro
  LatLngBounds? _routeBounds;
  final GeoJsonParser _geojsonParser = GeoJsonParser(
    defaultPolylineColor: chazkyGold.withAlpha(204),
    defaultPolylineStroke: 5.0,
  );
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Espera a que el widget esté construido para acceder al Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMiRuta();
    });
  }

  Future<void> _loadMiRuta() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _rutaData = null;
      _infoMessage = '';
      _markers = [];
      _polylines = [];
      _routeBounds = null;
    });

    try {
      // Obtiene el ID del repartidor logueado
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.userId == null) {
        throw Exception(
          "No se pudo identificar al repartidor. Vuelve a iniciar sesión.",
        );
      }

      // Llama a la nueva función API
      final response = await API.getMiRutaActiva(authService.userId!);
      if (!mounted) return;

      if (response['status'] == 'success') {
        if (response.containsKey('ruta') && response.containsKey('detalles')) {
          // ¡Ruta encontrada! Procesa los datos
          _rutaData = response;
          _processMapData(_rutaData!);
          _parseGeoJson(_rutaData!);
        } else {
          // No es un error, simplemente no hay ruta
          _infoMessage = response['message'] ?? 'No tienes una ruta asignada.';
        }
      } else {
        // Error reportado por el servidor
        throw Exception(response['message'] ?? 'Error al cargar la ruta.');
      }
    } catch (e) {
      if (mounted) {
        _error = "Error: ${e.toString().replaceFirst("Exception: ", "")}";
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // Centra el mapa si se cargaron datos
        if (_rutaData != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _fitMapToBounds(),
          );
        }
      }
    }
  }

  // --- Lógica de Mapa (Copiada de RutaDetalleScreen) ---

  void _processMapData(Map<String, dynamic> data) {
    if (data['ruta'] == null || data['detalles'] == null) return;
    final List<Marker> markers = [];
    LatLngBounds bounds = LatLngBounds(
      Configuracion.depositoLatLng,
      Configuracion.depositoLatLng,
    );
    markers.add(
      _buildMarker(
        Configuracion.depositoLatLng,
        'Depósito',
        Icons.storefront,
        Colors.blue,
      ),
    );

    final List detalles = data['detalles'] as List? ?? [];
    for (var detalle in detalles) {
      if (detalle is Map<String, dynamic>) {
        final lat = double.tryParse(detalle['lat']?.toString() ?? '');
        final lng = double.tryParse(detalle['lng']?.toString() ?? '');
        if (lat != null && lng != null) {
          final paradaCoords = LatLng(lat, lng);
          markers.add(
            _buildMarker(
              paradaCoords,
              '#${detalle['id_pedido']} - ${detalle['nombre_cliente'] ?? ''} ${detalle['apellido_cliente'] ?? ''}'
                  .trim(),
              Icons.location_pin,
              chazkyGold,
              detalle['orden_visita']?.toString(),
            ),
          );
          bounds.extend(paradaCoords);
        }
      }
    }
    setState(() {
      _markers = markers;
      _routeBounds = bounds;
      if (markers.length <= 1) _initialCenter = Configuracion.depositoLatLng;
    });
  }

  void _parseGeoJson(Map<String, dynamic> data) {
    final geometryData = data['ruta']?['geometria_geojson'];

    if (geometryData == null) {
      print("Advertencia: No se encontró geometría GeoJSON.");
      return;
    }

    try {
      Map<String, dynamic> geoJsonObject;

      // Convertir a Map si es String
      if (geometryData is String) {
        geoJsonObject = jsonDecode(geometryData);
      } else if (geometryData is Map<String, dynamic>) {
        geoJsonObject = geometryData;
      } else {
        throw FormatException("Formato inesperado para geometria_geojson");
      }

      print(
        "GeoJSON recibido: ${jsonEncode(geoJsonObject).substring(0, 200)}...",
      );

      // Extraer coordenadas según el tipo de GeoJSON
      List<LatLng> routePoints = [];

      if (geoJsonObject['type'] == 'FeatureCollection') {
        // FeatureCollection
        final features = geoJsonObject['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final geometry = features[0]['geometry'];
          routePoints = _extractCoordinates(geometry);
        }
      } else if (geoJsonObject['type'] == 'Feature') {
        // Feature único
        final geometry = geoJsonObject['geometry'];
        routePoints = _extractCoordinates(geometry);
      } else if (geoJsonObject['type'] == 'LineString') {
        // Geometría directa
        routePoints = _extractCoordinates(geoJsonObject);
      }

      if (routePoints.isEmpty) {
        print("Advertencia: No se pudieron extraer puntos de la ruta.");
        return;
      }

      print("Puntos de ruta extraídos: ${routePoints.length}");

      // Crear Polyline
      final polyline = Polyline(
        points: routePoints,
        color: chazkyGold.withOpacity(0.8),
        strokeWidth: 5.0,
      );

      // Actualizar bounds con los puntos de la ruta
      LatLngBounds? currentBounds = _routeBounds;
      for (final point in routePoints) {
        if (currentBounds == null) {
          currentBounds = LatLngBounds(point, point);
        } else {
          currentBounds.extend(point);
        }
      }

      setState(() {
        _polylines = [polyline];
        _routeBounds = currentBounds;
      });
    } catch (e) {
      print("Error parseando GeoJSON: $e");
      setState(() {
        _error = "Error al interpretar la forma de la ruta: $e";
      });
    }
  }

  List<LatLng> _extractCoordinates(Map<String, dynamic>? geometry) {
    if (geometry == null) return [];

    final type = geometry['type'];
    final coordinates = geometry['coordinates'];

    if (coordinates == null) return [];

    List<LatLng> points = [];

    if (type == 'LineString') {
      // LineString: [[lng, lat], [lng, lat], ...]
      for (var coord in coordinates) {
        if (coord is List && coord.length >= 2) {
          // GeoJSON usa [lng, lat], LatLng usa (lat, lng)
          final lng = (coord[0] is num)
              ? coord[0].toDouble()
              : double.tryParse(coord[0].toString());
          final lat = (coord[1] is num)
              ? coord[1].toDouble()
              : double.tryParse(coord[1].toString());

          if (lng != null && lat != null) {
            points.add(LatLng(lat, lng));
          }
        }
      }
    } else if (type == 'MultiLineString') {
      // MultiLineString: [[[lng, lat], ...], [[lng, lat], ...]]
      for (var line in coordinates) {
        for (var coord in line) {
          if (coord is List && coord.length >= 2) {
            final lng = (coord[0] is num)
                ? coord[0].toDouble()
                : double.tryParse(coord[0].toString());
            final lat = (coord[1] is num)
                ? coord[1].toDouble()
                : double.tryParse(coord[1].toString());

            if (lng != null && lat != null) {
              points.add(LatLng(lat, lng));
            }
          }
        }
      }
    }

    return points;
  }

  Marker _buildMarker(
    LatLng point,
    String tooltip,
    IconData iconData,
    Color color, [
    String? label,
  ]) {
    // ... (widget marcador idéntico al de ruta_detalle_screen) ...
    return Marker(
      width: label != null ? 40.0 : 30.0,
      height: label != null ? 40.0 : 30.0,
      point: point,
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tooltip), duration: Duration(seconds: 2)),
        ),
        child: Tooltip(
          message: tooltip,
          textStyle: TextStyle(fontSize: 12, color: primaryDarkBlue),
          decoration: BoxDecoration(
            color: chazkyWhite.withAlpha(230),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(iconData, color: color, size: label != null ? 35.0 : 30.0),
              if (label != null)
                Positioned(
                  top: 5,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: primaryDarkBlue.withAlpha(178),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: chazkyWhite,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _fitMapToBounds() {
    // ... (lógica de centrado idéntica) ...
    if (!mounted) return;
    if (_routeBounds != null) {
      Future.delayed(Duration(milliseconds: 150), () {
        if (mounted) {
          try {
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: _routeBounds!,
                padding: EdgeInsets.all(50.0),
              ),
            );
          } catch (e) {
            print("Error en fitCamera: $e");
            if (_markers.isNotEmpty)
              _mapController.move(_markers.first.point, 14.0);
          }
        }
      });
    } else if (_markers.isNotEmpty) {
      _mapController.move(_markers.first.point, 14.0);
    } else {
      _mapController.move(_initialCenter, 13.0);
    }
  }

  // --- Fin Lógica de Mapa ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Hereda gradiente del HomeScreen
      body: _isLoading
          ? _buildLoading() // Widget de Carga
          : _error != null
          ? _buildErrorWidget(_error!) // Widget de Error
          : _rutaData == null
          ? _buildNoRouteWidget(_infoMessage) // Widget "Sin Ruta"
          : _buildRouteView(), // Widget principal con Mapa y Lista
    );
  }

  // --- Widgets de Estado ---
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
          ),
          SizedBox(height: 16),
          Text(
            'Buscando ruta asignada...',
            style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String errorMsg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            SizedBox(height: 15),
            Text(
              errorMsg,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: chazkyWhite.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 25),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Reintentar'),
              onPressed: _loadMiRuta, // Llama a recargar
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumDarkBlue,
                foregroundColor: chazkyWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRouteWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              color: chazkyWhite.withOpacity(0.5),
              size: 80,
            ),
            SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: chazkyWhite.withOpacity(0.7),
                fontSize: 20,
                fontFamily: 'Montserrat',
              ),
            ),
            SizedBox(height: 25),
            ElevatedButton.icon(
              // Botón para reintentar
              icon: Icon(Icons.refresh),
              label: Text('Actualizar'),
              onPressed: _loadMiRuta,
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumDarkBlue,
                foregroundColor: chazkyWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // --- Fin Widgets de Estado ---

  // Widget principal que muestra Mapa y Lista
  Widget _buildRouteView() {
    final Map<String, dynamic> rutaInfo =
        _rutaData!['ruta'] as Map<String, dynamic>;
    final List paradas = _rutaData!['detalles'] as List? ?? [];

    return Column(
      children: [
        // --- MAPA ---
        Expanded(
          flex: 2, // El mapa ocupa 2/3 de la pantalla
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13.0,
              onMapReady: _fitMapToBounds, // Centra el mapa cuando esté listo
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
                userAgentPackageName: 'com.chazky.app', // USA TU package name
              ),
              // Ruta
              if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
              // Marcadores
              if (_markers.isNotEmpty) MarkerLayer(markers: _markers),
            ],
          ),
        ),
        // --- RESUMEN DE RUTA ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: primaryDarkBlue.withOpacity(0.9),
            border: Border(top: BorderSide(color: Colors.white24, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paradas: ${paradas.length}',
                style: TextStyle(
                  color: chazkyWhite,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Estimado: ${Ruta.fromJson(rutaInfo).distanciaFormateada} / ${Ruta.fromJson(rutaInfo).duracionFormateada}',
                style: TextStyle(
                  color: chazkyWhite.withOpacity(0.8),
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
        ),
        // --- LISTA DE PARADAS ---
        Expanded(
          flex: 1, // La lista ocupa 1/3 de la pantalla
          child: ListView.builder(
            itemCount: paradas.length,
            itemBuilder: (context, index) {
              final parada = paradas[index] as Map<String, dynamic>;
              final orden = parada['orden_visita']?.toString() ?? '?';
              final nombre =
                  '${parada['nombre_cliente'] ?? ''} ${parada['apellido_cliente'] ?? ''}'
                      .trim();
              final direccion = parada['direccion_entrega'] ?? 'N/A';
              // TODO: Implementar lógica de estado de parada (Entregado, No Entregado)
              final bool isCompletado = false; // Placeholder

              return Card(
                color: isCompletado
                    ? mediumDarkBlue.withOpacity(0.2)
                    : mediumDarkBlue.withOpacity(0.5),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.white24, width: 0.5),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCompletado ? Colors.grey : chazkyGold,
                    child: Text(
                      orden,
                      style: TextStyle(
                        color: isCompletado ? Colors.white54 : primaryDarkBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    nombre,
                    style: TextStyle(
                      color: chazkyWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    direccion,
                    style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TODO: Implementar botones de acción
                      IconButton(
                        icon: Icon(
                          Icons.check_circle_outline,
                          color: Colors.greenAccent,
                        ),
                        onPressed: () {
                          /* TODO: Marcar como Entregado */
                        },
                        tooltip: 'Marcar como Entregado',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.cancel_outlined,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          /* TODO: Marcar como No Entregado (abrir diálogo) */
                        },
                        tooltip: 'Marcar como No Entregado',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
