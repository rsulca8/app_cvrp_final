// lib/models/product_model.dart
class Product {
  final String id;
  final String nombre;
  final String marca;
  final double precio;
  final String descuento;
  final String imagenUrl;

  Product({
    required this.id,
    required this.nombre,
    required this.marca,
    required this.precio,
    required this.descuento,
    required this.imagenUrl,
  });

  // Factory constructor para crear un Product desde un Map (JSON)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id_producto'],
      nombre: json['nombre_producto'],
      marca: json['marca_producto'],
      precio: double.tryParse(json['precio_producto'].toString()) ?? 0.0,
      descuento: json['descuento_producto'],
      imagenUrl: json['imagen_producto'] ?? '',
    );
  }
}
