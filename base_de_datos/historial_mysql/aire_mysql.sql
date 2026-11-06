-- Base de datos del sistema de monitoreo de calidad del aire (MySQL 8)
-- Respaldo del modelo fisico. En el medio ciclo las tablas se crean con MySQL Workbench.
CREATE DATABASE IF NOT EXISTS aire_db;
USE aire_db;

CREATE TABLE dispositivo (
  cod_dis     INT          NOT NULL,
  nombre_dis  VARCHAR(40)  NOT NULL,
  placa_dis   VARCHAR(40)  NOT NULL,
  tipo_dis    VARCHAR(10)  NOT NULL,
  PRIMARY KEY (cod_dis),
  CHECK (tipo_dis IN ('SIMULADO', 'FISICO'))
);

CREATE TABLE lugar (
  cod_lug     INT          NOT NULL,
  nombre_lug  VARCHAR(50)  NOT NULL,
  tipo_lug    VARCHAR(20)  NOT NULL,
  volumen_lug DECIMAL(8,3) NULL,
  ciudad_lug  VARCHAR(30)  NOT NULL,
  PRIMARY KEY (cod_lug),
  CHECK (volumen_lug IS NULL OR volumen_lug > 0)
);

CREATE TABLE sesion (
  cod_ses         INT          NOT NULL,
  fecha_ini_ses   DATETIME     NOT NULL,
  fecha_fin_ses   DATETIME     NULL,
  observacion_ses VARCHAR(100) NULL,
  cod_dis         INT          NOT NULL,
  cod_lug         INT          NOT NULL,
  PRIMARY KEY (cod_ses),
  FOREIGN KEY (cod_dis) REFERENCES dispositivo (cod_dis) ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (cod_lug) REFERENCES lugar (cod_lug) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE lectura (
  cod_lec         INT          NOT NULL AUTO_INCREMENT,
  fecha_hora_lec  DATETIME     NOT NULL,
  temperatura_lec DECIMAL(5,2) NULL,
  humedad_lec     DECIMAL(5,2) NULL,
  co2_lec         INT          NOT NULL,
  ruido_lec       INT          NOT NULL,
  ventilador_lec  INT          NOT NULL,
  cod_ses         INT          NOT NULL,
  PRIMARY KEY (cod_lec),
  FOREIGN KEY (cod_ses) REFERENCES sesion (cod_ses) ON DELETE CASCADE ON UPDATE CASCADE,
  CHECK (humedad_lec IS NULL OR (humedad_lec >= 0 AND humedad_lec <= 100)),
  CHECK (co2_lec >= 0),
  CHECK (ruido_lec >= 0),
  CHECK (ventilador_lec IN (0, 1))
);

CREATE TABLE tipo_alerta (
  cod_tal       INT          NOT NULL,
  nombre_tal    VARCHAR(20)  NOT NULL,
  variable_tal  VARCHAR(15)  NOT NULL,
  condicion_tal VARCHAR(2)   NOT NULL,
  umbral_tal    DECIMAL(7,2) NOT NULL,
  PRIMARY KEY (cod_tal),
  UNIQUE (nombre_tal)
);

CREATE TABLE alerta (
  cod_lec INT NOT NULL,
  cod_tal INT NOT NULL,
  PRIMARY KEY (cod_lec, cod_tal),
  FOREIGN KEY (cod_lec) REFERENCES lectura (cod_lec) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (cod_tal) REFERENCES tipo_alerta (cod_tal) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Usuarios: administrador y usuario de la aplicacion (solo inserta y consulta)
CREATE USER 'admin_aire'@'localhost' IDENTIFIED BY 'cambiar_clave_admin';
GRANT ALL PRIVILEGES ON aire_db.* TO 'admin_aire'@'localhost';
CREATE USER 'app_aire'@'localhost' IDENTIFIED BY 'cambiar_clave_app';
GRANT SELECT, INSERT ON aire_db.* TO 'app_aire'@'localhost';
