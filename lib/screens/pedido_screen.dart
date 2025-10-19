// lib/screens/pedido_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../api.dart';
import '../models/product_model.dart'; // Importamos el modelo
import './checkout_screen.dart'; // Importamos la nueva pantalla

class PedidoScreen extends StatefulWidget {
  static const routeName = '/pedido';

  @override
  _PedidoScreenState createState() => _PedidoScreenState();
}

class _PedidoScreenState extends State<PedidoScreen> {
  // Paleta de colores
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

  // --- ¡NUEVA FUNCIÓN DE NAVEGACIÓN! ---
  void _goToCheckout() {
    if (_pedidoItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tu pedido está vacío.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navegamos a la nueva pantalla de checkout, pasando los datos del pedido
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) =>
            CheckoutScreen(pedidoItems: _pedidoItems, total: _total),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // ... (decoración del gradiente)
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
                  // El footer del total ahora está arriba, debajo de la AppBar
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
        // --- BOTÓN FLOTANTE ACTUALIZADO ---
        floatingActionButton: FloatingActionButton(
          onPressed: _goToCheckout, // Llama a la nueva función
          backgroundColor: chazkyGold,
          foregroundColor: primaryDarkBlue,
          child: Icon(Icons.arrow_forward_rounded), // Icono de "continuar"
        ),
      ),
    );
  }

  // ... (los widgets _buildTotalFooter y _buildPedidoItemCard no cambian)
  Widget _buildTotalFooter() {
    // ... (tu código actual de _buildTotalFooter)
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
    // ... (tu código actual de _buildPedidoItemCard)
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
              backgroundImage: NetworkImage(producto.imagenUrl),
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
