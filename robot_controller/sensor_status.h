/**********************************************************************
 *  sensor_status.h - Sensor Status Manager for Flutter App
 *  Manages and formats sensor data for transmission to Flutter application
 *********************************************************************/

#ifndef SENSOR_STATUS_H
#define SENSOR_STATUS_H

#include "collision_avoidance.h"
#include "config.h"
#include "memory_optimization.h"
#include "sensor_manager.h"

// Forward declaration to avoid circular dependency
extern void sendBluetoothMessage(const char *message);

class SensorStatusManager {
private:
  static SensorStatus currentStatus;
  static unsigned long lastStatusUpdate;
  static unsigned long lastStatusSent;
  static bool autoSendEnabled;
  static int statusUpdateInterval;
  static int statusSendInterval;

  // Private helper methods
  static void updateCurrentStatus();
  static String formatStatusForFlutter();
  static String formatDetailedStatus();
  static void sendStatusUpdate();

public:
  // Initialize sensor status manager
  static void init();

  // Update - call this in main loop
  static void update();

  // Status management
  static void enableAutoSend();
  static void disableAutoSend();
  static bool isAutoSendEnabled();

  // Manual status requests
  static void sendStatusNow();
  static void sendDetailedStatus();
  static void getStatusBuffer(char *buffer, size_t bufferSize);
  static void getDetailedStatusBuffer(char *buffer, size_t bufferSize);

  // Configuration
  static void setUpdateInterval(int intervalMs);
  static void setSendInterval(int intervalMs);
  static int getUpdateInterval();
  static int getSendInterval();

  // Status data access
  static SensorStatus getCurrentStatus();
  static float getFrontDistance();
  static float getRearDistance();
  static bool hasObstacles();
  static bool hasCollisionRisk();

  // Flutter app specific formatting
  static void formatForFlutterDashboard(char *buffer, size_t bufferSize);
  static void formatCollisionWarning(const char *sensor, float distance,
                                     char *buffer, size_t bufferSize);
  static void formatSensorHealthCheck(char *buffer, size_t bufferSize);

  // Diagnostics
  static void sendDiagnosticData();
  static void testSensorCommunication();
};

// Implementation
SensorStatus SensorStatusManager::currentStatus = {0.0,   0.0,   false, false,
                                                   false, false, false, 0};
unsigned long SensorStatusManager::lastStatusUpdate = 0;
unsigned long SensorStatusManager::lastStatusSent = 0;
bool SensorStatusManager::autoSendEnabled = true;
int SensorStatusManager::statusUpdateInterval = 100; // Update every 100ms
int SensorStatusManager::statusSendInterval = 500;   // Send every 500ms

void SensorStatusManager::init() {
  DEBUG_PRINTLN_P("Initializing Sensor Status Manager...");

  // Initialize status structure
  currentStatus.frontDistance = 0.0;
  currentStatus.rearDistance = 0.0;
  currentStatus.frontObstacle = false;
  currentStatus.rearObstacle = false;
  currentStatus.frontCollisionRisk = false;
  currentStatus.rearCollisionRisk = false;
  currentStatus.sensorsActive = true;
  currentStatus.lastUpdate = millis();

  lastStatusUpdate = millis();
  lastStatusSent = millis();

#if SERIAL_TESTING_MODE
  autoSendEnabled = false; // Disable auto-send in testing mode to reduce spam
#else
  autoSendEnabled = true;
#endif

  // Use the intervals defined in config.h
  statusUpdateInterval = 100;
  statusSendInterval = STATUS_SEND_INTERVAL;

  DEBUG_PRINTLN_P("Sensor Status Manager initialized");
}

void SensorStatusManager::update() {
  unsigned long currentTime = millis();

  // Update status at specified interval
  if (currentTime - lastStatusUpdate >= statusUpdateInterval) {
    updateCurrentStatus();
    lastStatusUpdate = currentTime;
  }

  // Send status updates if auto-send is enabled
  if (autoSendEnabled && (currentTime - lastStatusSent >= statusSendInterval)) {
    sendStatusUpdate();
    lastStatusSent = currentTime;
  }
}

void SensorStatusManager::updateCurrentStatus() {
  SensorManager::getSensorStatus(currentStatus);

  // Add collision avoidance status
  if (!CollisionAvoidance::isEnabled()) {
    currentStatus.frontCollisionRisk = false;
    currentStatus.rearCollisionRisk = false;
  }
}

void SensorStatusManager::enableAutoSend() {
  autoSendEnabled = true;
  DEBUG_PRINTLN("📊 Auto-send status updates ENABLED");
}

