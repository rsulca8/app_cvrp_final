<?php
// get_ruta_activa_repartidor.php
require("connection.php"); 
// Incluye el archivo que tiene la función getDetallesCompletosRuta
//require_once("get_ruta_detalle.php"); // O donde sea que la hayas definido

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');

/**
 * Busca la ruta activa (Asignada o En Curso) para un repartidor.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @param int $id_repartidor ID del repartidor (Usuario).
 * @return int|false Retorna el ID de la ruta activa, o false si no hay.
 */
function buscarIdRutaActiva(PDO $conn, int $id_repartidor): int|false
{
    // Busca rutas que estén 'Asignada' o 'En Curso' para este repartidor
    $sql = "SELECT id_ruta
            FROM Rutas
            WHERE id_repartidor = :id_repartidor
              AND estado_ruta IN ('En Curso')
            ORDER BY fecha_hora_creacion DESC -- Obtiene la más reciente si hubiera varias
            LIMIT 1";
    try {
        $stmt = $conn->prepare($sql);
        $stmt->bindParam(':id_repartidor', $id_repartidor, PDO::PARAM_INT);
        $stmt->execute();
        $resultado = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (isset($resultado['id_ruta'])) {
            return (int)$resultado['id_ruta'];
        } else {
            return false;
        }

    } catch (PDOException $e) {
        error_log("Error DB [buscarIdRutaActiva]: " . $e->getMessage());
        return false;
    }
}

// --- Lógica Principal del Script ---

// 1. Obtiene el id_repartidor del parámetro GET
$repartidorId = filter_input(INPUT_GET, 'id_repartidor', FILTER_VALIDATE_INT);

// 2. Valida el ID
if ($repartidorId === false || $repartidorId <= 0) {
    http_response_code(400); // Bad Request
    echo json_encode(['status' => 'error', 'message' => 'ID de repartidor inválido o no proporcionado.']);
    exit;
}

// 3. Busca el ID de la ruta activa
$idRutaActiva = buscarIdRutaActiva($conn, $repartidorId);

if ($idRutaActiva === false) {
    // No es un error, simplemente no tiene ruta asignada
    http_response_code(200); 
    echo json_encode(['status' => 'success', 'message' => 'No hay ruta activa asignada.']);
    exit;
}

// 4. Si encontró una ruta, usa la función existente para obtener sus detalles
$resultadoCompleto = getDetallesCompletosRuta($conn, $idRutaActiva);

if ($resultadoCompleto === false) {
    http_response_code(404); // Not Found
    echo json_encode(['status' => 'error', 'message' => "Se encontró la ruta ID $idRutaActiva pero falló al obtener sus detalles."]);
} else {
    // Devuelve los detalles completos
    echo json_encode(['status' => 'success', 'ruta' => $resultadoCompleto['ruta'], 'detalles' => $resultadoCompleto['detalles']]);
}

?>
