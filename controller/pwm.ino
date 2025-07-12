/**********************************************************************
 *  TTGO T‑Call | ESP32‑Dev‑Module  – Complete Fixed Robot Controller
 *  Enhanced version with MG996R servo fixes and proper speed control
 *  Bluetooth Classic text protocol, drives 6 MG996R servos + 2 ZK‑5AD boards
 *  
 *  FIXES INCLUDED:
 *  - Smooth servo movement to eliminate shaking
 *  - Proper power management for MG996R servos
 *  - Fixed speed control logic
 *  - Enhanced safety features
 *  - Improved diagnostics
 *********************************************************************/

 #if !defined(ESP32)
 #  error "Select an ESP32 board (e.g. ESP32 Dev Module) before compiling."
 #endif
 
 #include <Arduino.h>
 #include <BluetoothSerial.h>
 #include <ESP32Servo.h>
 #include <strings.h>          // strcasecmp()
 
 #define NO_SEPARATE_ENABLE_PINS
 #define COMMAND_SOURCE Serial
 
 /* -------- ZK-5AD Motor Driver Pinout Mapping -------- */
 // LEFT ZK-5AD Motor Driver (controls 2 left-side motors)
 constexpr uint8_t DRIVER1_D0 = 32;    // Motor A (Front Left) control pin 1
 constexpr uint8_t DRIVER1_D1 = 15;    // Motor A (Front Left) control pin 2
 constexpr uint8_t DRIVER1_D2 = 25;    // Motor B (Rear Left) control pin 1  
 constexpr uint8_t DRIVER1_D3 = 26;    // Motor B (Rear Left) control pin 2
 
 // RIGHT ZK-5AD Motor Driver (controls 2 right-side motors)
 constexpr uint8_t DRIVER2_D0 = 33;   // Motor A (Front Right) control pin 1
 constexpr uint8_t DRIVER2_D1= 4;    // Motor A (Front Right) control pin 2
 constexpr uint8_t DRIVER2_D2 = 27;   // Motor B (Rear Right) control pin 1
 constexpr uint8_t DRIVER2_D3 = 14;   // Motor B (Rear Right) control pin 2
 
 /* -------- MG996R Servo Configuration -------- */
 const uint8_t SERVO_PINS[6] = {12, 13, 18, 19, 21, 22};
 Servo servos[6];
 
 // Command buffer
 String commandBuffer = "";
 bool systemReady = false;
 
 // MG996R specific timing (critical for stability)
 constexpr uint16_t SERVO_MIN_PULSE = 500;   // Minimum pulse width in microseconds
 constexpr uint16_t SERVO_MAX_PULSE = 2500;  // Maximum pulse width in microseconds
 constexpr uint8_t SERVO_FREQUENCY = 50;     // 50Hz PWM frequency
 
 // Servo movement parameters for smooth operation
 constexpr uint8_t SERVO_MOVE_DELAY = 15;    // Delay between servo movements (ms)
 constexpr uint8_t SERVO_STEP_SIZE = 2;      // Maximum degrees to move per step
 constexpr uint16_t SERVO_SETTLE_TIME = 300; // Time to let servo settle (ms)
 
 // Current and target servo positions (for smooth movement)
 int currentServoPos[6] = {90, 90, 90, 90, 90, 90};
 int targetServoPos[6] = {90, 90, 90, 90, 90, 90};
 
 /* -------- Motor Control Variables -------- */
 int globalSpeedMultiplier = 80;       // Global speed multiplier (20-100%) - matches UI default
 bool motorDiagnostics = true;         // Enable motor diagnostics
 unsigned long lastMotorCommand = 0;   // Track last motor command time
 unsigned long lastServoUpdate = 0;    // Track servo update timing
 bool debugMode = true;
 unsigned long lastCommand = 0;
 const unsigned long COMMAND_TIMEOUT = 5000; // 5 seconds for testing
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
 
 /* -------- Predefined Poses -------- */
 struct Pose { const char* name; uint8_t a[6]; };
 Pose poses[] = {
   {"Home",  {90, 90, 90, 90, 90, 90}},    // All servos centered - safe position
   {"Pick",  {90,100, 80, 90,100,  0}},    // Ready to pick up object
   {"Place", {90, 80,100, 90, 80,180}},    // Ready to place object  
   {"Rest",  {90, 45,135, 90, 45, 90}}     // Folded/safe position
 };
 constexpr uint8_t NPOSE = sizeof(poses) / sizeof(poses[0]);
 
 /* -------- Bluetooth -------- */
 BluetoothSerial BT;
 constexpr char BT_NAME[] = "ESP32_Robot";
 
 
 
 
 
 
 
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
   
   
   Serial.println("📍 Pin Configuration:");
   Serial.println("   Driver 1 (Left): D0=22, D1=23, D2=24, D3=25");
   Serial.println("   Driver 2 (Right): D0=26, D1=27, D2=28, D3=29");
   

   
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
 
