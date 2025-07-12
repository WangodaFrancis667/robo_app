/**********************************************************************
 *  servo_arm.h - 6-Servo Arm Control Module
 *  Handles all servo arm operations and preset positions
 *********************************************************************/

#ifndef SERVO_ARM_H
#define SERVO_ARM_H

#include "config.h"
#include <Servo.h>

class ServoArm {
private:
  static Servo servos[6];
  static ServoState servoStates[6];
  static int servoMovementSpeed;
  static bool armEnabled;
  static unsigned long lastUpdate;
  
  // Private helper methods
  static void updateServoPosition(int servoIndex);
  static bool isValidAngle(int angle);
  static void moveServoToPosition(int servoIndex, int targetAngle);
  
public:
  // Initialize servo arm
  static void init();
  
  // Update - call this in main loop
  static void update();
  
  // Individual servo control
  static void setServoAngle(int servoIndex, int angle);
  static void setServoTarget(int servoIndex, int targetAngle);
  static int getServoAngle(int servoIndex);
  static String getServoName(int servoIndex);
  
  // Preset positions
  static void moveToHome();
  static void moveToPreset(int presetNumber);
  static void moveToPickup();
  static void moveToPlace();
  static void moveToRest();
  
  // Gripper control
  static void openGripper();
  static void closeGripper();
  static void setGripperPosition(int angle);
  
  // Arm control
  static void enableArm();
  static void disableArm();
  static void stopAll();
  static bool isArmEnabled();
  
  // Movement control
  static void setMovementSpeed(int speed);
  static int getMovementSpeed();
  static bool isAnyServoMoving();
  static void waitForMovementComplete();
  
  // Status and diagnostics
  static void getStatus(String &statusString);
  static void testAllServos();
  static void calibrateServos();
  
  // Smooth movement functions
  static void smoothMoveTo(int servoIndex, int targetAngle, int speed = SERVO_SPEED_NORMAL);
  static void smoothMoveAll(int angles[6], int speed = SERVO_SPEED_NORMAL);
  
  // Safety functions
  static bool isPositionSafe(int servoIndex, int angle);
  static void emergencyStop();
};

// Implementation
Servo ServoArm::servos[6];
ServoState ServoArm::servoStates[6] = {
  {SERVO_BASE_DEFAULT, SERVO_BASE_DEFAULT, false, 0, "Base"},
  {SERVO_SHOULDER_DEFAULT, SERVO_SHOULDER_DEFAULT, false, 0, "Shoulder"},
  {SERVO_ELBOW_DEFAULT, SERVO_ELBOW_DEFAULT, false, 0, "Elbow"},
  {SERVO_WRIST_ROT_DEFAULT, SERVO_WRIST_ROT_DEFAULT, false, 0, "Wrist Rot"},
  {SERVO_WRIST_TILT_DEFAULT, SERVO_WRIST_TILT_DEFAULT, false, 0, "Wrist Tilt"},
  {SERVO_GRIPPER_DEFAULT, SERVO_GRIPPER_DEFAULT, false, 0, "Gripper"}
};

int ServoArm::servoMovementSpeed = SERVO_SPEED_NORMAL;
bool ServoArm::armEnabled = false;
unsigned long ServoArm::lastUpdate = 0;

void ServoArm::init() {
  DEBUG_PRINTLN("🦾 Initializing Servo Arm...");
  
  // Attach servos to pins
  servos[SERVO_BASE_IDX].attach(SERVO_BASE);
  servos[SERVO_SHOULDER_IDX].attach(SERVO_SHOULDER);
  servos[SERVO_ELBOW_IDX].attach(SERVO_ELBOW);
  servos[SERVO_WRIST_ROT_IDX].attach(SERVO_WRIST_ROT);
  servos[SERVO_WRIST_TILT_IDX].attach(SERVO_WRIST_TILT);
  servos[SERVO_GRIPPER_IDX].attach(SERVO_GRIPPER);
  
  // Move to home position slowly
  DEBUG_PRINTLN("🏠 Moving to home position...");
  moveToHome();
  
  // Enable arm
  armEnabled = true;
  lastUpdate = millis();
  
  DEBUG_PRINTLN("✅ Servo Arm initialized");
  DEBUG_PRINTLN("📍 Servo Configuration:");
  DEBUG_PRINTLN("   Base: Pin " + String(SERVO_BASE));
  DEBUG_PRINTLN("   Shoulder: Pin " + String(SERVO_SHOULDER));
  DEBUG_PRINTLN("   Elbow: Pin " + String(SERVO_ELBOW));
  DEBUG_PRINTLN("   Wrist Rotation: Pin " + String(SERVO_WRIST_ROT));
  DEBUG_PRINTLN("   Wrist Tilt: Pin " + String(SERVO_WRIST_TILT));
  DEBUG_PRINTLN("   Gripper: Pin " + String(SERVO_GRIPPER));
}

