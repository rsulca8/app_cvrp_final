<?php

require("connection.php");
header('Content-Type: application/json');

/**
 * Obtiene todas las categorías.
 *
 * @param PDO $conn Objeto de conexión PDO. 
 * @return array Retorna un array de arrays asociativos con las categorías, o un array vacío si no hay o hay error.
 */
function getCategorias(PDO $conn): array
{
    $sql = 'SELECT * FROM Categorias ORDER BY nombre_categoria ASC';
    try {
        $stmt = $conn->query($sql);
        return $stmt->fetchAll(PDO::FETCH_ASSOC); 
    } catch (PDOException $e) {
        error_log("Error DB [getCategorias]: " . $e->getMessage());
        return []; // Devuelve array vacío en caso de error
    }
}

echo json_encode(getCategorias($conn));

?>