void setMotorDirection(int motorNum, int direction) {
  int d0Pin, d1Pin, enablePin;
  getMotorPins(motorNum, d0Pin, d1Pin, enablePin);

  // Direction: 1 = Forward, -1 = Reverse, 0 = Stop
  if (direction == 1) {
    digitalWrite(d0Pin, HIGH);
    digitalWrite(d1Pin, LOW);
  } else if (direction == -1) {
    digitalWrite(d0Pin, LOW);
    digitalWrite(d1Pin, HIGH);
  } else {
    digitalWrite(d0Pin, LOW);
    digitalWrite(d1Pin, LOW);  // Stop (freewheel)
  }

  motors[motorNum].currentSpeed = direction * 100; // just for tracking
  motors[motorNum].isRunning = (direction != 0);
  motors[motorNum].lastUpdate = millis();

  if (debugMode) {
    Serial.print("🔧 Motor ");
    Serial.print(motors[motorNum].name);
    Serial.print(": DIR=");
    if (direction == 1) Serial.println("FWD");
    else if (direction == -1) Serial.println("REV");
    else Serial.println("STOP");
  }
}

 
 void getMotorPins(int motorNum, int &d0Pin, int &d1Pin) {
   switch (motorNum) {
     case FRONT_LEFT:
       d0Pin = DRIVER1_D0;
       d1Pin = DRIVER1_D1;
       break;

       
     case REAR_LEFT:
       d0Pin = DRIVER1_D2;
       d1Pin = DRIVER1_D3;
       break;

       
     case FRONT_RIGHT:
       d0Pin = DRIVER2_D0;
       d1Pin = DRIVER2_D1;
       break;
 
       
     case REAR_RIGHT:
       d0Pin = DRIVER2_D2;
       d1Pin = DRIVER2_D3;
       break;
   }
 }
 
void stopAllMotors() {
  for (int i = 0; i < 4; i++) {
    setMotorDirection(i, 0);
  }

  if (debugMode) {
    Serial.println("⏹️ All motors stopped");
  }
}

 
void testIndividualMotor(int motorNum, int ignored = 0, int duration = 2000) {
  Serial.print("🧪 Testing motor ");
  Serial.println(motors[motorNum].name);

  setMotorDirection(motorNum, 1); // Forward
  delay(duration);

  setMotorDirection(motorNum, -1); // Reverse
  delay(duration);

  setMotorDirection(motorNum, 0); // Stop
  delay(500);
}

 
void testAllMotors() {
  Serial.println("🧪 Starting basic motor test (no PWM)");

  for (int i = 0; i < 4; i++) {
    Serial.println("Testing " + motors[i].name + "...");
    testIndividualMotor(i, 0, 1500);
  }

  Serial.println("🧪 Testing coordinated motions...");
  moveForward();
  delay(1500);
  stopAllMotors();

  delay(500);
  moveBackward();
  delay(1500);
  stopAllMotors();

  delay(500);
  turnLeft();
  delay(1500);
  stopAllMotors();

  delay(500);
  turnRight();
  delay(1500);
  stopAllMotors();

  Serial.println("✅ All tests done.");
}

 // Movement functions
 void moveForward() {
  stopAllMotors();

  if (debugMode) Serial.println("⬆️ Moving forward");
  setMotorDirection(FRONT_LEFT, 1);
  setMotorDirection(REAR_LEFT, 1);
  setMotorDirection(FRONT_RIGHT, -1);
  setMotorDirection(REAR_RIGHT, -1);
}