void ServoArm::update() {
  if (!armEnabled) return;
  
  unsigned long currentTime = millis();
  
  // Update servo positions if enough time has passed
  if (currentTime - lastUpdate > 20) { // 50Hz update rate
    for (int i = 0; i < 6; i++) {
      updateServoPosition(i);
    }
    lastUpdate = currentTime;
  }
}

void ServoArm::updateServoPosition(int servoIndex) {
  if (servoIndex < 0 || servoIndex >= 6) return;
  
  ServoState &state = servoStates[servoIndex];
  
  if (state.currentAngle != state.targetAngle) {
    state.isMoving = true;
    
    // Calculate step size based on movement speed
    int stepSize = servoMovementSpeed;
    int difference = state.targetAngle - state.currentAngle;
    
    if (abs(difference) <= stepSize) {
      // Close enough, move directly to target
      state.currentAngle = state.targetAngle;
      state.isMoving = false;
    } else {
      // Move one step closer to target
      if (difference > 0) {
        state.currentAngle += stepSize;
      } else {
        state.currentAngle -= stepSize;
      }
    }
    
    // Update servo hardware
    servos[servoIndex].write(state.currentAngle);
    state.lastUpdate = millis();
    
    if (DEBUG_SERVO) {
      DEBUG_PRINT("🦾 Servo " + state.name + ": ");
      DEBUG_PRINT(state.currentAngle);
      DEBUG_PRINT("° -> ");
      DEBUG_PRINTLN(state.targetAngle + "°");
    }
  } else {
    state.isMoving = false;
  }
}

void ServoArm::setServoAngle(int servoIndex, int angle) {
  if (servoIndex < 0 || servoIndex >= 6) return;
  if (!isValidAngle(angle)) return;
  if (!armEnabled) return;
  
  // Safety check
  if (!isPositionSafe(servoIndex, angle)) {
    DEBUG_PRINTLN("⚠ Unsafe servo position blocked: " + servoStates[servoIndex].name + " to " + String(angle) + "°");
    return;
  }
  
  servoStates[servoIndex].targetAngle = angle;
  
  if (DEBUG_SERVO) {
    DEBUG_PRINTLN("🎯 Setting " + servoStates[servoIndex].name + " target to " + String(angle) + "°");
  }
}

void ServoArm::setServoTarget(int servoIndex, int targetAngle) {
  setServoAngle(servoIndex, targetAngle);
}

int ServoArm::getServoAngle(int servoIndex) {
  if (servoIndex >= 0 && servoIndex < 6) {
    return servoStates[servoIndex].currentAngle;
  }
  return -1;
}

String ServoArm::getServoName(int servoIndex) {
  if (servoIndex >= 0 && servoIndex < 6) {
    return servoStates[servoIndex].name;
  }
  return "Unknown";
}

void ServoArm::moveToHome() {
  DEBUG_PRINTLN("🏠 Moving arm to home position");
  
  setServoAngle(SERVO_BASE_IDX, SERVO_BASE_DEFAULT);
  setServoAngle(SERVO_SHOULDER_IDX, SERVO_SHOULDER_DEFAULT);
  setServoAngle(SERVO_ELBOW_IDX, SERVO_ELBOW_DEFAULT);
  setServoAngle(SERVO_WRIST_ROT_IDX, SERVO_WRIST_ROT_DEFAULT);
  setServoAngle(SERVO_WRIST_TILT_IDX, SERVO_WRIST_TILT_DEFAULT);
  setServoAngle(SERVO_GRIPPER_IDX, SERVO_GRIPPER_DEFAULT);
}

