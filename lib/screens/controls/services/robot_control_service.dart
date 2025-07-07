import 'dart:convert';

class RobotControlService {
  static const List<String> defaultServoNames = [
    'Base (Waist)', // ID 0 - Pin 12
    'Shoulder', // ID 1 - Pin 13
    'Elbow', // ID 2 - Pin 18
    'Wrist Pitch', // ID 3 - Pin 19
    'Wrist Roll', // ID 4 - Pin 21
    'Gripper', // ID 5 - Pin 22
  ];

  static const List<String> defaultPoses = ['Home', 'Pick', 'Place', 'Rest'];

  /// Send servo angle command
  static String servoCommand(int servoId, int angle) {
    return 'S:$servoId,$angle';
  }

  /// Send pose command
  static String poseCommand(String pose) {
    return 'P:$pose';
  }

  /// Send global speed command
  static String globalSpeedCommand(int speed) {
    return 'G:$speed';
  }

  /// Send diagnostics toggle command
  static String diagnosticsCommand(bool enabled) {
    return 'D:${enabled ? 1 : 0}';
  }

  /// Send motor test command
  static String motorTestCommand() {
    return 'X';
  }

  /// Send status request command
  static String statusCommand() {
    return 'V';
  }

  /// Send tank drive command
  static String tankDriveCommand(int leftSpeed, int rightSpeed) {
    return 'T:$leftSpeed,$rightSpeed';
  }

  /// Send home command
  static String homeCommand() {
    return 'H';
  }

  /// Send emergency stop command
  static String emergencyStopCommand() {
    return 'E';
  }

  /// Send ping command for connection monitoring
  static String pingCommand() {
    return 'PING';
  }

  /// Convert command to bytes for transmission
  static List<int> commandToBytes(String command) {
    return utf8.encode('$command\n');
  }

  /// Validate servo angle (0-180 degrees)
  static bool isValidServoAngle(double angle) {
    return angle >= 0 && angle <= 180;
  }

  /// Validate motor speed (-100 to 100 percent)
  static bool isValidMotorSpeed(int speed) {
    return speed >= -100 && speed <= 100;
  }

  /// Validate global speed multiplier (20-100 percent)
  static bool isValidGlobalSpeed(int speed) {
    return speed >= 20 && speed <= 100;
  }

  /// Clamp servo angle to valid range
  static double clampServoAngle(double angle) {
    return angle.clamp(0.0, 180.0);
  }

  /// Clamp motor speed to valid range
  static int clampMotorSpeed(int speed) {
    return speed.clamp(-100, 100);
  }

  /// Clamp global speed to valid range
  static int clampGlobalSpeed(int speed) {
    return speed.clamp(20, 100);
  }
}
