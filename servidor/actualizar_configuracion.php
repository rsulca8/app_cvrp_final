<?php
// actualizar_configuracion.php

require("connection.php"); // Necesita $conn (PDO) y getConfiguracionPorClave
header('Content-Type: application/json');

// --- Leer Datos de Entrada (JSON desde PUT) ---
$jsonPayload = file_get_contents('php://input');
$data = json_decode($jsonPayload, true);

// --- Validar Entrada ---
if (json_last_error() !== JSON_ERROR_NONE) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'JSON inválido.']);
    exit;
}

$clave = $data['clave'] ?? null;
$nuevoValor = $data['valor'] ?? null; 

if (empty($clave) || $nuevoValor === null) { // Permite string vacío como valor válido
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Faltan la clave o el nuevo valor.']);
    exit;
}

// --- Verificar si la clave existe y es editable ---
$configActual = getConfiguracionPorClave($conn, $clave);

if ($configActual === false) {
    http_response_code(404);
    echo json_encode(['status' => 'error', 'message' => "La clave de configuración '$clave' no existe."]);
    exit;
}

if (($configActual['editable_admin'] ?? 1) != 1) { // Asume 1 por defecto si no existe la columna
    http_response_code(403); // Forbidden
    echo json_encode(['status' => 'error', 'message' => "La configuración '$clave' no se puede editar."]);
    exit;
}

$tipoDato = $configActual['tipo_dato'] ?? 'string';
$valorMin = $configActual['valor_minimo'];
$valorMax = $configActual['valor_maximo'];
$opciones = $configActual['opciones_validas'] ? json_decode($configActual['opciones_validas'], true) : null;

$errorValidacion = null;

switch ($tipoDato) {
    case 'integer':
        if (!filter_var($nuevoValor, FILTER_VALIDATE_INT)) {
            $errorValidacion = 'El valor debe ser un número entero.';
        } else {
            $numVal = intval($nuevoValor);
            if ($valorMin !== null && $numVal < intval($valorMin)) $errorValidacion = "El valor mínimo es $valorMin.";
            if ($valorMax !== null && $numVal > intval($valorMax)) $errorValidacion = "El valor máximo es $valorMax.";
        }
        break;
    case 'float':
        if (!filter_var($nuevoValor, FILTER_VALIDATE_FLOAT)) {
            $errorValidacion = 'El valor debe ser un número decimal.';
        } else {
            $numVal = floatval($nuevoValor);
            if ($valorMin !== null && $numVal < floatval($valorMin)) $errorValidacion = "El valor mínimo es $valorMin.";
            if ($valorMax !== null && $numVal > floatval($valorMax)) $errorValidacion = "El valor máximo es $valorMax.";
        }
        break;
    case 'boolean':
        if ($nuevoValor !== '0' && $nuevoValor !== '1' && strtolower($nuevoValor) !== 'true' && strtolower($nuevoValor) !== 'false') {
             $errorValidacion = 'El valor debe ser 0, 1, true o false.';
        }
        // Normaliza a '1' o '0' para guardar
        $nuevoValor = ($nuevoValor === '1' || strtolower($nuevoValor) === 'true') ? '1' : '0';
        break;
    case 'enum_string':
        if ($opciones === null || !in_array($nuevoValor, $opciones)) {
            $errorValidacion = 'El valor seleccionado no es una opción válida.';
        }
        break;
    case 'json_array':
         // Podrías intentar decodificar para validar, pero es más complejo
         if (json_decode($nuevoValor) === null && json_last_error() !== JSON_ERROR_NONE) {
             $errorValidacion = 'El valor no es un JSON Array válido.';
         }
         break;
    case 'string':
    default:
        // Validación de longitud u otras reglas si es necesario
        break;
}

if ($errorValidacion !== null) {
     http_response_code(400);
     echo json_encode(['status' => 'error', 'message' => $errorValidacion]);
     exit;
}

// --- Actualizar en Base de Datos ---
$sql = "UPDATE ConfiguracionSistema SET valor = :valor WHERE clave = :clave";

try {
    $stmt = $conn->prepare($sql);
    $stmt->bindParam(':valor', $nuevoValor); // Guarda el valor validado/normalizado
    $stmt->bindParam(':clave', $clave);
    $stmt->execute();

    if ($stmt->rowCount() > 0) {
        echo json_encode(['status' => 'success', 'message' => "Configuración '$clave' actualizada."]);
    } else {
        // No hubo error, pero no se modificó (quizás el valor era el mismo)
        echo json_encode(['status' => 'success', 'message' => "Configuración '$clave' sin cambios."]);
    }

} catch (PDOException $e) {
    http_response_code(500);
    error_log("Error DB [actualizar_configuracion]: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => 'Error al actualizar la configuración en la base de datos.']);
}
?>
