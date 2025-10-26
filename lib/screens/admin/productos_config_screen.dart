// lib/screens/admin/productos_config_screen.dart

import 'package:flutter/material.dart';
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

  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts(forceRefresh: true);
  }

  Future<void> _loadProducts({bool forceRefresh = false}) async {
    // No refresca si ya está cargando, a menos que se fuerce
    if (_isLoading && !forceRefresh) return;

    setState(() {
      _isLoading = true;
      _error = null; // Limpia errores previos
    });

    try {
      final productData = await API.getProductos();
      final loadedProducts = productData
          .map((item) => Product.fromJson(item))
          .toList();
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
          _error = 'Error al cargar productos: ${e.toString()}';
        });
      }
    }
  }

  // Navega a la pantalla de edición (para añadir o editar)
  Future<void> _navigateEditScreen([Product? product]) async {
    // Espera el resultado de la pantalla de edición
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (ctx) => ProductEditScreen(product: product)),
    );

    // Si la pantalla de edición devolvió 'true' (indicando éxito), recarga la lista
    if (result == true && mounted) {
      _loadProducts(forceRefresh: true);
    }
  }

  // Función para confirmar y eliminar un producto
  Future<void> _deleteProduct(String productId) async {
    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: mediumDarkBlue,
        title: Text(
          'Confirmar Eliminación',
          style: TextStyle(color: chazkyWhite),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar este producto?',
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

    if (confirm != true) return; // Si no confirma, no hacer nada

    setState(() => _isLoading = true); // Muestra loader mientras elimina

    try {
      final response = await API.eliminarProducto(productId);
      if (mounted) {
        if (response['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Producto eliminado.'),
              backgroundColor: Colors.orange,
            ),
          );
          // Elimina el producto de la lista localmente para reflejar el cambio al instante
          setState(() {
            _products.removeWhere((p) => p.id == productId);
            _isLoading = false;
          });
          // Podrías llamar a _loadProducts(forceRefresh: true) pero quitarlo localmente es más rápido
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
              'Error al eliminar: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Hereda el gradiente del HomeScreen
      body: RefreshIndicator(
        // Permite "pull to refresh"
        onRefresh: () => _loadProducts(forceRefresh: true),
        color: chazkyGold,
        backgroundColor: mediumDarkBlue,
        child:
            _isLoading &&
                _products
                    .isEmpty // Muestra loader solo al inicio
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
                ),
              )
            : _error != null
            ? _buildErrorWidget(_error!) // Muestra mensaje de error
            : _products.isEmpty
            ? _buildEmptyListWidget() // Muestra mensaje si la lista está vacía
            : _buildProductListView(), // Muestra la lista de productos
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _navigateEditScreen(), // Navega para añadir nuevo producto
        backgroundColor: chazkyGold,
        foregroundColor: primaryDarkBlue,
        child: Icon(Icons.add),
        tooltip: 'Añadir Producto',
      ),
    );
  }

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
              onPressed: () => _loadProducts(forceRefresh: true),
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
            Icons.inventory_2_outlined,
            color: chazkyWhite.withOpacity(0.5),
            size: 80,
          ),
          SizedBox(height: 20),
          Text(
            'No hay productos cargados',
            style: TextStyle(
              color: chazkyWhite.withOpacity(0.7),
              fontSize: 20,
              fontFamily: 'Montserrat',
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Usa el botón (+) para añadir el primero.',
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

  Widget _buildProductListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _products.length,
      itemBuilder: (ctx, index) {
        final product = _products[index];
        final imageUrl = product.imagenUrl; // Ya está completa desde el modelo

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
                // ClipRRect para bordes redondeados
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
              mainAxisSize: MainAxisSize
                  .min, // Para que los botones no ocupen toda la fila
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: chazkyGold),
                  onPressed: () =>
                      _navigateEditScreen(product), // Navega para editar
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () =>
                      _deleteProduct(product.id), // Llama a eliminar
                  tooltip: 'Eliminar',
                ),
              ],
            ),
            onTap: () =>
                _navigateEditScreen(product), // Tocar el item también edita
          ),
        );
      },
    );
  }
}
