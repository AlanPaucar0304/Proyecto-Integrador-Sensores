/* =====================================================================
   Sistema de monitoreo de calidad del aire - Proyecto integrador PAO 3
   Base de datos: aire_db   Gestor: SQL Server 2022 (Express) + SSMS
   Convencion de nombres: tablas en MAYUSCULA; columnas en snake_case
   con sufijo de su tabla (dis, lug, ses, lec, tal); dominios dom_;
   restricciones pk_, fk_, ck_, df_, uq_. Sin tildes ni enie.
   ===================================================================== */

-- 1. CREAR LA BASE DE DATOS
CREATE DATABASE aire_db;
GO
USE aire_db;
GO

-- 2. DOMINIOS (tipos de dato definidos por el usuario)
CREATE TYPE dom_codigo FROM INT NOT NULL;
CREATE TYPE dom_nombre FROM VARCHAR(50) NOT NULL;
CREATE TYPE dom_tipo FROM VARCHAR(20) NOT NULL;
CREATE TYPE dom_texto_opcional FROM VARCHAR(100) NULL;
CREATE TYPE dom_fecha FROM DATETIME NOT NULL;
CREATE TYPE dom_fecha_opcional FROM DATETIME NULL;
CREATE TYPE dom_medida_opcional FROM DECIMAL(5,2) NULL;
CREATE TYPE dom_medida_entera FROM INT NOT NULL;
CREATE TYPE dom_estado FROM BIT NOT NULL;
CREATE TYPE dom_volumen FROM DECIMAL(8,3) NULL;
CREATE TYPE dom_condicion FROM VARCHAR(2) NOT NULL;
CREATE TYPE dom_umbral FROM DECIMAL(7,2) NOT NULL;
GO

-- 3. TABLAS (con PK, FK, CHECK, DEFAULT y UNIQUE)
CREATE TABLE DISPOSITIVO (
  cod_dis     dom_codigo,
  nombre_dis  dom_nombre,
  placa_dis   dom_nombre,
  tipo_dis    dom_tipo CONSTRAINT df_dispositivo_tipo DEFAULT 'SIMULADO',
  CONSTRAINT pk_dispositivo PRIMARY KEY (cod_dis),
  CONSTRAINT uq_dispositivo_nombre UNIQUE (nombre_dis),
  CONSTRAINT ck_dispositivo_tipo CHECK (tipo_dis IN ('SIMULADO', 'FISICO'))
);

CREATE TABLE LUGAR (
  cod_lug     dom_codigo,
  nombre_lug  dom_nombre,
  tipo_lug    dom_tipo,
  volumen_lug dom_volumen,
  ciudad_lug  dom_nombre CONSTRAINT df_lugar_ciudad DEFAULT 'Francisco de Orellana',
  CONSTRAINT pk_lugar PRIMARY KEY (cod_lug),
  CONSTRAINT uq_lugar_nombre UNIQUE (nombre_lug),
  CONSTRAINT ck_lugar_tipo CHECK (tipo_lug IN ('VIRTUAL', 'MAQUETA', 'LOCAL', 'AULA')),
  CONSTRAINT ck_lugar_volumen CHECK (volumen_lug IS NULL OR volumen_lug > 0)
);

CREATE TABLE SESION (
  cod_ses         dom_codigo,
  fecha_ini_ses   dom_fecha CONSTRAINT df_sesion_fecha_ini DEFAULT GETDATE(),
  fecha_fin_ses   dom_fecha_opcional,
  observacion_ses dom_texto_opcional,
  cod_dis         dom_codigo,
  cod_lug         dom_codigo,
  CONSTRAINT pk_sesion PRIMARY KEY (cod_ses),
  CONSTRAINT fk_sesion_dispositivo FOREIGN KEY (cod_dis) REFERENCES DISPOSITIVO (cod_dis)
    ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT fk_sesion_lugar FOREIGN KEY (cod_lug) REFERENCES LUGAR (cod_lug)
    ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT ck_sesion_fechas CHECK (fecha_fin_ses IS NULL OR fecha_fin_ses >= fecha_ini_ses)
);

