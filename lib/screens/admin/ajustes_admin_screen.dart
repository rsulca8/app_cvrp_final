// lib/screens/admin/ajustes_admin_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para input formatters
import 'dart:convert'; // Para jsonDecode

import '../../api.dart'; // Importa la clase API

class AjustesAdminScreen extends StatefulWidget {
  @override
  _AjustesAdminScreenState createState() => _AjustesAdminScreenState();
}

class _AjustesAdminScreenState extends State<AjustesAdminScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _configurations = []; // Lista original de la API
  Map<String, dynamic> _editedValues =
      {}; // Mapa para guardar cambios: { 'clave': 'nuevoValor' }
  Map<String, List<Map<String, dynamic>>> _groupedConfigs =
      {}; // Para agrupar por 'grupo'

  bool _isSaving = false; // Estado para el botón de guardar

  @override
  void initState() {
    super.initState();
    _loadConfiguraciones();
  }

  Future<void> _loadConfiguraciones({bool showSuccess = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _editedValues.clear(); // Limpia cambios pendientes al recargar
    });

    try {
      final response = await API.getAllConfiguraciones(); // Usa la función API
      if (!mounted) return;

      if (response['status'] == 'success' &&
          response['configuraciones'] is List) {
        final configs = List<Map<String, dynamic>>.from(
          response['configuraciones'],
        );
        _groupConfigurations(configs); // Agrupa las configuraciones
        setState(() {
          _configurations = configs;
          _isLoading = false;
        });
        if (showSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Configuración recargada.'),
              backgroundColor: Colors.lightGreen,
            ),
          );
        }
      } else {
        throw Exception(
          response['message'] ?? 'Error al obtener configuraciones.',
        );
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

  // Agrupa las configuraciones por la clave 'grupo'
  void _groupConfigurations(List<Map<String, dynamic>> configs) {
    _groupedConfigs.clear();
    for (var config in configs) {
      final group =
          config['grupo'] as String? ?? 'General'; // Grupo por defecto
      if (!_groupedConfigs.containsKey(group)) {
        _groupedConfigs[group] = [];
      }
      _groupedConfigs[group]!.add(config);
    }
    // Opcional: Ordenar los grupos
    // _groupedConfigs = Map.fromEntries(
    //    _groupedConfigs.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    // );
  }

  // Guarda los cambios realizados
  Future<void> _saveChanges() async {
    if (_editedValues.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No hay cambios para guardar.')));
      return;
    }

    setState(() => _isSaving = true);
    int successCount = 0;
    int errorCount = 0;
    List<String> errorMessages = [];

    // Guarda cada cambio individualmente
    for (var entry in _editedValues.entries) {
      final clave = entry.key;
      final nuevoValor = entry.value.toString(); // Asegura que sea string

      try {
        final response = await API.actualizarConfiguracion(clave, nuevoValor);
        if (response['status'] == 'success') {
          successCount++;
        } else {
          errorCount++;
          errorMessages.add(
            "$clave: ${response['message'] ?? 'Error desconocido'}",
          );
        }
      } catch (e) {
        errorCount++;
        errorMessages.add(
          "$clave: ${e.toString().replaceFirst("Exception: ", "")}",
        );
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    // Muestra resultado
    if (errorCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount configuraciones guardadas.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadConfiguraciones(); // Recarga para ver valores actualizados
    } else {
      // Muestra un diálogo con los errores detallados
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: mediumDarkBlue,
          title: Text(
            'Error al Guardar',
            style: TextStyle(color: Colors.redAccent),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                  '$errorCount de ${errorCount + successCount} configuraciones fallaron:',
                  style: TextStyle(color: chazkyWhite),
                ),
                SizedBox(height: 10),
                ...errorMessages.map(
                  (msg) => Text(
                    '- $msg',
                    style: TextStyle(color: chazkyWhite.withOpacity(0.8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(color: chazkyGold)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
      // Recarga de todos modos para revertir cambios fallidos en la UI
      _loadConfiguraciones();
    }
  }

  // Actualiza el mapa _editedValues cuando un valor cambia
  void _updateValue(String clave, dynamic newValue) {
    setState(() {
      _editedValues[clave] = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool hasChanges = _editedValues.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent, // Hereda gradiente
      appBar: AppBar(
        // AppBar específica para esta pantalla
        title: Text(
          'Ajustes del Sistema',
          style: TextStyle(fontFamily: 'Montserrat', color: chazkyWhite),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Botón Guardar (habilitado si hay cambios y no está guardando)
          TextButton.icon(
            icon: _isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: chazkyGold,
                    ),
                  )
                : Icon(
                    Icons.save,
                    color: hasChanges ? chazkyGold : Colors.grey,
                  ),
            label: Text(
              'Guardar',
              style: TextStyle(color: hasChanges ? chazkyGold : Colors.grey),
            ),
            onPressed: (!hasChanges || _isSaving) ? null : _saveChanges,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadConfiguraciones(showSuccess: true),
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
            : _buildConfigList(), // Construye la lista de configuraciones
      ),
    );
  }

  // --- Widgets Helpers ---

  Widget _buildErrorWidget(String errorMsg) {
    // ... (Widget de error similar a logística) ...
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
              onPressed: () => _loadConfiguraciones(showSuccess: true),
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

  Widget _buildConfigList() {
    if (_groupedConfigs.isEmpty) {
      return Center(
        child: Text(
          'No hay configuraciones editables.',
          style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
        ),
      );
    }

    // Ordena los grupos alfabéticamente
    final sortedGroups = _groupedConfigs.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedGroups.length,
      itemBuilder: (context, index) {
        final groupName = sortedGroups[index];
        final groupItems = _groupedConfigs[groupName]!;
        return Card(
          // Agrupa cada sección en una Card
          color: mediumDarkBlue.withOpacity(0.3),
          margin: const EdgeInsets.only(bottom: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(color: Colors.white24, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título del Grupo
                Text(
                  groupName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: chazkyGold,
                    fontFamily: 'Montserrat',
                  ),
                ),
                Divider(color: Colors.white24, height: 20),
                // Items de Configuración dentro del grupo
                ...groupItems
                    .map((config) => _buildConfigItem(config))
                    .toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  // Construye el widget para UN item de configuración
  Widget _buildConfigItem(Map<String, dynamic> config) {
    final String clave = config['clave'];
    final String tipoDato = config['tipo_dato'] ?? 'string';
    final String? descripcion = config['descripcion'];
    // Obtiene el valor actual (editado si existe, si no el original)
    final dynamic currentValue = _editedValues.containsKey(clave)
        ? _editedValues[clave]
        : config['valor'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Descripción (si existe)
          if (descripcion != null && descripcion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                descripcion,
                style: TextStyle(
                  color: chazkyWhite.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ),
          // Input basado en tipo_dato
          _buildConfigInput(config, currentValue),
          // Muestra clave debajo (útil para debug o referencia)
          // Padding(
          //    padding: const EdgeInsets.only(top: 4.0),
          //    child: Text(clave, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          // ),
        ],
      ),
    );
  }

  // Determina qué widget de input mostrar según el tipo_dato
  Widget _buildConfigInput(Map<String, dynamic> config, dynamic currentValue) {
    final String clave = config['clave'];
    final String tipoDato = config['tipo_dato'] ?? 'string';
    final String label = _formatLabel(
      clave,
    ); // Convierte 'clave_ejemplo' a 'Clave Ejemplo'
    final List<dynamic>? opciones = (config['opciones_validas'] != null)
        ? jsonDecode(config['opciones_validas']) as List<dynamic>?
        : null;
    final String? valorMinStr = config['valor_minimo'];
    final String? valorMaxStr = config['valor_maximo'];

    // Define decoración común
    InputDecoration inputDecoration = InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: chazkyWhite.withOpacity(0.5)),
      filled: true,
      fillColor: primaryDarkBlue.withOpacity(0.5),
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
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );

    switch (tipoDato) {
      case 'integer':
      case 'float':
        TextInputType keyboard = (tipoDato == 'integer')
            ? TextInputType.number
            : TextInputType.numberWithOptions(decimal: true);
        List<TextInputFormatter> formatters = (tipoDato == 'integer')
            ? [FilteringTextInputFormatter.digitsOnly]
            : [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
              ]; // Permite decimales
        // Usa un TextEditingController temporal para manejar el valor numérico
        final controller = TextEditingController(
          text: currentValue?.toString() ?? '',
        );
        return TextFormField(
          controller: controller, // Usa controller temporal
          keyboardType: keyboard,
          inputFormatters: formatters,
          style: TextStyle(color: chazkyWhite),
          decoration: inputDecoration.copyWith(
            hintText: (valorMinStr != null || valorMaxStr != null)
                ? '(${valorMinStr ?? ''} - ${valorMaxStr ?? ''})' // Muestra rango como hint
                : null,
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          onChanged: (value) => _updateValue(clave, value), // Guarda el string
          validator: (value) {
            if (value == null || value.isEmpty) return 'Requerido';
            final number = num.tryParse(value.replaceAll(',', '.'));
            if (number == null) return 'Número inválido';
            if (tipoDato == 'integer' &&
                number is! int &&
                number.truncate() != number)
              return 'Debe ser entero';
            if (valorMinStr != null && number < num.parse(valorMinStr))
              return 'Mínimo: $valorMinStr';
            if (valorMaxStr != null && number > num.parse(valorMaxStr))
              return 'Máximo: $valorMaxStr';
            return null;
          },
        );

      case 'boolean':
        // Convierte el valor actual (puede ser '1','0', true, false) a bool
        bool currentBoolValue =
            (currentValue.toString() == '1' ||
            currentValue.toString().toLowerCase() == 'true');
        return SwitchListTile(
          title: Text(label, style: TextStyle(color: chazkyWhite)),
          value: currentBoolValue,
          onChanged: (newValue) => _updateValue(
            clave,
            newValue ? '1' : '0',
          ), // Guarda como '1' o '0'
          activeColor: chazkyGold,
          tileColor: primaryDarkBlue.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        );

      case 'enum_string':
        if (opciones == null || opciones.isEmpty) {
          return Text(
            'Error: No hay opciones definidas para "$clave".',
            style: TextStyle(color: Colors.red),
          );
        }
        // Asegura que currentValue sea un String y esté en las opciones
        String? currentStringValue = currentValue?.toString();
        if (!opciones.contains(currentStringValue)) {
          // Si el valor actual no es válido, usa el default o el primero de la lista
          currentStringValue = config['valor_default']?.toString();
          if (currentStringValue == null ||
              !opciones.contains(currentStringValue)) {
            currentStringValue = opciones.first
                .toString(); // Fallback al primero
          }
          _updateValue(clave, currentStringValue); // Actualiza el valor interno
        }

        return DropdownButtonFormField<String>(
          value: currentStringValue,
          items: opciones.map((option) {
            return DropdownMenuItem<String>(
              value: option.toString(),
              child: Text(
                option.toString(),
                style: TextStyle(color: chazkyWhite),
              ),
            );
          }).toList(),
          onChanged: (newValue) => _updateValue(clave, newValue),
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Selecciona una opción' : null,
          decoration: inputDecoration,
          dropdownColor: mediumDarkBlue,
          style: TextStyle(color: chazkyWhite, fontFamily: 'Montserrat'),
          iconEnabledColor: chazkyGold,
        );

      case 'json_array':
        // Por ahora, solo muestra el JSON como texto (editarlo es complejo)
        return TextFormField(
          initialValue: _prettyPrintJson(currentValue),
          maxLines: null, // Permite múltiples líneas
          readOnly: true, // No editable por ahora
          style: TextStyle(
            color: chazkyWhite.withOpacity(0.7),
            fontSize: 12,
            fontFamily: 'monospace',
          ),
          decoration: inputDecoration.copyWith(
            labelText: '$label (JSON - No editable)',
          ),
        );

      case 'string':
      default:
        // Usa un TextEditingController temporal para manejar el valor
        final controller = TextEditingController(
          text: currentValue?.toString() ?? '',
        );
        return TextFormField(
          controller: controller, // Usa controller temporal
          style: TextStyle(color: chazkyWhite),
          decoration: inputDecoration,
          onChanged: (value) => _updateValue(clave, value),
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Requerido' : null,
        );
    }
  }

  // Helper para convertir clave_ejemplo a "Clave Ejemplo"
  String _formatLabel(String key) {
    if (key.isEmpty) return '';
    // Reemplaza guiones bajos por espacios y capitaliza cada palabra
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Helper para mostrar JSON de forma legible (opcional)
  String _prettyPrintJson(dynamic jsonInput) {
    if (jsonInput == null) return '';
    String jsonString = (jsonInput is String)
        ? jsonInput
        : jsonEncode(jsonInput);
    try {
      var jsonObject = jsonDecode(jsonString);
      var encoder = JsonEncoder.withIndent('  '); // Indentación de 2 espacios
      return encoder.convert(jsonObject);
    } catch (e) {
      return jsonString; // Devuelve el original si no es JSON válido
    }
  }
}
