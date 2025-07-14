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
    'Gripper'
  ];

  // Default poses for the robot arm
  static const List<String> defaultPoses = [
    'Home',
    'Pickup',
    'Place', 
    'Rest',
    'Extended'
  ];

  // Motor control commands
  static String forwardCommand(int speed) => 'FORWARD:$speed';
  static String backwardCommand(int speed) => 'BACKWARD:$speed';
  static String leftCommand(int speed) => 'LEFT:$speed';
  static String rightCommand(int speed) => 'RIGHT:$speed';
  static String tankDriveCommand(int leftSpeed, int rightSpeed) => 'TANK:$leftSpeed,$rightSpeed';
  static String stopCommand() => 'STOP';

  // Servo control commands
  static String servoCommand(int servoId, int angle) => 'SERVO${servoId + 1}:$angle';
  static String armHomeCommand() => 'ARM_HOME';
  static String poseCommand(String pose) {
    final poses = defaultPoses;
    final index = poses.indexOf(pose);
    return index >= 0 ? 'ARM_PRESET:${index + 1}' : 'ARM_HOME';
  }
  static String gripperOpenCommand() => 'GRIPPER_OPEN';
  static String gripperCloseCommand() => 'GRIPPER_CLOSE';

  // System commands
  static String globalSpeedCommand(int speed) => 'SPEED:$speed';
  static String diagnosticsCommand(bool enabled) => 'DEBUG:${enabled ? 1 : 0}';
  static String statusCommand() => 'STATUS';
  static String emergencyStopCommand() => 'EMERGENCY';
  static String homeCommand() => 'ARM_HOME';
  static String motorTestCommand() => 'TEST_MOTORS';
  static String servoTestCommand() => 'TEST_SERVOS';
  static String pingCommand() => 'PING';

  // Sensor commands
  static String sensorStatusCommand() => 'SENSOR_STATUS';
  static String sensorsEnableCommand() => 'SENSORS_ENABLE';
  static String sensorsDisableCommand() => 'SENSORS_DISABLE';
  static String collisionDistanceCommand(int distance) => 'COLLISION_DIST:$distance';
  static String testSensorsCommand() => 'TEST_SENSORS';
  static String calibrateSensorsCommand() => 'CALIBRATE_SENSORS';

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