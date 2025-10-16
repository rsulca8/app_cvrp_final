import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Para formatear la fecha
import 'dart:convert';

import '../api.dart';
import '../models/product_model.dart'; // Reutilizamos el modelo de producto

// Reutilizamos el modelo del item del carrito que definimos en productos_screen
class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
}

class PedidoScreen extends StatefulWidget {
  static const routeName = '/pedido';

  @override
  _PedidoScreenState createState() => _PedidoScreenState();
}

class _PedidoScreenState extends State<PedidoScreen> {
  // Paleta de colores de Chazky para consistencia
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  List<CartItem> _pedidoItems = [];
  bool _isLoading = true;
  double _total = 0.0;

  @override
  void initState() {
    super.initState();
    _loadPedido();
  }

  // --- LÓGICA DE DATOS (SIN CAMBIOS) ---
  Future<void> _loadPedido() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('pedido')) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final pedidoData =
        json.decode(prefs.getString('pedido')!) as Map<String, dynamic>;
    final List<CartItem> loadedItems = [];
    double calculatedTotal = 0.0;

    pedidoData.forEach((key, value) {
      final item = CartItem(
        product: Product.fromJson(value['producto']),
        quantity: value['cantidad'],
      );
      loadedItems.add(item);
      calculatedTotal += item.product.precio * item.quantity;
    });

    if (mounted) {
      setState(() {
        _pedidoItems = loadedItems;
        _total = calculatedTotal;
        _isLoading = false;
      });
    }
  }

  Future<void> _enviarPedido() async {
    if (_pedidoItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tu pedido está vacío.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = json.decode(prefs.getString('userData')!);
      final fechaEnvio = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(DateTime.now());
      final encabezado = {
        'id_cliente': userData['userId'],
        'fecha_hora_pedido': fechaEnvio,
        'total_pedido': _total,
      };
      final detalles = _pedidoItems
          .map(
            (item) => {
              'id_producto': item.product.id,
              'producto_precio_venta': item.product.precio,
              'cantidad': item.quantity,
            },
          )
          .toList();

      await API.enviarPedido(encabezado, detalles);
      await prefs.remove('pedido');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Pedido enviado con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar el pedido.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // --- FIN DE LA LÓGICA DE DATOS ---

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
            'Resumen del Pedido',
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
                ),
              )
            : _pedidoItems.isEmpty
            ? Center(
                child: Text(
                  'No hay productos en tu pedido.',
                  style: TextStyle(
                    color: chazkyWhite.withOpacity(0.7),
                    fontSize: 18,
                    fontFamily: 'Montserrat',
                  ),
                ),
              )
            : Column(
                children: [
                  _buildTotalFooter(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      itemCount: _pedidoItems.length,
                      itemBuilder: (ctx, index) =>
                          _buildPedidoItemCard(_pedidoItems[index]),
                    ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _enviarPedido,
          backgroundColor: chazkyGold,
          foregroundColor: primaryDarkBlue,
          child: Icon(Icons.send_rounded),
        ),
      ),
    );
  }

  Widget _buildTotalFooter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: primaryDarkBlue.withOpacity(0.8),
        border: Border(top: BorderSide(color: Colors.white24, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total del Pedido:',
            style: TextStyle(
              color: chazkyWhite,
              fontSize: 18,
              fontFamily: 'Montserrat',
            ),
          ),
          Text(
            '\$${_total.toStringAsFixed(2)}',
            style: TextStyle(
              color: chazkyGold,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPedidoItemCard(CartItem item) {
    final producto = item.product;
    final totalProducto = producto.precio * item.quantity;

    return Card(
      color: mediumDarkBlue.withOpacity(0.5),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.white24, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(
                "https://149.50.143.81/cvrp${producto.imagenUrl}",
              ),
              backgroundColor: primaryDarkBlue,
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: chazkyWhite,
                      fontFamily: 'Montserrat',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Cantidad: ${item.quantity} x \$${producto.precio.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: chazkyWhite.withOpacity(0.7),
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 15),
            Text(
              '\$${totalProducto.toStringAsFixed(2)}',
              style: TextStyle(
                color: chazkyWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