void moveBackward() {
  stopAllMotors();

  if (debugMode) Serial.println("⬇️ Moving backward");
  setMotorDirection(FRONT_LEFT, -1);
  setMotorDirection(REAR_LEFT, -1);
  setMotorDirection(FRONT_RIGHT, 1);
  setMotorDirection(REAR_RIGHT, 1);
}

void turnLeft() {
  stopAllMotors();

  if (debugMode) Serial.println("⬅️ Turning left");
  setMotorDirection(FRONT_LEFT, -1);
  setMotorDirection(REAR_LEFT, -1);
  setMotorDirection(FRONT_RIGHT, -1);
  setMotorDirection(REAR_RIGHT, -1);
}

void turnRight() {
  stopAllMotors();

  if (debugMode) Serial.println("➡️ Turning right");
  setMotorDirection(FRONT_LEFT, 1);
  setMotorDirection(REAR_LEFT, 1);
  setMotorDirection(FRONT_RIGHT, 1);
  setMotorDirection(REAR_RIGHT, 1);
}

void tankDrive() {
  if (debugMode) Serial.println("🎮 Tank drive (no PWM): Left=FWD, Right=REV");
  setMotorDirection(FRONT_LEFT, 1);
  setMotorDirection(REAR_LEFT, 1);
  setMotorDirection(FRONT_RIGHT, -1);
  setMotorDirection(REAR_RIGHT, -1);
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
 return ESP.getFreeHeap();
 }
 
 /* -------- FIXED MG996R Servo Control Functions -------- */
 
 void setupServos() {
   Serial.println("🔧 Initializing MG996R servos...");
   Serial.println("⚠  Ensure 6V/10A+ power supply is connected!");
   
   // Initialize servos one by one with delays to prevent power surge
   for (uint8_t i = 0; i < 6; i++) {
     Serial.printf("Attaching servo %d to pin %d...\n", i, SERVO_PINS[i]);
     
     // Configure servo with MG996R specific parameters
     servos[i].setPeriodHertz(SERVO_FREQUENCY);
     servos[i].attach(SERVO_PINS[i], SERVO_MIN_PULSE, SERVO_MAX_PULSE);
     
     // Start at center position
     servos[i].write(90);
     currentServoPos[i] = 90;
     targetServoPos[i] = 90;
     
     delay(300); // Important delay between servo attachments
   }
   
   Serial.println("✅ All servos attached and centered");
   delay(1000); // Let all servos settle before continuing
 }
 
 void moveServoSmooth(uint8_t servoId, uint8_t targetAngle) {
   if (servoId >= 6) return;
   
   // Constrain target angle
   targetAngle = constrain(targetAngle, 0, 180);
   targetServoPos[servoId] = targetAngle;
   
   // Calculate movement direction and steps
   int currentPos = currentServoPos[servoId];
   int diff = targetAngle - currentPos;
   
   if (abs(diff) <= 1) {
     // Already at target, just set it
     servos[servoId].write(targetAngle);
     currentServoPos[servoId] = targetAngle;
     return;
   }
   
   // Move in small steps to reduce stress and eliminate shaking
   // Cast SERVO_STEP_SIZE to int to match types
   int step = (diff > 0) ? min((int)SERVO_STEP_SIZE, diff) : max(-(int)SERVO_STEP_SIZE, diff);
   int newPos = currentPos + step;
   
   servos[servoId].write(newPos);
   currentServoPos[servoId] = newPos;
   
   if (motorDiagnostics) {
     Serial.printf("🤖 Servo %d: %d° -> %d° (target: %d°)\n", 
                   servoId, currentPos, newPos, targetAngle);
   }
 }
 
 void updateServos() {
   // Only update servos every SERVO_MOVE_DELAY milliseconds
   if (millis() - lastServoUpdate < SERVO_MOVE_DELAY) {
     return;
   }
   
   bool anyMoving = false;
   
   for (uint8_t i = 0; i < 6; i++) {
     if (currentServoPos[i] != targetServoPos[i]) {
       moveServoSmooth(i, targetServoPos[i]);
       anyMoving = true;
     }
   }
   
   if (anyMoving) {
     lastServoUpdate = millis();
   }
 }
 
 void toPose(const Pose& p, uint16_t totalTime = 2000) {
   Serial.printf("🎯 Moving to pose: %s\n", p.name);
   
   // Set all target positions
   for (int i = 0; i < 6; i++) {
     targetServoPos[i] = p.a[i];
   }
   
   // Move gradually to targets
   unsigned long startTime = millis();
   while (millis() - startTime < totalTime) {
     updateServos();
     
     // Check if all servos reached target
     bool allReached = true;
     for (int i = 0; i < 6; i++) {
       if (abs(currentServoPos[i] - targetServoPos[i]) > 1) {
         allReached = false;
         break;
       }
     }
     
     if (allReached) {
       Serial.printf("✅ Pose '%s' reached in %lums\n", p.name, millis() - startTime);
       break;
     }
     
     delay(20); // Don't spam servo updates
   }
   
   delay(SERVO_SETTLE_TIME); // Let servos settle
 }
 
 void setServoPosition(uint8_t servoId, uint8_t angle) {
   if (servoId >= 6) return;
   
   angle = constrain(angle, 0, 180);
   targetServoPos[servoId] = angle;
   
   if (motorDiagnostics) {
     Serial.printf("🎯 Servo %d target set to %d°\n", servoId, angle);
   }
 }
 
 void home() { 
   Serial.println("🏠 Moving to home position...");
   toPose(poses[0], 1500);  // 1.5 seconds to home
   stopAllMotors();
 }
 
 /* -------- Enhanced Command Parser -------- */
 constexpr uint8_t BUFSZ = 128;
 char buf[BUFSZ]; 
 uint8_t idx = 0;
 void execCmd(char* cmd, Stream& port) {
   String command = String(cmd);
  command.trim();
  command.toUpperCase();
  lastCommand = millis();

  // FORWARD command (ignores speed)
  if (command.startsWith("FORWARD")) {
    moveForward();
    port.println("OK FORWARD");
    return;
  }

  // BACKWARD command (ignores speed)
  else if (command.startsWith("BACKWARD")) {
    moveBackward();
    port.println("OK BACKWARD");
    return;
  }

  // LEFT command (ignores speed)
  else if (command.startsWith("LEFT")) {
    turnLeft();
    port.println("OK LEFT");
    return;
  }

  // RIGHT command (ignores speed)
  else if (command.startsWith("RIGHT")) {
    turnRight();
    port.println("OK RIGHT");
    return;
  }

  // TANK:left,right — only direction is considered
  else if (command.startsWith("TANK:")) {
    int commaIndex = command.indexOf(',');
    if (commaIndex > 0) {
      int left = command.substring(5, commaIndex).toInt();
      int right = command.substring(commaIndex + 1).toInt();

      int leftDir = (left > 0) ? 1 : (left < 0 ? -1 : 0);
      int rightDir = (right > 0) ? 1 : (right < 0 ? -1 : 0);

      setMotorDirection(FRONT_LEFT, leftDir);
      setMotorDirection(REAR_LEFT, leftDir);
      setMotorDirection(FRONT_RIGHT, rightDir);
      setMotorDirection(REAR_RIGHT, rightDir);

      port.println("OK TANK");
    } else {
      port.println("ERR TANK_FORMAT");
    }
    return;
  }

  // STOP all motors
  else if (command == "STOP") {
    stopAllMotors();
    port.println("OK STOP");
    return;
  }
  // Now handle single-character commands
   if (cmd[0] == 'S') {                              // S:id,angle
     int id, ang;
     if (sscanf(cmd + 2, "%d,%d", &id, &ang) == 2 &&
         id >= 0 && id < 6 && ang >= 0 && ang <= 180) {
       
       setServoPosition(id, ang);
       port.printf("OK S %d %d\n", id, ang);
       
       if (motorDiagnostics) {
         Serial.printf("🤖 Servo %d target: %d°\n", id, ang);
       }
     } else {
       port.println("ERR S: Invalid servo ID (0-5) or angle (0-180)");
     }
   }
 
   if (cmd[0] == 'S') {                              // S:id,angle
     int id, ang;
     if (sscanf(cmd + 2, "%d,%d", &id, &ang) == 2 &&
         id >= 0 && id < 6 && ang >= 0 && ang <= 180) {
       
       setServoPosition(id, ang); // Use smooth movement function
       port.printf("OK S %d %d\n", id, ang);
       
       if (motorDiagnostics) {
         Serial.printf("🤖 Servo %d target: %d°\n", id, ang);
       }
     } else {
       port.println("ERR S: Invalid servo ID (0-5) or angle (0-180)");
     }
   }
 
   else if (cmd[0] == 'P') {                         // P:name
     char* name = cmd + 2;
     for (auto& p : poses)
       if (strcasecmp(name, p.name) == 0) { 
         toPose(p, 2000); // 2 seconds for pose transitions
         port.printf("OK P %s\n", name);
         if (motorDiagnostics) {
           Serial.printf("🎯 Pose set to: %s\n", name);
         }
         return; 
       }
     port.printf("ERR P: Unknown pose '%s' (try: Home/Pick/Place/Rest)\n", name);
   }
 
   else if (cmd[0] == 'M') {                         // M:L|R,±speed
     char lr; 
     int val;
     if (sscanf(cmd + 2, "%c,%d", &lr, &val) == 2) {
       val = constrain(val, -100, 100);  // Clamp input
       if (lr == 'L' || lr == 'l') {
         turnLeft(val);
         port.printf("OK M L %d\n", val);
       } else if (lr == 'R' || lr == 'r') {
         turnRight(val);
         port.printf("OK M R %d\n", val);
       } else {
         port.printf("ERR M: Invalid side '%c' (use L or R)\n", lr);
       }
     } else port.println("ERR M: Format should be M:L,speed or M:R,speed");
   }
 
   else if (cmd[0] == 'W') {                         // W:direction,speed
     char dir;
     int speed;
     if (sscanf(cmd + 2, "%c,%d", &dir, &speed) == 2) {
       speed = constrain(speed, -100, 100);  // Clamp input
       switch (dir) {
         case 'F': case 'f': moveForward(speed); break;
         case 'B': case 'b': moveBackward(speed); break;
         case 'L': case 'l': turnLeft(speed); break;
         case 'R': case 'r': turnRight(speed); break;
         default: port.printf("ERR W: Invalid direction '%c'\n", dir); return;
       }
       port.printf("OK W %c %d\n", dir, speed);
     } else port.println("ERR W: Format should be W:direction,speed");
   }
 
   else if (cmd[0] == 'I') {                         // I:FL,RL,FR,RR
     int fl, rl, fr, rr;
     if (sscanf(cmd + 2, "%d,%d,%d,%d", &fl, &rl, &fr, &rr) == 4) {
       // Clamp all inputs
       fl = constrain(fl, -100, 100);
       rl = constrain(rl, -100, 100);
       fr = constrain(fr, -100, 100);
       rr = constrain(rr, -100, 100);
       
       //motorFrontLeft(fl);
       //motorRearLeft(rl);
       //motorFrontRight(fr);
       //motorRearRight(rr);
       port.printf("OK I %d %d %d %d\n", fl, rl, fr, rr);
     } else port.println("ERR I: Format should be I:FL,RL,FR,RR");
   }
 
   else if (cmd[0] == 'G') {                         // G:speed - Global speed multiplier
     int speed;
     if (sscanf(cmd + 2, "%d", &speed) == 1 && speed >= 20 && speed <= 100) {
       int oldSpeed = globalSpeedMultiplier;
       globalSpeedMultiplier = speed;
       port.printf("OK G %d\n", speed);
       if (motorDiagnostics) {
         Serial.printf("🚀 Global speed changed: %d%% -> %d%%\n", oldSpeed, speed);
       }
     } else port.println("ERR G: Speed must be 20-100");
   }
 
   else if (cmd[0] == 'X') {                         // X - Motor test
     testAllMotors();
     port.println("OK X");
   }
 
   else if (cmd[0] == 'D') {                         // D:0|1 - Diagnostics on/off
     int diag;
     if (sscanf(cmd + 2, "%d", &diag) == 1 && (diag == 0 || diag == 1)) {
       motorDiagnostics = (diag == 1);
       port.printf("OK D %d\n", diag);
       Serial.printf("🔍 Diagnostics %s\n", motorDiagnostics ? "ENABLED" : "DISABLED");
     } else port.println("ERR D: Use D:0 (off) or D:1 (on)");
   }
 
   else if (cmd[0] == 'V') {                         // V - Get status
     port.printf("STATUS: Speed=%d%%, Diag=%s, Uptime=%lums, FreeHeap=%d, Servos=", 
                 globalSpeedMultiplier, 
                 motorDiagnostics ? "ON" : "OFF", 
                 millis(),
                 ESP.getFreeHeap());
     
     // Print current servo positions
     for (int i = 0; i < 6; i++) {
       port.printf("%d", currentServoPos[i]);
       if (i < 5) port.print(",");
     }
     port.println();
   }
 
   else if (cmd[0] == 'H') { 
     home(); 
     port.println("OK H - Homed");
     if (motorDiagnostics) Serial.println("🏠 Robot homed");
   }
   
   else if (cmd[0] == 'E') { 
     stopAllMotors();
     // Emergency stop - immediately stop all servos at current position
     for (int i = 0; i < 6; i++) {
       targetServoPos[i] = currentServoPos[i];
     }
     port.println("OK E - Emergency stop");
     if (motorDiagnostics) Serial.println("🚨 EMERGENCY STOP - All motion halted");
   }
   
   else if (cmd[0] == 'T') {                         // T:L,R - Tank drive
     int left, right;
     if (sscanf(cmd + 2, "%d,%d", &left, &right) == 2) {
       // Clamp inputs
       left = constrain(left, -100, 100);
       right = constrain(right, -100, 100);
       
       turnLeft(left);
       turnRight(right);
       port.printf("OK T %d %d\n", left, right);
       
       if (motorDiagnostics) {
         Serial.printf("🎮 Tank drive: L=%d%%, R=%d%% (global=%d%%)\n", 
                       left, right, globalSpeedMultiplier);
       }
     } else port.println("ERR T: Format should be T:left,right");
   }
   
   else { 
     port.printf("ERR ?: Unknown command '%c'\n", cmd[0]); 
   }
 }
 
 void feed(Stream& port) {
   while (port.available()) {
     char c = port.read();
     if (c == '\n' || c == '\r') {
       buf[idx] = '\0';
       if (idx) {
         if (motorDiagnostics) {
           Serial.printf("📨 Received: %s\n", buf);
         }
         execCmd(buf, port);
       }
       idx = 0;
     } else if (idx < BUFSZ - 1) {
       buf[idx++] = c;
     }
   }
 }
 
 /* -------- Setup Function -------- */
 void setup() {
   Serial.begin(115200);
   delay(1000);  // Allow serial to initialize
   
   Serial.println("\n🤖 ESP32 Enhanced 4WD Robot Controller Starting...");
   Serial.printf("Version: MG996R Fixed v2.0\n");
   Serial.printf("Build: %s %s\n", __DATE__, __TIME__);
   Serial.println("===============================================");
   
 //initialise motor pins
 setupMotorPins();
   // Initialize all motors to stopped state
   stopAllMotors();
   Serial.println("✅ Motors initialized and stopped");
 
   // Initialize MG996R servos with proper sequencing
   setupServos();
 
   // Initialize Bluetooth
   Serial.println("🔧 Starting Bluetooth...");
   if (BT.begin(BT_NAME)) {
     Serial.println("✅ Bluetooth ready as \"" + String(BT_NAME) + "\"");
   } else {
     Serial.println("⚠  Bluetooth init failed!");
   }
 
   // Move to home position
   Serial.println("🏠 Moving to home position...");
   home();
   
   Serial.println("\n✅ MG996R Robot controller ready!");
   Serial.println("===============================================");
   Serial.println("🔌 Hardware Setup:");
   Serial.println("   LEFT ZK-5AD:  IN1→32, IN2→15, IN3→25, IN4→26");
   Serial.println("   RIGHT ZK-5AD: IN1→33, IN2→4,  IN3→27, IN4→14");
   Serial.println("   Servos: 12→Base, 13→Shoulder, 18→Elbow");
   Serial.println("           19→Wrist Pitch, 21→Wrist Roll, 22→Gripper");
   Serial.println("   ⚠  IMPORTANT: Use 6V/10A+ power supply for servos!");
   Serial.println("   ⚠  Add 2200µF capacitor across servo power!");
   
   Serial.printf("🚗 Current Settings:\n");
   Serial.printf("   Global speed: %d%%\n", globalSpeedMultiplier);
   Serial.printf("   Min speed threshold: %d%%\n", MIN_SPEED_THRESHOLD);
   Serial.printf("   Motor timeout: %dms\n", COMMAND_TIMEOUT);
   Serial.printf("   Servo move delay: %dms\n", SERVO_MOVE_DELAY);
   Serial.printf("   Diagnostics: %s\n", motorDiagnostics ? "ON" : "OFF");
   
   Serial.println("📟 Available Commands:");
   Serial.println("   S:id,angle - Servo control (0-5, 0-180°)");
   Serial.println("   P:name - Poses (Home/Pick/Place/Rest)");
   Serial.println("   T:left,right - Tank drive (-100 to 100)");
   Serial.println("   G:speed - Global speed (20-100%)");
   Serial.println("   X - Test all motors");
   Serial.println("   D:0|1 - Diagnostics off/on");
   Serial.println("   V - Get detailed status");
   Serial.println("   H - Home position");
   Serial.println("   E - Emergency stop");
   
   Serial.println("💡 Try these commands:");
   Serial.println("   G:60 - Set medium speed");
   Serial.println("   T:50,50 - Move forward");
   Serial.println("   P:Pick - Go to pick pose");
   Serial.println("   S:5,0 - Open gripper");
   
   Serial.println("🎮 Ready for commands!\n");
 }
 
 /* -------- Main Loop with Enhanced Safety -------- */
 void loop() {
 
   // Process incoming commands
    feed(Serial);
    feed(BT);
 

   
   // Update servo positions gradually (critical for smooth movement)
   updateServos();
   
   // Read commands from appropriate source
   while (COMMAND_SOURCE.available()) {
     char c = COMMAND_SOURCE.read();
     if (c == '\n' || c == '\r') {
       if (commandBuffer.length() > 0) {
 
       Serial.println("new command");
         
           //processCommand(commandBuffer);
           //commandBuffer = "";
       }
     } else {
       commandBuffer += c;
     }
   }
   
       Serial.println(lastCommand);
   // Safety timeout
   if (millis() - lastCommand > COMMAND_TIMEOUT && lastCommand != 0) {
     stopAllMotors();
     lastCommand = 0;
     if (debugMode) {
       Serial.println("⚠️ Command timeout - motors stopped for safety");
     }
   }
   
   delay(10);
 }