void ServoArm::moveToPreset(int presetNumber) {
  DEBUG_PRINTLN("📋 Moving to preset position " + String(presetNumber));
  
  switch (presetNumber) {
    case 1: // Pickup position
      moveToPickup();
      break;
      
    case 2: // Place position
      moveToPlace();
      break;
      
    case 3: // Rest position
      moveToRest();
      break;
      
    case 4: // Extended position
      setServoAngle(SERVO_BASE_IDX, 90);
      setServoAngle(SERVO_SHOULDER_IDX, 45);
      setServoAngle(SERVO_ELBOW_IDX, 45);
      setServoAngle(SERVO_WRIST_ROT_IDX, 90);
      setServoAngle(SERVO_WRIST_TILT_IDX, 90);
      setServoAngle(SERVO_GRIPPER_IDX, 45);
      break;
      
    case 5: // Compact position
      setServoAngle(SERVO_BASE_IDX, 90);
      setServoAngle(SERVO_SHOULDER_IDX, 135);
      setServoAngle(SERVO_ELBOW_IDX, 135);
      setServoAngle(SERVO_WRIST_ROT_IDX, 90);
      setServoAngle(SERVO_WRIST_TILT_IDX, 45);
      setServoAngle(SERVO_GRIPPER_IDX, 90);
      break;
      
    default:
      moveToHome();
      break;
  }
}

void ServoArm::moveToPickup() {
  DEBUG_PRINTLN("📦 Moving to pickup position");
  
  // Sequential movement for safety
  setServoAngle(SERVO_GRIPPER_IDX, 180); // Open gripper first
  delay(500);
  setServoAngle(SERVO_SHOULDER_IDX, 60);
  setServoAngle(SERVO_ELBOW_IDX, 60);
  setServoAngle(SERVO_WRIST_TILT_IDX, 120);
}

void ServoArm::moveToPlace() {
  DEBUG_PRINTLN("📍 Moving to place position");
  
  setServoAngle(SERVO_SHOULDER_IDX, 90);
  setServoAngle(SERVO_ELBOW_IDX, 90);
  setServoAngle(SERVO_WRIST_TILT_IDX, 90);
}

void ServoArm::moveToRest() {
  DEBUG_PRINTLN("😴 Moving to rest position");
  
  setServoAngle(SERVO_BASE_IDX, 90);
  setServoAngle(SERVO_SHOULDER_IDX, 150);
  setServoAngle(SERVO_ELBOW_IDX, 150);
  setServoAngle(SERVO_WRIST_ROT_IDX, 90);
  setServoAngle(SERVO_WRIST_TILT_IDX, 30);
  setServoAngle(SERVO_GRIPPER_IDX, 90);
}

void ServoArm::openGripper() {
  DEBUG_PRINTLN("✋ Opening gripper");
  setServoAngle(SERVO_GRIPPER_IDX, 180);
}

void ServoArm::closeGripper() {
  DEBUG_PRINTLN("🤏 Closing gripper");
  setServoAngle(SERVO_GRIPPER_IDX, 0);
}

void ServoArm::setGripperPosition(int angle) {
  setServoAngle(SERVO_GRIPPER_IDX, angle);
}

void ServoArm::enableArm() {
  armEnabled = true;
  DEBUG_PRINTLN("✅ Servo arm enabled");
}

void ServoArm::disableArm() {
  armEnabled = false;
  DEBUG_PRINTLN("⏸ Servo arm disabled");
}

void ServoArm::stopAll() {
  for (int i = 0; i < 6; i++) {
    servoStates[i].targetAngle = servoStates[i].currentAngle;
    servoStates[i].isMoving = false;
  }
  DEBUG_PRINTLN("⏹ All servo movement stopped");
}

bool ServoArm::isArmEnabled() {
  return armEnabled;
}

