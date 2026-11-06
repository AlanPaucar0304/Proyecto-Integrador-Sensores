// =====================================================================
// MONITOR DE CALIDAD DEL AIRE · ESP32 (ESPOCH Orellana · PAO 3)
// Air quality monitor · ESP32 firmware (integrator project)
// ---------------------------------------------------------------------
// Measures estimated CO2 (MQ-135), temperature and humidity (DHT22) and
// noise (MAX4466). Shows the values on a 20x4 LCD, warns with LEDs and a
// buzzer, and controls an exhaust fan through a relay.
// Official data path: one CSV line every cycle over USB serial
// (Java app -> SQL Server). Mid-term add-on: every ~20 s the same data
// is also sent to ThingSpeak over WiFi.
//
// Index (search "BLOQUE n" with Ctrl+F):
//   1 Librerias         2 Modo              3 Pines
//   4 Umbrales          5 WiFi/ThingSpeak   6 Variables de estado
//   7 Sensores          8 LEDs y buzzer     9 Extractor
//  10 Pantalla LCD     11 Salida USB       12 Envio a ThingSpeak
//  13 Setup            14 Loop
// =====================================================================


// =====================================================================
// BLOQUE 1 · LIBRERIAS
// Block 1 · Libraries
// =====================================================================
#include <Wire.h>               // I2C bus for the LCD
#include <LiquidCrystal_I2C.h>  // 20x4 LCD with I2C adapter
#include "DHTesp.h"             // DHT22 temperature and humidity sensor
#include <WiFi.h>               // ESP32 WiFi radio
#include <WiFiClientSecure.h>   // HTTPS connection
#include <HTTPClient.h>         // HTTP POST requests


// =====================================================================
// BLOQUE 2 · MODO: SIMULACION O APARATO REAL
// Block 2 · Mode: simulation or real device
// =====================================================================
// true  = Wokwi: noise comes from a slide potentiometer and the gas sensor
//         runs at 3.3 V without the 10k/10k divider (the divider makes the
//         simulation very slow).
// false = real device: MAX4466 microphone and MQ-135 at 5 V with the divider.
const bool SIMULACION = true;


// =====================================================================
// BLOQUE 3 · PINES (CONEXIONES DEL ESP32)
// Block 3 · ESP32 pin map
// =====================================================================
// Sensors (inputs)
const int PIN_DHT = 15;         // DHT22 data
const int PIN_CO2 = 34;         // MQ-135 analog output (ADC)
const int PIN_RUIDO = 35;       // MAX4466 / potentiometer (ADC)
// LEDs (outputs)
const int LED_VERDE = 25;       // CO2 normal
const int LED_AMARILLO = 26;    // CO2: ventilate
const int LED_ROJO = 27;        // CO2 high
const int LED_CALOR = 14;       // heat (orange)
const int LED_FRIO = 13;        // cold (blue)
const int LED_RUIDO = 33;       // high noise (white)
// Actuators (outputs)
const int PIN_BUZZER = 4;       // buzzer
const int PIN_VENTILADOR = 18;  // relay input -> exhaust fan (purple LED in Wokwi)
// LCD: SDA = GPIO 21, SCL = GPIO 22 (default I2C pins, set by Wire)


// =====================================================================
// BLOQUE 4 · UMBRALES (LIMITES DE ALERTA)
// Block 4 · Alert thresholds
// =====================================================================
const int CO2_VENTILAR = 800;      // ppm: yellow LED, "VENTILAR"
const int CO2_ALTO = 1200;         // ppm: red LED, buzzer and fan ON
const int CO2_APAGAR = 1000;       // ppm: fan may turn OFF below this (hysteresis)
const float TEMP_CALOR = 30;       // °C: orange LED and fan ON
const float TEMP_FRIO = 20;        // °C: blue LED (below this value)
const float TEMP_APAGAR = 25;      // °C: fan may turn OFF at or below this (hysteresis)
const int RUIDO_ALTO_DB = 70;      // dB: provisional noise limit
const int LECTURAS_RUIDO = 3;      // readings in a row above the limit before warning
// Provisional CO2 scale (from the min and max of the Wokwi gas sensor)
const int CO2_CRUDO_MIN = 1386;    // ADC value for 400 ppm
const int CO2_CRUDO_MAX = 4041;    // ADC value for 2000 ppm
// Sensor warm-up. Simulation: 20 s. Real device: 120 s or more
const int SEGUNDOS_CALENTAMIENTO = 20;


