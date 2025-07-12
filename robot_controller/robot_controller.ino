/**********************************************************************
 *  4WD Robot with 6-Servo Arm - Bluetooth Control System
 *  Main Entry Point - Arduino Mega 2560
 *  
 *  This is the main file that coordinates all subsystems:
 *  - Bluetooth communication
 *  - Motor control (4 wheels)
 *  - Servo arm control (6 servos)
 *  - System status and safety
 *********************************************************************/

#include "config.h"
#include "system_status.h"
#include "motor_controller.h"
#include "servo_arm.h"
#include "command_processor.h"
#include "bluetooth_handler.h"

// Global system state
SystemState systemState;

// Function to handle command queue from Bluetooth (solves circular dependency)
void addCommandToQueue(const String& cmd) {
  CommandProcessor::addCommand(cmd);
}

void setup() {
  // Initialize serial for debugging
  Serial.begin(115200);
  delay(2000);
  
  Serial.println("===============================================");
  Serial.println("4WD Robot with 6-Servo Arm - Bluetooth Control");
  Serial.println("Version: 2.0");
  Serial.println("===============================================");
  
  // Initialize all subsystems
  initializeSystem();
  
  // System ready
  systemState.isReady = true;
  systemState.startTime = millis();
  
  Serial.println("✅ System Ready!");
  Serial.println("📱 Waiting for Bluetooth commands...");
  Serial.println("===============================================");
  
  // Send ready signal to Bluetooth
  BluetoothHandler::sendMessage("ROBOT_READY");
}

void loop() {
  // Update system status
  SystemStatus::update();
  
  // Handle Bluetooth communication
  BluetoothHandler::update();
  
  // Process any received commands
  CommandProcessor::processQueue();
  
  // Update motor controller (handles safety timeouts)
  MotorController::update();
  
  // Update servo arm
  ServoArm::update();
  
  // Safety check - stop all if timeout
  if (SystemStatus::isCommandTimeout()) {
    MotorController::stopAll();
    ServoArm::stopAll();
  }
  
  // Small delay to prevent overwhelming the system
  delay(10);
}

void initializeSystem() {
  Serial.println("🔧 Initializing subsystems...");
  
  // Initialize system status
  SystemStatus::init();
  
  // Initialize Bluetooth communication
  BluetoothHandler::init();
  
  // Initialize motor controller
  MotorController::init();
  
  // Initialize servo arm
  ServoArm::init();
  
  // Initialize command processor
  CommandProcessor::init();
  
  Serial.println("✅ All subsystems initialized");
}