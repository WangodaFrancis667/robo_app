import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'services/bluetoth_service.dart';

// Import all components
import 'components/bluetooth_section.dart';
import 'components/video_feed_section.dart';
import 'components/connection_status_section.dart';
import 'components/control_mode_selector.dart';
import 'components/quick_actions_section.dart';
import 'components/speed_control_section.dart';
import 'components/joystick_control_section.dart';
import 'components/pose_control_section.dart';
import 'components/servo_control_section.dart';

// Import all services
import 'services/video_service.dart';
import 'services/robot_control_service.dart';
import 'services/orientation_service.dart';

// Control mode selection
enum ControlMode { driving, armControl }

class RobotControllerApp extends StatelessWidget {
  const RobotControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const RobotControllerScreen(),
    );
  }
}

class RobotControllerScreen extends StatefulWidget {
  const RobotControllerScreen({super.key});

  @override
  State<RobotControllerScreen> createState() => _RobotControllerScreenState();
}

class _RobotControllerScreenState extends State<RobotControllerScreen> {
  // Services
  late VideoService _videoService;

  // Bluetooth
  BluetoothConnection? connection;
  bool isConnecting = false;
  bool isConnected = false;
  List<BluetoothDevice> bondedDevices = [];
  BluetoothDevice? selectedDevice;

  // Robot control
  List<double> servoAngles = [90, 90, 90, 90, 90, 90];
  List<String> servoNames = RobotControlService.defaultServoNames;
  List<String> poses = RobotControlService.defaultPoses;
  int leftMotorSpeed = 0;
  int rightMotorSpeed = 0;

  // Enhanced controls
  int globalSpeedMultiplier = 80; // Global speed control (20-100%)
  bool motorDiagnostics = true;

  // Control mode selection
  ControlMode _currentControlMode = ControlMode.driving;

  // Timers
  Timer? _servoTimer;

  @override
  void initState() {
    super.initState();
    // Initialize services
    _videoService = VideoService();

    // Start in portrait mode for Bluetooth connection
    OrientationService.switchToPortraitMode();
    _initializeBluetooth();
    _initializeVideoFeed();
  }

  @override
  void dispose() {
    _connectionMonitor?.cancel();
    _servoTimer?.cancel();
    connection?.close();
    // Restore all orientations when leaving the screen
    OrientationService.restoreAllOrientations();
    super.dispose();
  }

  Future<void> _initializeBluetooth() async {
    try {
      // Request permissions using cross-platform service
      bool permissionsGranted =
          await CrossPlatformBluetoothService.requestPermissions();

      if (!permissionsGranted) {
        _showSnackBar('Bluetooth permissions are required for this app');
        return;
      }

      bool isEnabled = await CrossPlatformBluetoothService.isBluetoothEnabled();
      if (!isEnabled) {
        try {
          await CrossPlatformBluetoothService.enableBluetooth();
        } catch (e) {
          _showSnackBar('Please enable Bluetooth: $e');
          return;
        }
      }

      List<BluetoothDevice> devices =
          await CrossPlatformBluetoothService.getDevices();
      setState(() {
        bondedDevices = devices;
      });
    } catch (e) {
      _showSnackBar('Error initializing Bluetooth: $e');
    }
  }

  // Video feed methods
  Future<void> _initializeVideoFeed() async {
    // Try auto-discovery first, then fallback to configured server
    await _videoService.initializeVideoFeedWithDiscovery();
    setState(() {
      // Video state is now managed by the service
    });
  }

  void _refreshVideoStream() {
    _videoService.refreshVideoStream();
    setState(() {
      // Video state is now managed by the service
    });
    _initializeVideoFeed();
  }

