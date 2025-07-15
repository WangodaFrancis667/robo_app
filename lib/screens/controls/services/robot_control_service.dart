// services/orientation_service.dart
import 'package:flutter/services.dart';

// services/robot_control_service.dart
class RobotControlService {
  // Default servo names for the 6-servo arm
  static const List<String> defaultServoNames = [
    'Base',
    'Shoulder',
    'Elbow',
    'Wrist R',
    'Wrist T',
    'Gripper',
  ];

  // Default poses for the robot arm
  static const List<String> defaultPoses = [
    'Home',
    'Pickup',
    'Place',
    'Rest',
    'Extended',
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
    return 'SERVO${servoId + 1}:$angle';
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
    return 'SS';
  }

  // Additional sensor commands (shortened format)
  static String sensorsEnableCommand() => 'SEN';
  static String sensorsDisableCommand() => 'SDS';
  static String collisionDistanceCommand(int distance) => 'CD:$distance';

  // Test commands (shortened format)
  static String motorTestCommand() => 'TM';
  static String servoTestCommand() => 'TS';
  static String sensorTestCommand() => 'TSS';
  static String calibrateCommand() => 'CAL';
  static String calibrateSensorsCommand() => 'CS';

  // Legacy compatibility method (deprecated)
  @Deprecated('Use debugCommand instead')
  static String diagnosticsCommand(bool enabled) {
    return debugCommand(enabled);
  }

  // Command validation
  static bool isValidSpeed(int speed) {
    return speed >= -100 && speed <= 100;
  }

  static bool isValidAngle(int angle) {
    return angle >= 0 && angle <= 180;
  }

  static bool isValidServoId(int servoId) {
    return servoId >= 0 && servoId < 6;
  }

  // Parse response commands
  static Map<String, dynamic>? parseStatusResponse(String response) {
    try {
      if (response.startsWith('STATUS_')) {
        final parts = response.split(':');
        if (parts.length >= 2) {
          return {
            'type': parts[0],
            'data': parts.sublist(1).join(':'),
            'timestamp': DateTime.now().toIso8601String(),
          };
        }
      }
    } catch (e) {
      print('Error parsing status response: $e');
    }
    return null;
  }

  static Map<String, dynamic>? parseSensorResponse(String response) {
    try {
      if (response.startsWith('SENSOR_STATUS:')) {
        final jsonStr = response.substring('SENSOR_STATUS:'.length);
        // This would need a JSON parser in a real implementation
        return {
          'type': 'sensor_status',
          'raw': jsonStr,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      print('Error parsing sensor response: $e');
    }
    return null;
  }
}

class OrientationService {
  static Future<void> switchToLandscapeMode() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  static Future<void> switchToPortraitMode() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  static Future<void> restoreAllOrientations() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}
