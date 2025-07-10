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
 *  - Updated for latest ESP32 Arduino Core
 *********************************************************************/

#if !defined(ESP32)
#error "Select an ESP32 board (e.g. ESP32 Dev Module) before compiling."
#endif

#include <Arduino.h>
#include <BluetoothSerial.h>
#include <ESP32Servo.h>
#include <strings.h> // strcasecmp()

/* -------- ZK-5AD Motor Driver Pinout Mapping -------- */
// LEFT ZK-5AD Motor Driver (controls 2 left-side motors)
constexpr uint8_t PWM_FREQUENCY = 1000; // Front Left PWM-enabled
constexpr uint8_t PWM_RESOLUTION = 8;   // Front Left PWM-enabled

constexpr uint8_t FL_PWM_PIN = 32;    // Front Left PWM-enabled
constexpr uint8_t FL_DIR_PIN = 15;    // Front Left Direction pin
constexpr uint8_t FL_PWM_CHANNEL = 0; // Front Left PWM CHANNEL

constexpr uint8_t RL_PWM_PIN = 25;    // Rear Left PWM-enabled
constexpr uint8_t RL_DIR_PIN = 26;    // Rear Left Direction pin
constexpr uint8_t RL_PWM_CHANNEL = 1; // Rear Left PWM CHANNEL

// RIGHT ZK-5AD Motor Driver (controls 2 right-side motors)
constexpr uint8_t FR_PWM_PIN = 33;    // Front Right PWM-enabled
constexpr uint8_t FR_DIR_PIN = 4;     // Front Right Direction pin
constexpr uint8_t FR_PWM_CHANNEL = 2; // Front Right PWM CHANNEL

constexpr uint8_t RR_PWM_PIN = 27;    // Rear Right PWM-enabled
constexpr uint8_t RR_DIR_PIN = 14;    // Rear Right Direction pin
constexpr uint8_t RR_PWM_CHANNEL = 3; // Rear Right PWM CHANNEL

/* -------- MG996R Servo Configuration -------- */
const uint8_t SERVO_PINS[6] = {12, 13, 18, 19, 21, 22};
Servo servos[6];

// MG996R specific timing (critical for stability)
constexpr uint16_t SERVO_MIN_PULSE = 500; // Minimum pulse width in microseconds
constexpr uint16_t SERVO_MAX_PULSE =
    2500;                               // Maximum pulse width in microseconds
constexpr uint8_t SERVO_FREQUENCY = 50; // 50Hz PWM frequency

// Servo movement parameters for smooth operation
constexpr uint8_t SERVO_MOVE_DELAY = 15; // Delay between servo movements (ms)
constexpr uint8_t SERVO_STEP_SIZE = 2;   // Maximum degrees to move per step
constexpr uint16_t SERVO_SETTLE_TIME = 300; // Time to let servo settle (ms)

// Current and target servo positions (for smooth movement)
int currentServoPos[6] = {90, 90, 90, 90, 90, 90};
int targetServoPos[6] = {90, 90, 90, 90, 90, 90};

/* -------- Motor Control Variables -------- */
int globalSpeedMultiplier =
    80; // Global speed multiplier (20-100%) - matches UI default
bool motorDiagnostics = true;                 // Enable motor diagnostics
unsigned long lastMotorCommand = 0;           // Track last motor command time
unsigned long lastServoUpdate = 0;            // Track servo update timing
constexpr unsigned long MOTOR_TIMEOUT = 3000; // 3 seconds motor timeout
constexpr uint8_t MIN_SPEED = 20;             // Minimum speed threshold

/* -------- Predefined Poses -------- */
struct Pose {
  const char *name;
  uint8_t a[6];
};
Pose poses[] = {
    {"Home", {90, 90, 90, 90, 90, 90}},  // All servos centered - safe position
    {"Pick", {90, 100, 80, 90, 100, 0}}, // Ready to pick up object
    {"Place", {90, 80, 100, 90, 80, 180}}, // Ready to place object
    {"Rest", {90, 45, 135, 90, 45, 90}}    // Folded/safe position
};
constexpr uint8_t NPOSE = sizeof(poses) / sizeof(poses[0]);

