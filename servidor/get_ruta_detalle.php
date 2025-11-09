<?php

    ini_set('display_errors', 1);
    ini_set('display_startup_errors', 1);
    error_reporting(E_ALL);
// get_ruta_detalle.php
require("connection.php"); // Asegúrate que $conn (PDO) esté disponible
header('Content-Type: application/json');

/**
 * Obtiene los detalles completos de una ruta específica, incluyendo paradas.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @param int $id_ruta ID de la ruta a buscar.
 * @return array|false Retorna un array con 'ruta' y 'detalles', o false si no se encuentra o hay error.
 */


// --- Lógica Principal del Script (sin cambios) ---

$rutaId = filter_input(INPUT_GET, 'id_ruta', FILTER_VALIDATE_INT);

if ($rutaId === false || $rutaId <= 0) {
// ... (código existente) ...
    http_response_code(400); // Bad Request
    echo json_encode(['status' => 'error', 'message' => 'ID de ruta inválido o no proporcionado.']);
    exit;
}

$resultado = getDetallesCompletosRuta($conn, $rutaId);

if ($resultado === false) {
    http_response_code(404); // Not Found
// ... (código existente) ...
    echo json_encode(['status' => 'error', 'message' => "No se encontraron detalles para la ruta ID $rutaId o hubo un error."]);
} else {
    echo json_encode(['status' => 'success', 'ruta' => $resultado['ruta'], 'detalles' => $resultado['detalles']]);
}

?>

