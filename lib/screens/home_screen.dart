// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Importa TODAS las pantallas posibles
import 'cliente/user_profile_screen.dart';
import 'cliente/productos_screen.dart';
import 'admin/ventas_screen.dart';
import 'admin/ajustes_admin_screen.dart';
import 'admin/logistica_screen.dart';
import 'repartidor/ruta_pedido_screen.dart';
import 'repartidor/hoja_ruta_diaria_screen.dart';
import 'admin/usuario_admin_screen.dart';
import 'admin/usuario_edit_screen.dart';
import 'admin/productos_config_screen.dart';

import '../auth_service.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  int _selectedIndex = 0;

  // --- Definiciones específicas por rol ---
  // Cliente
  static const List<Widget> _clienteWidgetOptions = <Widget>[
    ProductosScreen(),
    UserProfileScreen(),
  ];
  static const List<String> _clienteAppBarTitles = <String>[
    'Productos',
    'Mi Perfil',
  ];
  static const List<BottomNavigationBarItem> _clienteNavItems =
      <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart_outlined),
          activeIcon: Icon(Icons.shopping_cart),
          label: 'Productos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ];

  // Admin
  static final List<Widget> _adminWidgetOptions = <Widget>[
    UsuariosAdminScreen(),
    VentasScreen(),
    ProductosConfigScreen(),
    AjustesAdminScreen(),
    LogisticaScreen(),
  ];
  static const List<String> _adminAppBarTitles = <String>[
    'Usuarios',
    'Ventas',
    'Productos',
    'Ajustes',
    'Logística',
  ];
  static const List<BottomNavigationBarItem> _adminNavItems =
      <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Usuarios',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.point_of_sale_outlined),
          activeIcon: Icon(Icons.point_of_sale),
          label: 'Ventas',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          activeIcon: Icon(Icons.inventory_2),
          label: 'Productos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Ajustes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_shipping_outlined),
          activeIcon: Icon(Icons.local_shipping),
          label: 'Logística',
        ),
      ];

  // Repartidor
  static final List<Widget> _repartidorWidgetOptions = <Widget>[
    HojaRutaDiariaScreen(),
    RutaPedidoScreen(),
  ];
  static const List<String> _repartidorAppBarTitles = <String>[
    'Hoja de Ruta Diaria',
    'Ruta del Pedido',
  ];
  static const List<BottomNavigationBarItem> _repartidorNavItems =
      <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.list_outlined),
          activeIcon: Icon(Icons.list),
          label: 'Hoja de Ruta Diaria',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.route_outlined),
          activeIcon: Icon(Icons.route),
          label: 'Ruta',
        ),
      ];
  // --- Fin Definiciones ---

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos el rol del AuthService
    final userRole = Provider.of<AuthService>(context, listen: false).userRole;

    // Variables para almacenar las opciones según el rol
    List<Widget> currentWidgetOptions;
    List<String> currentAppBarTitles;
    List<BottomNavigationBarItem> currentNavItems;

    // Seleccionamos las opciones correctas usando un switch
    switch (userRole) {
      case UserRole.admin:
        currentWidgetOptions = _adminWidgetOptions;
        currentAppBarTitles = _adminAppBarTitles;
        currentNavItems = _adminNavItems;
        break;
      case UserRole.repartidor:
        currentWidgetOptions = _repartidorWidgetOptions;
        currentAppBarTitles = _repartidorAppBarTitles;
        currentNavItems = _repartidorNavItems;
        break;
      case UserRole.cliente:
      default: // Por defecto, mostramos la vista de cliente
        currentWidgetOptions = _clienteWidgetOptions;
        currentAppBarTitles = _clienteAppBarTitles;
        currentNavItems = _clienteNavItems;
        break;
    }

    // Asegurarnos de que el índice seleccionado no esté fuera de rango si cambian las opciones
    if (_selectedIndex >= currentNavItems.length) {
      _selectedIndex = 0;
    }

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
            // Usamos el título correspondiente al rol y al índice
            currentAppBarTitles[_selectedIndex],
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all<Color>(chazkyWhite),
              ),
              onPressed: () {
                Provider.of<AuthService>(context, listen: false).signOut();
                // Opcional: navegar explícitamente a Login si el Consumer no lo hace
                // Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
              },
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: currentNavItems, // Usamos los items correspondientes al rol
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: primaryDarkBlue.withOpacity(0.8),
          selectedItemColor: chazkyGold,
          unselectedItemColor: chazkyWhite.withOpacity(0.7),
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
          unselectedLabelStyle: TextStyle(fontFamily: 'Montserrat'),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        body: Center(
          // Mostramos el widget correspondiente al rol y al índice
          child: currentWidgetOptions.elementAt(_selectedIndex),
        ),
      ),
    );
  }
}
