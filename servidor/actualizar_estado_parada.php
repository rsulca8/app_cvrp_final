<?php
// actualizar_estado_parada.php

require("connection.php"); // Necesita $conn (PDO)
header('Content-Type: application/json');

// --- Leer Datos de Entrada (JSON desde PUT) ---
$jsonPayload = file_get_contents('php://input');
$data = json_decode($jsonPayload, true);

// --- Validar Entrada ---
if (json_last_error() !== JSON_ERROR_NONE) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'JSON inválido.']);
    exit;
}

$id_ruta_detalle = $data['id_ruta_detalle'] ?? null;
$nuevo_estado = $data['nuevo_estado'] ?? null;
$motivo_fallo = $data['motivo_fallo'] ?? null; // Opcional

// Validaciones básicas
if (empty($id_ruta_detalle) || !is_numeric($id_ruta_detalle)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Falta id_ruta_detalle válido.']);
    exit;
}

if (empty($nuevo_estado) || !in_array($nuevo_estado, ['Entregado', 'No Entregado'])) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => "Estado '$nuevo_estado' no es válido. Debe ser 'Entregado' o 'No Entregado'."]);
    exit;
}

if ($nuevo_estado == 'No Entregado' && empty($motivo_fallo)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Se requiere un motivo_fallo para el estado No Entregado.']);
    exit;
}

// --- Actualizar Base de Datos ---

try {
    $conn->beginTransaction();

    // 1. Actualizar el estado de la parada (RutaDetalles)
    $sqlParada = "UPDATE RutaDetalles SET
                    estado_parada = :estado,
                    motivo_fallo = :motivo,
                    fecha_hora_llegada_real = NOW(), -- Registra la hora de la acción
                    fecha_hora_salida_real = NOW()
                  WHERE id_ruta_detalle = :id_ruta_detalle";
    
    $stmtParada = $conn->prepare($sqlParada);
    $stmtParada->bindParam(':estado', $nuevo_estado);
    $stmtParada->bindParam(':motivo', $motivo_fallo); // Si es null, se guardará NULL
    $stmtParada->bindParam(':id_ruta_detalle', $id_ruta_detalle, PDO::PARAM_INT);
    $stmtParada->execute();

    if ($stmtParada->rowCount() == 0) {
        throw new Exception("No se encontró la parada con ID $id_ruta_detalle.");
    }

    // 2. Obtener el id_pedido Y id_ruta asociado a esta parada
    $sqlGetIds = "SELECT id_pedido, id_ruta FROM RutaDetalles WHERE id_ruta_detalle = :id_ruta_detalle";
    $stmtGetIds = $conn->prepare($sqlGetIds);
    $stmtGetIds->bindParam(':id_ruta_detalle', $id_ruta_detalle, PDO::PARAM_INT);
    $stmtGetIds->execute();
    $ids = $stmtGetIds->fetch(PDO::FETCH_ASSOC);

    if ($ids === false || empty($ids['id_pedido']) || empty($ids['id_ruta'])) {
         throw new Exception("No se pudo encontrar el pedido o la ruta asociados a la parada.");
    }
    $id_pedido = $ids['id_pedido'];
    $id_ruta = $ids['id_ruta']; // ID de la ruta padre

    // 3. Actualizar el estado del Pedido principal
    // Convierte el estado de parada a estado de pedido
    // Si no se entrega -> 'Cancelado'. Si se entrega -> 'Entregado'.
    $estado_pedido = ($nuevo_estado == 'Entregado') ? 'Entregado' : 'Cancelado';

    $sqlPedido = "UPDATE Pedidos SET
                    estado = :estado,
                    fecha_hora_actualizacion = NOW()
                  WHERE id_pedido = :id_pedido";
    
    $stmtPedido = $conn->prepare($sqlPedido);
    $stmtPedido->bindParam(':estado', $estado_pedido);
    $stmtPedido->bindParam(':id_pedido', $id_pedido, PDO::PARAM_INT);
    $stmtPedido->execute();

    // 4. Verificar si todas las paradas de esta RUTA están completadas
    $sqlCheckRuta = "SELECT COUNT(*) AS pendientes
                     FROM RutaDetalles
                     WHERE id_ruta = :id_ruta AND estado_parada = 'Pendiente'";
    $stmtCheckRuta = $conn->prepare($sqlCheckRuta);
    $stmtCheckRuta->bindParam(':id_ruta', $id_ruta, PDO::PARAM_INT);
    $stmtCheckRuta->execute();
    $conteo = $stmtCheckRuta->fetch(PDO::FETCH_ASSOC);

    // 5. Si el conteo de pendientes es 0, actualiza la Ruta principal
    // Asume que tu ENUM en Rutas.estado_ruta incluye 'Completada'
    if ($conteo !== false && (int)$conteo['pendientes'] === 0) {
        
        $sqlRutaFin = "UPDATE Rutas SET
                            estado_ruta = 'Completada',
                            fecha_hora_fin = NOW()
                       WHERE id_ruta = :id_ruta";
        $stmtRutaFin = $conn->prepare($sqlRutaFin);
        $stmtRutaFin->bindParam(':id_ruta', $id_ruta, PDO::PARAM_INT);
        $stmtRutaFin->execute();
    }
    
    // Confirma la transacción
    $conn->commit();

    echo json_encode([
        'status' => 'success',
        'message' => "Parada $id_ruta_detalle actualizada a $nuevo_estado."
    ]);

} catch (PDOException $e) {
    $conn->rollBack();
    http_response_code(500);
    error_log("Error DB [actualizar_estado_parada]: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => 'Error al actualizar en la base de datos.']);
} catch (Exception $e) {
    $conn->rollBack();
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}

?>