// =====================================================================
// BLOQUE 5 · WIFI Y THINGSPEAK (AGREGADO DEL MEDIO CICLO)
// Block 5 · WiFi and ThingSpeak settings (mid-term add-on)
// =====================================================================
const bool USAR_THINGSPEAK = true;                 // false = USB only
const char* WIFI_RED = "Wokwi-GUEST";              // Wokwi virtual network (no password)
const char* WIFI_CLAVE = "";
const char* THINGSPEAK_KEY = "PEGAR_WRITE_API_KEY";   // Write API Key of the channel
const char* THINGSPEAK_URL = "https://api.thingspeak.com/update";
// Free accounts accept one entry every 15 s: we send every 5 cycles (~20 s)
const int CICLOS_POR_ENVIO = 5;


// =====================================================================
// BLOQUE 6 · VARIABLES DE ESTADO
// Block 6 · Objects and state variables
// =====================================================================
DHTesp sensorDHT;
LiquidCrystal_I2C lcd(0x27, 20, 4);   // I2C address 0x27, 20 columns, 4 rows

// Last readings (updated in every cycle by Block 7)
float temperatura = 0;
float humedad = 0;
bool errorDHT = false;      // true when the DHT22 does not answer
int ppmCO2 = 400;
int ruidoDB = 30;
bool ruidoAlto = false;     // true after LECTURAS_RUIDO high readings in a row

// State kept between cycles
bool ventiladorEncendido = false;   // fan state (needed for the hysteresis)
int contadorRuido = 0;              // consecutive high-noise readings
int contadorCiclos = 0;             // cycles since the last ThingSpeak entry
String mensaje = "AIRE Normal";     // text for LCD row 4


// =====================================================================
// BLOQUE 7 · SENSORES (LECTURA)
// Block 7 · Sensor readings
// =====================================================================

// Noise in dB. Read first in the cycle, while the buzzer is silent.
int leerRuido() {
  if (SIMULACION) {
    // The potentiometer works as a "volume" control: 30 to 100 dB
    int crudo = analogRead(PIN_RUIDO);
    return map(crudo, 0, 4095, 30, 100);
  }

  // Real device: the MAX4466 outputs an audio wave.
  // We measure the peak-to-peak amplitude over a 50 ms window.
  int maximo = 0;
  int minimo = 4095;
  unsigned long inicio = millis();
  while (millis() - inicio < 50) {
    int muestra = analogRead(PIN_RUIDO);
    if (muestra > maximo) {
      maximo = muestra;
    }
    if (muestra < minimo) {
      minimo = muestra;
    }
  }
  float voltajePicoPico = (maximo - minimo) * 3.3 / 4095.0;
  if (voltajePicoPico < 0.001) {
    voltajePicoPico = 0.001;
  }
  // PROVISIONAL formula: to be calibrated with a phone sound level meter
  float decibeles = 60 + 20 * log10(voltajePicoPico / 0.2);
  return constrain((int)decibeles, 30, 120);
}

// Estimated CO2 in ppm (PROVISIONAL scale, see Block 4)
int leerCO2() {
  int crudo = analogRead(PIN_CO2);
  if (!SIMULACION) {
    // Real device: the MQ-135 runs at 5 V and the 10k/10k divider (R7, R8) halves
    // its output, so GPIO 34 gets 2.5 V at most. Doubling the reading gives back the
    // sensor value on the same scale used in Wokwi. To be calibrated in December.
    crudo = crudo * 2;
  }
  int ppm = map(crudo, CO2_CRUDO_MIN, CO2_CRUDO_MAX, 400, 2000);
  return constrain(ppm, 400, 2000);
}

