/**********************************************************************
 *  collision_avoidance.h - Collision Prevention System
 *  Integrates sensor data with motor control for autonomous collision prevention
 *********************************************************************/

#ifndef COLLISION_AVOIDANCE_H
#define COLLISION_AVOIDANCE_H

#include "config.h"
#include "sensor_manager.h"

class CollisionAvoidance {
private:
  static bool collisionAvoidanceEnabled;
  static bool emergencyStopActive;
  static unsigned long lastCollisionWarning;
  static unsigned long lastEmergencyStop;
  static int originalSpeed;
  static bool wasMovingForward;
  
  // Movement validation
  static bool validateMovementCommand(const String& command, int speed, bool &isForward);
  static int calculateSafeSpeed(int requestedSpeed, bool movingForward);
  
public:
  // Initialize collision avoidance
  static void init();
  
  // Update - call this in main loop
  static void update();
  
  // Enable/disable collision avoidance
  static void enable();
  static void disable();
  static bool isEnabled();
  
  // Movement validation and modification
  static bool isMovementSafe(const String& command, int speed);
  static int adjustSpeedForSafety(int requestedSpeed, bool movingForward);
  static bool shouldStopMovement(bool movingForward);
  
  // Emergency handling
  static void triggerEmergencyStop(const String& reason);
  static void clearEmergencyStop();
  static bool isEmergencyStopActive();
  
  // Status and diagnostics
  static void getStatus(String &statusString);
  static void sendCollisionWarning(const String& direction);
  
  // Integration with motor controller
  static bool validateForwardMovement(int speed);
  static bool validateBackwardMovement(int speed);
  static bool validateTurnMovement(int speed);
  
  // Configuration
  static void setAggressiveness(int level); // 1=conservative, 2=normal, 3=aggressive
  static int getAggressiveness();
};

// Implementation
bool CollisionAvoidance::collisionAvoidanceEnabled = true;
bool CollisionAvoidance::emergencyStopActive = false;
unsigned long CollisionAvoidance::lastCollisionWarning = 0;
unsigned long CollisionAvoidance::lastEmergencyStop = 0;
int CollisionAvoidance::originalSpeed = 0;
bool CollisionAvoidance::wasMovingForward = true;

void CollisionAvoidance::init() {
  DEBUG_PRINTLN("🛡 Initializing Collision Avoidance...");
  
  collisionAvoidanceEnabled = true;
  emergencyStopActive = false;
  lastCollisionWarning = 0;
  lastEmergencyStop = 0;
  
  DEBUG_PRINTLN("✅ Collision Avoidance initialized");
  DEBUG_PRINTLN("🛡 Status: " + String(collisionAvoidanceEnabled ? "ENABLED" : "DISABLED"));
}

void CollisionAvoidance::update() {
  if (!collisionAvoidanceEnabled) return;
  
  // Check for immediate collision risks
  bool frontRisk = SensorManager::isFrontCollisionRisk();
  bool rearRisk = SensorManager::isRearCollisionRisk();
  
  // Handle emergency stops
  if (frontRisk || rearRisk) {
    if (!emergencyStopActive) {
      String direction = frontRisk ? "FRONT" : "REAR";
      triggerEmergencyStop("Collision risk detected: " + direction);
    }
  } else {
    // Clear emergency stop if no immediate risks
    if (emergencyStopActive && (millis() - lastEmergencyStop > 1000)) {
      clearEmergencyStop();
    }
  }
  
  // Send periodic warnings for obstacles
  unsigned long currentTime = millis();
  if (currentTime - lastCollisionWarning > 2000) {
    if (SensorManager::isFrontObstacleDetected()) {
      sendCollisionWarning("FRONT");
    }
    if (SensorManager::isRearObstacleDetected()) {
      sendCollisionWarning("REAR");
    }
    lastCollisionWarning = currentTime;
  }
}

void CollisionAvoidance::enable() {
  collisionAvoidanceEnabled = true;
  DEBUG_PRINTLN("🛡 Collision avoidance ENABLED");
}

void CollisionAvoidance::disable() {
  collisionAvoidanceEnabled = false;
  clearEmergencyStop();
  DEBUG_PRINTLN("🛡 Collision avoidance DISABLED");
}

bool CollisionAvoidance::isEnabled() {
  return collisionAvoidanceEnabled;
}

bool CollisionAvoidance::isMovementSafe(const String& command, int speed) {
  if (!collisionAvoidanceEnabled) return true;
  
  bool isForward;
  return validateMovementCommand(command, speed, isForward);
}

bool CollisionAvoidance::validateMovementCommand(const String& command, int speed, bool &isForward) {
  isForward = true;
  
  if (command == "FORWARD") {
    isForward = true;
    return validateForwardMovement(speed);
  } else if (command == "BACKWARD") {
    isForward = false;
    return validateBackwardMovement(speed);
  } else if (command == "LEFT" || command == "RIGHT") {
    // For turns, check both directions but prioritize the turn direction
    return validateTurnMovement(speed);
  } else if (command == "TANK") {
    // Tank drive - more complex validation needed
    // For now, allow tank drive but at reduced speed if obstacles present
    return true;
  }
  
  return true; // Allow other commands (like STOP)
}

