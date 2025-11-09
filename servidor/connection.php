<?php
$host = getenv("CVRP_APP_HOST");
$db = getenv("CVRP_APP_DATABASE"); // Database name
$user = getenv("CVRP_APP_DB_USER"); // Username
$pass = getenv("CVRP_APP_DB_PASSWORD"); // Password
$charset = 'utf8mb4'; // Recommended charset for modern MySQL
//SE ASUME EL PUERTO POR DEFECTO 3306 DE MYSQL
// Data Source Name (DSN) - specifies how to connect
$dsn = "mysql:host=$host;dbname=$db;charset=$charset";

// Options for PDO connection
$options = [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, // Throw exceptions on errors (recommended)
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,       // Fetch results as associative arrays
    PDO::ATTR_EMULATE_PREPARES => false,                  // Use real prepared statements
];

try {
    // Create the PDO connection object and store it in $conn
    $conn = new PDO($dsn, $user, $pass, $options);
    // echo "Conexión PDO exitosa!"; // Optional: success message

} catch (\PDOException $e) {
    // Handle connection errors securely
    error_log("Error de conexión PDO: " . $e->getMessage()); // Log the error
    // Display a generic error message to the user
    http_response_code(500); // Internal Server Error
    echo json_encode(['status' => 'error', 'message' => 'Error al conectar con la base de datos.']);
    exit; // Stop script execution
}



/**
 * Obtiene el hash de la contraseña de un usuario.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @param string $user Nombre de usuario.
 * @return array|false Retorna un array asociativo con 'usuario' y 'password' (hash) o false si no se encuentra o hay error.
 */