// Reads all sensors and stores the values in the Block 6 variables
void leerSensores() {
  // 1. Noise (counts how many high readings come in a row)
  ruidoDB = leerRuido();
  if (ruidoDB >= RUIDO_ALTO_DB) {
    contadorRuido = contadorRuido + 1;
  } else {
    contadorRuido = 0;
  }
  ruidoAlto = (contadorRuido >= LECTURAS_RUIDO);

  // 2. Temperature and humidity (NaN = the DHT22 did not answer)
  TempAndHumidity datos = sensorDHT.getTempAndHumidity();
  temperatura = datos.temperature;
  humedad = datos.humidity;
  errorDHT = (isnan(temperatura) || isnan(humedad));

  // 3. CO2
  ppmCO2 = leerCO2();
}


// =====================================================================
// BLOQUE 8 · LEDS Y BUZZER (AVISOS)
// Block 8 · Alert LEDs and buzzer
// =====================================================================

// Short beep (~0.3 s at 1 kHz)
void pitar() {
  for (int i = 0; i < 300; i++) {
    digitalWrite(PIN_BUZZER, HIGH);
    delayMicroseconds(500);
    digitalWrite(PIN_BUZZER, LOW);
    delayMicroseconds(500);
  }
}

void apagarLeds() {
  digitalWrite(LED_VERDE, LOW);
  digitalWrite(LED_AMARILLO, LOW);
  digitalWrite(LED_ROJO, LOW);
  digitalWrite(LED_CALOR, LOW);
  digitalWrite(LED_FRIO, LOW);
  digitalWrite(LED_RUIDO, LOW);
}

// Turns on the LED for each state and prepares the LCD message.
// Priority of the message: CO2 over temperature; noise is added at the end.
void actualizarLeds() {
  apagarLeds();
  mensaje = "AIRE Normal";

  // Temperature (only if the DHT22 works)
  if (!errorDHT) {
    if (temperatura >= TEMP_CALOR) {
      digitalWrite(LED_CALOR, HIGH);
      mensaje = "CALOR";
    }
    if (temperatura < TEMP_FRIO) {
      digitalWrite(LED_FRIO, HIGH);
      mensaje = "FRIO";
    }
  } else {
    mensaje = "ERROR DHT22";
  }

  // CO2 traffic light
  if (ppmCO2 < CO2_VENTILAR) {
    digitalWrite(LED_VERDE, HIGH);
  }
  if (ppmCO2 >= CO2_VENTILAR && ppmCO2 < CO2_ALTO) {
    digitalWrite(LED_AMARILLO, HIGH);
    mensaje = "VENTILAR";
  }
  if (ppmCO2 >= CO2_ALTO) {
    digitalWrite(LED_ROJO, HIGH);
    mensaje = "CO2 ALTO";
  }

  // Noise: white LED and message only, never the buzzer
  if (ruidoAlto) {
    digitalWrite(LED_RUIDO, HIGH);
    if (mensaje.equals("AIRE Normal")) {
      mensaje = "RUIDO ALTO";
    } else {
      mensaje = mensaje + " + RUIDO";
      if (mensaje.length() > 18) {
        mensaje = "ERROR DHT22+RUIDO";
      }
    }
  }
}

// Buzzer: only when CO2 is critical
void avisarConBuzzer() {
  if (ppmCO2 >= CO2_ALTO) {
    pitar();
  }
}


// =====================================================================
// BLOQUE 9 · EXTRACTOR (RELE) CON HISTERESIS
// Block 9 · Exhaust fan control (relay) with hysteresis
// =====================================================================
// ON  when CO2 >= 1200 ppm or temperature >= 30 °C.
// OFF only when CO2 < 1000 ppm and temperature <= 25 °C.
// In between, the fan keeps its previous state (it does not switch on and off).
// Noise never turns the fan on.
void controlarExtractor() {
  bool calor = false;
  bool temperaturaOk = true;
  if (!errorDHT) {
    calor = (temperatura >= TEMP_CALOR);
    temperaturaOk = (temperatura <= TEMP_APAGAR);
  }
  bool hayQuePrender = calor || (ppmCO2 >= CO2_ALTO);
  bool sePuedeApagar = temperaturaOk && (ppmCO2 < CO2_APAGAR);

  if (hayQuePrender) {
    ventiladorEncendido = true;
  } else if (sePuedeApagar) {
    ventiladorEncendido = false;
  }

  if (ventiladorEncendido) {
    digitalWrite(PIN_VENTILADOR, HIGH);
  } else {
    digitalWrite(PIN_VENTILADOR, LOW);
  }
}