/* -------- Bluetooth -------- */
BluetoothSerial BT;
constexpr char BT_NAME[] = "ESP32_Robot";

/* -------- FIXED ZK-5AD Motor Driver Control -------- */

void setMotorSpeed(uint8_t pwmPin, uint8_t dirPin, uint8_t pwmChannel,
                   int speed) {
  // Clamp speed to -100 to 100
  speed = constrain(speed, -100, 100);

  // Apply global speed multiplier
  int adjustedSpeed = (speed * globalSpeedMultiplier) / 100;
  adjustedSpeed = constrain(adjustedSpeed, -100, 100);

  // Minimum speed enforcement
  if (adjustedSpeed != 0 && abs(adjustedSpeed) < MIN_SPEED) {
    adjustedSpeed = (adjustedSpeed > 0) ? MIN_SPEED : -MIN_SPEED;
  }

  // Map 0-100 to 0-255 for PWM
  int pwmValue = map(abs(adjustedSpeed), 0, 100, 0, 255);

  // Direction control
  if (adjustedSpeed > 0) {
    digitalWrite(dirPin, HIGH); // Forward
  } else if (adjustedSpeed < 0) {
    digitalWrite(dirPin, LOW); // Reverse
  }

  // Write PWM to control speed
  ledcWrite(pwmChannel, pwmValue);

  // Optional debug
  if (motorDiagnostics && speed != 0) {
    Serial.printf("Motor PWM: %d%% (%d/255)\n", adjustedSpeed, pwmValue);
  }
}

/* -------- Individual Motor Control Functions -------- */
void motorFrontLeft(int speed) {
  setMotorSpeed(FL_PWM_PIN, FL_DIR_PIN, 0, speed);
  if (motorDiagnostics && speed != 0) {
    Serial.printf("🔄 FL: %d%%\n", speed);
  }
}

void motorRearLeft(int speed) {
  setMotorSpeed(RL_PWM_PIN, RL_DIR_PIN, 1, speed);
  if (motorDiagnostics && speed != 0) {
    Serial.printf("🔄 RL: %d%%\n", speed);
  }
}

void motorFrontRight(int speed) {
  setMotorSpeed(FR_PWM_PIN, FR_DIR_PIN, 2, speed);
  if (motorDiagnostics && speed != 0) {
    Serial.printf("🔄 FR: %d%%\n", speed);
  }
}

void motorRearRight(int speed) {
  setMotorSpeed(RR_PWM_PIN, RR_DIR_PIN, 3, speed);
  if (motorDiagnostics && speed != 0) {
    Serial.printf("🔄 RR: %d%%\n", speed);
  }
}

/* -------- Motor Test Functions -------- */
void testMotor(const char *name, void (*motorFunc)(int), Stream &port) {
  port.printf("🔧 Testing %s motor...\n", name);

  // Test forward at reduced speed for safety
  motorFunc(30);
  delay(800);
  motorFunc(0);
  delay(300);

  // Test backward
  motorFunc(-30);
  delay(800);
  motorFunc(0);
  delay(300);

  port.printf("✅ %s test complete\n", name);
}

void testAllMotors(Stream &port) {
  port.println("🔧 Starting motor test sequence...");
  port.printf("Current global speed: %d%%\n", globalSpeedMultiplier);

  testMotor("Front Left", motorFrontLeft, port);
  testMotor("Rear Left", motorRearLeft, port);
  testMotor("Front Right", motorFrontRight, port);
  testMotor("Rear Right", motorRearRight, port);

  port.println("✅ Motor test sequence complete");
}

