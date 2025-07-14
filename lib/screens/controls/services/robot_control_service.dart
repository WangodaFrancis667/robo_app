import 'dart:convert';

class RobotControlService {
  static const List<String> defaultServoNames = [
    'Base (Servo 1)', // SERVO1 or SERVO_BASE - Pin 6
    'Shoulder (Servo 2)', // SERVO2 or SERVO_SHOULDER - Pin 7
    'Elbow (Servo 3)', // SERVO3 or SERVO_ELBOW - Pin 8
    'Wrist Rotation (Servo 4)', // SERVO4 or SERVO_WRIST_ROT - Pin 9
    'Wrist Tilt (Servo 5)', // SERVO5 or SERVO_WRIST_TILT - Pin 10
    'Gripper (Servo 6)', // SERVO6 or SERVO_GRIPPER - Pin 11
  ];

  static const List<String> defaultPoses = [
    'Home', // ARM_HOME
    'Preset 1', // ARM_PRESET:1
    'Preset 2', // ARM_PRESET:2
    'Preset 3', // ARM_PRESET:3
    'Preset 4', // ARM_PRESET:4
    'Preset 5', // ARM_PRESET:5
  ];

  // MOTOR COMMANDS - match Arduino controller exactly

  /// Send forward movement command
  static String forwardCommand(int speed) {
    return 'F:$speed';
  }

  /// Send backward movement command
  static String backwardCommand(int speed) {
    return 'B:$speed';
  }

  /// Send left turn command
  static String leftCommand(int speed) {
    return 'L:$speed';
  }

  /// Send right turn command
  static String rightCommand(int speed) {
    return 'R:$speed';
  }

  /// Send tank drive command
  static String tankDriveCommand(int leftSpeed, int rightSpeed) {
    return 'T:$leftSpeed,$rightSpeed';
  }

  /// Send stop command
  static String stopCommand() {
    return 'S';
  }

  // SERVO ARM COMMANDS - match Arduino controller exactly

  /// Send individual servo angle command (SERVO1-SERVO6)
  static String servoCommand(int servoId, int angle) {
    // Convert 0-based index to 1-based servo number
    return 'SE${servoId + 1}:$angle';
  }

  /// Send alternative servo command using named servos
  static String namedServoCommand(int servoId, int angle) {
    const List<String> servoNames = [
      'SERVO_BASE',
      'SERVO_SHOULDER',
      'SERVO_ELBOW',
      'SERVO_WRIST_ROT',
      'SERVO_WRIST_TILT',
      'SERVO_GRIPPER',
    ];
    if (servoId >= 0 && servoId < servoNames.length) {
      return '${servoNames[servoId]}:$angle';
    }
    return servoCommand(servoId, angle);
  }

  /// Send arm home command
  static String homeCommand() {
    return 'H';
  }

  /// Send preset position command
  static String poseCommand(String pose) {
    // Extract preset number from pose name
    if (pose.toLowerCase() == 'home') {
      return 'H';
    } else if (pose.toLowerCase().contains('preset')) {
      // Extract number from "Preset X" format
      final match = RegExp(r'\d+').firstMatch(pose);
      if (match != null) {
        return 'P:${match.group(0)}';
      }
    }
    return 'H'; // Fallback to home
  }

  /// Send gripper open command
  static String gripperOpenCommand() {
    return 'GO';
  }

  /// Send gripper close command
  static String gripperCloseCommand() {
    return 'GC';
  }

  /// Send arm enable command
  static String armEnableCommand() {
    return 'ARM_ENABLE';
  }

  /// Send arm disable command
  static String armDisableCommand() {
    return 'ARM_DISABLE';
  }

  // SYSTEM COMMANDS - match Arduino controller exactly

  /// Send status request command
  static String statusCommand() {
    return 'ST';
  }

  /// Send global speed command (20-100%)
  static String globalSpeedCommand(int speed) {
    return 'SP:$speed';
  }

  /// Send servo speed command (1-5)
  static String servoSpeedCommand(int speed) {
    return 'SERVO_SPEED:$speed';
  }

  /// Send debug mode toggle command
  static String debugCommand(bool enabled) {
    return 'D:${enabled ? 1 : 0}';
  }

  /// Send emergency stop command
  static String emergencyStopCommand() {
    return 'E';
  }

  /// Send ping command for connection monitoring
  static String pingCommand() {
    return 'PN';
  }

  /// Send help command
  static String helpCommand() {
    return 'HELP';
  }

  /// Send reset command
  static String resetCommand() {
    return 'RESET';
  }

  // SENSOR COMMANDS - match Arduino controller exactly

  /// Send sensor status request
  static String sensorStatusCommand() {
    return 'SENSOR_STATUS';
  }

  /// Send detailed sensor status request
  static String sensorDetailedCommand() {
    return 'SENSOR_DETAILED';
  }

