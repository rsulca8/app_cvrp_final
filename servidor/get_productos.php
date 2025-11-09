<?php
require("connection.php");
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

/**
 * Obtiene todos los productos con sus detalles asociados.
 * Adaptado a la estructura de tu JSON de ejemplo.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @return array Retorna un array de arrays asociativos con los productos, o un array vacío si no hay o hay error.
 */
function consultarProductos(PDO $conn): array
{
    // Tu consulta SQL original adaptada ligeramente para claridad
    $sql = 'SELECT
                P.id_producto, P.nombre, P.descripcion, P.precio, P.descuento_porcentaje,
                P.codigo_barra, P.sku, P.stock, P.peso,
                P.id_unidad_peso,
                P.ancho, P.alto, P.profundidad,
                P.id_unidad_dimension, 
                P.marca, P.imagen,
                C.nombre_categoria AS nombreCategorias, P.id_categoria id_categoria, -- Mantenido por compatibilidad con tu JSON
                EP.nombre AS Estado
            FROM Productos P
            INNER JOIN EstadosProducto EP ON EP.id_estado = P.id_estado
            INNER JOIN Categorias C ON C.id_categoria = P.id_categoria
            ORDER BY P.nombre ASC'; // Opcional: Ordenar alfabéticamente
    try {
        $stmt = $conn->query($sql);  
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (PDOException $e) {
        error_log("Error DB [consultarProductos]: " . $e->getMessage());
        return [];
    }
}

$productos = consultarProductos($conn);
header('Content-Type: application/json');
http_response_code(200);
echo json_encode($productos);
?>