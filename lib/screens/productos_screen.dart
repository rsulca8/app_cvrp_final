// lib/screens/productos_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../api.dart';
import '../models/product_model.dart';
import './pedido_screen.dart'; // Importa la pantalla de pedido

// Un modelo simple para el item del carrito
class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
}

class ProductosScreen extends StatefulWidget {
  static const routeName = '/productos';

  const ProductosScreen({Key? key}) : super(key: key);

  @override
  _ProductosScreenState createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  // Paleta de colores de Chazky para consistencia
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  List<Product> _products = [];
  Map<String, CartItem> _cart = {}; // Usamos un Map para fácil acceso por ID
  bool _isLoading = true;
  double _total = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final productData = await API.getProductos();
      final loadedProducts = productData
          .map((item) => Product.fromJson(item))
          .toList();
      await _loadCart();
      if (mounted) {
        setState(() {
          _products = loadedProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar productos: $e')),
        );
      }
    }
  }

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('pedido')) {
      final cartData =
          json.decode(prefs.getString('pedido')!) as Map<String, dynamic>;
      final Map<String, CartItem> loadedCart = {};
      cartData.forEach((key, value) {
        loadedCart[key] = CartItem(
          product: Product.fromJson(value['producto']),
          quantity: value['cantidad'],
        );
      });
      _cart = loadedCart;
      _calculateTotal();
    }
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartDataToSave = _cart.map(
      (key, value) => MapEntry(key, {
        'producto': {
          'id_producto': value.product.id,
          'nombre_producto': value.product.nombre,
          'marca_producto': value.product.marca,
          'precio_producto': value.product.precio,
          'descuento_producto': value.product.descuento,
          'imagen_producto': value.product.imagenUrl,
        },
        'cantidad': value.quantity,
      }),
    );
    prefs.setString('pedido', json.encode(cartDataToSave));
  }

  void _addToCart(Product product) {
    setState(() {
      if (_cart.containsKey(product.id)) {
        _cart[product.id]!.quantity++;
      } else {
        _cart[product.id] = CartItem(product: product);
      }
      _calculateTotal();
      _saveCart();
    });
  }

  void _removeFromCart(Product product) {
    setState(() {
      if (_cart.containsKey(product.id) && _cart[product.id]!.quantity > 1) {
        _cart[product.id]!.quantity--;
      } else {
        _cart.remove(product.id);
      }
      _calculateTotal();
      _saveCart();
    });
  }

  void _calculateTotal() {
    double total = 0.0;
    _cart.forEach((key, cartItem) {
      total += cartItem.product.precio * cartItem.quantity;
    });
    _total = total;
  }
  // --- FIN DE LA LÓGICA DE DATOS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El fondo debe ser transparente para heredar el gradiente del HomeScreen
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
              ),
            )
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildProductList()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed(PedidoScreen.routeName);
        },
        backgroundColor: chazkyGold, // Color dorado
        foregroundColor: primaryDarkBlue, // Color del ícono
        child: Icon(Icons.shopping_cart_checkout_rounded),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primaryDarkBlue.withOpacity(0.8),
        border: Border(bottom: BorderSide(color: Colors.white24, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total: \$${_total.toStringAsFixed(2)}',
            style: TextStyle(
              color: chazkyWhite,
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Items: ${_cart.values.fold(0, (sum, item) => sum + item.quantity)}',
            style: TextStyle(
              color: chazkyWhite,
              fontFamily: 'Montserrat',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _products.length,
      itemBuilder: (ctx, index) {
        final product = _products[index];
        // Construimos la URL completa de la imagen
        final imageUrl = "https://149.50.143.81/cvrp${product.imagenUrl}";

        return Card(
          color: mediumDarkBlue.withOpacity(0.5),
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: Colors.white24, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                SizedBox(
                  width: 70, // El doble del radio (35 * 2)
                  height: 70,
                  child: ClipOval(
                    // Widget para hacer circular a su hijo
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover, // Para que la imagen cubra el círculo
                      // 1. Esto se muestra MIENTRAS la imagen está cargando
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null)
                          return child; // Si ya cargó, muestra la imagen
                        return Center(
                          child: CircularProgressIndicator(
                            color: chazkyGold, // Indicador de carga dorado
                            strokeWidth: 2,
                          ),
                        );
                      },

                      // 2. Esto se muestra SI la imagen falla al cargar
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: primaryDarkBlue,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: chazkyWhite.withOpacity(0.7),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: chazkyWhite,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        product.marca,
                        style: TextStyle(
                          color: chazkyWhite.withOpacity(0.7),
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '\$${product.precio.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: chazkyGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                ),
                // Controles para añadir/quitar productos
                Column(
                  children: [
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: chazkyGold),
                      onPressed: () => _addToCart(product),
                    ),
                    Text(
                      _cart[product.id]?.quantity.toString() ?? '0',
                      style: TextStyle(
                        color: chazkyWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: chazkyWhite.withOpacity(0.7),
                      ),
                      onPressed: () => _removeFromCart(product),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
