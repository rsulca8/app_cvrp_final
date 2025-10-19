// lib/screens/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../api.dart';
import '../models/product_model.dart';
import '../auth_service.dart';
import './home_screen.dart'; // Para volver al Home

class CheckoutScreen extends StatefulWidget {
  static const routeName = '/checkout';

  final List<CartItem> pedidoItems;
  final double total;

  const CheckoutScreen({
    Key? key,
    required this.pedidoItems,
    required this.total,
  }) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true; // Inicia en true para cargar datos del usuario

  // Controladores para el formulario
  final _nombreC = TextEditingController();
  final _apellidoC = TextEditingController();
  final _telefonoC = TextEditingController();
  final _emailC = TextEditingController();
  final _direccionC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Precarga el formulario con los datos del usuario logueado
  Future<void> _loadUserData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userData = await API.getUserInfo(authService.token!);

      if (mounted) {
        setState(() {
          _nombreC.text = userData['nombre'] ?? '';
          _apellidoC.text = userData['apellido'] ?? '';
          _emailC.text = userData['email'] ?? '';
          // Asume que 'telefono' puede venir de la API, si no, déjalo vacío
          _telefonoC.text = userData['telefono'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      // No es crítico si falla, el usuario puede llenarlo manualmente
    }
  }

  // Esta es la lógica que movimos de pedido_screen
  Future<void> _enviarPedido() async {
    // 1. Validar el formulario
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Por favor, completa todos los campos requeridos.');
      return;
    }

    // 2. Validar dirección (simple)
    if (_direccionC.text.isEmpty) {
      _showErrorDialog('Por favor, ingresa una dirección de entrega.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = json.decode(prefs.getString('userData')!);
      final fechaEnvio = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(DateTime.now());

      // 3. Construir el encabezado con los datos del formulario
      final encabezado = {
        'id_cliente': userData['userId'],
        'fecha_hora_pedido': fechaEnvio,
        'total_pedido': widget.total,
        // --- ¡NUEVOS DATOS DEL FORMULARIO! ---
        'nombre_cliente': _nombreC.text,
        'apellido_cliente': _apellidoC.text,
        'telefono_cliente': _telefonoC.text,
        'email_cliente': _emailC.text,
        'direccion_entrega': _direccionC.text,
      };

      // 4. Construir los detalles
      final detalles = widget.pedidoItems
          .map(
            (item) => {
              'id_producto': item.product.id,
              'producto_precio_venta': item.product.precio,
              'cantidad': item.quantity,
            },
          )
          .toList();

      // 5. Enviar a la API
      // (Asegúrate de que tu API.enviarPedido ahora acepte estos nuevos campos)
      await API.enviarPedido(encabezado, detalles);

      // 6. Limpiar el carrito local
      await prefs.remove('pedido');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Pedido enviado con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        // 7. Volver hasta el Home
        Navigator.of(
          context,
        ).popUntil(ModalRoute.withName(HomeScreen.routeName));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Error al enviar el pedido. Intenta de nuevo.');
      }
    }
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // --- Placeholder para la función del mapa ---
  void _openMap() {
    // Aquí iría la lógica para abrir Google Maps
    _showErrorDialog('La selección por mapa no está implementada aún.');
    // TODO: Implementar google_maps_flutter
  }

  @override
  void dispose() {
    _nombreC.dispose();
    _apellidoC.dispose();
    _telefonoC.dispose();
    _emailC.dispose();
    _direccionC.dispose();
    super.dispose();
  }

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
            'Finalizar Pedido',
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
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderSummary(),
                      SizedBox(height: 30),
                      _buildSectionTitle('Datos de Contacto'),
                      _buildTextFormField(
                        _nombreC,
                        'Nombre',
                        Icons.person_outline,
                      ),
                      _buildTextFormField(
                        _apellidoC,
                        'Apellido',
                        Icons.badge_outlined,
                      ),
                      _buildTextFormField(
                        _telefonoC,
                        'Teléfono',
                        Icons.phone_outlined,
                        TextInputType.phone,
                      ),
                      _buildTextFormField(
                        _emailC,
                        'Email',
                        Icons.email_outlined,
                        TextInputType.emailAddress,
                      ),
                      SizedBox(height: 30),
                      _buildSectionTitle('Dirección de Entrega'),
                      _buildTextFormField(
                        _direccionC,
                        'Ingresa tu dirección',
                        Icons.home_outlined,
                      ),
                      TextButton.icon(
                        onPressed: _openMap,
                        icon: Icon(Icons.map_outlined, color: chazkyGold),
                        label: Text(
                          'Seleccionar en el mapa',
                          style: TextStyle(
                            color: chazkyGold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        // Botón de confirmar en la parte inferior
        bottomNavigationBar: _buildConfirmButton(),
      ),
    );
  }

  // --- Widgets de UI ---

  Widget _buildConfirmButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryDarkBlue,
        border: Border(top: BorderSide(color: Colors.white24, width: 0.5)),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: chazkyGold,
          minimumSize: Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
          foregroundColor: primaryDarkBlue,
        ),
        onPressed: _enviarPedido,
        child: _isLoading
            ? CircularProgressIndicator(color: primaryDarkBlue)
            : Text('Confirmar y Enviar Pedido'),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: chazkyWhite,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Montserrat',
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      color: mediumDarkBlue.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.white24, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Resumen del Pedido',
              style: TextStyle(
                color: chazkyWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
            Divider(color: Colors.white24, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total de items:',
                  style: TextStyle(
                    color: chazkyWhite.withOpacity(0.7),
                    fontFamily: 'Montserrat',
                  ),
                ),
                Text(
                  '${widget.pedidoItems.length}',
                  style: TextStyle(
                    color: chazkyWhite,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monto Total:',
                  style: TextStyle(
                    color: chazkyWhite.withOpacity(0.7),
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                  ),
                ),
                Text(
                  '\$${widget.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: chazkyGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper para los campos de texto
  Widget _buildTextFormField(
    TextEditingController controller,
    String label,
    IconData icon, [
    TextInputType keyboardType = TextInputType.text,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: chazkyWhite, fontFamily: 'Montserrat'),
        decoration: InputDecoration(
          filled: true,
          fillColor: mediumDarkBlue.withOpacity(0.7),
          prefixIcon: Icon(icon, color: chazkyWhite.withOpacity(0.8)),
          labelText: label,
          labelStyle: TextStyle(color: chazkyWhite.withOpacity(0.5)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white24),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: chazkyGold, width: 2),
          ),
          errorStyle: TextStyle(
            color: Colors.yellowAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Este campo es requerido';
          }
          if (label == 'Email' && !value.contains('@')) {
            return 'Por favor, ingresa un email válido.';
          }
          return null;
        },
      ),
    );
  }
}