// =====================================================================
// BLOQUE 10 · PANTALLA LCD 20x4
// Block 10 · 20x4 LCD display
// =====================================================================

// Writes one row and fills the rest with spaces (20 characters).
// The old text is covered, so lcd.clear() is not needed and the screen does not flicker.
void escribirFila(int fila, String texto) {
  if (texto.length() > 20) {
    texto = texto.substring(0, 20);
  }
  for (int i = texto.length(); i < 20; i++) {
    texto = texto + " ";
  }
  lcd.setCursor(0, fila);
  lcd.print(texto);
}

// Row 1: CO2 and noise · Row 2: temperature and humidity · Row 3: fan · Row 4: message
void mostrarLCD() {
  escribirFila(0, "CO2:" + String(ppmCO2) + "ppm  R:" + String(ruidoDB) + "dB");

  if (errorDHT) {
    escribirFila(1, "DHT22: ERROR");
  } else {
    escribirFila(1, "T:" + String(temperatura, 1) + "C  H:" + String(humedad, 0) + "%");
  }

  if (ventiladorEncendido) {
    escribirFila(2, "Ventilador: ON");
  } else {
    escribirFila(2, "Ventilador: OFF");
  }

  escribirFila(3, "> " + mensaje);
}


// =====================================================================
// BLOQUE 11 · SALIDA USB (LINEA SERIAL PARA LA APP JAVA)
// Block 11 · USB serial output (official data path)
// =====================================================================
// One CSV line per cycle: temperature,humidity,co2,noise,fan
// Example: 24.00,40.00,1373,30,1
// If the DHT22 fails, -999 is sent in the first two fields (error code).
// Status lines start with "#" so the Java app skips them.
void enviarSerial() {
  if (errorDHT) {
    Serial.print(-999);
    Serial.print(",");
    Serial.print(-999);
  } else {
    Serial.print(temperatura);
    Serial.print(",");
    Serial.print(humedad);
  }
  Serial.print(",");
  Serial.print(ppmCO2);
  Serial.print(",");
  Serial.print(ruidoDB);
  Serial.print(",");
  if (ventiladorEncendido) {
    Serial.println(1);
  } else {
    Serial.println(0);
  }
}


// =====================================================================
// BLOQUE 12 · ENVIO A THINGSPEAK POR WIFI (AGREGADO)
// Block 12 · WiFi connection and ThingSpeak upload (add-on)
// =====================================================================

// Connects to WiFi (about 20 s at most)
void conectarWiFi() {
  Serial.println("# Connecting to WiFi");
  WiFi.begin(WIFI_RED, WIFI_CLAVE, 6);
  int intentos = 0;
  while (WiFi.status() != WL_CONNECTED && intentos < 80) {
    delay(250);
    intentos++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("# WiFi connected");
  } else {
    Serial.println("# WiFi not connected, data only by USB");
  }
}

// Sends one entry. Fields: 1 temperature, 2 humidity, 3 CO2, 4 noise, 5 fan.
// If the DHT22 fails, fields 1 and 2 are left empty (no -999 in the charts).
void enviarThingSpeak() {
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.reconnect();
    return;
  }
  String datos = "api_key=" + String(THINGSPEAK_KEY);
  if (!errorDHT) {
    datos += "&field1=" + String(temperatura, 2);
    datos += "&field2=" + String(humedad, 2);
  }
  datos += "&field3=" + String(ppmCO2);
  datos += "&field4=" + String(ruidoDB);
  datos += "&field5=" + String(ventiladorEncendido ? 1 : 0);

  WiFiClientSecure cliente;
  cliente.setInsecure();   // simulation only: the certificate is not checked
  HTTPClient http;
  if (!http.begin(cliente, THINGSPEAK_URL)) {
    Serial.println("# ThingSpeak: could not start HTTPS");
    return;
  }
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");
  int codigo = http.POST(datos);
  String respuesta = http.getString();
  respuesta.trim();
  if (codigo == 200 && respuesta.toInt() > 0) {
    Serial.println("# ThingSpeak entry " + respuesta);   // entry number in the channel
  } else {
    Serial.println("# ThingSpeak error " + String(codigo) + " " + respuesta);
  }
  http.end();
}

