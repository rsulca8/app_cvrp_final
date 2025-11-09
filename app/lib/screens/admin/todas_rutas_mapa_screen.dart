// lib/screens/admin/todas_rutas_mapa_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:math';
import '../../models/pedido_model.dart';
import '../../api.dart';
import '../../configuracion.dart';

class TodasRutasMapaScreen extends StatefulWidget {
  static const routeName = '/admin/mapa-rutas';
  const TodasRutasMapaScreen({super.key});

  @override
  _TodasRutasMapaScreenState createState() => _TodasRutasMapaScreenState();
}

class _TodasRutasMapaScreenState extends State<TodasRutasMapaScreen> {
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  bool _isLoading = true;
  String? _error;
  List<Ruta> _rutas = [];

  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  LatLngBounds? _mapBounds;
  final MapController _mapController = MapController();
  final Random _random = Random();

  // Para la leyenda
  Map<int, Color> _rutaColors = {}; // id_ruta -> color

  @override
  void initState() {
    super.initState();
    _loadAllRoutes();
  }

  Future<void> _loadAllRoutes() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _polylines = [];
      _markers = [];
      _mapBounds = null;
      _rutaColors = {};
    });

    try {
      final rutasData = await API.getRutasAsignadas();
      if (!mounted) return;

      final List<Ruta> loadedRutas = rutasData
          .where((r) => r is Map<String, dynamic>)
          .map((r) => Ruta.fromJson(r as Map<String, dynamic>))
          .toList();

      _rutas = loadedRutas;
      _processAllRoutesForMap();

      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToBounds());
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error =
              "Error al cargar rutas: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  void _processAllRoutesForMap() {
    final List<Polyline> allPolylines = [];
    final List<Marker> allMarkers = [];
    LatLngBounds? combinedBounds;

    // Marcador del depósito
    final LatLng depositoCoords = Configuracion.depositoLatLng;
    allMarkers.add(
      _buildMarker(depositoCoords, 'Depósito', Icons.storefront, Colors.blue),
    );
    combinedBounds = LatLngBounds(depositoCoords, depositoCoords);

    int rutasConGeometria = 0;
    int rutasSinGeometria = 0;

    for (int i = 0; i < _rutas.length; i++) {
      final ruta = _rutas[i];
      final geometryData = ruta.geometriaGeojson;

      if (geometryData == null) {
        print("Ruta ${ruta.idRuta}: Sin geometría");
        rutasSinGeometria++;
        continue;
      }

      try {
        Map<String, dynamic> geoJsonObject;

        // Convertir a Map si es String
        if (geometryData is String) {
          if (geometryData.isEmpty) {
            print("Ruta ${ruta.idRuta}: Geometría vacía");
            rutasSinGeometria++;
            continue;
          }
          geoJsonObject = jsonDecode(geometryData);
        } else if (geometryData is Map<String, dynamic>) {
          geoJsonObject = geometryData;
        } else {
          print("Ruta ${ruta.idRuta}: Formato inesperado");
          rutasSinGeometria++;
          continue;
        }

        // Extraer coordenadas
        List<LatLng> routePoints = _extractCoordinates(geoJsonObject);

        if (routePoints.isEmpty) {
          print("Ruta ${ruta.idRuta}: No se pudieron extraer puntos");
          rutasSinGeometria++;
          continue;
        }

        // Generar color único para esta ruta
        final routeColor = _getDistinctColor(i);
        _rutaColors[int.parse(ruta.idRuta)] = routeColor;

        // Crear Polyline
        final polyline = Polyline(
          points: routePoints,
          color: routeColor.withOpacity(0.8),
          strokeWidth: 4.0,
        );
        allPolylines.add(polyline);

        // Extender bounds
        for (final point in routePoints) {
          combinedBounds?.extend(point);
        }

        rutasConGeometria++;
        print("Ruta ${ruta.idRuta}: ${routePoints.length} puntos procesados");
      } catch (e) {
        print("Error parseando GeoJSON para ruta ${ruta.idRuta}: $e");
        rutasSinGeometria++;
      }
    }

    print(
      "Resumen: $rutasConGeometria rutas con geometría, $rutasSinGeometria sin geometría",
    );
    print("Total de polilíneas generadas: ${allPolylines.length}");

    setState(() {
      _polylines = allPolylines;
      _markers = allMarkers;
      _mapBounds = combinedBounds;
    });
  }

  List<LatLng> _extractCoordinates(Map<String, dynamic>? geometry) {
    if (geometry == null) return [];

    final type = geometry['type'];
    final coordinates = geometry['coordinates'];

    if (coordinates == null) return [];

    List<LatLng> points = [];

    if (type == 'LineString') {
      for (var coord in coordinates) {
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
    } else if (type == 'MultiLineString') {
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
    } else if (type == 'Feature') {
      // Si es un Feature, extraer la geometría
      return _extractCoordinates(geometry['geometry']);
    } else if (type == 'FeatureCollection') {
      // Si es FeatureCollection, procesar todas las features
      final features = geometry['features'] as List?;
      if (features != null && features.isNotEmpty) {
        for (var feature in features) {
          points.addAll(_extractCoordinates(feature['geometry']));
        }
      }
    }

    return points;
  }

  // Genera colores distintos para cada ruta (mejor que aleatorio)
  Color _getDistinctColor(int index) {
    // Usa el modelo HSV para generar colores bien distribuidos
    final hue = (index * 137.5) % 360; // Número dorado para buena distribución
    return HSVColor.fromAHSV(1.0, hue, 0.7, 0.9).toColor();
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
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tooltip), duration: Duration(seconds: 2)),
        ),
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

    if (_mapBounds != null) {
      Future.delayed(Duration(milliseconds: 200), () {
        if (mounted) {
          try {
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: _mapBounds!,
                padding: EdgeInsets.all(40.0),
              ),
            );
          } catch (e) {
            print("Error en fitCamera: $e");
            _mapController.move(
              _markers.isNotEmpty
                  ? _markers.first.point
                  : Configuracion.depositoLatLng,
              13.0,
            );
          }
        }
      });
    } else {
      _mapController.move(Configuracion.depositoLatLng, 13.0);
    }
  }

  void _showLegend() {
    showModalBottomSheet(
      context: context,
      backgroundColor: primaryDarkBlue,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Leyenda de Rutas',
                  style: TextStyle(
                    color: chazkyWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: chazkyWhite),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _rutas.length,
                itemBuilder: (context, index) {
                  final ruta = _rutas[index];
                  final color = _rutaColors[ruta.idRuta];

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 4,
                      color: color ?? Colors.grey,
                    ),
                    title: Text(
                      'Ruta #${ruta.idRuta}',
                      style: TextStyle(color: chazkyWhite),
                    ),
                    subtitle: Text(
                      '${ruta.repartidorNombre ?? 'Sin asignar'} - ${ruta.estadoRuta}',
                      style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
                    ),
                    trailing: Text(
                      ruta.distanciaFormateada,
                      style: TextStyle(color: chazkyGold),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            'Mapa General de Rutas',
            style: TextStyle(color: chazkyWhite),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: chazkyWhite,
          actions: [
            if (_rutas.isNotEmpty)
              IconButton(
                icon: Icon(Icons.list, color: chazkyWhite),
                tooltip: 'Ver Leyenda',
                onPressed: _showLegend,
              ),
            IconButton(
              icon: Icon(
                Icons.center_focus_strong_outlined,
                color: chazkyWhite,
              ),
              tooltip: 'Centrar Mapa',
              onPressed: _isLoading || _mapBounds == null
                  ? null
                  : _fitMapToBounds,
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: chazkyWhite),
              tooltip: 'Recargar Rutas',
              onPressed: _isLoading ? null : _loadAllRoutes,
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
                      'Cargando rutas...',
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
                        onPressed: _loadAllRoutes,
                        child: Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: Configuracion.depositoLatLng,
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
                  // Contador de rutas en pantalla
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: primaryDarkBlue.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: chazkyGold, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route, color: chazkyGold, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '${_polylines.length} ruta${_polylines.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              color: chazkyWhite,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
