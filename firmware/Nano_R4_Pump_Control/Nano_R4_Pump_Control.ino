// =====================================================
// NANO R4 PUMP CONTROL STATION + WINDOWS SERIAL APP
//
// CL42T COMMON ANODE 5V WIRING:
// PUL+ / DIR+ -> regulated +5V
// PUL- -> STEP_PUMP
// DIR- -> DIR_PUMP
// ENA is optional. Leave ENA disconnected first for testing.
// If ENA is used: ENA+ -> +5V, ENA- -> ENA_PUMP
//
// PRESS SWITCH:
// One side to PRESS_SWITCH_PIN, the other side to GND.
// Uses INPUT_PULLUP, so pressed = LOW.
// =====================================================

#include <Arduino.h>

#if __has_include(<EEPROM.h>)
#include <EEPROM.h>
#define HAS_EEPROM 1
#else
#define HAS_EEPROM 0
#endif

#define FW_VERSION "V3-1 Nano R4 Peristaltic filling by G.C."

// ---------------- PIN MAP ----------------
#define STEP_PUMP A5
#define DIR_PUMP  2
#define ENA_PUMP  A1

#define PRESS_SWITCH_PIN A2

// ---------------- LIMITS / DEFAULTS ----------------
const long DEFAULT_PUMP_STEPS = 32000;
const long PURGE_STEPS = 15000;
const unsigned long DEFAULT_PUMP_SPEED_US = 210;

const long MIN_PUMP_STEPS = 10;
const long MAX_PUMP_STEPS = 50000;

const unsigned long MIN_PUMP_SPEED_US = 210;
const unsigned long MAX_PUMP_SPEED_US = 5000;

// ---------------- STEPPER DRIVER LOGIC ----------------
// Common anode: PUL+ / DIR+ to regulated +5V.
// The Nano R4 controls the negative side of each CL42T input.
// STEP is active when PUL- is pulled LOW.
#define STEP_IDLE_LEVEL HIGH
#define STEP_ACTIVE_LEVEL LOW

// ENA optional:
// With ENA+ tied to +5V, keeping ENA- HIGH leaves ENA inactive.
// Many CL42T drivers are enabled by default when ENA is inactive.
#define DRIVER_ENABLE_LEVEL HIGH
#define DRIVER_DISABLE_LEVEL LOW

// If pump turns the wrong way, change this to LOW.
#define PUMP_DIR_CW HIGH

// ---------------- INPUT LOGIC ----------------
#define SWITCH_PRESSED LOW

// ---------------- TIMING ----------------
const unsigned long DEBOUNCE_MS = 50;
const unsigned long POST_RUN_LOCKOUT_MS = 500;
const unsigned long PURGE_HOLD_MS = 3000;
const unsigned long SWITCH_ARM_RELEASE_MS = 1000;
const unsigned long SWITCH_MIN_PRESS_MS = 100;

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
long activeRunSteps = DEFAULT_PUMP_STEPS;
unsigned long lastPumpPulse = 0;
unsigned long runEndedAt = 0;

bool switchPrev = HIGH;
bool switchArmed = false;
bool switchPressActive = false;
bool switchLastRaw = HIGH;
unsigned long switchPressedAt = 0;
unsigned long switchLastRawChangeAt = 0;

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
#if HAS_EEPROM
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
#else
  config.magic = CONFIG_MAGIC;
  config.steps = DEFAULT_PUMP_STEPS;
  config.speedUs = DEFAULT_PUMP_SPEED_US;
#endif
}

void saveConfig()
{
  config.magic = CONFIG_MAGIC;
#if HAS_EEPROM
  EEPROM.put(EEPROM_ADDR, config);
#endif
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
  delayMicroseconds(100);
  digitalWrite(pin, STEP_IDLE_LEVEL);
  delayMicroseconds(10);
}

void startPumpRun()
{
  activeRunSteps = config.steps;

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

void startPumpRunFixed(long fixedSteps)
{
  if (machineState != IDLE)
  {
    Serial.println("ERR BUSY");
    return;
  }

  enablePumpDriver();
  activeRunSteps = fixedSteps;
  pumpStepsDone = 0;
  lastPumpPulse = micros();
  digitalWrite(DIR_PUMP, PUMP_DIR_CW);
  machineState = RUN_PUMP;

  Serial.print("PURGE START STEPS=");
  Serial.println(activeRunSteps);
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
  Serial.println("RUN COMPLETE");
}

void handlePressSwitch(unsigned long nowMs)
{
  bool rawSwitch = digitalRead(PRESS_SWITCH_PIN);

  if (rawSwitch != switchLastRaw)
  {
    switchLastRaw = rawSwitch;
    switchLastRawChangeAt = nowMs;
    return;
  }

  if ((nowMs - switchLastRawChangeAt) < DEBOUNCE_MS)
    return;

  bool switchNow = rawSwitch;

  if (machineState != IDLE ||
      (nowMs - runEndedAt) < POST_RUN_LOCKOUT_MS)
  {
    switchPrev = switchNow;
    return;
  }

  if (!switchArmed)
  {
    if (switchNow == HIGH &&
        (nowMs - switchLastRawChangeAt) >= SWITCH_ARM_RELEASE_MS)
    {
      switchArmed = true;
      Serial.println("SWITCH READY");
    }

    switchPrev = switchNow;
    return;
  }

  if (!switchPressActive &&
      switchPrev == HIGH &&
      switchNow == SWITCH_PRESSED)
  {
    switchPressActive = true;
    switchPressedAt = nowMs;
    Serial.println("SWITCH PRESSED");
  }

  if (switchPressActive &&
      switchPrev == SWITCH_PRESSED &&
      switchNow == HIGH)
  {
    unsigned long heldMs = nowMs - switchPressedAt;

    switchPressActive = false;
    switchArmed = false;

    if (heldMs < SWITCH_MIN_PRESS_MS)
    {
      Serial.println("SWITCH IGNORED");
    }
    else if (heldMs >= PURGE_HOLD_MS)
    {
      Serial.println("SWITCH LONG PRESS - PURGE");
      startPumpRunFixed(PURGE_STEPS);
    }
    else
    {
      Serial.println("SWITCH SHORT PRESS - RUN");
      startPumpRun();
    }
  }

  switchPrev = switchNow;
}

void servicePump(unsigned long nowMicros)
{
  if (machineState != RUN_PUMP)
    return;

  if (pumpStepsDone < activeRunSteps)
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
    Serial.println("PONG NANO_R4_PUMP");
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

  if (line == "PURGE")
  {
    startPumpRunFixed(PURGE_STEPS);
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

    if (serialLine.length() < 80)
      serialLine += c;
  }
}

void setup()
{
  Serial.begin(115200);
  delay(500);

  pinMode(STEP_PUMP, OUTPUT);
  pinMode(DIR_PUMP, OUTPUT);
  pinMode(ENA_PUMP, OUTPUT);
  pinMode(PRESS_SWITCH_PIN, INPUT_PULLUP);

  digitalWrite(STEP_PUMP, STEP_IDLE_LEVEL);
  digitalWrite(DIR_PUMP, PUMP_DIR_CW);
  enablePumpDriver();

  loadConfig();

  switchPrev = digitalRead(PRESS_SWITCH_PIN);
  switchLastRaw = switchPrev;
  switchLastRawChangeAt = millis();
  switchArmed = false;
  switchPressActive = false;
  runEndedAt = millis();

  Serial.println("");
  Serial.println("NANO_R4_PUMP READY");
  Serial.println(FW_VERSION);
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
