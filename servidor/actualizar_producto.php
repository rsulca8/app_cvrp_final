<?php
// actualizar_producto.php

require("connection.php");
header('Content-Type: application/json');

$jsonPayload = file_get_contents('php://input');
$data = json_decode($jsonPayload, true);


if (json_last_error() !== JSON_ERROR_NONE) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'JSON inválido.']);
    exit;
}

if (empty($data['id_producto'])) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Falta id_producto para actualizar.']);
    exit;
}
$productId = $data['id_producto'];

$required = ['nombre', 'descripcion', 'precio', 'marca', 'stock', 'nombreCategorias']; // Add others
foreach ($required as $field) {
     if (empty($data[$field]) && $data[$field] !== '0' && $data[$field] !== 0) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => "Falta el campo requerido: $field"]);
        exit;
    }
}

$sql = "UPDATE Productos SET
            nombre = :nombre,
            descripcion = :descripcion,
            precio = :precio,
            descuento_porcentaje = :descuento,
            codigo_barra = :codigo_barra,
            stock = :stock,
            marca = :marca,
            imagen = :imagen,
            id_categoria = :id_categoria,
            id_unidad_peso = :id_unidad_peso,
            id_unidad_dimension = :id_unidad_dimension,
            id_estado = :id_estado
        WHERE id_producto = :id_producto";

try {
    $stmt = $conn->prepare($sql);


    $stmt->bindParam(':id_producto', $productId, PDO::PARAM_INT);
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

    $success = $stmt->execute();

    if ($success && $stmt->rowCount() > 0) {
        http_response_code(200); 
        echo json_encode(['status' => 'success', 'message' => 'Producto actualizado correctamente.']);
    } elseif ($success) {
         http_response_code(200); 
         echo json_encode(['status' => 'success', 'message' => 'Producto actualizado (sin cambios detectados o ID no encontrado).']);
    } else {
        throw new PDOException("La ejecución de la actualización falló.");
    }

} catch (PDOException $e) {
    http_response_code(500);
    error_log("Error DB [actualizar_producto]: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => 'Error al actualizar en la base de datos.']);
} catch (Exception $e) {
    http_response_code(400);
     echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}

?>