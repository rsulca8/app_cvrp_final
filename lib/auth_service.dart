// lib/auth_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  String? _token;
  String? _userId;
  // Inicia como `true` para mostrar la pantalla de carga al principio.
  bool _isLoading = true;

  bool get isAuthenticated => _token != null;
  String? get token => _token;
  String? get userId => _userId;
  bool get isLoading => _isLoading;

  // Revisa si hay un token guardado en el dispositivo.
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
    _isLoading = false; // Deja de cargar
    notifyListeners(); // Notifica a la UI que el estado cambió
  }

  Future<void> signIn(String user, String id) async {
    _token = user;
    _userId = id;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userData = json.encode({'token': _token, 'userId': _userId});
    await prefs.setString('userData', userData);
  }

  Future<void> signOut() async {
    _token = null;
    _userId = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
  }
}
