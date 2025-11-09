// lib/screens/repartidor/ruta_pedido_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// import 'package:flutter_map_geojson/flutter_map_geojson.dart'; // No se usa
import 'dart:convert';
import 'package:provider/provider.dart'; // Para obtener el ID del repartidor
import 'package:intl/intl.dart'; // Para formatear fecha

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
  List<Polyline> _polylines = []; // Ahora poblado por _parseGeoJson
  LatLng _initialCenter = LatLng(-24.7891, -65.4106); // Salta Centro
  LatLngBounds? _routeBounds;

  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _paradas = [];
  bool _isUpdatingParada = false; // Loader para botones de acción

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
      _paradas = [];
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
          _paradas = List<Map<String, dynamic>>.from(
            response['detalles'] as List? ?? [],
          );
          _processMapData(_rutaData!); // Procesa marcadores
          _parseGeoJson(_rutaData!); // Procesa polilínea
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

  // --- Lógica de Estado de Parada (Marcar Entregado / No Entregado) ---

  Future<void> _marcarEntregado(String idRutaDetalle) async {
    if (_isUpdatingParada) return;
    setState(() => _isUpdatingParada = true);
    try {
      final response = await API.actualizarEstadoParada(
        idRutaDetalle,
        'Entregado',
      );
      if (!mounted) return;
      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Parada marcada como Entregada.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          final index = _paradas.indexWhere(
            (p) => p['id_ruta_detalle'].toString() == idRutaDetalle,
          );
          if (index != -1) _paradas[index]['estado_parada'] = 'Entregado';
        });
      } else {
        throw Exception(response['message'] ?? 'Error del servidor.');
      }
    } catch (e) {
      if (mounted)
        _showErrorDialog(
          "Error al actualizar: ${e.toString().replaceFirst("Exception: ", "")}",
        );
    } finally {
      if (mounted) setState(() => _isUpdatingParada = false);
    }
  }

  Future<void> _mostrarDialogoNoEntregado(String idRutaDetalle) async {
    if (_isUpdatingParada) return;
    String? motivo;
    final motivoController = TextEditingController();

    final bool? confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: mediumDarkBlue,
        title: Text(
          'Reportar Falla en Entrega',
          style: TextStyle(color: chazkyWhite),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingresa el motivo por el cual no se pudo completar la entrega.',
              style: TextStyle(color: chazkyWhite.withOpacity(0.8)),
            ),
            SizedBox(height: 16),
            TextField(
              controller: motivoController,
              style: TextStyle(color: chazkyWhite),
              decoration: InputDecoration(
                labelText: 'Motivo (requerido)',
                labelStyle: TextStyle(color: chazkyWhite.withOpacity(0.5)),
                filled: true,
                fillColor: primaryDarkBlue.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: chazkyGold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            child: Text(
              'Confirmar Falla',
              style: TextStyle(color: Colors.white),
            ), // Texto blanco
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent[700],
            ),
            onPressed: () {
              if (motivoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text("El motivo es requerido."),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              motivo = motivoController.text.trim();
              Navigator.of(ctx).pop(true);
            },
          ),
        ],
      ),
    );

    if (confirmado == true && motivo != null) {
      setState(() => _isUpdatingParada = true);
      try {
        final response = await API.actualizarEstadoParada(
          idRutaDetalle,
          'No Entregado',
          motivo: motivo,
        );
        if (!mounted) return;
        if (response['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Parada marcada como No Entregada.',
              ),
              backgroundColor: Colors.orange[800],
            ),
          );
          setState(() {
            final index = _paradas.indexWhere(
              (p) => p['id_ruta_detalle'].toString() == idRutaDetalle,
            );
            if (index != -1) {
              _paradas[index]['estado_parada'] = 'No Entregado';
              _paradas[index]['motivo_fallo'] = motivo;
            }
          });
        } else {
          throw Exception(response['message'] ?? 'Error del servidor.');
        }
      } catch (e) {
        if (mounted)
          _showErrorDialog(
            "Error al actualizar: ${e.toString().replaceFirst("Exception: ", "")}",
          );
      } finally {
        if (mounted) setState(() => _isUpdatingParada = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // --- Lógica de Mapa ---
  void _processMapData(Map<String, dynamic> data) {
    if (data['ruta'] == null || _paradas.isEmpty) return;
    final List<Marker> markers = [];
    LatLngBounds bounds = LatLngBounds(
      Configuracion.depositoLatLng,
      Configuracion.depositoLatLng,
    );
    // Marcador del Depósito
    markers.add(
      _buildMarker(
        Configuracion.depositoLatLng,
        'Depósito',
        Icons.storefront,
        Colors.blue,
        null, // Sin etiqueta
        () => _showPedidoDetails(null, isDeposito: true), // Tap para depósito
      ),
    );

    // Marcadores de Paradas (Pedidos)
    for (var detalle in _paradas) {
      final lat = double.tryParse(detalle['lat']?.toString() ?? '');
      final lng = double.tryParse(detalle['lng']?.toString() ?? '');
      if (lat != null && lng != null) {
        final paradaCoords = LatLng(lat, lng);
        markers.add(
          _buildMarker(
            paradaCoords,
            '${detalle['orden_visita']}: #${detalle['id_pedido']} - ${detalle['nombre_cliente'] ?? ''} ${detalle['apellido_cliente'] ?? ''}'
                .trim(),
            Icons.location_pin,
            chazkyGold,
            detalle['orden_visita']?.toString(),
            () => _showPedidoDetails(detalle), // Tap para esta parada
          ),
        );
        bounds.extend(paradaCoords);
      }
    }

    // Marcador de Ubicación del Repartidor (Simulada)
    final LatLng repartidorUbicacionActual = LatLng(
      -24.8453,
      -65.4412,
    ); // Valor actualizado
    markers.add(
      _buildMarker(
        repartidorUbicacionActual,
        'Tu Ubicación (Simulada)',
        Icons.delivery_dining_sharp,
        Colors.red,
        null, // Sin etiqueta
        () {
          // Tap para el repartidor
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Esta es tu ubicación actual (simulada).'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
    bounds.extend(repartidorUbicacionActual);

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
        throw FormatException("Formato inesperado para geometria_geojson");
      }

      List<LatLng> routePoints = _extractCoordinates(geoJsonObject);
      if (routePoints.isEmpty) {
        print("Advertencia: No se pudieron extraer puntos de la ruta.");
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
            pattern: StrokePattern.dotted(), // Usando StrokePattern
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
    VoidCallback? onTap, // Parámetro opcional para el tap
  ]) {
    return Marker(
      width: label != null ? 40.0 : 35.0,
      height: label != null ? 40.0 : 35.0,
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

  // --- Popup de Detalles del Pedido ---
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

    // Obtiene el estado de la parada (ya disponible en _paradas)
    final String estadoParada = parada['estado_parada'] ?? 'Pendiente';
    final String? motivoFallo = parada['motivo_fallo'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: API.getPedidoDetalles(idPedido), // Llama a la API
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
                  // Widget de Estado de Entrega
                  _buildStatusInfo(estadoParada, motivoFallo),
                  Divider(color: Colors.white24, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      "Productos:",
                      style: TextStyle(
                        color: chazkyWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
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
              height: MediaQuery.of(context).size.height * 0.75, // Más alto
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? _buildLoading()
          : _error != null
          ? _buildErrorWidget(_error!)
          : _rutaData == null
          ? _buildNoRouteWidget(_infoMessage)
          : _buildRouteView(),
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
    final List paradas = _paradas; // Usa el estado

    return Column(
      children: [
        // --- MAPA ---
        Expanded(
          flex: 2,
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
              if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
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
          flex: 1,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            itemCount: paradas.length,
            itemBuilder: (context, index) {
              final parada = paradas[index] as Map<String, dynamic>;
              final String estadoParada =
                  parada['estado_parada'] ?? 'Pendiente';
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
                  margin: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isPendiente
                          ? chazkyGold
                          : (isCompletado
                                ? Colors.green
                                : Colors.redAccent[700]!),
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
                        decoration: isFallido
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      isFallido ? "FALLIDO: $motivoFallo" : direccion,
                      style: TextStyle(
                        color: isFallido
                            ? Colors.redAccent[100]
                            : chazkyWhite.withOpacity(0.7),
                        fontWeight: isFallido
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _buildTrailingAction(parada, estadoParada),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper para la barra de estado en el popup
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

  // Widget helper para los botones de acción
  Widget _buildTrailingAction(Map<String, dynamic> parada, String estado) {
    final String idRutaDetalle = parada['id_ruta_detalle']?.toString() ?? '';
    // Muestra loader si esta parada se está actualizando
    bool isThisParadaUpdating =
        _isUpdatingParada &&
        (_paradas.firstWhere(
              (p) => p['id_ruta_detalle'].toString() == idRutaDetalle,
              orElse: () => {},
            )['estado_parada'] ==
            'Pendiente');

    if (isThisParadaUpdating) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: chazkyGold),
      );
    }

    // Botón de Lupa
    Widget detailsButton = IconButton(
      icon: Icon(Icons.search, color: chazkyWhite.withOpacity(0.7)),
      onPressed: _isUpdatingParada ? null : () => _showPedidoDetails(parada),
      tooltip: 'Ver Detalles del Pedido',
    );

    switch (estado) {
      case 'Entregado':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            detailsButton, // Muestra lupa
            Icon(Icons.check_circle, color: Colors.greenAccent[400], size: 28),
          ],
        );
      case 'No Entregado':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            detailsButton, // Muestra lupa
            Icon(Icons.error, color: Colors.redAccent[400], size: 28),
          ],
        );
      case 'Pendiente':
      default:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            detailsButton, // Muestra lupa
            IconButton(
              icon: Icon(Icons.check_circle_outline, color: Colors.greenAccent),
              onPressed: _isUpdatingParada
                  ? null
                  : () => _marcarEntregado(idRutaDetalle),
              tooltip: 'Marcar como Entregado',
            ),
            IconButton(
              icon: Icon(Icons.cancel_outlined, color: Colors.redAccent),
              onPressed: _isUpdatingParada
                  ? null
                  : () => _mostrarDialogoNoEntregado(idRutaDetalle),
              tooltip: 'Marcar como No Entregado',
            ),
          ],
        );
    }
  }
}
