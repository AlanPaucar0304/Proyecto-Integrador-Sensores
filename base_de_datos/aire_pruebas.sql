/* =====================================================================
   Pruebas de integridad y metadatos - aire_db (SQL Server)
   Todo va dentro de una transaccion que se deshace (ROLLBACK):
   los datos de la base quedan igual que antes de correr esto.
   ===================================================================== */
USE aire_db;
GO
SET NOCOUNT ON;
DECLARE @r TABLE (prueba VARCHAR(70), resultado VARCHAR(250));
DECLARE @lec INT, @ale INT;

BEGIN TRAN;

-- 1. Clave foranea: lectura de una sesion que no existe
BEGIN TRY
  INSERT INTO LECTURA (co2_lec, ruido_lec, cod_ses) VALUES (500, 30, 9);
  INSERT INTO @r VALUES ('1. Lectura con una sesion que no existe (FK)', 'ACEPTADA');
END TRY
BEGIN CATCH
  INSERT INTO @r VALUES ('1. Lectura con una sesion que no existe (FK)', 'RECHAZADA: ' + LEFT(ERROR_MESSAGE(), 200));
END CATCH;

-- 2. CHECK: humedad fuera de 0-100
BEGIN TRY
  INSERT INTO LECTURA (humedad_lec, co2_lec, ruido_lec, cod_ses) VALUES (150, 500, 30, 1);
  INSERT INTO @r VALUES ('2. Humedad de 150 % (CHECK)', 'ACEPTADA');
END TRY
BEGIN CATCH
  INSERT INTO @r VALUES ('2. Humedad de 150 % (CHECK)', 'RECHAZADA: ' + LEFT(ERROR_MESSAGE(), 200));
END CATCH;

-- 3. CHECK: tipo de dispositivo no permitido
BEGIN TRY
  INSERT INTO DISPOSITIVO (cod_dis, nombre_dis, placa_dis, tipo_dis) VALUES (9, 'Prueba', 'ESP32', 'OTRO');
  INSERT INTO @r VALUES ('3. Dispositivo de tipo OTRO (CHECK)', 'ACEPTADA');
END TRY
BEGIN CATCH
  INSERT INTO @r VALUES ('3. Dispositivo de tipo OTRO (CHECK)', 'RECHAZADA: ' + LEFT(ERROR_MESSAGE(), 200));
END CATCH;

-- 4. Integridad referencial: borrar un tipo de alerta que ya se uso
BEGIN TRY
  DELETE FROM TIPO_ALERTA WHERE cod_tal = 2;
  INSERT INTO @r VALUES ('4. Borrar el tipo de alerta CO2 ALTO (NO ACTION)', 'ACEPTADA');
END TRY
BEGIN CATCH
  INSERT INTO @r VALUES ('4. Borrar el tipo de alerta CO2 ALTO (NO ACTION)', 'RECHAZADA: ' + LEFT(ERROR_MESSAGE(), 200));
END CATCH;

-- 5. Valores por defecto: lectura sin fecha ni ventilador
INSERT INTO LECTURA (temperatura_lec, humedad_lec, co2_lec, ruido_lec, cod_ses) VALUES (24.00, 70.00, 1751, 30, 1);
INSERT INTO @r
  SELECT '5. Lectura sin fecha ni ventilador (DEFAULT)',
         'ACEPTADA: fecha_hora_lec = ' + CONVERT(VARCHAR(19), fecha_hora_lec, 120)
         + ' (GETDATE), ventilador_lec = ' + CAST(ventilador_lec AS VARCHAR(1))
  FROM LECTURA WHERE cod_lec = SCOPE_IDENTITY();

-- 6. Borrado en cascada: borrar la sesion 2
SELECT @lec = COUNT(*) FROM LECTURA WHERE cod_ses = 2;
SELECT @ale = COUNT(*) FROM ALERTA a JOIN LECTURA l ON l.cod_lec = a.cod_lec WHERE l.cod_ses = 2;
DELETE FROM SESION WHERE cod_ses = 2;
INSERT INTO @r VALUES ('6. Borrar la sesion 2 (CASCADE)',
  'ACEPTADA: se borraron con ella ' + CAST(@lec AS VARCHAR(5)) + ' lecturas y ' + CAST(@ale AS VARCHAR(5)) + ' alertas');

ROLLBACK;   -- se deshacen las pruebas
DBCC CHECKIDENT ('LECTURA', RESEED, 111) WITH NO_INFOMSGS;   -- el autonumerico vuelve a 111

SELECT prueba, resultado FROM @r;
SELECT (SELECT COUNT(*) FROM LECTURA) AS lecturas_despues, (SELECT COUNT(*) FROM ALERTA) AS alertas_despues;
GO

-- 7. METADATOS: descripcion de cada tabla y columna
SELECT t.name AS tabla,
       ISNULL(c.name, '(tabla)') AS columna,
       CAST(ep.value AS VARCHAR(200)) AS descripcion
FROM sys.extended_properties ep
JOIN sys.tables t ON t.object_id = ep.major_id
LEFT JOIN sys.columns c ON c.object_id = ep.major_id AND c.column_id = ep.minor_id
WHERE ep.name = 'MS_Description'
ORDER BY t.name, ep.minor_id;
GO
