// lib/screens/admin/logistica_screen.dart

import 'package:flutter/material.dart';
import '../../api.dart';
import '../../models/pedido_model.dart'; // Importa Pedido, Repartidor y RUTA
import 'package:intl/intl.dart';
// Importa las pantallas de detalle
import './ruta_detalle_screen.dart';
import './todas_rutas_mapa_screen.dart'; // <-- Importa la pantalla del mapa general

class LogisticaScreen extends StatefulWidget {
  @override
  _LogisticaScreenState createState() => _LogisticaScreenState();
}

class _LogisticaScreenState extends State<LogisticaScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  // Estados
  List<Pedido> _pedidosPendientes = [];
  List<Ruta> _rutasAsignadas = [];
  List<Repartidor> _repartidores = [];
  bool _isLoading = true;
  String? _error;

  // Sets para guardar los IDs seleccionados
  final Set<String> _selectedPedidoIds = {};
  final Set<String> _selectedRepartidorIds = {};
  bool _isGeneratingRoutes = false;

  @override
  void initState() {
    super.initState();
    _loadData(forceRefresh: true);
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (forceRefresh) {
        _selectedPedidoIds.clear();
        _selectedRepartidorIds.clear();
      }
    });

    try {
      // Pide datos en paralelo
      final results = await Future.wait([
        API.getPedidosPorEstado(['Pendiente']),
        API.getRutasAsignadas(), // Obtiene rutas con geometría
        API.getRepartidoresDisponibles(),
      ]);

      final pedidosData = results[0] as List<dynamic>;
      final rutasData = results[1] as List<dynamic>;
      final repartidoresData = results[2] as List<dynamic>;

      if (mounted) {
        setState(() {
          // Procesa y guarda los datos en el estado
          _pedidosPendientes = pedidosData
              .whereType<Map<String, dynamic>>() // Filtra tipos incorrectos
              .map((p) => Pedido.fromJson(p))
              .toList();
          _rutasAsignadas = rutasData
              .whereType<Map<String, dynamic>>()
              .map((r) => Ruta.fromJson(r))
              .toList();
          _repartidores = repartidoresData
              .whereType<Map<String, dynamic>>()
              .map((r) => Repartidor.fromJson(r))
              .toList();
          _isLoading = false;
        });
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

  // --- Funciones de Selección y Generación (sin cambios) ---
  void _togglePedidoSelection(String pedidoId) {
    setState(() {
      if (_selectedPedidoIds.contains(pedidoId)) {
        _selectedPedidoIds.remove(pedidoId);
      } else {
        _selectedPedidoIds.add(pedidoId);
      }
    });
  }

  void _toggleRepartidorSelection(String repartidorId) {
    setState(() {
      if (_selectedRepartidorIds.contains(repartidorId)) {
        _selectedRepartidorIds.remove(repartidorId);
      } else {
        _selectedRepartidorIds.add(repartidorId);
      }
    });
  }

  Future<void> _generarRutas() async {
    if (_selectedPedidoIds.isEmpty || _selectedRepartidorIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecciona pedido(s) y repartidor(es).'),
          backgroundColor: Colors.orange[800],
        ),
      );
      return;
    }
    setState(() => _isGeneratingRoutes = true);
    try {
      final response = await API.generarRutas(
        _selectedPedidoIds.toList(),
        _selectedRepartidorIds.toList(),
      );
      if (mounted) {
        if (response['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Rutas generadas.'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadData(forceRefresh: true);
        } else {
          throw Exception(response['message'] ?? 'Error desconocido.');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted && _isGeneratingRoutes) {
        setState(() => _isGeneratingRoutes = false);
      }
    }
  }
  // --- Fin Funciones ---

  // Navega a la pantalla de detalle de ruta
  void _verRuta(Ruta ruta) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => RutaDetalleScreen(rutaId: ruta.idRuta),
      ),
    );
  }

  // Navega a la pantalla del mapa general
  void _verMapaGeneral() {
    // Navega usando MaterialPageRoute
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (ctx) => TodasRutasMapaScreen()));
    // O si definiste routeName, puedes usar pushNamed:
    // Navigator.of(context).pushNamed(TodasRutasMapaScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    bool canGenerate =
        _selectedPedidoIds.isNotEmpty && _selectedRepartidorIds.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // --- AppBar con Título y Botón de Mapa ---
      appBar: AppBar(
        title: Text(
          'Ver todas las rutas',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: chazkyWhite,
          ),
        ),
        backgroundColor: Colors.transparent, // Hereda gradiente
        elevation: 0, // Sin sombra
        actions: [
          IconButton(
            icon: Icon(Icons.map_outlined), // Icono de mapa
            tooltip: 'Ver Mapa General de Rutas',
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.all<Color>(chazkyGold),
            ),
            // Deshabilita el botón si no hay rutas cargadas o si está cargando
            onPressed: _isLoading || _rutasAsignadas.isEmpty
                ? null
                : _verMapaGeneral,
          ),
        ],
      ),
      // --- Fin AppBar ---
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true),
        color: chazkyGold,
        backgroundColor: mediumDarkBlue,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
                ),
              )
            : _error != null
            ? _buildErrorWidget(_error!)
            : ListView(
                padding: const EdgeInsets.all(8.0).copyWith(bottom: 100),
                children: [
                  _buildSectionTitle(
                    'Repartidores Disponibles (${_selectedRepartidorIds.length}/${_repartidores.length})',
                  ),
                  _buildRepartidoresList(),
                  SizedBox(height: 16),

                  _buildSectionTitle(
                    'Pedidos Pendientes (${_selectedPedidoIds.length}/${_pedidosPendientes.length})',
                  ),
                  _buildPedidosList(_pedidosPendientes),
                  SizedBox(height: 16),

                  _buildSectionTitle(
                    'Rutas Asignadas/En Curso (${_rutasAsignadas.length})',
                  ),
                  _buildRutasList(_rutasAsignadas),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isGeneratingRoutes || !canGenerate) ? null : _generarRutas,
        backgroundColor: canGenerate ? chazkyGold : Colors.grey[700],
        foregroundColor: canGenerate ? primaryDarkBlue : Colors.white54,
        icon: _isGeneratingRoutes
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: primaryDarkBlue,
                  strokeWidth: 2,
                ),
              )
            : Icon(Icons.route_outlined),
        label: Text(
          _isGeneratingRoutes ? 'Generando...' : 'Generar Rutas',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        tooltip: !canGenerate
            ? 'Selecciona pedidos y repartidores'
            : 'Generar rutas seleccionadas',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- Widgets Helpers (sin cambios) ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: chazkyGold,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
        ),
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
            Icon(Icons.cloud_off_outlined, color: Colors.redAccent, size: 60),
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
              onPressed: () => _loadData(forceRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumDarkBlue,
                foregroundColor: chazkyWhite,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepartidoresList() {
    if (_repartidores.isEmpty && !_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Text(
          'No hay repartidores.',
          style: TextStyle(
            color: chazkyWhite.withOpacity(0.7),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: _repartidores.map((repartidor) {
        final isSelected = _selectedRepartidorIds.contains(
          repartidor.idUsuario,
        );
        return FilterChip(
          label: Text(repartidor.nombreCompleto),
          selected: isSelected,
          onSelected: (bool selected) =>
              _toggleRepartidorSelection(repartidor.idUsuario),
          backgroundColor: mediumDarkBlue.withOpacity(0.4),
          selectedColor: chazkyGold.withOpacity(0.3),
          checkmarkColor: chazkyGold,
          labelStyle: TextStyle(
            color: isSelected ? chazkyGold : chazkyWhite,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          side: BorderSide(color: isSelected ? chazkyGold : Colors.white30),
          showCheckmark: true,
        );
      }).toList(),
    );
  }

  Widget _buildPedidosList(List<Pedido> pedidos) {
    if (pedidos.isEmpty && !_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Text(
          'No hay pedidos pendientes.',
          style: TextStyle(
            color: chazkyWhite.withOpacity(0.7),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Column(
      children: pedidos.map((pedido) {
        final isSelected = _selectedPedidoIds.contains(pedido.idPedido);
        return Card(
          color: mediumDarkBlue.withOpacity(0.5),
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(
              color: isSelected ? chazkyGold : Colors.white24,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (bool? value) =>
                  _togglePedidoSelection(pedido.idPedido),
              activeColor: chazkyGold,
              checkColor: primaryDarkBlue,
              visualDensity: VisualDensity.compact,
            ),
            title: Text(
              '#${pedido.idPedido} - ${pedido.nombreCompletoCliente}',
              style: TextStyle(
                color: chazkyWhite,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pedido.direccionEntrega,
                  style: TextStyle(
                    color: chazkyWhite.withOpacity(0.8),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  '${DateFormat('dd/MM HH:mm').format(pedido.fechaHoraPedido)} - \$${pedido.totalPedido.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: chazkyWhite.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            onTap: () => _togglePedidoSelection(pedido.idPedido),
            dense: true,
            selected: isSelected,
            selectedTileColor: chazkyGold.withOpacity(0.08),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRutasList(List<Ruta> rutas) {
    if (rutas.isEmpty && !_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Text(
          'No hay rutas asignadas.',
          style: TextStyle(
            color: chazkyWhite.withOpacity(0.7),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Column(
      children: rutas.map((ruta) {
        return Card(
          color: mediumDarkBlue.withOpacity(0.3),
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(color: Colors.white24, width: 0.5),
          ),
          child: ListTile(
            leading: Icon(
              ruta.estadoRuta == 'En Curso'
                  ? Icons.local_shipping
                  : Icons.route,
              color: chazkyGold.withOpacity(0.8),
              size: 28,
            ),
            title: Text(
              'Ruta #${ruta.idRuta} - ${ruta.nombreCompletoRepartidor}',
              style: TextStyle(
                color: chazkyWhite,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado: ${ruta.estadoRuta} - Creada: ${DateFormat('dd/MM HH:mm').format(ruta.fechaHoraCreacion)}',
                  style: TextStyle(
                    color: chazkyWhite.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Estimado: ${ruta.distanciaFormateada} / ${ruta.duracionFormateada}',
                  style: TextStyle(
                    color: chazkyWhite.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.visibility_outlined, color: chazkyGold),
              tooltip: 'Ver Detalles de Ruta',
              onPressed: () => _verRuta(ruta),
            ),
            dense: true,
          ),
        );
      }).toList(),
    );
  }
}
