# Sistema de monitoreo de calidad del aire basado en sensores

Proyecto integrador PAO 3 · Carrera de Tecnologías de la Información · ESPOCH Sede Orellana
Tutor (guía): Ing. Santiago Logroño · Periodo septiembre 2026 – febrero 2027

Aparato de bajo costo con un **ESP32** que mide **CO2 estimado, temperatura, humedad y ruido** en espacios cerrados (aulas, oficinas, locales), avisa con una pantalla LCD 20x4, LEDs y un buzzer, y **enciende un extractor por sí solo**. Las lecturas pasan por USB a una computadora y se guardan en **MySQL 8**. Con esos datos se plantean modelos de **Ecuaciones Diferenciales** y **Cálculo de Varias Variables**. Para las pruebas se usa una maqueta con el aspecto de un aula (banco de pruebas).

> **Estado (medio ciclo, noviembre 2026):** diseño completo y simulación en Wokwi funcionando, **13 de 13 pruebas aprobadas**, base de datos diseñada y probada con 111 lecturas de la simulación, modelos resueltos y comprobados en MATLAB. El aparato real, la maqueta y la aplicación Java se construyen en el segundo ciclo.

## Equipo

| Integrante | Rol |
|---|---|
| Alan Paucar | Líder del proyecto · Ecuaciones Diferenciales · Cálculo de Varias Variables |
| Lenin Manobanda | Hardware · Base de datos |
| Andrea Quiroga | Simulación y pruebas · Diseño de la aplicación |
| Daniela Valladolid | Gestión del proyecto · Contexto social |

## Simulación

Proyecto en Wokwi: https://wokwi.com/projects/476817489772753921

1. Abrir el enlace y presionar **Play**. Esperar los 20 s de precalentamiento.
2. La simulación arranca con el gas alto: lo primero es **bajar la barra del sensor de gas** al mínimo.
3. Cambiar la barra del gas, la temperatura del DHT22 y el potenciómetro de ruido para ver las reglas.

En Wokwi el MQ-135 se reemplaza por un MQ-2 con barra, el micrófono MAX4466 por un potenciómetro deslizante y el extractor por un LED morado detrás del relé. En el código, `SIMULACION = true` para Wokwi y `false` para el aparato real.

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

**Línea serial (USB, 115200, cada ~4 s):** `temperatura,humedad,ppmCO2,ruidoDB,ventilador` · ejemplo `24.00,40.00,1326,30,1` · si falla el DHT22 se envía `-999`.

## Estructura del repositorio

| Carpeta | Contenido |
|---|---|
| `firmware/` | `sketch.ino` (programa del ESP32, comentarios en inglés) y `diagram.json` (circuito de Wokwi) |
| `pruebas_wokwi/` | CSV con las 111 lecturas de las pruebas y capturas de los 13 casos |
| `base_de_datos/` | `aire_mysql.sql`, modelo E-R, modelo físico y los 6 CSV para cargar |
| `matlab/` | `ED_modelos.m`, `VV_funciones.m`, `figuras_EN.m`, salida de MATLAB, figuras en español (informe) y en inglés (diapositivas) |
| `diagramas/` | Diagrama de bloques, esquema de conexiones v3, diagrama de procesos, UML y wireframes |
| `presentacion/` | Presentación del medio ciclo (HTML, funciona sin internet) y maqueta 3D |
| `documentos/` | Informe de avance y piezas de cada materia |

## Base de datos (MySQL 8)

Esquema `aire_db` con 6 tablas: `dispositivo`, `lugar`, `sesion`, `lectura`, `tipo_alerta` y `alerta` (tercera forma normal).

1. Instalar MySQL Community Server 8 y MySQL Workbench.
2. Crear el esquema y las tablas (con Workbench o con `base_de_datos/aire_mysql.sql`).
3. Crear los usuarios `admin_aire` (todos los permisos) y `app_aire` (solo `SELECT` e `INSERT`), ambos en localhost.
4. Importar los CSV en este orden: `dispositivo` → `lugar` → `tipo_alerta` → `sesion` → `lectura` → `alerta`.

## Modelos matemáticos (MATLAB)

Abrir y ejecutar `matlab/ED_modelos.m` y `matlab/VV_funciones.m`. Cada script imprime sus resultados y guarda las figuras en PNG. Los valores son **supuestos** para el medio ciclo (ejemplo: espacio de 144 m³ con 30 personas).

- **Mezclas (CO2):** `C(t) = Css + (C0 − Css)·e^(−kt)`, con `k = Q/V` y `Css = Cext + G/Q`.
- **Newton (temperatura):** `T(t) = Ta + (T0 − Ta)·e^(−kt)`.
- **Índice de incomodidad:** `DI(T, H) = T − 0,55(1 − 0,01H)(T − 14,5)`; en (30 °C, 80 %) vale 28,3.
- **CO2 de equilibrio:** `Css(n, Q) = 420 + 5n/Q`; para no pasar de 1000 ppm con 30 personas hacen falta unos 8,6 L/s por persona.

## Componentes (segundo ciclo)

ESP32 DevKitC V4 · MQ-135 (divisor 10 kΩ / 10 kΩ, máx. 2,5 V al GPIO 34) · DHT22 · MAX4466 · LCD 20x4 I2C · 6 LEDs · buzzer · relé 5 V · ventilador 5020 de 5 V. Costo estimado con la maqueta: cerca de 101 dólares.
