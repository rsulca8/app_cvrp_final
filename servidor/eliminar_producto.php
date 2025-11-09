<?php
// eliminar_producto.php

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
    echo json_encode(['status' => 'error', 'message' => 'Falta id_producto para eliminar.']);
    exit;
}
$productId = $data['id_producto'];

$sql = "DELETE FROM Productos WHERE id_producto = :id_producto";

try {
    $stmt = $conn->prepare($sql);
    $stmt->bindParam(':id_producto', $productId, PDO::PARAM_INT);

    $success = $stmt->execute();

    if ($success && $stmt->rowCount() > 0) {
        http_response_code(200); // OK
        echo json_encode(['status' => 'success', 'message' => 'Producto eliminado correctamente.']);
    } elseif ($success) {
         http_response_code(404); 
         echo json_encode(['status' => 'error', 'message' => 'Producto no encontrado con el ID proporcionado.']);
    } else {
        throw new PDOException("La ejecución de la eliminación falló.");
    }

} catch (PDOException $e) {
    if ($e->getCode() == '23000') { 
         http_response_code(409);
         error_log("Error DB [eliminar_producto]: " . $e->getMessage());
         echo json_encode(['status' => 'error', 'message' => 'No se puede eliminar el producto, está asociado a pedidos existentes.']);
    } else {
        http_response_code(500);
        error_log("Error DB [eliminar_producto]: " . $e->getMessage());
        echo json_encode(['status' => 'error', 'message' => 'Error al eliminar de la base de datos.']);
    }
}
?>