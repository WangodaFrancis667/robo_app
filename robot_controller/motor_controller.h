/**********************************************************************
 *  motor_controller.h - 4-Wheel Motor Control Module
 *  Handles all motor control operations for 4WD robot
 *********************************************************************/

#ifndef MOTOR_CONTROLLER_H
#define MOTOR_CONTROLLER_H

#include "config.h"

class MotorController {
private:
  static MotorState motors[4];
  static int globalSpeedMultiplier;
  static unsigned long lastCommandTime;
  static bool safetyStopActive;
  
  // Private helper methods
  static void setIndividualMotorSpeed(int motorIndex, int speed);
  static void getMotorPins(int motorIndex, int &d0Pin, int &d1Pin, int &enablePin);
  static void updateMotorHardware(int motorIndex);
  
public:
  // Initialize motor controller
  static void init();
  
  // Update - call this in main loop
  static void update();
  
  // Movement commands
  static void moveForward(int speed);
  static void moveBackward(int speed);
  static void turnLeft(int speed);
  static void turnRight(int speed);
  static void tankDrive(int leftSpeed, int rightSpeed);
  
  // Individual motor control
  static void setMotorSpeed(int motorIndex, int speed);
  static void testMotor(int motorIndex, int speed, int duration = 2000);
  
  // System control
  static void stopAll();
  static void emergencyStop();
  static void setGlobalSpeed(int speed);
  static int getGlobalSpeed();
  
  // Status and diagnostics
  static void getStatus(String &statusString);
  static bool isAnyMotorRunning();
  static int getMotorSpeed(int motorIndex);
  static String getMotorName(int motorIndex);
  
  // Safety functions
  static void enableSafetyStop();
  static void disableSafetyStop();
  static bool isSafetyStopActive();
  static void resetCommandTimeout();
  
  // Test functions
  static void testAllMotors();
  static void testMovementPatterns();
};

// Implementation
MotorState MotorController::motors[4] = {
  {0, false, 0, "Front Left"},
  {0, false, 0, "Rear Left"},
  {0, false, 0, "Front Right"},
  {0, false, 0, "Rear Right"}
};

int MotorController::globalSpeedMultiplier = 60;
unsigned long MotorController::lastCommandTime = 0;
bool MotorController::safetyStopActive = false;

void MotorController::init() {
  DEBUG_PRINTLN("🚗 Initializing Motor Controller...");
  
  // Initialize all motor pins
  pinMode(DRIVER1_D0, OUTPUT);
  pinMode(DRIVER1_D1, OUTPUT);
  pinMode(DRIVER1_D2, OUTPUT);
  pinMode(DRIVER1_D3, OUTPUT);
  
  pinMode(DRIVER2_D0, OUTPUT);
  pinMode(DRIVER2_D1, OUTPUT);
  pinMode(DRIVER2_D2, OUTPUT);
  pinMode(DRIVER2_D3, OUTPUT);
  
  // Initialize PWM enable pins
  pinMode(DRIVER1_EN1, OUTPUT);
  pinMode(DRIVER1_EN2, OUTPUT);
  pinMode(DRIVER2_EN1, OUTPUT);
  pinMode(DRIVER2_EN2, OUTPUT);
  
  // Stop all motors initially
  stopAll();
  
  // Reset timers
  lastCommandTime = millis();
  
  DEBUG_PRINTLN("✅ Motor Controller initialized");
  DEBUG_PRINTLN("📍 Pin Configuration:");
  DEBUG_PRINTLN("   Driver 1 (Left): D0=22, D1=23, D2=24, D3=25");
  DEBUG_PRINTLN("   Driver 2 (Right): D0=26, D1=27, D2=28, D3=29");
  DEBUG_PRINTLN("   PWM Enable: EN1=2, EN2=3, EN3=4, EN4=5");
}

void MotorController::update() {
  // Check for safety timeout
  if (millis() - lastCommandTime > COMMAND_TIMEOUT && lastCommandTime != 0) {
    if (!safetyStopActive) {
      DEBUG_PRINTLN("⚠ Motor safety timeout - stopping all motors");
      stopAll();
      safetyStopActive = true;
    }
  }
  
  // Update motor states
  for (int i = 0; i < 4; i++) {
    motors[i].lastUpdate = millis();
  }
}

