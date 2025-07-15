import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

// Import your existing components (keeping the ones that work)
import './components/video_feed_section.dart' as video;
import './components/control_mode_selector.dart';
import './components/quick_actions_section.dart';
import './components/speed_control_section.dart';
import './components/joystick_control_section.dart';
import './components/pose_control_section.dart';
import './components/servo_control_section.dart';

// Import your existing services
import './services/video_service.dart';
import './services/robot_control_service.dart';
import './services/orientation_service.dart' as orientation;

// Import the sensor dashboard
import '../sensors/sensor_dashboard_screen.dart';

// Control mode selection
enum ControlMode { driving, armControl }

class RobotControllerApp extends StatelessWidget {
  final Function(bool)? onConnectionStatusChanged;

  const RobotControllerApp({super.key, this.onConnectionStatusChanged});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Control Screen',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: RobotControllerScreen(
        onConnectionStatusChanged: onConnectionStatusChanged,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RobotControllerScreen extends StatefulWidget {
  final Function(bool)? onConnectionStatusChanged;

  const RobotControllerScreen({super.key, this.onConnectionStatusChanged});

  @override
  State<RobotControllerScreen> createState() => _RobotControllerScreenState();
}

class _RobotControllerScreenState extends State<RobotControllerScreen> {
  // Simplified Bluetooth variables
  BluetoothConnection? connection;
  bool isConnected = false;
  bool isConnecting = false;
  bool isBluetoothEnabled = false;
  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;
  String statusMessage = 'Checking Bluetooth...';

  // Services
  late VideoService _videoService;

  // Video initialization state
  bool _isVideoInitialized = false;
  bool _isVideoInitializing = false;

  // Robot control
  List<double> servoAngles = [90, 90, 90, 90, 90, 90];
  List<String> servoNames = RobotControlService.defaultServoNames;
  List<String> poses = RobotControlService.defaultPoses;
  int leftMotorSpeed = 0;
  int rightMotorSpeed = 0;

  // Enhanced controls
  int globalSpeedMultiplier = 80;
  bool motorDiagnostics = true;

  // Control mode selection
  ControlMode _currentControlMode = ControlMode.driving;

  // Timers
  Timer? _servoTimer;
  Timer? _connectionMonitor;

  @override
  void initState() {
    super.initState();
    _videoService = VideoService();
    orientation.OrientationService.switchToPortraitMode();
    _initializeBluetooth();
  }

  @override
  void dispose() {
    _connectionMonitor?.cancel();
    _servoTimer?.cancel();
    if (isConnected) {
      connection?.dispose();
    }
    orientation.OrientationService.restoreAllOrientations();
    super.dispose();
  }

  // Simplified Bluetooth initialization
  void _initializeBluetooth() async {
    try {
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      setState(() {
        isBluetoothEnabled = isEnabled ?? false;
        statusMessage = isBluetoothEnabled
            ? 'Bluetooth enabled'
            : 'Bluetooth disabled';
      });

      if (isBluetoothEnabled) {
        _getBondedDevices();
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error checking Bluetooth: $e';
      });
    }
  }

  // Enable Bluetooth
  void _enableBluetooth() async {
    try {
      await FlutterBluetoothSerial.instance.requestEnable();
      _initializeBluetooth();
    } catch (e) {
      setState(() {
        statusMessage = 'Failed to enable Bluetooth: $e';
      });
    }
  }

  // Get paired devices
  void _getBondedDevices() async {
    try {
      setState(() {
        statusMessage = 'Loading paired devices...';
      });

      List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial
          .instance
          .getBondedDevices();

      setState(() {
        devices = bondedDevices;
        statusMessage = devices.isEmpty
            ? 'No paired devices found'
            : 'Found ${devices.length} paired devices';
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Error getting paired devices: $e';
      });
    }
  }