/* -------- Combined Motor Control Functions -------- */
void motorLeft(int speed) {
  motorFrontLeft(speed);
  motorRearLeft(speed);
  lastMotorCommand = millis();
}

void motorRight(int speed) {
  motorFrontRight(speed);
  motorRearRight(speed);
  lastMotorCommand = millis();
}

void allMotors(int speed) {
  motorFrontLeft(speed);
  motorRearLeft(speed);
  motorFrontRight(speed);
  motorRearRight(speed);
  lastMotorCommand = millis();
}

void stopWheels() {
  allMotors(0);
  if (motorDiagnostics) {
    Serial.println("⏹ All motors stopped");
  }
}

/* -------- Enhanced Movement Functions -------- */
void moveForward(int speed) {
  allMotors(speed);
  if (motorDiagnostics) {
    Serial.printf("⬆ Moving forward at %d%% (global: %d%%)\n", speed,
                  globalSpeedMultiplier);
  }
}

void moveBackward(int speed) {
  allMotors(-speed);
  if (motorDiagnostics) {
    Serial.printf("⬇ Moving backward at %d%% (global: %d%%)\n", speed,
                  globalSpeedMultiplier);
  }
}

void turnLeft(int speed) {
  motorLeft(-speed); // Left motors backward
  motorRight(speed); // Right motors forward
  if (motorDiagnostics) {
    Serial.printf("⬅ Turning left at %d%% (global: %d%%)\n", speed,
                  globalSpeedMultiplier);
  }
}

void turnRight(int speed) {
  motorLeft(speed);   // Left motors forward
  motorRight(-speed); // Right motors backward
  if (motorDiagnostics) {
    Serial.printf("➡ Turning right at %d%% (global: %d%%)\n", speed,
                  globalSpeedMultiplier);
  }
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
  if (servoId >= 6)
    return;

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
  int step = (diff > 0) ? min((int)SERVO_STEP_SIZE, diff)
                        : max(-(int)SERVO_STEP_SIZE, diff);
  int newPos = currentPos + step;

  servos[servoId].write(newPos);
  currentServoPos[servoId] = newPos;

  if (motorDiagnostics) {
    Serial.printf("🤖 Servo %d: %d° -> %d° (target: %d°)\n", servoId,
                  currentPos, newPos, targetAngle);
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

void toPose(const Pose &p, uint16_t totalTime = 2000) {
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
      Serial.printf("✅ Pose '%s' reached in %lums\n", p.name,
                    millis() - startTime);
      break;
    }

    delay(20); // Don't spam servo updates
  }

  delay(SERVO_SETTLE_TIME); // Let servos settle
}

void setServoPosition(uint8_t servoId, uint8_t angle) {
  if (servoId >= 6)
    return;

  angle = constrain(angle, 0, 180);
  targetServoPos[servoId] = angle;

  if (motorDiagnostics) {
    Serial.printf("🎯 Servo %d target set to %d°\n", servoId, angle);
  }
}

void home() {
  Serial.println("🏠 Moving to home position...");
  toPose(poses[0], 1500); // 1.5 seconds to home
  stopWheels();
}

/* -------- Enhanced Command Parser -------- */
constexpr uint8_t BUFSZ = 128;
char buf[BUFSZ];
uint8_t idx = 0;

