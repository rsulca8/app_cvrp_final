// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io'; // Necesario para HttpOverrides

// Importa tus archivos
import 'auth_service.dart';
import 'http_override.dart'; // Archivo para el fix de SSL (ver abajo)
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/create_user_screen.dart';
import 'screens/cliente/pedido_screen.dart';
import 'screens/splash_screen.dart'; // Una pantalla de carga simple

void main() {
  // IMPORTANTE: Esto es para solucionar el error de certificado SSL
  HttpOverrides.global = MyHttpOverrides();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 1. Proveemos la instancia de AuthService a toda la app.
    //    Al crearse, llama inmediatamente a tryAutoLogin() para
    //    verificar si ya existe una sesión.
    return ChangeNotifierProvider(
      create: (ctx) => AuthService()..tryAutoLogin(),
      child: Consumer<AuthService>(
        builder: (ctx, auth, _) => MaterialApp(
          title: 'Chazky',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          // 2. Aquí está la lógica principal
          home: auth.isLoading
              ? SplashScreen() // Si está cargando, muestra la pantalla de carga
              : auth.isAuthenticated
              ? HomeScreen() // Si está autenticado, muestra Home
              : LoginScreen(), // Si no, muestra Login
          // 3. Define el resto de las rutas para la navegación
          routes: {
            LoginScreen.routeName: (ctx) => LoginScreen(),
            HomeScreen.routeName: (ctx) => HomeScreen(),
            CreateUserScreen.routeName: (ctx) => CreateUserScreen(),
            PedidoScreen.routeName: (ctx) => PedidoScreen(),
          },
        ),
      ),
    );
  }
}
