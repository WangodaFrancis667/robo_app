/**********************************************************************
 *  system_status.h - System Status and Safety Management
 *  Handles system monitoring, status reporting, and safety functions
 *********************************************************************/

#ifndef SYSTEM_STATUS_H
#define SYSTEM_STATUS_H

#include "config.h"

class SystemStatus {
private:
  static SystemState state;
  static unsigned long lastStatusUpdate;
  static unsigned long lastHeartbeat;
  static bool statusLedState;
  static unsigned long lastLedToggle;

  // Safety monitoring
  static bool emergencyStopPressed;
  static unsigned long emergencyStopTime;

  // Performance monitoring
  static unsigned long loopCount;
  static unsigned long lastLoopCountReset;
  static int averageLoopTime;

public:
  // Initialize system status
  static void init();

  // Update - call this in main loop
  static void update();

  // Status LED control
  static void updateStatusLED();
  static void setStatusLED(bool state);
  static void blinkStatusLED(int count = 3);

  // System state management
  static void setReady(bool ready);
  static bool isReady();
  static void setEmergencyStop(bool active);
  static bool isEmergencyStopActive();
  static void setDebugMode(bool enabled);
  static bool isDebugModeEnabled();

  // Command timeout management
  static void updateLastCommand();
  static bool isCommandTimeout();
  static unsigned long getTimeSinceLastCommand();

  // System information
  static void getStatus(String &statusString);
  static void getStatus(char *buffer, size_t bufferSize);
  static void getDetailedStatus();
  static unsigned long getUptime();
  static int getFreeMemory();
  static float getLoopFrequency();

  // Safety functions
  static void checkEmergencyButton();
  static void performSafetyCheck();
  static void resetSystem();

  // Performance monitoring
  static void updatePerformanceMetrics();
  static void getPerformanceReport(String &report);

  // Watchdog functions
  static void feedWatchdog();
  static bool isSystemHealthy();

  // Error handling
  static void reportError(const String &errorMessage);
  static void reportWarning(const String &warningMessage);
};

// Implementation
SystemState SystemStatus::state = {false, 0, 0, false, 60, DEBUG_ENABLED};
unsigned long SystemStatus::lastStatusUpdate = 0;
unsigned long SystemStatus::lastHeartbeat = 0;
bool SystemStatus::statusLedState = false;
unsigned long SystemStatus::lastLedToggle = 0;
bool SystemStatus::emergencyStopPressed = false;
unsigned long SystemStatus::emergencyStopTime = 0;
unsigned long SystemStatus::loopCount = 0;
unsigned long SystemStatus::lastLoopCountReset = 0;
int SystemStatus::averageLoopTime = 0;

void SystemStatus::init() {
  DEBUG_PRINTLN("🔧 Initializing System Status...");

  // Initialize status LED
  pinMode(STATUS_LED, OUTPUT);
  setStatusLED(false);

// Initialize emergency stop button (if available)
#ifdef EMERGENCY_STOP_PIN
  pinMode(EMERGENCY_STOP_PIN, INPUT_PULLUP);
#endif

  // Initialize system state
  state.isReady = false;
  state.startTime = millis();
  state.lastCommand = 0;
  state.emergencyStop = false;
  state.globalSpeedMultiplier = 60;
  state.debugMode = DEBUG_ENABLED;

  // Reset timers
  lastStatusUpdate = millis();
  lastHeartbeat = millis();
  lastLedToggle = millis();
  lastLoopCountReset = millis();

  DEBUG_PRINTLN("✅ System Status initialized");
}

void SystemStatus::update() {
  unsigned long currentTime = millis();

  // Update status LED
  updateStatusLED();

  // Check emergency button
  checkEmergencyButton();

  // Perform safety checks
  if (currentTime - lastStatusUpdate > 1000) { // Every second
    performSafetyCheck();
    lastStatusUpdate = currentTime;
  }

  // Update performance metrics
  updatePerformanceMetrics();

  // Feed watchdog
  feedWatchdog();

  loopCount++;
}

void SystemStatus::updateStatusLED() {
  unsigned long currentTime = millis();

  if (state.emergencyStop) {
    // Fast blink for emergency
    if (currentTime - lastLedToggle > 100) {
      statusLedState = !statusLedState;
      digitalWrite(STATUS_LED, statusLedState);
      lastLedToggle = currentTime;
    }
  } else if (!state.isReady) {
    // Slow blink for not ready
    if (currentTime - lastLedToggle > 500) {
      statusLedState = !statusLedState;
      digitalWrite(STATUS_LED, statusLedState);
      lastLedToggle = currentTime;
    }
  } else {
    // Steady on for normal operation
    if (currentTime - lastLedToggle > 2000) {
      statusLedState = !statusLedState;
      digitalWrite(STATUS_LED, statusLedState);
      lastLedToggle = currentTime;
    }
  }
}