void SensorStatusManager::disableAutoSend() {
  autoSendEnabled = false;
  DEBUG_PRINTLN("📊 Auto-send status updates DISABLED");
}

bool SensorStatusManager::isAutoSendEnabled() { return autoSendEnabled; }

void SensorStatusManager::sendStatusNow() {
  updateCurrentStatus();
  sendStatusUpdate();
}

void SensorStatusManager::sendDetailedStatus() {
  updateCurrentStatus();

  if (MessageBuffer::isAvailable()) {
    char *buffer = MessageBuffer::getBuffer();
    getDetailedStatusBuffer(buffer, MAX_MESSAGE_LENGTH);

    TempString<MAX_MESSAGE_LENGTH + 50>
        message; // Extra buffer for "SENSOR_DETAILED:" prefix
    message.printf_P(PSTR("SENSOR_DETAILED:%s"), buffer);

    sendBluetoothMessage(message.get());
    MessageBuffer::releaseBuffer();
  }
}

void SensorStatusManager::sendStatusUpdate() {
  if (MessageBuffer::isAvailable()) {
    char *buffer = MessageBuffer::getBuffer();
    getStatusBuffer(buffer, MAX_MESSAGE_LENGTH);

    TempString<MAX_MESSAGE_LENGTH + 50>
        message; // Extra buffer for "SENSOR_STATUS:" prefix
    message.printf_P(PSTR("SENSOR_STATUS:%s"), buffer);

    sendBluetoothMessage(message.get());
    MessageBuffer::releaseBuffer();
  }
}

void SensorStatusManager::getStatusBuffer(char *buffer, size_t bufferSize) {
  char frontStr[8], rearStr[8];
  formatFloat(currentStatus.frontDistance, frontStr, sizeof(frontStr), 1);
  formatFloat(currentStatus.rearDistance, rearStr, sizeof(rearStr), 1);

  snprintf_P(buffer, bufferSize,
             PSTR("{\"f\":%s,\"r\":%s,\"fo\":%s,\"ro\":%s,\"fr\":%s,\"rr\":%s,"
                  "\"a\":%s,\"t\":%lu}"),
             frontStr, rearStr, currentStatus.frontObstacle ? "1" : "0",
             currentStatus.rearObstacle ? "1" : "0",
             currentStatus.frontCollisionRisk ? "1" : "0",
             currentStatus.rearCollisionRisk ? "1" : "0",
             currentStatus.sensorsActive ? "1" : "0", currentStatus.lastUpdate);
}

void SensorStatusManager::getDetailedStatusBuffer(char *buffer,
                                                  size_t bufferSize) {
  char frontStr[8], rearStr[8];
  formatFloat(currentStatus.frontDistance, frontStr, sizeof(frontStr), 1);
  formatFloat(currentStatus.rearDistance, rearStr, sizeof(rearStr), 1);

  // Simplified detailed status to fit in buffer
  snprintf_P(
      buffer, bufferSize,
      PSTR("{\"sensors\":{\"front\":{\"dist\":%s,\"obs\":%s,\"risk\":%s},"
           "\"rear\":{\"dist\":%s,\"obs\":%s,\"risk\":%s},\"active\":%s}}"),
      frontStr, currentStatus.frontObstacle ? "true" : "false",
      currentStatus.frontCollisionRisk ? "true" : "false", rearStr,
      currentStatus.rearObstacle ? "true" : "false",
      currentStatus.rearCollisionRisk ? "true" : "false",
      currentStatus.sensorsActive ? "true" : "false");
}

void SensorStatusManager::formatForFlutterDashboard(char *buffer,
                                                    size_t bufferSize) {
  char frontStr[8], rearStr[8];
  formatFloat(currentStatus.frontDistance, frontStr, sizeof(frontStr), 0);
  formatFloat(currentStatus.rearDistance, rearStr, sizeof(rearStr), 0);

  const char *status;
  if (currentStatus.frontCollisionRisk || currentStatus.rearCollisionRisk) {
    status = "COLLISION_RISK";
  } else if (currentStatus.frontObstacle || currentStatus.rearObstacle) {
    status = "OBSTACLES";
  } else {
    status = "CLEAR";
  }

  snprintf_P(buffer, bufferSize, PSTR("DASHBOARD_SENSORS:F=%scm,R=%scm,%s"),
             frontStr, rearStr, status);
}

void SensorStatusManager::formatCollisionWarning(const char *sensor,
                                                 float distance, char *buffer,
                                                 size_t bufferSize) {
  // This function is now implemented in memory_optimization.h
  ::formatCollisionMessage(sensor, distance, buffer, bufferSize);
}

