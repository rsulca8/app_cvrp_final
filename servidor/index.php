<?php 
    $params = $_GET;
    ini_set('display_errors', 1);
    ini_set('display_startup_errors', 1);
    error_reporting(E_ALL);

    require("connection.php");
    //localhost/?create_user=true&user=fulano&password=asdf&email=fulano@gmail.com&nombre=cosme&apellido=fulanito
    //NO HACE NADA ESTE SCRIPT :v solo es para probar la conexion a la base de datos
    echo "Conexion exitosa a la base de datos";
    // if (isset($params["user"])){
    //     $user = $params["user"];
    //     if (isset($params["password"])){
    //         $password = $params["password"];
    //     }
    //     $email = $params["email"];
    //     $nombre = $params["nombre"];
    //     $apellido = $params["apellido"];
    //     insertarUsuario($conn, $user, $password, $nombre, $apellido, $email);
    // }
    // else{
    //     echo json_encode("No se pudo concretar");
    // }
?>