void SystemStatus::setStatusLED(bool ledState) {
  statusLedState = ledState;
  digitalWrite(STATUS_LED, ledState);
}

void SystemStatus::blinkStatusLED(int count) {
  for (int i = 0; i < count; i++) {
    setStatusLED(true);
    delay(200);
    setStatusLED(false);
    delay(200);
  }
}

void SystemStatus::setReady(bool ready) {
  state.isReady = ready;
  DEBUG_PRINTLN("🚦 System ready state: " +
                String(ready ? "READY" : "NOT READY"));
}

bool SystemStatus::isReady() { return state.isReady; }

void SystemStatus::setEmergencyStop(bool active) {
  state.emergencyStop = active;
  emergencyStopTime = millis();

  if (active) {
    DEBUG_PRINTLN("🚨 EMERGENCY STOP ACTIVATED");
    blinkStatusLED(5);
  } else {
    DEBUG_PRINTLN("✅ Emergency stop cleared");
  }
}

bool SystemStatus::isEmergencyStopActive() { return state.emergencyStop; }

void SystemStatus::setDebugMode(bool enabled) {
  state.debugMode = enabled;
  DEBUG_PRINTLN("🔍 Debug mode: " + String(enabled ? "ENABLED" : "DISABLED"));
}

bool SystemStatus::isDebugModeEnabled() { return state.debugMode; }

void SystemStatus::updateLastCommand() { state.lastCommand = millis(); }

bool SystemStatus::isCommandTimeout() {
  if (state.lastCommand == 0)
    return false;
  return (millis() - state.lastCommand) > COMMAND_TIMEOUT;
}

unsigned long SystemStatus::getTimeSinceLastCommand() {
  if (state.lastCommand == 0)
    return 0;
  return millis() - state.lastCommand;
}

void SystemStatus::getStatus(String &statusString) {
  statusString = "Uptime: " + String(getUptime()) + "ms";
  statusString += " | Ready: " + String(state.isReady ? "YES" : "NO");
  statusString +=
      " | Emergency: " + String(state.emergencyStop ? "ACTIVE" : "OK");
  statusString += " | Memory: " + String(getFreeMemory()) + " bytes";
  statusString += " | Loop: " + String(getLoopFrequency(), 1) + "Hz";
}

void SystemStatus::getStatus(char *buffer, size_t bufferSize) {
  char freqStr[8];
  formatFloat(getLoopFrequency(), freqStr, sizeof(freqStr), 1);

  snprintf_P(buffer, bufferSize,
             PSTR("Uptime:%lu|Ready:%s|Emergency:%s|Memory:%d|Loop:%sHz"),
             getUptime(), state.isReady ? "YES" : "NO",
             state.emergencyStop ? "ACTIVE" : "OK", getFreeMemory(), freqStr);
}

void SystemStatus::getDetailedStatus() {
  DEBUG_PRINTLN("📊 === DETAILED SYSTEM STATUS ===");
  DEBUG_PRINTLN("⏱ Uptime: " + String(getUptime()) + " ms");
  DEBUG_PRINTLN("🔋 Free Memory: " + String(getFreeMemory()) + " bytes");
  DEBUG_PRINTLN("🔄 Loop Frequency: " + String(getLoopFrequency(), 1) + " Hz");
  DEBUG_PRINTLN("🚦 System Ready: " + String(state.isReady ? "YES" : "NO"));
  DEBUG_PRINTLN("🚨 Emergency Stop: " +
                String(state.emergencyStop ? "ACTIVE" : "OK"));
  DEBUG_PRINTLN("🔍 Debug Mode: " + String(state.debugMode ? "ON" : "OFF"));
  DEBUG_PRINTLN("⚡ Global Speed: " + String(state.globalSpeedMultiplier) +
                "%");
  DEBUG_PRINTLN("📡 Last Command: " + String(getTimeSinceLastCommand()) +
                " ms ago");
  DEBUG_PRINTLN("📊 === END STATUS ===");
}

unsigned long SystemStatus::getUptime() { return millis() - state.startTime; }

int SystemStatus::getFreeMemory() {
  char top;
  extern char *__brkval;
  extern char __bss_end;
  return __brkval ? &top - __brkval : &top - &__bss_end;
}

