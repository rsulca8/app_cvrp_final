<?php

require("connection.php"); 

// Establece el tipo de contenido como JSON para todas las respuestas
header('Content-Type: application/json');

// Lee el parámetro 'clave' de la URL, si existe
$claveBuscada = trim($_GET["clave"] ?? '');

function getConfiguracionesEditables(PDO $conn): array
{
    // Selecciona todas las columnas donde editable_admin sea 1
    $sql = "SELECT * FROM ConfiguracionSistema WHERE editable_admin = 1 ORDER BY grupo, clave";

    try {
        $stmt = $conn->query($sql); // No necesita prepare porque no hay parámetros
        return $stmt->fetchAll(PDO::FETCH_ASSOC); // Devuelve todas las filas

    } catch (PDOException $e) {
        error_log("Error DB [getConfiguracionesEditables]: " . $e->getMessage());
        return []; // Devuelve array vacío en caso de error
    }
}

// Verifica si se proporcionó una clave específica
if (!empty($claveBuscada)) {
    // --- Lógica para buscar UNA configuración por clave ---
    $config = getConfiguracionPorClave($conn, $claveBuscada);

    if ($config === false) {
        // No se encontró la clave o hubo un error de DB (ya logueado en la función)
        http_response_code(404); // Not Found
        echo json_encode(['status' => 'error', 'message' => "Configuración con clave '$claveBuscada' no encontrada o error interno."]);
    } else {
        // Se encontró la configuración, devuelve solo esa
        http_response_code(200); // OK
        echo json_encode(['status' => 'success', 'configuracion' => $config]);
    }
} else {
    $configuraciones = getConfiguracionesEditables($conn); // Llama a la nueva función

    // Siempre devuelve éxito, incluso si la lista está vacía (es un resultado válido)
    http_response_code(200); // OK
    echo json_encode(['status' => 'success', 'configuraciones' => $configuraciones]);
}

?>

