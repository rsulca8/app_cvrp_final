<?php
    ini_set('display_errors', 1);
    ini_set('display_startup_errors', 1);
    error_reporting(E_ALL);

    require("connection.php");
    require("get_imagenes.php");


function importarProductosCSV($conn) {
    
    // 1. Cachés para optimizar consultas
    $categorias_cache = getCategoriasMap($conn); 
    $dimensiones_cache = []; 

    // 2. Mapeo simple de unidades de peso (CSV -> ID de tu DB)
    $map_unidades_peso = [
        'g'   => 1, // Asumiendo que 1 es 'g'
        'gr'  => 1, // 'gr' también es 'g'
        'kg'  => 2  // Asumiendo que 2 es 'kg'
    ];
    
    // $gestor = fopen("productos.csv", "r");
    $gestor = fopen("producto2_modificados.csv", "r");
    
    if ($gestor === FALSE) {
        echo "Error: No se pudo abrir el archivo productos.csv";
        return;
    }

    // 3. Leer la primera línea (cabecera) para descartarla
    fgetcsv($gestor, 2000, ";"); 

    echo "Iniciando importación... <br>";

    // 4. Bucle principal
    while (($datos = fgetcsv($gestor, 1000, ";")) !== FALSE) {
        //print_r($datos);
        if (count($datos) < 5) {
            echo "Fila saltada (datos incompletos): " . implode(";", $datos) . "<br>";
            continue; 
        }

        // 5. Mapeo de datos del CSV a variables limpias
        $nombre_completo = trim($datos[0]);
        $peso_valor = (float) str_replace(',', '.', $datos[1]); // Convertir "1,5" a 1.5
        $peso_unidad_str = trim(strtolower($datos[2]));
        $marca = trim($datos[3]);
        $precio = (float) str_replace(',', '.', $datos[4]);

        // Si el nombre o el precio están vacíos, saltar fila
        if (empty($nombre_completo) || empty($precio)) {
            echo "Fila saltada (nombre o precio vacío): " . $nombre_completo . "<br>";
            continue;
        }

        // 6. Lógica de Categoría (Tu Requerimiento 1)
        $partes_nombre = explode(' ', $nombre_completo);
        $nombre_categoria = ucfirst(strtolower($partes_nombre[0])); // "Aceite", "Arroz", "Polenta"
        // Pasamos el caché por referencia para que se actualice
        $id_categoria = getOrInsertCategoria($conn, $nombre_categoria, $categorias_cache);

        // 7. Lógica de Dimensiones (Tu Requerimiento 2)
        // Pasamos el caché de dimensiones por referencia
        $dimensiones = getDimensionesParaCategoria($nombre_categoria, $dimensiones_cache);

        // 8. Mapeo de Unidades
        $id_unidad_peso = $map_unidades_peso[$peso_unidad_str] ?? 1; // ID 1 ('g') por defecto
        $id_unidad_dimension = 1; // Asumiendo ID 1 = 'cm'

        if (!existeProducto($conn, $nombre_completo)){

            // 9. Preparar el array del producto (coincide con tu tabla Productos)
            $producto = [
                "nombre" => $nombre_completo,
                "descripcion" => $nombre_completo, // Puedes poner una descripción más larga aquí
                "precio" => $precio,
                "descuento_porcentaje" => 0.00,
                "codigo_barra" => '779' . str_pad(rand(0, 9999999999), 10, '0', STR_PAD_LEFT), // Genera uno aleatorio
                "sku" => null, // Sku aleatorio
                "stock" => rand(50, 200),
                "peso" => $peso_valor,
                "id_unidad_peso" => $id_unidad_peso,
                "ancho" => $dimensiones['ancho'],
                "alto" => $dimensiones['alto'],
                "profundidad" => $dimensiones['profundidad'],
                "id_unidad_dimension" => $id_unidad_dimension,
                "marca" => $marca,
                // "imagen_portada" => "/img/productos/" . strtolower($nombre_categoria) . ".jpg", // Imagen genérica
                "imagen" => get_imagen($nombre_completo), // Imagen genérica

                "id_categoria" => $id_categoria,
                "id_estado" => 1 // Asumiendo ID 1 = 'Publicado'
            ];

            // 10. Insertar en la base de datos
                insertarProductos($conn, $producto);
                echo "<p>Producto '" . $producto['nombre'] . "' insertado.</p>\n";
        }
    }

    fclose($gestor);
    echo "<h2>¡Proceso completado!</h2>";
}


/**
 * Inserta un producto en la BD usando sentencias preparadas (más seguro).
 * Esta función DEBE coincidir con tu tabla 'Productos'.
 *
 * @param mysqli $conn La conexión a la base de datos.
 * @param array $producto El array asociativo con los datos del producto.
 */
function insertarProductos($conn, $producto) {

    $sql = "INSERT INTO Productos (
                nombre, descripcion, precio, descuento_porcentaje, 
                codigo_barra, sku, stock, peso, 
                id_unidad_peso, ancho, alto, profundidad, 
                id_unidad_dimension, marca, imagen, 
                id_categoria, id_estado
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    $stmt = mysqli_prepare($conn, $sql);

    if ($stmt === false) {
        echo "Error al preparar la consulta: " . mysqli_error($conn);
        return;
    }

    // "ssddssidiiddisisi" es el string de tipos para bind_param:
    // s = string, d = double (decimal), i = integer
    mysqli_stmt_bind_param($stmt, "ssddssidiiddisisi", 
        $producto['nombre'],
        $producto['descripcion'],
        $producto['precio'],
        $producto['descuento_porcentaje'],
        $producto['codigo_barra'],
        $producto['sku'],
        $producto['stock'],
        $producto['peso'],
        $producto['id_unidad_peso'],
        $producto['ancho'],
        $producto['alto'],
        $producto['profundidad'],
        $producto['id_unidad_dimension'],
        $producto['marca'],
        $producto['imagen'],
        $producto['id_categoria'],
        $producto['id_estado']
    );

    if (!mysqli_stmt_execute($stmt)) {
        echo "Error al ejecutar la consulta: " . mysqli_stmt_error($stmt) . "<br>";
    }

    mysqli_stmt_close($stmt);


}