void execCmd(char *cmd, Stream &port) {
  if (cmd[0] == 'S') { // S:id,angle
    int id, ang;
    if (sscanf(cmd + 2, "%d,%d", &id, &ang) == 2 && id >= 0 && id < 6 &&
        ang >= 0 && ang <= 180) {

      setServoPosition(id, ang); // Use smooth movement function
      port.printf("OK S %d %d\n", id, ang);

      if (motorDiagnostics) {
        Serial.printf("🤖 Servo %d target: %d°\n", id, ang);
      }
    } else {
      port.println("ERR S: Invalid servo ID (0-5) or angle (0-180)");
    }
  }

  else if (cmd[0] == 'P') { // P:name
    char *name = cmd + 2;
    for (auto &p : poses)
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

  else if (cmd[0] == 'M') { // M:L|R,±speed
    char lr;
    int val;
    if (sscanf(cmd + 2, "%c,%d", &lr, &val) == 2) {
      val = constrain(val, -100, 100); // Clamp input
      if (lr == 'L' || lr == 'l') {
        motorLeft(val);
        port.printf("OK M L %d\n", val);
      } else if (lr == 'R' || lr == 'r') {
        motorRight(val);
        port.printf("OK M R %d\n", val);
      } else {
        port.printf("ERR M: Invalid side '%c' (use L or R)\n", lr);
      }
    } else
      port.println("ERR M: Format should be M:L,speed or M:R,speed");
  }

  else if (cmd[0] == 'W') { // W:direction,speed
    char dir;
    int speed;
    if (sscanf(cmd + 2, "%c,%d", &dir, &speed) == 2) {
      speed = constrain(speed, -100, 100); // Clamp input
      switch (dir) {
      case 'F':
      case 'f':
        moveForward(speed);
        break;
      case 'B':
      case 'b':
        moveBackward(speed);
        break;
      case 'L':
      case 'l':
        turnLeft(speed);
        break;
      case 'R':
      case 'r':
        turnRight(speed);
        break;
      default:
        port.printf("ERR W: Invalid direction '%c'\n", dir);
        return;
      }
      port.printf("OK W %c %d\n", dir, speed);
    } else
      port.println("ERR W: Format should be W:direction,speed");
  }

  else if (cmd[0] == 'I') { // I:FL,RL,FR,RR
    int fl, rl, fr, rr;
    if (sscanf(cmd + 2, "%d,%d,%d,%d", &fl, &rl, &fr, &rr) == 4) {
      // Clamp all inputs
      fl = constrain(fl, -100, 100);
      rl = constrain(rl, -100, 100);
      fr = constrain(fr, -100, 100);
      rr = constrain(rr, -100, 100);

      motorFrontLeft(fl);
      motorRearLeft(rl);
      motorFrontRight(fr);
      motorRearRight(rr);
      port.printf("OK I %d %d %d %d\n", fl, rl, fr, rr);
    } else
      port.println("ERR I: Format should be I:FL,RL,FR,RR");
  }

  else if (cmd[0] == 'G') { // G:speed - Global speed multiplier
    int speed;
    if (sscanf(cmd + 2, "%d", &speed) == 1 && speed >= 20 && speed <= 100) {
      int oldSpeed = globalSpeedMultiplier;
      globalSpeedMultiplier = speed;
      port.printf("OK G %d\n", speed);
      if (motorDiagnostics) {
        Serial.printf("🚀 Global speed changed: %d%% -> %d%%\n", oldSpeed,
                      speed);
      }
    } else
      port.println("ERR G: Speed must be 20-100");
  }

  else if (cmd[0] == 'X') { // X - Motor test
    testAllMotors(port);
    port.println("OK X");
  }

  else if (cmd[0] == 'D') { // D:0|1 - Diagnostics on/off
    int diag;
    if (sscanf(cmd + 2, "%d", &diag) == 1 && (diag == 0 || diag == 1)) {
      motorDiagnostics = (diag == 1);
      port.printf("OK D %d\n", diag);
      Serial.printf("🔍 Diagnostics %s\n",
                    motorDiagnostics ? "ENABLED" : "DISABLED");
    } else
      port.println("ERR D: Use D:0 (off) or D:1 (on)");
  }

  else if (cmd[0] == 'V') { // V - Get status
    port.printf(
        "STATUS: Speed=%d%%, Diag=%s, Uptime=%lums, FreeHeap=%d, Servos=",
        globalSpeedMultiplier, motorDiagnostics ? "ON" : "OFF", millis(),
        ESP.getFreeHeap());

    // Print current servo positions
    for (int i = 0; i < 6; i++) {
      port.printf("%d", currentServoPos[i]);
      if (i < 5)
        port.print(",");
    }
    port.println();
  }

  else if (cmd[0] == 'H') {
    home();
    port.println("OK H - Homed");
    if (motorDiagnostics)
      Serial.println("🏠 Robot homed");
  }

  else if (cmd[0] == 'E') {
    stopWheels();
    // Emergency stop - immediately stop all servos at current position
    for (int i = 0; i < 6; i++) {
      targetServoPos[i] = currentServoPos[i];
    }
    port.println("OK E - Emergency stop");
    if (motorDiagnostics)
      Serial.println("🚨 EMERGENCY STOP - All motion halted");
  }

  else if (cmd[0] == 'T') { // T:L,R - Tank drive
    int left, right;
    if (sscanf(cmd + 2, "%d,%d", &left, &right) == 2) {
      // Clamp inputs
      left = constrain(left, -100, 100);
      right = constrain(right, -100, 100);

      motorLeft(left);
      motorRight(right);
      port.printf("OK T %d %d\n", left, right);

      if (motorDiagnostics) {
        Serial.printf("🎮 Tank drive: L=%d%%, R=%d%% (global=%d%%)\n", left,
                      right, globalSpeedMultiplier);
      }
    } else
      port.println("ERR T: Format should be T:left,right");
  }

  else {
    port.printf("ERR ?: Unknown command '%c'\n", cmd[0]);
  }
}

void feed(Stream &port) {
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
  delay(1000); // Allow serial to initialize

  Serial.println("\n🤖 ESP32 Enhanced 4WD Robot Controller Starting...");
  Serial.printf("Version: MG996R Fixed v2.1\n");
  Serial.printf("Build: %s %s\n", __DATE__, __TIME__);
  Serial.println("===============================================");

  // Configure motor pins as digital outputs for direction control
  Serial.println("🔧 Configuring motor control pins...");

  pinMode(FL_DIR_PIN, OUTPUT);
  pinMode(RL_DIR_PIN, OUTPUT);
  pinMode(FR_DIR_PIN, OUTPUT);
  pinMode(RR_DIR_PIN, OUTPUT);

  // Setup PWM channels for motor speed control
  // Using ledcAttach for newer ESP32 Arduino Core (3.x)
  if (!ledcAttach(FL_PWM_PIN, PWM_FREQUENCY, PWM_RESOLUTION)) {
    Serial.println("⚠️ Failed to attach FL PWM channel");
  }
  if (!ledcAttach(RL_PWM_PIN, PWM_FREQUENCY, PWM_RESOLUTION)) {
    Serial.println("⚠️ Failed to attach RL PWM channel");
  }
  if (!ledcAttach(FR_PWM_PIN, PWM_FREQUENCY, PWM_RESOLUTION)) {
    Serial.println("⚠️ Failed to attach FR PWM channel");
  }
  if (!ledcAttach(RR_PWM_PIN, PWM_FREQUENCY, PWM_RESOLUTION)) {
    Serial.println("⚠️ Failed to attach RR PWM channel");
  }

  // Initialize all motors to stopped state
  stopWheels();
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
  Serial.printf("   Min speed threshold: %d%%\n", MIN_SPEED);
  Serial.printf("   Motor timeout: %dms\n", MOTOR_TIMEOUT);
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

  // Safety timeout - stop motors if no command received
  if (millis() - lastMotorCommand > MOTOR_TIMEOUT && lastMotorCommand != 0) {
    stopWheels();
    lastMotorCommand = 0;
    if (motorDiagnostics) {
      Serial.printf("⚠ Motor timeout (%dms) - stopping for safety\n",
                    MOTOR_TIMEOUT);
    }
  }

  // Small delay to prevent system overload
  delay(5);
}