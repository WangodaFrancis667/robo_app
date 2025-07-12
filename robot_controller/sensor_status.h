/**********************************************************************
 *  sensor_status.h - Sensor Status Manager for Flutter App
 *  Manages and formats sensor data for transmission to Flutter application
 *********************************************************************/

#ifndef SENSOR_STATUS_H
#define SENSOR_STATUS_H

#include "config.h"
#include "sensor_manager.h"
#include "collision_avoidance.h"

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
  static String getStatusJSON();
  static String getDetailedStatusJSON();
  
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
  static String formatForFlutterDashboard();
  static String formatCollisionWarning();
  static String formatSensorHealthCheck();
  
  // Diagnostics
  static void sendDiagnosticData();
  static void testSensorCommunication();
};

// Implementation
SensorStatus SensorStatusManager::currentStatus = {0.0, 0.0, false, false, false, false, false, 0};
unsigned long SensorStatusManager::lastStatusUpdate = 0;
unsigned long SensorStatusManager::lastStatusSent = 0;
bool SensorStatusManager::autoSendEnabled = true;
int SensorStatusManager::statusUpdateInterval = 100; // Update every 100ms
int SensorStatusManager::statusSendInterval = 500;   // Send every 500ms

void SensorStatusManager::init() {
  DEBUG_PRINTLN("📊 Initializing Sensor Status Manager...");
  
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
  autoSendEnabled = true;
  
  DEBUG_PRINTLN("✅ Sensor Status Manager initialized");
  DEBUG_PRINTLN("📊 Auto-send: " + String(autoSendEnabled ? "ENABLED" : "DISABLED"));
  DEBUG_PRINTLN("📊 Update interval: " + String(statusUpdateInterval) + "ms");
  DEBUG_PRINTLN("📊 Send interval: " + String(statusSendInterval) + "ms");
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

bool SensorStatusManager::isAutoSendEnabled() {
  return autoSendEnabled;
}

void SensorStatusManager::sendStatusNow() {
  updateCurrentStatus();
  sendStatusUpdate();
}

void SensorStatusManager::sendDetailedStatus() {
  updateCurrentStatus();
  
  extern void sendBluetoothMessage(const String& message);
  sendBluetoothMessage("SENSOR_DETAILED:" + getDetailedStatusJSON());
}

void SensorStatusManager::sendStatusUpdate() {
  extern void sendBluetoothMessage(const String& message);
  sendBluetoothMessage("SENSOR_STATUS:" + getStatusJSON());
}

String SensorStatusManager::getStatusJSON() {
  String json = "{";
  json += "\"frontDist\":" + String(currentStatus.frontDistance, 1) + ",";
  json += "\"rearDist\":" + String(currentStatus.rearDistance, 1) + ",";
  json += "\"frontObstacle\":" + String(currentStatus.frontObstacle ? "true" : "false") + ",";
  json += "\"rearObstacle\":" + String(currentStatus.rearObstacle ? "true" : "false") + ",";
  json += "\"frontRisk\":" + String(currentStatus.frontCollisionRisk ? "true" : "false") + ",";
  json += "\"rearRisk\":" + String(currentStatus.rearCollisionRisk ? "true" : "false") + ",";
  json += "\"active\":" + String(currentStatus.sensorsActive ? "true" : "false") + ",";
  json += "\"timestamp\":" + String(currentStatus.lastUpdate);
  json += "}";
  return json;
}

String SensorStatusManager::getDetailedStatusJSON() {
  String json = "{";
  json += "\"sensors\":{";
  json += "\"front\":{";
  json += "\"distance\":" + String(currentStatus.frontDistance, 1) + ",";
  json += "\"obstacle\":" + String(currentStatus.frontObstacle ? "true" : "false") + ",";
  json += "\"collisionRisk\":" + String(currentStatus.frontCollisionRisk ? "true" : "false") + ",";
  json += "\"active\":" + String(SensorManager::areSensorsEnabled() ? "true" : "false");
  json += "},";
  json += "\"rear\":{";
  json += "\"distance\":" + String(currentStatus.rearDistance, 1) + ",";
  json += "\"obstacle\":" + String(currentStatus.rearObstacle ? "true" : "false") + ",";
  json += "\"collisionRisk\":" + String(currentStatus.rearCollisionRisk ? "true" : "false") + ",";
  json += "\"active\":" + String(SensorManager::areSensorsEnabled() ? "true" : "false");
  json += "}";
  json += "},";
  json += "\"collisionAvoidance\":{";
  json += "\"enabled\":" + String(CollisionAvoidance::isEnabled() ? "true" : "false") + ",";
  json += "\"emergencyStop\":" + String(CollisionAvoidance::isEmergencyStopActive() ? "true" : "false") + ",";
  json += "\"aggressiveness\":" + String(CollisionAvoidance::getAggressiveness());
  json += "},";
  json += "\"thresholds\":{";
  json += "\"collision\":" + String(SensorManager::getCollisionDistance(), 1) + ",";
  json += "\"warning\":" + String(SensorManager::getWarningDistance(), 1);
  json += "},";
  json += "\"system\":{";
  json += "\"healthy\":" + String(SensorManager::areSensorsHealthy() ? "true" : "false") + ",";
  json += "\"autoSend\":" + String(autoSendEnabled ? "true" : "false") + ",";
  json += "\"updateInterval\":" + String(statusUpdateInterval) + ",";
  json += "\"sendInterval\":" + String(statusSendInterval);
  json += "},";
  json += "\"timestamp\":" + String(currentStatus.lastUpdate);
  json += "}";
  return json;
}

String SensorStatusManager::formatForFlutterDashboard() {
  String status = "DASHBOARD_SENSORS:";
  status += "F=" + String(currentStatus.frontDistance, 0) + "cm,";
  status += "R=" + String(currentStatus.rearDistance, 0) + "cm";
  
  if (currentStatus.frontCollisionRisk || currentStatus.rearCollisionRisk) {
    status += ",COLLISION_RISK";
  } else if (currentStatus.frontObstacle || currentStatus.rearObstacle) {
    status += ",OBSTACLES";
  } else {
    status += ",CLEAR";
  }
  
  return status;
}

String SensorStatusManager::formatCollisionWarning() {
  String warning = "COLLISION_WARNING:{";
  
  if (currentStatus.frontCollisionRisk) {
    warning += "\"front\":" + String(currentStatus.frontDistance, 1) + ",";
  }
  if (currentStatus.rearCollisionRisk) {
    warning += "\"rear\":" + String(currentStatus.rearDistance, 1) + ",";
  }
  
  warning += "\"timestamp\":" + String(millis());
  warning += "}";
  
  return warning;
}

String SensorStatusManager::formatSensorHealthCheck() {
  String health = "SENSOR_HEALTH:{";
  health += "\"frontActive\":" + String(SensorManager::areSensorsEnabled() ? "true" : "false") + ",";
  health += "\"rearActive\":" + String(SensorManager::areSensorsEnabled() ? "true" : "false") + ",";
  health += "\"systemHealthy\":" + String(SensorManager::areSensorsHealthy() ? "true" : "false") + ",";
  health += "\"collisionAvoidance\":" + String(CollisionAvoidance::isEnabled() ? "true" : "false") + ",";
  health += "\"timestamp\":" + String(millis());
  health += "}";
  return health;
}

void SensorStatusManager::setUpdateInterval(int intervalMs) {
  statusUpdateInterval = constrain(intervalMs, 50, 2000);
  DEBUG_PRINTLN("📊 Status update interval set to " + String(statusUpdateInterval) + "ms");
}

void SensorStatusManager::setSendInterval(int intervalMs) {
  statusSendInterval = constrain(intervalMs, 100, 5000);
  DEBUG_PRINTLN("📊 Status send interval set to " + String(statusSendInterval) + "ms");
}

int SensorStatusManager::getUpdateInterval() {
  return statusUpdateInterval;
}

int SensorStatusManager::getSendInterval() {
  return statusSendInterval;
}

SensorStatus SensorStatusManager::getCurrentStatus() {
  return currentStatus;
}

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
  DEBUG_PRINTLN("📊 Sending diagnostic data...");
  
  extern void sendBluetoothMessage(const String& message);
  
  // Send sensor readings
  sendBluetoothMessage("DIAGNOSTIC_SENSORS:" + getDetailedStatusJSON());
  
  // Send collision avoidance status
  String collisionStatus;
  CollisionAvoidance::getStatus(collisionStatus);
  sendBluetoothMessage("DIAGNOSTIC_COLLISION:" + collisionStatus);
  
  // Send sensor health
  sendBluetoothMessage("DIAGNOSTIC_HEALTH:" + formatSensorHealthCheck());
  
  DEBUG_PRINTLN("✅ Diagnostic data sent");
}

void SensorStatusManager::testSensorCommunication() {
  DEBUG_PRINTLN("🧪 Testing sensor communication...");
  
  extern void sendBluetoothMessage(const String& message);
  
  // Send test message
  sendBluetoothMessage("SENSOR_TEST_START");
  
  // Send multiple status updates
  for (int i = 0; i < 5; i++) {
    updateCurrentStatus();
    sendBluetoothMessage("SENSOR_TEST_" + String(i) + ":" + getStatusJSON());
    delay(200);
  }
  
  sendBluetoothMessage("SENSOR_TEST_COMPLETE");
  DEBUG_PRINTLN("✅ Sensor communication test complete");
}

#endif // SENSOR_STATUS_H
