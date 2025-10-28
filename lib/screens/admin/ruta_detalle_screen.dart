// lib/screens/admin/ruta_detalle_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import '../../models/pedido_model.dart';
import '../../api.dart';

class Configuracion {
  static LatLng get depositoLatLng {
    return LatLng(-24.789100, -65.410600);
  }
}

class RutaDetalleScreen extends StatefulWidget {
  static const routeName = '/admin/ruta-detalle';
  final String rutaId;

  const RutaDetalleScreen({required this.rutaId, super.key});

  @override
  RutaDetalleScreenState createState() => RutaDetalleScreenState();
}

class RutaDetalleScreenState extends State<RutaDetalleScreen> {
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _rutaData;

  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  LatLng _initialCenter = LatLng(-24.7891, -65.4106);
  LatLngBounds? _routeBounds;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadRutaDetails();
  }

  Future<void> _loadRutaDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _markers = [];
      _polylines = [];
      _routeBounds = null;
    });

    try {
      _rutaData = await API.getDetallesRuta(widget.rutaId);

      if (!mounted) return;

      if (_rutaData!['status'] == 'success') {
        _processMapData(_rutaData!);
        _parseGeoJson(_rutaData!);

        setState(() {
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitMapToBounds();
        });
      } else {
        throw Exception(
          _rutaData!['message'] ?? 'Error desconocido al cargar ruta.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error =
              "Error al cargar: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  void _processMapData(Map<String, dynamic> data) {
    if (data['ruta'] == null || data['detalles'] == null) {
      print(
        "Advertencia: Faltan datos 'ruta' o 'detalles' en la respuesta de API.",
      );
      return;
    }

    final List<Marker> markers = [];
    LatLngBounds? bounds;

    final LatLng depositoCoords = Configuracion.depositoLatLng;
    markers.add(
      _buildMarker(depositoCoords, 'Depósito', Icons.storefront, Colors.blue),
    );
    bounds = LatLngBounds(depositoCoords, depositoCoords);

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
      if (markers.length <= 1) _initialCenter = depositoCoords;
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
    return Marker(
      width: label != null ? 40.0 : 30.0,
      height: label != null ? 40.0 : 30.0,
      point: point,
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tooltip), duration: Duration(seconds: 2)),
          );
        },
        child: Tooltip(
          message: tooltip,
          textStyle: TextStyle(fontSize: 12, color: primaryDarkBlue),
          decoration: BoxDecoration(
            color: chazkyWhite.withOpacity(0.9),
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
                      color: primaryDarkBlue.withOpacity(0.7),
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
    if (!mounted) return;

    if (_routeBounds != null) {
      Future.delayed(Duration(milliseconds: 200), () {
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
            if (_markers.isNotEmpty) {
              _mapController.move(_markers.first.point, 14.0);
            }
          }
        }
      });
    } else if (_markers.isNotEmpty) {
      _mapController.move(_markers.first.point, 14.0);
    } else {
      _mapController.move(_initialCenter, 13.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? rutaInfo =
        _rutaData?['ruta'] as Map<String, dynamic>?;
    final String repartidorNombre = rutaInfo != null
        ? '${rutaInfo['repartidor_nombre'] ?? ''} ${rutaInfo['repartidor_apellido'] ?? ''}'
              .trim()
        : 'N/A';
    final String estadoRuta = rutaInfo?['estado_ruta'] ?? 'Desconocido';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [mediumDarkBlue, primaryDarkBlue],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Detalle Ruta #${widget.rutaId}',
            style: TextStyle(fontFamily: 'Montserrat', color: chazkyWhite),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            tooltip: 'Ver Todas las Rutas',
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: _isLoading ? null : _loadRutaDetails,
            ),
            IconButton(
              icon: Icon(Icons.center_focus_strong_outlined),
              tooltip: 'Centrar Mapa',
              onPressed:
                  _isLoading || (_routeBounds == null && _markers.isEmpty)
                  ? null
                  : _fitMapToBounds,
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Cargando ruta...',
                      style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
                    ),
                  ],
                ),
              )
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRutaDetails,
                        child: Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : _rutaData == null || rutaInfo == null
            ? Center(
                child: Text(
                  'No se encontraron datos.',
                  style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _initialCenter,
                        initialZoom: 13.0,
                        onMapReady: _fitMapToBounds,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: ['a', 'b', 'c'],
                          userAgentPackageName: 'com.chazky.app',
                        ),
                        if (_polylines.isNotEmpty)
                          PolylineLayer(polylines: _polylines),
                        if (_markers.isNotEmpty) MarkerLayer(markers: _markers),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: primaryDarkBlue.withOpacity(0.9),
                      border: Border(
                        top: BorderSide(color: Colors.white24, width: 0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: chazkyGold, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Repartidor: $repartidorNombre',
                                style: TextStyle(
                                  color: chazkyWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.flag, color: chazkyGold, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Estado: $estadoRuta',
                                  style: TextStyle(
                                    color: chazkyWhite.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                            if (rutaInfo['distancia_total_metros'] != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.route,
                                    color: chazkyGold,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '${Ruta.fromJson(rutaInfo).distanciaFormateada} / ${Ruta.fromJson(rutaInfo).duracionFormateada}',
                                    style: TextStyle(
                                      color: chazkyWhite.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Paradas: ${_markers.length - 1}',
                          style: TextStyle(
                            color: chazkyWhite.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
