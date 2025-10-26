// lib/screens/cliente/productos_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../api.dart';
import '../../models/product_model.dart';
import 'pedido_screen.dart';

class ProductosScreen extends StatefulWidget {
  static const routeName = '/productos';
  const ProductosScreen({Key? key}) : super(key: key);
  @override
  _ProductosScreenState createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  // Estados
  List<Product> _products = [];
  Map<String, CartItem> _cart = {};
  bool _isLoading = true; // Loader principal para productos y unidades
  double _total = 0.0;
  String? _errorLoading;

  // --- ¡NUEVO! Estados para las Unidades ---
  List<Map<String, dynamic>> _weightUnits = [];
  List<Map<String, dynamic>> _dimensionUnits = [];
  // --- Fin Nuevo ---

  @override
  void initState() {
    super.initState();
    // Ahora _loadInitialData carga todo
    _loadInitialData();
  }

  // --- ¡ACTUALIZADO! Carga productos Y unidades ---
  Future<void> _loadInitialData() async {
    if (!_isLoading) setState(() => _isLoading = true);
    _errorLoading = null;

    try {
      // Carga productos, unidades de peso y dimensión en paralelo
      final results = await Future.wait([
        API.getProductos(),
        API.getUnidadesPeso(),
        API.getUnidadesDimension(),
        _loadCartFromPrefs(), // Carga el carrito también en paralelo
      ]);

      // Procesa resultados
      final productData = results[0] as List<dynamic>;
      final weightUnitData = results[1] as List<dynamic>;
      final dimensionUnitData = results[2] as List<dynamic>;
      // El carrito ya se cargó en _loadCartFromPrefs y actualizó _cart y _total

      final loadedProducts = productData
          .where((item) => item is Map<String, dynamic>)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _products = loadedProducts;
          // Guarda las listas de unidades (asegura el tipo)
          _weightUnits = List<Map<String, dynamic>>.from(weightUnitData);
          _dimensionUnits = List<Map<String, dynamic>>.from(dimensionUnitData);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error detallado al cargar datos iniciales: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorLoading = "Error al cargar datos. Intenta de nuevo.";
        });
      }
    }
  }

  // Separado para poder llamarlo con await en Future.wait
  Future<void> _loadCartFromPrefs() async {
    // La lógica interna de _loadCart sigue igual
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('pedido')) {
        final cartData =
            json.decode(prefs.getString('pedido')!) as Map<String, dynamic>;
        final Map<String, CartItem> loadedCart = {};
        cartData.forEach((key, value) {
          if (value is Map<String, dynamic> &&
              value['producto'] is Map<String, dynamic>) {
            try {
              loadedCart[key] = CartItem(
                product: Product.fromJson(
                  value['producto'] as Map<String, dynamic>,
                ),
                quantity: value['cantidad'] ?? 1,
              );
            } catch (e) {
              print("Error decodificando producto del carrito (ID: $key): $e");
            }
          } else {
            print("Item de carrito inválido encontrado (ID: $key)");
          }
        });
        _cart = loadedCart; // Actualiza directamente
      } else {
        _cart = {}; // Asegura que esté vacío
      }
      _calculateTotal(); // Calcula total después de cargar
    } catch (e) {
      print("Error al cargar carrito: $e");
      _cart = {};
      _calculateTotal();
    }
  }
  // --- Fin Carga ---

  // --- Funciones del Carrito (sin cambios funcionales) ---
  Future<void> _saveCart() async {
    /* ... sin cambios ... */
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartDataToSave = _cart.map(
        (key, value) => MapEntry(key, {
          'producto': value.product.toJson(), // Usa el modelo actualizado
          'cantidad': value.quantity,
        }),
      );
      if (cartDataToSave.isEmpty) {
        await prefs.remove('pedido');
      } else {
        await prefs.setString('pedido', json.encode(cartDataToSave));
      }
    } catch (e) {
      print("Error al guardar carrito: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el carrito.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addToCart(Product product, [int quantity = 1]) {
    /* ... sin cambios ... */
    setState(() {
      if (_cart.containsKey(product.id)) {
        _cart[product.id]!.quantity += quantity;
      } else {
        _cart[product.id] = CartItem(product: product, quantity: quantity);
      }
      _calculateTotal();
      _saveCart(); // Guarda después de modificar
    });
  }

  void _removeFromCart(Product product) {
    /* ... sin cambios ... */
    setState(() {
      bool removed = false;
      if (_cart.containsKey(product.id)) {
        if (_cart[product.id]!.quantity > 1) {
          _cart[product.id]!.quantity--;
        } else {
          _cart.remove(product.id);
          removed = true;
        }
        _calculateTotal();
        _saveCart(); // Guarda después de modificar
        if (removed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.nombre} eliminado del carrito.'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  void _calculateTotal() {
    /* ... sin cambios ... */
    double total = 0.0;
    _cart.forEach((key, cartItem) {
      total += cartItem.product.precio * cartItem.quantity;
    });
    if (mounted) {
      setState(() {
        _total = total;
      });
    }
  }
  // --- Fin Funciones Carrito ---

  // --- ¡NUEVO! Helpers para obtener símbolos de unidades ---
  String _getPesoUnitSymbol(String? unitId) {
    if (unitId == null || unitId.isEmpty) return '';
    final unit = _weightUnits.firstWhere(
      (u) => u['id_unidad_peso']?.toString() == unitId,
      orElse: () => {}, // Devuelve mapa vacío si no encuentra
    );
    return unit['simbolo'] ?? unitId; // Devuelve símbolo o el ID como fallback
  }

  String _getDimensionUnitSymbol(String? unitId) {
    if (unitId == null || unitId.isEmpty) return '';
    final unit = _dimensionUnits.firstWhere(
      (u) => u['id_unidad_dimension']?.toString() == unitId,
      orElse: () => {},
    );
    return unit['simbolo'] ?? unitId; // Devuelve símbolo o el ID como fallback
  }
  // --- Fin Helpers ---

  void _showProductDetail(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // --- Contenido del Popup (¡AHORA USA LOS HELPERS!) ---
        return Container(
          // ... (decoración y estructura sin cambios) ...
          height: MediaQuery.of(context).size.height * 0.85,
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen, Marca, Nombre, Precio, Descripción (sin cambios)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          /* ... */ product.imagenUrl,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (c, ch, p) => p == null
                              ? ch
                              : Container(
                                  height: 250,
                                  color: mediumDarkBlue,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: chazkyGold,
                                    ),
                                  ),
                                ),
                          errorBuilder: (c, e, s) => Container(
                            height: 250,
                            color: mediumDarkBlue,
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.white54,
                              size: 60,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
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

                      // --- Detalles Adicionales (¡ACTUALIZADO!) ---
                      _buildDetailRow('Categoría:', product.categorias),
                      _buildDetailRow('Stock:', product.stock ?? 'N/A'),
                      _buildDetailRow(
                        'Peso:',
                        (product.peso != null && product.peso!.isNotEmpty)
                            // Usa el helper para obtener el símbolo
                            ? '${product.peso} ${_getPesoUnitSymbol(product.id_unidad_peso)}'
                            : 'No especificado',
                      ),
                      _buildDetailRow(
                        'Dimensiones:',
                        (product.alto != null && product.alto!.isNotEmpty)
                            // Usa el helper para obtener el símbolo
                            ? '${product.alto} x ${product.ancho} x ${product.profundidad} ${_getDimensionUnitSymbol(product.id_unidad_dimension)}'
                            : 'No especificadas',
                      ),
                      _buildDetailRow(
                        'Código Barras:',
                        product.codigoBarra ?? 'N/A',
                      ),
                    ],
                  ),
                ),
              ),
              // Botón Añadir (sin cambios)
              Container(
                /* ... Botón ... */
                padding: EdgeInsets.fromLTRB(
                  20,
                  15,
                  20,
                  MediaQuery.of(context).padding.bottom + 15,
                ),
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
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.nombre} añadido.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
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

  // Helper sin cambios
  Widget _buildDetailRow(String title, String value) {
    return Padding(
      /* ... */
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: chazkyWhite.withOpacity(0.7),
              fontFamily: 'Montserrat',
              fontSize: 14,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: chazkyWhite,
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (Scaffold, FAB sin cambios) ...
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
              ),
            )
          : _errorLoading != null
          ? _buildErrorWidget(_errorLoading!)
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _products.isEmpty
                      ? _buildEmptyListWidget()
                      : _buildProductList(),
                ),
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

  // --- Widgets Helpers (Error, Empty, Header, List sin cambios funcionales) ---
  Widget _buildErrorWidget(String errorMsg) {
    // ... (sin cambios) ...
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 50,
            ), // Icono más genérico
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
              onPressed: _loadInitialData, // Llama a la función que carga todo
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
    // ... (sin cambios) ...
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: chazkyWhite.withOpacity(0.5),
            size: 80,
          ),
          SizedBox(height: 20),
          Text(
            'No hay productos disponibles',
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

  Widget _buildHeader() {
    // ... (sin cambios) ...
    int totalItems = _cart.values.fold(0, (sum, item) => sum + item.quantity);
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
            'Items: $totalItems',
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
    // ... (sin cambios funcionales, la UI ya estaba bien) ...
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _products.length,
      itemBuilder: (ctx, index) {
        final product = _products[index];
        final imageUrl = product.imagenUrl;

        return Card(
          color: mediumDarkBlue.withOpacity(0.5),
          margin: const EdgeInsets.symmetric(vertical: 8),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: Colors.white24, width: 0.5),
          ),
          child: InkWell(
            onTap: () {
              _showProductDetail(context, product);
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                  Column(
                    // Controles +/-
                    children: [
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: chazkyGold),
                        onPressed: () => _addToCart(product),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          _cart[product.id]?.quantity.toString() ?? '0',
                          style: TextStyle(
                            color: chazkyWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: _cart.containsKey(product.id)
                              ? chazkyWhite.withOpacity(0.7)
                              : Colors.transparent,
                        ),
                        onPressed: _cart.containsKey(product.id)
                            ? () => _removeFromCart(product)
                            : null,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
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