void ServoArm::setMovementSpeed(int speed) {
  servoMovementSpeed = constrain(speed, SERVO_SPEED_SLOW, SERVO_SPEED_FAST);
  DEBUG_PRINTLN("🏃 Servo movement speed set to " + String(servoMovementSpeed));
}

int ServoArm::getMovementSpeed() {
  return servoMovementSpeed;
}

bool ServoArm::isAnyServoMoving() {
  for (int i = 0; i < 6; i++) {
    if (servoStates[i].isMoving) return true;
  }
  return false;
}

void ServoArm::waitForMovementComplete() {
  while (isAnyServoMoving()) {
    update();
    delay(20);
  }
}

void ServoArm::getStatus(String &statusString) {
  statusString = "Servos: ";
  for (int i = 0; i < 6; i++) {
    statusString += servoStates[i].name + ":" + String(servoStates[i].currentAngle) + "°";
    if (i < 5) statusString += ", ";
  }
  statusString += " | Speed: " + String(servoMovementSpeed);
  statusString += " | Enabled: " + String(armEnabled ? "YES" : "NO");
}

void ServoArm::testAllServos() {
  DEBUG_PRINTLN("🧪 Testing all servos...");
  
  for (int i = 0; i < 6; i++) {
    DEBUG_PRINTLN("Testing " + servoStates[i].name + "...");
    
    int originalAngle = servoStates[i].currentAngle;
    
    // Test movement
    setServoAngle(i, 45);
    waitForMovementComplete();
    delay(1000);
    
    setServoAngle(i, 135);
    waitForMovementComplete();
    delay(1000);
    
    // Return to original position
    setServoAngle(i, originalAngle);
    waitForMovementComplete();
    
    DEBUG_PRINTLN("✅ " + servoStates[i].name + " test complete");
  }
  
  DEBUG_PRINTLN("✅ All servo tests complete");
}

void ServoArm::calibrateServos() {
  DEBUG_PRINTLN("🔧 Calibrating servos...");
  
  // Move all servos to center position for calibration
  for (int i = 0; i < 6; i++) {
    setServoAngle(i, 90);
  }
  
  waitForMovementComplete();
  DEBUG_PRINTLN("✅ Calibration complete - all servos at 90°");
}

void ServoArm::smoothMoveTo(int servoIndex, int targetAngle, int speed) {
  if (servoIndex < 0 || servoIndex >= 6) return;
  
  int oldSpeed = servoMovementSpeed;
  setMovementSpeed(speed);
  setServoAngle(servoIndex, targetAngle);
  
  // Restore original speed after movement
  while (servoStates[servoIndex].isMoving) {
    update();
    delay(20);
  }
  setMovementSpeed(oldSpeed);
}

void ServoArm::smoothMoveAll(int angles[6], int speed) {
  int oldSpeed = servoMovementSpeed;
  setMovementSpeed(speed);
  
  for (int i = 0; i < 6; i++) {
    setServoAngle(i, angles[i]);
  }
  
  waitForMovementComplete();
  setMovementSpeed(oldSpeed);
}

bool ServoArm::isValidAngle(int angle) {
  return (angle >= SERVO_MIN_ANGLE && angle <= SERVO_MAX_ANGLE);
}

bool ServoArm::isPositionSafe(int servoIndex, int angle) {
  // Add safety checks here based on your arm's physical constraints
  // For example, prevent elbow from going too far back if shoulder is forward
  
  if (!isValidAngle(angle)) return false;
  
  // Example safety rules (customize based on your arm design):
  if (servoIndex == SERVO_ELBOW_IDX) {
    // Don't allow elbow to extend too far if shoulder is raised
    int shoulderAngle = servoStates[SERVO_SHOULDER_IDX].currentAngle;
    if (shoulderAngle < 45 && angle < 30) {
      return false; // Prevent collision with base
    }
  }
  
  return true; // Default to safe if no specific rules violated
}

void ServoArm::emergencyStop() {
  DEBUG_PRINTLN("🚨 SERVO ARM EMERGENCY STOP");
  stopAll();
  disableArm();
}

#endif // SERVO_ARM_H