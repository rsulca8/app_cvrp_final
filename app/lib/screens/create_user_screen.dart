// lib/screens/create_user_screen.dart

import 'package:flutter/material.dart';
import '../api.dart';

class CreateUserScreen extends StatefulWidget {
  static const routeName = '/create-user';

  @override
  _CreateUserScreenState createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  // Paleta de colores de Chazky para consistencia
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _emailController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Future<void> _submitForm() async {
    // Valida que todos los campos del formulario estén llenos
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Por favor, completa todos los campos.');
      return;
    }

    // Valida que las contraseñas coincidan
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog('Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await API.createUser(
        _nombreController.text,
        _apellidoController.text,
        _emailController.text,
        _usuarioController.text,
        _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Usuario creado con éxito. ¡Ya puedes iniciar sesión!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Vuelve a la pantalla de Login
      }
    } catch (error) {
      _showErrorDialog(
        'Ocurrió un error al crear el usuario. Inténtalo de nuevo.',
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Registro', style: TextStyle(fontFamily: 'Montserrat')),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    SizedBox(height: 20),
                    Text(
                      'Crea tu cuenta',
                      style: TextStyle(
                        color: chazkyWhite,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    SizedBox(height: 30),
                    _buildTextFormField(
                      controller: _nombreController,
                      label: 'Nombre',
                      icon: Icons.badge_outlined,
                    ),
                    _buildTextFormField(
                      controller: _apellidoController,
                      label: 'Apellido',
                      icon: Icons.badge_outlined,
                    ),
                    _buildTextFormField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _buildTextFormField(
                      controller: _usuarioController,
                      label: 'Usuario',
                      icon: Icons.person_outline,
                    ),
                    _buildTextFormField(
                      controller: _passwordController,
                      label: 'Contraseña',
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    _buildTextFormField(
                      controller: _confirmPasswordController,
                      label: 'Confirmar Contraseña',
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    SizedBox(height: 40),
                    if (_isLoading)
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
                      )
                    else
                      Column(
                        children: [
                          ElevatedButton(
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
                            onPressed: _submitForm,
                            child: Text('Crear Cuenta'),
                          ),
                          SizedBox(height: 10),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(), // Vuelve a login
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                color: chazkyWhite.withOpacity(0.8),
                                fontSize: 16,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget helper para no repetir código de los inputs, ahora usando TextFormField
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
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
