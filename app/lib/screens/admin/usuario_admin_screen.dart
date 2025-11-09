// lib/screens/admin/usuarios_admin_screen.dart

import 'package:flutter/material.dart';
import '../../api.dart';
import './usuario_edit_screen.dart'; // Importa la pantalla de edición/creación

class UsuariosAdminScreen extends StatefulWidget {
  static const routeName = '/admin/usuarios';

  @override
  _UsuariosAdminScreenState createState() => _UsuariosAdminScreenState();
}

class _UsuariosAdminScreenState extends State<UsuariosAdminScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _usuarios = []; // Lista completa de usuarios
  List<Map<String, dynamic>> _filteredUsuarios = []; // Lista filtrada

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsuarios();
    _searchController.addListener(_filterUsuarios);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterUsuarios);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsuarios({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await API.getAllUsuarios();
      if (!mounted) return;

      if (response['status'] == 'success' && response['usuarios'] is List) {
        final loadedUsuarios = List<Map<String, dynamic>>.from(
          response['usuarios'],
        );
        setState(() {
          _usuarios = loadedUsuarios;
          _filteredUsuarios = loadedUsuarios; // Inicialmente muestra todos
          _isLoading = false;
          _filterUsuarios(); // Aplica filtro (en caso de que haya texto)
        });
      } else {
        throw Exception(response['message'] ?? 'Error al obtener usuarios.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Error: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  // Filtra la lista de usuarios
  void _filterUsuarios() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      if (searchTerm.isEmpty) {
        _filteredUsuarios = List.from(_usuarios);
      } else {
        _filteredUsuarios = _usuarios.where((user) {
          final nombreCompleto = '${user['nombre']} ${user['apellido']}'
              .toLowerCase();
          final usuario = user['usuario']?.toString().toLowerCase() ?? '';
          final email = user['email']?.toString().toLowerCase() ?? '';
          return nombreCompleto.contains(searchTerm) ||
              usuario.contains(searchTerm) ||
              email.contains(searchTerm);
        }).toList();
      }
    });
  }

  // Navega a la pantalla de edición
  Future<void> _navigateEditScreen([Map<String, dynamic>? usuario]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => UsuarioEditScreen(
          // Pasa los datos del usuario si se está editando
          usuarioData: usuario,
        ),
      ),
    );
    // Si la pantalla de edición/creación devolvió 'true', recarga la lista
    if (result == true && mounted) {
      _loadUsuarios(forceRefresh: true);
    }
  }

  // Icono y color por tipo de usuario
  IconData _getIconForRole(String tipo) {
    switch (tipo) {
      case 'Admin':
        return Icons.admin_panel_settings;
      case 'Repartidor':
        return Icons.local_shipping;
      case 'Cliente':
      default:
        return Icons.person;
    }
  }

  Color _getColorForRole(String tipo) {
    switch (tipo) {
      case 'Admin':
        return Colors.redAccent[400]!;
      case 'Repartidor':
        return chazkyGold;
      case 'Cliente':
      default:
        return chazkyWhite.withOpacity(0.7);
    }
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
            'Gestión de Usuarios',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadUsuarios(forceRefresh: true),
                color: chazkyGold,
                backgroundColor: mediumDarkBlue,
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
                        ),
                      )
                    : _error != null
                    ? _buildErrorWidget(_error!)
                    : _buildUsuarioList(),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () =>
              _navigateEditScreen(), // Llama sin datos para "Crear"
          backgroundColor: chazkyGold,
          foregroundColor: primaryDarkBlue,
          child: Icon(Icons.add),
          tooltip: 'Añadir Usuario',
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String errorMsg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, color: Colors.redAccent, size: 60),
            SizedBox(height: 15),
            Text(
              errorMsg,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: chazkyWhite.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 25),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Reintentar'),
              onPressed: () => _loadUsuarios(forceRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumDarkBlue,
                foregroundColor: chazkyWhite,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 12.0),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: chazkyWhite, fontFamily: 'Montserrat'),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, usuario o email...',
          hintStyle: TextStyle(
            color: chazkyWhite.withOpacity(0.5),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: chazkyWhite.withOpacity(0.7),
            size: 20,
          ),
          filled: true,
          fillColor: mediumDarkBlue.withOpacity(0.5),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            vertical: 12.0,
            horizontal: 12.0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.white24, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.white24, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: chazkyGold, width: 1.5),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.white54, size: 20),
                  onPressed: () => _searchController.clear(),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildUsuarioList() {
    if (_filteredUsuarios.isEmpty) {
      return Center(
        child: Text(
          _usuarios.isEmpty
              ? 'No hay usuarios registrados.'
              : 'No se encontraron usuarios.',
          style: TextStyle(color: chazkyWhite.withOpacity(0.7), fontSize: 18),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _filteredUsuarios.length,
      itemBuilder: (ctx, index) {
        final usuario = _filteredUsuarios[index];
        final tipo = usuario['tipo_usuario'] ?? 'Cliente';
        final activo = (usuario['activo'] ?? 1) == 1;

        return Card(
          color: mediumDarkBlue.withOpacity(0.5),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(
              color: activo ? Colors.white24 : Colors.redAccent,
              width: 0.5,
            ),
          ),
          child: Opacity(
            // Atenúa usuarios inactivos
            opacity: activo ? 1.0 : 0.5,
            child: ListTile(
              leading: Icon(
                _getIconForRole(tipo),
                color: _getColorForRole(tipo),
              ),
              title: Text(
                '${usuario['nombre']} ${usuario['apellido']} (${usuario['usuario']})',
                style: TextStyle(
                  color: chazkyWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                usuario['email'] ?? 'Sin email',
                style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
              ),
              trailing: IconButton(
                icon: Icon(Icons.edit_outlined, color: chazkyGold),
                onPressed: () => _navigateEditScreen(usuario),
                tooltip: 'Editar Usuario',
              ),
              onTap: () => _navigateEditScreen(usuario),
            ),
          ),
        );
      },
    );
  }
}
