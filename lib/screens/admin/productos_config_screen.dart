// lib/screens/admin/productos_config_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert'; // Importado para jsonDecode
import '../../models/product_model.dart';
import '../../api.dart';
import './product_edit_screen.dart'; // Importa la pantalla de edición

class ProductosConfigScreen extends StatefulWidget {
  @override
  _ProductosConfigScreenState createState() => _ProductosConfigScreenState();
}

class _ProductosConfigScreenState extends State<ProductosConfigScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  // Estados de Datos
  List<Product> _products = []; // Lista completa
  List<Product> _filteredProducts = []; // Lista para mostrar
  bool _isLoading = true;
  String? _error;

  // --- Estados de Filtro y Búsqueda ---
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId; // null = "Todas"
  bool _isLoadingCategories = true;
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  // --- Fin Estados ---

  @override
  void initState() {
    super.initState();
    _loadInitialData(forceRefresh: true);
    // Listener para actualizar la lista al escribir
    _searchController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onFilterChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _isLoadingCategories = true; // Inicia carga de categorías
    });

    try {
      // Carga productos y categorías en paralelo
      final results = await Future.wait([
        API.getProductos(),
        API.getCategorias(),
      ]);

      final productData = results[0] as List<dynamic>;
      final categoriesData = results[1] as List<dynamic>;

      final loadedProducts = productData
          .where((item) => item is Map<String, dynamic>)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _products = loadedProducts;
          _categories = List<Map<String, dynamic>>.from(categoriesData);
          _isLoading = false;
          _isLoadingCategories = false;
          _onFilterChanged(); // Aplica el filtro inicial (todos)
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingCategories = false;
          _error =
              'Error al cargar datos: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    }
  }

  // Lógica unificada para filtrar y buscar
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

      // 2. Filtrar por Término de Búsqueda
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

  // Navega a la pantalla de edición
  Future<void> _navigateEditScreen([Product? product]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (ctx) => ProductEditScreen(product: product)),
    );
    if (result == true && mounted) {
      _loadInitialData(forceRefresh: true); // Recarga todo al volver
    }
  }

  // Función para confirmar y eliminar un producto
  Future<void> _deleteProduct(String productId, String productName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: mediumDarkBlue,
        title: Text(
          'Confirmar Eliminación',
          style: TextStyle(color: chazkyWhite),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar "$productName"? Esta acción no se puede deshacer.',
          style: TextStyle(color: chazkyWhite.withOpacity(0.8)),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Muestra un loader de "eliminando"
    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(
      SnackBar(
        content: Text('Eliminando "$productName"...'),
        duration: Duration(
          seconds: 10,
        ), // Duración larga, se ocultará manualmente
      ),
    );

    try {
      final response = await API.eliminarProducto(productId);
      snack.hideCurrentSnackBar(); // Oculta "Eliminando..."

      if (mounted) {
        if (response['status'] == 'success') {
          snack.showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Producto eliminado.'),
              backgroundColor: Colors.orange,
            ),
          );
          // Actualiza la UI localmente
          setState(() {
            _products.removeWhere((p) => p.id == productId);
            _onFilterChanged(); // Re-aplica filtros
          });
        } else {
          throw Exception(
            response['message'] ?? 'Error desconocido del servidor.',
          );
        }
      }
    } catch (e) {
      snack.hideCurrentSnackBar(); // Oculta si falla
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al eliminar: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // --- NUEVA AppBar ---
      appBar: AppBar(
        title: Text(
          'Configurar Productos',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: chazkyWhite,
          ),
        ),
        backgroundColor: primaryDarkBlue.withOpacity(
          0.8,
        ), // Coincide con _buildHeader
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isSearchVisible ? Icons.close : Icons.search,
              color: chazkyWhite,
            ),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible && _searchController.text.isNotEmpty) {
                  _searchController.clear(); // Dispara _onFilterChanged
                }
              });
            },
            tooltip: 'Buscar por nombre o marca',
          ),
        ],
      ),
      // --- Fin AppBar ---
      body: Column(
        children: [
          // Muestra la barra de búsqueda si está visible
          if (_isSearchVisible) _buildSearchBar(),

          // Muestra la barra de filtros de categoría
          _buildFilterControls(),

          // Lista de productos (con su propio loader/error/empty)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadInitialData(forceRefresh: true),
              color: chazkyGold,
              backgroundColor: mediumDarkBlue,
              child:
                  _isLoading // Loader principal
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
                      ),
                    )
                  : _error != null
                  ? _buildErrorWidget(_error!)
                  : _buildProductListView(), // Este widget maneja la lista vacía
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateEditScreen(),
        backgroundColor: chazkyGold,
        foregroundColor: primaryDarkBlue,
        child: Icon(Icons.add),
        tooltip: 'Añadir Producto',
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
            Icon(Icons.cloud_off, color: Colors.redAccent, size: 50),
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
              onPressed: () => _loadInitialData(forceRefresh: true),
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
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.white54, size: 20),
                  onPressed: () => _searchController.clear(),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterControls() {
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
    if (_categories.isEmpty)
      return SizedBox.shrink(); // No muestra nada si no hay categorías

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      color: primaryDarkBlue.withAlpha(200), // Fondo sutil
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
                // Llama al filtro unificado al cambiar la selección
                setState(() => _selectedCategoryId = categoryId);
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

  // Widget para la lista vacía (ahora usa _filteredProducts)
  Widget _buildEmptyListWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            color: chazkyWhite.withOpacity(0.5),
            size: 80,
          ),
          SizedBox(height: 20),
          Text(
            // Mensaje dinámico
            _selectedCategoryId == null && _searchController.text.isEmpty
                ? 'No hay productos cargados'
                : 'No se encontraron productos\ncon esos filtros.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: chazkyWhite.withOpacity(0.7),
              fontSize: 20,
              fontFamily: 'Montserrat',
            ),
          ),
          SizedBox(height: 10),
          Text(
            _selectedCategoryId == null && _searchController.text.isEmpty
                ? 'Usa el botón (+) para añadir el primero.'
                : 'Intenta cambiar los filtros o el término de búsqueda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: chazkyWhite.withOpacity(0.5),
              fontSize: 16,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }

  // Widget para la lista (ahora usa _filteredProducts)
  Widget _buildProductListView() {
    // Maneja el estado de "lista vacía" aquí
    if (_filteredProducts.isEmpty) {
      return _buildEmptyListWidget();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _filteredProducts.length, // Usa la lista filtrada
      itemBuilder: (ctx, index) {
        final product = _filteredProducts[index]; // Usa la lista filtrada
        final imageUrl = product.imagenUrl;

        return Card(
          color: mediumDarkBlue.withOpacity(0.5),
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(color: Colors.white24, width: 0.5),
          ),
          child: ListTile(
            leading: SizedBox(
              width: 50,
              height: 50,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: chazkyGold,
                          ),
                        ),
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: primaryDarkBlue,
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
            title: Text(
              product.nombre,
              style: TextStyle(color: chazkyWhite, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Stock: ${product.stock ?? 'N/A'} - \$${product.precio.toStringAsFixed(2)}',
              style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: chazkyGold),
                  onPressed: () => _navigateEditScreen(product),
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteProduct(
                    product.id,
                    product.nombre,
                  ), // Pasa el nombre para el diálogo
                  tooltip: 'Eliminar',
                ),
              ],
            ),
            onTap: () => _navigateEditScreen(product),
          ),
        );
      },
    );
  }
}
