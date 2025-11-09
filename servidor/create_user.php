<?php
$params = $_GET;
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require("connection.php");


function insertarUsuario($conn, $user, $password_plain, $nombre, $apellido, $email)
{
    // 1. Crear el HASH seguro de la contraseña
    $password_hash = password_hash($password_plain, PASSWORD_DEFAULT);

    // 2. Preparar la consulta SQL (usando la nueva estructura)
    $sql = "INSERT INTO Usuarios (nombre, apellido, usuario, email, password, tipo_usuario)
                VALUES (:nombre, :apellido, :usuario, :email, :password_hash, 'Cliente')"; // Asume tipo Cliente por defecto

    try {
        $stmt = $conn->prepare($sql);

        // 3. Vincular parámetros (¡importante para seguridad!)
        $stmt->bindParam(':nombre', $nombre);
        $stmt->bindParam(':apellido', $apellido);
        $stmt->bindParam(':usuario', $user);
        $stmt->bindParam(':email', $email);
        $stmt->bindParam(':password_hash', $password_hash); // Guarda el hash, no la contraseña original

        // 4. Ejecutar
        $stmt->execute();

        // Puedes devolver el ID del nuevo usuario o un mensaje de éxito
        return json_encode(['status' => 'success', 'message' => 'Usuario registrado con éxito.', 'id_usuario' => $conn->lastInsertId()]);

    } catch (PDOException $e) {
        // Manejar errores (ej. usuario o email duplicado)
        if ($e->getCode() == 23000) { // Código de error para violación de constraint UNIQUE
            return json_encode(['status' => 'error', 'message' => 'El nombre de usuario o email ya está registrado.']);
        } else {
            error_log("Error DB: " . $e->getMessage()); // Guarda el error real en logs
            return json_encode(['status' => 'error', 'message' => 'Error al registrar el usuario. Intente de nuevo.']);
        }
    }
}


header('Content-Type: application/json');
if (isset($params["user"]) && isset($params["password"])) {
    $user = $params["user"];
    if (isset($params["password"])) {
        $password = $params["password"];
    }
    $email = $params["email"];
    $nombre = $params["nombre"];
    $apellido = $params["apellido"];
    echo insertarUsuario($conn, $user, $password, $nombre, $apellido, $email);
} else {
    echo json_encode("No se pudo concretar");
}
?>