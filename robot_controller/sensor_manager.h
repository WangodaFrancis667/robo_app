/**********************************************************************
 *  sensor_manager.h - HC-SR04 Ultrasonic Sensor Management
 *  Handles front and rear ultrasonic sensors for collision detection
 *********************************************************************/

#ifndef SENSOR_MANAGER_H
#define SENSOR_MANAGER_H

#include "config.h"

class SensorManager {
private:
  static SensorState sensors[2];
  static bool sensorsEnabled;
  static unsigned long lastSensorUpdate;
  static float collisionDistance;
  static float warningDistance;
  
  // Private helper methods
  static float readDistance(int trigPin, int echoPin);
  static void updateSensorState(int sensorIndex);
  static bool isValidReading(float distance);
  static void stabilizeReading(int sensorIndex, float newReading);
  
public:
  // Initialize sensor manager
  static void init();
  
  // Update - call this in main loop
  static void update();
  
  // Sensor control
  static void enableSensors();
  static void disableSensors();
  static bool areSensorsEnabled();
  
  // Distance readings
  static float getFrontDistance();
  static float getRearDistance();
  static float getDistance(int sensorIndex);
  
  // Obstacle detection
  static bool isFrontObstacleDetected();
  static bool isRearObstacleDetected();
  static bool isObstacleDetected(int sensorIndex);
  
  // Collision risk assessment
  static bool isFrontCollisionRisk();
  static bool isRearCollisionRisk();
  static bool isCollisionRisk(int sensorIndex);
  
  // Configuration
  static void setCollisionDistance(float distance);
  static void setWarningDistance(float distance);
  static float getCollisionDistance();
  static float getWarningDistance();
  
  // Status and diagnostics
  static void getSensorStatus(SensorStatus &status);
  static void getDetailedStatus(String &statusString);
  static bool areSensorsHealthy();
  
  // Calibration and testing
  static void calibrateSensors();
  static void testSensors();
  static void testSensor(int sensorIndex);
  
  // Safety functions
  static bool isSafeToMoveForward();
  static bool isSafeToMoveBackward();
  static int getRecommendedSpeed(int requestedSpeed, bool movingForward);
};

// Implementation
SensorState SensorManager::sensors[2] = {
  {0.0, 0.0, false, false, 0, 0, "Front", true},
  {0.0, 0.0, false, false, 0, 0, "Rear", true}
};

bool SensorManager::sensorsEnabled = true;
unsigned long SensorManager::lastSensorUpdate = 0;
float SensorManager::collisionDistance = COLLISION_DISTANCE_STOP;
float SensorManager::warningDistance = COLLISION_DISTANCE_WARN;

void SensorManager::init() {
  DEBUG_PRINTLN("📡 Initializing Sensor Manager...");
  
  // Initialize sensor pins
  pinMode(FRONT_SENSOR_TRIG, OUTPUT);
  pinMode(FRONT_SENSOR_ECHO, INPUT);
  pinMode(REAR_SENSOR_TRIG, OUTPUT);
  pinMode(REAR_SENSOR_ECHO, INPUT);
  
  // Initialize sensor states
  for (int i = 0; i < 2; i++) {
    sensors[i].currentDistance = 0.0;
    sensors[i].lastStableDistance = 0.0;
    sensors[i].isObstacleDetected = false;
    sensors[i].isCollisionRisk = false;
    sensors[i].lastUpdate = 0;
    sensors[i].stableReadingCount = 0;
    sensors[i].isActive = true;
  }
  
  sensorsEnabled = true;
  lastSensorUpdate = millis();
  
  // Initial sensor reading
  delay(100);
  update();
  
  DEBUG_PRINTLN("✅ Sensor Manager initialized");
  DEBUG_PRINTLN("📍 Sensor Configuration:");
  DEBUG_PRINTLN("   Front Sensor: Trig=" + String(FRONT_SENSOR_TRIG) + ", Echo=" + String(FRONT_SENSOR_ECHO));
  DEBUG_PRINTLN("   Rear Sensor: Trig=" + String(REAR_SENSOR_TRIG) + ", Echo=" + String(REAR_SENSOR_ECHO));
  DEBUG_PRINTLN("   Collision Distance: " + String(collisionDistance) + "cm");
  DEBUG_PRINTLN("   Warning Distance: " + String(warningDistance) + "cm");
}

