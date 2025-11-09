<?php
// get_imagenes.php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require("connection.php");
header('Content-Type: application/json');

/**
 * Busca una imagen usando la API de Google, la guarda en el servidor y retorna su ruta relativa.
 *
 * @param string $busqueda Término a buscar.
 * @return string Ruta relativa de la imagen o cadena vacía si falla.
 */
function get_imagen($busqueda) {
    $directorio_guardado = '/var/www/html/cvrp/imagenes/'; // Ajustar según servidor
    $ruta_relativa_base = '/imagenes/'; // Ajustar según servidor

    $apiKey = getenv('GOOGLE_API_KEY');
    $cx = getenv('GOOGLE_SEARCH_CX'); // ID del motor de búsqueda personalizado

    if (!$apiKey || !$cx) {
        error_log("Faltan variables de entorno GOOGLE_API_KEY o GOOGLE_SEARCH_CX");
        return "";
    }

    $q = $busqueda;
    $cantidad = 1;
    $query = sprintf(
        "https://customsearch.googleapis.com/customsearch/v1?cx=%s&q=%s&searchType=image&key=%s&num=%s&fileType=png",
        $cx,
        urlencode($q),
        $apiKey,
        $cantidad
    );

    $respuesta_api = @file_get_contents($query);
    if ($respuesta_api === false) {
        error_log("Error al contactar con la API de Google para: $q");
        return "";
    }
    
    $resultado = json_decode($respuesta_api);

    if (!isset($resultado->items) || $resultado->searchInformation->totalResults == 0) {
        error_log("No se encontraron resultados para: $q");
        return "";
    }

    $link_imagen = $resultado->items[0]->link;
    
    $datos_imagen = @file_get_contents($link_imagen);
    if ($datos_imagen === false) {
        error_log("Error al descargar la imagen: $link_imagen");
        return "";
    }

    $extension = pathinfo(parse_url($link_imagen, PHP_URL_PATH), PATHINFO_EXTENSION);
    if (empty($extension) || strlen($extension) > 5) {
        $headers = @get_headers($link_imagen, 1);
        if (isset($headers['Content-Type'])) {
             $mime = $headers['Content-Type'];
             if ($mime == 'image/jpeg') $extension = 'jpg';
             else if ($mime == 'image/png') $extension = 'png';
             else if ($mime == 'image/webp') $extension = 'webp';
             else $extension = 'jpg';
        } else {
             $extension = 'jpg';
        }
    }
    $nombre_unico = uniqid() . '.' . preg_replace('/[^A-Za-z0-9]/', '', $extension);

    $ruta_completa_guardado = $directorio_guardado . $nombre_unico;

    if (file_put_contents($ruta_completa_guardado, $datos_imagen)) {
        return $ruta_relativa_base . $nombre_unico;
    } else {
        error_log("Error al guardar archivo en: $ruta_completa_guardado");
        return "";
    }
}

/**
 * Actualiza masivamente las imágenes de productos que no tienen una asignada.
 *
 * @param PDO $conn Objeto de conexión PDO.
 * @return array Resumen de la operación.
 */
function actualizarImagenesProductos(PDO $conn): array
{
    $reporte = ['actualizados' => 0, 'fallidos' => 0, 'errores' => []];

    try {
        $sql_update = "UPDATE Productos SET imagen_portada = :imagen_ruta WHERE id_producto = :id_producto";
        $stmt_update = $conn->prepare($sql_update);

        $sql_select = "SELECT id_producto, nombre FROM Productos WHERE imagen_portada IS NULL OR imagen_portada = '' OR imagen_portada = '0'";
        $stmt_select = $conn->query($sql_select);

        if ($stmt_select === false) {
            throw new Exception("Error al seleccionar productos.");
        }
        $productos = $stmt_select->fetchAll(PDO::FETCH_ASSOC);

        if (empty($productos)) {
             $reporte['message'] = "No hay productos pendientes de actualización de imagen.";
             return $reporte;
        }

        foreach ($productos as $producto) {
            $id = $producto['id_producto'];
            $nombre_busqueda = $producto['nombre'];

            $ruta_imagen_relativa = get_imagen($nombre_busqueda);

            if (!empty($ruta_imagen_relativa)) {
                $stmt_update->bindParam(':imagen_ruta', $ruta_imagen_relativa, PDO::PARAM_STR);
                $stmt_update->bindParam(':id_producto', $id, PDO::PARAM_INT);
                
                if ($stmt_update->execute()) {
                    if ($stmt_update->rowCount() > 0) {
                        $reporte['actualizados']++;
                    }
                } else {
                    $reporte['fallidos']++;
                    $reporte['errores'][] = "Error SQL ID $id.";
                }
            } else {
                $reporte['fallidos']++;
                $reporte['errores'][] = "Imagen no encontrada para ID $id ($nombre_busqueda).";
            }
            // usleep(500000); // Descomentar para evitar rate limits si es necesario
        }
        
        $reporte['message'] = "Actualización masiva completada.";

    } catch (PDOException $e) {
        error_log("Error DB [actualizarImagenes]: " . $e->getMessage());
        $reporte['status'] = 'error';
        $reporte['message'] = 'Error DB: ' . $e->getMessage();
        http_response_code(500);
    } catch (Exception $e) {
         error_log("Error [actualizarImagenes]: " . $e->getMessage());
         $reporte['status'] = 'error';
         $reporte['message'] = $e->getMessage();
         http_response_code(500);
    }

    return $reporte;
}

// --- Controladores ---

if (isset($_GET["q"])) {
    $ruta = get_imagen($_GET["q"]);
    if (!empty($ruta)) {
        echo json_encode(['status' => 'success', 'ruta_imagen' => $ruta]);
    } else {
         http_response_code(404);
         echo json_encode(['status' => 'error', 'message' => 'No se encontró imagen.']);
    }

} elseif (isset($_GET["actualizar_todas"]) && $_GET["actualizar_todas"] == 'true') {
    set_time_limit(600); // 10 minutos máximo
    $resultado = actualizarImagenesProductos($conn);
    if (!isset($resultado['status'])) {
         echo json_encode(['status' => 'success', 'reporte' => $resultado]);
    } else {
         echo json_encode($resultado);
    }

} else {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Parámetros inválidos.']);
}
?>