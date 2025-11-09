<?php
// get_rutas.php
require("connection.php"); // Incluye tu conexión PDO ($conn)
header('Content-Type: application/json');

/**
 * Obtiene rutas filtrando por uno o más estados.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @param array $estados Array de strings con los estados a buscar.
 * @return array Retorna un array de arrays asociativos con las rutas encontradas,
 * o un array vacío si no hay o hay un error.
 */
function getRutasPorEstado(PDO $conn, array $estados): array
{
    // Si no se proporcionan estados válidos, no busca nada.
    if (empty($estados)) {
        return [];
    }

    // Crea los placeholders (?, ?, ?) dinámicamente según la cantidad de estados.
    $placeholders = implode(',', array_fill(0, count($estados), '?'));

    $sql = "SELECT
                r.id_ruta,
                r.id_repartidor,
                r.fecha_hora_creacion,
                r.estado_ruta,
                r.distancia_total_metros,
                r.duracion_total_segundos,
                r.geometria_geojson,
                u.nombre AS repartidor_nombre,  
                u.apellido AS repartidor_apellido 
            FROM Rutas r
            INNER JOIN Usuarios u ON r.id_repartidor = u.id_usuario
            WHERE r.estado_ruta IN ($placeholders) 
            ORDER BY r.fecha_hora_creacion DESC"; 

    try {
        $stmt = $conn->prepare($sql);
        $stmt->execute($estados);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (PDOException $e) {
        error_log("Error DB [getRutasPorEstado]: " . $e->getMessage());
        return [];
    }
}

// --- Lógica Principal del Script ---

$estados_param = $_GET['estados'] ?? ''; 
$estados_array = [];

if (!empty($estados_param)) {
    $estados_array = array_filter(array_map('trim', explode(',', $estados_param)));
}

// 3. Valida que haya al menos un estado válido para buscar.
if (empty($estados_array)) {
     http_response_code(400); 
     echo json_encode(['status' => 'error', 'message' => 'No se especificaron estados válidos para buscar.']);
     exit; 
}

// 4. Llama a la función para obtener las rutas.
$rutas = getRutasPorEstado($conn, $estados_array);

// 5. Devuelve el resultado (el array de rutas o un array vacío) como JSON.
echo json_encode($rutas);



?>