void MotorController::moveForward(int speed) {
  speed = CONSTRAIN_SPEED(speed);
  
  // Check collision avoidance if enabled
  extern bool checkCollisionSafety(bool movingForward);
  if (!checkCollisionSafety(true)) {
    DEBUG_PRINTLN("⚠ Forward movement blocked by collision avoidance");
    return;
  }
  
  if (DEBUG_MOTOR) {
    DEBUG_PRINTLN("⬆ Moving forward at " + String(speed) + "%");
  }
  
  setIndividualMotorSpeed(FRONT_LEFT, speed * FRONT_LEFT_DIR);
  setIndividualMotorSpeed(REAR_LEFT, speed * REAR_LEFT_DIR);
  setIndividualMotorSpeed(FRONT_RIGHT, speed * FRONT_RIGHT_DIR);
  setIndividualMotorSpeed(REAR_RIGHT, speed * REAR_RIGHT_DIR);
  
  resetCommandTimeout();
}

void MotorController::moveBackward(int speed) {
  speed = CONSTRAIN_SPEED(speed);
  
  // Check collision avoidance if enabled
  extern bool checkCollisionSafety(bool movingForward);
  if (!checkCollisionSafety(false)) {
    DEBUG_PRINTLN("⚠ Backward movement blocked by collision avoidance");
    return;
  }
  
  if (DEBUG_MOTOR) {
    DEBUG_PRINTLN("⬇ Moving backward at " + String(speed) + "%");
  }
  
  setIndividualMotorSpeed(FRONT_LEFT, -speed * FRONT_LEFT_DIR);
  setIndividualMotorSpeed(REAR_LEFT, -speed * REAR_LEFT_DIR);
  setIndividualMotorSpeed(FRONT_RIGHT, -speed * FRONT_RIGHT_DIR);
  setIndividualMotorSpeed(REAR_RIGHT, -speed * REAR_RIGHT_DIR);
  
  resetCommandTimeout();
}

void MotorController::turnLeft(int speed) {
  speed = CONSTRAIN_SPEED(speed);
  
  if (DEBUG_MOTOR) {
    DEBUG_PRINTLN("⬅ Turning left at " + String(speed) + "%");
  }
  
  setIndividualMotorSpeed(FRONT_LEFT, -speed * FRONT_LEFT_DIR);
  setIndividualMotorSpeed(REAR_LEFT, -speed * REAR_LEFT_DIR);
  setIndividualMotorSpeed(FRONT_RIGHT, speed * FRONT_RIGHT_DIR);
  setIndividualMotorSpeed(REAR_RIGHT, speed * REAR_RIGHT_DIR);
  
  resetCommandTimeout();
}

void MotorController::turnRight(int speed) {
  speed = CONSTRAIN_SPEED(speed);
  
  if (DEBUG_MOTOR) {
    DEBUG_PRINTLN("➡ Turning right at " + String(speed) + "%");
  }
  
  setIndividualMotorSpeed(FRONT_LEFT, speed * FRONT_LEFT_DIR);
  setIndividualMotorSpeed(REAR_LEFT, speed * REAR_LEFT_DIR);
  setIndividualMotorSpeed(FRONT_RIGHT, -speed * FRONT_RIGHT_DIR);
  setIndividualMotorSpeed(REAR_RIGHT, -speed * REAR_RIGHT_DIR);
  
  resetCommandTimeout();
}

