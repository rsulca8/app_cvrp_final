<?php
require("connection.php"); // Incluye tu conexión PDO ($conn) y getConfiguracionPorClave()
// ini_set('display_errors', 1);
// ini_set('display_startup_errors', 1);
// error_reporting(E_ALL);
header('Content-Type: application/json');

// --- 1. Leer Datos de Entrada ---
$jsonPayload = file_get_contents('php://input');
$data = json_decode($jsonPayload, true);

if (json_last_error() !== JSON_ERROR_NONE || empty($data['pedido_ids']) || empty($data['repartidor_ids'])) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Datos inválidos: Se requieren pedido_ids y repartidor_ids.']);
    exit;
}

$pedido_ids = $data['pedido_ids'];
$repartidor_ids = $data['repartidor_ids'];

// --- 2. Obtener Datos de Pedidos y Repartidores ---
try {
    // Pedidos (con cálculo de demanda y orden)
    $placeholders_pedidos = implode(',', array_fill(0, count($pedido_ids), '?'));
    $sql_pedidos = "SELECT
                        p.*,
                        ROW_NUMBER() OVER(ORDER BY p.id_pedido) as orden_calculado,
                        COALESCE(SUM(dp.cantidad * IFNULL(pr.peso, 0)), 0) AS demanda 
                    FROM Pedidos p
                    LEFT JOIN DetallesPedido dp ON p.id_pedido = dp.id_pedido
                    LEFT JOIN Productos pr ON dp.id_producto = pr.id_producto
                    WHERE p.id_pedido IN ($placeholders_pedidos) AND p.estado = 'Pendiente'
                    GROUP BY p.id_pedido
                    ORDER BY p.id_pedido";
    $stmt_pedidos = $conn->prepare($sql_pedidos);
    $stmt_pedidos->execute($pedido_ids);
    $pedidos_data = $stmt_pedidos->fetchAll(PDO::FETCH_ASSOC);

    // Repartidores
    $placeholders_repartidores = implode(',', array_fill(0, count($repartidor_ids), '?'));
    $sql_repartidores = "SELECT id_usuario, nombre, apellido
                         FROM Usuarios
                         WHERE id_usuario IN ($placeholders_repartidores) AND tipo_usuario = 'Repartidor' AND activo = 1
                         ORDER BY id_usuario";
    $stmt_repartidores = $conn->prepare($sql_repartidores);
    $stmt_repartidores->execute($repartidor_ids);
    $repartidores_data = $stmt_repartidores->fetchAll(PDO::FETCH_ASSOC);

    // Depósito
    $deposito_config = getConfiguracionPorClave($conn, 'deposito_ubicacion');
    if ($deposito_config === false || empty($deposito_config['valor'])) {
        throw new Exception("Configuración 'deposito_ubicacion' no encontrada.");
    }
    $deposito_coords = json_decode($deposito_config["valor"], true);
    if (json_last_error() !== JSON_ERROR_NONE || !isset($deposito_coords['lat']) || !isset($deposito_coords['lng'])) {
        throw new Exception("Valor de 'deposito_ubicacion' inválido.");
    }
    // Validaciones
    if (empty($pedidos_data))
        throw new Exception("No se encontraron pedidos pendientes válidos.");
    if (empty($repartidores_data))
        throw new Exception("No se encontraron repartidores activos válidos.");

} catch (PDOException $e) { 
    http_response_code(500);
    error_log("Error DB [generar_rutas - fetch data]: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => 'Error al obtener datos iniciales.']);
    exit;
} catch (Exception $e) { 
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    exit;
}

// --- 3. Preparar Datos para CVRP ---
$pedidos_ordenados = [];
foreach ($pedidos_data as $p) {
    $pedidos_ordenados[(int) $p['orden_calculado']] = $p;
}
ksort($pedidos_ordenados);

$puntos_cvrp = [];
$puntos_cvrp[0] = ['nodo' => 1, 'coordenadas' => ['lat' => (float) $deposito_coords['lat'], 'lng' => (float) $deposito_coords['lng']]];
$demandas_cvrp = [0];
foreach ($pedidos_ordenados as $orden => $pedido) {
    $puntos_cvrp[$orden] = ['nodo' => $orden + 1, 'coordenadas' => ['lat' => (float) $pedido['lat'], 'lng' => (float) $pedido['lng']]];
    $demandas_cvrp[$orden] = (int) $pedido['demanda'];
}


$capacidad_config = getConfiguracionPorClave($conn, 'capacidad_maxima_vehiculos');
$capacidadMax = $capacidad_config ? (int) $capacidad_config['valor'] : 2000;
$nroVehiculos = count($repartidores_data);

$data_to_solver = http_build_query([ /* ... datos para solver ... */
    'data' => json_encode(array_values($puntos_cvrp)),
    'nroVehiculos' => $nroVehiculos,
    'capacidadMax' => $capacidadMax,
    'demandas' => json_encode(array_values($demandas_cvrp))
]);

// --- 4. Llamar al Solver CVRP (Simulado) ---
// $rutas_nodos = [[1, 2], [1, 3], [1, 4, 5]]; // Simulación
try {
 //TODO: este hardcode debería hacerse configurable con variable de entorno
    $rutas_response = file_get_contents("http://localhost:8000/post", false, stream_context_create([
        'http' => [
            'method' => 'POST',
            'header' => 'Content-Type: application/x-www-form-urlencoded',
            'content' => $data_to_solver
        ]
    ]));

    $response_data = json_decode($rutas_response, true);
    $rutas_nodos = $response_data["rutas"];
    $rutas_nodos = json_decode($response_data["rutas"], true);

    // $rutas_nodos = [[1, 2], [1, 3], [1, 4, 5]]; // Simulación
    if ($rutas_nodos === null) { // Chequear si el solver falló
        throw new Exception("El solver CVRP no devolvió rutas válidas.");
    }
} catch (Exception $e) {
    http_response_code(500);
    error_log("Error Solver CVRP: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => 'Error al calcular las rutas óptimas.']);
    exit;
}


// --- 5. Procesar Rutas, Llamar a OSRM y GUARDAR en DB ---
$osrm_base_url = "http://localhost:5000"; //TODO: este hardcode debería hacerse configurable con variable de entorno
$final_results = []; // Para la respuesta a Flutter
$pedidos_a_actualizar = []; // [ ['id_pedido' => x, 'id_ruta' => y], ... ]

// Prepara las sentencias SQL una sola vez fuera del bucle
$sql_insert_ruta = "INSERT INTO Rutas (id_repartidor, distancia_total_metros, duracion_total_segundos, geometria_geojson, instrucciones_json, estado_ruta)
                    VALUES (:id_repartidor, :distancia, :duracion, :geometria, :instrucciones, 'Asignada')";
$stmt_insert_ruta = $conn->prepare($sql_insert_ruta);

$sql_insert_detalle = "INSERT INTO RutaDetalles (id_ruta, id_pedido, orden_visita) VALUES (:id_ruta, :id_pedido, :orden)";
$stmt_insert_detalle = $conn->prepare($sql_insert_detalle);


$conn->beginTransaction(); // Inicia transacción

try {
    $repartidor_index = 0;

    foreach ($rutas_nodos as $ruta_index => $nodos_ruta) {
        if ($repartidor_index >= count($repartidores_data)) { continue; } // Salta si no hay más repartidores

        $repartidor_asignado = $repartidores_data[$repartidor_index];
        $repartidor_id = $repartidor_asignado['id_usuario'];
        $coordenadas_ruta_osrm = [];
        $ids_pedidos_en_ruta_actual = []; // IDs de pedido para ESTA ruta específica
        $orden_visita_actual = 1; // Contador para el orden en RutaDetalles

        // Convierte nodos a coords y guarda IDs de pedido para esta ruta
        foreach ($nodos_ruta as $nodo) {
            if ($nodo == 1) { // Depósito
                $coordenadas_ruta_osrm[] = (float) $deposito_coords['lng'] . ',' . (float) $deposito_coords['lat'];
            } else {
                $orden_cvrp = $nodo - 1; // Índice basado en 0 usado en $pedidos_ordenados
                if (isset($pedidos_ordenados[$orden_cvrp])) {
                    $pedido_actual = $pedidos_ordenados[$orden_cvrp];
                    $coordenadas_ruta_osrm[] = (float) $pedido_actual['lng'] . ',' . (float) $pedido_actual['lat'];
                    // Guarda el ID del pedido y su orden DENTRO de esta ruta
                    $ids_pedidos_en_ruta_actual[] = ['id' => $pedido_actual['id_pedido'], 'orden' => $orden_visita_actual];
                    $orden_visita_actual++;
                } else {
                    error_log("Nodo CVRP $nodo (orden $orden_cvrp) no encontrado.");
                }
            }
        }

        if (count($coordenadas_ruta_osrm) > 1) {
            $coordenadas_ruta_osrm[] = (float) $deposito_coords['lng'] . ',' . (float) $deposito_coords['lat'];
        }

        // Inicializa variables para OSRM
        $osrm_geometry = null;
        $osrm_instructions = [];
        $osrm_distance = null;
        $osrm_duration = null;
        $ruta_status = 'success'; // Asume éxito inicial
        $ruta_message = 'Ruta generada y procesada.';

        // Llama a OSRM si hay al menos 2 puntos
        if (count($coordenadas_ruta_osrm) >= 2) {
            $osrm_coords_string = implode(';', $coordenadas_ruta_osrm);
            $osrm_url = "{$osrm_base_url}/route/v1/driving/{$osrm_coords_string}?overview=full&steps=true&geometries=geojson&alternatives=false";
            $osrm_response_json = @file_get_contents($osrm_url);

            if ($osrm_response_json === FALSE) {
                error_log("Error conectando a OSRM: $osrm_url");
                $ruta_status = 'error_osrm';
                $ruta_message = 'No se pudo obtener la ruta desde OSRM.';
            } else {
                $osrm_data = json_decode($osrm_response_json, true);
                if ($osrm_data && isset($osrm_data['code']) && $osrm_data['code'] == 'Ok' && !empty($osrm_data['routes'])) {
                    $route_info = $osrm_data['routes'][0];
                    $osrm_geometry = $route_info['geometry']; // GeoJSON
                    $osrm_distance = $route_info['distance'];
                    $osrm_duration = $route_info['duration'];
                    $leg = $route_info['legs'][0] ?? null;
                    $instructions = []; // Reinicia instructions para cada ruta
                    if ($leg && isset($leg['steps'])) {
                        foreach ($leg['steps'] as $step) {
                            $man_type = $step['maneuver']['type'] ?? '';
                            $man_modifier = $step['maneuver']['modifier'] ?? '';
                            $instructions[] = [
                                'maneuver' => trim($man_type . ' ' . $man_modifier),
                                'instruction' => $step['maneuver']['instruction'] ?? '',
                                'distance' => $step['distance'] ?? 0,
                                'duration' => $step['duration'] ?? 0,
                                'name' => $step['name'] ?? ''
                            ];
                        }
                    }
                    $osrm_instructions = $instructions; // Asigna las instrucciones procesadas para esta ruta
                } else {
                    error_log("Respuesta inválida de OSRM: " . $osrm_response_json);
                    $ruta_status = 'error_osrm_response';
                    $ruta_message = 'Respuesta inválida de OSRM.';
                }
            }
        } else { // Menos de 2 puntos
            $ruta_status = 'empty_route';
            $ruta_message = 'Ruta vacía o inválida (menos de 2 puntos).';
        }

        // --- Guarda en Base de Datos SOLO si OSRM no dio error crítico ---
        $id_ruta_nueva = null;
        if ($ruta_status == 'success') { // Solo guarda si OSRM funcionó
            // 1. Inserta en Rutas
            $stmt_insert_ruta->bindParam(':id_repartidor', $repartidor_id);
            $stmt_insert_ruta->bindParam(':distancia', $osrm_distance);
            $stmt_insert_ruta->bindParam(':duracion', $osrm_duration);
            $geometria_json = json_encode($osrm_geometry); // Codifica GeoJSON
            $instrucciones_json = json_encode($osrm_instructions); // Codifica instrucciones
            $stmt_insert_ruta->bindParam(':geometria', $geometria_json);
            $stmt_insert_ruta->bindParam(':instrucciones', $instrucciones_json);
            if (!$stmt_insert_ruta->execute()) {
                throw new PDOException("Error al insertar en Rutas.");
            }
            $id_ruta_nueva = $conn->lastInsertId();

            // 2. Inserta en RutaDetalles y prepara actualización de Pedidos
            foreach ($ids_pedidos_en_ruta_actual as $pedido_info) {
                $stmt_insert_detalle->bindParam(':id_ruta', $id_ruta_nueva);
                $stmt_insert_detalle->bindParam(':id_pedido', $pedido_info['id']);
                $stmt_insert_detalle->bindParam(':orden', $pedido_info['orden']);
                if (!$stmt_insert_detalle->execute()) {
                    throw new PDOException("Error al insertar en RutaDetalles para pedido {$pedido_info['id']}.");
                }
                $pedidos_a_actualizar[] = ['id_pedido' => $pedido_info['id'], 'id_ruta' => $id_ruta_nueva];
            }
        }

        // --- Guarda resultado para la respuesta---
        $final_results[] = [
            'ruta_db_id' => $id_ruta_nueva,
            'repartidor_id' => $repartidor_id,
            'repartidor_nombre' => $repartidor_asignado['nombre'] . ' ' . $repartidor_asignado['apellido'],
            'pedido_ids_ordenados' => $ids_pedidos_en_ruta_actual, 
            'status' => $ruta_status,
            'message' => $ruta_message,
            'geometry' => $osrm_geometry,
            'instructions' => $osrm_instructions,
            'summary' => $osrm_distance !== null ? ['distance' => $osrm_distance, 'duration' => $osrm_duration] : null
        ];

        $repartidor_index++; // Siguiente repartidor
    } // Fin foreach $rutas_nodos

    // --- 6. Actualizar Estado de Pedidos en DB (SIN id_ruta_asignada) ---
    if (!empty($pedidos_a_actualizar)) {
        $ids_para_update = array_column($pedidos_a_actualizar, 'id_pedido');
        $ids_para_update = array_unique($ids_para_update); // Asegura únicos

        $placeholders_update = implode(',', array_fill(0, count($ids_para_update), '?'));
        $sql_update_simple = "UPDATE Pedidos SET estado = 'En Proceso' WHERE id_pedido IN ($placeholders_update)";
        $stmt_update_simple = $conn->prepare($sql_update_simple);

        if (!$stmt_update_simple->execute($ids_para_update)) {
            error_log("Error al actualizar estado para pedidos: " . implode(',', $ids_para_update));

        }
    }


    $conn->commit(); // Confirma todos los cambios si no hubo excepciones

    // --- 7. Respuesta Final ---
    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'message' => 'Proceso de generación de rutas completado.',
        'rutas_asignadas' => $final_results
    ]);

} catch (PDOException $e) { 
    if ($conn->inTransaction())
        $conn->rollBack();
    http_response_code(500);
    error_log("Error DB [generar_rutas - transaction]: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => 'Error de base de datos durante la operación.']);
} catch (Exception $e) { 
    if ($conn->inTransaction())
        $conn->rollBack();
    http_response_code(500);
    error_log("Error General [generar_rutas]: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
?>