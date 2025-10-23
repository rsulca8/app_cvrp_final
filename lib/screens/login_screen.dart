// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart'; // Nuestra API simulada
import '../auth_service.dart'; // Nuestro servicio de autenticación
import 'create_user_screen.dart'; // La pantalla de registro

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Colores definidos para la paleta de Chazky
  static const Color primaryDarkBlue = Color(
    0xFF1A202C,
  ); // Color más oscuro del gradiente
  static const Color mediumDarkBlue = Color(
    0xFF2D3748,
  ); // Color intermedio del gradiente
  static const Color chazkyGold = Color(0xFFD4AF37); // Dorado del logo
  static const Color chazkyWhite = Colors.white; // Blanco para perfil y texto

  Future<void> _loginCheck() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final resp = await API.checkLogin(
        _userController.text,
        _passwordController.text,
      );

      switch (resp['resp']) {
        case 'OK':
          final userData = await API.getUserInfo(_userController.text);
          // Asume que tu API devuelve 'tipo_usuario'
          final String userRoleString =
              userData['tipo_usuario'] ?? 'Cliente'; // Rol por defecto
          Provider.of<AuthService>(context, listen: false).signIn(
            userData['usuario']!,
            userData['id']!.toString(),
            userRoleString,
          ); // <-- Pasar el rol
          break;
        case 'contraseña incorrecta':
          _showErrorDialog('Contraseña incorrecta.');
          break;
        case 'usuario incorrecto':
          _showErrorDialog('Usuario incorrecto.');
          break;
        default:
          _showErrorDialog('Error desconocido en el login.');
          break;
      }
    } catch (e) {
      _showErrorDialog('No se pudo conectar al servidor. Intenta de nuevo.');
      print('Error de login: $e'); // Para depuración
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _goToCreateUser() {
    Navigator.of(context).pushNamed(CreateUserScreen.routeName);
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos la altura total de la pantalla
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [mediumDarkBlue, primaryDarkBlue],
          ),
        ),
        child: SafeArea(
          // Envuelve SingleChildScrollView en un LayoutBuilder
          // para que el SingleChildScrollView sepa su altura máxima.
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                // Aquí usamos la altura máxima disponible
                // `constraints.maxHeight` para que ocupe todo el espacio.
                // Si el contenido es más pequeño que la pantalla, se centrará.
                // Si es más grande, permitirá el scroll.
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints
                        .maxHeight, // Hace que ocupe al menos toda la altura disponible
                  ),
                  child: IntrinsicHeight(
                    // Ajusta la altura de la columna a su contenido
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center, // Centra verticalmente
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Usamos Spacer para empujar el contenido hacia el centro vertical.
                          // Si el contenido se hace más grande, los SizedBox se expandirán.
                          Spacer(),

                          // Logo de Chazky
                          Image.asset(
                            'assets/images/chazky_logo2.png',
                            height: 120,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Chazky',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: chazkyWhite,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 50),

                          // Campo de Usuario
                          _buildTextField(
                            controller: _userController,
                            hintText: 'Usuario',
                            icon: Icons.person,
                          ),
                          SizedBox(height: 20),

                          // Campo de Contraseña
                          _buildTextField(
                            controller: _passwordController,
                            hintText: 'Contraseña',
                            isObscure: true,
                            icon: Icons.lock,
                          ),
                          SizedBox(height: 50),

                          _isLoading
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    chazkyGold,
                                  ),
                                )
                              : Column(
                                  children: [
                                    // Botón Iniciar Sesión
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: chazkyGold,
                                        minimumSize: Size(double.infinity, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        textStyle: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Montserrat',
                                        ),
                                        foregroundColor: primaryDarkBlue,
                                      ),
                                      onPressed: _loginCheck,
                                      child: Text('Iniciar Sesión'),
                                    ),
                                    SizedBox(height: 20),

                                    // Botón Crear Usuario
                                    TextButton(
                                      onPressed: _goToCreateUser,
                                      child: Text(
                                        'Crear Usuario',
                                        style: TextStyle(
                                          color: chazkyWhite.withOpacity(0.8),
                                          fontSize: 16,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                          Spacer(), // Otro Spacer para centrar
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Widget helper para no repetir código de los inputs
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool isObscure = false,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: mediumDarkBlue.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        maxLength: 8,
        style: TextStyle(color: chazkyWhite, fontFamily: 'Montserrat'),
        decoration: InputDecoration(
          prefixIcon: icon != null
              ? Icon(icon, color: chazkyWhite.withOpacity(0.8))
              : null,
          hintText: hintText,
          hintStyle: TextStyle(
            color: chazkyWhite.withOpacity(0.5),
            fontFamily: 'Montserrat',
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }
}