void SensorManager::update() {
  if (!sensorsEnabled) return;
  
  unsigned long currentTime = millis();
  
  // Update sensors at specified interval
  if (currentTime - lastSensorUpdate >= SENSOR_UPDATE_INTERVAL) {
    updateSensorState(FRONT_SENSOR);
    updateSensorState(REAR_SENSOR);
    lastSensorUpdate = currentTime;
  }
}

void SensorManager::updateSensorState(int sensorIndex) {
  if (sensorIndex < 0 || sensorIndex >= 2) return;
  
  int trigPin, echoPin;
  if (sensorIndex == FRONT_SENSOR) {
    trigPin = FRONT_SENSOR_TRIG;
    echoPin = FRONT_SENSOR_ECHO;
  } else {
    trigPin = REAR_SENSOR_TRIG;
    echoPin = REAR_SENSOR_ECHO;
  }
  
  // Read distance
  float distance = readDistance(trigPin, echoPin);
  
  if (isValidReading(distance)) {
    stabilizeReading(sensorIndex, distance);
    
    // Update obstacle detection
    sensors[sensorIndex].isObstacleDetected = (sensors[sensorIndex].lastStableDistance <= warningDistance);
    sensors[sensorIndex].isCollisionRisk = (sensors[sensorIndex].lastStableDistance <= collisionDistance);
    sensors[sensorIndex].lastUpdate = millis();
    sensors[sensorIndex].isActive = true;
    
    if (DEBUG_ENABLED) {
      if (sensors[sensorIndex].isCollisionRisk) {
        DEBUG_PRINT("🚨 " + sensors[sensorIndex].name + " COLLISION RISK: ");
        DEBUG_PRINTLN(String(sensors[sensorIndex].lastStableDistance, 1) + "cm");
      } else if (sensors[sensorIndex].isObstacleDetected) {
        DEBUG_PRINT("⚠ " + sensors[sensorIndex].name + " obstacle: ");
        DEBUG_PRINTLN(String(sensors[sensorIndex].lastStableDistance, 1) + "cm");
      }
    }
  } else {
    // Invalid reading - sensor may be blocked or malfunctioning
    sensors[sensorIndex].isActive = false;
    if (millis() - sensors[sensorIndex].lastUpdate > 1000) {
      DEBUG_PRINTLN("⚠ " + sensors[sensorIndex].name + " sensor not responding");
    }
  }
}

float SensorManager::readDistance(int trigPin, int echoPin) {
  // Send trigger pulse
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  
  // Read echo pulse
  unsigned long duration = pulseIn(echoPin, HIGH, 30000); // 30ms timeout
  
  if (duration == 0) {
    return -1; // Timeout - no echo received
  }
  
  // Calculate distance in centimeters
  float distance = (duration * 0.034) / 2;
  
  return distance;
}

bool SensorManager::isValidReading(float distance) {
  return (distance > 0 && distance <= MAX_SENSOR_DISTANCE);
}

void SensorManager::stabilizeReading(int sensorIndex, float newReading) {
  SensorState &sensor = sensors[sensorIndex];
  
  // Check if reading is consistent with previous readings
  if (abs(newReading - sensor.currentDistance) < 5.0) {
    sensor.stableReadingCount++;
  } else {
    sensor.stableReadingCount = 0;
  }
  
  sensor.currentDistance = newReading;
  
  // Update stable distance if we have enough consistent readings
  if (sensor.stableReadingCount >= SENSOR_STABILIZE_COUNT) {
    sensor.lastStableDistance = newReading;
  }
}