CREATE TABLE LECTURA (
  cod_lec         INT IDENTITY(1,1) NOT NULL,   -- autonumerico (IDENTITY va sobre INT directo)
  fecha_hora_lec  dom_fecha CONSTRAINT df_lectura_fecha_hora DEFAULT GETDATE(),
  temperatura_lec dom_medida_opcional,
  humedad_lec     dom_medida_opcional,
  co2_lec         dom_medida_entera,
  ruido_lec       dom_medida_entera,
  ventilador_lec  dom_estado CONSTRAINT df_lectura_ventilador DEFAULT 0,
  cod_ses         dom_codigo,
  CONSTRAINT pk_lectura PRIMARY KEY (cod_lec),
  CONSTRAINT fk_lectura_sesion FOREIGN KEY (cod_ses) REFERENCES SESION (cod_ses)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_lectura_temperatura CHECK (temperatura_lec IS NULL OR temperatura_lec BETWEEN -40 AND 80),
  CONSTRAINT ck_lectura_humedad CHECK (humedad_lec IS NULL OR humedad_lec BETWEEN 0 AND 100),
  CONSTRAINT ck_lectura_co2 CHECK (co2_lec BETWEEN 0 AND 10000),
  CONSTRAINT ck_lectura_ruido CHECK (ruido_lec BETWEEN 0 AND 150)
);

CREATE TABLE TIPO_ALERTA (
  cod_tal       dom_codigo,
  nombre_tal    dom_nombre,
  variable_tal  dom_tipo,
  condicion_tal dom_condicion,
  umbral_tal    dom_umbral,
  CONSTRAINT pk_tipo_alerta PRIMARY KEY (cod_tal),
  CONSTRAINT uq_tipo_alerta_nombre UNIQUE (nombre_tal),
  CONSTRAINT ck_tipo_alerta_variable CHECK (variable_tal IN ('CO2', 'TEMPERATURA', 'HUMEDAD', 'RUIDO')),
  CONSTRAINT ck_tipo_alerta_condicion CHECK (condicion_tal IN ('>=', '<=', '>', '<', '='))
);

CREATE TABLE ALERTA (
  cod_lec dom_codigo,
  cod_tal dom_codigo,
  CONSTRAINT pk_alerta PRIMARY KEY (cod_lec, cod_tal),
  CONSTRAINT fk_alerta_lectura FOREIGN KEY (cod_lec) REFERENCES LECTURA (cod_lec)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_alerta_tipo_alerta FOREIGN KEY (cod_tal) REFERENCES TIPO_ALERTA (cod_tal)
    ON DELETE NO ACTION ON UPDATE CASCADE
);
GO

