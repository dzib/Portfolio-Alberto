/* 
==================================================================================================
PROYECTO: P1_Inventario -Sistema de Gestión de Inventario-
FASE 5: (SQL) - Business Intelligence (BI) & Capa de Analytics
AUTOR: Alberto Dzib
VERSIÓN: 2.0
DESCRIPCIÓN:
    - Creación del esquema Analytics para segregación de reportes.
    - Vista Global de Ventas: Unifica Pedidos (Online) y Ventas (Mostrador).
    - KPIs Ejecutivos: Top Sellers, Desempeño por Canal y Alertas Logísticas.
    - Este script consolida las ventas y analiza el rendimiento del inventario.
==================================================================================================
*/

USE P1_Inventario;
GO

-- --------------------------------------------------------------------------------------------------------------
-- 1. CREACIÓN DE ESQUEMA ANALÍTICO
-- --------------------------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Analytics') EXEC('CREATE SCHEMA Analytics');
GO

-- Esta vista se une Pedidos Online y Ventas de Mostrador en un solo reporte lógico.

PRINT '--- PASO 1: CREANDO VISTA CONSOLIDADA DE INGRESOS (OMNICHANNEL) ---';
GO 

CREATE OR ALTER VIEW Analytics.vw_ReporteGlobalVentas AS
SELECT 
    'Pedido Online' AS Canal,
    p.FechaPedido AS Fecha_Transaccion,
    c.Nombre AS Entidad_Origen,
    cat.Nombre AS Categoria_Producto,
    pr.Nombre AS Nombre_Producto,
    pr.Modelo_Ref AS Modelo_Producto,
    dp.Cantidad,
    dp.PrecioUnitario,
    (dp.Cantidad * dp.PrecioUnitario) AS Subtotal,
    p.Estado_Info AS Estatus_Actual 
FROM Operaciones.Pedidos p
JOIN Operaciones.Clientes c ON p.ClienteID = c.ClienteID
JOIN Operaciones.DetallePedido dp ON p.PedidoID = dp.PedidoID
JOIN Inventario.Productos pr ON dp.ProductoID = pr.ProductoID
JOIN Inventario.Categorias cat ON pr.CategoriaID = cat.CategoriaID
UNION ALL
SELECT 
    'Venta Mostrador' AS Canal,
    v.FechaVenta AS Fecha_Transaccion,
    v.Sucursal_Info AS Entidad_Origen,
    cat.Nombre AS Categoria_Producto,
    pr.Nombre AS Nombre_Producto,
    pr.Modelo_Ref AS Modelo_Producto,
    v.Cantidad,
    v.PrecioAplicado AS PrecioUnitario,
    (v.Cantidad * v.PrecioAplicado) AS Subtotal,
    'Pagado' AS Estatus_Actual
FROM Operaciones.Ventas_Mostrador v
JOIN Inventario.Productos pr ON v.ProductoID = pr.ProductoID
JOIN Inventario.Categorias cat ON pr.CategoriaID = cat.CategoriaID;
GO

----------------------------------------------------------------------------------------------------------------
PRINT '--- PASO 2: GENERANDO KPIS EJECUTIVOS (PRUEBA DE CONCEPTO) ---';
GO
-- --------------------------------------------------------------------------------------------------------------
-- KPI 1: Salud del Inventario (BI Preventivo)
-- --------------------------------------------------------------------------------------------------------------
CREATE OR ALTER VIEW Analytics.vw_Alerta_Logistica AS
SELECT 
    prov.Nombre AS Proveedor,
    prod.Nombre AS Producto,
    prod.Modelo_Ref AS Modelo,
    prod.StockActual,
    prod.StockMinimo,
    CASE 
        WHEN prod.StockActual <= prod.StockMinimo THEN 'REABASTECIMIENTO URGENTE'
        WHEN prod.StockActual <= prod.StockMinimo * 1.5 THEN 'STOCK BAJO'
        ELSE 'SALUDABLE'
    END AS Semaforo_Logistico
FROM Inventario.Proveedores prov
JOIN Inventario.Productos prod ON prov.ProveedorID = prod.ProveedorID;
GO
---------------------------------------------------------------------------------------------------------------
-- KPI 2: Top 5 Categorías por Ingreso (Para Gráfico de Pastel en Excel) (Top Sellers)
-- --------------------------------------------------------------------------------------------------------------
SELECT TOP 5 
    Categoria_Producto, 
    FORMAT(SUM(Cantidad), 'N0', 'es-MX') AS Unidades_Vendidas,
    FORMAT(SUM(Subtotal), 'C', 'es-MX') AS Ingreso_Total
FROM Analytics.vw_ReporteGlobalVentas
WHERE UPPER(Estatus_Actual) NOT LIKE '%Cancelado%' -- Filtro de integridad forzamos mayúsculas para comparar.
GROUP BY Categoria_Producto
ORDER BY SUM(Subtotal) DESC;
GO

PRINT '=====================================================';
PRINT '✅ Fase 1.5: Capa de Analytics (Omnicanal) Finalizada';
PRINT '⏱️ Tiempo de validación: ' + CAST(DATEDIFF(MS, GETDATE(), GETDATE()) AS VARCHAR) + ' ms';
PRINT '=====================================================';
