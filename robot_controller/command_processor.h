
#ifndef COMMAND_PROCESSOR_H
#define COMMAND_PROCESSOR_H

#include "bluetooth_handler.h"
#include "config.h"
#include "memory_optimization.h"
#include "motor_controller.h"
#include "sensor_status.h"
#include "servo_arm.h"
#include "system_status.h"

class CommandProcessor {
private:
  static Command commandQueue[COMMAND_QUEUE_SIZE]; // Reduced queue size
  static int queueHead;
  static int queueTail;
  static int queueSize;
  static unsigned long lastProcessTime;

  // Private helper methods
  static bool parseCommand(const char *input, Command &cmd);
  static void executeCommand(const Command &cmd);
  static bool isQueueFull();
  static bool isQueueEmpty();
  static void processMotorCommand(const Command &cmd);
  static void processServoCommand(const Command &cmd);
  static void processSystemCommand(const Command &cmd);

public:
  // Initialize command processor
  static void init();

  // Add command to queue
  static bool addCommand(const char *commandString);
  static bool addCommand(const String &commandString); // Backward compatibility

  // Process command queue
  static void processQueue();

  // Process single command immediately
  static void processImmediate(const char *commandString);

  // Queue management
  static void clearQueue();
  static int getQueueCount();
  static void getQueueStatus(char *buffer, size_t bufferSize);

  // Command validation
  static bool isValidCommand(const char *commandString);
  static void sendCommandHelp();
};

// Implementation
Command CommandProcessor::commandQueue[COMMAND_QUEUE_SIZE];
int CommandProcessor::queueHead = 0;
int CommandProcessor::queueTail = 0;
int CommandProcessor::queueSize = 0;
unsigned long CommandProcessor::lastProcessTime = 0;

void CommandProcessor::init() {
  DEBUG_PRINTLN_P("Initializing Command Processor...");

  // Clear queue
  clearQueue();
  lastProcessTime = millis();

  DEBUG_PRINTLN_P("Command Processor initialized");
}

bool CommandProcessor::addCommand(const char *commandString) {
  if (isQueueFull()) {
    DEBUG_PRINTLN_P("Command queue full, dropping command");
    sendBluetoothMessage("ERROR_QUEUE_FULL");
    return false;
  }

  Command cmd;
  if (!parseCommand(commandString, cmd)) {
    DEBUG_PRINTLN_P("Invalid command format");
    return false;
  }

  // Add to queue
  commandQueue[queueTail] = cmd;
  queueTail = (queueTail + 1) % COMMAND_QUEUE_SIZE;
  queueSize++;

  return true;
}

// Backward compatibility wrapper
bool CommandProcessor::addCommand(const String &commandString) {
  return addCommand(commandString.c_str());
}

void CommandProcessor::processQueue() {
  // Process fewer commands per loop to save memory
  int commandsProcessed = 0;
  const int maxCommandsPerLoop = 2; // Reduced from 3

  while (!isQueueEmpty() && commandsProcessed < maxCommandsPerLoop) {
    Command cmd = commandQueue[queueHead];
    queueHead = (queueHead + 1) % COMMAND_QUEUE_SIZE;
    queueSize--;

    executeCommand(cmd);
    commandsProcessed++;
    lastProcessTime = millis();
  }
}

void CommandProcessor::processImmediate(const char *commandString) {
  Command cmd;
  if (parseCommand(commandString, cmd)) {
    executeCommand(cmd);
  }
}

