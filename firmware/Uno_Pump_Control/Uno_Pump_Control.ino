// =====================================================
// UNO PUMP CONTROL STATION + WINDOWS SERIAL APP
//
// CL42T DIRECT 5V WIRING:
// PUL+ / DIR+ / ENA+ -> Arduino UNO 5V
// PUL- -> STEP_PUMP
// DIR- -> DIR_PUMP
// ENA- -> ENA_PUMP
//
// PRESS SWITCH:
// One side to PRESS_SWITCH_PIN, the other side to GND.
// Uses INPUT_PULLUP, so pressed = LOW.
// =====================================================

#include <Arduino.h>
#include <EEPROM.h>

// ---------------- PIN MAP ----------------
#define STEP_PUMP A5
#define DIR_PUMP  2
#define ENA_PUMP  A1

#define PRESS_SWITCH_PIN A3

// ---------------- LIMITS / DEFAULTS ----------------
const long DEFAULT_PUMP_STEPS = 32000;
const unsigned long DEFAULT_PUMP_SPEED_US = 210;

const long MIN_PUMP_STEPS = 10;
const long MAX_PUMP_STEPS = 50000;

const unsigned long MIN_PUMP_SPEED_US = 210;
const unsigned long MAX_PUMP_SPEED_US = 5000;

// ---------------- STEPPER DRIVER LOGIC ----------------
// Common anode: PUL+ / DIR+ / ENA+ to +5V.
// Arduino output LOW activates the CL42T input.
#define STEP_IDLE_LEVEL HIGH
#define STEP_ACTIVE_LEVEL LOW

#define DRIVER_ENABLE_LEVEL HIGH
#define DRIVER_DISABLE_LEVEL LOW

// If pump turns the wrong way, change this to LOW.
#define PUMP_DIR_CW HIGH

// ---------------- INPUT LOGIC ----------------
#define SWITCH_PRESSED LOW

// ---------------- TIMING ----------------
const unsigned long DEBOUNCE_MS = 50;
const unsigned long POST_RUN_LOCKOUT_MS = 500;

const uint32_t CONFIG_MAGIC = 0x50554D50UL; // "PUMP"
const int EEPROM_ADDR = 0;

struct PumpConfig
{
  uint32_t magic;
  long steps;
  unsigned long speedUs;
};

PumpConfig config;

enum State
{
  IDLE,
  RUN_PUMP
};

State machineState = IDLE;

long pumpStepsDone = 0;
unsigned long lastPumpPulse = 0;
unsigned long runEndedAt = 0;

bool switchPrev = HIGH;
bool switchArmed = false;

String serialLine = "";

bool validSteps(long steps)
{
  return steps >= MIN_PUMP_STEPS && steps <= MAX_PUMP_STEPS;
}

bool validSpeed(unsigned long speedUs)
{
  return speedUs >= MIN_PUMP_SPEED_US && speedUs <= MAX_PUMP_SPEED_US;
}

void loadConfig()
{
  EEPROM.get(EEPROM_ADDR, config);

  if (config.magic != CONFIG_MAGIC ||
      !validSteps(config.steps) ||
      !validSpeed(config.speedUs))
  {
    config.magic = CONFIG_MAGIC;
    config.steps = DEFAULT_PUMP_STEPS;
    config.speedUs = DEFAULT_PUMP_SPEED_US;
    EEPROM.put(EEPROM_ADDR, config);
  }
}

void saveConfig()
{
  config.magic = CONFIG_MAGIC;
  EEPROM.put(EEPROM_ADDR, config);
}

void printStatus()
{
  Serial.print("STATUS ");
  Serial.print(machineState == IDLE ? "IDLE" : "RUNNING");
  Serial.print(" STEPS=");
  Serial.print(config.steps);
  Serial.print(" SPEED_US=");
  Serial.print(config.speedUs);
  Serial.print(" DONE=");
  Serial.println(pumpStepsDone);
}

void enablePumpDriver()
{
  digitalWrite(ENA_PUMP, DRIVER_ENABLE_LEVEL);
}

void disablePumpDriver()
{
  digitalWrite(ENA_PUMP, DRIVER_DISABLE_LEVEL);
}

inline void pulseStep(uint8_t pin)
{
  digitalWrite(pin, STEP_ACTIVE_LEVEL);
  delayMicroseconds(10);
  digitalWrite(pin, STEP_IDLE_LEVEL);
  delayMicroseconds(10);
}

void startPumpRun()
{
  if (machineState != IDLE)
  {
    Serial.println("ERR BUSY");
    return;
  }

  enablePumpDriver();

  pumpStepsDone = 0;
  lastPumpPulse = micros();

  digitalWrite(DIR_PUMP, PUMP_DIR_CW);

  machineState = RUN_PUMP;

  Serial.println("RUN START");
}

