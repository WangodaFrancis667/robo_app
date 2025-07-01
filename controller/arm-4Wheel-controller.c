/* ================================================================
 * 4-Wheel Robot · Two ZK-5AD Motor Drivers · Comprehensive Test
 * AND
 * Robotic Arm Control · Six MG996R Servo Motors
 * ---------------------------------------------------------------
 * Robot Wheel Control:
 * Left driver  (front-left, rear-left)  : D9  D8  D6  D7
 * Right driver (front-right, rear-right): D5  D4  D3  D2
 *
 * Direction logic per ZK-5AD:
 * Forward  -> IN1 = PWM/HIGH, IN2 = LOW
 * Reverse  -> IN1 = LOW         , IN2 = PWM/HIGH
 * Brake    -> IN1 = HIGH        , IN2 = HIGH
 * Stop     -> IN1 = LOW         , IN2 = LOW
 *
 * Robotic Arm Servo Control:
 * Using 6 MG996R servo motors.
 * Pins chosen: D10, D11, A0, A1, A2, A3 (as digital pins)
 *
 * IMPORTANT: MG996R servos draw significant current.
 * YOU MUST USE AN EXTERNAL POWER SUPPLY (e.g., 5V, 5A+)
 * for the servos. Do NOT power them directly from the Arduino Uno.
 * Connect the GND of the external power supply to the Arduino's GND.
 *
 * Author: ChatGPT rewrite for Wangoda Francis · 2025-06-29
 * ================================================================
 */

#include <Arduino.h>
#include <Servo.h> // Include the Servo library for controlling servo motors

/* ------------ Arduino-to-driver wiring (Robot Wheels) ------------ */
//  Left driver (board #1)
const uint8_t L_A_IN1 = 9; // PWM  · D0 on driver (front-left motor)
const uint8_t L_A_IN2 = 8; //      · D1
const uint8_t L_B_IN1 = 6; // PWM  · D2 (rear-left motor)
const uint8_t L_B_IN2 = 7; //      · D3

//  Right driver (board #2)
const uint8_t R_A_IN1 = 5; // PWM  · D0 (front-right motor)
const uint8_t R_A_IN2 = 4; //      · D1
const uint8_t R_B_IN1 = 3; // PWM  · D2 (rear-right motor)
const uint8_t R_B_IN2 = 2; //      · D3

/* ------------ Robotic Arm Servos ------------ */
// Declare 6 Servo objects for the robotic arm joints
Servo baseServo;       // Controls the base rotation of the arm
Servo shoulderServo;   // Controls the shoulder joint (e.g., up/down movement)
Servo elbowServo;      // Controls the elbow joint
Servo wristRollServo;  // Controls the wrist's rotation
Servo wristPitchServo; // Controls the wrist's up/down movement
Servo gripperServo;    // Controls the gripper (open/close)

// Define the pins for your servo motors.
// These pins are chosen to avoid conflict with the motor driver pins (D2-D9).
// D10 and D11 are PWM pins, A0-A3 can be used as digital pins.
const uint8_t BASE_SERVO_PIN = 10;
const uint8_t SHOULDER_SERVO_PIN = 11;
const uint8_t ELBOW_SERVO_PIN = A0;       // Analog pin A0 used as Digital 14
const uint8_t WRIST_ROLL_SERVO_PIN = A1;  // Analog pin A1 used as Digital 15
const uint8_t WRIST_PITCH_SERVO_PIN = A2; // Analog pin A2 used as Digital 16
const uint8_t GRIPPER_SERVO_PIN = A3;     // Analog pin A3 used as Digital 17

/* ------------ high-level definitions ------------ */
enum Direction { FWD, REV, BRAKE, STOP };
const uint8_t DEFAULT_SPEED = 80; // % of full PWM for robot wheels
bool verbose = true;              // serial prints for debugging

/* ------------ prototypes ------------ */
// Robot Wheel Control Prototypes
void driveSide(Direction dir, uint8_t pct, bool leftSide);
void driveMotor(uint8_t in1, uint8_t in2, Direction dir, uint8_t pct);
void brakeSide(bool leftSide);
void debug(const char *tag);

// Robotic Arm Control Prototypes (example functions)
void setArmPosition(int baseAngle, int shoulderAngle, int elbowAngle,
                    int wristRollAngle, int wristPitchAngle, int gripperAngle);
void openGripper();
void closeGripper();

