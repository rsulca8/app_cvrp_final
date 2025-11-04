// lib/screens/admin/ventas_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatear fechas y números
import '../../api.dart';
import '../../models/pedido_model.dart'; // Importa el modelo Pedido
import '../../configuracion.dart'; // Para colores

class VentasScreen extends StatefulWidget {
  @override
  _VentasScreenState createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  bool _isLoading = true;
  String? _error;
  List<Pedido> _pedidosEntregados = [];

  // Variables para el dashboard
  double _ventasTotales = 0.0;
  int _numeroDeVentas = 0;

  @override
  void initState() {
    super.initState();
    _loadVentas();
  }

  Future<void> _loadVentas() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _pedidosEntregados = [];
      _ventasTotales = 0.0;
      _numeroDeVentas = 0;
    });

    try {
      // Pide solo los pedidos que están 'Entregado'
      final pedidosData = await API.getPedidosPorEstado(['Entregado']);

      if (mounted) {
        final List<Pedido> loadedPedidos = pedidosData
            .where((p) => p is Map<String, dynamic>)
            .map((p) => Pedido.fromJson(p as Map<String, dynamic>))
            .toList();

        // Calcula los totales para el dashboard
        double total = 0.0;
        for (var pedido in loadedPedidos) {
          total += pedido.totalPedido;
        }

        setState(() {
          _pedidosEntregados = loadedPedidos;
          _ventasTotales = total;
          _numeroDeVentas = loadedPedidos.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error =
              "Error al cargar ventas: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  // Popup de Detalles del Pedido (similar al de repartidor)
  void _showPedidoDetails(Map<String, dynamic> pedido) {
    final String idPedido = pedido['id_pedido']?.toString() ?? '0';
    final String nombreCliente =
        '${pedido['nombre_cliente'] ?? ''} ${pedido['apellido_cliente'] ?? ''}'
            .trim();
    final String direccion = pedido['direccion_entrega'] ?? 'N/A';
    final String estado = pedido['estado'] ?? 'Desconocido';
    final String? motivo = pedido['motivo_fallo'] as String?;

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
                /* Loader */
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: chazkyGold),
                      SizedBox(height: 16),
                      Text(
                        'Cargando productos...',
                        style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              content = Center(
                /* Error */
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
                /* No productos */
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
                    /* Encabezado */
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalle Pedido #${idPedido}',
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
                          'Total Pedido: \$${totalPedido.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: chazkyWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusInfo(estado, motivo), // Muestra estado
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
                    /* Lista Productos */
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: detallesProducto.length,
                      itemBuilder: (context, index) {
                        final item = detallesProducto[index];
                        final nombreProd =
                            item['nombre_producto'] ?? 'Producto s/nombre';
                        final marcaProd = item['marca_producto'] ?? 'S/marca';
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
              height: MediaQuery.of(context).size.height * 0.75,
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

  @override
  Widget build(BuildContext context) {
    // Formateador de moneda
    final currencyFormatter = NumberFormat.simpleCurrency(
      locale: 'es_AR',
      decimalDigits: 2,
      name: '',
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadVentas,
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
            : Column(
                // Cuerpo principal con Dashboard y Lista
                children: [
                  // 1. Dashboard de Resumen
                  _buildDashboardSummary(currencyFormatter),

                  // 2. Título de sección
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Historial de Ventas Entregadas (${_pedidosEntregados.length})',
                      style: TextStyle(
                        color: chazkyGold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),

                  // 3. Lista de Pedidos
                  Expanded(
                    child: _pedidosEntregados.isEmpty
                        ? _buildEmptyListWidget()
                        : _buildVentasList(),
                  ),
                ],
              ),
      ),
    );
  }

  // --- Widgets Helpers ---

  Widget _buildDashboardSummary(NumberFormat formatter) {
    return Card(
      color: mediumDarkBlue.withOpacity(0.4),
      margin: const EdgeInsets.all(12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: Colors.white24, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildDashboardItem(
              Icons.attach_money,
              '\$${formatter.format(_ventasTotales)}', // Formatea el total
              'Ventas Totales',
              Colors.greenAccent[400]!,
            ),
            Container(width: 1, height: 60, color: Colors.white24), // Divisor
            _buildDashboardItem(
              Icons.check_circle,
              _numeroDeVentas.toString(),
              'Pedidos Entregados',
              chazkyGold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardItem(
    IconData icon,
    String value,
    String label,
    Color iconColor,
  ) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 32),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: chazkyWhite,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
        ),
        Text(
          label,
          style: TextStyle(color: chazkyWhite.withOpacity(0.7), fontSize: 13),
        ),
      ],
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
              onPressed: _loadVentas,
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

  Widget _buildEmptyListWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: chazkyWhite.withOpacity(0.5),
            size: 80,
          ),
          SizedBox(height: 16),
          Text(
            'Aún no hay ventas entregadas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: chazkyWhite.withOpacity(0.7),
              fontSize: 20,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVentasList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      itemCount: _pedidosEntregados.length,
      itemBuilder: (context, index) {
        final pedido = _pedidosEntregados[index];

        return Opacity(
          opacity: 0.7, // Atenúa las ventas ya pasadas
          child: Card(
            color: mediumDarkBlue.withOpacity(0.3),
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.green[800]!, width: 0.5),
            ),
            child: ListTile(
              leading: Icon(Icons.check_circle, color: Colors.greenAccent[400]),
              title: Text(
                '#${pedido.idPedido} - ${pedido.nombreCompletoCliente}',
                style: TextStyle(
                  color: chazkyWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                'Entregado: ${DateFormat('dd/MM/yy HH:mm').format(pedido.fechaHoraPedido)}', // Idealmente usar fecha_hora_fin
                style: TextStyle(
                  color: chazkyWhite.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\$${pedido.totalPedido.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: chazkyGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.search,
                      color: chazkyWhite.withOpacity(0.7),
                    ),
                    onPressed: () {
                      // Llama al popup de detalles. Pasa el Pedido.toJson()
                      // ya que el popup espera un Map<String, dynamic> de la parada.
                      // Es una adaptación, idealmente el popup aceptaría un Pedido.
                      Map<String, dynamic> paradaData = {
                        'id_pedido': pedido.idPedido,
                        'nombre_cliente': pedido.nombreCliente,
                        'apellido_cliente': pedido.apellidoCliente,
                        'direccion_entrega': pedido.direccionEntrega,
                        'estado_parada': pedido.estado, // 'Entregado'
                        'motivo_fallo': null,
                      };
                      _showPedidoDetails(paradaData);
                    },
                    tooltip: 'Ver Detalles del Pedido',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper para mostrar el estado en el popup
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
      case 'Cancelado': // Si se usa 'Cancelado' para 'No Entregado'
        icon = Icons.error;
        color = Colors.redAccent[400]!;
        text = 'Fallido: ${motivo ?? "Sin motivo."}';
        break;
      default:
        icon = Icons.info_outline;
        color = chazkyWhite;
        text = estado;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(color: color.withOpacity(0.1)),
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
}
