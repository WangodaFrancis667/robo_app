/**********************************************************************
 *  collision_avoidance.h - Collision Prevention System
 *  Integrates sensor data with motor control for autonomous collision
 *prevention
 *********************************************************************/

#ifndef COLLISION_AVOIDANCE_H
#define COLLISION_AVOIDANCE_H

#include "config.h"
#include "memory_optimization.h"
#include "sensor_manager.h"

// Forward declaration to avoid circular dependency
extern void sendBluetoothMessage(const char *message);

class CollisionAvoidance {
private:
  static bool collisionAvoidanceEnabled;
  static bool emergencyStopActive;
  static unsigned long lastCollisionWarning;
  static unsigned long lastEmergencyStop;
  static int originalSpeed;
  static bool wasMovingForward;

  // Movement validation
  static bool validateMovementCommand(const char *command, int speed,
                                      bool &isForward);
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
  static bool isMovementSafe(const char *command, int speed);
  static int adjustSpeedForSafety(int requestedSpeed, bool movingForward);
  static bool shouldStopMovement(bool movingForward);

  // Emergency handling
  static void triggerEmergencyStop(const char *reason);
  static void clearEmergencyStop();
  static bool isEmergencyStopActive();

  // Status and diagnostics
  static void getStatus(char *buffer, size_t bufferSize);
  static void sendCollisionWarning(const char *direction);

  // Integration with motor controller
  static bool validateForwardMovement(int speed);
  static bool validateBackwardMovement(int speed);
  static bool validateTurnMovement(int speed);

  // Configuration
  static void
  setAggressiveness(int level); // 1=conservative, 2=normal, 3=aggressive
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
  DEBUG_PRINTLN_P("Initializing Collision Avoidance...");

  collisionAvoidanceEnabled = true;
  emergencyStopActive = false;
  lastCollisionWarning = 0;
  lastEmergencyStop = 0;

  DEBUG_PRINTLN_P("Collision Avoidance initialized - ENABLED");
}