bool CommandProcessor::parseCommand(const char *input, Command &cmd) {
  // Use stack-based string for parsing
  TempString<MAX_COMMAND_LENGTH> tempInput;
  strncpy(tempInput.get(), input, tempInput.size() - 1);
  tempInput.get()[tempInput.size() - 1] = '\0';

  // Convert to uppercase in place
  char *str = tempInput.get();
  for (int i = 0; str[i]; i++) {
    str[i] = toupper(str[i]);
  }

  cmd.timestamp = millis();

  // Parse command components
  char *colonPos = strchr(str, ':');
  char *commaPos = strchr(str, ',');

  if (colonPos) {
    *colonPos = '\0'; // Split at colon
    strncpy(cmd.type, str, sizeof(cmd.type) - 1);
    cmd.type[sizeof(cmd.type) - 1] = '\0';

    char *params = colonPos + 1;
    if (commaPos && commaPos > colonPos) {
      *commaPos = '\0'; // Split at comma
      strncpy(cmd.parameter, params, sizeof(cmd.parameter) - 1);
      cmd.parameter[sizeof(cmd.parameter) - 1] = '\0';
      cmd.value1 = atoi(params);
      cmd.value2 = atoi(commaPos + 1);
    } else {
      strncpy(cmd.parameter, params, sizeof(cmd.parameter) - 1);
      cmd.parameter[sizeof(cmd.parameter) - 1] = '\0';
      cmd.value1 = atoi(params);
      cmd.value2 = 0;
    }
  } else {
    strncpy(cmd.type, str, sizeof(cmd.type) - 1);
    cmd.type[sizeof(cmd.type) - 1] = '\0';
    cmd.parameter[0] = '\0';
    cmd.value1 = 0;
    cmd.value2 = 0;
  }

  return true;
}

void CommandProcessor::executeCommand(const Command &cmd) {
  DEBUG_PRINT_P("⚡ Executing: ");
  DEBUG_PRINTLN(cmd.type);

  // Route command to appropriate subsystem
  if (strcmp(cmd.type, CMD_FORWARD) == 0 ||
      strcmp(cmd.type, CMD_BACKWARD) == 0 || strcmp(cmd.type, CMD_LEFT) == 0 ||
      strcmp(cmd.type, CMD_RIGHT) == 0 || strcmp(cmd.type, CMD_TANK) == 0 ||
      strcmp(cmd.type, CMD_STOP) == 0) {
    processMotorCommand(cmd);

  } else if (strncmp(cmd.type, "SERVO", 5) == 0 ||
             strncmp(cmd.type, "ARM", 3) == 0 ||
             strncmp(cmd.type, "GRIPPER", 7) == 0) {
    processServoCommand(cmd);

  } else {
    processSystemCommand(cmd);
  }
}

void CommandProcessor::processMotorCommand(const Command &cmd) {
  // Check collision avoidance before executing motor commands
  if (!CollisionAvoidance::isMovementSafe(cmd.type, cmd.value1)) {
    // Use message buffer for blocked message
    if (MessageBuffer::isAvailable()) {
      char *buffer = MessageBuffer::getBuffer();
      snprintf_P(buffer, MAX_MESSAGE_LENGTH,
                 PSTR("BLOCKED_BY_COLLISION_AVOIDANCE:%s"), cmd.type);
      BluetoothHandler::sendMessage(buffer);
      MessageBuffer::releaseBuffer();
    }
    BluetoothHandler::sendResponse(cmd.type, false);
    return;
  }

  if (strcmp(cmd.type, CMD_FORWARD) == 0) {
    int speed = constrain(cmd.value1, 0, 100);
    // Apply collision avoidance speed adjustment
    speed = CollisionAvoidance::adjustSpeedForSafety(speed, true);
    MotorController::moveForward(speed);
    BluetoothHandler::sendResponse(CMD_FORWARD);

  } else if (strcmp(cmd.type, CMD_BACKWARD) == 0) {
    int speed = constrain(cmd.value1, 0, 100);
    // Apply collision avoidance speed adjustment
    speed = CollisionAvoidance::adjustSpeedForSafety(speed, false);
    MotorController::moveBackward(speed);
    BluetoothHandler::sendResponse(CMD_BACKWARD);

  } else if (strcmp(cmd.type, CMD_LEFT) == 0) {
    int speed = constrain(cmd.value1, 0, 100);
    MotorController::turnLeft(speed);
    BluetoothHandler::sendResponse(CMD_LEFT);

  } else if (strcmp(cmd.type, CMD_RIGHT) == 0) {
    int speed = constrain(cmd.value1, 0, 100);
    MotorController::turnRight(speed);
    BluetoothHandler::sendResponse(CMD_RIGHT);

  } else if (strcmp(cmd.type, CMD_TANK) == 0) {
    int leftSpeed = constrain(cmd.value1, -100, 100);
    int rightSpeed = constrain(cmd.value2, -100, 100);
    MotorController::tankDrive(leftSpeed, rightSpeed);
    BluetoothHandler::sendResponse(CMD_TANK);

  } else if (strcmp(cmd.type, CMD_STOP) == 0) {
    MotorController::stopAll();
    BluetoothHandler::sendResponse(CMD_STOP);
  }
}