bool CollisionAvoidance::validateForwardMovement(int speed) {
  if (SensorManager::isFrontCollisionRisk()) {
    DEBUG_PRINTLN("🚫 Forward movement blocked - collision risk");
    return false;
  }
  return true;
}

bool CollisionAvoidance::validateBackwardMovement(int speed) {
  if (SensorManager::isRearCollisionRisk()) {
    DEBUG_PRINTLN("🚫 Backward movement blocked - collision risk");
    return false;
  }
  return true;
}

bool CollisionAvoidance::validateTurnMovement(int speed) {
  // For turns, we're more lenient but still check for immediate collision risks
  if (SensorManager::isFrontCollisionRisk() && SensorManager::isRearCollisionRisk()) {
    DEBUG_PRINTLN("🚫 Turn movement blocked - surrounded by obstacles");
    return false;
  }
  return true;
}

int CollisionAvoidance::adjustSpeedForSafety(int requestedSpeed, bool movingForward) {
  if (!collisionAvoidanceEnabled) return requestedSpeed;
  
  return SensorManager::getRecommendedSpeed(requestedSpeed, movingForward);
}

bool CollisionAvoidance::shouldStopMovement(bool movingForward) {
  if (!collisionAvoidanceEnabled) return false;
  
  if (movingForward) {
    return SensorManager::isFrontCollisionRisk();
  } else {
    return SensorManager::isRearCollisionRisk();
  }
}

void CollisionAvoidance::triggerEmergencyStop(const String& reason) {
  if (!emergencyStopActive) {
    emergencyStopActive = true;
    lastEmergencyStop = millis();
    
    DEBUG_PRINTLN("🚨 COLLISION AVOIDANCE EMERGENCY STOP: " + reason);
    
    // Send emergency stop notification
    extern void sendBluetoothMessage(const String& message);
    sendBluetoothMessage("EMERGENCY_STOP_COLLISION:" + reason);
    
    // Stop all motors immediately
    extern void emergencyStopAllMotors();
    emergencyStopAllMotors();
  }
}

void CollisionAvoidance::clearEmergencyStop() {
  if (emergencyStopActive) {
    emergencyStopActive = false;
    DEBUG_PRINTLN("✅ Collision avoidance emergency stop cleared");
    
    extern void sendBluetoothMessage(const String& message);
    sendBluetoothMessage("EMERGENCY_STOP_CLEARED");
  }
}

bool CollisionAvoidance::isEmergencyStopActive() {
  return emergencyStopActive;
}

void CollisionAvoidance::getStatus(String &statusString) {
  statusString = "Collision Avoidance: ";
  statusString += String(collisionAvoidanceEnabled ? "ENABLED" : "DISABLED");
  statusString += " | Emergency Stop: " + String(emergencyStopActive ? "ACTIVE" : "CLEAR");
  
  if (SensorManager::isFrontCollisionRisk() || SensorManager::isRearCollisionRisk()) {
    statusString += " | COLLISION RISK";
  } else if (SensorManager::isFrontObstacleDetected() || SensorManager::isRearObstacleDetected()) {
    statusString += " | OBSTACLES DETECTED";
  } else {
    statusString += " | PATH CLEAR";
  }
}

void CollisionAvoidance::sendCollisionWarning(const String& direction) {
  float distance = (direction == "FRONT") ? SensorManager::getFrontDistance() : SensorManager::getRearDistance();
  
  DEBUG_PRINTLN("⚠ Collision warning: " + direction + " obstacle at " + String(distance, 1) + "cm");
  
  extern void sendBluetoothMessage(const String& message);
  sendBluetoothMessage("COLLISION_WARNING:" + direction + ":" + String(distance, 1));
}

void CollisionAvoidance::setAggressiveness(int level) {
  level = constrain(level, 1, 3);
  
  switch (level) {
    case 1: // Conservative
      SensorManager::setCollisionDistance(25);
      SensorManager::setWarningDistance(60);
      break;
    case 2: // Normal
      SensorManager::setCollisionDistance(15);
      SensorManager::setWarningDistance(50);
      break;
    case 3: // Aggressive
      SensorManager::setCollisionDistance(10);
      SensorManager::setWarningDistance(30);
      break;
  }
  
  DEBUG_PRINTLN("🛡 Collision avoidance aggressiveness set to level " + String(level));
}

int CollisionAvoidance::getAggressiveness() {
  float collisionDist = SensorManager::getCollisionDistance();
  
  if (collisionDist >= 20) return 1; // Conservative
  else if (collisionDist >= 12) return 2; // Normal
  else return 3; // Aggressive
}

#endif // COLLISION_AVOIDANCE_H