void SensorStatusManager::formatSensorHealthCheck(char *buffer,
                                                  size_t bufferSize) {
  snprintf_P(
      buffer, bufferSize,
      PSTR("SENSOR_HEALTH:{\"frontActive\":%s,\"rearActive\":%s,"
           "\"systemHealthy\":%s,\"collisionAvoidance\":%s,\"timestamp\":%lu}"),
      SensorManager::areSensorsEnabled() ? "true" : "false",
      SensorManager::areSensorsEnabled() ? "true" : "false",
      SensorManager::areSensorsHealthy() ? "true" : "false",
      CollisionAvoidance::isEnabled() ? "true" : "false", millis());
}

void SensorStatusManager::setUpdateInterval(int intervalMs) {
  statusUpdateInterval = constrain(intervalMs, 50, 2000);
  DEBUG_PRINT_P("📊 Status update interval set to ");
  DEBUG_PRINT_VAL("", statusUpdateInterval);
  DEBUG_PRINTLN_P("ms");
}

void SensorStatusManager::setSendInterval(int intervalMs) {
  statusSendInterval = constrain(intervalMs, 100, 5000);
  DEBUG_PRINTLN("📊 Status send interval set to " + String(statusSendInterval) +
                "ms");
}

int SensorStatusManager::getUpdateInterval() { return statusUpdateInterval; }

int SensorStatusManager::getSendInterval() { return statusSendInterval; }

SensorStatus SensorStatusManager::getCurrentStatus() { return currentStatus; }

float SensorStatusManager::getFrontDistance() {
  return currentStatus.frontDistance;
}

float SensorStatusManager::getRearDistance() {
  return currentStatus.rearDistance;
}

bool SensorStatusManager::hasObstacles() {
  return currentStatus.frontObstacle || currentStatus.rearObstacle;
}

bool SensorStatusManager::hasCollisionRisk() {
  return currentStatus.frontCollisionRisk || currentStatus.rearCollisionRisk;
}

void SensorStatusManager::sendDiagnosticData() {
  DEBUG_PRINTLN_P("📊 Sending diagnostic data...");

  // Send sensor readings using buffer
  if (MessageBuffer::isAvailable()) {
    char *buffer = MessageBuffer::getBuffer();
    getDetailedStatusBuffer(buffer, MAX_MESSAGE_LENGTH);

    TempString<MAX_MESSAGE_LENGTH + 30> message;
    message.printf_P(PSTR("DIAGNOSTIC_SENSORS:%s"), buffer);
    sendBluetoothMessage(message.get());
    MessageBuffer::releaseBuffer();
  }

  // Send collision avoidance status using buffer
  if (MessageBuffer::isAvailable()) {
    char *buffer = MessageBuffer::getBuffer();
    CollisionAvoidance::getStatus(buffer, MAX_MESSAGE_LENGTH);

    TempString<MAX_MESSAGE_LENGTH + 30> message;
    message.printf_P(PSTR("DIAGNOSTIC_COLLISION:%s"), buffer);
    sendBluetoothMessage(message.get());
    MessageBuffer::releaseBuffer();
  }

  // Send sensor health using buffer
  if (MessageBuffer::isAvailable()) {
    char *buffer = MessageBuffer::getBuffer();
    formatSensorHealthCheck(buffer, MAX_MESSAGE_LENGTH);

    TempString<MAX_MESSAGE_LENGTH + 30> message;
    message.printf_P(PSTR("DIAGNOSTIC_HEALTH:%s"), buffer);
    sendBluetoothMessage(message.get());
    MessageBuffer::releaseBuffer();
  }

  DEBUG_PRINTLN_P("✅ Diagnostic data sent");
}

void SensorStatusManager::testSensorCommunication() {
  DEBUG_PRINTLN_P("🧪 Testing sensor communication...");

  // Send test message
  sendBluetoothMessage("SENSOR_TEST_START");

  // Send multiple status updates
  for (int i = 0; i < 5; i++) {
    updateCurrentStatus();

    if (MessageBuffer::isAvailable()) {
      char *buffer = MessageBuffer::getBuffer();
      getStatusBuffer(buffer, MAX_MESSAGE_LENGTH);

      TempString<MAX_MESSAGE_LENGTH + 30> message;
      message.printf_P(PSTR("SENSOR_TEST_%d:%s"), i, buffer);
      sendBluetoothMessage(message.get());
      MessageBuffer::releaseBuffer();
    }
    delay(200);
  }

  sendBluetoothMessage("SENSOR_TEST_COMPLETE");
  DEBUG_PRINTLN_P("✅ Sensor communication test complete");
}

#endif // SENSOR_STATUS_H