void MotorController::tankDrive(int leftSpeed, int rightSpeed) {
  leftSpeed = CONSTRAIN_SPEED(leftSpeed);
  rightSpeed = CONSTRAIN_SPEED(rightSpeed);
  
  if (DEBUG_MOTOR) {
    DEBUG_PRINTLN("🎮 Tank drive - Left: " + String(leftSpeed) + "%, Right: " + String(rightSpeed) + "%");
  }
  
  setIndividualMotorSpeed(FRONT_LEFT, leftSpeed * FRONT_LEFT_DIR);
  setIndividualMotorSpeed(REAR_LEFT, leftSpeed * REAR_LEFT_DIR);
  setIndividualMotorSpeed(FRONT_RIGHT, rightSpeed * FRONT_RIGHT_DIR);
  setIndividualMotorSpeed(REAR_RIGHT, rightSpeed * REAR_RIGHT_DIR);
  
  resetCommandTimeout();
}

void MotorController::setMotorSpeed(int motorIndex, int speed) {
  if (motorIndex >= 0 && motorIndex < 4) {
    setIndividualMotorSpeed(motorIndex, speed);
    resetCommandTimeout();
  }
}

void MotorController::setIndividualMotorSpeed(int motorIndex, int speed) {
  if (motorIndex < 0 || motorIndex > 3) return;
  
  // Apply global speed multiplier
  int adjustedSpeed = (speed * globalSpeedMultiplier) / 100;
  adjustedSpeed = CONSTRAIN_SPEED(adjustedSpeed);
  
  // Apply minimum speed threshold
  if (abs(adjustedSpeed) > 0 && abs(adjustedSpeed) < MIN_SPEED_THRESHOLD) {
    adjustedSpeed = (adjustedSpeed > 0) ? MIN_SPEED_THRESHOLD : -MIN_SPEED_THRESHOLD;
  }
  
  // Update motor state
  motors[motorIndex].currentSpeed = adjustedSpeed;
  motors[motorIndex].isRunning = (adjustedSpeed != 0);
  motors[motorIndex].lastUpdate = millis();
  
  // Update hardware
  updateMotorHardware(motorIndex);
}

void MotorController::updateMotorHardware(int motorIndex) {
  int d0Pin, d1Pin, enablePin;
  getMotorPins(motorIndex, d0Pin, d1Pin, enablePin);
  
  int speed = motors[motorIndex].currentSpeed;
  
  if (speed == 0) {
    // Stop motor
    digitalWrite(d0Pin, LOW);
    digitalWrite(d1Pin, LOW);
    analogWrite(enablePin, 0);
    return;
  }
  
  // Calculate PWM value
  int pwmValue = MAP_SPEED_TO_PWM(speed);
  
  // Set direction
  if (speed > 0) {
    digitalWrite(d0Pin, HIGH);
    digitalWrite(d1Pin, LOW);
  } else {
    digitalWrite(d0Pin, LOW);
    digitalWrite(d1Pin, HIGH);
  }
  
  // Set PWM speed
  analogWrite(enablePin, pwmValue);
  
  if (DEBUG_MOTOR) {
    DEBUG_PRINT("🔧 Motor " + motors[motorIndex].name + ": ");
    DEBUG_PRINT(speed);
    DEBUG_PRINT("% -> PWM:");
    DEBUG_PRINT(pwmValue);
    DEBUG_PRINT(", DIR:");
    DEBUG_PRINTLN(speed > 0 ? "FWD" : "REV");
  }
}

void MotorController::getMotorPins(int motorIndex, int &d0Pin, int &d1Pin, int &enablePin) {
  switch (motorIndex) {
    case FRONT_LEFT:
      d0Pin = DRIVER1_D0;
      d1Pin = DRIVER1_D1;
      enablePin = DRIVER1_EN1;
      break;
    case REAR_LEFT:
      d0Pin = DRIVER1_D2;
      d1Pin = DRIVER1_D3;
      enablePin = DRIVER1_EN2;
      break;
    case FRONT_RIGHT:
      d0Pin = DRIVER2_D0;
      d1Pin = DRIVER2_D1;
      enablePin = DRIVER2_EN1;
      break;
    case REAR_RIGHT:
      d0Pin = DRIVER2_D2;
      d1Pin = DRIVER2_D3;
      enablePin = DRIVER2_EN2;
      break;
  }
}

void MotorController::stopAll() {
  for (int i = 0; i < 4; i++) {
    setIndividualMotorSpeed(i, 0);
  }
  safetyStopActive = false;
  
  if (DEBUG_MOTOR) {
    DEBUG_PRINTLN("⏹ All motors stopped");
  }
}

