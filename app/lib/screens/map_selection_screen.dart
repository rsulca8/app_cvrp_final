// lib/screens/map_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Importa LatLng de latlong2
import 'package:geocoding/geocoding.dart'; // Mantenlo si conviertes coordenadas

class MapSelectionScreen extends StatefulWidget {
  @override
  _MapSelectionScreenState createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  // Controlador de mapa para flutter_map
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  Marker? _marker;

  // Ubicación inicial (Salta, Argentina)
  final LatLng _initialCenter = const LatLng(-24.7891, -65.4106);

  // --- Lógica del Mapa ---
  void _onTapMap(TapPosition tapPosition, LatLng location) {
    setState(() {
      _selectedLocation = location;
      _marker = Marker(
        width: 80.0,
        height: 80.0,
        point: location,
        child: Icon(
          // Usamos un widget como marcador
          Icons.location_pin,
          color: chazkyGold, // Marcador dorado
          size: 50.0,
        ),
      );
    });
  }

  // --- Convertir Coordenadas a Dirección (usando geocoding) ---
  Future<String> _getAddressFromLatLng(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks[0];
        return "${place.street}, ${place.locality}, ${place.administrativeArea}";
      }
    } catch (e) {
      print("Error obteniendo dirección: $e");
    }
    return "No se pudo obtener la dirección";
  }
  // --- Fin Conversión ---

  // --- Confirmar Selección y Volver ---
  void _confirmSelection() async {
    if (_selectedLocation != null) {
      String address = await _getAddressFromLatLng(_selectedLocation!);
      // Devolvemos el LatLng de latlong2 y la dirección
      Navigator.of(
        context,
      ).pop({'location': _selectedLocation, 'address': address});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, selecciona una ubicación en el mapa.'),
        ),
      );
    }
  }
  // --- Fin Confirmar ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Selecciona la Dirección',
          style: TextStyle(fontFamily: 'Montserrat'),
        ),
        backgroundColor: mediumDarkBlue,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13.0,
              onTap: _onTapMap, // Define la función a llamar al tocar
            ),
            children: [
              // Capa de Tiles (mapa base de OpenStreetMap)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.chazky.app', // Reemplaza con tu package name
              ),
              // Capa de Marcadores
              if (_marker != null) MarkerLayer(markers: [_marker!]),
            ],
          ),
          // Botón de Confirmar Selección
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              icon: Icon(Icons.check_circle_outline),
              label: Text('Confirmar Dirección'),
              style: ElevatedButton.styleFrom(
                backgroundColor: chazkyGold,
                foregroundColor: primaryDarkBlue,
                padding: EdgeInsets.symmetric(vertical: 15),
                textStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _confirmSelection,
            ),
          ),
        ],
      ),
    );
  }
}
