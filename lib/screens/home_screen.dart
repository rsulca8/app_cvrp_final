// lib/screens/home_screen.dart

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

// Importamos las pantallas
import './user_profile_screen.dart';
import './productos_screen.dart';
import '../auth_service.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Paleta de colores de Chazky
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  int _selectedIndex = 0;

  // Lista de las pantallas que se mostrarán
  static const List<Widget> _widgetOptions = <Widget>[
    ProductosScreen(),
    UserProfileScreen(),
    // Puedes añadir una tercera pantalla si quieres, como "Mis Pedidos"
  ];

  // Títulos para la AppBar
  static const List<String> _appBarTitles = <String>['Productos', 'Mi Perfil'];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
        // La AppBar ahora es más simple y puede mostrar el título de la vista actual
        appBar: AppBar(
          title: Text(
            _appBarTitles[_selectedIndex],
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          // Añadimos un botón de Logout directamente en la AppBar
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () {
                Provider.of<AuthService>(context, listen: false).signOut();
              },
            ),
          ],
        ),
        // Aquí está el cambio principal: usamos bottomNavigationBar
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart), // Icono cuando está activo
              label: 'Productos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          // --- Estilo de la barra de navegación ---
          backgroundColor: primaryDarkBlue.withOpacity(
            0.8,
          ), // Fondo oscuro semi-transparente
          selectedItemColor: chazkyGold, // Color del ítem activo (dorado)
          unselectedItemColor: chazkyWhite.withOpacity(
            0.7,
          ), // Color de ítems inactivos
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
          unselectedLabelStyle: TextStyle(fontFamily: 'Montserrat'),
          elevation: 0, // Sin sombra
          type:
              BottomNavigationBarType.fixed, // Asegura que el fondo sea visible
        ),
        // El body sigue funcionando igual, mostrando la pantalla seleccionada
        body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      ),
    );
  }
}
