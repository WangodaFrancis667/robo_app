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

// String utility functions
inline String formatTime(unsigned long milliseconds) {
  unsigned long seconds = milliseconds / 1000;
  unsigned long minutes = seconds / 60;
  unsigned long hours = minutes / 60;
  
  if (hours > 0) {
    return String(hours) + "h " + String(minutes % 60) + "m " + String(seconds % 60) + "s";
  } else if (minutes > 0) {
    return String(minutes) + "m " + String(seconds % 60) + "s";
  } else {
    return String(seconds) + "s";
  }
}

// Math utility functions
inline int constrainSpeed(int speed) {
  return constrain(speed, -100, 100);
}

inline int constrainAngle(int angle) {
  return constrain(angle, 0, 180);
}

inline int mapSpeedToPWM(int speed) {
  return map(abs(speed), 0, 100, 0, 255);
}

// Validation functions
inline bool isValidSpeed(int speed) {
  return (speed >= -100 && speed <= 100);
}

inline bool isValidAngle(int angle) {
  return (angle >= 0 && angle <= 180);
}

// Timing utilities
inline bool hasTimeElapsed(unsigned long lastTime, unsigned long interval) {
  return (millis() - lastTime) >= interval;
}

inline unsigned long getElapsedTime(unsigned long startTime) {
  return millis() - startTime;
}

#endif // UTILS_H