void CommandProcessor::processServoCommand(const Command &cmd) {
  if (strcmp(cmd.type, CMD_ARM_HOME) == 0) {
    ServoArm::moveToHome();
    BluetoothHandler::sendResponse(CMD_ARM_HOME);

  } else if (strcmp(cmd.type, CMD_ARM_PRESET) == 0) {
    int preset = constrain(cmd.value1, 1, 5);
    ServoArm::moveToPreset(preset);
    BluetoothHandler::sendResponse(CMD_ARM_PRESET);

  } else if (strcmp(cmd.type, CMD_GRIPPER_OPEN) == 0) {
    ServoArm::openGripper();
    BluetoothHandler::sendResponse(CMD_GRIPPER_OPEN);

  } else if (strcmp(cmd.type, CMD_GRIPPER_CLOSE) == 0) {
    ServoArm::closeGripper();
    BluetoothHandler::sendResponse(CMD_GRIPPER_CLOSE);

  } else if (strncmp(cmd.type, "SERVO", 5) == 0) {
    // Parse servo command (e.g., SERVO1:90, SERVO_BASE:45)
    int servoIndex = -1;

    if (strcmp(cmd.type, "SERVO1") == 0 ||
        strcmp(cmd.type, "SERVO_BASE") == 0) {
      servoIndex = SERVO_BASE_IDX;
    } else if (strcmp(cmd.type, "SERVO2") == 0 ||
               strcmp(cmd.type, "SERVO_SHOULDER") == 0) {
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

void CommandProcessor::processSystemCommand(const Command &cmd) {
  if (cmd.type == CMD_STATUS) {
    // Use char buffers instead of String objects for better memory efficiency
    char motorStatus[64], servoStatus[64], systemStatus[64];
    MotorController::getStatus(motorStatus, sizeof(motorStatus));
    ServoArm::getStatus(servoStatus, sizeof(servoStatus));
    SystemStatus::getStatus(systemStatus, sizeof(systemStatus));

    // Send status messages using buffer formatting
    if (MessageBuffer::isAvailable()) {
      char *buffer = MessageBuffer::getBuffer();
      snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("STATUS_MOTORS:%s"),
                 motorStatus);
      BluetoothHandler::sendMessage(buffer);
      MessageBuffer::releaseBuffer();
    }

    if (MessageBuffer::isAvailable()) {
      char *buffer = MessageBuffer::getBuffer();
      snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("STATUS_SERVOS:%s"),
                 servoStatus);
      BluetoothHandler::sendMessage(buffer);
      MessageBuffer::releaseBuffer();
    }

    if (MessageBuffer::isAvailable()) {
      char *buffer = MessageBuffer::getBuffer();
      snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("STATUS_SYSTEM:%s"),
                 systemStatus);
      BluetoothHandler::sendMessage(buffer);
      MessageBuffer::releaseBuffer();
    }

    BluetoothHandler::sendResponse(CMD_STATUS);

  } else if (cmd.type == CMD_SPEED) {
    int speed = constrain(cmd.value1, 20, 100);
    MotorController::setGlobalSpeed(speed);

    if (MessageBuffer::isAvailable()) {
      char *buffer = MessageBuffer::getBuffer();
      snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("SPEED_SET:%d"), speed);
      BluetoothHandler::sendMessage(buffer);
      MessageBuffer::releaseBuffer();
    }
    BluetoothHandler::sendResponse(CMD_SPEED);

  } else if (cmd.type == CMD_DEBUG) {
    // Toggle debug mode
    SystemStatus::setDebugMode(cmd.value1 == 1);

    if (MessageBuffer::isAvailable()) {
      char *buffer = MessageBuffer::getBuffer();
      snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("DEBUG_MODE:%d"), cmd.value1);
      BluetoothHandler::sendMessage(buffer);
      MessageBuffer::releaseBuffer();
    }
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

    if (MessageBuffer::isAvailable()) {
      char *buffer = MessageBuffer::getBuffer();
      snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("SERVO_SPEED_SET:%d"), speed);
      BluetoothHandler::sendMessage(buffer);
      MessageBuffer::releaseBuffer();
    }
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

    if (MessageBuffer::isAvailable()) {
      char *buffer = MessageBuffer::getBuffer();
      char distStr[8];
      formatFloat(distance, distStr, sizeof(distStr), 1);
      snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("COLLISION_DISTANCE_SET:%s"),
                 distStr);
      BluetoothHandler::sendMessage(buffer);
      MessageBuffer::releaseBuffer();
    }
    BluetoothHandler::sendResponse(CMD_COLLISION_DISTANCE);

  } else if (cmd.type == "COLLISION_AGGRESSIVENESS") {
    int level = constrain(cmd.value1, 1, 3);
    CollisionAvoidance::setAggressiveness(level);

    if (MessageBuffer::isAvailable()) {
      char *buffer = MessageBuffer::getBuffer();
      snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("AGGRESSIVENESS_SET:%d"),
                 level);
      BluetoothHandler::sendMessage(buffer);
      MessageBuffer::releaseBuffer();
    }
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
    DEBUG_PRINT_P("❌ Unknown command: ");
    DEBUG_PRINTLN(cmd.type);
    if (MessageBuffer::isAvailable()) {
      char *buffer = MessageBuffer::getBuffer();
      snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("ERROR_UNKNOWN_COMMAND:%s"),
                 cmd.type);
      BluetoothHandler::sendMessage(buffer);
      MessageBuffer::releaseBuffer();
    }
  }
}

