<?php
// crear_producto.php

require("connection.php"); // Include your PDO connection file ($conn)
header('Content-Type: application/json');

$jsonPayload = file_get_contents('php://input');
$data = json_decode($jsonPayload, true);

// Basic Validation
if (json_last_error() !== JSON_ERROR_NONE) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'JSON inválido.']);
    exit;
}

$required = ['nombre', 'descripcion', 'precio', 'marca', 'stock', 'nombreCategorias']; // Add other required fields like IDs
foreach ($required as $field) {
    if (empty($data[$field]) && $data[$field] !== '0' && $data[$field] !== 0) { // Allow 0 for stock/price etc.
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => "Falta el campo requerido: $field"]);
        exit;
    }
}


$sql = "INSERT INTO Productos (
            nombre, descripcion, precio, descuento_porcentaje, codigo_barra,
            stock, marca, imagen,
            id_categoria, id_unidad_peso, id_unidad_dimension, id_estado
        ) VALUES (
            :nombre, :descripcion, :precio, :descuento, :codigo_barra,
            :stock, :marca, :imagen,
            :id_categoria, :id_unidad_peso, :id_unidad_dimension, :id_estado
        )";

try {
    $stmt = $conn->prepare($sql);


    $stmt->bindParam(':nombre', $data['nombre']);
    $stmt->bindParam(':descripcion', $data['descripcion']);
    $stmt->bindParam(':precio', $data['precio']); 
    $stmt->bindParam(':descuento', $data['descuento_porcentaje'] ?? '0.00'); 
    $stmt->bindParam(':codigo_barra', $data['codigo_barra'] ?? null);
    $stmt->bindParam(':stock', $data['stock']);
    $stmt->bindParam(':marca', $data['marca']);
    $stmt->bindParam(':imagen', $data['imagen'] ?? '0'); 

    $id_categoria_placeholder = $data['id_categoria'] ?? 1; 
    $id_unidad_peso_placeholder = $data['id_unidad_peso'] ?? 1;
    $id_unidad_dimension_placeholder = $data['id_unidad_dimension'] ?? 1;
    $id_estado_placeholder = $data['id_estado'] ?? 1;

    $stmt->bindParam(':id_categoria', $id_categoria_placeholder, PDO::PARAM_INT);
    $stmt->bindParam(':id_unidad_peso', $id_unidad_peso_placeholder, PDO::PARAM_INT);
    $stmt->bindParam(':id_unidad_dimension', $id_unidad_dimension_placeholder, PDO::PARAM_INT);
    $stmt->bindParam(':id_estado', $id_estado_placeholder, PDO::PARAM_INT);

    // --- Execute ---
    $stmt->execute();
    $newProductId = $conn->lastInsertId();

    // --- Success Response ---
    http_response_code(201); // Created
    echo json_encode([
        'status' => 'success',
        'message' => 'Producto creado correctamente.',
        'id_producto' => $newProductId
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    error_log("Error DB [crear_producto]: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => 'Error al guardar en la base de datos.']);
} catch (Exception $e) { 
    http_response_code(400);
     echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
?>