/**********************************************************************
 *  servo_arm.h - 6-Servo Arm Control Module
 *  Handles all servo arm operations and preset positions
 *********************************************************************/

#ifndef SERVO_ARM_H
#define SERVO_ARM_H

#include "config.h"
#include "utils.h"
#ifdef ESP32
  #include <ESP32Servo.h>
#else
  #include <Servo.h>
#endif

class ServoArm {
private:
  static Servo servos[6];
  static ServoState servoStates[6];
  static int servoMovementSpeed;
  static bool armEnabled;

public:
  static void init();
  static void update();
  static void setServoAngle(int servoIndex, int angle);
  static int getServoAngle(int servoIndex);
  static void moveToHome();
  static void moveToPreset(int presetNumber);
  static void openGripper();
  static void closeGripper();
  static void enableArm();
  static void disableArm();
  static void stopAll();
  static void setMovementSpeed(int speed);
  static void getStatus(String &statusString);
  static void getStatus(char *buffer, size_t bufferSize);
  static void testAllServos();
  static void calibrateServos();
  static void emergencyStop();
};

Servo ServoArm::servos[6];
ServoState ServoArm::servoStates[6] = {
    {SERVO_BASE_DEFAULT, SERVO_BASE_DEFAULT, false, 0},
    {SERVO_SHOULDER_DEFAULT, SERVO_SHOULDER_DEFAULT, false, 0},
    {SERVO_ELBOW_DEFAULT, SERVO_ELBOW_DEFAULT, false, 0},
    {SERVO_WRIST_ROT_DEFAULT, SERVO_WRIST_ROT_DEFAULT, false, 0},
    {SERVO_WRIST_TILT_DEFAULT, SERVO_WRIST_TILT_DEFAULT, false, 0},
    {SERVO_GRIPPER_DEFAULT, SERVO_GRIPPER_DEFAULT, false, 0}};

int ServoArm::servoMovementSpeed = SERVO_SPEED_NORMAL;
bool ServoArm::armEnabled = false;

void ServoArm::init() {
  DEBUG_PRINTLN("🦾 Initializing Servo Arm...");

  servos[0].attach(SERVO_BASE);
  servos[1].attach(SERVO_SHOULDER);
  servos[2].attach(SERVO_ELBOW);
  servos[3].attach(SERVO_WRIST_ROT);
  servos[4].attach(SERVO_WRIST_TILT);
  servos[5].attach(SERVO_GRIPPER);

  moveToHome();
  armEnabled = true;

  DEBUG_PRINTLN("✅ Servo Arm initialized");
}

void ServoArm::update() {
  if (!armEnabled)
    return;

  for (int i = 0; i < 6; i++) {
    if (servoStates[i].currentAngle != servoStates[i].targetAngle) {
      int diff = servoStates[i].targetAngle - servoStates[i].currentAngle;
      if (abs(diff) <= servoMovementSpeed) {
        servoStates[i].currentAngle = servoStates[i].targetAngle;
        servoStates[i].isMoving = false;
      } else {
        servoStates[i].currentAngle +=
            (diff > 0) ? servoMovementSpeed : -servoMovementSpeed;
        servoStates[i].isMoving = true;
      }
      servos[i].write(servoStates[i].currentAngle);

      if (DEBUG_SERVO) {
        DEBUG_PRINT_P("🦾 Servo ");
        DEBUG_PRINT(getServoName(i));
        DEBUG_PRINT_P(": ");
        DEBUG_PRINT_VAL("", servoStates[i].currentAngle);
        DEBUG_PRINTLN_P("°");
      }
    }
  }
}

void ServoArm::setServoAngle(int servoIndex, int angle) {
  if (servoIndex < 0 || servoIndex >= 6 || !armEnabled)
    return;
  angle = CONSTRAIN_ANGLE(angle);
  servoStates[servoIndex].targetAngle = angle;

  if (DEBUG_SERVO) {
    DEBUG_PRINT_P("🎯 Setting ");
    DEBUG_PRINT(getServoName(servoIndex));
    DEBUG_PRINT_P(" target to ");
    DEBUG_PRINT_VAL("", angle);
    DEBUG_PRINTLN_P("°");
  }
}