void CollisionAvoidance::update() {
  if (!collisionAvoidanceEnabled)
    return;

  // Check for immediate collision risks
  bool frontRisk = SensorManager::isFrontCollisionRisk();
  bool rearRisk = SensorManager::isRearCollisionRisk();

  // Handle emergency stops
  if (frontRisk || rearRisk) {
    if (!emergencyStopActive) {
      const char *direction = frontRisk ? "FRONT" : "REAR";
      triggerEmergencyStop("Collision risk detected");

      // Send collision warning with optimized message
      if (MessageBuffer::isAvailable()) {
        char *buffer = MessageBuffer::getBuffer();
        float distance = frontRisk ? SensorManager::getFrontDistance()
                                   : SensorManager::getRearDistance();
        formatCollisionMessage(direction, distance, buffer, MAX_MESSAGE_LENGTH);
        sendBluetoothMessage(buffer);
        MessageBuffer::releaseBuffer();
      }
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

bool CollisionAvoidance::isEnabled() { return collisionAvoidanceEnabled; }

bool CollisionAvoidance::isMovementSafe(const char *command, int speed) {
  if (!collisionAvoidanceEnabled)
    return true;

  bool isForward;
  return validateMovementCommand(command, speed, isForward);
}

bool CollisionAvoidance::validateMovementCommand(const char *command, int speed,
                                                 bool &isForward) {
  isForward = true;

  if (strcmp(command, "FORWARD") == 0) {
    isForward = true;
    return validateForwardMovement(speed);
  } else if (strcmp(command, "BACKWARD") == 0) {
    isForward = false;
    return validateBackwardMovement(speed);
  } else if (strcmp(command, "LEFT") == 0 || strcmp(command, "RIGHT") == 0) {
    // For turns, check both directions but prioritize the turn direction
    return validateTurnMovement(speed);
  } else if (strcmp(command, "TANK") == 0) {
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
  if (SensorManager::isFrontCollisionRisk() &&
      SensorManager::isRearCollisionRisk()) {
    DEBUG_PRINTLN("🚫 Turn movement blocked - surrounded by obstacles");
    return false;
  }
  return true;
}

int CollisionAvoidance::adjustSpeedForSafety(int requestedSpeed,
                                             bool movingForward) {
  if (!collisionAvoidanceEnabled)
    return requestedSpeed;

  return SensorManager::getRecommendedSpeed(requestedSpeed, movingForward);
}

bool CollisionAvoidance::shouldStopMovement(bool movingForward) {
  if (!collisionAvoidanceEnabled)
    return false;

  if (movingForward) {
    return SensorManager::isFrontCollisionRisk();
  } else {
    return SensorManager::isRearCollisionRisk();
  }
}

void CollisionAvoidance::triggerEmergencyStop(const char *reason) {
  if (!emergencyStopActive) {
    emergencyStopActive = true;
    lastEmergencyStop = millis();

    DEBUG_PRINT_P("🚨 COLLISION AVOIDANCE EMERGENCY STOP: ");
    DEBUG_PRINTLN(reason);

    // Send emergency stop notification using message buffer
    if (MessageBuffer::isAvailable()) {
      char *buffer = MessageBuffer::getBuffer();
      snprintf_P(buffer, MAX_MESSAGE_LENGTH,
                 PSTR("EMERGENCY_STOP_COLLISION:%s"), reason);
      sendBluetoothMessage(buffer);
      MessageBuffer::releaseBuffer();
    }

    // Stop all motors immediately
    extern void emergencyStopAllMotors();
    emergencyStopAllMotors();
  }
}

void CollisionAvoidance::clearEmergencyStop() {
  if (emergencyStopActive) {
    emergencyStopActive = false;
    DEBUG_PRINTLN_P("✅ Collision avoidance emergency stop cleared");

    sendBluetoothMessage("EMERGENCY_STOP_CLEARED");
  }
}

bool CollisionAvoidance::isEmergencyStopActive() { return emergencyStopActive; }

void CollisionAvoidance::getStatus(char *buffer, size_t bufferSize) {
  const char *enabled = collisionAvoidanceEnabled ? "ENABLED" : "DISABLED";
  const char *emergency = emergencyStopActive ? "ACTIVE" : "CLEAR";

  snprintf_P(buffer, bufferSize,
             PSTR("Collision Avoidance: %s | Emergency Stop: %s"), enabled,
             emergency);

  if (SensorManager::isFrontCollisionRisk() ||
      SensorManager::isRearCollisionRisk()) {
    strncat_P(buffer, PSTR(" | COLLISION RISK"),
              bufferSize - strlen(buffer) - 1);
  } else if (SensorManager::isFrontObstacleDetected() ||
             SensorManager::isRearObstacleDetected()) {
    strncat_P(buffer, PSTR(" | OBSTACLES DETECTED"),
              bufferSize - strlen(buffer) - 1);
  } else {
    strncat_P(buffer, PSTR(" | PATH CLEAR"), bufferSize - strlen(buffer) - 1);
  }
}

void CollisionAvoidance::sendCollisionWarning(const char *direction) {
  float distance = (strcmp(direction, "FRONT") == 0)
                       ? SensorManager::getFrontDistance()
                       : SensorManager::getRearDistance();

  DEBUG_PRINT_P("⚠ Collision warning: ");
  DEBUG_PRINT(direction);
  DEBUG_PRINT_P(" obstacle at ");
  DEBUG_PRINT_VAL("", distance);
  DEBUG_PRINTLN_P("cm");

  // Use the optimized collision message formatter
  if (MessageBuffer::isAvailable()) {
    char *buffer = MessageBuffer::getBuffer();
    formatCollisionMessage(direction, distance, buffer, MAX_MESSAGE_LENGTH);
    extern void sendBluetoothMessage(const char *message);
    sendBluetoothMessage(buffer);
    MessageBuffer::releaseBuffer();
  }
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

  DEBUG_PRINTLN("🛡 Collision avoidance aggressiveness set to level " +
                String(level));
}

int CollisionAvoidance::getAggressiveness() {
  float collisionDist = SensorManager::getCollisionDistance();

  if (collisionDist >= 20)
    return 1; // Conservative
  else if (collisionDist >= 12)
    return 2; // Normal
  else
    return 3; // Aggressive
}

#endif // COLLISION_AVOIDANCE_H