function getCredential(PDO $conn, string $user): array|false
{
    $sql = 'SELECT id_usuario, usuario, password FROM Usuarios WHERE usuario = :usuario LIMIT 1';
    try {
        $stmt = $conn->prepare($sql);
        $stmt->bindParam(':usuario', $user, PDO::PARAM_STR);
        $stmt->execute();
        // fetch() devuelve false si no hay filas
        return $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (PDOException $e) {
        error_log("Error DB [getCredential]: " . $e->getMessage());
        // echo "Error: " . $e->getMessage();
        return false;
    }
}

/**
 * Obtiene todos los datos de un usuario por su nombre de usuario.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @param string $user Nombre de usuario.
 * @return array|false Retorna un array asociativo con los datos del usuario o false si no se encuentra o hay error.
 */
function consultarUsuario(PDO $conn, string $user): array|false
{
    $sql = 'SELECT * FROM Usuarios WHERE usuario = :usuario LIMIT 1';
    try {
        $stmt = $conn->prepare($sql);
        $stmt->bindParam(':usuario', $user, PDO::PARAM_STR);
        $stmt->execute();
        return $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (PDOException $e) {
        error_log("Error DB [consultarUsuario]: " . $e->getMessage());
        return false;
    }
}


/**
 * Inserta una nueva categoría.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @param string $nombreCategoria Nombre de la nueva categoría.
 * @return int|false Retorna el ID de la nueva categoría o false en caso de error.
 */
function insertarCategoria(PDO $conn, string $nombreCategoria): int|false // Renombrado para claridad
{
    $sql = 'INSERT INTO Categorias (nombre_categoria) VALUES (:nombre)';
    try {
        $stmt = $conn->prepare($sql);
        $stmt->bindParam(':nombre', $nombreCategoria, PDO::PARAM_STR);
        $stmt->execute();
        return (int) $conn->lastInsertId(); // Devuelve el ID insertado
    } catch (PDOException $e) {
        error_log("Error DB [insertarCategoria]: " . $e->getMessage());
        return false;
    }
}


/**
 * Inserta un nuevo producto.
 * Adaptado a la estructura de la tabla Productos que usaste antes.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @param array $producto Array asociativo con los datos del producto.
 * @return int|false Retorna el ID del nuevo producto o false en caso de error.
 */
function insertarProducto(PDO $conn, array $producto): int|false
{
    $sql = 'INSERT INTO Productos (
                nombre, descripcion, precio, descuento_porcentaje, codigo_barra,
                sku, stock, peso, id_unidad_peso, ancho, alto, profundidad,
                id_unidad_dimension, marca, imagen, id_categoria, id_estado
            ) VALUES (
                :nombre, :descripcion, :precio, :descuento, :codigo_barra,
                :sku, :stock, :peso, :id_unidad_peso, :ancho, :alto, :profundidad,
                :id_unidad_dimension, :marca, :imagen, :id_categoria, :id_estado
            )';
    try {
        $stmt = $conn->prepare($sql);

        $stmt->bindParam(':nombre', $producto['nombre']); 
        $stmt->bindParam(':descripcion', $producto['descripcion']);
        $stmt->bindParam(':precio', $producto['precio']);
        $stmt->bindParam(':descuento', $producto['descuento_porcentaje']);
        $stmt->bindParam(':codigo_barra', $producto['codigo_barra']);
        $stmt->bindParam(':sku', $producto['sku']);
        $stmt->bindParam(':stock', $producto['stock']);
        $stmt->bindParam(':peso', $producto['peso']);
        $stmt->bindParam(':id_unidad_peso', $producto['id_unidad_peso']); 
        $stmt->bindParam(':ancho', $producto['ancho']);
        $stmt->bindParam(':alto', $producto['alto']);
        $stmt->bindParam(':profundidad', $producto['profundidad']);
        $stmt->bindParam(':id_unidad_dimension', $producto['id_unidad_dimension']); 
        $stmt->bindParam(':marca', $producto['marca']);
        $stmt->bindParam(':imagen', $producto['imagen']);
        $stmt->bindParam(':id_categoria', $producto['id_categoria']); 
        $stmt->bindParam(':id_estado', $producto['id_estado']); 

        $stmt->execute();
        return (int) $conn->lastInsertId();
    } catch (PDOException $e) {
        error_log("Error DB [insertarProducto]: " . $e->getMessage());
        return false;
    }
}

/**
 * Obtiene un registro de configuración específico por su clave.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @param string $clave La clave única de la configuración a buscar (e.g., 'capacidad_maxima_vehiculos').
 * @return array|false Retorna un array asociativo con todos los datos de la configuración si se encuentra,
 * o false si no se encuentra o hay un error.
 */
function getConfiguracionPorClave(PDO $conn, string $clave): array|false
{
    $sql = "SELECT * FROM ConfiguracionSistema WHERE clave = :clave LIMIT 1";

    try {
        $stmt = $conn->prepare($sql);
        $stmt->bindParam(':clave', $clave, PDO::PARAM_STR);
        $stmt->execute();

        $configuracion = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($configuracion && isset($configuracion['tipo_dato'])) {
            switch ($configuracion['tipo_dato']) {
                case 'integer':
                    $configuracion['valor'] = (int)$configuracion['valor'];
                    break;
                case 'float':
                    $configuracion['valor'] = (float)$configuracion['valor'];
                    break;
                case 'boolean':
                    $configuracion['valor'] = (bool)$configuracion['valor'];
                    break;
                case 'json_array':
                    $configuracion['valor'] = json_decode($configuracion['valor'], true) ?? []; // Decodifica JSON
                    break;
                // 'string' y 'enum_string' se quedan como string
            }
        }

        return $configuracion; // Devuelve el array asociativo o false

    } catch (PDOException $e) {
        // Registra el error real en los logs del servidor
        error_log("Error DB [getConfiguracionPorClave]: Clave='$clave' - " . $e->getMessage());
        // Devuelve false para indicar un error
        return false;
    }
}


/**
 * Obtiene los detalles completos de una ruta específica, incluyendo paradas.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @param int $id_ruta ID de la ruta a buscar.
 * @return array|false Retorna un array con 'ruta' y 'detalles', o false si no se encuentra o hay error.
 */
function getDetallesCompletosRuta(PDO $conn, int $id_ruta): array|false
{
    $rutaData = false;
    $detallesData = [];

    try {
        // 1. Obtener datos principales de la ruta y repartidor
        $sqlRuta = "SELECT
                        r.id_ruta, r.id_repartidor, r.fecha_hora_creacion, r.estado_ruta,
                        r.distancia_total_metros, r.duracion_total_segundos,
                        r.geometria_geojson, r.instrucciones_json,
                        u.nombre AS repartidor_nombre, u.apellido AS repartidor_apellido
                    FROM Rutas r
                    JOIN Usuarios u ON r.id_repartidor = u.id_usuario
                    WHERE r.id_ruta = :id_ruta
                    LIMIT 1";

        $stmtRuta = $conn->prepare($sqlRuta);

        $stmtRuta->bindParam(':id_ruta', $id_ruta, PDO::PARAM_INT);
        $stmtRuta->execute();
        $rutaData = $stmtRuta->fetch(PDO::FETCH_ASSOC);

        if ($rutaData === false) {
            return false;
        }

        // Intenta decodificar los campos JSON
        $geoJsonDecoded = json_decode($rutaData['geometria_geojson'] ?? '', true);

        if (json_last_error() === JSON_ERROR_NONE) {
            $rutaData['geometria_geojson'] = $geoJsonDecoded;
        }
        $instruccionesDecoded = json_decode($rutaData['instrucciones_json'] ?? '', true);
         if (json_last_error() === JSON_ERROR_NONE) {
            $rutaData['instrucciones_json'] = $instruccionesDecoded;
        }


        $sqlDetalles = "SELECT
                            rd.id_ruta_detalle, rd.id_pedido, rd.orden_visita,
                            rd.estado_parada, rd.motivo_fallo, 
                            p.direccion_entrega, p.lat, p.lng,
                            p.nombre_cliente, p.apellido_cliente
                        FROM RutaDetalles rd
                        JOIN Pedidos p ON rd.id_pedido = p.id_pedido
                        WHERE rd.id_ruta = :id_ruta
                        ORDER BY rd.orden_visita ASC";

        $stmtDetalles = $conn->prepare($sqlDetalles);

        $stmtDetalles->bindParam(':id_ruta', $id_ruta, PDO::PARAM_INT);
        $stmtDetalles->execute();
        $detallesData = $stmtDetalles->fetchAll(PDO::FETCH_ASSOC);

        return [
            'ruta' => $rutaData,
            'detalles' => $detallesData
        ];

    } catch (PDOException $e) {

        error_log("Error DB [getDetallesCompletosRuta_2]: " . $e->getMessage());
        return false; // Error de base de datos
    }
}

?>