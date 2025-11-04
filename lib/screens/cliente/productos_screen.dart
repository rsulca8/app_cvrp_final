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

  // Estados de Datos
  List<Product> _products = []; // Lista completa de productos
  List<Product> _filteredProducts = []; // Lista filtrada para mostrar
  Map<String, CartItem> _cart = {};
  double _total = 0.0;
  String? _errorLoading;

  // Estados de Unidades
  List<Map<String, dynamic>> _weightUnits = [];
  List<Map<String, dynamic>> _dimensionUnits = [];

  // --- Estados de Filtro y Búsqueda ---
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId; // null = "Todas"
  bool _isLoadingCategories = true;

  bool _isSearchVisible = false; // Controla visibilidad del searchbar
  final TextEditingController _searchController = TextEditingController();
  // --- Fin Estados ---

  bool _isLoadingProducts = true; // Loader principal

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // Listener para actualizar la lista al escribir
    _searchController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onFilterChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    // ... (sin cambios) ...
    if (!_isLoadingProducts) setState(() => _isLoadingProducts = true);
    _errorLoading = null;

    try {
      final results = await Future.wait([
        API.getProductos(),
        API.getUnidadesPeso(),
        API.getUnidadesDimension(),
        _loadCartFromPrefs(), // Carga el carrito
        API.getCategorias(), // Carga categorías
      ]);

      final productData = results[0] as List<dynamic>;
      final weightUnitData = results[1] as List<dynamic>;
      final dimensionUnitData = results[2] as List<dynamic>;
      final categoriesData = results[4] as List<dynamic>;

      final loadedProducts = productData
          .where((item) => item is Map<String, dynamic>)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _products = loadedProducts;
          _weightUnits = List<Map<String, dynamic>>.from(weightUnitData);
          _dimensionUnits = List<Map<String, dynamic>>.from(dimensionUnitData);
          _categories = List<Map<String, dynamic>>.from(categoriesData);

          _isLoadingProducts = false;
          _isLoadingCategories = false;

          _onFilterChanged(); // Aplica el filtro inicial (mostrar todos)
        });
      }
    } catch (e) {
      print("Error detallado al cargar datos iniciales: $e");
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _isLoadingCategories = false;
          _errorLoading = "Error al cargar datos. Intenta de nuevo.";
        });
      }
    }
  }

  // --- ¡ACTUALIZADO! Lógica unificada para filtrar y buscar ---
  void _onFilterChanged() {
    final String searchTerm = _searchController.text.toLowerCase();

    setState(() {
      List<Product> tempProducts = List.from(_products);

      // 1. Filtrar por Categoría
      if (_selectedCategoryId != null) {
        tempProducts = tempProducts
            .where((p) => p.id_categoria == _selectedCategoryId)
            .toList();
      }

      // 2. Filtrar por Término de Búsqueda (sobre la lista ya filtrada por categoría)
      if (searchTerm.isNotEmpty) {
        tempProducts = tempProducts
            .where(
              (p) =>
                  p.nombre.toLowerCase().contains(searchTerm) ||
                  p.marca.toLowerCase().contains(searchTerm),
            )
            .toList();
      }

      _filteredProducts = tempProducts;
    });
  }
  // --- Fin Actualización ---

  // --- Funciones del Carrito (sin cambios) ---
  Future<void> _loadCartFromPrefs() async {
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
        _cart = loadedCart;
      } else {
        _cart = {};
      }
      _calculateTotal(); // Llama a setState internamente
    } catch (e) {
      print("Error al cargar carrito: $e");
      _cart = {};
      _calculateTotal();
    }
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartDataToSave = _cart.map(
        (key, value) => MapEntry(key, {
          'producto': value.product.toJson(),
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
    setState(() {
      if (_cart.containsKey(product.id)) {
        _cart[product.id]!.quantity += quantity;
      } else {
        _cart[product.id] = CartItem(product: product, quantity: quantity);
      }
      _calculateTotal();
    });
    _saveCart();
  }

  void _removeFromCart(Product product) {
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
        if (removed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.nombre} eliminado.'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    });
    _saveCart();
  }

  void _calculateTotal() {
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

  // --- Helpers de Unidades (sin cambios) ---
  String _getPesoUnitSymbol(String? unitId) {
    if (unitId == null || unitId.isEmpty) return '';
    final unit = _weightUnits.firstWhere(
      (u) => u['id_unidad_peso']?.toString() == unitId,
      orElse: () => {},
    );
    return unit['simbolo'] ?? unitId;
  }

  String _getDimensionUnitSymbol(String? unitId) {
    if (unitId == null || unitId.isEmpty) return '';
    final unit = _dimensionUnits.firstWhere(
      (u) => u['id_unidad_dimension']?.toString() == unitId,
      orElse: () => {},
    );
    return unit['simbolo'] ?? unitId;
  }
  // --- Fin Helpers ---

  // --- Popup de Detalle (sin cambios) ---
  void _showProductDetail(BuildContext context, Product product) {
    // ... (código del popup sin cambios) ...
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          product.imagenUrl,
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
                      _buildDetailRow('Categoría:', product.categorias),
                      _buildDetailRow('Stock:', product.stock ?? 'N/A'),
                      _buildDetailRow(
                        'Peso:',
                        (product.peso != null && product.peso!.isNotEmpty)
                            ? '${product.peso} ${_getPesoUnitSymbol(product.id_unidad_peso)}'
                            : 'N/A',
                      ),
                      _buildDetailRow(
                        'Dimensiones:',
                        (product.alto != null && product.alto!.isNotEmpty)
                            ? '${product.alto}x${product.ancho}x${product.profundidad} ${_getDimensionUnitSymbol(product.id_unidad_dimension)}'
                            : 'N/A',
                      ),
                      _buildDetailRow(
                        'Código Barras:',
                        product.codigoBarra ?? 'N/A',
                      ),
                    ],
                  ),
                ),
              ),
              Container(
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

  Widget _buildDetailRow(String title, String value) {
    return Padding(
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
  // --- Fin Popup ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoadingProducts
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
              ),
            )
          : _errorLoading != null
          ? _buildErrorWidget(_errorLoading!)
          : Column(
              children: [
                _buildHeader(), // Contiene el botón de búsqueda
                // --- ¡NUEVO! Muestra la barra de búsqueda si está visible ---
                if (_isSearchVisible) _buildSearchBar(),

                _buildFilterControls(), // Barra de Filtros de Categoría

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

  // --- Widgets de UI ---

  Widget _buildErrorWidget(String errorMsg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
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
              onPressed: _loadInitialData,
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

  // --- ¡ACTUALIZADO! ---
  // Se movió el total a la izquierda y se añadió el botón de búsqueda
  Widget _buildHeader() {
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
          // Total y Items a la izquierda
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  color: chazkyWhite.withOpacity(0.8),
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                ),
              ),
            ],
          ),
          // Botón de Búsqueda a la derecha
          IconButton(
            icon: Icon(
              _isSearchVisible ? Icons.close : Icons.search,
              color: chazkyWhite,
            ),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                // Si se está ocultando la barra, limpia el texto y filtra de nuevo
                if (!_isSearchVisible && _searchController.text.isNotEmpty) {
                  _searchController
                      .clear(); // Esto dispara el listener y llama a _onFilterChanged
                }
              });
            },
            tooltip: 'Buscar por nombre o marca',
          ),
        ],
      ),
    );
  }

  // --- ¡NUEVO! Widget de Barra de Búsqueda ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 4.0),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: chazkyWhite, fontFamily: 'Montserrat'),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o marca...',
          hintStyle: TextStyle(
            color: chazkyWhite.withOpacity(0.5),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: chazkyWhite.withOpacity(0.7),
            size: 20,
          ),
          filled: true,
          fillColor: mediumDarkBlue.withOpacity(0.5),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            vertical: 12.0,
            horizontal: 12.0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.white24, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.white24, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: chazkyGold, width: 1.5),
          ),
          // Botón para limpiar el texto
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.white54, size: 20),
                  onPressed: () {
                    _searchController.clear(); // Dispara el listener y filtra
                  },
                )
              : null,
        ),
      ),
    );
  }
  // --- Fin Nuevo ---

  Widget _buildFilterControls() {
    // ... (sin cambios) ...
    if (_isLoadingCategories) {
      return Container(
        height: 50,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: chazkyGold),
          ),
        ),
      );
    }
    if (_categories.isEmpty) return SizedBox.shrink();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      color: primaryDarkBlue.withAlpha(200),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: _categories.length + 1, // +1 "Todas"
        itemBuilder: (context, index) {
          final bool isAllChip = index == 0;
          final String categoryName = isAllChip
              ? 'Todas'
              : _categories[index - 1]['nombre_categoria'] ?? 'N/A';
          final String? categoryId = isAllChip
              ? null
              : _categories[index - 1]['id_categoria']?.toString();
          final bool isSelected = _selectedCategoryId == categoryId;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(categoryName),
              selected: isSelected,
              onSelected: (selected) {
                // Actualiza el estado Y llama al filtro
                setState(() {
                  _selectedCategoryId = categoryId;
                });
                _onFilterChanged();
              },
              backgroundColor: mediumDarkBlue.withOpacity(0.5),
              selectedColor: chazkyGold,
              labelStyle: TextStyle(
                color: isSelected ? primaryDarkBlue : chazkyWhite,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Montserrat',
              ),
              side: BorderSide(color: isSelected ? chazkyGold : Colors.white30),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductList() {
    // ... (sin cambios) ...
    if (_filteredProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                color: chazkyWhite.withOpacity(0.5),
                size: 60,
              ),
              SizedBox(height: 16),
              Text(
                _selectedCategoryId == null && _searchController.text.isEmpty
                    ? 'No hay productos disponibles.'
                    : 'No se encontraron productos\ncon esos filtros.', // Mensaje más específico
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: chazkyWhite.withOpacity(0.7),
                  fontSize: 18,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _filteredProducts.length,
      itemBuilder: (ctx, index) {
        final product = _filteredProducts[index];
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