// Counts cycles and sends one entry every CICLOS_POR_ENVIO cycles
void revisarEnvioThingSpeak() {
  if (!USAR_THINGSPEAK) {
    return;
  }
  contadorCiclos = contadorCiclos + 1;
  if (contadorCiclos >= CICLOS_POR_ENVIO) {
    contadorCiclos = 0;
    enviarThingSpeak();
  }
}


// =====================================================================
// BLOQUE 13 · SETUP (ARRANQUE)
// Block 13 · Start-up: pins, self-test, WiFi and sensor warm-up
// =====================================================================
void setup() {
  Serial.begin(115200);

  // Output pins
  pinMode(LED_VERDE, OUTPUT);
  pinMode(LED_AMARILLO, OUTPUT);
  pinMode(LED_ROJO, OUTPUT);
  pinMode(LED_CALOR, OUTPUT);
  pinMode(LED_FRIO, OUTPUT);
  pinMode(LED_RUIDO, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_VENTILADOR, OUTPUT);
  digitalWrite(PIN_VENTILADOR, LOW);

  // Self-test: all LEDs, the fan and the buzzer for 2 s
  digitalWrite(LED_VERDE, HIGH);
  digitalWrite(LED_AMARILLO, HIGH);
  digitalWrite(LED_ROJO, HIGH);
  digitalWrite(LED_CALOR, HIGH);
  digitalWrite(LED_FRIO, HIGH);
  digitalWrite(LED_RUIDO, HIGH);
  digitalWrite(PIN_VENTILADOR, HIGH);
  pitar();
  delay(2000);
  apagarLeds();
  digitalWrite(PIN_VENTILADOR, LOW);

  // Sensors and LCD
  sensorDHT.setup(PIN_DHT, DHTesp::DHT22);
  lcd.init();
  lcd.backlight();

  // WiFi (add-on)
  if (USAR_THINGSPEAK) {
    escribirFila(0, "Calidad del aire");
    escribirFila(1, "Conectando WiFi...");
    escribirFila(2, "");
    escribirFila(3, "");
    conectarWiFi();
  }

  // MQ-135 warm-up (no alarms during this time; the yellow LED blinks)
  for (int s = SEGUNDOS_CALENTAMIENTO; s > 0; s--) {
    escribirFila(0, "Calidad del aire");
    escribirFila(1, "CALENTANDO SENSORES");
    escribirFila(2, "");
    escribirFila(3, "Faltan: " + String(s) + " s");
    digitalWrite(LED_AMARILLO, HIGH);
    delay(500);
    digitalWrite(LED_AMARILLO, LOW);
    delay(500);
  }

  lcd.clear();
  lcd.setCursor(0, 1);
  lcd.print("Sistema listo");
  delay(1500);
}


// =====================================================================
// BLOQUE 14 · LOOP (CICLO PRINCIPAL CADA 4 s)
// Block 14 · Main cycle (every 4 s)
// =====================================================================
void loop() {
  leerSensores();            // Block 7: noise, temperature, humidity, CO2
  actualizarLeds();          // Block 8: LEDs and LCD message
  controlarExtractor();      // Block 9: relay with hysteresis
  avisarConBuzzer();         // Block 8: beep only with high CO2
  mostrarLCD();              // Block 10: 4 rows on the LCD
  enviarSerial();            // Block 11: CSV line over USB (official path)
  revisarEnvioThingSpeak();  // Block 12: one entry every ~20 s (add-on)
  delay(4000);
}
