/**********************************************************************
 *  4WD Robot with 6-Servo Arm - Bluetooth Control System
 *  Main Entry Point - Arduino Mega 2560
 *
 *  This is the main file that coordinates all subsystems:
 *  - Bluetooth communication
 *  - Motor control (4 wheels)
 *  - Servo arm control (6 servos)
 *  - Sensor management (HC-SR04 ultrasonic sensors)
 *  - Collision avoidance system
 *  - System status and safety
 *********************************************************************/

#include "bluetooth_handler.h"
#include "collision_avoidance.h"
#include "command_processor.h"
#include "config.h"
#include "memory_optimization.h"
#include "motor_controller.h"
#include "sensor_manager.h"
#include "sensor_status.h"
#include "servo_arm.h"
#include "system_status.h"

// Global system state
SystemState systemState;

// Forward declarations for circular dependency resolution
void sendBluetoothMessage(const char *message);

// Function to handle command queue from Bluetooth (solves circular dependency)
void addCommandToQueue(const char *cmd) { CommandProcessor::addCommand(cmd); }

// Function to send Bluetooth messages (solves circular dependency)
void sendBluetoothMessage(const char *message) {
#if SERIAL_TESTING_MODE
  // In testing mode, send to Serial Monitor with shorter prefix
  Serial.print(F("📤 "));
  Serial.println(message);
#else
  BluetoothHandler::sendMessage(message);
#endif
}

// Function for emergency motor stop (solves circular dependency)
void emergencyStopAllMotors() { MotorController::emergencyStop(); }

// Function to check collision safety (solves circular dependency)
bool checkCollisionSafety(bool movingForward) {
  return !CollisionAvoidance::shouldStopMovement(movingForward);
}

void setup() {
  // Initialize serial for debugging
  Serial.begin(115200);
  delay(2000);

  Serial.println(F("==============================================="));
  Serial.println(F("4WD Robot with 6-Servo Arm - Bluetooth Control"));
  Serial.println(F("+ HC-SR04 Collision Avoidance System"));
  Serial.println(F("Version: 2.1 - Memory Optimized"));

#if SERIAL_TESTING_MODE
  Serial.println(F("MODE: Serial Monitor Testing"));
  Serial.println(F("Send commands via Serial Monitor"));
#else
  Serial.println(F("MODE: Bluetooth Operation"));
#endif

  Serial.println(F("==============================================="));

  // Initialize memory monitor first
  MemoryMonitor::init();

  Serial.print(F("Initial free memory: "));
  Serial.print(MemoryMonitor::getFreeMemory());
  Serial.println(F(" bytes"));

  // Initialize all subsystems
  initializeSystem();

  // System ready
  systemState.isReady = true;
  systemState.startTime = millis();

  Serial.println(F("✅ System Ready!"));

#if SERIAL_TESTING_MODE
  Serial.println(F("📝 Use Serial Monitor to send commands"));
  Serial.println(F("💡 Type 'HELP' to see available commands"));
#else
  Serial.println(F("📱 Waiting for Bluetooth commands..."));
#endif

  Serial.println(F("🛡 Collision avoidance: ACTIVE"));
  Serial.println(F("==============================================="));

  // Send ready signal
#if SERIAL_TESTING_MODE
  Serial.println(F("ROBOT_READY - You can now send commands!"));
#else
  sendBluetoothMessage("ROBOT_READY");
#endif
}

void loop() {
  // Monitor memory first to detect issues early
  if (!MemoryMonitor::checkMemory()) {
    // Critical memory situation - force garbage collection
    MemoryMonitor::forceGarbageCollection();
    delay(100); // Give system time to recover
  }

  // Update system status
  SystemStatus::update();

#if SERIAL_TESTING_MODE
  // Handle Serial Monitor commands in testing mode
  handleSerialCommands();
#else
  // Handle Bluetooth communication in normal mode
  BluetoothHandler::update();
#endif

  // Process any received commands (do this frequently)
  CommandProcessor::processQueue();

  // Update motor controller (handles safety timeouts)
  MotorController::update();

  // Update servo arm
  ServoArm::update();

  // Update sensors less frequently to improve responsiveness and save memory
  static unsigned long lastSensorUpdate = 0;
  if (millis() - lastSensorUpdate >= SENSOR_UPDATE_INTERVAL) {
    SensorManager::update();
    CollisionAvoidance::update();
    lastSensorUpdate = millis();
  }

  // Update sensor status even less frequently to save memory
  static unsigned long lastStatusUpdate = 0;
  if (millis() - lastStatusUpdate >= STATUS_SEND_INTERVAL) {
    SensorStatusManager::update();
    lastStatusUpdate = millis();
  }

  // Safety check - stop all if timeout or collision risk
  if (SystemStatus::isCommandTimeout()) {
    MotorController::stopAll();
    ServoArm::stopAll();
  }

  // Additional safety check for collision avoidance
  if (CollisionAvoidance::isEmergencyStopActive()) {
    MotorController::stopAll();
  }

  // Increased delay to reduce loop frequency and save processing power
  delay(10); // Increased from 5ms
}

// Serial command handler for testing mode - optimized for memory
void handleSerialCommands() {
  static char serialBuffer[MAX_COMMAND_LENGTH];
  static int bufferIndex = 0;

  while (Serial.available()) {
    char c = Serial.read();

    if (c == '\n' || c == '\r') {
      if (bufferIndex > 0) {
        serialBuffer[bufferIndex] = '\0'; // Null terminate

        Serial.println(); // New line for readability
        Serial.print(F(">>> Processing: "));
        Serial.println(serialBuffer);

        // Update command timestamp immediately to prevent timeout
        SystemStatus::updateLastCommand();

        // Add command to processing queue
        CommandProcessor::addCommand(serialBuffer);

        // Clear buffer
        bufferIndex = 0;
        memset(serialBuffer, 0, sizeof(serialBuffer));

        // Small delay to let command process
        delay(10);
      }
    } else if (c != '\0' && c != '\r') {
      if (bufferIndex == 0 && c == ' ') {
        // Skip leading spaces
        continue;
      }

      if (bufferIndex < MAX_COMMAND_LENGTH - 1) {
        serialBuffer[bufferIndex++] = c;
      } else {
        // Buffer overflow protection
        Serial.println(F("⚠ Command too long, clearing buffer"));
        bufferIndex = 0;
        memset(serialBuffer, 0, sizeof(serialBuffer));
      }
    }
  }
}

void initializeSystem() {
  Serial.println(F("🔧 Initializing subsystems..."));

  // Initialize system status
  SystemStatus::init();

#if !SERIAL_TESTING_MODE
  // Initialize Bluetooth communication only in normal mode
  BluetoothHandler::init();
#else
  Serial.println(F("📝 Bluetooth disabled - Serial testing mode"));
#endif

  // Initialize motor controller
  MotorController::init();

  // Initialize servo arm
  ServoArm::init();

  // Initialize sensor manager
  SensorManager::init();

  // Initialize collision avoidance
  CollisionAvoidance::init();

  // Initialize sensor status manager
  SensorStatusManager::init();

  // Initialize command processor (last, as it may depend on others)
  CommandProcessor::init();

  Serial.println(F("✅ All subsystems initialized"));

  // Final memory check after initialization
  Serial.print(F("Post-init free memory: "));
  Serial.print(MemoryMonitor::getFreeMemory());
  Serial.println(F(" bytes"));
}