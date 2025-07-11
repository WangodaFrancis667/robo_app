/**********************************************************************
 *  Arduino Mega 2560 - Motor Test & Standalone Controller
 *  Test motor directions and control via Serial Monitor
 *  Can be easily modified to connect with TTGO T-Call later
 * 
 *  USAGE:
 *  1. Upload this code to test motors individually
 *  2. Use Serial Monitor to send movement commands
 *  3. Uncomment TTGO_CONNECTION section when ready to connect ESP32
 *********************************************************************/

 #include <Arduino.h>

 // ========== CONFIGURATION SECTION ==========
 
 // Set to true for standalone testing, false when connecting to TTGO
 #define STANDALONE_MODE false
 
 // Uncomment this line when ready to connect to TTGO T-Call
 #define TTGO_CONNECTION
 
 // Uncomment this if your motor drivers don't have separate enable pins
 // #define NO_SEPARATE_ENABLE_PINS
 
 // ========== MOTOR DRIVER PIN CONFIGURATION ==========
 
 // Driver Board 1 (Left Motors)
 const int DRIVER1_D0 = 22;  // Front Left Motor Control 1
 const int DRIVER1_D1 = 23;  // Front Left Motor Control 2
 const int DRIVER1_D2 = 24;  // Rear Left Motor Control 1
 const int DRIVER1_D3 = 25;  // Rear Left Motor Control 2
 
 // Driver Board 2 (Right Motors)
 const int DRIVER2_D0 = 26;  // Front Right Motor Control 1
 const int DRIVER2_D1 = 27;  // Front Right Motor Control 2
 const int DRIVER2_D2 = 28;  // Rear Right Motor Control 1
 const int DRIVER2_D3 = 29;  // Rear Right Motor Control 2
 
 // PWM Enable pins (comment out if using NO_SEPARATE_ENABLE_PINS)
 #ifndef NO_SEPARATE_ENABLE_PINS
 const int DRIVER1_EN1 = 2;  // PWM for Front Left motor
 const int DRIVER1_EN2 = 3;  // PWM for Rear Left motor
 const int DRIVER2_EN1 = 4;  // PWM for Front Right motor
 const int DRIVER2_EN2 = 5;  // PWM for Rear Right motor
 #endif
 
 // ========== COMMUNICATION SETUP ==========
 
 #ifdef TTGO_CONNECTION
 // Use Serial1 for TTGO T-Call communication
 #define ESP32_SERIAL Serial1
 #define COMMAND_SOURCE ESP32_SERIAL
 #else
 // Use main Serial for standalone testing
 #define COMMAND_SOURCE Serial
 #endif
 
 // ========== SYSTEM VARIABLES ==========
 
 // Status LED
 const int STATUS_LED = 13;
 
 // Motor control variables
 int globalSpeedMultiplier = 60;  // Start with lower speed for testing
 bool debugMode = true;
 unsigned long lastCommand = 0;
 const unsigned long COMMAND_TIMEOUT = 500; // 5 seconds for testing
 const int MIN_SPEED_THRESHOLD = 20;
 
 // Motor indices
 #define FRONT_LEFT  0
 #define REAR_LEFT   1
 #define FRONT_RIGHT 2
 #define REAR_RIGHT  3
 
 // Motor state tracking
 struct MotorState {
   int currentSpeed;
   bool isRunning;
   unsigned long lastUpdate;
   String name;
 };
 
 MotorState motors[4] = {
   {0, false, 0, "FL"}, // Front Left
   {0, false, 0, "RL"}, // Rear Left  
   {0, false, 0, "FR"}, // Front Right
   {0, false, 0, "RR"}  // Rear Right
 };
 
 // Command buffer
 String commandBuffer = "";
 bool systemReady = false;
 
 void setup() {
   // Initialize serial communications
   Serial.begin(115200);
   
 #ifdef TTGO_CONNECTION
   ESP32_SERIAL.begin(9600);
 #endif
   
   delay(2000);
   
   Serial.println("===============================================");
   Serial.println("Arduino Mega Motor Test & Controller v1.0");
   Serial.println("4WD Robot with D0-D3 Motor Drivers");
   
 #if STANDALONE_MODE
   Serial.println("MODE: Standalone Testing");
   Serial.println("Use Serial Monitor to send commands");
 #else
   Serial.println("MODE: TTGO T-Call Connection");
 #endif
 
   Serial.println("===============================================");
   
   // Initialize status LED
   pinMode(STATUS_LED, OUTPUT);
   digitalWrite(STATUS_LED, LOW);
   
   // Initialize motor pins
   setupMotorPins();
   
   // Stop all motors initially
   stopAllMotors();
   
   // System ready
   systemReady = true;
   digitalWrite(STATUS_LED, HIGH);
   
   Serial.println("✅ System Ready!");
   Serial.println();
   printHelp();
   Serial.println("===============================================");
   
 #ifdef TTGO_CONNECTION
   // Send ready signal to ESP32
   ESP32_SERIAL.println("MEGA_READY");
 #endif
   
   delay(1000);
 }
 
 void setupMotorPins() {
   Serial.println("🔧 Configuring motor driver pins...");
   
   // Driver Board 1 (Left Motors)
   pinMode(DRIVER1_D0, OUTPUT);
   pinMode(DRIVER1_D1, OUTPUT);
   pinMode(DRIVER1_D2, OUTPUT);
   pinMode(DRIVER1_D3, OUTPUT);
   
   // Driver Board 2 (Right Motors)
   pinMode(DRIVER2_D0, OUTPUT);
   pinMode(DRIVER2_D1, OUTPUT);
   pinMode(DRIVER2_D2, OUTPUT);
   pinMode(DRIVER2_D3, OUTPUT);
   
 #ifndef NO_SEPARATE_ENABLE_PINS
   // PWM Enable pins
   pinMode(DRIVER1_EN1, OUTPUT);
   pinMode(DRIVER1_EN2, OUTPUT);
   pinMode(DRIVER2_EN1, OUTPUT);
   pinMode(DRIVER2_EN2, OUTPUT);
   Serial.println("✅ Using separate PWM enable pins");
 #else
   Serial.println("✅ Using direct PWM on D pins");
 #endif
   
   Serial.println("📍 Pin Configuration:");
   Serial.println("   Driver 1 (Left): D0=22, D1=23, D2=24, D3=25");
   Serial.println("   Driver 2 (Right): D0=26, D1=27, D2=28, D3=29");
   
 #ifndef NO_SEPARATE_ENABLE_PINS
   Serial.println("   PWM Enable: EN1=2, EN2=3, EN3=4, EN4=5");
 #endif
 }
 
 void printHelp() {
   Serial.println("🎮 AVAILABLE COMMANDS:");
   Serial.println("📋 Individual Motor Testing:");
   Serial.println("   TEST_FL:speed    - Test Front Left motor");
   Serial.println("   TEST_RL:speed    - Test Rear Left motor");
   Serial.println("   TEST_FR:speed    - Test Front Right motor");
   Serial.println("   TEST_RR:speed    - Test Rear Right motor");
   Serial.println();
   Serial.println("🚗 Movement Commands:");
   Serial.println("   FORWARD:speed    - Move forward (0-100)");
   Serial.println("   BACKWARD:speed   - Move backward (0-100)");
   Serial.println("   LEFT:speed       - Turn left (0-100)");
   Serial.println("   RIGHT:speed      - Turn right (0-100)");
   Serial.println("   TANK:left,right  - Tank drive (-100 to 100)");
   Serial.println();
   Serial.println("⚙️ System Commands:");
   Serial.println("   STOP             - Stop all motors");
   Serial.println("   SPEED:value      - Set global speed (20-100)");
   Serial.println("   TEST_ALL         - Test all motors in sequence");
   Serial.println("   STATUS           - Show system status");
   Serial.println("   DEBUG:0/1        - Toggle debug output");
   Serial.println("   HELP             - Show this help");
   Serial.println();
   Serial.println("⚡ Current Speed: " + String(globalSpeedMultiplier) + "%");
 }
 
 void setMotorSpeed(int motorNum, int speed) {
   if (motorNum < 0 || motorNum > 3) return;
   
   // Clamp speed to valid range
   speed = constrain(speed, -100, 100);
   
   // Apply global speed multiplier
   int adjustedSpeed = (speed * globalSpeedMultiplier) / 100;
   adjustedSpeed = constrain(adjustedSpeed, -100, 100);
   
   // Apply minimum speed threshold
   if (abs(adjustedSpeed) > 0 && abs(adjustedSpeed) < MIN_SPEED_THRESHOLD) {
     adjustedSpeed = (adjustedSpeed > 0) ? MIN_SPEED_THRESHOLD : -MIN_SPEED_THRESHOLD;
   }
   
   // Update motor state
   motors[motorNum].currentSpeed = adjustedSpeed;
   motors[motorNum].lastUpdate = millis();
   
   // Get motor control pins
   int d0Pin, d1Pin;
   int enablePin = -1;
   getMotorPins(motorNum, d0Pin, d1Pin, enablePin);
   
   if (adjustedSpeed == 0) {
     // Stop motor
     digitalWrite(d0Pin, LOW);
     digitalWrite(d1Pin, LOW);
     
 #ifndef NO_SEPARATE_ENABLE_PINS
     if (enablePin != -1) {
       analogWrite(enablePin, 0);
     }
 #endif
     
     motors[motorNum].isRunning = false;
     
     if (debugMode) {
       Serial.print("🛑 Motor ");
       Serial.print(motors[motorNum].name);
       Serial.println(" STOPPED");
     }
     return;
   }
   
   // Calculate PWM value (0-255)
   int pwmValue = map(abs(adjustedSpeed), 0, 100, 0, 255);
   
 #ifdef NO_SEPARATE_ENABLE_PINS
   // Direct PWM control on D pins
   if (adjustedSpeed > 0) {
     // Forward: D0=PWM, D1=LOW
     analogWrite(d0Pin, pwmValue);
     digitalWrite(d1Pin, LOW);
   } else {
     // Reverse: D0=LOW, D1=PWM
     digitalWrite(d0Pin, LOW);
     analogWrite(d1Pin, pwmValue);
   }
 #else
   // Using separate enable pins for PWM
   if (adjustedSpeed > 0) {
     // Forward: D0=HIGH, D1=LOW
     digitalWrite(d0Pin, HIGH);
     digitalWrite(d1Pin, LOW);
   } else {
     // Reverse: D0=LOW, D1=HIGH
     digitalWrite(d0Pin, LOW);
     digitalWrite(d1Pin, HIGH);
   }
   
   // Set PWM on enable pin
   if (enablePin != -1) {
     analogWrite(enablePin, pwmValue);
   }
 #endif
   
   motors[motorNum].isRunning = true;
   
   if (debugMode) {
     Serial.print("🔧 Motor ");
     Serial.print(motors[motorNum].name);
     Serial.print(": ");
     Serial.print(adjustedSpeed);
     Serial.print("% -> PWM:");
     Serial.print(pwmValue);
     Serial.print(", DIR:");
     Serial.println(adjustedSpeed > 0 ? "FWD" : "REV");
   }
 }
 
 void getMotorPins(int motorNum, int &d0Pin, int &d1Pin, int &enablePin) {
   switch (motorNum) {
     case FRONT_LEFT:
       d0Pin = DRIVER1_D0;
       d1Pin = DRIVER1_D1;
 #ifndef NO_SEPARATE_ENABLE_PINS
       enablePin = DRIVER1_EN1;
 #else
       enablePin = -1;
 #endif
       break;
       
     case REAR_LEFT:
       d0Pin = DRIVER1_D2;
       d1Pin = DRIVER1_D3;
 #ifndef NO_SEPARATE_ENABLE_PINS
       enablePin = DRIVER1_EN2;
 #else
       enablePin = -1;
 #endif
       break;
       
     case FRONT_RIGHT:
       d0Pin = DRIVER2_D0;
       d1Pin = DRIVER2_D1;
 #ifndef NO_SEPARATE_ENABLE_PINS
       enablePin = DRIVER2_EN1;
 #else
       enablePin = -1;
 #endif
       break;
       
     case REAR_RIGHT:
       d0Pin = DRIVER2_D2;
       d1Pin = DRIVER2_D3;
 #ifndef NO_SEPARATE_ENABLE_PINS
       enablePin = DRIVER2_EN2;
 #else
       enablePin = -1;
 #endif
       break;
   }
 }
 
 void stopAllMotors() {
   for (int i = 0; i < 4; i++) {
     setMotorSpeed(i, 0);
   }
   if (debugMode) {
     Serial.println("⏹️ All motors stopped");
   }
 }
 
 void testIndividualMotor(int motorNum, int speed, int duration = 2000) {
   Serial.print("🧪 Testing motor ");
   Serial.print(motors[motorNum].name);
   Serial.print(" at ");
   Serial.print(speed);
   Serial.println("%");
   
   setMotorSpeed(motorNum, speed);
   delay(duration);
   setMotorSpeed(motorNum, 0);
   delay(500);
 }
 
 void testAllMotors() {
   Serial.println("🧪 Starting comprehensive motor test...");
   Serial.println("⚡ Speed: " + String(globalSpeedMultiplier) + "%");
   
   int testSpeed = 50;
   
   // Test each motor individually
   for (int i = 0; i < 4; i++) {
     Serial.println("Testing " + motors[i].name + " motor...");
     
     // Forward test
     Serial.println("  → Forward");
     testIndividualMotor(i, testSpeed, 1500);
     
     // Reverse test
     Serial.println("  → Reverse");
     testIndividualMotor(i, -testSpeed, 1500);
     
     Serial.println("  ✅ " + motors[i].name + " test complete");
   }
   
   Serial.println("🧪 Testing coordinated movements...");
   
   // Test movements
   Serial.println("  → All Forward");
   moveForward(testSpeed);
   delay(1500);
   stopAllMotors();
   delay(500);
   
   Serial.println("  → All Backward");
   moveBackward(testSpeed);
   delay(1500);
   stopAllMotors();
   delay(500);
   
   Serial.println("  → Turn Left");
   turnLeft(testSpeed);
   delay(1500);
   stopAllMotors();
   delay(500);
   
   Serial.println("  → Turn Right");
   turnRight(testSpeed);
   delay(1500);
   stopAllMotors();
   
   Serial.println("✅ All tests completed!");
 }
 
 // Movement functions
 void moveForward(int speed) {
   if (debugMode) {
     Serial.println("⬆️ Moving forward at " + String(speed) + "%");
   }
   setMotorSpeed(FRONT_LEFT, speed);
   setMotorSpeed(REAR_LEFT, speed);
   setMotorSpeed(FRONT_RIGHT, -speed);
   setMotorSpeed(REAR_RIGHT, -speed);
 }
 
 void moveBackward(int speed) {
   if (debugMode) {
     Serial.println("⬇️ Moving backward at " + String(speed) + "%");
   }
   setMotorSpeed(FRONT_LEFT, -speed);
   setMotorSpeed(REAR_LEFT, -speed);
   setMotorSpeed(FRONT_RIGHT, speed);
   setMotorSpeed(REAR_RIGHT, speed);
 }
 
 void turnLeft(int speed) {
   if (debugMode) {
     Serial.println("⬅️ Turning left at " + String(speed) + "%");
   }
   setMotorSpeed(FRONT_LEFT, -speed);
   setMotorSpeed(REAR_LEFT, -speed);
   setMotorSpeed(FRONT_RIGHT,- speed);
   setMotorSpeed(REAR_RIGHT, -speed);
 }
 
 void turnRight(int speed) {
   if (debugMode) {
     Serial.println("➡️ Turning right at " + String(speed) + "%");
   }
   setMotorSpeed(FRONT_LEFT, speed);
   setMotorSpeed(REAR_LEFT, speed);
   setMotorSpeed(FRONT_RIGHT, speed);
   setMotorSpeed(REAR_RIGHT, speed);
 }
 
 void tankDrive(int leftSpeed, int rightSpeed) {
   if (debugMode) {
     Serial.println("🎮 Tank drive - Left: " + String(leftSpeed) + "%, Right: " + String(rightSpeed) + "%");
   }
   setMotorSpeed(FRONT_LEFT, leftSpeed);
   setMotorSpeed(REAR_LEFT, leftSpeed);
   setMotorSpeed(FRONT_RIGHT, rightSpeed);
   setMotorSpeed(REAR_RIGHT, rightSpeed);
 }
 
 void processCommand(String command) {
   command.trim();
   command.toUpperCase();
   lastCommand = millis();
   
   if (debugMode) {
     Serial.println("📨 Command: " + command);
   }
   
   // Individual motor testing commands
   if (command.startsWith("TEST_FL:")) {
     int speed = command.substring(8).toInt();
     speed = constrain(speed, -100, 100);
     testIndividualMotor(FRONT_LEFT, speed);
     Serial.println("OK TEST_FL");
     
   } else if (command.startsWith("TEST_RL:")) {
     int speed = command.substring(8).toInt();
     speed = constrain(speed, -100, 100);
     testIndividualMotor(REAR_LEFT, speed);
     Serial.println("OK TEST_RL");
     
   } else if (command.startsWith("TEST_FR:")) {
     int speed = command.substring(8).toInt();
     speed = constrain(speed, -100, 100);
     testIndividualMotor(FRONT_RIGHT, speed);
     Serial.println("OK TEST_FR");
     
   } else if (command.startsWith("TEST_RR:")) {
     int speed = command.substring(8).toInt();
     speed = constrain(speed, -100, 100);
     testIndividualMotor(REAR_RIGHT, speed);
     Serial.println("OK TEST_RR");
     
   } 
   
   // Movement commands
   else if (command.startsWith("FORWARD:")) {
     int speed = command.substring(8).toInt();
     speed = constrain(speed, 0, 100);
     moveForward(speed);
     Serial.println("OK FORWARD");
     
   } else if (command.startsWith("BACKWARD:")) {
     int speed = command.substring(9).toInt();
     speed = constrain(speed, 0, 100);
     moveBackward(speed);
     Serial.println("OK BACKWARD");
     
   } else if (command.startsWith("LEFT:")) {
     int speed = command.substring(5).toInt();
     speed = constrain(speed, 0, 100);
     turnLeft(speed);
     Serial.println("OK LEFT");
     
   } else if (command.startsWith("RIGHT:")) {
     int speed = command.substring(6).toInt();
     speed = constrain(speed, 0, 100);
     turnRight(speed);
     Serial.println("OK RIGHT");
     
   } else if (command.startsWith("TANK:")) {
     int commaIndex = command.indexOf(',');
     if (commaIndex > 0) {
       int leftSpeed = command.substring(5, commaIndex).toInt();
       int rightSpeed = command.substring(commaIndex + 1).toInt();
       leftSpeed = constrain(leftSpeed, -100, 100);
       rightSpeed = constrain(rightSpeed, -100, 100);
       tankDrive(leftSpeed, rightSpeed);
       Serial.println("OK TANK");
     } else {
       Serial.println("ERROR TANK_FORMAT");
     }
     
   } 
   
   // System commands
   else if (command.startsWith("SPEED:")) {
     int speed = command.substring(6).toInt();
     speed = constrain(speed, 20, 100);
     globalSpeedMultiplier = speed;
     Serial.println("OK SPEED:" + String(speed));
     Serial.println("🚀 Global speed set to: " + String(speed) + "%");
     
   } else if (command == "STOP") {
     stopAllMotors();
     Serial.println("OK STOP");
     
   } else if (command == "TEST_ALL") {
     testAllMotors();
     Serial.println("OK TEST_ALL");
     
   } else if (command == "STATUS") {
     Serial.println("📊 SYSTEM STATUS:");
     Serial.println("   Speed: " + String(globalSpeedMultiplier) + "%");
     Serial.print("   Motors: ");
     for (int i = 0; i < 4; i++) {
       Serial.print(motors[i].name + ":" + String(motors[i].currentSpeed) + "%");
       if (i < 3) Serial.print(", ");
     }
     Serial.println();
     Serial.println("   Uptime: " + String(millis()) + "ms");
     Serial.println("   Free RAM: " + String(freeMemory()) + " bytes");
     Serial.println("OK STATUS");
     
   } else if (command.startsWith("DEBUG:")) {
     int debug = command.substring(6).toInt();
     debugMode = (debug == 1);
     Serial.println("OK DEBUG:" + String(debug));
     Serial.println("🔍 Debug mode: " + String(debugMode ? "ON" : "OFF"));
     
   } else if (command == "HELP") {
     printHelp();
     Serial.println("OK HELP");
     
   } else if (command == "PING") {
     Serial.println("PONG");
     
   } else {
     Serial.println("ERROR UNKNOWN_COMMAND");
     Serial.println("❌ Unknown command. Type HELP for available commands.");
   }
 }
 
 // Simple memory check function
 int freeMemory() {
   char top;
   extern char *__brkval;
   extern char __bss_end;
   return __brkval ? &top - __brkval : &top - &__bss_end;
 }
 
 void loop() {
   Serial.println("");
 
   // Blink status LED
   static unsigned long lastBlink = 0;
   if (millis() - lastBlink > 1000) {
     digitalWrite(STATUS_LED, !digitalRead(STATUS_LED));
     lastBlink = millis();
   }
   
   // Read commands from appropriate source
   while (COMMAND_SOURCE.available()) {
     char c = COMMAND_SOURCE.read();
     if (c == '\n' || c == '\r') {
       if (commandBuffer.length() > 0) {
         processCommand(commandBuffer);
         commandBuffer = "";
       }
     } else {
       commandBuffer += c;
     }
   }
   
   // Safety timeout
   if (millis() - lastCommand > COMMAND_TIMEOUT && lastCommand != 0) {
     stopAllMotors();
       Serial.println(lastCommand);
     lastCommand = 0;
     if (debugMode) {
       Serial.println("⚠️ Command timeout - motors stopped for safety");
     }
   }
   
   delay(10);
 }