void SensorManager::enableSensors() {
  sensorsEnabled = true;
  DEBUG_PRINTLN("📡 Sensors enabled");
}

void SensorManager::disableSensors() {
  sensorsEnabled = false;
  
  // Clear obstacle flags when disabling
  for (int i = 0; i < 2; i++) {
    sensors[i].isObstacleDetected = false;
    sensors[i].isCollisionRisk = false;
  }
  
  DEBUG_PRINTLN("📡 Sensors disabled");
}

bool SensorManager::areSensorsEnabled() {
  return sensorsEnabled;
}

float SensorManager::getFrontDistance() {
  return sensors[FRONT_SENSOR].lastStableDistance;
}

float SensorManager::getRearDistance() {
  return sensors[REAR_SENSOR].lastStableDistance;
}

float SensorManager::getDistance(int sensorIndex) {
  if (sensorIndex >= 0 && sensorIndex < 2) {
    return sensors[sensorIndex].lastStableDistance;
  }
  return -1;
}

bool SensorManager::isFrontObstacleDetected() {
  return sensorsEnabled && sensors[FRONT_SENSOR].isObstacleDetected;
}

bool SensorManager::isRearObstacleDetected() {
  return sensorsEnabled && sensors[REAR_SENSOR].isObstacleDetected;
}

bool SensorManager::isObstacleDetected(int sensorIndex) {
  if (sensorIndex >= 0 && sensorIndex < 2) {
    return sensorsEnabled && sensors[sensorIndex].isObstacleDetected;
  }
  return false;
}

bool SensorManager::isFrontCollisionRisk() {
  return sensorsEnabled && sensors[FRONT_SENSOR].isCollisionRisk;
}

bool SensorManager::isRearCollisionRisk() {
  return sensorsEnabled && sensors[REAR_SENSOR].isCollisionRisk;
}

bool SensorManager::isCollisionRisk(int sensorIndex) {
  if (sensorIndex >= 0 && sensorIndex < 2) {
    return sensorsEnabled && sensors[sensorIndex].isCollisionRisk;
  }
  return false;
}

void SensorManager::setCollisionDistance(float distance) {
  collisionDistance = constrain(distance, 5.0, 100.0);
  DEBUG_PRINTLN("📏 Collision distance set to " + String(collisionDistance) + "cm");
}

void SensorManager::setWarningDistance(float distance) {
  warningDistance = constrain(distance, 10.0, 200.0);
  DEBUG_PRINTLN("📏 Warning distance set to " + String(warningDistance) + "cm");
}

float SensorManager::getCollisionDistance() {
  return collisionDistance;
}

float SensorManager::getWarningDistance() {
  return warningDistance;
}

void SensorManager::getSensorStatus(SensorStatus &status) {
  status.frontDistance = getFrontDistance();
  status.rearDistance = getRearDistance();
  status.frontObstacle = isFrontObstacleDetected();
  status.rearObstacle = isRearObstacleDetected();
  status.frontCollisionRisk = isFrontCollisionRisk();
  status.rearCollisionRisk = isRearCollisionRisk();
  status.sensorsActive = sensorsEnabled;
  status.lastUpdate = millis();
}

void SensorManager::getDetailedStatus(String &statusString) {
  statusString = "Sensors: ";
  statusString += "Front=" + String(getFrontDistance(), 1) + "cm";
  statusString += ", Rear=" + String(getRearDistance(), 1) + "cm";
  statusString += " | Obstacles: F=" + String(isFrontObstacleDetected() ? "YES" : "NO");
  statusString += ", R=" + String(isRearObstacleDetected() ? "YES" : "NO");
  statusString += " | Collision Risk: F=" + String(isFrontCollisionRisk() ? "YES" : "NO");
  statusString += ", R=" + String(isRearCollisionRisk() ? "YES" : "NO");
  statusString += " | Active: " + String(sensorsEnabled ? "YES" : "NO");
}