  void _switchControlMode(ControlMode mode) {
    setState(() {
      _currentControlMode = mode;
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      isConnecting = true;
      selectedDevice = device;
    });

    try {
      _showSnackBar('Connecting to ${device.name}...');

      connection = await CrossPlatformBluetoothService.connectToDevice(device);

      setState(() {
        isConnected = true;
        isConnecting = false;
      });

      _showSnackBar('Connected to ${device.name}');

      // Switch to landscape mode for robot control
      OrientationService.switchToLandscapeMode();

      // Set initial configuration
      await Future.delayed(Duration(milliseconds: 500));
      _sendCommand(
        RobotControlService.globalSpeedCommand(globalSpeedMultiplier),
      );
      await Future.delayed(Duration(milliseconds: 100));
      _sendCommand(RobotControlService.diagnosticsCommand(motorDiagnostics));

      // Start monitoring connection
      _startConnectionMonitoring();
    } catch (e) {
      setState(() {
        isConnecting = false;
        isConnected = false;
        connection = null;
        selectedDevice = null;
      });
      _showSnackBar('Connection failed: ${e.toString()}');
      print('Connection error: $e');
      // Ensure we stay in portrait mode if connection fails
      OrientationService.switchToPortraitMode();
    }
  }

  Timer? _connectionMonitor;

