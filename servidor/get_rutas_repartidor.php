<?php
// get_rutas_repartidor.php
require("connection.php"); // Incluye tu conexión PDO ($conn)
header('Content-Type: application/json');

    ini_set('display_errors', 1);
    ini_set('display_startup_errors', 1);
    error_reporting(E_ALL);
/**
 * Obtiene las rutas (solo encabezados) para un repartidor específico,
 * filtrando por uno o más estados.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @param int $id_repartidor ID del repartidor (Usuario).
 * @param array $estados Array de strings con los estados a buscar.
 * @return array Retorna un array de arrays asociativos con las rutas,
 * o un array vacío si no hay o hay un error.
 */
function getRutasRepartidorPorEstado(PDO $conn, int $id_repartidor, array $estados): array
{
    // No busca si no se especifican estados
    if (empty($estados)) {
        return [];
    }

    $placeholders_estados = implode(',', array_fill(0, count($estados), '?'));

    // Consulta SQL que une Rutas con Usuarios
    // No incluye geometría ni instrucciones para que sea más rápida
    $sql = "SELECT
                r.id_ruta, r.id_repartidor, r.fecha_hora_creacion, r.estado_ruta,
                r.distancia_total_metros, r.duracion_total_segundos,
                u.nombre AS repartidor_nombre, u.apellido AS repartidor_apellido
            FROM Rutas r
            JOIN Usuarios u ON r.id_repartidor = u.id_usuario
            WHERE r.id_repartidor = :id_repartidor -- Filtra por repartidor

            ORDER BY r.estado_ruta ASC, r.fecha_hora_creacion DESC"; // Prioriza 'Asignada' o 'En Curso'
    

    
        $stmt = $conn->prepare($sql);
        
        $stmt->bindParam(':id_repartidor', $id_repartidor, PDO::PARAM_INT);


        $params = array_merge([$id_repartidor], $estados);
    

        $stmt->execute(); // Pasa [id_repartidor, 'Asignada', 'En Curso']
    try {


        return $stmt->fetchAll(PDO::FETCH_ASSOC);
        
    } catch (PDOException $e) {      
        error_log("Error DB [getRutasRepartidorPorEstado]: " . $e->getMessage());
        return []; // Array vacío en error
    }
}

// --- Lógica Principal del Script ---

// 1. Obtiene el id_repartidor (requerido)
$repartidorId = filter_input(INPUT_GET, 'id_repartidor', FILTER_VALIDATE_INT);

// 2. Valida el ID
if ($repartidorId === false || $repartidorId <= 0) {
    http_response_code(400); // Bad Request
    echo json_encode(['status' => 'error', 'message' => 'ID de repartidor inválido o no proporcionado.']);
    exit;
}

// 3. Obtiene los estados (opcional, con default)
$estados_param = $_GET['estados'] ?? 'Asignada,En Curso'; // Default si no se pasa
$estados_array = array_filter(array_map('trim', explode(',', $estados_param)));

if (empty($estados_array)) {
     http_response_code(400);
     echo json_encode(['status' => 'error', 'message' => 'No se especificaron estados válidos.']);
     exit;
}

// 4. Llama a la función
$rutas = getRutasRepartidorPorEstado($conn, $repartidorId, $estados_array);

// 5. Devuelve el resultado
// Devuelve un JSON estructurado para consistencia con otras llamadas
echo json_encode([
    'status' => 'success',
    'rutas' => $rutas // Devuelve la lista (puede estar vacía)
]);

?>