-- 4. METADATOS (descripcion de cada tabla y columna, visible en SSMS > Propiedades)
EXEC sp_addextendedproperty 'MS_Description', N'Aparato que mide: ESP32 simulado en Wokwi o ESP32 fisico de la maqueta', 'SCHEMA', 'dbo', 'TABLE', 'DISPOSITIVO';
EXEC sp_addextendedproperty 'MS_Description', N'Codigo del dispositivo (PK)', 'SCHEMA', 'dbo', 'TABLE', 'DISPOSITIVO', 'COLUMN', 'cod_dis';
EXEC sp_addextendedproperty 'MS_Description', N'Nombre del dispositivo', 'SCHEMA', 'dbo', 'TABLE', 'DISPOSITIVO', 'COLUMN', 'nombre_dis';
EXEC sp_addextendedproperty 'MS_Description', N'Modelo de la placa', 'SCHEMA', 'dbo', 'TABLE', 'DISPOSITIVO', 'COLUMN', 'placa_dis';
EXEC sp_addextendedproperty 'MS_Description', N'SIMULADO o FISICO', 'SCHEMA', 'dbo', 'TABLE', 'DISPOSITIVO', 'COLUMN', 'tipo_dis';
EXEC sp_addextendedproperty 'MS_Description', N'Espacio cerrado donde se mide: simulacion, maqueta, local o aula', 'SCHEMA', 'dbo', 'TABLE', 'LUGAR';
EXEC sp_addextendedproperty 'MS_Description', N'Codigo del lugar (PK)', 'SCHEMA', 'dbo', 'TABLE', 'LUGAR', 'COLUMN', 'cod_lug';
EXEC sp_addextendedproperty 'MS_Description', N'Nombre del lugar', 'SCHEMA', 'dbo', 'TABLE', 'LUGAR', 'COLUMN', 'nombre_lug';
EXEC sp_addextendedproperty 'MS_Description', N'VIRTUAL, MAQUETA, LOCAL o AULA', 'SCHEMA', 'dbo', 'TABLE', 'LUGAR', 'COLUMN', 'tipo_lug';
EXEC sp_addextendedproperty 'MS_Description', N'Volumen en m3 (opcional)', 'SCHEMA', 'dbo', 'TABLE', 'LUGAR', 'COLUMN', 'volumen_lug';
EXEC sp_addextendedproperty 'MS_Description', N'Ciudad donde esta el lugar', 'SCHEMA', 'dbo', 'TABLE', 'LUGAR', 'COLUMN', 'ciudad_lug';
EXEC sp_addextendedproperty 'MS_Description', N'Periodo continuo de medicion con un dispositivo en un lugar', 'SCHEMA', 'dbo', 'TABLE', 'SESION';
EXEC sp_addextendedproperty 'MS_Description', N'Codigo de la sesion (PK)', 'SCHEMA', 'dbo', 'TABLE', 'SESION', 'COLUMN', 'cod_ses';
EXEC sp_addextendedproperty 'MS_Description', N'Fecha y hora de inicio', 'SCHEMA', 'dbo', 'TABLE', 'SESION', 'COLUMN', 'fecha_ini_ses';
EXEC sp_addextendedproperty 'MS_Description', N'Fecha y hora de fin (vacia si sigue abierta)', 'SCHEMA', 'dbo', 'TABLE', 'SESION', 'COLUMN', 'fecha_fin_ses';
EXEC sp_addextendedproperty 'MS_Description', N'Observacion de la sesion', 'SCHEMA', 'dbo', 'TABLE', 'SESION', 'COLUMN', 'observacion_ses';
EXEC sp_addextendedproperty 'MS_Description', N'Dispositivo usado (FK)', 'SCHEMA', 'dbo', 'TABLE', 'SESION', 'COLUMN', 'cod_dis';
EXEC sp_addextendedproperty 'MS_Description', N'Lugar de la medicion (FK)', 'SCHEMA', 'dbo', 'TABLE', 'SESION', 'COLUMN', 'cod_lug';
EXEC sp_addextendedproperty 'MS_Description', N'Cada linea que envia el ESP32 por USB cada 4 s, con fecha y hora', 'SCHEMA', 'dbo', 'TABLE', 'LECTURA';
EXEC sp_addextendedproperty 'MS_Description', N'Codigo de la lectura, autonumerico (PK)', 'SCHEMA', 'dbo', 'TABLE', 'LECTURA', 'COLUMN', 'cod_lec';
EXEC sp_addextendedproperty 'MS_Description', N'Fecha y hora en que llego la lectura', 'SCHEMA', 'dbo', 'TABLE', 'LECTURA', 'COLUMN', 'fecha_hora_lec';
EXEC sp_addextendedproperty 'MS_Description', N'Temperatura en grados C (vacia si falla el DHT22)', 'SCHEMA', 'dbo', 'TABLE', 'LECTURA', 'COLUMN', 'temperatura_lec';
EXEC sp_addextendedproperty 'MS_Description', N'Humedad relativa en % (vacia si falla el DHT22)', 'SCHEMA', 'dbo', 'TABLE', 'LECTURA', 'COLUMN', 'humedad_lec';
EXEC sp_addextendedproperty 'MS_Description', N'CO2 estimado en ppm (MQ-135)', 'SCHEMA', 'dbo', 'TABLE', 'LECTURA', 'COLUMN', 'co2_lec';
EXEC sp_addextendedproperty 'MS_Description', N'Ruido estimado en dB (MAX4466)', 'SCHEMA', 'dbo', 'TABLE', 'LECTURA', 'COLUMN', 'ruido_lec';
EXEC sp_addextendedproperty 'MS_Description', N'Extractor: 1 encendido, 0 apagado', 'SCHEMA', 'dbo', 'TABLE', 'LECTURA', 'COLUMN', 'ventilador_lec';
EXEC sp_addextendedproperty 'MS_Description', N'Sesion a la que pertenece (FK)', 'SCHEMA', 'dbo', 'TABLE', 'LECTURA', 'COLUMN', 'cod_ses';
EXEC sp_addextendedproperty 'MS_Description', N'Catalogo de alertas con su variable, condicion y umbral', 'SCHEMA', 'dbo', 'TABLE', 'TIPO_ALERTA';
EXEC sp_addextendedproperty 'MS_Description', N'Codigo del tipo de alerta (PK)', 'SCHEMA', 'dbo', 'TABLE', 'TIPO_ALERTA', 'COLUMN', 'cod_tal';
EXEC sp_addextendedproperty 'MS_Description', N'Nombre de la alerta', 'SCHEMA', 'dbo', 'TABLE', 'TIPO_ALERTA', 'COLUMN', 'nombre_tal';
EXEC sp_addextendedproperty 'MS_Description', N'Variable que vigila', 'SCHEMA', 'dbo', 'TABLE', 'TIPO_ALERTA', 'COLUMN', 'variable_tal';
EXEC sp_addextendedproperty 'MS_Description', N'Comparacion con el umbral', 'SCHEMA', 'dbo', 'TABLE', 'TIPO_ALERTA', 'COLUMN', 'condicion_tal';
EXEC sp_addextendedproperty 'MS_Description', N'Valor limite de la alerta', 'SCHEMA', 'dbo', 'TABLE', 'TIPO_ALERTA', 'COLUMN', 'umbral_tal';
EXEC sp_addextendedproperty 'MS_Description', N'Alertas que genero cada lectura (relacion N:N entre LECTURA y TIPO_ALERTA)', 'SCHEMA', 'dbo', 'TABLE', 'ALERTA';
EXEC sp_addextendedproperty 'MS_Description', N'Lectura que genero la alerta (PK, FK)', 'SCHEMA', 'dbo', 'TABLE', 'ALERTA', 'COLUMN', 'cod_lec';
EXEC sp_addextendedproperty 'MS_Description', N'Tipo de alerta generada (PK, FK)', 'SCHEMA', 'dbo', 'TABLE', 'ALERTA', 'COLUMN', 'cod_tal';
GO