bool SensorManager::areSensorsHealthy() {
  if (!sensorsEnabled) return true; // Consider disabled sensors as "healthy"
  
  unsigned long currentTime = millis();
  for (int i = 0; i < 2; i++) {
    if (!sensors[i].isActive || (currentTime - sensors[i].lastUpdate > 2000)) {
      return false; // Sensor not responding
    }
  }
  return true;
}

bool SensorManager::isSafeToMoveForward() {
  return !isFrontCollisionRisk();
}

bool SensorManager::isSafeToMoveBackward() {
  return !isRearCollisionRisk();
}

int SensorManager::getRecommendedSpeed(int requestedSpeed, bool movingForward) {
  if (!sensorsEnabled) return requestedSpeed;
  
  bool collisionRisk = movingForward ? isFrontCollisionRisk() : isRearCollisionRisk();
  bool obstacleDetected = movingForward ? isFrontObstacleDetected() : isRearObstacleDetected();
  
  if (collisionRisk) {
    return 0; // Stop immediately
  } else if (obstacleDetected) {
    // Reduce speed when obstacle detected
    return constrain(requestedSpeed / 2, 0, 30);
  }
  
  return requestedSpeed; // No obstacles, maintain requested speed
}

void SensorManager::calibrateSensors() {
  DEBUG_PRINTLN("🔧 Calibrating sensors...");
  
  // Take multiple readings and average them
  float frontTotal = 0, rearTotal = 0;
  int validReadings = 0;
  
  for (int i = 0; i < 10; i++) {
    float frontDist = readDistance(FRONT_SENSOR_TRIG, FRONT_SENSOR_ECHO);
    float rearDist = readDistance(REAR_SENSOR_TRIG, REAR_SENSOR_ECHO);
    
    if (isValidReading(frontDist) && isValidReading(rearDist)) {
      frontTotal += frontDist;
      rearTotal += rearDist;
      validReadings++;
    }
    
    delay(100);
  }
  
  if (validReadings > 0) {
    sensors[FRONT_SENSOR].lastStableDistance = frontTotal / validReadings;
    sensors[REAR_SENSOR].lastStableDistance = rearTotal / validReadings;
    
    DEBUG_PRINTLN("✅ Calibration complete");
    DEBUG_PRINTLN("   Front: " + String(sensors[FRONT_SENSOR].lastStableDistance, 1) + "cm");
    DEBUG_PRINTLN("   Rear: " + String(sensors[REAR_SENSOR].lastStableDistance, 1) + "cm");
  } else {
    DEBUG_PRINTLN("❌ Calibration failed - no valid readings");
  }
}

void SensorManager::testSensors() {
  DEBUG_PRINTLN("🧪 Testing all sensors...");
  testSensor(FRONT_SENSOR);
  testSensor(REAR_SENSOR);
  DEBUG_PRINTLN("✅ Sensor test complete");
}

void SensorManager::testSensor(int sensorIndex) {
  if (sensorIndex < 0 || sensorIndex >= 2) return;
  
  DEBUG_PRINTLN("Testing " + sensors[sensorIndex].name + " sensor...");
  
  for (int i = 0; i < 5; i++) {
    updateSensorState(sensorIndex);
    DEBUG_PRINT("  Reading " + String(i + 1) + ": ");
    DEBUG_PRINT(String(sensors[sensorIndex].currentDistance, 1) + "cm");
    
    if (sensors[sensorIndex].isCollisionRisk) {
      DEBUG_PRINT(" [COLLISION RISK]");
    } else if (sensors[sensorIndex].isObstacleDetected) {
      DEBUG_PRINT(" [OBSTACLE]");
    } else {
      DEBUG_PRINT(" [CLEAR]");
    }
    
    DEBUG_PRINTLN("");
    delay(200);
  }
}

#endif // SENSOR_MANAGER_H
