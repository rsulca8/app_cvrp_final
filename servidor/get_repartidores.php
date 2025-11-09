<?php
require("connection.php");
$params = $_GET;
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);


header('Content-Type: application/json');


function getReparidores(PDO $conn): array{
    $sql = "SELECT  id_usuario, nombre, apellido, usuario, email, activo
     FROM Usuarios WHERE tipo_usuario = 'Repartidor'";
    try {
        $stmt = $conn->prepare($sql);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (PDOException $e) {
        error_log("Error DB [getReparidores]: " . $e->getMessage());
        return [];
    }
}

echo json_encode(getReparidores($conn));

?>