-- 5. SEGURIDAD: roles, inicios de sesion y usuarios
CREATE ROLE rol_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_admin;
CREATE ROLE rol_app;
GRANT SELECT, INSERT ON SCHEMA::dbo TO rol_app;   -- la app Java solo guarda y consulta

-- Requiere autenticacion mixta (SQL Server y Windows). Cambiar las claves antes de usar.
CREATE LOGIN login_admin_aire WITH PASSWORD = 'Aire.Admin#2026', CHECK_POLICY = ON;
CREATE LOGIN login_app_aire WITH PASSWORD = 'Aire.App#2026', CHECK_POLICY = ON;
CREATE USER usr_admin_aire FOR LOGIN login_admin_aire;
CREATE USER usr_app_aire FOR LOGIN login_app_aire;
ALTER ROLE rol_admin ADD MEMBER usr_admin_aire;
ALTER ROLE rol_app ADD MEMBER usr_app_aire;
GO

-- 6. DATOS (lecturas reales de las pruebas en Wokwi del 22 de octubre de 2026)
INSERT INTO DISPOSITIVO (cod_dis, nombre_dis, placa_dis, tipo_dis) VALUES
  (1, 'Monitor simulado', 'ESP32 DevKitC V4 (Wokwi)', 'SIMULADO'),
  (2, 'Monitor de la maqueta', 'ESP32 DevKitC V4', 'FISICO');
