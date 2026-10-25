#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include "DHTesp.h"

// Air quality monitor - ESP32 firmware (ESPOCH Orellana, PAO 3 integrator project)
// Measures estimated CO2 (MQ-135), temperature and humidity (DHT22) and noise (MAX4466).
// Shows the values on a 20x4 LCD, warns with LEDs and a buzzer, controls an exhaust fan
// through a relay, and sends one CSV line per cycle over USB serial (one way only).
//
// In Wokwi, noise is simulated with a slide potentiometer.
// On the real device (MAX4466) set this to false.
const bool SIMULACION = true;

const int PIN_DHT = 15;
const int PIN_CO2 = 34;
const int PIN_RUIDO = 35;

const int LED_VERDE = 25;
const int LED_AMARILLO = 26;
const int LED_ROJO = 27;
const int LED_CALOR = 14;
const int LED_FRIO = 13;
const int LED_RUIDO = 33;
const int PIN_BUZZER = 4;
const int PIN_VENTILADOR = 18;

// Sensor warm-up time. Simulation: 20 s. Real device: 120 s or more
const int SEGUNDOS_CALENTAMIENTO = 20;

// Noise: provisional threshold and number of readings in a row before warning
const int RUIDO_ALTO_DB = 70;
const int LECTURAS_RUIDO = 3;

DHTesp sensorDHT;
LiquidCrystal_I2C lcd(0x27, 20, 4);

// Fan state is kept between cycles (hysteresis)
bool ventiladorEncendido = false;
// Number of consecutive high-noise readings
int contadorRuido = 0;

void pitar() {
  for (int i = 0; i < 300; i++) {
    digitalWrite(PIN_BUZZER, HIGH);
    delayMicroseconds(500);
    digitalWrite(PIN_BUZZER, LOW);
    delayMicroseconds(500);
  }
}

// Writes one LCD row and fills the rest with spaces (20 characters).
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

// Returns the estimated noise level in dB
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

void setup() {
  Serial.begin(115200);

  pinMode(LED_VERDE, OUTPUT);
  pinMode(LED_AMARILLO, OUTPUT);
  pinMode(LED_ROJO, OUTPUT);
  pinMode(LED_CALOR, OUTPUT);
  pinMode(LED_FRIO, OUTPUT);
  pinMode(LED_RUIDO, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_VENTILADOR, OUTPUT);
  digitalWrite(PIN_VENTILADOR, LOW);

  // Self-test at start-up: all LEDs, fan and buzzer
  digitalWrite(LED_VERDE, HIGH);
  digitalWrite(LED_AMARILLO, HIGH);
  digitalWrite(LED_ROJO, HIGH);
  digitalWrite(LED_CALOR, HIGH);
  digitalWrite(LED_FRIO, HIGH);
  digitalWrite(LED_RUIDO, HIGH);
  digitalWrite(PIN_VENTILADOR, HIGH);   // the fan is tested too
  pitar();
  delay(2000);
  digitalWrite(LED_VERDE, LOW);
  digitalWrite(LED_AMARILLO, LOW);
  digitalWrite(LED_ROJO, LOW);
  digitalWrite(LED_CALOR, LOW);
  digitalWrite(LED_FRIO, LOW);
  digitalWrite(LED_RUIDO, LOW);
  digitalWrite(PIN_VENTILADOR, LOW);

  sensorDHT.setup(PIN_DHT, DHTesp::DHT22);
  lcd.init();
  lcd.backlight();

  // MQ-135 warm-up (no alarms during this time)
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

void loop() {
  // 1. Noise first: the buzzer is silent at this moment
  int ruidoDB = leerRuido();
  if (ruidoDB >= RUIDO_ALTO_DB) {
    contadorRuido = contadorRuido + 1;
  } else {
    contadorRuido = 0;
  }
  bool ruidoAlto = (contadorRuido >= LECTURAS_RUIDO);

  // 2. Temperature and humidity
  TempAndHumidity datos = sensorDHT.getTempAndHumidity();
  float temperatura = datos.temperature;
  float humedad = datos.humidity;
  bool errorDHT = false;
  if (isnan(temperatura) || isnan(humedad)) {
    errorDHT = true;
  }

  // 3. CO2 (PROVISIONAL scale, calibrated with the Wokwi sensor min and max)
  int crudoCO2 = analogRead(PIN_CO2);
  int ppmCO2 = map(crudoCO2, 1386, 4041, 400, 2000);
  ppmCO2 = constrain(ppmCO2, 400, 2000);

  // Turn all LEDs off before deciding
  digitalWrite(LED_VERDE, LOW);
  digitalWrite(LED_AMARILLO, LOW);
  digitalWrite(LED_ROJO, LOW);
  digitalWrite(LED_CALOR, LOW);
  digitalWrite(LED_FRIO, LOW);
  digitalWrite(LED_RUIDO, LOW);

  String mensaje = "AIRE Normal";

  // Temperature rules (only if the DHT22 works)
  if (!errorDHT) {
    if (temperatura >= 30) {
      digitalWrite(LED_CALOR, HIGH);
      mensaje = "CALOR";
    }
    if (temperatura < 20) {
      digitalWrite(LED_FRIO, HIGH);
      mensaje = "FRIO";
    }
  } else {
    mensaje = "ERROR DHT22";
  }

  // CO2 traffic light
  if (ppmCO2 < 800) {
    digitalWrite(LED_VERDE, HIGH);
  }
  if (ppmCO2 >= 800 && ppmCO2 < 1200) {
    digitalWrite(LED_AMARILLO, HIGH);
    mensaje = "VENTILAR";
  }
  if (ppmCO2 >= 1200) {
    digitalWrite(LED_ROJO, HIGH);
    mensaje = "CO2 ALTO";
  }

  // Noise: LED and message only, never the buzzer
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

  // Fan with hysteresis (CO2 and temperature; noise does not turn it on)
  bool calor = false;
  bool temperaturaOk = true;
  if (!errorDHT) {
    calor = (temperatura >= 30);
    temperaturaOk = (temperatura <= 25);
  }
  bool hayQuePrender = calor || (ppmCO2 >= 1200);
  bool sePuedeApagar = temperaturaOk && (ppmCO2 < 1000);

  if (hayQuePrender) {
    ventiladorEncendido = true;
  } else if (sePuedeApagar) {
    ventiladorEncendido = false;
  }
  // If neither condition is true, the fan keeps its previous state

  if (ventiladorEncendido) {
    digitalWrite(PIN_VENTILADOR, HIGH);
  } else {
    digitalWrite(PIN_VENTILADOR, LOW);
  }

  // Buzzer: only when CO2 is critical
  if (ppmCO2 >= 1200) {
    pitar();
  }

  // 20x4 LCD: each row is written over the old one (no lcd.clear(), no flicker)
  String fila1 = "CO2:" + String(ppmCO2) + "ppm  R:" + String(ruidoDB) + "dB";

  String fila2;
  if (errorDHT) {
    fila2 = "DHT22: ERROR";
  } else {
    fila2 = "T:" + String(temperatura, 1) + "C  H:" + String(humedad, 0) + "%";
  }

  String fila3;
  if (ventiladorEncendido) {
    fila3 = "Ventilador: ON";
  } else {
    fila3 = "Ventilador: OFF";
  }

  String fila4 = "> " + mensaje;

  escribirFila(0, fila1);
  escribirFila(1, fila2);
  escribirFila(2, fila3);
  escribirFila(3, fila4);

  // Serial line: T, H, CO2, noise, fan
  // If the DHT22 fails, -999 is sent (error code)
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

  delay(4000);
}
