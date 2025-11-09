// lib/models/product_model.dart

class Product {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final double descuentoPorcentaje;
  final String? codigoBarra;
  final String? stock;
  final String marca;
  final String imagenUrl; // Esta será la URL completa
  final String categorias;
  final String? id_categoria;

  // Campos adicionales para la vista de detalle
  final String? peso;
  final String? id_unidad_peso; // Nuevo - ID
  final String? alto;
  final String? ancho;
  final String? profundidad;
  final String? id_unidad_dimension; // Nuevo - ID

  Product({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.descuentoPorcentaje,
    this.codigoBarra,
    this.stock,
    required this.marca,
    required this.imagenUrl,
    required this.categorias,
    required this.id_categoria,
    this.peso,
    this.id_unidad_peso, // Nuevo
    this.alto,
    this.ancho,
    this.profundidad,
    this.id_unidad_dimension, // Nuevo
  });

  // Factory constructor para crear un Product desde un Map (JSON)
  factory Product.fromJson(Map<String, dynamic> json) {
    // Función helper para construir la URL de la imagen de forma segura
    String _buildImageUrl(dynamic imgData) {
      if (imgData == null || imgData == "0" || imgData.toString().isEmpty) {
        return ""; // URL vacía si no hay imagen
      }
      String imgPath = imgData.toString();
      // Si ya es una URL completa (del carrito guardado), la devuelve
      if (imgPath.startsWith("http")) {
        return imgPath;
      }
      // Si es una ruta relativa (de la API o del carrito antiguo), construye la URL
      return "https://149.50.143.81/cvrp${imgPath.replaceAll("https://149.50.143.81/cvrp", "")}";
    }

    return Product(
      // Usamos '??' para ser compatibles con los datos antiguos del carrito
      id: json['id_producto'].toString(),
      nombre: json['nombre'] ?? json['nombre_producto'] ?? 'Sin Nombre',
      descripcion:
          json['descripcion'].toString() ??
          json['nombre'] ??
          json['nombre_producto'] ??
          '',
      precio:
          double.tryParse(
            (json['precio'] ?? json['precio_producto'] ?? '0.0').toString(),
          ) ??
          0.0,
      descuentoPorcentaje:
          double.tryParse(
            (json['descuento_porcentaje'] ??
                    json['descuento_producto'] ??
                    '0.0')
                .toString(),
          ) ??
          0.0,
      codigoBarra: json['codigo_barra'].toString(),
      stock: json['stock'].toString(),
      marca: json['marca'] ?? json['marca_producto'] ?? 'Sin Marca',
      imagenUrl: _buildImageUrl(json['imagen'] ?? json['imagen_producto']),
      categorias: json['nombreCategorias'] ?? 'Sin Categoría',
      id_categoria: json['id_categoria']?.toString(),
      peso: json['peso'].toString(),
      id_unidad_peso: json['id_unidad_peso'].toString(),
      alto: json['alto'].toString(),
      ancho: json['ancho'].toString(),
      profundidad: json['profundidad'].toString(),
      id_unidad_dimension: json['id_unidad_dimension'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_producto': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio.toString(),
      'descuento_porcentaje': descuentoPorcentaje.toString(),
      'codigo_barra': codigoBarra,
      'stock': stock,
      'marca': marca,
      'imagen': imagenUrl,
      'nombreCategorias': categorias,
      'id_categoria': id_categoria,
      'peso': peso,
      'id_unidad_peso': id_unidad_peso,
      'alto': alto,
      'ancho': ancho,
      'profundidad': profundidad,
      'id_unidad_dimension': id_unidad_dimension,
    };
  }
}

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
}
