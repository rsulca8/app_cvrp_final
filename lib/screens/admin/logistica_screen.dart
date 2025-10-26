// lib/screens/admin/logistica_screen.dart

import 'package:flutter/material.dart';
import '../../api.dart';
import '../../models/pedido_model.dart'; // Importa el modelo Pedido y Repartidor
import 'package:intl/intl.dart'; // Para formatear fecha

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
  List<Pedido> _pedidosEnProceso = [];
  List<Repartidor> _repartidores = [];
  bool _isLoading = true;
  String? _error;

  // Sets para guardar los IDs seleccionados (más eficiente para buscar)
  final Set<String> _selectedPedidoIds = {};
  final Set<String> _selectedRepartidorIds = {};

  bool _isGeneratingRoutes = false; // Estado para el botón de generar

  @override
  void initState() {
    super.initState();
    _loadData(forceRefresh: true);
  }

  // Carga todos los datos necesarios
  Future<void> _loadData({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;
    setState(() {
      _isLoading = true;
      _error = null;
      // Limpia selecciones al recargar
      if (forceRefresh) {
        _selectedPedidoIds.clear();
        _selectedRepartidorIds.clear();
      }
    });

    try {
      // Pide ambos tipos de pedidos en una sola llamada
      final pedidosData = await API.getPedidosPorEstado([
        'Pendiente',
        'En Proceso',
      ]);
      final repartidoresData = await API.getRepartidoresDisponibles();

      if (mounted) {
        setState(() {
          // Filtra los pedidos por estado
          _pedidosPendientes = pedidosData
              .where((p) => p['estado'] == 'Pendiente')
              .map((p) => Pedido.fromJson(p as Map<String, dynamic>))
              .toList();
          _pedidosEnProceso = pedidosData
              .where((p) => p['estado'] == 'En Proceso')
              .map((p) => Pedido.fromJson(p as Map<String, dynamic>))
              .toList();
          // Mapea los repartidores
          _repartidores = repartidoresData
              .map((r) => Repartidor.fromJson(r as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error =
              "Error al cargar datos: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  // Maneja la selección/deselección de pedidos pendientes
  void _togglePedidoSelection(String pedidoId) {
    setState(() {
      if (_selectedPedidoIds.contains(pedidoId)) {
        _selectedPedidoIds.remove(pedidoId);
      } else {
        _selectedPedidoIds.add(pedidoId);
      }
    });
  }

  // Maneja la selección/deselección de repartidores
  void _toggleRepartidorSelection(String repartidorId) {
    setState(() {
      if (_selectedRepartidorIds.contains(repartidorId)) {
        _selectedRepartidorIds.remove(repartidorId);
      } else {
        _selectedRepartidorIds.add(repartidorId);
      }
    });
  }

  // Llama a la API para generar rutas
  Future<void> _generarRutas() async {
    if (_selectedPedidoIds.isEmpty || _selectedRepartidorIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selecciona al menos un pedido pendiente y un repartidor.',
          ),
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
              content: Text(
                response['message'] ?? 'Rutas generadas. Actualizando...',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Recarga los datos para ver los pedidos movidos a "En Proceso"
          await _loadData(forceRefresh: true);
        } else {
          throw Exception(
            response['message'] ?? 'Error desconocido del servidor.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al generar rutas: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingRoutes = false);
      }
    }
  }

  // Placeholder para la acción "Ver Ruta"
  void _verRuta(Pedido pedido) {
    // Aquí navegarías a una nueva pantalla o mostrarías un diálogo
    // pasando el ID del pedido para cargar los detalles de la ruta
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: mediumDarkBlue,
        title: Text(
          'Ver Ruta (Próximamente)',
          style: TextStyle(color: chazkyWhite),
        ),
        content: Text(
          'Aquí se mostrarán los detalles de la ruta para el pedido #${pedido.idPedido}.',
          style: TextStyle(color: chazkyWhite.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            child: Text('Cerrar', style: TextStyle(color: chazkyGold)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canGenerate =
        _selectedPedidoIds.isNotEmpty && _selectedRepartidorIds.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent, // Hereda gradiente
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
                // Usamos ListView general para poder poner títulos entre listas
                padding: const EdgeInsets.all(8.0),
                children: [
                  _buildSectionTitle(
                    'Repartidores Disponibles (${_repartidores.length})',
                  ),
                  _buildRepartidoresList(),
                  SizedBox(height: 16),

                  _buildSectionTitle(
                    'Pedidos Pendientes (${_pedidosPendientes.length})',
                  ),
                  _buildPedidosList(
                    _pedidosPendientes,
                    true,
                  ), // true para permitir selección
                  SizedBox(height: 16),

                  _buildSectionTitle(
                    'Pedidos En Proceso (${_pedidosEnProceso.length})',
                  ),
                  _buildPedidosList(
                    _pedidosEnProceso,
                    false,
                  ), // false para no permitir selección
                  SizedBox(height: 80), // Espacio para el botón flotante
                ],
              ),
      ),
      // Botón flotante para Generar Rutas
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isGeneratingRoutes || !canGenerate)
            ? null
            : _generarRutas, // Deshabilita si carga o no hay selección
        backgroundColor: canGenerate ? chazkyGold : Colors.grey,
        foregroundColor: canGenerate ? primaryDarkBlue : Colors.white60,
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
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat, // Centra el botón
    );
  }

  // --- Widgets Helpers ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
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
    /* ... (igual que en productos_config) ... */
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, color: Colors.redAccent, size: 50),
            SizedBox(height: 10),
            Text(
              errorMsg,
              textAlign: TextAlign.center,
              style: TextStyle(color: chazkyWhite.withOpacity(0.8)),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Reintentar'),
              onPressed: () => _loadData(forceRefresh: true),
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

  // Lista de Repartidores seleccionables
  Widget _buildRepartidoresList() {
    if (_repartidores.isEmpty && !_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No hay repartidores disponibles.',
          style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
        ),
      );
    }
    return Container(
      constraints: BoxConstraints(
        maxHeight: 150,
      ), // Limita altura para scroll si hay muchos
      child: ListView.builder(
        itemCount: _repartidores.length,
        itemBuilder: (ctx, index) {
          final repartidor = _repartidores[index];
          final isSelected = _selectedRepartidorIds.contains(
            repartidor.idUsuario,
          );
          return CheckboxListTile(
            value: isSelected,
            onChanged: (bool? value) {
              _toggleRepartidorSelection(repartidor.idUsuario);
            },
            title: Text(
              repartidor.nombreCompleto,
              style: TextStyle(color: chazkyWhite),
            ),
            tileColor: mediumDarkBlue.withOpacity(0.3),
            activeColor: chazkyGold,
            checkColor: primaryDarkBlue,
            controlAffinity:
                ListTileControlAffinity.leading, // Checkbox a la izquierda
            dense: true,
          );
        },
      ),
    );
  }

  // Lista genérica para Pedidos (Pendientes o En Proceso)
  Widget _buildPedidosList(List<Pedido> pedidos, bool allowSelection) {
    if (pedidos.isEmpty && !_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No hay pedidos en este estado.',
          style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true, // Para que funcione dentro del ListView principal
      physics: NeverScrollableScrollPhysics(), // Deshabilita scroll individual
      itemCount: pedidos.length,
      itemBuilder: (ctx, index) {
        final pedido = pedidos[index];
        final isSelected = _selectedPedidoIds.contains(pedido.idPedido);

        return Card(
          color: mediumDarkBlue.withOpacity(
            allowSelection ? 0.5 : 0.3,
          ), // Más opaco si es seleccionable
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(color: Colors.white24, width: 0.5),
          ),
          child: ListTile(
            // Checkbox solo si allowSelection es true
            leading: allowSelection
                ? Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) =>
                        _togglePedidoSelection(pedido.idPedido),
                    activeColor: chazkyGold,
                    checkColor: primaryDarkBlue,
                  )
                : Icon(
                    pedido.estado == 'En Proceso'
                        ? Icons.local_shipping_outlined
                        : Icons.pending_actions_outlined,
                    color: chazkyGold.withOpacity(0.7),
                  ),
            title: Text(
              '#${pedido.idPedido} - ${pedido.nombreCompletoCliente}',
              style: TextStyle(color: chazkyWhite, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pedido.direccionEntrega,
                  style: TextStyle(color: chazkyWhite.withOpacity(0.8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${DateFormat('dd/MM/yy HH:mm').format(pedido.fechaHoraPedido)} - \$${pedido.totalPedido.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: chazkyWhite.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing:
                !allowSelection // Botón "Ver Ruta" solo para "En Proceso"
                ? IconButton(
                    icon: Icon(Icons.route, color: chazkyGold),
                    tooltip: 'Ver Ruta Asignada',
                    onPressed: () => _verRuta(pedido),
                  )
                : null,
            onTap: allowSelection
                ? () => _togglePedidoSelection(pedido.idPedido)
                : null, // Tocar el tile también selecciona
            selected: isSelected,
            selectedTileColor: chazkyGold.withOpacity(0.1),
          ),
        );
      },
    );
  }
}