INSERT INTO LUGAR (cod_lug, nombre_lug, tipo_lug, volumen_lug, ciudad_lug) VALUES
  (1, 'Simulacion Wokwi', 'VIRTUAL', NULL, 'Francisco de Orellana'),
  (2, 'Maqueta del aula', 'MAQUETA', 0.030, 'Francisco de Orellana'),
  (3, 'Local comercial', 'LOCAL', NULL, 'Francisco de Orellana');
INSERT INTO TIPO_ALERTA (cod_tal, nombre_tal, variable_tal, condicion_tal, umbral_tal) VALUES
  (1, 'VENTILAR', 'CO2', '>=', 800),
  (2, 'CO2 ALTO', 'CO2', '>=', 1200),
  (3, 'CALOR', 'TEMPERATURA', '>=', 30),
  (4, 'FRIO', 'TEMPERATURA', '<', 20),
  (5, 'RUIDO ALTO', 'RUIDO', '>=', 70),
  (6, 'ERROR DHT22', 'TEMPERATURA', '=', -999);
INSERT INTO SESION (cod_ses, fecha_ini_ses, fecha_fin_ses, observacion_ses, cod_dis, cod_lug) VALUES
  (1, '2026-10-22 23:34:13', '2026-10-22 23:41:37', 'Pruebas P03 a P13 de la simulacion', 1, 1),
  (2, '2026-10-22 23:42:08', '2026-10-22 23:42:38', 'Prueba P12: falla del DHT22', 1, 1);
