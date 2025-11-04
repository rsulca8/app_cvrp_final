// lib/screens/user_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../auth_service.dart';

class UserProfileScreen extends StatelessWidget {
  static const routeName = '/user-profile';

  // Paleta de colores de Chazky para consistencia
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Obtenemos el AuthService para acceder al nombre de usuario actual
    final authService = Provider.of<AuthService>(context, listen: false);
    final userName = authService.token ?? 'Usuario';

    return Scaffold(
      // Fondo transparente para heredar el gradiente del HomeScreen
      backgroundColor: Colors.transparent,
      body: FutureBuilder<Map<String, dynamic>>(
        // Usamos FutureBuilder para obtener la información completa del usuario desde la API
        future: API.getUserInfo(userName),
        builder: (ctx, snapshot) {
          // Mientras carga, muestra un indicador de progreso dorado
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
              ),
            );
          }

          // Si hay un error de conexión o de API
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    color: chazkyWhite.withOpacity(0.7),
                    size: 50,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Error al cargar el perfil',
                    style: TextStyle(
                      color: chazkyWhite.withOpacity(0.7),
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ],
              ),
            );
          }

          final userData = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                _buildProfileAvatar(userData['foto_perfil'] ?? ''),
                SizedBox(height: 15),
                Text(
                  // Usamos los datos de la API que son más completos
                  '${userData['nombre'] ?? ''} ${userData['apellido'] ?? ''}'
                      .trim(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: chazkyWhite,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                ),
                Text(
                  userData['email'] ?? 'email@ejemplo.com',
                  style: TextStyle(
                    color: chazkyWhite.withOpacity(0.7),
                    fontSize: 16,
                    fontFamily: 'Montserrat',
                  ),
                ),
                SizedBox(height: 40),
                _buildInfoCard(
                  icon: Icons.business_center_outlined,
                  title: 'Razón Social',
                  value: userData['razon_social'] ?? 'No especificada',
                ),
                _buildInfoCard(
                  icon: Icons.person_pin_outlined,
                  title: 'Nombre de Usuario',
                  value: userData['usuario'] ?? 'N/A',
                ),
                // Puedes añadir más tarjetas de información aquí
              ],
            ),
          );
        },
      ),
    );
  }

  /// Widget para construir el avatar del perfil con un borde dorado.
  Widget _buildProfileAvatar(String fotoPerfil) {
    return CircleAvatar(
      radius: 65,
      backgroundColor: chazkyGold, // Color del borde
      child: CircleAvatar(
        radius: 60,
        backgroundImage: NetworkImage(fotoPerfil), // Tu imagen de perfil
        backgroundColor: mediumDarkBlue,
      ),
    );
  }

  /// Widget helper para crear tarjetas de información estilizadas.
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      color: mediumDarkBlue.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.white24, width: 0.5),
      ),
      child: ListTile(
        leading: Icon(icon, color: chazkyGold, size: 30),
        title: Text(
          title,
          style: TextStyle(
            color: chazkyWhite.withOpacity(0.7),
            fontFamily: 'Montserrat',
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            color: chazkyWhite,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
    );
  }
}
