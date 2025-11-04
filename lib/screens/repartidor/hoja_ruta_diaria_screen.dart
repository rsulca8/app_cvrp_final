// lib/screens/repartidor/hoja_ruta_diaria_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Para obtener el ID del repartidor
import 'package:intl/intl.dart'; // Para formatear fecha

import '../../api.dart';
import '../../models/pedido_model.dart'; // Importa el modelo Ruta
import '../../auth_service.dart'; // Para obtener ID del repartidor
import '../admin/ruta_detalle_screen.dart'; // Reutiliza la pantalla de detalle del admin

class HojaRutaDiariaScreen extends StatefulWidget {
  @override
  _HojaRutaDiariaScreenState createState() => _HojaRutaDiariaScreenState();
}

class _HojaRutaDiariaScreenState extends State<HojaRutaDiariaScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  bool _isLoading = true;
  String? _error;
  List<Ruta> _rutasAsignadas = [];

  @override
  void initState() {
    super.initState();
    // Espera al primer frame para acceder al Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRutasRepartidor();
    });
  }

  Future<void> _loadRutasRepartidor() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _rutasAsignadas = [];
    });

    try {
      // 1. Obtener el ID del repartidor logueado
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.userId == null) {
        throw Exception(
          "ID de repartidor no encontrado. Vuelve a iniciar sesión.",
        );
      }

      // 2. Llamar a la nueva función API
      final response = await API.getRutasPorRepartidor(authService.userId!, [
        'Asignada',
        'En Curso',
        'Completada',
        'Cancelada',
      ]);

      if (mounted) {
        // 3. Procesar la respuesta (que ahora es una lista)
        final List<Ruta> loadedRutas = response
            .whereType<Map<String, dynamic>>()
            .map((r) => Ruta.fromJson(r)) // Usa el modelo Ruta
            .toList();

        setState(() {
          _rutasAsignadas = loadedRutas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Error: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  // 4. Navegar a la pantalla de detalle (reutilizando la del admin)
  void _verRutaDetalle(Ruta ruta) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (ctx) => RutaDetalleScreen(rutaId: ruta.idRuta),
          ),
        )
        .then((_) {
          // Opcional: Recargar cuando vuelve de la pantalla de detalle
          // por si el estado de la ruta cambió (ej: a 'Completada')
          _loadRutasRepartidor();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Hereda gradiente
      body: RefreshIndicator(
        onRefresh: _loadRutasRepartidor,
        color: chazkyGold,
        backgroundColor: mediumDarkBlue,
        child: _isLoading
            ? _buildLoading()
            : _error != null
            ? _buildErrorWidget(_error!)
            : _rutasAsignadas.isEmpty
            ? _buildNoRoutesWidget()
            : _buildRutasList(), // Muestra la lista de rutas
      ),
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
            'Cargando tus rutas...',
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
              onPressed: _loadRutasRepartidor,
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

  Widget _buildNoRoutesWidget() {
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
              'No tienes rutas asignadas.',
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
              onPressed: _loadRutasRepartidor,
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

  // Widget para mostrar la lista de RUTAS
  Widget _buildRutasList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _rutasAsignadas.length,
      itemBuilder: (context, index) {
        final ruta = _rutasAsignadas[index];
        final bool enCurso = ruta.estadoRuta == 'En Curso';

        return Card(
          color: enCurso
              ? mediumDarkBlue.withOpacity(0.6)
              : mediumDarkBlue.withOpacity(0.3), // Resalta si está en curso
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(
              color: enCurso ? chazkyGold : Colors.white24,
              width: enCurso ? 1.5 : 0.5,
            ), // Borde dorado si está en curso
          ),
          child: ListTile(
            leading: Icon(
              enCurso ? Icons.local_shipping : Icons.route,
              color: chazkyGold,
              size: 32,
            ),
            title: Text(
              'Ruta #${ruta.idRuta} (${ruta.estadoRuta})',
              style: TextStyle(
                color: chazkyWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              'Creada: ${DateFormat('dd/MM/yy HH:mm').format(ruta.fechaHoraCreacion)}\nEstimado: ${ruta.distanciaFormateada} / ${ruta.duracionFormateada}',
              style: TextStyle(
                color: chazkyWhite.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: chazkyWhite.withOpacity(0.7),
              size: 16,
            ),
            isThreeLine: true,
            onTap: () => _verRuta(ruta), // Llama a la navegación
          ),
        );
      },
    );
  }

  void _verRuta(Ruta ruta) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (ctx) => RutaDetalleScreen(rutaId: ruta.idRuta),
          ),
        )
        .then((_) {
          // Opcional: recargar la lista al volver
          _loadRutasRepartidor();
        });
  }
}
