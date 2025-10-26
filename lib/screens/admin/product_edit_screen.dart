// lib/screens/admin/product_edit_screen.dart

import 'package:flutter/material.dart';
import '../../models/product_model.dart'; // Asegúrate que este modelo tenga peso/dimensiones
import '../../api.dart'; // Asegúrate que tenga getUnidadesPeso/Dimension

class ProductEditScreen extends StatefulWidget {
  static const routeName = '/admin/edit-product';
  final Product? product;
  const ProductEditScreen({Key? key, this.product}) : super(key: key);
  @override
  _ProductEditScreenState createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  // Paleta de colores
  static const Color primaryDarkBlue = Color(0xFF1A202C);
  static const Color mediumDarkBlue = Color(0xFF2D3748);
  static const Color chazkyGold = Color(0xFFD4AF37);
  static const Color chazkyWhite = Colors.white;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // Loader general para guardar
  late bool _isEditing;

  // --- Controladores ---
  final _nombreC = TextEditingController();
  final _descripcionC = TextEditingController();
  final _precioC = TextEditingController();
  final _marcaC = TextEditingController();
  final _stockC = TextEditingController();
  final _codigoBarraC = TextEditingController();
  // Nuevos controladores
  final _pesoC = TextEditingController();
  final _anchoC = TextEditingController();
  final _altoC = TextEditingController();
  final _profundidadC = TextEditingController();

  // --- Estados para Dropdowns ---
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  bool _isLoadingCategories = true;
  List<Map<String, dynamic>> _weightUnits = [];
  String? _selectedPesoUnitId;
  bool _isLoadingWeightUnits = true;
  List<Map<String, dynamic>> _dimensionUnits = [];
  String? _selectedDimensionUnitId;
  bool _isLoadingDimensionUnits = true;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.product != null;

