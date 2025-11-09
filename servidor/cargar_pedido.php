<?php
require("connection.php");
// ini_set('display_errors', 1);
// ini_set('display_startup_errors', 1);
// error_reporting(E_ALL);


// cargar_pedido.php

// --- Configuración y Conexión ---
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Responde siempre como JSON
header('Content-Type: application/json');


// --- Leer el JSON del Body ---
$jsonPayload = file_get_contents('php://input');
$data = json_decode($jsonPayload, true); // true para obtener un array asociativo

// --- Validación Básica ---
if (json_last_error() !== JSON_ERROR_NONE) {
    http_response_code(400); // Bad Request
    echo json_encode(['status' => 'error', 'message' => 'JSON inválido recibido.']);
    exit;
}

// Verifica campos obligatorios del encabezado 
$requiredFields = [
    'id_cliente',
    'total_pedido',
    'nombre_cliente',
    'apellido_cliente',
    'email_cliente',
    'telefono_cliente',
    'direccion_entrega',
    'latitud_entrega',
    'longitud_entrega',
    'detalles'
];
foreach ($requiredFields as $field) {
    if (!isset($data[$field])) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => "Falta el campo requerido: $field"]);
        exit;
    }
}

// Verifica que 'detalles' sea un array y no esté vacío
if (!is_array($data['detalles']) || empty($data['detalles'])) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'El pedido debe contener al menos un producto (detalles).']);
    exit;
}

// --- Procesamiento del Pedido (con Transacción) ---
try {
    // Inicia la transacción
    $conn->beginTransaction();

    // 1. Insertar en la tabla Pedidos 
    $sqlPedido = "INSERT INTO Pedidos (
                    id_usuario, total_pedido, nombre_cliente, apellido_cliente,
                    email, telefono, direccion_entrega, lat, lng,
                    fecha_hora_pedido, estado  -- Asume estado Pendiente por defecto
                  ) VALUES (
                    :id_usuario, :total_pedido, :nombre_cliente, :apellido_cliente,
                    :email, :telefono, :direccion_entrega, :lat, :lng,
                    :fecha_hora_pedido, 'Pendiente'
                  )";

    $stmtPedido = $conn->prepare($sqlPedido);

    // Asigna los valores usando bindParam para seguridad
    $stmtPedido->bindParam(':id_usuario', $data['id_cliente']); 
    $stmtPedido->bindParam(':total_pedido', $data['total_pedido']);
    $stmtPedido->bindParam(':nombre_cliente', $data['nombre_cliente']);
    $stmtPedido->bindParam(':apellido_cliente', $data['apellido_cliente']);
    $stmtPedido->bindParam(':email', $data['email_cliente']);
    $stmtPedido->bindParam(':telefono', $data['telefono_cliente']);
    $stmtPedido->bindParam(':direccion_entrega', $data['direccion_entrega']);
    $stmtPedido->bindParam(':lat', $data['latitud_entrega']);
    $stmtPedido->bindParam(':lng', $data['longitud_entrega']); 
    $stmtPedido->bindParam(':fecha_hora_pedido', $data['fecha_hora_pedido']); 

    $stmtPedido->execute();

    // 2. Obtener el ID del pedido recién insertado
    $id_pedido_nuevo = $conn->lastInsertId();

    // 3. Insertar en la tabla DetallesPedido
    $sqlDetalle = "INSERT INTO DetallesPedido (
                     id_pedido, id_producto, cantidad, precio_unitario
                   ) VALUES (
                     :id_pedido, :id_producto, :cantidad, :precio_unitario
                   )";
    $stmtDetalle = $conn->prepare($sqlDetalle);

    foreach ($data['detalles'] as $detalle) {
        // Verifica campos obligatorios del detalle
        if (!isset($detalle['id_producto']) || !isset($detalle['cantidad']) || !isset($detalle['producto_precio_venta'])) {
            throw new Exception("Detalle de producto incompleto: " . json_encode($detalle));
        }

        $stmtDetalle->bindParam(':id_pedido', $id_pedido_nuevo);
        $stmtDetalle->bindParam(':id_producto', $detalle['id_producto']);
        $stmtDetalle->bindParam(':cantidad', $detalle['cantidad']);
        $stmtDetalle->bindParam(':precio_unitario', $detalle['producto_precio_venta']);
        $stmtDetalle->execute();
    }

    // Si todo fue bien, confirma la transacción
    $conn->commit();

    // --- Respuesta Exitosa ---
    http_response_code(201); // Created
    echo json_encode([
        'status' => 'success',
        'message' => 'Pedido registrado correctamente.',
        'id_pedido' => $id_pedido_nuevo // Devuelve el ID por si acaso
    ]);

} catch (PDOException $e) {
    // Si algo falló, revierte la transacción
    $conn->rollBack();
    http_response_code(500); // Internal Server Error
    echo json_encode([
        'status' => 'error',
        'message' => 'Error en la base de datos: ' . $e->getMessage()
    ]);
} catch (Exception $e) {
    // Otro tipo de error (ej: detalle incompleto)
    $conn->rollBack();
    http_response_code(400); // Bad Request
    echo json_encode([
        'status' => 'error',
        'message' => 'Error procesando el pedido: ' . $e->getMessage()
    ]);
} finally {
    // Debería cerrar la conexión :v
    // $conn = null;
}
?>