void MotorController::emergencyStop() {
  DEBUG_PRINTLN("🚨 EMERGENCY STOP ACTIVATED");
  stopAll();
  safetyStopActive = true;
}

void MotorController::setGlobalSpeed(int speed) {
  globalSpeedMultiplier = constrain(speed, 20, 100);
  DEBUG_PRINTLN("🚀 Global speed set to: " + String(globalSpeedMultiplier) + "%");
}

int MotorController::getGlobalSpeed() {
  return globalSpeedMultiplier;
}

void MotorController::resetCommandTimeout() {
  lastCommandTime = millis();
  safetyStopActive = false;
}

void MotorController::testMotor(int motorIndex, int speed, int duration) {
  if (motorIndex < 0 || motorIndex > 3) return;
  
  DEBUG_PRINT("🧪 Testing motor " + motors[motorIndex].name + " at " + String(speed) + "%");
  
  setIndividualMotorSpeed(motorIndex, speed);
  delay(duration);
  setIndividualMotorSpeed(motorIndex, 0);
  delay(500);
  
  DEBUG_PRINTLN(" - Complete");
}

void MotorController::testAllMotors() {
  DEBUG_PRINTLN("🧪 Starting motor test sequence...");
  
  int testSpeed = 50;
  
  for (int i = 0; i < 4; i++) {
    DEBUG_PRINTLN("Testing " + motors[i].name + "...");
    testMotor(i, testSpeed, 1500);
    testMotor(i, -testSpeed, 1500);
  }
  
  DEBUG_PRINTLN("✅ Motor test sequence complete");
}

bool MotorController::isAnyMotorRunning() {
  for (int i = 0; i < 4; i++) {
    if (motors[i].isRunning) return true;
  }
  return false;
}

int MotorController::getMotorSpeed(int motorIndex) {
  if (motorIndex >= 0 && motorIndex < 4) {
    return motors[motorIndex].currentSpeed;
  }
  return 0;
}

String MotorController::getMotorName(int motorIndex) {
  if (motorIndex >= 0 && motorIndex < 4) {
    return motors[motorIndex].name;
  }
  return "Unknown";
}

void MotorController::getStatus(String &statusString) {
  statusString = "Motors: ";
  for (int i = 0; i < 4; i++) {
    statusString += motors[i].name + ":" + String(motors[i].currentSpeed) + "%";
    if (i < 3) statusString += ", ";
  }
  statusString += " | Speed: " + String(globalSpeedMultiplier) + "%";
  statusString += " | Safety: " + String(safetyStopActive ? "ACTIVE" : "OK");
}

void MotorController::enableSafetyStop() {
  safetyStopActive = true;
}

void MotorController::disableSafetyStop() {
  safetyStopActive = false;
}

bool MotorController::isSafetyStopActive() {
  return safetyStopActive;
}

void MotorController::testMovementPatterns() {
  DEBUG_PRINTLN("🧪 Testing movement patterns...");
  
  int testSpeed = 40;
  int testDuration = 2000;
  
  DEBUG_PRINTLN("  → Forward");
  moveForward(testSpeed);
  delay(testDuration);
  stopAll();
  delay(500);
  
  DEBUG_PRINTLN("  → Backward");
  moveBackward(testSpeed);
  delay(testDuration);
  stopAll();
  delay(500);
  
  DEBUG_PRINTLN("  → Left Turn");
  turnLeft(testSpeed);
  delay(testDuration);
  stopAll();
  delay(500);
  
  DEBUG_PRINTLN("  → Right Turn");
  turnRight(testSpeed);
  delay(testDuration);
  stopAll();
  delay(500);
  
  DEBUG_PRINTLN("  → Tank Drive Test");
  tankDrive(testSpeed, -testSpeed);
  delay(testDuration);
  stopAll();
  
  DEBUG_PRINTLN("✅ Movement pattern test complete");
}

#endif // MOTOR_CONTROLLER_H
