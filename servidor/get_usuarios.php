<?php
// get_usuarios.php
require("connection.php"); // Incluye tu conexión PDO ($conn)
header('Content-Type: application/json');

/**
 * Obtiene todos los usuarios de la base de datos, excluyendo la contraseña.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @return array Retorna un array de arrays asociativos con los usuarios,
 * o un array vacío si no hay o hay un error.
 */
function getAllUsuarios(PDO $conn): array
{
    $sql = "SELECT
                id_usuario,
                nombre,
                apellido,
                usuario,
                email,
                foto_perfil,
                tipo_usuario,
                activo,
                fecha_registro,
                fecha_actualizacion
            FROM Usuarios
            ORDER BY nombre, apellido ASC"; 

    try {
        $stmt = $conn->query($sql); 
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (PDOException $e) {
        error_log("Error DB [getAllUsuarios]: " . $e->getMessage());
        return []; 
    }
}

// --- Lógica Principal ---
$usuarios = getAllUsuarios($conn);

echo json_encode([
    'status' => 'success',
    'usuarios' => $usuarios 
]);

?>
