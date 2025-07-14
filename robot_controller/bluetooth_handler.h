/**********************************************************************
 *  bluetooth_handler.h - Bluetooth Communication Module
 *  Handles all Bluetooth communication with HC-05/HC-06 modules
 *********************************************************************/

#ifndef BLUETOOTH_HANDLER_H
#define BLUETOOTH_HANDLER_H

#include "config.h"
#include "memory_optimization.h"

// Forward declaration to avoid circular dependency
class CommandProcessor;

class BluetoothHandler {
private:
  static char inputBuffer[MAX_COMMAND_LENGTH];
  static bool connectionEstablished;
  static unsigned long lastHeartbeat;
  static unsigned long lastDataReceived;

public:
  // Initialize Bluetooth module
  static void init();

  // Update - call this in main loop
  static void update();

  // Send message to Bluetooth device
  static void sendMessage(const char *message);

  // Send response with OK/ERROR prefix
  static void sendResponse(const char *command, bool success = true);

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
char BluetoothHandler::inputBuffer[MAX_COMMAND_LENGTH];
bool BluetoothHandler::connectionEstablished = false;
unsigned long BluetoothHandler::lastHeartbeat = 0;
unsigned long BluetoothHandler::lastDataReceived = 0;

void BluetoothHandler::init() {
#if SERIAL_TESTING_MODE
  DEBUG_PRINTLN_P("🔵 Bluetooth initialization skipped - Serial testing mode");
  connectionEstablished = true; // Simulate connection for testing
  return;
#endif

  DEBUG_PRINTLN_P("🔵 Initializing Bluetooth...");

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
  char responseBuffer[64];
  int responseIndex = 0;

  while (millis() - startTime < 3000) {
    if (Serial1.available()) {
      char c = Serial1.read();
      if (c != '\r' && c != '\n' && responseIndex < 63) {
        responseBuffer[responseIndex++] = c;
      } else if (responseIndex > 0) {
        responseBuffer[responseIndex] = '\0';
        connectionEstablished = true;
        lastDataReceived = millis();
        DEBUG_PRINTLN_P("✅ Bluetooth connection established");
        break;
      }
    }
    delay(100);
  }

  if (!connectionEstablished) {
    DEBUG_PRINTLN_P("⚠ Bluetooth connection not confirmed, but continuing...");
  }

  DEBUG_PRINTLN_P("🔵 Bluetooth initialized on Serial1");
}

void BluetoothHandler::update() {
#if SERIAL_TESTING_MODE
  // Skip Bluetooth updates in testing mode
  return;
#endif

  // Process any incoming data
  processIncomingData();

  // Send periodic heartbeat
  if (millis() - lastHeartbeat > 5000) {
    sendHeartbeat();
    lastHeartbeat = millis();
  }

  // Check connection health
  if (millis() - lastDataReceived > 30000 && connectionEstablished) {
    DEBUG_PRINTLN_P("⚠ Bluetooth connection may be lost");
    connectionEstablished = false;
  }
}

void BluetoothHandler::sendMessage(const char *message) {
#if SERIAL_TESTING_MODE
  // In testing mode, output to Serial Monitor with prefix
  Serial.print(F("📡 "));
  Serial.println(message);
  return;
#endif

  if (DEBUG_BLUETOOTH) {
    DEBUG_PRINT_P("📤 BT Send: ");
    DEBUG_PRINTLN(message);
  }

  Serial1.println(message);
  Serial1.flush(); // Ensure data is sent immediately
}

void BluetoothHandler::sendResponse(const char *command, bool success) {
  if (MessageBuffer::isAvailable()) {
    char *buffer = MessageBuffer::getBuffer();
    const char *responsePrefix = success ? "OK" : "ERROR";
    snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("%s_%s"), responsePrefix,
               command);
    sendMessage(buffer);
    MessageBuffer::releaseBuffer();
  }
}

void BluetoothHandler::sendStatus() {
  // Send comprehensive status using message buffer
  if (MessageBuffer::isAvailable()) {
    char *buffer = MessageBuffer::getBuffer();

    snprintf_P(buffer, MAX_MESSAGE_LENGTH,
               PSTR("STATUS_BLUETOOTH_CONNECTED:%d"), connectionEstablished);
    sendMessage(buffer);

    snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("STATUS_UPTIME:%lu"), millis());
    sendMessage(buffer);

    snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("STATUS_FREE_MEMORY:%d"),
               MemoryMonitor::getFreeMemory());
    sendMessage(buffer);

    snprintf_P(buffer, MAX_MESSAGE_LENGTH, PSTR("STATUS_LAST_COMMAND:%lu"),
               millis() - lastDataReceived);
    sendMessage(buffer);

    MessageBuffer::releaseBuffer();
  }
}

bool BluetoothHandler::isConnected() { return connectionEstablished; }

int BluetoothHandler::getSignalStrength() {
  // This would require AT commands for HC-05
  // For now, return a dummy value
  return connectionEstablished ? 85 : 0;
}

void BluetoothHandler::processIncomingData() {
  static int bufferIndex = 0;

  while (Serial1.available()) {
    char c = Serial1.read();

    if (c == '\n' || c == '\r') {
      if (bufferIndex > 0) {
        // Null terminate the command
        BluetoothHandler::inputBuffer[bufferIndex] = '\0';

        if (DEBUG_BLUETOOTH) {
          DEBUG_PRINT_P("📥 BT Received: ");
          DEBUG_PRINTLN(BluetoothHandler::inputBuffer);
        }

        // Update connection status
        connectionEstablished = true;
        lastDataReceived = millis();

        // Add command to processing queue - will be handled after
        // CommandProcessor is included This is a temporary solution to avoid
        // circular dependency
        extern void addCommandToQueue(const char *cmd);
        addCommandToQueue(BluetoothHandler::inputBuffer);

        // Clear buffer
        bufferIndex = 0;
        memset(BluetoothHandler::inputBuffer, 0,
               sizeof(BluetoothHandler::inputBuffer));
      }
    } else if (c != '\0' && c != '\r') {
      if (bufferIndex < MAX_COMMAND_LENGTH - 1) {
        BluetoothHandler::inputBuffer[bufferIndex++] = c;
      } else {
        // Prevent buffer overflow
        DEBUG_PRINTLN_P("⚠ Bluetooth buffer overflow, clearing");
        bufferIndex = 0;
        memset(BluetoothHandler::inputBuffer, 0,
               sizeof(BluetoothHandler::inputBuffer));
      }
    }
  }
}

void BluetoothHandler::clearBuffer() {
  memset(BluetoothHandler::inputBuffer, 0,
         sizeof(BluetoothHandler::inputBuffer));
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