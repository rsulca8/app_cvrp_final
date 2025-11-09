-- Script para insertar 15 pedidos de ejemplo con IDs de usuario 16-30
-- Ubicaciones distribuidas por Salta Capital, más alejadas del centro.

-- Pedido 1 (Cliente ID 16: Juan Perez) - ZONA SUR (B° Santa Ana)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    16, 'Pendiente', 0.00, 'Juan', 'Perez', 'juan.perez@email.com', '3874111222', 'Av. San Nicolás de Bari 450, B° Santa Ana I, Salta', -24.845310, -65.440850, NOW() - INTERVAL 1 DAY
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 50, 1, 2100.00),
(@pedido_id, 150, 2, 1600.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 2 (Cliente ID 17: Maria Gomez) - ZONA NORTE (Vaqueros)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    17, 'Pendiente', 0.00, 'Maria', 'Gomez', 'maria.gomez@email.com', '3875222333', 'Av. San Martín 350, Vaqueros, Salta', -24.718500, -65.433200, NOW() - INTERVAL 1 DAY
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 25, 3, 950.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 3 (Cliente ID 18: Carlos Rodriguez) - ZONA OESTE (San Lorenzo Chico)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    18, 'Pendiente', 0.00, 'Carlos', 'Rodriguez', 'carlos.r@email.com', '3876333444', 'Av. principal San Lorenzo Chico, Salta', -24.755100, -65.485500, NOW() - INTERVAL 2 DAY
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 112, 1, 4500.00),
(@pedido_id, 220, 2, 330.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 4 (Cliente ID 19: Ana Lopez) - ZONA SUR (B° San Luis)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    19, 'Pendiente', 0.00, 'Ana', 'Lopez', 'ana.lopez@email.com', '3874444555', 'Ruta 51 Km 4, B° San Luis, Salta', -24.862300, -65.465800, NOW() - INTERVAL 6 HOUR
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 303, 1, 1990.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 5 (Cliente ID 20: Luis Martinez) - ZONA ESTE (Villa Mitre)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    20, 'Pendiente', 0.00, 'Luis', 'Martinez', 'luis.m@email.com', '3875555666', 'Av. Hipólito Yrigoyen 1800, Villa Mitre, Salta', -24.805100, -65.401200, NOW() - INTERVAL 4 HOUR
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 440, 2, 600.00),
(@pedido_id, 515, 1, 1200.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 6 (Cliente ID 21: Sofia Diaz) - ZONA NORTE (B° El Huaico)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    21, 'Pendiente', 0.00, 'Sofia', 'Diaz', 'sofia.diaz@email.com', '3876666777', 'Av. de la Universidad 2500, B° El Huaico, Salta', -24.726500, -65.423300, NOW() - INTERVAL 3 HOUR
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 710, 1, 850.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 7 (Cliente ID 22: Javier Romero) - ZONA SUR (Cerrillos)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    22, 'Pendiente', 0.00, 'Javier', 'Romero', 'javier.r@email.com', '3874777888', 'Av. Gral. Güemes 300, Cerrillos, Salta', -24.895000, -65.488000, NOW() - INTERVAL 2 HOUR
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 18, 5, 250.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 8 (Cliente ID 23: Valentina Alvarez) - ZONA OESTE (Grand Bourg)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    23, 'En Proceso', 0.00, 'Valentina', 'Alvarez', 'vale.a@email.com', '3875888999', 'Av. Los Incas 3100, Grand Bourg, Salta', -24.810500, -65.437000, NOW() - INTERVAL 2 DAY
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 770, 1, 990.00),
(@pedido_id, 771, 1, 1400.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 9 (Cliente ID 24: Matias Ruiz) - ZONA NORTE (Ciudad del Milagro)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    24, 'En Proceso', 0.00, 'Matias', 'Ruiz', 'matias.r@email.com', '3876999000', 'Av. Batalla de Salta 500, Ciudad del Milagro, Salta', -24.753500, -65.427800, NOW() - INTERVAL 1 DAY
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 101, 2, 700.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 10 (Cliente ID 25: Camila Sanchez) - ZONA SUR (B° Intersindical)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    25, 'En Proceso', 0.00, 'Camila', 'Sanchez', 'cami.s@email.com', '3874123123', 'Av. Radio Independencia 3500, B° Intersindical, Salta', -24.825000, -65.430000, NOW() - INTERVAL 1 DAY
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 210, 1, 350.00),
(@pedido_id, 215, 3, 410.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 11 (Cliente ID 26: Diego Torres) - ZONA ESTE (B° Autódromo)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    26, 'Entregado', 0.00, 'Diego', 'Torres', 'diego.t@email.com', '3875234234', 'Av. Autódromo 150, Salta', -24.811500, -65.395600, NOW() - INTERVAL 5 DAY
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 501, 1, 220.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 12 (Cliente ID 27: Laura Paz) - ZONA NORTE (B° Castañares)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    27, 'Entregado', 0.00, 'Laura', 'Paz', 'laura.paz@email.com', '3876345345', 'Av. Houssay 2100, B° Castañares, Salta', -24.733000, -65.419000, NOW() - INTERVAL 4 DAY
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 655, 1, 1300.00),
(@pedido_id, 660, 2, 400.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 13 (Cliente ID 28: Martin Gutierrez) - ZONA SUR (Atocha)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    28, 'Entregado', 0.00, 'Martin', 'Gutierrez', 'martin.g@email.com', '3874567567', 'Ruta 51 Km 7, Atocha, Salta', -24.850500, -65.480000, NOW() - INTERVAL 3 DAY
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 11, 2, 650.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 14 (Cliente ID 29: Luciana Vera) - ZONA OESTE (San Lorenzo)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    29, 'Cancelado', 0.00, 'Luciana', 'Vera', 'lu.vera@email.com', '3875678678', 'Av. San Martín 2100, San Lorenzo, Salta', -24.770000, -65.495000, NOW() - INTERVAL 4 DAY
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 790, 1, 1500.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;

-- Pedido 15 (Cliente ID 30: Pedro Acuña) - ZONA NORTE (B° Huaico II - Mirasoles)
INSERT INTO Pedidos (id_usuario, estado, total_pedido, nombre_cliente, apellido_cliente, email, telefono, direccion_entrega, lat, lng, fecha_hora_pedido)
VALUES (
    30, 'Pendiente', 0.00, 'Pedro', 'Acuña', 'pedro.a@email.com', '3876789789', 'Av. de las Vicuñas 300, B° Mirasoles, Salta', -24.722000, -65.420000, NOW() - INTERVAL 10 MINUTE
);
SET @pedido_id = LAST_INSERT_ID();
INSERT INTO DetallesPedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(@pedido_id, 222, 1, 100.00),
(@pedido_id, 333, 2, 250.00);
UPDATE Pedidos SET total_pedido = (SELECT SUM(cantidad * precio_unitario) FROM DetallesPedido WHERE id_pedido = @pedido_id) WHERE id_pedido = @pedido_id;
