// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Importamos las pantallas del drawer
import './user_profile_screen.dart';
import './productos_screen.dart';

import '../auth_service.dart'; // Para el botón de logout

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Paleta de colores de Chazky para consistencia
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  int _selectedIndex = 0;

  // Títulos para la AppBar que cambian dinámicamente
  static const List<String> _appBarTitles = <String>['Productos', 'Mi Perfil'];

  static const List<Widget> _widgetOptions = <Widget>[
    ProductosScreen(),
    UserProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.of(context).pop(); // Cierra el drawer
  }

  @override
  Widget build(BuildContext context) {
    // Usamos un Container para aplicar el gradiente a toda la pantalla
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [mediumDarkBlue, primaryDarkBlue],
        ),
      ),
      child: Scaffold(
        // Hacemos el fondo del Scaffold transparente para que se vea el gradiente
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          // La AppBar también transparente y sin sombra
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _appBarTitles[_selectedIndex], // Título dinámico
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: chazkyWhite,
            ),
          ),
        ),
        drawer:
            _buildCustomDrawer(), // Usamos un método para construir el drawer
        body: _widgetOptions.elementAt(_selectedIndex),
      ),
    );
  }

  /// Un método que construye nuestro Drawer con el nuevo estilo.
  Widget _buildCustomDrawer() {
    return Drawer(
      // El fondo del Drawer también debe ser oscuro
      child: Container(
        color: primaryDarkBlue,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            // Cabecera del Drawer con el logo y nombre
            DrawerHeader(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24, width: 0.5),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/chazky_logo2.png', // Asegúrate que esta ruta es correcta
                    height: 60,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Chazky',
                    style: TextStyle(
                      color: chazkyWhite,
                      fontSize: 24,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Items del menú
            _buildDrawerItem(
              icon: Icons.shopping_cart_outlined,
              title: 'Productos',
              index: 0,
              isSelected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            _buildDrawerItem(
              icon: Icons.person_outline,
              title: 'Perfil de Usuario',
              index: 1,
              isSelected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(color: Colors.white24),
            ),
            // Item para cerrar sesión
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'Cerrar Sesión',
              onTap: () {
                Provider.of<AuthService>(context, listen: false).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Widget helper para crear cada item del Drawer y manejar el estado de selección.
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    int? index,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    // Colores basados en si el item está seleccionado o no
    final Color color = isSelected ? chazkyGold : chazkyWhite;
    final Color tileColor = isSelected
        ? chazkyGold.withOpacity(0.15)
        : Colors.transparent;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontFamily: 'Montserrat',
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: tileColor,
      onTap: onTap,
    );
  }
}
