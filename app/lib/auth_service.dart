// lib/auth_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum para los roles (más seguro que strings)
enum UserRole { cliente, admin, repartidor, unknown }

class AuthService with ChangeNotifier {
  String? _token;
  String? _userId;
  UserRole _userRole = UserRole.unknown; // <-- NUEVO: Almacena el rol
  bool _isLoading = true;

  bool get isAuthenticated => _token != null;
  String? get token => _token;
  String? get userId => _userId;
  UserRole get userRole => _userRole; // <-- NUEVO: Getter para el rol
  bool get isLoading => _isLoading;

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    final extractedUserData =
        json.decode(prefs.getString('userData')!) as Map<String, dynamic>;

    _token = extractedUserData['token'];
    _userId = extractedUserData['userId'];
    _userRole = _parseRole(
      extractedUserData['role'],
    ); // <-- NUEVO: Carga el rol
    _isLoading = false;
    notifyListeners();
  }

  // Modifica signIn para aceptar y guardar el rol
  Future<void> signIn(String user, String id, String roleString) async {
    _token = user;
    _userId = id;
    _userRole = _parseRole(roleString); // <-- NUEVO: Guarda el rol
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userData = json.encode({
      'token': _token,
      'userId': _userId,
      'role': roleString, // <-- NUEVO: Guarda el rol como string
    });
    await prefs.setString('userData', userData);
  }

  Future<void> signOut() async {
    _token = null;
    _userId = null;
    _userRole = UserRole.unknown; // <-- NUEVO: Resetea el rol
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
  }

  // Helper para convertir el string del rol a nuestro Enum
  UserRole _parseRole(String? roleString) {
    switch (roleString?.toLowerCase()) {
      case 'cliente':
        return UserRole.cliente;
      case 'admin':
        return UserRole.admin;
      case 'repartidor':
        return UserRole.repartidor;
      default:
        return UserRole.unknown; // O UserRole.cliente por defecto
    }
  }
}
