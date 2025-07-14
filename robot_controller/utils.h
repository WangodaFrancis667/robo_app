/**********************************************************************
 *  utils.h - Utility Functions and Helpers
 *  Common utility functions used across the system
 *********************************************************************/

#ifndef UTILS_H
#define UTILS_H

#include <Arduino.h>

// Memory check function
inline int freeMemory() {
  char top;
  extern char *__brkval;
  extern char __bss_end;
  return __brkval ? &top - __brkval : &top - &__bss_end;
}

// String utility functions - optimized for memory
inline void formatTime(unsigned long milliseconds, char* buffer, size_t bufferSize) {
  unsigned long seconds = milliseconds / 1000;
  unsigned long minutes = seconds / 60;
  unsigned long hours = minutes / 60;

  if (hours > 0) {
    snprintf(buffer, bufferSize, "%luh %lum %lus", hours, minutes % 60, seconds % 60);
  } else if (minutes > 0) {
    snprintf(buffer, bufferSize, "%lum %lus", minutes, seconds % 60);
  } else {
    snprintf(buffer, bufferSize, "%lus", seconds);
  }
}

// Math utility functions
inline int constrainSpeed(int speed) { return constrain(speed, -100, 100); }

inline int constrainAngle(int angle) { return constrain(angle, 0, 180); }

inline int mapSpeedToPWM(int speed) { return map(abs(speed), 0, 100, 0, 255); }

// Validation functions
inline bool isValidSpeed(int speed) { return (speed >= -100 && speed <= 100); }

inline bool isValidAngle(int angle) { return (angle >= 0 && angle <= 180); }

// Timing utilities
inline bool hasTimeElapsed(unsigned long lastTime, unsigned long interval) {
  return (millis() - lastTime) >= interval;
}

inline unsigned long getElapsedTime(unsigned long startTime) {
  return millis() - startTime;
}

// Helper functions for name retrieval - optimized for memory
inline const char* getMotorName(int motorIndex) {
  switch (motorIndex) {
  case 0:
    return "FL";
  case 1:
    return "RL";
  case 2:
    return "FR";
  case 3:
    return "RR";
  default:
    return "?";
  }
}

inline const char* getServoName(int servoIndex) {
  switch (servoIndex) {
  case 0:
    return "Base";
  case 1:
    return "Shoulder";
  case 2:
    return "Elbow";
  case 3:
    return "WristR";
  case 4:
    return "WristT";
  case 5:
    return "Grip";
  default:
    return "?";
  }
}

inline const char* getSensorName(int sensorIndex) {
  switch (sensorIndex) {
  case 0:
    return "Front";
  case 1:
    return "Rear";
  default:
    return "?";
  }
}

#endif // UTILS_H