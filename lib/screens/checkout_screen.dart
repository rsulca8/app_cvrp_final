// lib/screens/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:latlong2/latlong.dart'; // Importar LatLng de latlong2

import '../api.dart';
import '../models/product_model.dart';
import '../auth_service.dart';
import './home_screen.dart'; // Para volver al Home
import './map_selection_screen.dart'; // Importar la pantalla del mapa

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

  // Estados para la ubicación seleccionada
  LatLng? _selectedLocation;
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Precarga el formulario con los datos del usuario logueado
  Future<void> _loadUserData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      // Evita llamar a la API si no hay token (aunque no debería pasar aquí)
      if (authService.token == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final userData = await API.getUserInfo(authService.token!);

      if (mounted) {
        setState(() {
          _nombreC.text = userData['nombre'] ?? '';
          _apellidoC.text = userData['apellido'] ?? '';
          _emailC.text = userData['email'] ?? '';
          _telefonoC.text = userData['telefono'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error cargando datos de usuario: $e");
      if (mounted) setState(() => _isLoading = false);
      // Muestra un mensaje si falla, pero permite continuar
      _showErrorDialog(
        'No se pudieron precargar tus datos. Por favor, complétalos manualmente.',
      );
    }
  }

  Future<void> _enviarPedido() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Por favor, completa todos los campos requeridos.');
      return;
    }
    if (_selectedLocation == null || _direccionC.text.isEmpty) {
      _showErrorDialog(
        'Por favor, selecciona una dirección de entrega en el mapa.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('userData');
      if (userDataString == null) {
        throw Exception('No se encontraron datos de sesión del usuario.');
      }
      final userData = json.decode(userDataString);
      final fechaEnvio = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(DateTime.now());

      // --- CONSTRUIR EL PAYLOAD JSON ---
      // Creamos un solo Map que contiene todo
      final Map<String, dynamic> pedidoPayload = {
        // Datos del encabezado
        'id_cliente':
            userData['userId'], // Asegúrate que 'userId' sea la clave correcta
        'fecha_hora_pedido': fechaEnvio,
        'total_pedido': widget.total,
        'nombre_cliente': _nombreC.text,
        'apellido_cliente': _apellidoC.text,
        'telefono_cliente': _telefonoC.text,
        'email_cliente': _emailC.text,
        'direccion_entrega': _direccionC.text,
        'latitud_entrega': _selectedLocation!.latitude,
        'longitud_entrega': _selectedLocation!.longitude,
        // Array de detalles
        'detalles': widget.pedidoItems
            .map(
              (item) => {
                'id_producto': item.product.id,
                'cantidad': item.quantity,
                'producto_precio_venta':
                    item.product.precio, // Precio al momento de la compra
              },
            )
            .toList(),
      };
      // --- FIN PAYLOAD JSON ---

      // --- LLAMAR A LA API ACTUALIZADA ---
      final response = await API.enviarPedido(pedidoPayload);
      // --- FIN LLAMADA API ---

      // --- MANEJAR RESPUESTA ---
      if (response['status'] == 'success') {
        await prefs.remove('pedido'); // Limpia el carrito solo si fue exitoso

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? '¡Pedido enviado con éxito!',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        // Si PHP devolvió status: error
        throw Exception(
          response['message'] ?? 'Error desconocido al procesar el pedido.',
        );
      }
      // --- FIN MANEJO RESPUESTA ---
    } catch (e) {
      print("Error al enviar pedido (catch): $e");
      if (mounted) {
        setState(() => _isLoading = false);
        // Muestra el mensaje de error específico devuelto por la API o el catch
        _showErrorDialog(
          'Error: ${e.toString().replaceFirst("Exception: ", "")}',
        );
      }
    } finally {
      // Asegúrate de que isLoading se ponga en false incluso si hay un error no capturado
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ... (resto del código de checkout_screen: _loadUserData, _showErrorDialog, _openMap, build, etc. sin cambios) ...
  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // --- FUNCIÓN DEL MAPA IMPLEMENTADA ---
  void _openMap() async {
    // 1. Navega a la pantalla del mapa y ESPERA a que regrese un resultado.
    //    'await' pausa la ejecución aquí hasta que MapSelectionScreen llame a Navigator.pop(result).
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      // Especifica el tipo esperado
      MaterialPageRoute(builder: (ctx) => MapSelectionScreen()),
    );

    // 2. Verifica si se recibió un resultado (si el usuario confirmó y no solo cerró la pantalla).
    if (result != null) {
      // 3. Actualiza el estado con los datos recibidos del mapa.
      setState(() {
        // Hacemos un cast seguro al tipo esperado (LatLng de latlong2)
        _selectedLocation = result['location'] as LatLng?;
        _selectedAddress = result['address'] as String?;
        // Actualiza el campo de texto con la dirección obtenida.
        _direccionC.text = _selectedAddress ?? 'Dirección no obtenida';
      });
      // Vuelve a validar el campo de dirección después de seleccionarlo
      _formKey.currentState?.validate();
    } else {
      // Opcional: Mostrar un mensaje si el usuario canceló la selección
      print("Selección de mapa cancelada.");
    }
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
        body:
            _isLoading &&
                _nombreC
                    .text
                    .isEmpty // Muestra loader solo si está cargando datos iniciales
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
                      // Campo de dirección (solo lectura, se llena desde el mapa)
                      TextFormField(
                        controller: _direccionC,
                        readOnly: true,
                        style: TextStyle(
                          color: chazkyWhite,
                          fontFamily: 'Montserrat',
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: mediumDarkBlue.withOpacity(0.7),
                          prefixIcon: Icon(
                            Icons.home_outlined,
                            color: chazkyWhite.withOpacity(0.8),
                          ),
                          labelText: 'Dirección seleccionada en el mapa',
                          labelStyle: TextStyle(
                            color: chazkyWhite.withOpacity(0.5),
                          ),
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
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          errorStyle: TextStyle(
                            color: Colors.yellowAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          // Muestra el hintText si está vacío
                          hintText: _direccionC.text.isEmpty
                              ? 'Toca el botón para seleccionar'
                              : null,
                          hintStyle: TextStyle(
                            color: chazkyWhite.withOpacity(0.4),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, selecciona una dirección en el mapa';
                          }
                          return null;
                        },
                      ),
                      // Botón para abrir el mapa
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextButton.icon(
                          onPressed: _openMap,
                          icon: Icon(Icons.map_outlined, color: chazkyGold),
                          label: Text(
                            'Seleccionar/Cambiar en el mapa',
                            style: TextStyle(
                              color: chazkyGold,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20), // Espacio antes del botón inferior
                    ],
                  ),
                ),
              ),
        // Botón inferior para confirmar
        bottomNavigationBar: _buildConfirmButton(),
      ),
    );
  }

  // --- Widgets de UI (sin cambios significativos) ---

  Widget _buildConfirmButton() {
    return Container(
      // Añade padding inferior basado en el área segura del dispositivo
      padding: EdgeInsets.fromLTRB(
        20,
        15,
        20,
        MediaQuery.of(context).padding.bottom + 15,
      ),
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
          // Deshabilita visualmente el botón si está cargando
          disabledBackgroundColor: chazkyGold.withOpacity(0.5),
        ),
        // onPressed es null si _isLoading es true, deshabilitando el botón
        onPressed: _isLoading ? null : _enviarPedido,
        child: _isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: primaryDarkBlue,
                  strokeWidth: 3,
                ),
              )
            : Text('Confirmar y Enviar Pedido'),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8.0,
        top: 16.0,
      ), // Añade espacio superior también
      child: Text(
        title,
        style: TextStyle(
          color: chazkyWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
        ),
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
          crossAxisAlignment:
              CrossAxisAlignment.start, // Alinea el título a la izquierda
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
                // Calcula la suma total de cantidades de items
                Text(
                  '${widget.pedidoItems.fold<int>(0, (sum, item) => sum + item.quantity)}',
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
          if (label == 'Teléfono' &&
              (value.length < 7 ||
                  !RegExp(
                    r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s\./0-9]*$',
                  ).hasMatch(value))) {
            // Validación más flexible para teléfono
            return 'Ingresa un número válido.';
          }
          return null;
        },
      ),
    );
  }
}
