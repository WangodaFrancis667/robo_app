/**********************************************************************
 *  bluetooth_handler.h - Bluetooth Communication Module
 *  Handles all Bluetooth communication with HC-05/HC-06 modules
 *********************************************************************/

#ifndef BLUETOOTH_HANDLER_H
#define BLUETOOTH_HANDLER_H

#include "config.h"

// Forward declaration to avoid circular dependency
class CommandProcessor;

class BluetoothHandler {
private:
  static String inputBuffer;
  static bool connectionEstablished;
  static unsigned long lastHeartbeat;
  static unsigned long lastDataReceived;
  
public:
  // Initialize Bluetooth module
  static void init();
  
  // Update - call this in main loop
  static void update();
  
  // Send message to Bluetooth device
  static void sendMessage(const String& message);
  
  // Send response with OK/ERROR prefix
  static void sendResponse(const String& command, bool success = true);
  
  // Send status information
  static void sendStatus();
  
  // Check if Bluetooth is connected
  static bool isConnected();
  
  // Get signal strength (if supported)
  static int getSignalStrength();
  
  // Process incoming data
  static void processIncomingData();
  
  // Clear input buffer
  static void clearBuffer();
  
  // Send heartbeat
  static void sendHeartbeat();
  
  // Check connection health
  static bool isConnectionHealthy();
};

// Implementation
String BluetoothHandler::inputBuffer = "";
bool BluetoothHandler::connectionEstablished = false;
unsigned long BluetoothHandler::lastHeartbeat = 0;
unsigned long BluetoothHandler::lastDataReceived = 0;

void BluetoothHandler::init() {
  DEBUG_PRINTLN("🔵 Initializing Bluetooth...");
  
  // Initialize Serial1 for Bluetooth communication
  Serial1.begin(BLUETOOTH_BAUD);
  
  // Clear any existing data
  while (Serial1.available()) {
    Serial1.read();
  }
  
  // Send initialization message
  delay(1000);
  sendMessage("BLUETOOTH_INIT");
  
  // Wait for response or timeout
  unsigned long startTime = millis();
  while (millis() - startTime < 3000) {
    if (Serial1.available()) {
      String response = Serial1.readString();
      response.trim();
      if (response.length() > 0) {
        connectionEstablished = true;
        lastDataReceived = millis();
        DEBUG_PRINTLN("✅ Bluetooth connection established");
        break;
      }
    }
    delay(100);
  }
  
  if (!connectionEstablished) {
    DEBUG_PRINTLN("⚠ Bluetooth connection not confirmed, but continuing...");
  }
  
  DEBUG_PRINTLN("🔵 Bluetooth initialized on Serial1");
}

void BluetoothHandler::update() {
  // Process any incoming data
  processIncomingData();
  
  // Send periodic heartbeat
  if (millis() - lastHeartbeat > 5000) {
    sendHeartbeat();
    lastHeartbeat = millis();
  }
  
  // Check connection health
  if (millis() - lastDataReceived > 30000 && connectionEstablished) {
    DEBUG_PRINTLN("⚠ Bluetooth connection may be lost");
    connectionEstablished = false;
  }
}

void BluetoothHandler::sendMessage(const String& message) {
  if (DEBUG_BLUETOOTH) {
    DEBUG_PRINT("📤 BT Send: ");
    DEBUG_PRINTLN(message);
  }
  
  Serial1.println(message);
  Serial1.flush(); // Ensure data is sent immediately
}

void BluetoothHandler::sendResponse(const String& command, bool success) {
  String response = success ? RESP_OK : RESP_ERROR;
  response += "_" + command;
  sendMessage(response);
}

void BluetoothHandler::sendStatus() {
  // Send comprehensive status
  sendMessage("STATUS_BLUETOOTH_CONNECTED:" + String(connectionEstablished));
  sendMessage("STATUS_UPTIME:" + String(millis()));
  sendMessage("STATUS_FREE_MEMORY:" + String(freeMemory()));
  sendMessage("STATUS_LAST_COMMAND:" + String(millis() - lastDataReceived));
}

bool BluetoothHandler::isConnected() {
  return connectionEstablished;
}

int BluetoothHandler::getSignalStrength() {
  // This would require AT commands for HC-05
  // For now, return a dummy value
  return connectionEstablished ? 85 : 0;
}

void BluetoothHandler::processIncomingData() {
  while (Serial1.available()) {
    char c = Serial1.read();
    
    if (c == '\n' || c == '\r') {
      if (inputBuffer.length() > 0) {
        // Process complete command
        inputBuffer.trim();
        
        if (DEBUG_BLUETOOTH) {
          DEBUG_PRINT("📥 BT Received: ");
          DEBUG_PRINTLN(inputBuffer);
        }
        
        // Update connection status
        connectionEstablished = true;
        lastDataReceived = millis();
        
        // Add command to processing queue - will be handled after CommandProcessor is included
        // This is a temporary solution to avoid circular dependency
        extern void addCommandToQueue(const String& cmd);
        addCommandToQueue(inputBuffer);
        
        // Clear buffer
        inputBuffer = "";
      }
    } else if (c != '\0') {
      inputBuffer += c;
      
      // Prevent buffer overflow
      if (inputBuffer.length() > 100) {
        DEBUG_PRINTLN("⚠ Bluetooth buffer overflow, clearing");
        inputBuffer = "";
      }
    }
  }
}

void BluetoothHandler::clearBuffer() {
  inputBuffer = "";
  while (Serial1.available()) {
    Serial1.read();
  }
}

void BluetoothHandler::sendHeartbeat() {
  if (connectionEstablished) {
    sendMessage("HEARTBEAT");
  }
}

bool BluetoothHandler::isConnectionHealthy() {
  return connectionEstablished && (millis() - lastDataReceived < 10000);
}

#endif // BLUETOOTH_HANDLER_H