float SystemStatus::getLoopFrequency() {
  unsigned long currentTime = millis();
  unsigned long elapsed = currentTime - lastLoopCountReset;

  if (elapsed > 1000) { // Calculate every second
    float frequency = (float)loopCount / (elapsed / 1000.0);
    loopCount = 0;
    lastLoopCountReset = currentTime;
    return frequency;
  }

  return 0.0; // Not ready yet
}

void SystemStatus::checkEmergencyButton() {
#ifdef EMERGENCY_STOP_PIN
  bool buttonPressed = !digitalRead(EMERGENCY_STOP_PIN); // Active low

  if (buttonPressed && !emergencyStopPressed) {
    // Button just pressed
    emergencyStopPressed = true;
    setEmergencyStop(true);
    reportError("Emergency button pressed");
  } else if (!buttonPressed && emergencyStopPressed) {
    // Button released
    emergencyStopPressed = false;
    // Don't automatically clear emergency stop - require manual reset
  }
#endif
}

void SystemStatus::performSafetyCheck() {
  // Check memory levels
  int freeMemory = getFreeMemory();
  if (freeMemory < 500) {
    reportWarning("Low memory: " + String(freeMemory) + " bytes");
  }

  // Check loop frequency
  float loopFreq = getLoopFrequency();
  if (loopFreq > 0 && loopFreq < 50) {
    reportWarning("Low loop frequency: " + String(loopFreq, 1) + " Hz");
  }

  // Check for system hangs
  static unsigned long lastSafetyCheck = 0;
  unsigned long timeSinceLastCheck = millis() - lastSafetyCheck;
  if (lastSafetyCheck != 0 && timeSinceLastCheck > 5000) {
    reportError("System hang detected");
  }
  lastSafetyCheck = millis();
}

void SystemStatus::resetSystem() {
  DEBUG_PRINTLN("🔄 Resetting system...");

  // Clear emergency stop
  setEmergencyStop(false);

  // Reset command timeout
  state.lastCommand = 0;

  // Reset performance counters
  loopCount = 0;
  lastLoopCountReset = millis();

  // Blink LED to indicate reset
  blinkStatusLED(3);

  DEBUG_PRINTLN("✅ System reset complete");
}

void SystemStatus::updatePerformanceMetrics() {
  static unsigned long lastUpdate = 0;
  static unsigned long lastLoopTime = 0;

  unsigned long currentTime = millis();

  // Calculate average loop time
  if (lastLoopTime != 0) {
    unsigned long loopTime = currentTime - lastLoopTime;
    averageLoopTime = (averageLoopTime + loopTime) / 2;
  }
  lastLoopTime = currentTime;
}

void SystemStatus::getPerformanceReport(String &report) {
  report = "Performance Report:\n";
  report += "  Loop Frequency: " + String(getLoopFrequency(), 1) + " Hz\n";
  report += "  Average Loop Time: " + String(averageLoopTime) + " ms\n";
  report += "  Free Memory: " + String(getFreeMemory()) + " bytes\n";
  report += "  Uptime: " + String(getUptime()) + " ms\n";
}

void SystemStatus::feedWatchdog() {
  // Simple watchdog implementation
  lastHeartbeat = millis();
}

bool SystemStatus::isSystemHealthy() {
  // Check if system is responding
  if (millis() - lastHeartbeat > 10000) {
    return false; // No heartbeat for 10 seconds
  }

  // Check memory
  if (getFreeMemory() < 200) {
    return false; // Critical memory shortage
  }

  // Check if emergency stop is active
  if (state.emergencyStop) {
    return false;
  }

  return true;
}

void SystemStatus::reportError(const String &errorMessage) {
  DEBUG_PRINTLN("❌ ERROR: " + errorMessage);

  // Blink LED rapidly to indicate error
  for (int i = 0; i < 10; i++) {
    setStatusLED(true);
    delay(50);
    setStatusLED(false);
    delay(50);
  }

  // Send error via Bluetooth if available
  // BluetoothHandler::sendMessage("ERROR:" + errorMessage);
}

void SystemStatus::reportWarning(const String &warningMessage) {
  DEBUG_PRINTLN("⚠ WARNING: " + warningMessage);

  // Single long blink for warning
  setStatusLED(true);
  delay(500);
  setStatusLED(false);

  // Send warning via Bluetooth if available
  // BluetoothHandler::sendMessage("WARNING:" + warningMessage);
}

#endif // SYSTEM_STATUS_H