SET IDENTITY_INSERT LECTURA ON;
INSERT INTO LECTURA (cod_lec, fecha_hora_lec, temperatura_lec, humedad_lec, co2_lec, ruido_lec, ventilador_lec, cod_ses) VALUES
  (1, '2026-10-22 23:34:13', 16.10, 30.00, 1751, 30, 1, 1),
  (2, '2026-10-22 23:34:17', 16.10, 30.00, 1751, 30, 1, 1),
  (3, '2026-10-22 23:34:21', 16.10, 30.00, 1751, 30, 1, 1),
  (4, '2026-10-22 23:34:26', 16.10, 30.00, 1751, 30, 1, 1),
  (5, '2026-10-22 23:34:30', 16.10, 30.00, 1751, 30, 1, 1),
  (6, '2026-10-22 23:34:34', 16.10, 30.00, 1751, 30, 1, 1),
  (7, '2026-10-22 23:34:39', 16.10, 30.00, 1751, 30, 1, 1),
  (8, '2026-10-22 23:34:43', 16.10, 30.00, 1751, 30, 1, 1),
  (9, '2026-10-22 23:34:47', 16.10, 30.00, 1831, 30, 1, 1),
  (10, '2026-10-22 23:34:52', 16.10, 30.00, 1831, 30, 1, 1),
  (11, '2026-10-22 23:34:56', 16.10, 30.00, 1831, 30, 1, 1),
  (12, '2026-10-22 23:35:01', 16.10, 30.00, 1831, 30, 1, 1),
  (13, '2026-10-22 23:35:05', 16.10, 30.00, 1575, 30, 1, 1),
  (14, '2026-10-22 23:35:09', 16.10, 30.00, 1575, 30, 1, 1),
  (15, '2026-10-22 23:35:14', 16.10, 30.00, 1122, 30, 1, 1),
  (16, '2026-10-22 23:35:18', 16.10, 30.00, 1122, 30, 1, 1),
  (17, '2026-10-22 23:35:22', 16.10, 30.00, 551, 30, 0, 1),
  (18, '2026-10-22 23:35:27', 16.10, 30.00, 551, 30, 0, 1),
  (19, '2026-10-22 23:35:31', 16.10, 30.00, 551, 30, 0, 1),
  (20, '2026-10-22 23:35:35', 16.10, 30.00, 551, 30, 0, 1),
  (21, '2026-10-22 23:35:40', 16.10, 30.00, 551, 30, 0, 1),
  (22, '2026-10-22 23:35:44', 16.10, 30.00, 551, 30, 0, 1),
  (23, '2026-10-22 23:35:48', 16.10, 30.00, 551, 30, 0, 1),
  (24, '2026-10-22 23:35:53', 16.10, 30.00, 551, 30, 0, 1),
  (25, '2026-10-22 23:35:57', 24.00, 40.00, 400, 30, 0, 1),
  (26, '2026-10-22 23:36:02', 24.00, 40.00, 400, 30, 0, 1),
  (27, '2026-10-22 23:36:06', 24.00, 40.00, 400, 30, 0, 1),
  (28, '2026-10-22 23:36:10', 24.00, 40.00, 400, 30, 0, 1),
  (29, '2026-10-22 23:36:15', 24.00, 40.00, 400, 30, 0, 1),
  (30, '2026-10-22 23:36:19', 24.00, 40.00, 400, 30, 0, 1),
  (31, '2026-10-22 23:36:23', 24.00, 40.00, 400, 30, 0, 1),
  (32, '2026-10-22 23:36:28', 24.00, 40.00, 400, 30, 0, 1),
  (33, '2026-10-22 23:36:32', 24.00, 40.00, 400, 30, 0, 1),
  (34, '2026-10-22 23:36:36', 24.00, 40.00, 400, 30, 0, 1),
  (35, '2026-10-22 23:36:41', 24.00, 40.00, 400, 30, 0, 1),
  (36, '2026-10-22 23:36:45', 24.00, 40.00, 400, 30, 0, 1),
  (37, '2026-10-22 23:36:50', 24.00, 40.00, 400, 30, 0, 1),
  (38, '2026-10-22 23:36:54', 24.00, 40.00, 400, 100, 0, 1),
  (39, '2026-10-22 23:36:58', 24.00, 40.00, 400, 100, 0, 1),
  (40, '2026-10-22 23:37:03', 24.00, 40.00, 400, 100, 0, 1),
  (41, '2026-10-22 23:37:07', 24.00, 40.00, 400, 100, 0, 1),
  (42, '2026-10-22 23:37:11', 24.00, 40.00, 839, 30, 0, 1),
  (43, '2026-10-22 23:37:16', 24.00, 40.00, 839, 30, 0, 1),
  (44, '2026-10-22 23:37:20', 24.00, 40.00, 839, 30, 0, 1),
  (45, '2026-10-22 23:37:24', 24.00, 40.00, 839, 30, 0, 1),
  (46, '2026-10-22 23:37:29', 24.00, 40.00, 1326, 30, 1, 1),
  (47, '2026-10-22 23:37:33', 24.00, 40.00, 1326, 30, 1, 1),
  (48, '2026-10-22 23:37:37', 24.00, 40.00, 1326, 30, 1, 1),
  (49, '2026-10-22 23:37:42', 24.00, 40.00, 1326, 30, 1, 1),
  (50, '2026-10-22 23:37:46', 24.00, 40.00, 1122, 30, 1, 1);
