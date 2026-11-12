# Sistema de monitoreo de calidad del aire basado en sensores

Proyecto integrador PAO 3 · Carrera de Tecnologías de la Información · ESPOCH Sede Orellana
Tutor (guía): Ing. Santiago Logroño · Periodo septiembre 2026 – febrero 2027 · Defensa final: enero de 2027

Aparato de bajo costo con un **ESP32** que mide **CO2 estimado, temperatura, humedad y ruido** en espacios cerrados (aulas, oficinas, locales), avisa con una pantalla LCD 20x4, LEDs y un buzzer, y **enciende un extractor por sí solo**. Las lecturas pasan por **cable USB** a una computadora y se guardan en **SQL Server 2022** (camino oficial). Como agregado del medio ciclo, la simulación también envía los datos por **WiFi a ThingSpeak**. Con los datos se plantean modelos de **Ecuaciones Diferenciales** y **Cálculo de Varias Variables**. Para las pruebas se usa una maqueta con el aspecto de un aula (banco de pruebas).

> **Estado (medio ciclo, 10 de noviembre de 2026):** diseño completo; simulación en Wokwi **versión 4** (protoboard) funcionando, **13 de 13 pruebas aprobadas**; envío a ThingSpeak funcionando; base de datos implementada en SQL Server con 111 lecturas de la simulación y pruebas de integridad. El aparato real, la maqueta y la aplicación Java se construyen en el segundo ciclo.

## Equipo

| Integrante | Rol |
|---|---|
| Alan Paucar | Líder del proyecto · Ecuaciones Diferenciales · Cálculo de Varias Variables |
| Lenin Manobanda | Simulación y pruebas · Diseño de la aplicación |
| Andrea Quiroga | Hardware · Base de datos |
| Daniela Valladolid | Gestión del proyecto · Contexto social |

## Simulación (Wokwi, versión 4)

Proyecto en Wokwi: https://wokwi.com/projects/479818931364503553

1. Abrir el enlace y presionar **Play**. Esperar la conexión WiFi (`# WiFi connected` en el monitor serial) y los 20 s de precalentamiento.
2. La simulación arranca con el gas alto: lo primero es **bajar la barra del sensor de gas** al mínimo.
3. Cambiar la barra del gas, la temperatura del DHT22 y el potenciómetro de ruido para ver las reglas.

El circuito está en una protoboard con rieles de **3,3 V**, **5 V** (con interruptor) y **GND**. En Wokwi:

| Aparato real | En Wokwi |
|---|---|
| MQ-135 a 5 V con divisor 10 kΩ / 10 kΩ | Sensor de gas MQ-2 con barra, directo a 3,3 V (con el divisor la simulación corre al 1–3 %) |
| Micrófono MAX4466 | Potenciómetro deslizante (30 a 100 dB) |
| Extractor de 5 V | Relé + LED morado |

En el código, `SIMULACION = true` para Wokwi y `false` para el aparato real (en el real, la lectura del gas se multiplica por 2 para compensar el divisor).

## Código del ESP32 (`firmware_v4/sketch.ino`)

Ordenado en **14 bloques numerados** (buscar `BLOQUE n` con Ctrl+F). Títulos en español e inglés, comentarios en inglés.

| Bloque | Contenido | Bloque | Contenido |
|---|---|---|---|
| 1 | Librerías | 8 | LEDs y buzzer |
| 2 | Modo: simulación o aparato real | 9 | Extractor (relé) con histéresis |
| 3 | Pines | 10 | Pantalla LCD 20x4 |
| 4 | Umbrales (todos los límites) | 11 | Salida USB (línea serial) |
| 5 | WiFi y ThingSpeak | 12 | Envío a ThingSpeak |
| 6 | Variables de estado | 13 | `setup()`: autoprueba, WiFi, precalentamiento |
| 7 | Sensores | 14 | `loop()`: ciclo cada 4 s |

La **Write API Key** de ThingSpeak no está en el repositorio: en el bloque 5 reemplazar `PEGAR_WRITE_API_KEY` por la clave del canal.

## Reglas del aparato

| Condición | LED | Mensaje | Buzzer | Extractor |
|---|---|---|---|---|
| CO2 < 800 ppm | Verde | AIRE Normal | No | — |
| CO2 800–1199 ppm | Amarillo | VENTILAR | No | — |
| CO2 ≥ 1200 ppm | Rojo | CO2 ALTO | Cada ~4 s | Prende |
| T ≥ 30 °C | Naranja | CALOR | No | Prende |
| T < 20 °C | Azul | FRIO | No | — |
| Ruido ≥ 70 dB, 3 lecturas seguidas | Blanco | RUIDO ALTO | Nunca | No |
| Falla del DHT22 | — | ERROR DHT22 | No | Decide por CO2 |