/* ================================================================ */
void setup() {
  Serial.begin(9600);
  Serial.println(F("\n4WD Robot and 6-DOF Robotic Arm Control Sketch"));
  Serial.println(F("Initializing..."));

  // --- Initialize Robot Wheel Motor Driver Pins ---
  uint8_t motor_pins[] = {L_A_IN1, L_A_IN2, L_B_IN1, L_B_IN2,
                          R_A_IN1, R_A_IN2, R_B_IN1, R_B_IN2};
  for (uint8_t p : motor_pins) {
    pinMode(p, OUTPUT);
  }

  // Ensure robot wheels are stopped initially
  driveSide(STOP, 0, true);
  driveSide(STOP, 0, false);
  Serial.println(F("Robot wheel motors initialized and stopped."));

  // --- Initialize Robotic Arm Servo Motors ---
  // Attach each servo object to its respective pin
  baseServo.attach(BASE_SERVO_PIN);
  shoulderServo.attach(SHOULDER_SERVO_PIN);
  elbowServo.attach(ELBOW_SERVO_PIN);
  wristRollServo.attach(WRIST_ROLL_SERVO_PIN);
  wristPitchServo.attach(WRIST_PITCH_SERVO_PIN);
  gripperServo.attach(GRIPPER_SERVO_PIN);

  // Set initial positions for the arm (e.g., all to 90 degrees, gripper
  // half-open) Adjust these initial values based on your arm's physical limits
  // and desired starting pose.
  baseServo.write(90);
  shoulderServo.write(90);
  elbowServo.write(90);
  wristRollServo.write(90);
  wristPitchServo.write(90);
  gripperServo.write(90); // 90 degrees is often a good mid-point for gripper
  delay(1500);            // Give servos time to move to initial position
  Serial.println(F("Robotic arm servos initialized to home position."));
  Serial.println(F("Setup complete. Starting loop."));
}

/* ================================================================ */
void loop() {

  // --- Robot Wheel Control Demonstration ---
  Serial.println(F("\n--- Robot Wheel Movements ---"));

  /* -------- 1. Forward -------- */
  driveSide(FWD, DEFAULT_SPEED, true);  // left
  driveSide(FWD, DEFAULT_SPEED, false); // right
  debug("►► forward");
  delay(3000);
  brakeSide(true);
  brakeSide(false); // full brake
  delay(1000);

  /* -------- 2. Reverse -------- */
  driveSide(REV, 60, true);
  driveSide(REV, 60, false);
  debug("◄◄ reverse");
  delay(3000);
  brakeSide(true);
  brakeSide(false);
  delay(1000);

  /* -------- 3. Turn left (tank style) -------- */
  driveSide(REV, 80, true);  // left wheels reverse
  driveSide(FWD, 80, false); // right wheels forward
  debug("↺ turn left");
  delay(2000);
  brakeSide(true);
  brakeSide(false);
  delay(1000);

  /* -------- 4. Turn right -------- */
  driveSide(FWD, 80, true);  // left wheels forward
  driveSide(REV, 80, false); // right wheels reverse
  debug("↻ turn right");
  delay(2000);
  brakeSide(true);
  brakeSide(false);
  delay(1000);

  /* -------- 5. Ramp test on right side -------- */
  debug("⇉ ramp right");
  for (int pct = 0; pct <= 100; pct += 10) {
    driveSide(FWD, 80, true);   // left constant
    driveSide(FWD, pct, false); // right ramp
    delay(400);
  }
  brakeSide(true);
  brakeSide(false);
  delay(2000);

  // --- Robotic Arm Control Demonstration ---
  Serial.println(F("\n--- Robotic Arm Movements ---"));

  // Example: Move arm to a "pickup" position
  Serial.println(F("Moving arm to pickup position..."));
  setArmPosition(45, 120, 60, 90, 90,
                 90); // Adjust angles as needed for your arm geometry
  delay(3000);

  // Example: Close gripper
  Serial.println(F("Closing gripper..."));
  closeGripper();
  delay(2000);

  // Example: Move arm to a "place" position
  Serial.println(F("Moving arm to place position..."));
  setArmPosition(135, 60, 100, 90, 90,
                 gripperServo.read()); // Keep gripper state
  delay(3000);

  // Example: Open gripper
  Serial.println(F("Opening gripper..."));
  openGripper();
  delay(2000);

  // Example: Return arm to home position
  Serial.println(F("Returning arm to home position..."));
  setArmPosition(90, 90, 90, 90, 90, 90);
  delay(3000);

  // Repeat forever
}

/* ================================================================
 * Robot Wheel Control Functions
 * ================================================================ */