  /// Send enable sensors command
  static String sensorsEnableCommand() {
    return 'SENSORS_ENABLE';
  }

  /// Send disable sensors command
  static String sensorsDisableCommand() {
    return 'SENSORS_DISABLE';
  }

  /// Send collision distance setting command
  static String collisionDistanceCommand(int distance) {
    return 'COLLISION_DISTANCE:$distance';
  }

  /// Send collision aggressiveness setting command
  static String collisionAggressivenessCommand(int level) {
    return 'COLLISION_AGGRESSIVENESS:$level';
  }

  // TEST COMMANDS - match Arduino controller exactly

  /// Send motor test command
  static String motorTestCommand() {
    return 'TEST_MOTORS';
  }

  /// Send servo test command
  static String servoTestCommand() {
    return 'TEST_SERVOS';
  }

  /// Send sensor test command
  static String sensorTestCommand() {
    return 'TEST_SENSORS';
  }

  /// Send calibration command
  static String calibrateCommand() {
    return 'CALIBRATE';
  }

  /// Send sensor calibration command
  static String calibrateSensorsCommand() {
    return 'CALIBRATE_SENSORS';
  }

  // DIAGNOSTIC COMMANDS - legacy compatibility (deprecated)

  /// Legacy diagnostics command (now maps to debug)
  @Deprecated('Use debugCommand instead')
  static String diagnosticsCommand(bool enabled) {
    return debugCommand(enabled);
  }

  /// Convert command to bytes for transmission
  static List<int> commandToBytes(String command) {
    return utf8.encode('$command\n');
  }

  /// Validate servo angle (0-180 degrees)
  static bool isValidServoAngle(double angle) {
    return angle >= 0 && angle <= 180;
  }

  /// Validate motor speed (0 to 100 percent for single direction)
  static bool isValidMotorSpeed(int speed) {
    return speed >= 0 && speed <= 100;
  }

  /// Validate tank drive speed (-100 to 100 percent)
  static bool isValidTankSpeed(int speed) {
    return speed >= -100 && speed <= 100;
  }

  /// Validate global speed multiplier (20-100 percent)
  static bool isValidGlobalSpeed(int speed) {
    return speed >= 20 && speed <= 100;
  }

  /// Validate servo speed setting (1-5)
  static bool isValidServoSpeed(int speed) {
    return speed >= 1 && speed <= 5;
  }

  /// Validate collision distance (5-100 cm)
  static bool isValidCollisionDistance(int distance) {
    return distance >= 5 && distance <= 100;
  }

  /// Validate collision aggressiveness level (1-3)
  static bool isValidAggressiveness(int level) {
    return level >= 1 && level <= 3;
  }

  /// Clamp servo angle to valid range
  static double clampServoAngle(double angle) {
    return angle.clamp(0.0, 180.0);
  }

  /// Clamp motor speed to valid range
  static int clampMotorSpeed(int speed) {
    return speed.clamp(0, 100);
  }

  /// Clamp tank drive speed to valid range
  static int clampTankSpeed(int speed) {
    return speed.clamp(-100, 100);
  }

  /// Clamp global speed to valid range
  static int clampGlobalSpeed(int speed) {
    return speed.clamp(20, 100);
  }

  /// Clamp servo speed to valid range
  static int clampServoSpeed(int speed) {
    return speed.clamp(1, 5);
  }

  /// Clamp collision distance to valid range
  static int clampCollisionDistance(int distance) {
    return distance.clamp(5, 100);
  }

  /// Clamp aggressiveness level to valid range
  static int clampAggressiveness(int level) {
    return level.clamp(1, 3);
  }

  /// Get command description for help/debugging
  static String getCommandDescription(String command) {
    if (command.startsWith('FORWARD:'))
      return 'Move forward at specified speed';
    if (command.startsWith('BACKWARD:'))
      return 'Move backward at specified speed';
    if (command.startsWith('LEFT:')) return 'Turn left at specified speed';
    if (command.startsWith('RIGHT:')) return 'Turn right at specified speed';
    if (command.startsWith('TANK:')) return 'Tank drive with left,right speeds';
    if (command == 'STOP') return 'Stop all motors';
    if (command.startsWith('SERVO')) return 'Control servo angle (0-180°)';
    if (command == 'ARM_HOME') return 'Move arm to home position';
    if (command.startsWith('ARM_PRESET:')) return 'Move arm to preset position';
    if (command == 'GRIPPER_OPEN') return 'Open gripper';
    if (command == 'GRIPPER_CLOSE') return 'Close gripper';
    if (command == 'STATUS') return 'Get system status';
    if (command.startsWith('SPEED:')) return 'Set global motor speed (20-100%)';
    if (command.startsWith('SERVO_SPEED:'))
      return 'Set servo movement speed (1-5)';
    if (command == 'EMERGENCY') return 'Emergency stop all systems';
    if (command == 'PING') return 'Connection test';
    return 'Unknown command';
  }
}