  void _startConnectionMonitoring() {
    _connectionMonitor?.cancel();
    _connectionMonitor = Timer.periodic(Duration(seconds: 5), (timer) {
      if (connection != null && isConnected) {
        // Send a ping command to check if connection is still alive
        try {
          _sendCommand('PING');
        } catch (e) {
          print('Connection monitoring failed: $e');
          _handleConnectionLost();
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _handleConnectionLost() {
    if (mounted) {
      setState(() {
        isConnected = false;
        connection = null;
        selectedDevice = null;
      });
      _showSnackBar('Connection lost to robot');
      // Switch back to portrait mode when connection is lost
      OrientationService.switchToPortraitMode();
    }
  }

  Future<void> _disconnect() async {
    if (connection != null) {
      _connectionMonitor?.cancel();
      await connection!.close();
      setState(() {
        isConnected = false;
        connection = null;
        selectedDevice = null;
      });
      _showSnackBar('Disconnected');
      // Switch back to portrait mode when manually disconnecting
      OrientationService.switchToPortraitMode();
    }
  }

  void _sendCommand(String command) {
    if (connection != null && isConnected) {
      try {
        // Skip ping commands from being logged
        if (command != 'PING') {
          print('Sending: $command');
        }

        connection!.write(utf8.encode('$command\n'));
      } catch (e) {
        print('Error sending command "$command": $e');
        _showSnackBar('Communication error: ${e.toString()}');

        // If we can't send commands, the connection is probably lost
        _handleConnectionLost();
      }
    } else {
      if (command != 'PING') {
        // Don't show error for ping commands
        _showSnackBar('Not connected to robot');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _updateServoAngle(int servoId, double angle) {
    setState(() {
      servoAngles[servoId] = angle;
    });

    // Debounce servo commands to reduce spam
    _servoTimer?.cancel();
    _servoTimer = Timer(Duration(milliseconds: 100), () {
      _sendCommand(RobotControlService.servoCommand(servoId, angle.round()));
    });
  }

  void _setPose(String pose) {
    _sendCommand(RobotControlService.poseCommand(pose));
  }

  void _updateGlobalSpeed(int speed) {
    setState(() {
      globalSpeedMultiplier = speed;
    });
    _sendCommand(RobotControlService.globalSpeedCommand(speed));
  }

  void _toggleDiagnostics() {
    setState(() {
      motorDiagnostics = !motorDiagnostics;
    });
    _sendCommand(RobotControlService.diagnosticsCommand(motorDiagnostics));
  }

  void _testMotors() {
    _sendCommand(RobotControlService.motorTestCommand());
    _showSnackBar('Running motor test sequence...');
  }

  void _getStatus() {
    _sendCommand(RobotControlService.statusCommand());
  }

  void _updateMotorSpeeds(int left, int right) {
    setState(() {
      leftMotorSpeed = left;
      rightMotorSpeed = right;
    });
    _sendCommand(RobotControlService.tankDriveCommand(left, right));
  }

  void _homeRobot() {
    _sendCommand(RobotControlService.homeCommand());
    setState(() {
      servoAngles = [90, 90, 90, 90, 90, 90];
      leftMotorSpeed = 0;
      rightMotorSpeed = 0;
    });
  }

  void _emergencyStop() {
    _sendCommand(RobotControlService.emergencyStopCommand());
    setState(() {
      leftMotorSpeed = 0;
      rightMotorSpeed = 0;
    });
  }

  void _showConnectionTips() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ESP32 Connection Tips'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'If you\'re having trouble connecting to your ESP32:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text('1. Ensure ESP32 is powered on and running'),
                SizedBox(height: 8),
                Text('2. Check that Bluetooth is enabled on ESP32'),
                SizedBox(height: 8),
                Text('3. Verify device is paired in Android settings'),
                SizedBox(height: 8),
                Text('4. Make sure ESP32 code has Serial Port Profile (SPP)'),
                SizedBox(height: 8),
                Text('5. Try restarting both devices'),
                SizedBox(height: 8),
                Text('6. Check ESP32 Serial Monitor for connection status'),
                SizedBox(height: 12),
                Text(
                  'ESP32 Code Requirements:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Include BluetoothSerial library'),
                SizedBox(height: 4),
                Text('• Set device name (e.g., "ESP32_Robot")'),
                SizedBox(height: 4),
                Text('• Enable pairing and discoverable mode'),
                SizedBox(height: 4),
                Text('• Handle incoming serial commands'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _onCameraServerDiscovered(CameraServer server) {
    print('🎯 Camera server discovered: ${server.url}');

    setState(() {
      _videoService = _videoService.createFromDiscoveredServer(server);
    });

    _initializeVideoFeed();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connected to camera server at ${server.ip}:${server.port}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 Robot Controller'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _getStatus,
              tooltip: 'Get Status',
            ),
          IconButton(
            icon: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: isConnected ? Colors.green : null,
            ),
            onPressed: isConnected ? _disconnect : null,
            tooltip: isConnected ? 'Disconnect' : 'Bluetooth',
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _refreshVideoStream,
            tooltip: 'Refresh Video',
          ),
        ],
      ),
      body: !isConnected
          ? BluetoothConnectionSection(
              bondedDevices: bondedDevices,
              isConnecting: isConnecting,
              selectedDevice: selectedDevice,
              onRefreshDevices: _initializeBluetooth,
              onShowConnectionTips: _showConnectionTips,
              onConnectToDevice: _connectToDevice,
            )
          : Row(
              children: [
                // Left side - Video Feed
                Expanded(
                  flex: 1,
                  child: VideoFeedSection(
                    streamUrl: _videoService.streamUrl,
                    isLoadingStream: _videoService.isLoadingStream,
                    errorMessage: _videoService.errorMessage,
                    isStreamActive: _videoService.isStreamActive,
                    mjpegKey: _videoService.mjpegKey,
                    onRefreshVideoStream: _refreshVideoStream,
                    onCameraServerDiscovered: _onCameraServerDiscovered,
                  ),
                ),

                // Right side - Controls
                Expanded(
                  flex: 1,
                  child: Container(
                    constraints: const BoxConstraints.expand(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Connection status bar
                        ConnectionStatusSection(selectedDevice: selectedDevice),

                        // Control mode selector
                        ControlModeSelectorSection(
                          currentControlMode: _currentControlMode,
                          onControlModeChanged: _switchControlMode,
                        ),

                        // Scrollable controls
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(8),
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                QuickActionsSection(
                                  onHomeRobot: _homeRobot,
                                  onEmergencyStop: _emergencyStop,
                                  onTestMotors: _testMotors,
                                  onToggleDiagnostics: _toggleDiagnostics,
                                  motorDiagnostics: motorDiagnostics,
                                ),
                                const SizedBox(height: 12),
                                if (_currentControlMode ==
                                    ControlMode.driving) ...[
                                  SpeedControlSection(
                                    globalSpeedMultiplier:
                                        globalSpeedMultiplier,
                                    onSpeedChanged: _updateGlobalSpeed,
                                  ),
                                  const SizedBox(height: 12),
                                  JoystickControlSection(
                                    leftMotorSpeed: leftMotorSpeed,
                                    rightMotorSpeed: rightMotorSpeed,
                                    onMotorSpeedsChanged: _updateMotorSpeeds,
                                    onShowMessage: _showSnackBar,
                                  ),
                                ] else ...[
                                  PoseControlSection(
                                    poses: poses,
                                    onSetPose: _setPose,
                                  ),
                                  const SizedBox(height: 12),
                                  ServoControlSection(
                                    servoAngles: servoAngles,
                                    servoNames: servoNames,
                                    onServoAngleChanged: _updateServoAngle,
                                  ),
                                ],
                                // Add some bottom padding to ensure scrolling works properly
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