    if (_isEditing) {
      // Llena campos existentes
      _nombreC.text = widget.product!.nombre;
      _descripcionC.text = widget.product!.descripcion;
      _precioC.text = widget.product!.precio.toStringAsFixed(2);
      _marcaC.text = widget.product!.marca;
      _stockC.text = widget.product!.stock ?? '';
      _codigoBarraC.text = widget.product!.codigoBarra ?? '';
      _pesoC.text = widget.product!.peso ?? '';
      _anchoC.text = widget.product!.ancho ?? '';
      _altoC.text = widget.product!.alto ?? '';
      _profundidadC.text = widget.product!.profundidad ?? '';
    }
    // Carga los datos para los dropdowns
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Ya no seteamos isLoading general aquí, solo los de los dropdowns
    setState(() {
      _isLoadingCategories = true;
      _isLoadingWeightUnits = true;
      _isLoadingDimensionUnits = true;
    });
    try {
      final results = await Future.wait([
        API.getCategorias(),
        API.getUnidadesPeso(),
        API.getUnidadesDimension(),
      ]);

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(results[0]);
          _isLoadingCategories = false;
          if (_isEditing &&
              widget.product!.id_categoria != null &&
              _categories.any(
                (c) =>
                    c['id_categoria'].toString() ==
                    widget.product!.id_categoria,
              )) {
            _selectedCategoryId = widget.product!.id_categoria;
          }

          _weightUnits = List<Map<String, dynamic>>.from(results[1]);
          _isLoadingWeightUnits = false;
          if (_isEditing &&
              widget.product!.id_unidad_peso != null &&
              _weightUnits.any(
                (u) =>
                    u['id_unidad_peso'].toString() ==
                    widget.product!.id_unidad_peso,
              )) {
            _selectedPesoUnitId = widget.product!.id_unidad_peso;
          }

          _dimensionUnits = List<Map<String, dynamic>>.from(results[2]);
          _isLoadingDimensionUnits = false;
          if (_isEditing &&
              widget.product!.id_unidad_dimension != null &&
              _dimensionUnits.any(
                (u) =>
                    u['id_unidad_dimension'].toString() ==
                    widget.product!.id_unidad_dimension,
              )) {
            _selectedDimensionUnitId = widget.product!.id_unidad_dimension;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Asegura que los loaders se desactiven en error
          _isLoadingCategories = false;
          _isLoadingWeightUnits = false;
          _isLoadingDimensionUnits = false;
        });
        _showErrorDialog(
          "Error al cargar datos iniciales: ${e.toString().replaceFirst("Exception: ", "")}",
        );
      }
    }
  }

  @override
  void dispose() {
    _nombreC.dispose();
    _descripcionC.dispose();
    _precioC.dispose();
    _marcaC.dispose();
    _stockC.dispose();
    _codigoBarraC.dispose();
    _pesoC.dispose();
    _anchoC.dispose();
    _altoC.dispose();
    _profundidadC.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    final isValid = _formKey.currentState?.validate();
    if (isValid == null || !isValid) return;

    setState(() => _isLoading = true); // Activa loader general al guardar

    final productData = {
      'nombre': _nombreC.text,
      'descripcion': _descripcionC.text,
      'precio': _precioC.text,
      'marca': _marcaC.text,
      'stock': _stockC.text,
      'codigo_barra': _codigoBarraC.text.isNotEmpty
          ? _codigoBarraC.text
          : null, // Null si está vacío
      'id_categoria': _selectedCategoryId,
      'peso': _pesoC.text.isNotEmpty ? _pesoC.text : null,
      'id_unidad_peso': _selectedPesoUnitId,
      'ancho': _anchoC.text.isNotEmpty ? _anchoC.text : null,
      'alto': _altoC.text.isNotEmpty ? _altoC.text : null,
      'profundidad': _profundidadC.text.isNotEmpty ? _profundidadC.text : null,
      'id_unidad_dimension': _selectedDimensionUnitId,
      'descuento_porcentaje':
          widget.product?.descuentoPorcentaje.toString() ?? '0.00',
      'imagen':
          widget.product?.imagenUrl ??
          '0', // Manejar carga/actualización de imagen es más complejo
      // 'id_estado': '1', // Asignar ID de estado si es necesario
    };

    try {
      Map<String, dynamic> response;
      if (_isEditing) {
        response = await API.actualizarProducto(
          widget.product!.id,
          productData,
        );
      } else {
        response = await API.crearProducto(productData);
      }
      if (mounted) {
        if (response['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Guardado.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Indica éxito
        } else {
          throw Exception(response['message'] ?? 'Error desconocido.');
        }
      }
    } catch (error) {
      if (mounted) {
        _showErrorDialog(
          'Error al guardar: ${error.toString().replaceFirst("Exception: ", "")}',
        );
      }
    } finally {
      // Desactiva loader general independientemente del resultado
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Verifica si los datos iniciales (categorías, unidades) aún están cargando
    bool stillLoadingInitialData =
        _isLoadingCategories ||
        _isLoadingWeightUnits ||
        _isLoadingDimensionUnits;

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
          title: Text(_isEditing ? 'Editar Producto' : 'Añadir Producto'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.save),
              // Deshabilita guardar si está cargando datos iniciales o guardando
              onPressed: stillLoadingInitialData || _isLoading
                  ? null
                  : _saveForm,
            ),
          ],
        ),
        // Muestra loader si está cargando datos iniciales o guardando
        body: stillLoadingInitialData
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(chazkyGold),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment
                          .start, // Alinea títulos a la izquierda
                      children: <Widget>[
                        _buildSectionTitle('Información Básica'),
                        _buildTextFormField(
                          _nombreC,
                          'Nombre Producto',
                          Icons.label_important_outline,
                        ),
                        _buildTextFormField(
                          _descripcionC,
                          'Descripción',
                          Icons.notes_outlined,
                          TextInputType.text,
                          3,
                        ),
                        _buildTextFormField(
                          _precioC,
                          'Precio',
                          Icons.attach_money_outlined,
                          TextInputType.numberWithOptions(decimal: true),
                        ),
                        _buildTextFormField(
                          _marcaC,
                          'Marca',
                          Icons.branding_watermark_outlined,
                        ),
                        _buildTextFormField(
                          _codigoBarraC,
                          'Código Barras (Opcional)',
                          Icons.qr_code_outlined,
                          TextInputType.number,
                          1,
                          true,
                        ),
                        _buildCategoryDropdown(),

                        _buildSectionTitle('Inventario'),
                        _buildTextFormField(
                          _stockC,
                          'Stock',
                          Icons.inventory_2_outlined,
                          TextInputType.number,
                        ),

                        _buildSectionTitle('Peso (Opcional)'),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildTextFormField(
                                _pesoC,
                                'Valor',
                                Icons.scale_outlined,
                                TextInputType.numberWithOptions(decimal: true),
                                1,
                                true,
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: _buildUnitDropdown(
                                isLoading: _isLoadingWeightUnits,
                                items: _weightUnits,
                                selectedId: _selectedPesoUnitId,
                                idKey: 'id_unidad_peso',
                                nameKey:
                                    'nombre', // Muestra el nombre ('Kilogramo')
                                label: 'Unidad Peso',
                                icon: Icons.scale_outlined,
                                onChanged: (val) =>
                                    setState(() => _selectedPesoUnitId = val),
                                validator: (val) {
                                  if (_pesoC.text.isNotEmpty &&
                                      (val == null || val.isEmpty)) {
                                    return 'Selecciona unidad';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        _buildSectionTitle('Dimensiones (Opcional)'),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTextFormField(
                                _anchoC,
                                'Ancho',
                                Icons.width_normal_outlined,
                                TextInputType.numberWithOptions(decimal: true),
                                1,
                                true,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _buildTextFormField(
                                _altoC,
                                'Alto',
                                Icons.height_outlined,
                                TextInputType.numberWithOptions(decimal: true),
                                1,
                                true,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _buildTextFormField(
                                _profundidadC,
                                'Prof.',
                                Icons.square_foot_outlined,
                                TextInputType.numberWithOptions(decimal: true),
                                1,
                                true,
                              ),
                            ),
                          ],
                        ),
                        _buildUnitDropdown(
                          isLoading: _isLoadingDimensionUnits,
                          items: _dimensionUnits,
                          selectedId: _selectedDimensionUnitId,
                          idKey: 'id_unidad_dimension',
                          nameKey: 'nombre', // Muestra el nombre ('Centímetro')
                          label: 'Unidad Dimensión',
                          icon: Icons.straighten_outlined,
                          onChanged: (val) =>
                              setState(() => _selectedDimensionUnitId = val),
                          validator: (val) {
                            if ((_anchoC.text.isNotEmpty ||
                                    _altoC.text.isNotEmpty ||
                                    _profundidadC.text.isNotEmpty) &&
                                (val == null || val.isEmpty)) {
                              return 'Selecciona unidad';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 30),
                        ElevatedButton.icon(
                          icon: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: primaryDarkBlue,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(Icons.save),
                          label: Text(
                            _isLoading
                                ? 'Guardando...'
                                : (_isEditing
                                      ? 'Guardar Cambios'
                                      : 'Crear Producto'),
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
                            disabledBackgroundColor: chazkyGold.withOpacity(
                              0.5,
                            ), // Color cuando está deshabilitado
                          ),
                          onPressed: stillLoadingInitialData || _isLoading
                              ? null
                              : _saveForm, // Deshabilita si carga datos o guarda
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // --- Widgets Helpers ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: chazkyGold,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _isLoadingCategories
          ? Row(
              children: [
                /* Loader */ SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: chazkyGold,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Cargando...',
                  style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
                ),
              ],
            )
          : DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              items: _categories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category['id_categoria']?.toString(),
                      child: Text(
                        category['nombre_categoria'] ?? '?',
                        style: TextStyle(color: chazkyWhite),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (newValue) =>
                  setState(() => _selectedCategoryId = newValue),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Selecciona categoría'
                  : null,
              decoration: _inputDecoration(
                'Categoría',
                Icons.category_outlined,
              ),
              dropdownColor: mediumDarkBlue,
              style: TextStyle(color: chazkyWhite, fontFamily: 'Montserrat'),
              iconEnabledColor: chazkyGold,
            ),
    );
  }

  Widget _buildUnitDropdown({
    required bool isLoading,
    required List<Map<String, dynamic>> items,
    required String? selectedId,
    required String idKey,
    required String nameKey,
    required String label,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    FormFieldValidator<String>? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: isLoading
          ? Row(
              children: [
                /* Loader */ SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: chazkyGold,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Cargando...',
                  style: TextStyle(color: chazkyWhite.withOpacity(0.7)),
                ),
              ],
            )
          : DropdownButtonFormField<String>(
              value: selectedId,
              items: items
                  .map(
                    (unit) => DropdownMenuItem<String>(
                      value: unit[idKey]?.toString(),
                      child: Text(
                        unit[nameKey] ?? '?',
                        style: TextStyle(color: chazkyWhite),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
              validator: validator,
              decoration: _inputDecoration(
                label,
                icon,
              ), // Reutiliza la decoración
              dropdownColor: mediumDarkBlue,
              style: TextStyle(color: chazkyWhite, fontFamily: 'Montserrat'),
              iconEnabledColor: chazkyGold,
              isExpanded: true,
            ),
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller,
    String label,
    IconData icon, [
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool optional = false,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: chazkyWhite, fontFamily: 'Montserrat'),
        decoration: _inputDecoration(label, icon), // Reutiliza la decoración
        validator: (value) {
          if (optional && (value == null || value.trim().isEmpty)) return null;
          if (!optional && (value == null || value.trim().isEmpty))
            return 'Requerido'; // Mensaje corto
          if (value != null &&
              value.trim().isNotEmpty &&
              (keyboardType == TextInputType.number ||
                  keyboardType.toString().contains('decimal'))) {
            final number = double.tryParse(
              value.replaceAll(',', '.'),
            ); // Reemplaza coma por punto
            if (number == null) return 'Número inválido';
            // Permite precio 0, pero no stock negativo (a menos que quieras)
            if (number < 0 &&
                (label == 'Stock' ||
                    label == 'Peso' ||
                    label == 'Ancho' ||
                    label == 'Alto' ||
                    label == 'Prof.')) {
              return 'No negativo';
            }
          }
          return null;
        },
      ),
    );
  }

  // ¡NUEVO! Helper para la decoración de Inputs (TextFormField y Dropdown)
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      filled: true,
      fillColor: mediumDarkBlue.withOpacity(0.7),
      prefixIcon: Icon(
        icon,
        color: chazkyWhite.withOpacity(0.8),
        size: 20,
      ), // Icono más pequeño
      labelText: label,
      labelStyle: TextStyle(
        color: chazkyWhite.withOpacity(0.5),
        fontSize: 14,
      ), // Label más pequeño
      contentPadding: EdgeInsets.symmetric(
        vertical: 14.0,
        horizontal: 12.0,
      ), // Ajusta padding
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
      ), // Error más pequeño
    );
  }
}
