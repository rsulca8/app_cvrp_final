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
  Map<String, CartItem> _cart = {};
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
        setState(() => _isLoading = false);
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
          // Product.fromJson ahora es robusto y puede leer datos nuevos y antiguos
          product: Product.fromJson(value['producto']),
          quantity: value['cantidad'],
        );
      });
      _cart = loadedCart;
      _calculateTotal();
    }
  }

  // --- ¡ACTUALIZADO! ---
  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartDataToSave = _cart.map(
      (key, value) => MapEntry(key, {
        // Usamos el método toJson() de nuestro modelo
        'producto': value.product.toJson(),
        'cantidad': value.quantity,
      }),
    );
    prefs.setString('pedido', json.encode(cartDataToSave));
  }

  void _addToCart(Product product, [int quantity = 1]) {
    setState(() {
      if (_cart.containsKey(product.id)) {
        _cart[product.id]!.quantity += quantity;
      } else {
        _cart[product.id] = CartItem(product: product, quantity: quantity);
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

  // --- ¡NUEVO! ---
  // Método para mostrar el popup de detalle del producto
  void _showProductDetail(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el sheet sea más alto
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height:
              MediaQuery.of(context).size.height * 0.85, // 85% de la pantalla
          decoration: BoxDecoration(
            color: primaryDarkBlue,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Barra para indicar que se puede arrastrar
              Container(
                width: 60,
                height: 6,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: mediumDarkBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Contenido con scroll
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen del producto
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          product.imagenUrl,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 250,
                              color: mediumDarkBlue,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: chazkyGold,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 250,
                              color: mediumDarkBlue,
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.white54,
                                size: 60,
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      // Marca y Nombre
                      Text(
                        product.marca.toUpperCase(),
                        style: TextStyle(
                          color: chazkyGold,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        product.nombre,
                        style: TextStyle(
                          color: chazkyWhite,
                          fontFamily: 'Montserrat',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 15),
                      // Precio
                      Text(
                        '\$${product.precio.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: chazkyGold,
                          fontFamily: 'Montserrat',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      // Descripción
                      Text(
                        'Descripción',
                        style: TextStyle(
                          color: chazkyWhite,
                          fontFamily: 'Montserrat',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        product.descripcion,
                        style: TextStyle(
                          color: chazkyWhite.withOpacity(0.7),
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 20),
                      // Detalles adicionales
                      _buildDetailRow('Categoría:', product.categorias),
                      _buildDetailRow('Stock:', product.stock ?? 'N/A'),
                      _buildDetailRow(
                        'Peso:',
                        '${product.peso ?? '-'} ${product.simboloUnidadPeso ?? ''}',
                      ),
                      _buildDetailRow(
                        'Dimensiones:',
                        '${product.alto ?? '-'} x ${product.ancho ?? '-'} x ${product.profundidad ?? '-'} ${product.simboloUnidadDimension ?? ''}',
                      ),
                    ],
                  ),
                ),
              ),
              // Barra inferior con botón de añadir
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: mediumDarkBlue,
                  border: Border(
                    top: BorderSide(color: Colors.white24, width: 0.5),
                  ),
                ),
                child: ElevatedButton(
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
                  onPressed: () {
                    _addToCart(product);
                    Navigator.of(ctx).pop(); // Cierra el popup
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.nombre} añadido al carrito.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text('Añadir al Carrito'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper para las filas de detalle en el popup
  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: chazkyWhite.withOpacity(0.7),
              fontFamily: 'Montserrat',
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: chazkyWhite,
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        onPressed: () =>
            Navigator.of(context).pushNamed(PedidoScreen.routeName),
        backgroundColor: chazkyGold,
        foregroundColor: primaryDarkBlue,
        child: Icon(Icons.shopping_cart_checkout_rounded),
      ),
    );
  }

  Widget _buildHeader() {
    // ... (sin cambios)
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
        // ¡Usamos la URL completa desde el modelo!
        final imageUrl = product.imagenUrl;

        return Card(
          color: mediumDarkBlue.withOpacity(0.5),
          margin: const EdgeInsets.symmetric(vertical: 8),
          clipBehavior:
              Clip.antiAlias, // Asegura que el InkWell siga los bordes
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: Colors.white24, width: 0.5),
          ),
          // --- ¡ACTUALIZADO! ---
          // Envolvemos la tarjeta en InkWell para hacerla "tocable"
          child: InkWell(
            onTap: () {
              _showProductDetail(context, product); // Llama al popup
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: ClipOval(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: chazkyGold,
                              strokeWidth: 2,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: primaryDarkBlue,
                            child: Icon(
                              Icons.inventory_2_outlined,
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
                          maxLines: 2, // Permite hasta 2 líneas para el nombre
                          overflow: TextOverflow
                              .ellipsis, // Añade '...' si es muy largo
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
          ),
        );
      },
    );
  }
}
