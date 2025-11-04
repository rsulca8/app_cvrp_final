// lib/screens/admin/ruta_detalle_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:intl/intl.dart'; // Import para formatear fecha

import '../../models/pedido_model.dart';
import '../../api.dart';

// Clase de Configuración (Placeholder, asegúrate de que esté disponible)
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

  // Estado para las paradas
  List<Map<String, dynamic>> _paradas = [];

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
      _paradas = [];
    });

    try {
      _rutaData = await API.getDetallesRuta(widget.rutaId);
      if (!mounted) return;
      if (_rutaData!['status'] == 'success') {
        _paradas = List<Map<String, dynamic>>.from(
          _rutaData!['detalles'] as List? ?? [],
        );
        _processMapData(_rutaData!);
        _parseGeoJson(_rutaData!);
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToBounds());
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
    if (data['ruta'] == null || _paradas.isEmpty) {
      print("Advertencia: Faltan datos 'ruta' o 'detalles'.");
      return;
    }
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
        null,
        () => _showPedidoDetails(null, isDeposito: true),
      ),
    );
    for (var detalle in _paradas) {
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
              () => _showPedidoDetails(detalle),
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
      if (geometryData is String) {
        geoJsonObject = jsonDecode(geometryData);
      } else if (geometryData is Map<String, dynamic>) {
        geoJsonObject = geometryData;
      } else {
        throw FormatException("Formato inesperado");
      }

      List<LatLng> routePoints = _extractCoordinates(geoJsonObject);
      if (routePoints.isEmpty) {
        print("Advertencia: No se pudieron extraer puntos.");
        return;
      }

      LatLng? lastStopLatLng;
      if (_paradas.isNotEmpty) {
        final lastStopData = _paradas.last;
        final lat = double.tryParse(lastStopData['lat']?.toString() ?? '');
        final lng = double.tryParse(lastStopData['lng']?.toString() ?? '');
        if (lat != null && lng != null) lastStopLatLng = LatLng(lat, lng);
      }
      List<Polyline> polylines = [];
      int splitIndex = -1;
      if (lastStopLatLng != null) {
        final distance = Distance();
        double minDistance = double.infinity;
        for (int i = 0; i < routePoints.length; i++) {
          final d = distance.as(
            LengthUnit.Meter,
            routePoints[i],
            lastStopLatLng,
          );
          if (d < minDistance) {
            minDistance = d;
            splitIndex = i;
          }
        }
      }
      if (splitIndex == -1 || splitIndex >= routePoints.length - 1) {
        polylines.add(
          Polyline(
            points: routePoints,
            color: chazkyGold.withOpacity(0.8),
            strokeWidth: 5.0,
          ),
        );
      } else {
        polylines.add(
          Polyline(
            points: routePoints.sublist(0, splitIndex + 1),
            color: chazkyGold.withOpacity(0.8),
            strokeWidth: 5.0,
          ),
        );
        polylines.add(
          Polyline(
            points: routePoints.sublist(splitIndex),
            color: Colors.grey.withOpacity(0.7),
            strokeWidth: 4.0,
            pattern: StrokePattern.dotted(),
          ),
        );
      }

      LatLngBounds? currentBounds = _routeBounds;
      for (final point in routePoints) {
        if (currentBounds == null) {
          currentBounds = LatLngBounds(point, point);
        } else {
          currentBounds.extend(point);
        }
      }
      setState(() {
        _polylines = polylines;
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
      for (var coord in coordinates) {
        if (coord is List && coord.length >= 2) {
          final lng = (coord[0] is num)
              ? coord[0].toDouble()
              : double.tryParse(coord[0].toString());
          final lat = (coord[1] is num)
              ? coord[1].toDouble()
              : double.tryParse(coord[1].toString());
          if (lng != null && lat != null) points.add(LatLng(lat, lng));
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
            if (lng != null && lat != null) points.add(LatLng(lat, lng));
          }
        }
      }
    } else if (type == 'Feature') {
      return _extractCoordinates(geometry['geometry']);
    } else if (type == 'FeatureCollection') {
      final features = geometry['features'] as List?;
      if (features != null) {
        for (var feature in features) {
          if (feature is Map<String, dynamic>) {
            points.addAll(_extractCoordinates(feature['geometry']));
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
    VoidCallback? onTap,
  ]) {
    return Marker(
      width: label != null ? 40.0 : 30.0,
      height: label != null ? 40.0 : 30.0,
      point: point,
      child: GestureDetector(
        onTap:
            onTap ??
            () => ScaffoldMessenger.of(context).showSnackBar(
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

  // --- Popup de Detalles del Pedido (Actualizado) ---
  void _showPedidoDetails(
    Map<String, dynamic>? parada, {
    bool isDeposito = false,
  }) {
    if (isDeposito || parada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Este es el punto de inicio/fin (Depósito).'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final String idPedido = parada['id_pedido']?.toString() ?? '0';
    final String nombreCliente =
        '${parada['nombre_cliente'] ?? ''} ${parada['apellido_cliente'] ?? ''}'
            .trim();
    final String direccion = parada['direccion_entrega'] ?? 'N/A';

    // --- Obtiene el estado de la parada desde los datos ya pasados ---
    // (El PHP de `get_ruta_detalle` ahora incluye esta info en `detalles`)
    final String estadoParada = parada['estado_parada'] ?? 'Pendiente';
    final String? motivoFallo = parada['motivo_fallo'] as String?;
    // --- Fin ---

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: API.getPedidoDetalles(idPedido),
          builder: (context, snapshot) {
            Widget content;
            if (snapshot.connectionState == ConnectionState.waiting) {
              content = Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: chazkyGold),
                      SizedBox(height: 16),
                      Text(
                        'Cargando productos del pedido #$idPedido...',
                        style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              content = Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'Error al cargar detalles: ${snapshot.error}',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            } else if (!snapshot.hasData ||
                snapshot.data!['status'] != 'success' ||
                snapshot.data!['detalles'] == null) {
              content = Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No se encontraron productos para este pedido.',
                    style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
                  ),
                ),
              );
            } else {
              // Contenido Exitoso (Lista de Productos)
              final List detallesProducto =
                  snapshot.data!['detalles'] as List? ?? [];
              double totalPedido = 0.0;
              for (var item in detallesProducto) {
                totalPedido +=
                    (double.tryParse(
                          item['precio_unitario']?.toString() ?? '0.0',
                        ) ??
                        0.0) *
                    (int.tryParse(item['cantidad']?.toString() ?? '0') ?? 0);
              }
              content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado del pedido
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalle del Pedido #${idPedido}',
                          style: TextStyle(
                            color: chazkyGold,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          nombreCliente,
                          style: TextStyle(color: chazkyWhite, fontSize: 16),
                        ),
                        Text(
                          direccion,
                          style: TextStyle(
                            color: chazkyWhite.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Total del Pedido: \$${totalPedido.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: chazkyWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // --- ¡NUEVO! Widget de Estado de Entrega ---
                  _buildStatusInfo(estadoParada, motivoFallo),
                  // --- Fin Nuevo ---
                  Divider(color: Colors.white24, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Productos:",
                      style: TextStyle(
                        color: chazkyWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  // Lista de productos
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: detallesProducto.length,
                      itemBuilder: (context, index) {
                        final item = detallesProducto[index];
                        final nombreProd =
                            item['nombre_producto'] ?? 'Producto desconocido';
                        final marcaProd = item['marca_producto'] ?? 'Sin marca';
                        final cantidad = item['cantidad']?.toString() ?? '?';
                        final precioUnit =
                            double.tryParse(
                              item['precio_unitario']?.toString() ?? '0.0',
                            ) ??
                            0.0;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: mediumDarkBlue,
                            child: Text(
                              cantidad,
                              style: TextStyle(
                                color: chazkyGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            nombreProd,
                            style: TextStyle(color: chazkyWhite),
                          ),
                          subtitle: Text(
                            marcaProd,
                            style: TextStyle(
                              color: chazkyWhite.withOpacity(0.7),
                            ),
                          ),
                          trailing: Text(
                            '\$${(precioUnit * int.parse(cantidad)).toStringAsFixed(2)}',
                            style: TextStyle(color: chazkyWhite, fontSize: 14),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }
            // Contenedor principal del BottomSheet
            return Container(
              height:
                  MediaQuery.of(context).size.height * 0.75, // Un poco más alto
              decoration: BoxDecoration(
                color: primaryDarkBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 6,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: mediumDarkBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Expanded(child: content),
                ],
              ),
            );
          },
        );
      },
    );
  }
  // --- Fin Función Popup ---

  @override
  Widget build(BuildContext context) {
    // ... (build
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
          foregroundColor: chazkyWhite,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: chazkyWhite),
            tooltip: 'Ver Todas las Rutas',
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: chazkyWhite),
              tooltip: 'Recargar',
              onPressed: _isLoading ? null : _loadRutaDetails,
            ),
            IconButton(
              icon: Icon(
                Icons.center_focus_strong_outlined,
                color: chazkyWhite,
              ),
              tooltip: 'Centrar Mapa',
              onPressed:
                  _isLoading || (_routeBounds == null && _markers.isEmpty)
                  ? null
                  : _fitMapToBounds,
            ),
          ],
        ),
        body: _isLoading
            ? _buildLoading()
            : _error != null
            ? _buildErrorWidget(_error!)
            : _rutaData == null || rutaInfo == null
            ? _buildNoDataWidget()
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
                    child: _buildRutaInfoPanel(
                      rutaInfo,
                      repartidorNombre,
                      estadoRuta,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Paradas (${_paradas.length})',
                      style: TextStyle(
                        color: chazkyGold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                  Expanded(flex: 2, child: _buildParadasList()),
                ],
              ),
      ),
    );
  }

  // --- Widgets de Estado (Sin cambios) ---
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
            'Cargando ruta...',
            style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String errorMsg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
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
    );
  }

  Widget _buildNoDataWidget() {
    return Center(
      child: Text(
        'No se encontraron datos.',
        style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
      ),
    );
  }
  // --- Fin Widgets de Estado ---

  // Panel de info de ruta
  Widget _buildRutaInfoPanel(
    Map<String, dynamic> rutaInfo,
    String repartidorNombre,
    String estadoRuta,
  ) {
    return Column(
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
                  style: TextStyle(color: chazkyWhite.withOpacity(0.8)),
                ),
              ],
            ),
            if (rutaInfo['distancia_total_metros'] != null)
              Row(
                children: [
                  Icon(Icons.route, color: chazkyGold, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '${Ruta.fromJson(rutaInfo).distanciaFormateada} / ${Ruta.fromJson(rutaInfo).duracionFormateada}',
                    style: TextStyle(color: chazkyWhite.withOpacity(0.8)),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // Lista de paradas
  Widget _buildParadasList() {
    final List paradas = _paradas;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      itemCount: paradas.length,
      itemBuilder: (context, index) {
        final parada = paradas[index] as Map<String, dynamic>;
        final String estadoParada = parada['estado_parada'] ?? 'Pendiente';
        final String? motivoFallo = parada['motivo_fallo'] as String?;
        final String orden = parada['orden_visita']?.toString() ?? '?';
        final String nombre =
            '${parada['nombre_cliente'] ?? ''} ${parada['apellido_cliente'] ?? ''}'
                .trim();
        final String direccion = parada['direccion_entrega'] ?? 'N/A';

        bool isPendiente = estadoParada == 'Pendiente';
        bool isCompletado = estadoParada == 'Entregado';
        bool isFallido = estadoParada == 'No Entregado';
        double opacity = isPendiente ? 1.0 : 0.6;

        return Opacity(
          opacity: opacity,
          child: Card(
            color: isCompletado
                ? Colors.green[900]?.withOpacity(0.3)
                : (isFallido
                      ? Colors.red[900]?.withOpacity(0.3)
                      : mediumDarkBlue.withOpacity(0.5)),
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isPendiente
                    ? chazkyGold
                    : (isCompletado ? Colors.green : Colors.redAccent[700]!),
                width: isPendiente ? 1.0 : 0.5,
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isPendiente
                    ? chazkyGold
                    : (isCompletado ? Colors.green : Colors.redAccent),
                child: Text(
                  orden,
                  style: TextStyle(
                    color: isPendiente ? primaryDarkBlue : chazkyWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                nombre,
                style: TextStyle(
                  color: chazkyWhite,
                  fontWeight: FontWeight.bold,
                  decoration: isFallido ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                isFallido ? "FALLIDO: $motivoFallo" : direccion,
                style: TextStyle(
                  color: isFallido
                      ? Colors.redAccent[100]
                      : chazkyWhite.withOpacity(0.7),
                  fontWeight: isFallido ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _buildTrailingAction(parada, estadoParada),
            ),
          ),
        );
      },
    );
  }

  // --- ¡NUEVO! Helper para la barra de estado en el popup ---
  Widget _buildStatusInfo(String estado, String? motivo) {
    IconData icon;
    Color color;
    String text;

    switch (estado) {
      case 'Entregado':
        icon = Icons.check_circle;
        color = Colors.greenAccent[400]!;
        text = 'Entregado';
        break;
      case 'No Entregado':
        icon = Icons.error;
        color = Colors.redAccent[400]!;
        text = 'Fallido: ${motivo ?? "Sin motivo."}';
        break;
      default: // Pendiente
        icon = Icons.pending_actions_outlined;
        color = chazkyGold;
        text = 'Pendiente de Entrega';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), // Fondo sutil
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: chazkyWhite,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
        ],
      ),
    );
  }
  // --- Fin Nuevo ---

  // Botones de acción para el admin (solo lupa)
  Widget _buildTrailingAction(Map<String, dynamic> parada, String estado) {
    // Botón de Lupa
    Widget detailsButton = IconButton(
      icon: Icon(Icons.search, color: chazkyWhite.withOpacity(0.7)),
      onPressed: () => _showPedidoDetails(parada), // Llama al popup
      tooltip: 'Ver Detalles del Pedido',
    );

    switch (estado) {
      case 'Entregado':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            detailsButton,
            Icon(Icons.check_circle, color: Colors.greenAccent[400], size: 28),
          ],
        );
      case 'No Entregado':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            detailsButton,
            Icon(Icons.error, color: Colors.redAccent[400], size: 28),
          ],
        );
      case 'Pendiente':
      default:
        return detailsButton; // El Admin solo ve el botón de detalles
    }
  }
}