INSERT INTO LECTURA (cod_lec, fecha_hora_lec, temperatura_lec, humedad_lec, co2_lec, ruido_lec, ventilador_lec, cod_ses) VALUES
  (51, '2026-10-22 23:37:51', 24.00, 40.00, 1122, 30, 1, 1),
  (52, '2026-10-22 23:37:55', 24.00, 40.00, 551, 30, 0, 1),
  (53, '2026-10-22 23:37:59', 24.00, 40.00, 551, 30, 0, 1),
  (54, '2026-10-22 23:38:04', 24.00, 40.00, 551, 30, 0, 1),
  (55, '2026-10-22 23:38:08', 24.00, 40.00, 551, 30, 0, 1),
  (56, '2026-10-22 23:38:12', 24.00, 40.00, 551, 30, 0, 1),
  (57, '2026-10-22 23:38:17', 24.00, 40.00, 839, 30, 0, 1),
  (58, '2026-10-22 23:38:21', 24.00, 40.00, 839, 30, 0, 1),
  (59, '2026-10-22 23:38:25', 24.00, 40.00, 839, 30, 0, 1),
  (60, '2026-10-22 23:38:30', 31.00, 40.00, 400, 30, 1, 1),
  (61, '2026-10-22 23:38:34', 31.00, 40.00, 400, 30, 1, 1),
  (62, '2026-10-22 23:38:39', 31.00, 40.00, 400, 30, 1, 1),
  (63, '2026-10-22 23:38:43', 31.00, 40.00, 400, 30, 1, 1),
  (64, '2026-10-22 23:38:47', 31.00, 40.00, 400, 30, 1, 1),
  (65, '2026-10-22 23:38:52', 27.00, 40.00, 400, 30, 1, 1),
  (66, '2026-10-22 23:38:56', 27.00, 40.00, 400, 30, 1, 1),
  (67, '2026-10-22 23:39:00', 25.00, 40.00, 400, 30, 0, 1),
  (68, '2026-10-22 23:39:05', 25.00, 40.00, 400, 30, 0, 1),
  (69, '2026-10-22 23:39:09', 25.00, 40.00, 400, 30, 0, 1),
  (70, '2026-10-22 23:39:13', 18.00, 40.00, 400, 30, 0, 1),
  (71, '2026-10-22 23:39:18', 18.00, 40.00, 400, 30, 0, 1),
  (72, '2026-10-22 23:39:22', 18.00, 40.00, 400, 30, 0, 1),
  (73, '2026-10-22 23:39:26', 18.00, 40.00, 400, 30, 0, 1),
  (74, '2026-10-22 23:39:31', 24.00, 40.00, 400, 30, 0, 1),
  (75, '2026-10-22 23:39:35', 24.00, 40.00, 400, 30, 0, 1),
  (76, '2026-10-22 23:39:40', 24.00, 40.00, 400, 90, 0, 1),
  (77, '2026-10-22 23:39:44', 24.00, 40.00, 400, 90, 0, 1),
  (78, '2026-10-22 23:39:48', 24.00, 40.00, 400, 90, 0, 1),
  (79, '2026-10-22 23:39:53', 24.00, 40.00, 400, 90, 0, 1),
  (80, '2026-10-22 23:39:57', 24.00, 40.00, 1326, 90, 1, 1),
  (81, '2026-10-22 23:40:01', 24.00, 40.00, 1326, 90, 1, 1),
  (82, '2026-10-22 23:40:06', 24.00, 40.00, 1326, 90, 1, 1),
  (83, '2026-10-22 23:40:10', 24.00, 40.00, 1326, 90, 1, 1),
  (84, '2026-10-22 23:40:14', 24.00, 40.00, 400, 30, 0, 1),
  (85, '2026-10-22 23:40:19', 24.00, 40.00, 400, 30, 0, 1),
  (86, '2026-10-22 23:40:23', 24.00, 40.00, 400, 30, 0, 1),
  (87, '2026-10-22 23:40:28', 24.00, 40.00, 400, 30, 0, 1),
  (88, '2026-10-22 23:40:32', 24.00, 40.00, 400, 30, 0, 1),
  (89, '2026-10-22 23:40:36', 24.00, 40.00, 400, 30, 0, 1),
  (90, '2026-10-22 23:40:41', 24.00, 40.00, 400, 30, 0, 1),
  (91, '2026-10-22 23:40:45', 24.00, 40.00, 400, 30, 0, 1),
  (92, '2026-10-22 23:40:49', 24.00, 40.00, 400, 30, 0, 1),
  (93, '2026-10-22 23:40:54', 24.00, 40.00, 400, 30, 0, 1),
  (94, '2026-10-22 23:40:58', 24.00, 40.00, 400, 30, 0, 1),
  (95, '2026-10-22 23:41:02', 24.00, 40.00, 400, 30, 0, 1),
  (96, '2026-10-22 23:41:07', 24.00, 40.00, 400, 30, 0, 1),
  (97, '2026-10-22 23:41:11', 24.00, 40.00, 400, 30, 0, 1),
  (98, '2026-10-22 23:41:15', 24.00, 40.00, 400, 30, 0, 1),
  (99, '2026-10-22 23:41:20', 24.00, 40.00, 400, 30, 0, 1),
  (100, '2026-10-22 23:41:24', 24.00, 40.00, 400, 30, 0, 1);
