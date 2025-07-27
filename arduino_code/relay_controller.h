/**********************************************************************
 *  relay_controller.h - Power Relay Control System
 *  Controls JOC-3FF-S-Z relay for automatic power cutoff
 *********************************************************************/

#ifndef RELAY_CONTROLLER_H
#define RELAY_CONTROLLER_H

#include "config.h"
#include <Arduino.h>

class RelayController {
private:
  static bool relayState;          // Current relay state (true = power ON, false = power OFF)
  static unsigned long lastToggle; // Last toggle timestamp for debouncing
  static bool initialized;         // Initialization flag

public:
  // Initialize relay controller
  static void init() {
    if (!initialized) {
      pinMode(POWER_RELAY_PIN, OUTPUT);
      powerOn(); // Start with power ON
      initialized = true;
      lastToggle = millis();
      
      #if DEBUG_ENABLED
      Serial.println(F("🔌 Relay Controller initialized - Power ON"));
      #endif
    }
  }

  // Power control methods
  static void powerOn() {
    if (millis() - lastToggle > 100) { // 100ms debounce
      digitalWrite(POWER_RELAY_PIN, HIGH); // Relay activated = power ON
      relayState = true;
      lastToggle = millis();
      
      #if DEBUG_ENABLED
      Serial.println(F("🟢 Power RELAY ON"));
      #endif
    }
  }

  static void powerOff() {
    if (millis() - lastToggle > 100) { // 100ms debounce
      digitalWrite(POWER_RELAY_PIN, LOW); // Relay deactivated = power OFF
      relayState = false;
      lastToggle = millis();
      
      #if DEBUG_ENABLED
      Serial.println(F("🔴 Power RELAY OFF"));
      #endif
    }
  }

  static void toggle() {
    if (relayState) {
      powerOff();
    } else {
      powerOn();
    }
  }

  // Status methods
  static bool isPowerOn() {
    return relayState;
  }

  static bool isPowerOff() {
    return !relayState;
  }

  static void getStatus(char *buffer, size_t bufferSize) {
    snprintf(buffer, bufferSize, "RELAY_STATUS:%s", relayState ? "ON" : "OFF");
  }

  // Emergency power off
  static void emergencyPowerOff() {
    digitalWrite(POWER_RELAY_PIN, LOW); // Immediate power off
    relayState = false;
    lastToggle = millis();
    
    #if DEBUG_ENABLED
    Serial.println(F("🚨 EMERGENCY POWER OFF"));
    #endif
  }

  // Update method (for any periodic tasks if needed)
  static void update() {
    // No periodic tasks needed for relay
  }
};

// Static variable definitions
bool RelayController::relayState = true;
unsigned long RelayController::lastToggle = 0;
bool RelayController::initialized = false;

#endif // RELAY_CONTROLLER_H
