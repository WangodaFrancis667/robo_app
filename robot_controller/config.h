/**********************************************************************
 *  config.h - System Configuration and Constants
 *  Contains all pin definitions, constants, and configuration settings
 *********************************************************************/

#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>
#include "utils.h"

// ========== SYSTEM CONFIGURATION ==========

// Version information
#define FIRMWARE_VERSION "2.0"
#define HARDWARE_VERSION "Arduino Mega 2560"

// Debug settings
#define DEBUG_ENABLED true
#define DEBUG_MOTOR true
#define DEBUG_SERVO true
#define DEBUG_BLUETOOTH true

// Safety settings
#define COMMAND_TIMEOUT 2000        // 2 seconds timeout
#define SAFETY_STOP_TIMEOUT 5000    // 5 seconds emergency stop
#define MIN_SPEED_THRESHOLD 20      // Minimum motor speed
#define MAX_SPEED_LIMIT 100         // Maximum motor speed

// ========== PIN DEFINITIONS ==========

// Status LED
#define STATUS_LED 13

// Bluetooth Module (HC-05/HC-06)
#define BLUETOOTH_RX 19  // Pin 19 (Serial1 RX)
#define BLUETOOTH_TX 18  // Pin 18 (Serial1 TX)
#define BLUETOOTH_BAUD 9600

// Motor Driver Pins - Driver Board 1 (Left Motors)
#define DRIVER1_D0 22    // Front Left Motor Control 1
#define DRIVER1_D1 23    // Front Left Motor Control 2
#define DRIVER1_D2 24    // Rear Left Motor Control 1
#define DRIVER1_D3 25    // Rear Left Motor Control 2

// Motor Driver Pins - Driver Board 2 (Right Motors)
#define DRIVER2_D0 26    // Front Right Motor Control 1
#define DRIVER2_D1 27    // Front Right Motor Control 2
#define DRIVER2_D2 28    // Rear Right Motor Control 1
#define DRIVER2_D3 29    // Rear Right Motor Control 2

// PWM Enable pins for motor drivers
#define DRIVER1_EN1 2    // PWM for Front Left motor
#define DRIVER1_EN2 3    // PWM for Rear Left motor
#define DRIVER2_EN1 4    // PWM for Front Right motor
#define DRIVER2_EN2 5    // PWM for Rear Right motor

// Servo Arm Pins (6 servos)
#define SERVO_BASE 6     // Base rotation servo
#define SERVO_SHOULDER 7 // Shoulder servo
#define SERVO_ELBOW 8    // Elbow servo
#define SERVO_WRIST_ROT 9   // Wrist rotation servo
#define SERVO_WRIST_TILT 10 // Wrist tilt servo
#define SERVO_GRIPPER 11    // Gripper servo

// Emergency stop button (optional)
#define EMERGENCY_STOP_PIN 12

// ========== MOTOR CONFIGURATION ==========

// Motor indices
#define FRONT_LEFT  0
#define REAR_LEFT   1
#define FRONT_RIGHT 2
#define REAR_RIGHT  3

// Motor direction correction (set to -1 if motor runs backwards)
#define FRONT_LEFT_DIR 1
#define REAR_LEFT_DIR 1
#define FRONT_RIGHT_DIR -1
#define REAR_RIGHT_DIR -1

// ========== SERVO CONFIGURATION ==========

// Servo indices
#define SERVO_BASE_IDX 0
#define SERVO_SHOULDER_IDX 1
#define SERVO_ELBOW_IDX 2
#define SERVO_WRIST_ROT_IDX 3
#define SERVO_WRIST_TILT_IDX 4
#define SERVO_GRIPPER_IDX 5

// Servo angle limits (degrees)
#define SERVO_MIN_ANGLE 0
#define SERVO_MAX_ANGLE 180

// Servo default positions
#define SERVO_BASE_DEFAULT 90
#define SERVO_SHOULDER_DEFAULT 90
#define SERVO_ELBOW_DEFAULT 90
#define SERVO_WRIST_ROT_DEFAULT 90
#define SERVO_WRIST_TILT_DEFAULT 90
#define SERVO_GRIPPER_DEFAULT 90

// Servo movement speed (degrees per update)
#define SERVO_SPEED_SLOW 1
#define SERVO_SPEED_NORMAL 3
#define SERVO_SPEED_FAST 5

// ========== SYSTEM STRUCTURES ==========

// System state structure
struct SystemState {
  bool isReady;
  unsigned long startTime;
  unsigned long lastCommand;
  bool emergencyStop;
  int globalSpeedMultiplier;
  bool debugMode;
};

// Motor state structure
struct MotorState {
  int currentSpeed;
  bool isRunning;
  unsigned long lastUpdate;
  String name;
};

// Servo state structure
struct ServoState {
  int currentAngle;
  int targetAngle;
  bool isMoving;
  unsigned long lastUpdate;
  String name;
};

// Command structure
struct Command {
  String type;
  String parameter;
  int value1;
  int value2;
  unsigned long timestamp;
};

// ========== UTILITY MACROS ==========

#define CONSTRAIN_SPEED(speed) constrainSpeed(speed)
#define CONSTRAIN_ANGLE(angle) constrainAngle(angle)
#define MAP_SPEED_TO_PWM(speed) mapSpeedToPWM(speed)

// Debug printing macros
#if DEBUG_ENABLED
  #define DEBUG_PRINT(x) Serial.print(x)
  #define DEBUG_PRINTLN(x) Serial.println(x)
#else
  #define DEBUG_PRINT(x)
  #define DEBUG_PRINTLN(x)
#endif

// ========== FORWARD DECLARATIONS ==========

// Forward declarations to avoid circular dependencies
class BluetoothHandler;
class MotorController;
class ServoArm;
class CommandProcessor;
class SystemStatus;

// ========== COMMAND DEFINITIONS ==========

// Motor commands
#define CMD_FORWARD "FORWARD"
#define CMD_BACKWARD "BACKWARD"
#define CMD_LEFT "LEFT"
#define CMD_RIGHT "RIGHT"
#define CMD_TANK "TANK"
#define CMD_STOP "STOP"

// Servo commands
#define CMD_ARM_HOME "ARM_HOME"
#define CMD_ARM_PRESET "ARM_PRESET"
#define CMD_SERVO_MOVE "SERVO"
#define CMD_GRIPPER_OPEN "GRIPPER_OPEN"
#define CMD_GRIPPER_CLOSE "GRIPPER_CLOSE"

// System commands
#define CMD_STATUS "STATUS"
#define CMD_SPEED "SPEED"
#define CMD_DEBUG "DEBUG"
#define CMD_EMERGENCY "EMERGENCY"
#define CMD_PING "PING"

// Response codes
#define RESP_OK "OK"
#define RESP_ERROR "ERROR"
#define RESP_PONG "PONG"

#endif // CONFIG_H