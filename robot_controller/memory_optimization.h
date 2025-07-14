/**********************************************************************
 *  memory_optimization.h - Memory Management and Optimization
 *  Utilities for efficient memory usage on Arduino Mega
 *********************************************************************/

#ifndef MEMORY_OPTIMIZATION_H
#define MEMORY_OPTIMIZATION_H

#include <Arduino.h>

// Memory optimization settings
#define MAX_MESSAGE_LENGTH 64
#define MAX_COMMAND_LENGTH 32
#define COMMAND_QUEUE_SIZE 5    // Reduced from 10

// Flash string macros to save RAM
#define F_READY PSTR("ROBOT_READY")
#define F_OK PSTR("OK")
#define F_ERROR PSTR("ERROR")
#define F_STOP PSTR("STOP")
#define F_COLLISION_WARN PSTR("COLLISION_WARNING")
#define F_EMERGENCY_STOP PSTR("EMERGENCY_STOP")
#define F_EMERGENCY_CLEARED PSTR("EMERGENCY_STOP_CLEARED")

// Optimized message buffer management
class MessageBuffer {
private:
  static char buffer[MAX_MESSAGE_LENGTH];
  static bool inUse;

public:
  static char* getBuffer() {
    if (!inUse) {
      inUse = true;
      memset(buffer, 0, MAX_MESSAGE_LENGTH);
      return buffer;
    }
    return nullptr;  // Buffer busy
  }
  
  static void releaseBuffer() {
    inUse = false;
  }
  
  static bool isAvailable() {
    return !inUse;
  }
};

// Static allocations
char MessageBuffer::buffer[MAX_MESSAGE_LENGTH];
bool MessageBuffer::inUse = false;

// Optimized string formatting functions
inline void formatFloat(float value, char* buffer, size_t bufferSize, int decimals = 1) {
  dtostrf(value, 0, decimals, buffer);
}

inline void formatInt(int value, char* buffer, size_t bufferSize) {
  itoa(value, buffer, 10);
}

inline void formatCollisionMessage(const char* sensor, float distance, char* buffer, size_t bufferSize) {
  char distStr[8];
  formatFloat(distance, distStr, sizeof(distStr), 1);
  snprintf_P(buffer, bufferSize, PSTR("COLLISION_WARNING:%s:%s"), sensor, distStr);
}

inline void formatSensorStatus(float front, float rear, char* buffer, size_t bufferSize) {
  char frontStr[8], rearStr[8];
  formatFloat(front, frontStr, sizeof(frontStr), 1);
  formatFloat(rear, rearStr, sizeof(rearStr), 1);
  snprintf_P(buffer, bufferSize, PSTR("SENSOR:%s:%s"), frontStr, rearStr);
}

// Memory monitoring
class MemoryMonitor {
private:
  static int lastFreeMemory;
  static unsigned long lastCheck;
  static const int LOW_MEMORY_THRESHOLD = 400;
  static const int CRITICAL_MEMORY_THRESHOLD = 200;

public:
  static void init() {
    lastFreeMemory = getFreeMemory();
    lastCheck = millis();
  }
  
  static int getFreeMemory() {
    char top;
    extern char *__brkval;
    extern char __bss_end;
    return __brkval ? &top - __brkval : &top - &__bss_end;
  }
  
  static bool checkMemory() {
    unsigned long now = millis();
    if (now - lastCheck > 5000) {  // Check every 5 seconds
      int currentMemory = getFreeMemory();
      
      if (currentMemory < CRITICAL_MEMORY_THRESHOLD) {
        Serial.print(F("🚨 CRITICAL: Memory "));
        Serial.print(currentMemory);
        Serial.println(F(" bytes"));
        return false;  // Critical
      } else if (currentMemory < LOW_MEMORY_THRESHOLD) {
        Serial.print(F("⚠ WARNING: Low memory: "));
        Serial.print(currentMemory);
        Serial.println(F(" bytes"));
      }
      
      lastFreeMemory = currentMemory;
      lastCheck = now;
    }
    return true;  // OK
  }
  
  static void forceGarbageCollection() {
    // Force string cleanup by creating and destroying a small string
    String temp = "";
    temp.reserve(1);
    temp = "";
  }
};

// Static initializations
int MemoryMonitor::lastFreeMemory = 0;
unsigned long MemoryMonitor::lastCheck = 0;

// Optimized debug macros using less memory
#if DEBUG_ENABLED
  #define DEBUG_PRINT_P(x) Serial.print(F(x))
  #define DEBUG_PRINTLN_P(x) Serial.println(F(x))
  #define DEBUG_PRINT_VAL(name, val) do { \
    Serial.print(F(name)); \
    Serial.print(F(": ")); \
    Serial.println(val); \
  } while(0)
#else
  #define DEBUG_PRINT_P(x)
  #define DEBUG_PRINTLN_P(x)
  #define DEBUG_PRINT_VAL(name, val)
#endif

// Stack-based temporary string for one-time use
template<size_t SIZE>
class TempString {
private:
  char buffer[SIZE];
  
public:
  TempString() {
    buffer[0] = '\0';
  }
  
  char* get() { return buffer; }
  size_t size() const { return SIZE; }
  
  void printf(const char* format, ...) {
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, SIZE, format, args);
    va_end(args);
  }
  
  void printf_P(PGM_P format, ...) {
    va_list args;
    va_start(args, format);
    vsnprintf_P(buffer, SIZE, format, args);
    va_end(args);
  }
};

#endif // MEMORY_OPTIMIZATION_H
