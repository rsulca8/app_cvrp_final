<?php    
    // ini_set('display_errors', 1);
    // ini_set('display_startup_errors', 1);
    // error_reporting(E_ALL);
    require("connection.php");

    $user_param = $_GET["user"];
    $pass_param = $_GET["password"];

    $resultado = getCredential($conn, "rsulca8");
    $usuario = $resultado["usuario"];
    $password = $resultado["password_cliente"];
    
    header('Content-Type: application/json');
    if($user_param == $usuario){
        if($pass_param == $password){
            http_response_code(200);
            echo json_encode(array("resp"=>"OK"));
        }
        else{
            http_response_code(401);
            echo json_encode(array("resp"=>"contraseña incorrecta"));
        }
    }
    else{
        http_response_code(401);
        echo json_encode(array("resp"=>"usuario incorrecto"));
    }

    
?>