void stopPumpRun()
{
  machineState = IDLE;
  runEndedAt = millis();
  Serial.println("RUN STOP");
}

void finishPumpRun()
{
  machineState = IDLE;
  runEndedAt = millis();

  // Leave enabled if holding torque is needed. Disable for cooler idle driver.
  // disablePumpDriver();

  Serial.println("RUN COMPLETE");
}

void handlePressSwitch(unsigned long nowMs)
{
  bool switchNow = digitalRead(PRESS_SWITCH_PIN);

  if (switchNow == HIGH)
    switchArmed = true;

  if (machineState == IDLE &&
      switchArmed &&
      (nowMs - runEndedAt) >= POST_RUN_LOCKOUT_MS &&
      switchPrev == HIGH &&
      switchNow == SWITCH_PRESSED)
  {
    delay(DEBOUNCE_MS);

    if (digitalRead(PRESS_SWITCH_PIN) == SWITCH_PRESSED)
    {
      switchArmed = false;
      startPumpRun();
    }
  }

  switchPrev = switchNow;
}

void servicePump(unsigned long nowMicros)
{
  if (machineState != RUN_PUMP)
    return;

  if (pumpStepsDone < config.steps)
  {
    if (nowMicros - lastPumpPulse >= config.speedUs)
    {
      pulseStep(STEP_PUMP);
      lastPumpPulse = nowMicros;
      pumpStepsDone++;
    }
  }
  else
  {
    finishPumpRun();
  }
}

void handleCommand(String line)
{
  line.trim();
  line.toUpperCase();

  if (line.length() == 0)
    return;

  if (line == "PING")
  {
    Serial.println("PONG UNO_PUMP");
    return;
  }

  if (line == "GET")
  {
    printStatus();
    return;
  }

  if (line == "RUN")
  {
    startPumpRun();
    return;
  }

  if (line.startsWith("RUN "))
  {
    long stepsValue = 0;
    unsigned long speedValue = 0;

    int parsed = sscanf(line.c_str(), "RUN %ld %lu", &stepsValue, &speedValue);

    if (parsed != 2)
    {
      Serial.println("ERR RUN FORMAT");
      return;
    }

    if (!validSteps(stepsValue))
    {
      Serial.println("ERR STEPS RANGE");
      return;
    }

    if (!validSpeed(speedValue))
    {
      Serial.println("ERR SPEED RANGE");
      return;
    }

    config.steps = stepsValue;
    config.speedUs = speedValue;
    saveConfig();
    printStatus();
    startPumpRun();
    return;
  }

  if (line == "STOP")
  {
    stopPumpRun();
    return;
  }

  if (line.startsWith("SET STEPS "))
  {
    long value = line.substring(10).toInt();

    if (!validSteps(value))
    {
      Serial.println("ERR STEPS RANGE");
      return;
    }

    config.steps = value;
    saveConfig();
    Serial.println("OK STEPS");
    printStatus();
    return;
  }

  if (line.startsWith("SET SPEED "))
  {
    unsigned long value = (unsigned long)line.substring(10).toInt();

    if (!validSpeed(value))
    {
      Serial.println("ERR SPEED RANGE");
      return;
    }

    config.speedUs = value;
    saveConfig();
    Serial.println("OK SPEED");
    printStatus();
    return;
  }

  Serial.println("ERR UNKNOWN CMD");
}

void serviceSerial()
{
  while (Serial.available())
  {
    char c = (char)Serial.read();

    if (c == '\r')
      continue;

    if (c == '\n')
    {
      handleCommand(serialLine);
      serialLine = "";
      continue;
    }

    if (serialLine.length() < 60)
      serialLine += c;
  }
}

void setup()
{
  Serial.begin(115200);

  pinMode(STEP_PUMP, OUTPUT);
  pinMode(DIR_PUMP, OUTPUT);
  pinMode(ENA_PUMP, OUTPUT);
  pinMode(PRESS_SWITCH_PIN, INPUT_PULLUP);

  digitalWrite(STEP_PUMP, STEP_IDLE_LEVEL);
  digitalWrite(DIR_PUMP, PUMP_DIR_CW);

  enablePumpDriver();
  loadConfig();

  switchPrev = digitalRead(PRESS_SWITCH_PIN);
  switchArmed = (switchPrev == HIGH);
  runEndedAt = millis();

  Serial.println("");
  Serial.println("UNO_PUMP READY");
  printStatus();
}

void loop()
{
  unsigned long nowMicros = micros();
  unsigned long nowMs = millis();

  serviceSerial();
  handlePressSwitch(nowMs);
  servicePump(nowMicros);
}