INSERT INTO LECTURA (cod_lec, fecha_hora_lec, temperatura_lec, humedad_lec, co2_lec, ruido_lec, ventilador_lec, cod_ses) VALUES
  (101, '2026-10-22 23:41:29', 24.00, 40.00, 400, 30, 0, 1),
  (102, '2026-10-22 23:41:33', 24.00, 40.00, 400, 30, 0, 1),
  (103, '2026-10-22 23:41:37', 24.00, 40.00, 400, 30, 0, 1),
  (104, '2026-10-22 23:42:08', NULL, NULL, 1751, 30, 1, 2),
  (105, '2026-10-22 23:42:12', NULL, NULL, 1751, 30, 1, 2),
  (106, '2026-10-22 23:42:16', NULL, NULL, 1751, 30, 1, 2),
  (107, '2026-10-22 23:42:21', NULL, NULL, 1751, 30, 1, 2),
  (108, '2026-10-22 23:42:25', NULL, NULL, 1751, 30, 1, 2),
  (109, '2026-10-22 23:42:29', NULL, NULL, 400, 30, 0, 2),
  (110, '2026-10-22 23:42:34', NULL, NULL, 400, 30, 0, 2),
  (111, '2026-10-22 23:42:38', NULL, NULL, 400, 30, 0, 2);
SET IDENTITY_INSERT LECTURA OFF;
INSERT INTO ALERTA (cod_lec, cod_tal) VALUES
  (1, 4),
  (1, 2),
  (2, 4),
  (2, 2),
  (3, 4),
  (3, 2),
  (4, 4),
  (4, 2),
  (5, 4),
  (5, 2),
  (6, 4),
  (6, 2),
  (7, 4),
  (7, 2),
  (8, 4),
  (8, 2),
  (9, 4),
  (9, 2),
  (10, 4),
  (10, 2),
  (11, 4),
  (11, 2),
  (12, 4),
  (12, 2),
  (13, 4),
  (13, 2),
  (14, 4),
  (14, 2),
  (15, 4),
  (15, 1),
  (16, 4),
  (16, 1),
  (17, 4),
  (18, 4),
  (19, 4),
  (20, 4),
  (21, 4),
  (22, 4),
  (23, 4),
  (24, 4),
  (40, 5),
  (41, 5),
  (42, 1),
  (43, 1),
  (44, 1),
  (45, 1),
  (46, 2),
  (47, 2),
  (48, 2),
  (49, 2);
INSERT INTO ALERTA (cod_lec, cod_tal) VALUES
  (50, 1),
  (51, 1),
  (57, 1),
  (58, 1),
  (59, 1),
  (60, 3),
  (61, 3),
  (62, 3),
  (63, 3),
  (64, 3),
  (70, 4),
  (71, 4),
  (72, 4),
  (73, 4),
  (78, 5),
  (79, 5),
  (80, 2),
  (80, 5),
  (81, 2),
  (81, 5),
  (82, 2),
  (82, 5),
  (83, 2),
  (83, 5),
  (104, 6),
  (104, 2),
  (105, 6),
  (105, 2),
  (106, 6),
  (106, 2),
  (107, 6),
  (107, 2),
  (108, 6),
  (108, 2),
  (109, 6),
  (110, 6),
  (111, 6);
GO

-- 7. COMPROBACION
SELECT 'DISPOSITIVO' AS tabla, COUNT(*) AS filas FROM DISPOSITIVO UNION ALL
SELECT 'LUGAR', COUNT(*) FROM LUGAR UNION ALL
SELECT 'SESION', COUNT(*) FROM SESION UNION ALL
SELECT 'LECTURA', COUNT(*) FROM LECTURA UNION ALL
SELECT 'TIPO_ALERTA', COUNT(*) FROM TIPO_ALERTA UNION ALL
SELECT 'ALERTA', COUNT(*) FROM ALERTA;
GO
