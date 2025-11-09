<?php

require("connection.php");
header('Content-Type: application/json');

/**
 * Obtiene todas las unidades de dimensión.
 *
 * @param PDO $conn Objeto de conexión PDO. 
 * @return array Retorna un array de arrays asociativos con las unidades de dimensión, o un array vacío si no hay o hay error.
 */
function getUnidadesDimension(PDO $conn): array
{
    $sql = 'SELECT * FROM UnidadesDimension ORDER BY nombre ASC';
    try {
        $stmt = $conn->query($sql);
        return $stmt->fetchAll(PDO::FETCH_ASSOC); 
    } catch (PDOException $e) {
        error_log("Error DB [getUnidadesDimension]: " . $e->getMessage());
        return []; 
    }
}

echo json_encode(getUnidadesDimension($conn));

?>