/**
 * Obtiene o crea una categoría y devuelve su ID.
 * Usa un caché (array) para evitar consultar la BD por cada producto.
 *
 * @param mysqli $conn La conexión a la base de datos.
 * @param string $nombreCategoria El nombre de la categoría (ej: "Aceite").
 * @param array &$cache El array de caché (pasado por referencia).
 * @return int El ID de la categoría.
 */
function getOrInsertCategoria($conn, $nombreCategoria, &$cache) {
    // Si la categoría ya está en el caché, la devolvemos
    if (isset($cache[$nombreCategoria])) {
        return $cache[$nombreCategoria];
    }

    // Si no, la buscamos en la BD
    $sql = "SELECT id_categoria FROM Categorias WHERE nombre_categoria = ?";
    $stmt = mysqli_prepare($conn, $sql);
    mysqli_stmt_bind_param($stmt, "s", $nombreCategoria);
    mysqli_stmt_execute($stmt);
    $resultado = mysqli_stmt_get_result($stmt);

    if ($fila = mysqli_fetch_assoc($resultado)) {
        // Encontrada: la guardamos en caché y la devolvemos
        $id = $fila['id_categoria'];
        $cache[$nombreCategoria] = $id;
        mysqli_stmt_close($stmt);
        return $id;
    } else {
        // No encontrada: la insertamos
        mysqli_stmt_close($stmt);
        $sql_insert = "INSERT INTO Categorias (nombre_categoria) VALUES (?)";
        $stmt_insert = mysqli_prepare($conn, $sql_insert);
        mysqli_stmt_bind_param($stmt_insert, "s", $nombreCategoria);
        mysqli_stmt_execute($stmt_insert);
        
        $id_nuevo = mysqli_insert_id($conn); // Obtenemos el nuevo ID
        $cache[$nombreCategoria] = $id_nuevo; // La guardamos en caché
        mysqli_stmt_close($stmt_insert);
        
        echo "<i>Nueva categoría creada: " . $nombreCategoria . " (ID: " . $id_nuevo . ")</i><br>";
        return $id_nuevo;
    }
}


/**
 * Genera dimensiones aleatorias pero consistentes para una categoría.
 *
 * @param string $nombreCategoria El nombre de la categoría.
 * @param array &$cache El array de caché de dimensiones (pasado por referencia).
 * @return array Un array asociativo con ['ancho', 'alto', 'profundidad'].
 */
function getDimensionesParaCategoria($nombreCategoria, &$cache) {
    // Si no hemos guardado dimensiones base para esta categoría...
    if (!isset($cache[$nombreCategoria])) {
        // Creamos dimensiones base aleatorias
        $cache[$nombreCategoria] = [
            'ancho_base' => rand(5, 15),  // Ancho base entre 5 y 15 cm
            'alto_base'  => rand(10, 30), // Alto base entre 10 y 30 cm
            'prof_base'  => rand(5, 15)  // Prof. base entre 5 y 15 cm
        ];
    }

    // Tomamos las dimensiones base
    $base = $cache[$nombreCategoria];

    // Calculamos una pequeña variación (ej: +/- 1.5 cm)
    $var_ancho = rand(-15, 15) / 10; 
    $var_alto = rand(-15, 15) / 10;
    $var_prof = rand(-15, 15) / 10;

    // Devolvemos las dimensiones finales (asegurándonos que nunca sean 0 o menos)
    return [
        'ancho' => max(1, round($base['ancho_base'] + $var_ancho, 1)),
        'alto'  => max(1, round($base['alto_base'] + $var_alto, 1)),
        'profundidad' => max(1, round($base['prof_base'] + $var_prof, 1))
    ];
}


/**
 * Carga todas las categorías existentes en un mapa (array)
 * para reducir consultas a la BD.
 *
 * @param mysqli $conn La conexión a la base de datos.
 * @return array Mapa de [nombre_categoria => id_categoria].
 */
function getCategoriasMap($conn) {
    $map = [];
    $sql = "SELECT id_categoria, nombre_categoria FROM Categorias";
    $resultado = mysqli_query($conn, $sql);
    
    if ($resultado) {
        while ($fila = mysqli_fetch_assoc($resultado)) {
            $map[$fila['nombre_categoria']] = $fila['id_categoria'];
        }
    }
    return $map;
}

    //insertarRubros($conn);
    importarProductosCSV($conn);
    function existeProducto($conn, $nombre_producto){
        // Si no, la buscamos en la BD
        $sql = "SELECT id_producto FROM Productos WHERE nombre = ?";
        $stmt = mysqli_prepare($conn, $sql);
        mysqli_stmt_bind_param($stmt, "s", $nombre_producto);
        mysqli_stmt_execute($stmt);
        $resultado = mysqli_stmt_get_result($stmt);
        $fila = mysqli_fetch_assoc($resultado);
        mysqli_stmt_close($stmt);

        return isset($fila);
    }


?>
