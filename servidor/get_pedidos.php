<?php

require("connection.php"); // Asegúrate que $conn sea tu conexión PDO
header('Content-Type: application/json');
ini_set('display_errors', 1); // Para desarrollo, quitar en producción
error_reporting(E_ALL);

/**
 * Obtiene pedidos filtrando por uno o más estados.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @param array $estados Array de strings con los estados a buscar.
 * @return array Retorna un array de pedidos, o un array vacío si no hay o hay error.
 */
function getPedidosPorEstado(PDO $conn, array $estados): array
{
    // 1. Validar que el array de estados no esté vacío
    if (empty($estados)) {
        return []; // No hay estados por los cuales filtrar
    }

    // 2. Crear placeholders para la cláusula IN (?, ?, ?)
    // Esto genera una cadena como "?, ?, ?" según cuántos estados haya
    $placeholders = implode(',', array_fill(0, count($estados), '?'));

    // 3. Construir la consulta SQL usando los placeholders
    $sql = "SELECT
                p.id_pedido, p.id_usuario, p.fecha_hora_pedido, p.estado,
                p.total_pedido, p.direccion_entrega,
                p.nombre_cliente, p.apellido_cliente
            FROM Pedidos p
            WHERE p.estado IN ($placeholders)
            ORDER BY p.fecha_hora_pedido DESC";

    try {
        // 4. Preparar la consulta
        $stmt = $conn->prepare($sql);

        // 5. Ejecutar la consulta pasando el array de estados.
        // PDO maneja automáticamente el binding de cada '?' con los valores del array.
        $stmt->execute($estados);

        // 6. Obtener todos los resultados como array asociativo
        return $stmt->fetchAll(PDO::FETCH_ASSOC);

    } catch (PDOException $e) {
        error_log("Error DB [getPedidosPorEstado]: " . $e->getMessage());
        return []; // Devuelve array vacío en caso de error
    }
}

// --- Lógica Principal del Script ---
$estados_param = $_GET['estados'] ?? ''; // Obtiene el parámetro 'estados', default vacío

if (empty($estados_param)) {
    http_response_code(400); // Bad Request
    echo json_encode(['status' => 'error', 'message' => 'El parámetro "estados" es requerido.']);
    exit;
}

// Convierte el string separado por comas en un array
$estados_array = explode(',', $estados_param);

// Limpia espacios en blanco de cada estado (por si acaso)
$estados_array = array_map('trim', $estados_array);

// Filtra valores vacíos que podrían quedar si hay comas extra (ej: "Pendiente,,En Proceso")
$estados_array = array_filter($estados_array);

if (empty($estados_array)) {
     http_response_code(400); // Bad Request
    echo json_encode(['status' => 'error', 'message' => 'El parámetro "estados" no contiene valores válidos.']);
    exit;
}


// Llama a la función con el array de estados
$pedidos = getPedidosPorEstado($conn, $estados_array);

// Devuelve el resultado como JSON
echo json_encode($pedidos);

?>
