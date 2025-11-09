<?php    

    require("connection.php");

    $user_param = $_GET["user"];
    $pass_param = $_GET["password"];

    $resultado = consultarUsuario($conn, $user_param);
    $usuario = $resultado["usuario"];
    $password = $resultado["password"];
    header('Content-Type: application/json');

    if($user_param == $usuario){
        if(password_verify($pass_param, $password) == 1){
            http_response_code(200);
            echo json_encode(array("resp"=>"OK"));
        }
        else{
            http_response_code(401);
            echo json_encode(array("resp"=>"credenciales incorrectas"));
        }
    }
    else{
        http_response_code(401);
        echo json_encode(array("resp"=>"credenciales incorrectas"));
    }

    
?>