/*
 * driveSide() – send same command to both motors on a side
 * dir: Direction enum (FWD, REV, BRAKE, STOP)
 * pct: Percentage of full speed (0-100)
 * leftSide: true for left side motors, false for right side motors
 */
void driveSide(Direction dir, uint8_t pct, bool leftSide) {
  pct = constrain(pct, 0, 100); // Ensure percentage is within 0-100
  if (leftSide) {
    driveMotor(L_A_IN1, L_A_IN2, dir, pct); // Front-left motor
    driveMotor(L_B_IN1, L_B_IN2, dir, pct); // Rear-left motor
  } else {
    driveMotor(R_A_IN1, R_A_IN2, dir, pct); // Front-right motor
    driveMotor(R_B_IN1, R_B_IN2, dir, pct); // Rear-right motor
  }
}

/*
 * driveMotor() – low-level primitive for one motor on the ZK-5AD driver
 * in1: Digital pin connected to IN1 of the motor driver
 * in2: Digital pin connected to IN2 of the motor driver
 * dir: Direction enum (FWD, REV, BRAKE, STOP)
 * pct: Percentage of full speed (0-100)
 */
void driveMotor(uint8_t in1, uint8_t in2, Direction dir, uint8_t pct) {

  // Map percentage (0-100) to PWM value (0-255)
  uint8_t pwm = map(pct, 0, 100, 0, 255);

  switch (dir) {
  case FWD: // IN1 = PWM, IN2 = LOW for forward motion
    analogWrite(in1, pwm);
    digitalWrite(in2, LOW);
    break;

  case REV: // IN1 = LOW, IN2 = PWM for reverse motion
    digitalWrite(in1, LOW);
    analogWrite(in2, pwm);
    break;

  case BRAKE: // IN1 = HIGH, IN2 = HIGH for braking
    digitalWrite(in1, HIGH);
    digitalWrite(in2, HIGH);
    break;

  case STOP: // IN1 = LOW, IN2 = LOW for stopping (freewheel)
  default:
    digitalWrite(in1, LOW);
    digitalWrite(in2, LOW);
    break;
  }
}

/*
 * brakeSide() – apply brake to both motors on one side
 * leftSide: true for left side motors, false for right side motors
 */
void brakeSide(bool leftSide) {
  if (leftSide) {
    driveMotor(L_A_IN1, L_A_IN2, BRAKE, 0);
    driveMotor(L_B_IN1, L_B_IN2, BRAKE, 0);
  } else {
    driveMotor(R_A_IN1, R_A_IN2, BRAKE, 0);
    driveMotor(R_B_IN1, R_B_IN2, BRAKE, 0);
  }
}

/*
 * debug() – tiny helper for serial status prints
 * tag: String to print to Serial monitor
 */
void debug(const char *tag) {
  if (!verbose)
    return;
  Serial.println(tag);
}

/* ================================================================
 * Robotic Arm Control Functions
 * ================================================================ */

/*
 * setArmPosition() – Moves all arm servos to specified angles
 * All angles are in degrees (0-180). Adjust ranges based on your servo limits.
 */
void setArmPosition(int baseAngle, int shoulderAngle, int elbowAngle,
                    int wristRollAngle, int wristPitchAngle, int gripperAngle) {
  // Use constrain to keep angles within typical servo limits (0-180 degrees)
  // You might need to adjust these limits based on your specific arm's physical
  // constraints.
  baseServo.write(constrain(baseAngle, 0, 180));
  shoulderServo.write(constrain(shoulderAngle, 0, 180));
  elbowServo.write(constrain(elbowAngle, 0, 180));
  wristRollServo.write(constrain(wristRollAngle, 0, 180));
  wristPitchServo.write(constrain(wristPitchAngle, 0, 180));
  gripperServo.write(constrain(gripperAngle, 0, 180));
}

/*
 * openGripper() – Opens the gripper to a predefined angle
 * Adjust the angle (e.g., 0 or 180) based on how your gripper is mounted and
 * operates.
 */
void openGripper() {
  gripperServo.write(180); // Example: 180 degrees for open. Adjust as needed.
  Serial.println(F("Gripper opened."));
}

/*
 * closeGripper() – Closes the gripper to a predefined angle
 * Adjust the angle (e.g., 0 or 180) based on how your gripper is mounted and
 * operates.
 */
void closeGripper() {
  gripperServo.write(0); // Example: 0 degrees for closed. Adjust as needed.
  Serial.println(F("Gripper closed."));
}
/* ================================================================
 * End of robotic arm and 4WD robot control sketch
 * ================================================================ */ 