// lib/screens/admin/usuario_edit_screen.dart

import 'package:flutter/material.dart';

class UsuarioEditScreen extends StatefulWidget {
  static const routeName = '/admin/edit-usuario';
  final Map<String, dynamic>? usuarioData; // null si es nuevo

  const UsuarioEditScreen({Key? key, this.usuarioData}) : super(key: key);

  @override
  _UsuarioEditScreenState createState() => _UsuarioEditScreenState();
}

class _UsuarioEditScreenState extends State<UsuarioEditScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late bool _isEditing;

  // Controladores
  final _nombreC = TextEditingController();
  final _apellidoC = TextEditingController();
  final _usuarioC = TextEditingController();
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController(); // Para nueva contraseña

  // Valores para tipo de usuario y estado
  String? _selectedTipoUsuario;
  bool _isActive = true;
  final List<String> _tiposUsuario = ['Cliente', 'Repartidor', 'Admin'];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.usuarioData != null;

    if (_isEditing) {
      // Carga datos existentes
      _nombreC.text = widget.usuarioData!['nombre'] ?? '';
      _apellidoC.text = widget.usuarioData!['apellido'] ?? '';
      _usuarioC.text = widget.usuarioData!['usuario'] ?? '';
      _emailC.text = widget.usuarioData!['email'] ?? '';
      _selectedTipoUsuario = widget.usuarioData!['tipo_usuario'] ?? 'Cliente';
      _isActive = (widget.usuarioData!['activo'] ?? 1) == 1;
      // Deja _passwordC vacío (la contraseña solo se actualiza si se escribe)
    } else {
      // Valores por defecto para nuevo usuario
      _selectedTipoUsuario = 'Cliente';
      _isActive = true;
    }
  }

  @override
  void dispose() {
    _nombreC.dispose();
    _apellidoC.dispose();
    _usuarioC.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    final isValid = _formKey.currentState?.validate();
    if (isValid == null || !isValid) return;

    setState(() => _isLoading = true);

    // --- Lógica de Guardado (Placeholder) ---
    // Aquí llamarías a API.crearUsuario o API.actualizarUsuario
    // que aún no has pedido.
    print("--- SIMULANDO GUARDADO ---");
    print("Nombre: ${_nombreC.text}");
    print("Apellido: ${_apellidoC.text}");
    print("Usuario: ${_usuarioC.text}");
    print("Email: ${_emailC.text}");
    print(
      "Password: ${_passwordC.text.isNotEmpty ? '********' : '(Sin cambios)'}",
    );
    print("Tipo: $_selectedTipoUsuario");
    print("Activo: $_isActive");
    print("--- FIN SIMULACIÓN ---");

    // Simula una llamada API
    await Future.delayed(Duration(seconds: 2));

    // Oculta el loader
    if (mounted) setState(() => _isLoading = false);

    // Muestra éxito (simulado)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Simulación: Usuario guardado (función no implementada).',
        ),
        backgroundColor: Colors.blue,
      ),
    );

    // Regresa a la lista (enviando 'true' para recargar)
    Navigator.of(context).pop(true);

    /*
    // --- CÓDIGO REAL (CUANDO LO IMPLEMENTES) ---
    try {
      final data = {
        'nombre': _nombreC.text,
        'apellido': _apellidoC.text,
        'usuario': _usuarioC.text,
        'email': _emailC.text,
        'tipo_usuario': _selectedTipoUsuario,
        'activo': _isActive ? '1' : '0',
        // Solo envía password si se escribió uno nuevo
        if (_passwordC.text.isNotEmpty) 'password': _passwordC.text,
      };

      Map<String, dynamic> response;
      if (_isEditing) {
        // response = await API.actualizarUsuario(widget.usuarioData!['id_usuario'].toString(), data);
      } else {
        // response = await API.crearUsuario(data);
      }
      
      // if (mounted && response['status'] == 'success') {
      //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message']), backgroundColor: Colors.green));
      //   Navigator.of(context).pop(true); // Recarga
      // } else {
      //   throw Exception(response['message'] ?? 'Error desconocido');
      // }

    } catch (e) {
      if (mounted) {
         _showErrorDialog(e.toString().replaceFirst("Exception: ", ""));
         setState(() => _isLoading = false);
      }
    }
    */
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
            _isEditing ? 'Editar Usuario' : 'Nuevo Usuario',
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
              icon: Icon(Icons.save),
              onPressed: _isLoading ? null : _saveForm,
              tooltip: 'Guardar',
              color: chazkyWhite,
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
                ),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: <Widget>[
                      _buildTextFormField(
                        _nombreC,
                        'Nombre',
                        Icons.person_outline,
                      ),
                      _buildTextFormField(
                        _apellidoC,
                        'Apellido',
                        Icons.badge_outlined,
                      ),
                      _buildTextFormField(
                        _usuarioC,
                        'Nombre de Usuario',
                        Icons.alternate_email,
                        !_isEditing,
                      ), // Solo editable al crear
                      _buildTextFormField(
                        _emailC,
                        'Email',
                        Icons.email_outlined,
                        true,
                        TextInputType.emailAddress,
                      ),
                      _buildTextFormField(
                        _passwordC,
                        _isEditing
                            ? 'Nueva Contraseña (opcional)'
                            : 'Contraseña',
                        Icons.lock_outline,
                        true,
                        TextInputType.text,
                        1,
                        !_isEditing, // Requerido solo al crear
                      ),

                      SizedBox(height: 16),
                      // Dropdown para Tipo de Usuario
                      _buildDropdown(
                        label: 'Tipo de Usuario',
                        icon: Icons.admin_panel_settings_outlined,
                        value: _selectedTipoUsuario,
                        items: _tiposUsuario,
                        onChanged: (val) {
                          if (val != null)
                            setState(() => _selectedTipoUsuario = val);
                        },
                      ),

                      // Switch para Estado (Activo/Inactivo)
                      SwitchListTile(
                        title: Text(
                          'Usuario Activo',
                          style: TextStyle(color: chazkyWhite),
                        ),
                        value: _isActive,
                        onChanged: (val) => setState(() => _isActive = val),
                        activeColor: chazkyGold,
                        tileColor: mediumDarkBlue.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),

                      SizedBox(height: 30),
                      ElevatedButton.icon(
                        icon: Icon(Icons.save),
                        label: Text(
                          _isEditing ? 'Guardar Cambios' : 'Crear Usuario',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: chazkyGold,
                          foregroundColor: primaryDarkBlue,
                          minimumSize: Size(double.infinity, 50),
                          textStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        onPressed: _isLoading ? null : _saveForm,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // Helper para TextFormField
  Widget _buildTextFormField(
    TextEditingController controller,
    String label,
    IconData icon, [
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = true,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        enabled: enabled, // Para deshabilitar 'usuario' en edición
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: enabled ? chazkyWhite : Colors.grey[500]),
        decoration: _inputDecoration(label, icon).copyWith(
          fillColor: enabled
              ? primaryDarkBlue.withOpacity(0.5)
              : mediumDarkBlue.withOpacity(0.2),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return 'Este campo es requerido';
          }
          if (label == 'Email' && value!.isNotEmpty && !value.contains('@')) {
            return 'Email inválido';
          }
          if (label == 'Contraseña' && isRequired && value!.length < 6) {
            return 'Debe tener al menos 6 caracteres';
          }
          return null;
        },
      ),
    );
  }

  // Helper para DropdownButtonFormField
  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: TextStyle(color: chazkyWhite)),
              ),
            )
            .toList(),
        onChanged: onChanged,
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Selecciona un tipo' : null,
        decoration: _inputDecoration(label, icon),
        dropdownColor: mediumDarkBlue,
        style: TextStyle(color: chazkyWhite, fontFamily: 'Montserrat'),
        iconEnabledColor: chazkyGold,
      ),
    );
  }

  // Helper para la decoración de Inputs
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: chazkyWhite.withOpacity(0.5)),
      filled: true,
      fillColor: primaryDarkBlue.withOpacity(0.5), // Color base
      prefixIcon: Icon(icon, color: chazkyWhite.withOpacity(0.8), size: 20),
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
        fontSize: 12,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}