void CommandProcessor::clearQueue() {
  queueHead = 0;
  queueTail = 0;
  queueSize = 0;
  DEBUG_PRINTLN("🗑 Command queue cleared");
}

int CommandProcessor::getQueueCount() { return queueSize; }

void CommandProcessor::getQueueStatus(char *buffer, size_t bufferSize) {
  snprintf_P(buffer, bufferSize, PSTR("Queue: %d/%d commands"), queueSize,
             COMMAND_QUEUE_SIZE);
}

bool CommandProcessor::isQueueFull() { return queueSize >= COMMAND_QUEUE_SIZE; }

bool CommandProcessor::isQueueEmpty() { return queueSize == 0; }

bool CommandProcessor::isValidCommand(const char *commandString) {
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
  BluetoothHandler::sendMessage(
      "  TANK:left,right  - Tank drive (-100 to 100)");
  BluetoothHandler::sendMessage("  STOP             - Stop all motors");
  BluetoothHandler::sendMessage("");
  BluetoothHandler::sendMessage("SERVO ARM COMMANDS:");
  BluetoothHandler::sendMessage(
      "  ARM_HOME         - Move arm to home position");
  BluetoothHandler::sendMessage("  ARM_PRESET:1-5   - Move to preset position");
  BluetoothHandler::sendMessage(
      "  SERVO1:angle     - Control base servo (0-180)");
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
  BluetoothHandler::sendMessage(
      "  SPEED:value      - Set motor speed (20-100)");
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