// lib/screens/pedido_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Para formatear la fecha
import 'dart:convert';

import '../../api.dart';
import '../../models/product_model.dart';
import 'checkout_screen.dart'; // Importamos la nueva pantalla

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

  // --- LÓGICA DEL CARRITO ---

  Future<void> _loadPedido() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('pedido')) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final pedidoData =
        json.decode(prefs.getString('pedido')!) as Map<String, dynamic>;
    final List<CartItem> loadedItems = [];

    pedidoData.forEach((key, value) {
      final item = CartItem(
        product: Product.fromJson(value['producto']),
        quantity: value['cantidad'],
      );
      loadedItems.add(item);
    });

    if (mounted) {
      setState(() {
        _pedidoItems = loadedItems;
        _calculateTotal(); // Llama a calcular total
        _isLoading = false;
      });
    }
  }

  // ¡NUEVO! - Guarda el estado actual del carrito en SharedPreferences
  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    // Convertimos la lista de items en un Map, usando el ID del producto como clave
    final Map<String, dynamic> cartDataToSave = {
      for (var item in _pedidoItems)
        item.product.id: {
          'producto': item.product.toJson(),
          'cantidad': item.quantity,
        },
    };

    if (cartDataToSave.isEmpty) {
      await prefs.remove('pedido');
    } else {
      await prefs.setString('pedido', json.encode(cartDataToSave));
    }
  }

  // ¡NUEVO! - Calcula el total basado en la lista _pedidoItems
  void _calculateTotal() {
    double calculatedTotal = 0.0;
    for (var item in _pedidoItems) {
      calculatedTotal += item.product.precio * item.quantity;
    }
    setState(() {
      _total = calculatedTotal;
    });
  }

  // ¡NUEVO! - Lógica para incrementar la cantidad
  void _increaseQuantity(CartItem item) {
    setState(() {
      item.quantity++;
      _calculateTotal();
      _saveCart();
    });
  }

  // ¡NUEVO! - Lógica para decrementar la cantidad
  void _decreaseQuantity(CartItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
        _calculateTotal();
        _saveCart();
      } else {
        // Si la cantidad es 1, lo eliminamos
        _removeItem(item);
      }
    });
  }

  // ¡NUEVO! - Lógica para eliminar un item
  void _removeItem(CartItem item) {
    setState(() {
      _pedidoItems.remove(item);
      _calculateTotal();
      _saveCart();
    });
  }

  // Navegación al checkout (sin cambios)
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) =>
            CheckoutScreen(pedidoItems: _pedidoItems, total: _total),
      ),
    );
  }

  // --- UI (Interfaz de Usuario) ---

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
            'Mi Pedido',
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: chazkyWhite,
              fontWeight: FontWeight.bold,
            ),
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
            ? _buildEmptyCart() // ¡MEJORADO!
            : Column(
                children: [
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
        // --- ¡MEJORA DE LAYOUT! ---
        // Reemplazamos el FAB y el _buildTotalFooter por una barra inferior fija
        bottomNavigationBar: _buildCheckoutBar(),
      ),
    );
  }

  // ¡NUEVO! - Barra inferior que combina el total y el botón de checkout
  Widget _buildCheckoutBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 15,
      ).copyWith(bottom: 30), // Espacio extra para gestos
      decoration: BoxDecoration(
        color: primaryDarkBlue,
        border: Border(top: BorderSide(color: Colors.white24, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Para que ocupe el mínimo espacio
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total:',
                style: TextStyle(
                  color: chazkyWhite.withOpacity(0.7),
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
          SizedBox(height: 15),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: chazkyGold,
              minimumSize: Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
              foregroundColor: primaryDarkBlue,
            ),
            onPressed: _goToCheckout,
            child: Text('Continuar al Checkout'),
          ),
        ],
      ),
    );
  }

  // ¡MEJORADO! - Widget para el carrito vacío
  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            color: chazkyWhite.withOpacity(0.5),
            size: 80,
          ),
          SizedBox(height: 20),
          Text(
            'Tu pedido está vacío',
            style: TextStyle(
              color: chazkyWhite.withOpacity(0.7),
              fontSize: 20,
              fontFamily: 'Montserrat',
            ),
          ),
          SizedBox(height: 30),
          TextButton.icon(
            onPressed: () {
              // Vuelve a la pantalla anterior (que es Home/Productos)
              Navigator.of(context).pop();
            },
            icon: Icon(Icons.arrow_back, color: chazkyGold),
            label: Text(
              'Volver a productos',
              style: TextStyle(
                color: chazkyGold,
                fontSize: 16,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- ¡MEJORADO! - Tarjeta de item editable ---
  Widget _buildPedidoItemCard(CartItem item) {
    final producto = item.product;
    final totalProducto = producto.precio * item.quantity;

    // Usamos Dismissible para la funcionalidad de "deslizar para eliminar"
    return Dismissible(
      key: ValueKey(producto.id), // Clave única para el widget
      direction: DismissDirection.endToStart, // Deslizar de derecha a izquierda
      onDismissed: (direction) {
        _removeItem(item); // Llama a la función de eliminar
      },
      background: Container(
        color: Colors.red[800],
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Icon(Icons.delete_sweep_outlined, color: Colors.white, size: 30),
      ),
      child: Card(
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  producto.imagenUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Container(
                    width: 60,
                    height: 60,
                    color: primaryDarkBlue,
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white54,
                    ),
                  ),
                ),
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
                        fontSize: 15,
                        color: chazkyWhite,
                        fontFamily: 'Montserrat',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '\$${totalProducto.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: chazkyWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 15),
              // --- Controles de Cantidad ---
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: chazkyWhite.withOpacity(0.7),
                    ),
                    onPressed: () => _decreaseQuantity(item),
                  ),
                  Text(
                    item.quantity.toString(),
                    style: TextStyle(
                      color: chazkyWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: chazkyGold),
                    onPressed: () => _increaseQuantity(item),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