  // Simplified connection method
  void _connectToDevice(BluetoothDevice device) async {
    setState(() {
      isConnecting = true;
      selectedDevice = device;
      statusMessage = 'Connecting to ${device.name}...';
    });

    try {
      connection = await BluetoothConnection.toAddress(device.address);
      setState(() {
        isConnected = true;
        isConnecting = false;
        statusMessage = 'Connected to ${device.name}';
      });

      if (widget.onConnectionStatusChanged != null) {
        widget.onConnectionStatusChanged!(true);
      }

      _showSnackBar('Connected to ${device.name}', Colors.green);

      // Switch to landscape for robot control
      orientation.OrientationService.switchToLandscapeMode();

      // Send initial commands
      await Future.delayed(const Duration(milliseconds: 500));
      _sendCommand(
        RobotControlService.globalSpeedCommand(globalSpeedMultiplier),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      _sendCommand(RobotControlService.debugCommand(motorDiagnostics));

      // Start connection monitoring
      _startConnectionMonitoring();

      // Initialize video feed
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && isConnected) {
          _initializeVideoFeed();
        }
      });
    } catch (e) {
      setState(() {
        isConnecting = false;
        statusMessage = 'Failed to connect: $e';
      });
      _showSnackBar('Failed to connect: $e', Colors.red);
    }
  }

  // Simplified disconnect
  void _disconnect() async {
    try {
      _connectionMonitor?.cancel();
      await connection?.close();
      setState(() {
        isConnected = false;
        connection = null;
        selectedDevice = null;
        _isVideoInitialized = false;
        _isVideoInitializing = false;
        statusMessage = 'Disconnected';
      });

      if (widget.onConnectionStatusChanged != null) {
        widget.onConnectionStatusChanged!(false);
      }

      _showSnackBar('Disconnected', Colors.orange);
      orientation.OrientationService.switchToPortraitMode();
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }

  // Simplified connection monitoring
  void _startConnectionMonitoring() {
    _connectionMonitor?.cancel();
    _connectionMonitor = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (connection != null && isConnected) {
        try {
          _sendCommand('STATUS');
        } catch (e) {
          print('Connection lost: $e');
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
        _isVideoInitialized = false;
        _isVideoInitializing = false;
        statusMessage = 'Connection lost';
      });

      if (widget.onConnectionStatusChanged != null) {
        widget.onConnectionStatusChanged!(false);
      }

      _showSnackBar('Connection lost to robot', Colors.red);
      orientation.OrientationService.switchToPortraitMode();
    }
  }

  // Simplified command sending
  void _sendCommand(String command) {
    if (connection != null && isConnected) {
      try {
        if (command != 'STATUS') {
          print('Sending: $command');
        }
        connection!.output.add(Uint8List.fromList(utf8.encode('$command\n')));
      } catch (e) {
        print('Error sending command "$command": $e');
        _handleConnectionLost();
      }
    }
  }

  void _showSnackBar(String message, [Color? backgroundColor]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // NEW: Open sensor dashboard method
  void _openSensorDashboard() {
    if (isConnected && connection != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RobotSensorDashboard(
            bluetoothConnection: connection,
            isConnected: isConnected,
            deviceName: selectedDevice?.name,
          ),
        ),
      ).then((_) {
        // This runs when user returns from dashboard
        // No need to reconnect - connection remains active
        print('Returned from sensor dashboard - connection maintained');

        // Optionally refresh the video stream when returning
        if (mounted && isConnected) {
          _refreshVideoStream();
        }
      });
    } else {
      _showSnackBar(
        'Connect to robot first to view sensor data',
        Colors.orange,
      );
    }
  }

  void _showConnectionHelp() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Connection Help'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Having trouble connecting? Here\'s how to fix common issues:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                _buildHelpItem(
                  icon: Icons.bluetooth,
                  title: 'HC-05 Module Setup',
                  description:
                      'Ensure your HC-05 module is properly powered and the LED is blinking (pairing mode)',
                ),

                _buildHelpItem(
                  icon: Icons.settings_bluetooth,
                  title: 'Pairing Process',
                  description:
                      'Go to Android Settings > Bluetooth and pair with HC-05 first (PIN: 1234 or 0000)',
                ),

                _buildHelpItem(
                  icon: Icons.electrical_services,
                  title: 'Wiring Check',
                  description:
                      'Verify HC-05 connections:\n• VCC → 5V\n• GND → GND\n• TX → Pin 2\n• RX → Pin 3',
                ),

                _buildHelpItem(
                  icon: Icons.code,
                  title: 'Arduino Code',
                  description:
                      'Make sure your Arduino code is uploaded and Serial communication is set to 9600 baud',
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tip: The HC-05 LED should be solid (not blinking) when successfully connected',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: Colors.blue[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Video feed methods (simplified)
  Future<void> _initializeVideoFeed() async {
    if (_isVideoInitialized || _isVideoInitializing) return;

    setState(() {
      _isVideoInitializing = true;
    });

    try {
      await _videoService.initializeVideoFeed();
      setState(() {
        _isVideoInitialized = true;
        _isVideoInitializing = false;
      });
      print('✅ Video initialization successful');
    } catch (e) {
      print('❌ Video initialization error: $e');
      setState(() {
        _isVideoInitializing = false;
      });
    }
  }

  Future<void> _refreshVideoStream() async {
    setState(() {
      _isVideoInitialized = false;
      _isVideoInitializing = true;
    });

    try {
      _videoService.refreshVideoStream();
      await Future.delayed(const Duration(milliseconds: 500));
      await _initializeVideoFeed();
      _showSnackBar('Video connection refreshed', Colors.blue);
    } catch (e) {
      setState(() {
        _isVideoInitializing = false;
      });
      _showSnackBar('Failed to refresh video: $e', Colors.red);
    }
  }

  // Control methods
  void _switchControlMode(ControlMode mode) {
    setState(() {
      _currentControlMode = mode;
    });
  }

  void _updateServoAngle(int servoId, double angle) {
    setState(() {
      servoAngles[servoId] = angle;
    });

    _servoTimer?.cancel();
    _servoTimer = Timer(const Duration(milliseconds: 100), () {
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
    _sendCommand(RobotControlService.debugCommand(motorDiagnostics));
  }

  void _testMotors() {
    _sendCommand(RobotControlService.motorTestCommand());
    _showSnackBar('Running motor test sequence...', Colors.blue);
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

  void _onCameraServerDiscovered(CameraServer server) {
    print('🎯 Camera server discovered: ${server.url}');
    setState(() {
      _videoService = _videoService.createFromDiscoveredServer(server);
    });
    _initializeVideoFeed();
    _showSnackBar(
      'Connected to camera server at ${server.ip}:${server.port}',
      Colors.green,
    );
  }

  // Professional connection section
  Widget _buildConnectionSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue[50]!, Colors.white],
        ),
      ),
      child: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.bluetooth,
                  size: 64,
                  color: isBluetoothEnabled ? Colors.blue[600] : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'Robot Connection',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect to your HC-05 Bluetooth module to control the robot',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Status section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isBluetoothEnabled ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBluetoothEnabled
                    ? Colors.green[200]!
                    : Colors.orange[200]!,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isBluetoothEnabled ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isBluetoothEnabled
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBluetoothEnabled
                            ? 'Bluetooth Ready'
                            : 'Bluetooth Disabled',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isBluetoothEnabled
                              ? Colors.green[800]
                              : Colors.orange[800],
                        ),
                      ),
                      Text(
                        statusMessage,
                        style: TextStyle(
                          fontSize: 12,
                          color: isBluetoothEnabled
                              ? Colors.green[600]
                              : Colors.orange[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (!isBluetoothEnabled) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _enableBluetooth,
                      icon: const Icon(Icons.bluetooth),
                      label: const Text('Enable Bluetooth'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _getBondedDevices,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Devices'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _showConnectionHelp,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Help'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Device list
          if (isBluetoothEnabled) _buildDeviceList(),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (devices.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.devices_other, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Paired Devices Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please pair your HC-05 module in Android Bluetooth settings first',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Available Devices (${devices.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final isRecommended =
                    device.name?.toLowerCase().contains('hc-05') == true ||
                    device.name?.toLowerCase().contains('robot') == true ||
                    device.name?.toLowerCase().contains('arduino') == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isRecommended
                          ? BorderSide(color: Colors.green[300]!, width: 2)
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Device icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isRecommended
                                  ? Colors.green[100]
                                  : Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isRecommended ? Icons.smart_toy : Icons.devices,
                              color: isRecommended
                                  ? Colors.green[700]
                                  : Colors.blue[700],
                              size: 24,
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Device info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        device.name ?? 'Unknown Device',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isRecommended) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          'RECOMMENDED',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  device.address,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (device.isConnected) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.link,
                                        size: 12,
                                        color: Colors.blue[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Currently connected',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Connect button
                          SizedBox(
                            width: 90,
                            child: ElevatedButton(
                              onPressed: isConnecting
                                  ? null
                                  : () => _connectToDevice(device),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRecommended
                                    ? Colors.green[600]
                                    : Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: isConnecting && selectedDevice == device
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Connect',
                                      style: TextStyle(fontSize: 12),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoFeedWidget() {
    if (!_isVideoInitialized && !_isVideoInitializing) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade900,
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Live Camera Feed',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'WAITING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      size: 48,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Waiting for Bluetooth Connection',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Camera will initialize after robot connection',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return video.VideoFeedSection(
      streamUrl: _videoService.streamUrl,
      isLoadingStream: _videoService.isLoadingStream || _isVideoInitializing,
      errorMessage: _videoService.errorMessage,
      isStreamActive: _videoService.isStreamActive,
      mjpegKey: _videoService.mjpegKey,
      onRefreshVideoStream: _refreshVideoStream,
      onCameraServerDiscovered: _onCameraServerDiscovered,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isConnected
            ? Row(
                children: [
                  const Text('🤖 Robot Controller'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bluetooth_connected,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          selectedDevice?.name ?? 'Robot',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : const Text('🤖 Robot Controller'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isConnected) ...[
            // Sensor Dashboard Button
            // IconButton(
            //   icon: const Icon(Icons.dashboard),
            //   onPressed: _openSensorDashboard,
            //   tooltip: 'Sensor Dashboard',
            // ),
            // IconButton(
            //   icon: const Icon(Icons.settings),
            //   onPressed: _getStatus,
            //   tooltip: 'Get Status',
            // ),
          ],
          IconButton(
            icon: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
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
          ? SingleChildScrollView(child: _buildConnectionSection())
          : Row(
              children: [
                Expanded(flex: 1, child: _buildVideoFeedWidget()),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      ControlModeSelectorSection(
                        currentControlMode: _currentControlMode,
                        onControlModeChanged: _switchControlMode,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(8),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
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
                                  globalSpeedMultiplier: globalSpeedMultiplier,
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
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
