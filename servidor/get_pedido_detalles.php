<?php
// get_pedido_detalles.php
require("connection.php"); 
header('Content-Type: application/json');

/**
 * Obtiene los productos (detalles) de un pedido específico.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @param int $id_pedido ID del pedido a buscar.
 * @return array Retorna un array de arrays asociativos con los productos.
 */
function getProductosDelPedido(PDO $conn, int $id_pedido): array
{
    $sql = "SELECT
                dp.id_detalle,
                dp.id_producto,
                dp.cantidad,
                dp.precio_unitario,
                p.nombre AS nombre_producto, 
                p.marca AS marca_producto,
                rd.*
            FROM DetallesPedido dp
            LEFT JOIN Productos p ON dp.id_producto = p.id_producto 
            LEFT JOIN RutaDetalles rd ON dp.id_pedido = rd.id_pedido  
            WHERE dp.id_pedido = :id_pedido
            ORDER BY p.nombre ASC";

    try {
        $stmt = $conn->prepare($sql);
        $stmt->bindParam(':id_pedido', $id_pedido, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (PDOException $e) {
        error_log("Error DB [getProductosDelPedido]: " . $e->getMessage());
        return []; 
    }
}


$pedidoId = filter_input(INPUT_GET, 'id_pedido', FILTER_VALIDATE_INT);

if ($pedidoId === false || $pedidoId <= 0) {
    http_response_code(400); 
    echo json_encode(['status' => 'error', 'message' => 'ID de pedido inválido o no proporcionado.']);
    exit;
}

$detalles = getProductosDelPedido($conn, $pedidoId);

// Devuelve un JSON estructurado
echo json_encode([
    'status' => 'success',
    'detalles' => $detalles // Devuelve la lista (puede estar vacía)
]);

?>