int ServoArm::getServoAngle(int servoIndex) {
  if (servoIndex >= 0 && servoIndex < 6) {
    return servoStates[servoIndex].currentAngle;
  }
  return -1;
}

void ServoArm::moveToHome() {
  DEBUG_PRINTLN("🏠 Moving arm to home position");
  // for (int i = 0; i < 6; i++) {
  //   setServoAngle(i, 90);
  // }
  setServoAngle(0, 90);
  setServoAngle(1, 90);
  setServoAngle(2, 90);
  setServoAngle(3, 90);
  setServoAngle(4, 40);
  setServoAngle(5, 90);
}

void ServoArm::moveToPreset(int presetNumber) {
  DEBUG_PRINTLN("📋 Moving to preset position " + String(presetNumber));

  switch (presetNumber) {
  case 1: // Pickup
    setServoAngle(0, 90);
    setServoAngle(1, 60);
    setServoAngle(2, 60);
    setServoAngle(5, 180);
    break;
  case 2: // Place
    setServoAngle(0, 90);
    setServoAngle(1, 90);
    setServoAngle(2, 90);
    break;
  case 3: // Rest
    setServoAngle(0, 90);
    setServoAngle(1, 150);
    setServoAngle(2, 150);
    break;
  default:
    moveToHome();
    break;
  }
}

void ServoArm::openGripper() {
  DEBUG_PRINTLN("✋ Opening gripper");
  setServoAngle(SERVO_GRIPPER_IDX, 180);
}

void ServoArm::closeGripper() {
  DEBUG_PRINTLN("🤏 Closing gripper");
  setServoAngle(SERVO_GRIPPER_IDX, 0);
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

void ServoArm::setMovementSpeed(int speed) {
  servoMovementSpeed = constrain(speed, SERVO_SPEED_SLOW, SERVO_SPEED_FAST);
  DEBUG_PRINTLN("🏃 Servo movement speed set to " + String(servoMovementSpeed));
}

void ServoArm::getStatus(String &statusString) {
  statusString = "Servos: ";
  for (int i = 0; i < 6; i++) {
    statusString += String(getServoName(i)) + ":" +
                    String(servoStates[i].currentAngle) + "°";
    if (i < 5)
      statusString += ", ";
  }
  statusString += " | Speed: " + String(servoMovementSpeed);
  statusString += " | Enabled: " + String(armEnabled ? "YES" : "NO");
}

void ServoArm::getStatus(char *buffer, size_t bufferSize) {
  char angles[48];
  snprintf_P(angles, sizeof(angles), PSTR("%d,%d,%d,%d,%d,%d"),
             servoStates[0].currentAngle, servoStates[1].currentAngle,
             servoStates[2].currentAngle, servoStates[3].currentAngle,
             servoStates[4].currentAngle, servoStates[5].currentAngle);

  snprintf_P(buffer, bufferSize, PSTR("Servos:%s|Speed:%d|Enabled:%s"), angles,
             servoMovementSpeed, armEnabled ? "YES" : "NO");
}

void ServoArm::testAllServos() {
  DEBUG_PRINTLN_P("🧪 Testing all servos...");

  for (int i = 0; i < 6; i++) {
    DEBUG_PRINT_P("Testing ");
    DEBUG_PRINT(getServoName(i));
    DEBUG_PRINTLN_P("...");

    int originalAngle = servoStates[i].currentAngle;

    setServoAngle(i, 45);
    delay(1000);
    setServoAngle(i, 135);
    delay(1000);
    setServoAngle(i, originalAngle);
    delay(500);

    DEBUG_PRINT_P("✅ ");
    DEBUG_PRINT(getServoName(i));
    DEBUG_PRINTLN_P(" test complete");
  }

  DEBUG_PRINTLN_P("✅ All servo tests complete");
}

void ServoArm::calibrateServos() {
  DEBUG_PRINTLN("🔧 Calibrating servos...");
  for (int i = 0; i < 6; i++) {
    setServoAngle(i, 90);
  }
  DEBUG_PRINTLN("✅ Calibration complete - all servos at 90°");
}

void ServoArm::emergencyStop() {
  DEBUG_PRINTLN("🚨 SERVO ARM EMERGENCY STOP");
  stopAll();
  disableArm();
}

#endif // SERVO_ARM_H