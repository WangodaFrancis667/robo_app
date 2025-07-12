void CommandProcessor::sendCommandHelp() {
  BluetoothHandler::sendMessage("=== ROBOT COMMAND HELP ===");
  BluetoothHandler::sendMessage("MOTOR COMMANDS:");
  BluetoothHandler::sendMessage("  FORWARD:speed    - Move forward (0-100)");
  BluetoothHandler::sendMessage("  BACKWARD:speed   - Move backward (0-100)");
  BluetoothHandler::sendMessage("  LEFT:speed       - Turn left (0-100)");
  BluetoothHandler::sendMessage("  RIGHT:speed      - Turn right (0-100)");
  BluetoothHandler::sendMessage("  TANK:left,right  - Tank drive (-100 to 100)");
  BluetoothHandler::sendMessage("  STOP             - Stop all motors");
  BluetoothHandler::sendMessage("");
  BluetoothHandler::sendMessage("SERVO ARM COMMANDS:");
  BluetoothHandler::sendMessage("  ARM_HOME         - Move arm to home position");
  BluetoothHandler::sendMessage("  ARM_PRESET:1-5   - Move to preset position");
  BluetoothHandler::sendMessage("  SERVO1:angle     - Control base servo (0-180)");
  BluetoothHandler::sendMessage("  SERVO2:angle     - Control shoulder servo");
  BluetoothHandler::sendMessage("  SERVO3:angle     - Control elbow servo");
  BluetoothHandler::sendMessage("  SERVO4:angle     - Control wrist rotation");
  BluetoothHandler::sendMessage("  SERVO5:angle     - Control wrist tilt");
  BluetoothHandler::sendMessage("  SERVO6:angle     - Control gripper");
  BluetoothHandler::sendMessage("  GRIPPER_OPEN     - Open gripper");
  BluetoothHandler::sendMessage("  GRIPPER_CLOSE    - Close gripper");
  BluetoothHandler::sendMessage("");
  BluetoothHandler::sendMessage("SENSOR COMMANDS:");
  BluetoothHandler::sendMessage("  SENSOR_STATUS    - Get current sensor status");
  BluetoothHandler::sendMessage("  SENSOR_DETAILED  - Get detailed sensor data");
  BluetoothHandler::sendMessage("  SENSORS_ENABLE   - Enable collision avoidance");
  BluetoothHandler::sendMessage("  SENSORS_DISABLE  - Disable collision avoidance");
  BluetoothHandler::sendMessage("  COLLISION_DIST:cm- Set collision distance");
  BluetoothHandler::sendMessage("  TEST_SENSORS     - Test all sensors");
  BluetoothHandler::sendMessage("  CALIBRATE_SENSORS- Calibrate sensors");
  BluetoothHandler::sendMessage("");
  BluetoothHandler::sendMessage("SYSTEM COMMANDS:");
  BluetoothHandler::sendMessage("  STATUS           - Get system status");
  BluetoothHandler::sendMessage("  SPEED:value      - Set motor speed (20-100)");
  BluetoothHandler::sendMessage("  SERVO_SPEED:val  - Set servo speed (1-5)");
  BluetoothHandler::sendMessage("  DEBUG:0/1        - Toggle debug mode");
  BluetoothHandler::sendMessage("  EMERGENCY        - Emergency stop all");
  BluetoothHandler::sendMessage("  TEST_MOTORS      - Test all motors");
  BluetoothHandler::sendMessage("  TEST_SERVOS      - Test all servos");
  BluetoothHandler::sendMessage("  CALIBRATE        - Calibrate servos");
  BluetoothHandler::sendMessage("  PING             - Connection test");/**********************************************************************
 *  command_processor.h - Command Processing System
 *  Handles parsing and execution of all robot commands
 *********************************************************************/

#ifndef COMMAND_PROCESSOR_H
#define COMMAND_PROCESSOR_H

#include "config.h"
#include "bluetooth_handler.h"
#include "motor_controller.h"
#include "servo_arm.h"
#include "system_status.h"

class CommandProcessor {
private:
  static Command commandQueue[10];
  static int queueHead;
  static int queueTail;
  static int queueSize;
  static unsigned long lastProcessTime;
  
  // Private helper methods
  static bool parseCommand(const String& input, Command& cmd);
  static void executeCommand(const Command& cmd);
  static bool isQueueFull();
  static bool isQueueEmpty();
  static void processMotorCommand(const Command& cmd);
  static void processServoCommand(const Command& cmd);
  static void processSystemCommand(const Command& cmd);
  
public:
  // Initialize command processor
  static void init();
  
  // Add command to queue
  static bool addCommand(const String& commandString);
  
  // Process command queue
  static void processQueue();
  
  // Process single command immediately
  static void processImmediate(const String& commandString);
  
  // Queue management
  static void clearQueue();
  static int getQueueCount();
  static void getQueueStatus(String& status);
  
  // Command validation
  static bool isValidCommand(const String& commandString);
  static void sendCommandHelp();
};

// Implementation
Command CommandProcessor::commandQueue[10];
int CommandProcessor::queueHead = 0;
int CommandProcessor::queueTail = 0;
int CommandProcessor::queueSize = 0;
unsigned long CommandProcessor::lastProcessTime = 0;

void CommandProcessor::init() {
  DEBUG_PRINTLN("📋 Initializing Command Processor...");
  
  // Clear queue
  clearQueue();
  lastProcessTime = millis();
  
  DEBUG_PRINTLN("✅ Command Processor initialized");
}

bool CommandProcessor::addCommand(const String& commandString) {
  if (isQueueFull()) {
    DEBUG_PRINTLN("⚠ Command queue full, dropping command");
    BluetoothHandler::sendMessage("ERROR_QUEUE_FULL");
    return false;
  }
  
  Command cmd;
  if (!parseCommand(commandString, cmd)) {
    DEBUG_PRINTLN("❌ Invalid command format: " + commandString);
    BluetoothHandler::sendResponse(commandString, false);
    return false;
  }
  
  // Add to queue
  commandQueue[queueTail] = cmd;
  queueTail = (queueTail + 1) % 10;
  queueSize++;
  
  DEBUG_PRINTLN("📥 Command queued: " + cmd.type);
  return true;
}

void CommandProcessor::processQueue() {
  // Process one command per loop to avoid blocking
  if (!isQueueEmpty() && (millis() - lastProcessTime > 10)) {
    Command cmd = commandQueue[queueHead];
    queueHead = (queueHead + 1) % 10;
    queueSize--;
    
    executeCommand(cmd);
    lastProcessTime = millis();
  }
}

void CommandProcessor::processImmediate(const String& commandString) {
  Command cmd;
  if (parseCommand(commandString, cmd)) {
    executeCommand(cmd);
  }
}

bool CommandProcessor::parseCommand(const String& input, Command& cmd) {
  String cleanInput = input;
  cleanInput.trim();
  cleanInput.toUpperCase();
  
  cmd.timestamp = millis();
  
  // Handle commands with parameters
  int colonIndex = cleanInput.indexOf(':');
  int commaIndex = cleanInput.indexOf(',');
  
  if (colonIndex > 0) {
    cmd.type = cleanInput.substring(0, colonIndex);
    String params = cleanInput.substring(colonIndex + 1);
    
    if (commaIndex > colonIndex) {
      // Two parameters (e.g., TANK:50,30)
      cmd.parameter = params.substring(0, commaIndex - colonIndex - 1);
      cmd.value1 = params.substring(0, commaIndex - colonIndex - 1).toInt();
      cmd.value2 = params.substring(commaIndex - colonIndex).toInt();
    } else {
      // One parameter (e.g., FORWARD:50)
      cmd.parameter = params;
      cmd.value1 = params.toInt();
      cmd.value2 = 0;
    }
  } else {
    // No parameters (e.g., STOP, HOME)
    cmd.type = cleanInput;
    cmd.parameter = "";
    cmd.value1 = 0;
    cmd.value2 = 0;
  }
  
  return true;
}

void CommandProcessor::executeCommand(const Command& cmd) {
  DEBUG_PRINTLN("⚡ Executing: " + cmd.type);
  
  // Route command to appropriate subsystem
  if (cmd.type == CMD_FORWARD || cmd.type == CMD_BACKWARD || 
      cmd.type == CMD_LEFT || cmd.type == CMD_RIGHT || 
      cmd.type == CMD_TANK || cmd.type == CMD_STOP) {
    processMotorCommand(cmd);
    
  } else if (cmd.type.startsWith("SERVO") || cmd.type.startsWith("ARM") || 
             cmd.type.startsWith("GRIPPER")) {
    processServoCommand(cmd);
    
  } else {
    processSystemCommand(cmd);
  }
}

void CommandProcessor::processMotorCommand(const Command& cmd) {
  // Check collision avoidance before executing motor commands
  if (!CollisionAvoidance::isMovementSafe(cmd.type, cmd.value1)) {
    BluetoothHandler::sendMessage("BLOCKED_BY_COLLISION_AVOIDANCE:" + cmd.type);
    BluetoothHandler::sendResponse(cmd.type, false);
    return;
  }
  
  if (cmd.type == CMD_FORWARD) {
    int speed = constrain(cmd.value1, 0, 100);
    // Apply collision avoidance speed adjustment
    speed = CollisionAvoidance::adjustSpeedForSafety(speed, true);
    MotorController::moveForward(speed);
    BluetoothHandler::sendResponse(CMD_FORWARD);
    
  } else if (cmd.type == CMD_BACKWARD) {
    int speed = constrain(cmd.value1, 0, 100);
    // Apply collision avoidance speed adjustment
    speed = CollisionAvoidance::adjustSpeedForSafety(speed, false);
    MotorController::moveBackward(speed);
    BluetoothHandler::sendResponse(CMD_BACKWARD);
    
  } else if (cmd.type == CMD_LEFT) {
    int speed = constrain(cmd.value1, 0, 100);
    MotorController::turnLeft(speed);
    BluetoothHandler::sendResponse(CMD_LEFT);
    
  } else if (cmd.type == CMD_RIGHT) {
    int speed = constrain(cmd.value1, 0, 100);
    MotorController::turnRight(speed);
    BluetoothHandler::sendResponse(CMD_RIGHT);
    
  } else if (cmd.type == CMD_TANK) {
    int leftSpeed = constrain(cmd.value1, -100, 100);
    int rightSpeed = constrain(cmd.value2, -100, 100);
    MotorController::tankDrive(leftSpeed, rightSpeed);
    BluetoothHandler::sendResponse(CMD_TANK);
    
  } else if (cmd.type == CMD_STOP) {
    MotorController::stopAll();
    BluetoothHandler::sendResponse(CMD_STOP);
  }
}

void CommandProcessor::processServoCommand(const Command& cmd) {
  if (cmd.type == CMD_ARM_HOME) {
    ServoArm::moveToHome();
    BluetoothHandler::sendResponse(CMD_ARM_HOME);
    
  } else if (cmd.type == CMD_ARM_PRESET) {
    int preset = constrain(cmd.value1, 1, 5);
    ServoArm::moveToPreset(preset);
    BluetoothHandler::sendResponse(CMD_ARM_PRESET);
    
  } else if (cmd.type == CMD_GRIPPER_OPEN) {
    ServoArm::openGripper();
    BluetoothHandler::sendResponse(CMD_GRIPPER_OPEN);
    
  } else if (cmd.type == CMD_GRIPPER_CLOSE) {
    ServoArm::closeGripper();
    BluetoothHandler::sendResponse(CMD_GRIPPER_CLOSE);
    
  } else if (cmd.type.startsWith("SERVO")) {
    // Parse servo command (e.g., SERVO1:90, SERVO_BASE:45)
    int servoIndex = -1;
    
    if (cmd.type == "SERVO1" || cmd.type == "SERVO_BASE") {
      servoIndex = SERVO_BASE_IDX;
    } else if (cmd.type == "SERVO2" || cmd.type == "SERVO_SHOULDER") {
      servoIndex = SERVO_SHOULDER_IDX;
    } else if (cmd.type == "SERVO3" || cmd.type == "SERVO_ELBOW") {
      servoIndex = SERVO_ELBOW_IDX;
    } else if (cmd.type == "SERVO4" || cmd.type == "SERVO_WRIST_ROT") {
      servoIndex = SERVO_WRIST_ROT_IDX;
    } else if (cmd.type == "SERVO5" || cmd.type == "SERVO_WRIST_TILT") {
      servoIndex = SERVO_WRIST_TILT_IDX;
    } else if (cmd.type == "SERVO6" || cmd.type == "SERVO_GRIPPER") {
      servoIndex = SERVO_GRIPPER_IDX;
    }
    
    if (servoIndex >= 0) {
      int angle = constrain(cmd.value1, SERVO_MIN_ANGLE, SERVO_MAX_ANGLE);
      ServoArm::setServoAngle(servoIndex, angle);
      BluetoothHandler::sendResponse(cmd.type);
    } else {
      BluetoothHandler::sendResponse(cmd.type, false);
    }
  }
}

void CommandProcessor::processSystemCommand(const Command& cmd) {
  if (cmd.type == CMD_STATUS) {
    String motorStatus, servoStatus, systemStatus;
    MotorController::getStatus(motorStatus);
    ServoArm::getStatus(servoStatus);
    SystemStatus::getStatus(systemStatus);
    
    BluetoothHandler::sendMessage("STATUS_MOTORS:" + motorStatus);
    BluetoothHandler::sendMessage("STATUS_SERVOS:" + servoStatus);
    BluetoothHandler::sendMessage("STATUS_SYSTEM:" + systemStatus);
    BluetoothHandler::sendResponse(CMD_STATUS);
    
  } else if (cmd.type == CMD_SPEED) {
    int speed = constrain(cmd.value1, 20, 100);
    MotorController::setGlobalSpeed(speed);
    BluetoothHandler::sendMessage("SPEED_SET:" + String(speed));
    BluetoothHandler::sendResponse(CMD_SPEED);
    
  } else if (cmd.type == CMD_DEBUG) {
    // Toggle debug mode
    SystemStatus::setDebugMode(cmd.value1 == 1);
    BluetoothHandler::sendMessage("DEBUG_MODE:" + String(cmd.value1));
    BluetoothHandler::sendResponse(CMD_DEBUG);
    
  } else if (cmd.type == CMD_EMERGENCY) {
    MotorController::emergencyStop();
    ServoArm::emergencyStop();
    SystemStatus::setEmergencyStop(true);
    BluetoothHandler::sendMessage("EMERGENCY_STOP_ACTIVATED");
    BluetoothHandler::sendResponse(CMD_EMERGENCY);
    
  } else if (cmd.type == CMD_PING) {
    BluetoothHandler::sendMessage(RESP_PONG);
    
  } else if (cmd.type == "HELP") {
    sendCommandHelp();
    BluetoothHandler::sendResponse("HELP");
    
  } else if (cmd.type == "TEST_MOTORS") {
    MotorController::testAllMotors();
    BluetoothHandler::sendResponse("TEST_MOTORS");
    
  } else if (cmd.type == "TEST_SERVOS") {
    ServoArm::testAllServos();
    BluetoothHandler::sendResponse("TEST_SERVOS");
    
  } else if (cmd.type == "CALIBRATE") {
    ServoArm::calibrateServos();
    BluetoothHandler::sendResponse("CALIBRATE");
    
  } else if (cmd.type == "SERVO_SPEED") {
    int speed = constrain(cmd.value1, SERVO_SPEED_SLOW, SERVO_SPEED_FAST);
    ServoArm::setMovementSpeed(speed);
    BluetoothHandler::sendMessage("SERVO_SPEED_SET:" + String(speed));
    BluetoothHandler::sendResponse("SERVO_SPEED");
    
  } else if (cmd.type == "ARM_ENABLE") {
    ServoArm::enableArm();
    BluetoothHandler::sendResponse("ARM_ENABLE");
    
  } else if (cmd.type == "ARM_DISABLE") {
    ServoArm::disableArm();
    BluetoothHandler::sendResponse("ARM_DISABLE");
    
  } else if (cmd.type == "RESET") {
    SystemStatus::resetSystem();
    BluetoothHandler::sendResponse("RESET");
    
  } else if (cmd.type == CMD_SENSOR_STATUS) {
    SensorStatusManager::sendStatusNow();
    BluetoothHandler::sendResponse(CMD_SENSOR_STATUS);
    
  } else if (cmd.type == CMD_SENSORS_ENABLE) {
    SensorManager::enableSensors();
    CollisionAvoidance::enable();
    BluetoothHandler::sendResponse(CMD_SENSORS_ENABLE);
    
  } else if (cmd.type == CMD_SENSORS_DISABLE) {
    SensorManager::disableSensors();
    CollisionAvoidance::disable();
    BluetoothHandler::sendResponse(CMD_SENSORS_DISABLE);
    
  } else if (cmd.type == CMD_COLLISION_DISTANCE) {
    float distance = constrain(cmd.value1, 5, 100);
    SensorManager::setCollisionDistance(distance);
    BluetoothHandler::sendMessage("COLLISION_DISTANCE_SET:" + String(distance));
    BluetoothHandler::sendResponse(CMD_COLLISION_DISTANCE);
    
  } else if (cmd.type == "COLLISION_AGGRESSIVENESS") {
    int level = constrain(cmd.value1, 1, 3);
    CollisionAvoidance::setAggressiveness(level);
    BluetoothHandler::sendMessage("AGGRESSIVENESS_SET:" + String(level));
    BluetoothHandler::sendResponse("COLLISION_AGGRESSIVENESS");
    
  } else if (cmd.type == "SENSOR_DETAILED") {
    SensorStatusManager::sendDetailedStatus();
    BluetoothHandler::sendResponse("SENSOR_DETAILED");
    
  } else if (cmd.type == "TEST_SENSORS") {
    SensorManager::testSensors();
    BluetoothHandler::sendResponse("TEST_SENSORS");
    
  } else if (cmd.type == "CALIBRATE_SENSORS") {
    SensorManager::calibrateSensors();
    BluetoothHandler::sendResponse("CALIBRATE_SENSORS");
    
  } else {
    DEBUG_PRINTLN("❌ Unknown command: " + cmd.type);
    BluetoothHandler::sendMessage("ERROR_UNKNOWN_COMMAND:" + cmd.type);
  }
}

void CommandProcessor::clearQueue() {
  queueHead = 0;
  queueTail = 0;
  queueSize = 0;
  DEBUG_PRINTLN("🗑 Command queue cleared");
}

int CommandProcessor::getQueueCount() {
  return queueSize;
}

void CommandProcessor::getQueueStatus(String& status) {
  status = "Queue: " + String(queueSize) + "/10 commands";
}

bool CommandProcessor::isQueueFull() {
  return queueSize >= 10;
}

bool CommandProcessor::isQueueEmpty() {
  return queueSize == 0;
}

bool CommandProcessor::isValidCommand(const String& commandString) {
  Command cmd;
  return parseCommand(commandString, cmd);
}

void CommandProcessor::sendCommandHelp() {
  BluetoothHandler::sendMessage("=== ROBOT COMMAND HELP ===");
  BluetoothHandler::sendMessage("MOTOR COMMANDS:");
  BluetoothHandler::sendMessage("  FORWARD:speed    - Move forward (0-100)");
  BluetoothHandler::sendMessage("  BACKWARD:speed   - Move backward (0-100)");
  BluetoothHandler::sendMessage("  LEFT:speed       - Turn left (0-100)");
  BluetoothHandler::sendMessage("  RIGHT:speed      - Turn right (0-100)");
  BluetoothHandler::sendMessage("  TANK:left,right  - Tank drive (-100 to 100)");
  BluetoothHandler::sendMessage("  STOP             - Stop all motors");
  BluetoothHandler::sendMessage("");
  BluetoothHandler::sendMessage("SERVO ARM COMMANDS:");
  BluetoothHandler::sendMessage("  ARM_HOME         - Move arm to home position");
  BluetoothHandler::sendMessage("  ARM_PRESET:1-5   - Move to preset position");
  BluetoothHandler::sendMessage("  SERVO1:angle     - Control base servo (0-180)");
  BluetoothHandler::sendMessage("  SERVO2:angle     - Control shoulder servo");
  BluetoothHandler::sendMessage("  SERVO3:angle     - Control elbow servo");
  BluetoothHandler::sendMessage("  SERVO4:angle     - Control wrist rotation");
  BluetoothHandler::sendMessage("  SERVO5:angle     - Control wrist tilt");
  BluetoothHandler::sendMessage("  SERVO6:angle     - Control gripper");
  BluetoothHandler::sendMessage("  GRIPPER_OPEN     - Open gripper");
  BluetoothHandler::sendMessage("  GRIPPER_CLOSE    - Close gripper");
  BluetoothHandler::sendMessage("");
  BluetoothHandler::sendMessage("SYSTEM COMMANDS:");
  BluetoothHandler::sendMessage("  STATUS           - Get system status");
  BluetoothHandler::sendMessage("  SPEED:value      - Set motor speed (20-100)");
  BluetoothHandler::sendMessage("  SERVO_SPEED:val  - Set servo speed (1-5)");
  BluetoothHandler::sendMessage("  DEBUG:0/1        - Toggle debug mode");
  BluetoothHandler::sendMessage("  EMERGENCY        - Emergency stop all");
  BluetoothHandler::sendMessage("  TEST_MOTORS      - Test all motors");
  BluetoothHandler::sendMessage("  TEST_SERVOS      - Test all servos");
  BluetoothHandler::sendMessage("  CALIBRATE        - Calibrate servos");
  BluetoothHandler::sendMessage("  PING             - Connection test");
  BluetoothHandler::sendMessage("=== END HELP ===");
}

#endif // COMMAND_PROCESSOR_H