**Histéresis:** el extractor se enciende con CO2 ≥ 1200 ppm o T ≥ 30 °C y se apaga solo con CO2 < 1000 ppm **y** T ≤ 25 °C.

**Línea serial (USB, 115200, camino oficial):** `temperatura,humedad,ppmCO2,ruidoDB,ventilador` · ejemplo `24.00,40.00,1373,30,1` · si falla el DHT22 se envía `-999`. Las líneas que empiezan con `#` son de estado (WiFi, ThingSpeak) y la aplicación las ignora.

## ThingSpeak (agregado del medio ciclo)

Canal **Calidad del aire ESPOCH** (Channel ID 3566904). Una entrada cada 5 ciclos (~20 s), porque la cuenta gratuita acepta una cada 15 s. Campos: 1 temperatura · 2 humedad · 3 CO2 · 4 ruido · 5 extractor. Si falla el DHT22, los campos 1 y 2 no se envían. No reemplaza al cable USB; en el aparato real es opcional.

## Estructura del repositorio

| Carpeta | Contenido |
|---|---|
| `firmware_v4/` | **Versión vigente:** `sketch.ino` (por bloques) y `diagram.json` (circuito en protoboard) |
| `firmware_v3_anterior/` | Versión anterior (22 de octubre), solo como historial |
| `pruebas_wokwi/` | CSV con las 111 lecturas de la primera ronda, `capturas_v4/` (5 de noviembre) y `capturas_v3_22oct/` |
| `base_de_datos/` | `aire_sqlserver.sql`, `aire_pruebas.sql`, modelo E-R, modelo físico de SSMS, capturas de SQL Server y los CSV. `historial_mysql/` guarda el diseño anterior en MySQL |
| `matlab/` | `ED_modelos.m`, `VV_funciones.m`, `figuras_EN.m`, salida de MATLAB y figuras |
| `diagramas/` | Circuito v4, diagrama de bloques, esquema de conexiones v3 (aparato real), diagrama de procesos, UML y wireframes |
| `presentacion/` | Presentación del medio ciclo (HTML, con réplica sin internet) y maqueta 3D |
| `documentos/` | Informe de avance, diseño de la base de datos, piezas de cada materia, protocolo de pruebas, guion y ficha de la demo |

## Base de datos (SQL Server 2022 Express + SSMS)

Base `aire_db` con 6 tablas en tercera forma normal: `DISPOSITIVO`, `LUGAR`, `SESION`, `LECTURA`, `TIPO_ALERTA` y `ALERTA`. Convención: tablas en MAYÚSCULA, columnas en snake_case con el sufijo de su tabla, dominios `dom_`, restricciones `pk_`, `fk_`, `ck_`, `df_`, `uq_`.

1. Instalar SQL Server 2022 Express y SQL Server Management Studio.
2. Abrir `base_de_datos/aire_sqlserver.sql` y ejecutarlo (F5): crea la base, los 12 dominios, las tablas con sus reglas y valores por defecto, los metadatos, los roles `rol_admin` y `rol_app` con sus usuarios, y carga los datos.
3. Ejecutar `base_de_datos/aire_pruebas.sql`: 6 pruebas de integridad y la consulta de metadatos. No cambia los datos.
4. Para que la aplicación Java se conecte: activar TCP/IP en el puerto 1433 y la autenticación mixta (driver mssql-jdbc, `jdbc:sqlserver://localhost:1433;databaseName=aire_db;encrypt=false`).

## Modelos matemáticos (MATLAB)

Abrir y ejecutar `matlab/ED_modelos.m` y `matlab/VV_funciones.m`. Cada script imprime sus resultados y guarda las figuras en PNG. Los valores son **supuestos** para el medio ciclo (ejemplo: espacio de 144 m³ con 30 personas).

- **Mezclas (CO2):** `C(t) = Css + (C0 − Css)·e^(−kt)`, con `k = Q/V` y `Css = Cext + G/Q`.
- **Newton (temperatura):** `T(t) = Ta + (T0 − Ta)·e^(−kt)`.
- **Índice de incomodidad:** `DI(T, H) = T − 0,55(1 − 0,01H)(T − 14,5)`; en (30 °C, 80 %) vale 28,3.
- **CO2 de equilibrio:** `Css(n, Q) = 420 + 5n/Q`; para no pasar de 1000 ppm con 30 personas hacen falta unos 8,6 L/s por persona.

## Componentes (segundo ciclo)

ESP32 DevKitC V4 · MQ-135 (divisor 10 kΩ / 10 kΩ, máx. 2,5 V al GPIO 34) · DHT22 · MAX4466 · LCD 20x4 I2C · 6 LEDs · buzzer · relé 5 V · ventilador 5020 de 5 V. Costo estimado: $70,28 en electrónica y cerca de $101 con la maqueta.
