import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/bluetoth_service.dart';
import 'dart:convert';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:http/http.dart' as http;

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
  // Bluetooth
  BluetoothConnection? connection;
  bool isConnecting = false;
  bool isConnected = false;
  List<BluetoothDevice> bondedDevices = [];
  BluetoothDevice? selectedDevice;

  // Robot control
  List<double> servoAngles = [90, 90, 90, 90, 90, 90];
  List<String> servoNames = [
    'Base (Waist)', // ID 0 - Pin 12
    'Shoulder', // ID 1 - Pin 13
    'Elbow', // ID 2 - Pin 18
    'Wrist Pitch', // ID 3 - Pin 19
    'Wrist Roll', // ID 4 - Pin 21
    'Gripper', // ID 5 - Pin 22
  ];
  List<String> poses = ['Home', 'Pick', 'Place', 'Rest'];
  int leftMotorSpeed = 0;
  int rightMotorSpeed = 0;

  // Enhanced controls
  int globalSpeedMultiplier = 80; // Global speed control (20-100%)
  bool motorDiagnostics = true;

  // Video feed properties
  final String _raspberryPiIP = '192.168.1.8'; // Change this to your Pi's IP
  String get streamUrl => 'http://$_raspberryPiIP:8080/my_mac_camera';
  bool _isLoadingStream = false;
  String _errorMessage = '';
  bool _isStreamActive = false;
  Key _mjpegKey = UniqueKey();

  // Control mode selection
  ControlMode _currentControlMode = ControlMode.driving;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
    _initializeVideoFeed();
    // Force landscape orientation for better layout
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _connectionMonitor?.cancel();
    _servoTimer?.cancel();
    connection?.close();
    // Restore all orientations when leaving the screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
    setState(() {
      _isLoadingStream = true;
      _errorMessage = '';
    });

    try {
      bool serverRunning = await _testVideoConnectivity();

      if (serverRunning) {
        setState(() {
          _isLoadingStream = false;
          _isStreamActive = true;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _isLoadingStream = false;
          _isStreamActive = false;
          _errorMessage = 'Camera server not available';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingStream = false;
        _isStreamActive = false;
        _errorMessage = 'Failed to initialize video feed: $e';
      });
    }
  }

  Future<bool> _testVideoConnectivity() async {
    try {
      final client = http.Client();
      try {
        final response = await client
            .get(Uri.parse(streamUrl))
            .timeout(const Duration(seconds: 5));
        return response.statusCode == 200;
      } finally {
        client.close();
      }
    } catch (e) {
      return false;
    }
  }

  void _refreshVideoStream() {
    setState(() {
      _mjpegKey = UniqueKey();
      _errorMessage = '';
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

      // Set initial configuration
      await Future.delayed(Duration(milliseconds: 500));
      _sendCommand('G:$globalSpeedMultiplier');
      await Future.delayed(Duration(milliseconds: 100));
      _sendCommand('D:${motorDiagnostics ? 1 : 0}');

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

  Timer? _servoTimer;

  void _updateServoAngle(int servoId, double angle) {
    setState(() {
      servoAngles[servoId] = angle;
    });

    // Debounce servo commands to reduce spam
    _servoTimer?.cancel();
    _servoTimer = Timer(Duration(milliseconds: 100), () {
      _sendCommand('S:$servoId,${angle.round()}');
    });
  }

  void _setPose(String pose) {
    _sendCommand('P:$pose');
  }

  void _updateGlobalSpeed(int speed) {
    setState(() {
      globalSpeedMultiplier = speed;
    });
    _sendCommand('G:$speed');
  }

  void _toggleDiagnostics() {
    setState(() {
      motorDiagnostics = !motorDiagnostics;
    });
    _sendCommand('D:${motorDiagnostics ? 1 : 0}');
  }

  void _testMotors() {
    _sendCommand('X');
    _showSnackBar('Running motor test sequence...');
  }

  void _getStatus() {
    _sendCommand('V');
  }

  void _updateMotorSpeeds(int left, int right) {
    setState(() {
      leftMotorSpeed = left;
      rightMotorSpeed = right;
    });
    _sendCommand('T:$left,$right');
  }

  void _homeRobot() {
    _sendCommand('H');
    setState(() {
      servoAngles = [90, 90, 90, 90, 90, 90];
      leftMotorSpeed = 0;
      rightMotorSpeed = 0;
    });
  }

  void _emergencyStop() {
    _sendCommand('E');
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
          ? _buildBluetoothSection()
          : Row(
              children: [
                // Left side - Video Feed
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        // Video header
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.grey.shade900,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 20,
                              ),
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
                                  color: _isStreamActive
                                      ? Colors.green
                                      : Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _isStreamActive ? 'LIVE' : 'OFFLINE',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Video content
                        Expanded(child: _buildVideoWidget()),
                      ],
                    ),
                  ),
                ),

                // Right side - Controls
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      // Connection status bar
                      _buildConnectionStatus(),

                      // Control mode selector
                      _buildControlModeSelector(),

                      // Scrollable controls
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              _buildQuickActions(),
                              const SizedBox(height: 12),
                              if (_currentControlMode ==
                                  ControlMode.driving) ...[
                                _buildSpeedControl(),
                                const SizedBox(height: 12),
                                _buildJoystickControl(),
                              ] else ...[
                                _buildPoseControl(),
                                const SizedBox(height: 12),
                                _buildServoControl(),
                              ],
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

  Widget _buildVideoWidget() {
    if (_isLoadingStream) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Icon(Icons.videocam, size: 48, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'Connecting to Camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'Camera Offline',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshVideoStream,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_isStreamActive) {
      return Mjpeg(
        key: _mjpegKey,
        isLive: true,
        stream: streamUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        loading: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
        error: (context, error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                'Stream Error: $error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 48, color: Colors.white54),
          SizedBox(height: 16),
          Text(
            'No Video Feed',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothSection() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Bluetooth Connection Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (bondedDevices.isEmpty)
              const Text('No paired devices found')
            else
              ...bondedDevices
                  .take(3)
                  .map(
                    // Limit to 3 devices for compact view
                    (device) => Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.bluetooth, size: 20),
                        title: Text(
                          device.name.isNotEmpty
                              ? device.name
                              : 'Unknown Device',
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          device.address,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing:
                            isConnecting &&
                                selectedDevice?.address == device.address
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _connectToDevice(device),
                      ),
                    ),
                  ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _initializeBluetooth,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showConnectionTips,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Help'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade100,
                    foregroundColor: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlModeSelector() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _switchControlMode(ControlMode.driving),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: _currentControlMode == ControlMode.driving
                      ? LinearGradient(
                          colors: [Colors.blue.shade600, Colors.blue.shade500],
                        )
                      : null,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car,
                      color: _currentControlMode == ControlMode.driving
                          ? Colors.white
                          : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Driving',
                      style: TextStyle(
                        color: _currentControlMode == ControlMode.driving
                            ? Colors.white
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _switchControlMode(ControlMode.armControl),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: _currentControlMode == ControlMode.armControl
                      ? LinearGradient(
                          colors: [
                            Colors.green.shade600,
                            Colors.green.shade500,
                          ],
                        )
                      : null,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.precision_manufacturing,
                      color: _currentControlMode == ControlMode.armControl
                          ? Colors.white
                          : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Arm Control',
                      style: TextStyle(
                        color: _currentControlMode == ControlMode.armControl
                            ? Colors.white
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bluetooth_connected,
            color: Colors.green.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedDevice?.name ?? 'Robot',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  selectedDevice?.address ?? 'Unknown',
                  style: TextStyle(color: Colors.green.shade600, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'ONLINE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚡ Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _homeRobot,
                    icon: const Icon(Icons.home),
                    label: const Text('Home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _emergencyStop,
                    icon: const Icon(Icons.emergency),
                    label: const Text('E-Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testMotors,
                    icon: const Icon(Icons.build),
                    label: const Text('Test Motors'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleDiagnostics,
                    icon: Icon(
                      motorDiagnostics
                          ? Icons.bug_report
                          : Icons.bug_report_outlined,
                    ),
                    label: Text(motorDiagnostics ? 'Diag: ON' : 'Diag: OFF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: motorDiagnostics
                          ? Colors.green
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedControl() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Global Speed Control',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.remove, color: Colors.grey),
                Expanded(
                  child: Slider(
                    value: globalSpeedMultiplier.toDouble(),
                    min: 20,
                    max: 100,
                    divisions: 16,
                    label: '$globalSpeedMultiplier%',
                    onChanged: (value) => _updateGlobalSpeed(value.round()),
                  ),
                ),
                const Icon(Icons.add, color: Colors.grey),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '20%\nSlow',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$globalSpeedMultiplier%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                Text(
                  '100%\nFast',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoystickControl() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.control_camera, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Movement Control',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Motor Speed Indicators
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.blue.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.chevron_left, color: Colors.blue.shade700),
                        const SizedBox(height: 4),
                        Text(
                          'Left Motor',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$leftMotorSpeed%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: leftMotorSpeed > 0
                                ? Colors.green.shade600
                                : leftMotorSpeed < 0
                                ? Colors.red.shade600
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade50, Colors.green.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.chevron_right, color: Colors.green.shade700),
                        const SizedBox(height: 4),
                        Text(
                          'Right Motor',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$rightMotorSpeed%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: rightMotorSpeed > 0
                                ? Colors.green.shade600
                                : rightMotorSpeed < 0
                                ? Colors.red.shade600
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Directional Control Pad
            Center(
              child: Column(
                children: [
                  // Forward button
                  _buildDirectionalButton(
                    icon: Icons.keyboard_arrow_up,
                    onPressed: () => _updateMotorSpeeds(60, 60),
                    onReleased: () => _updateMotorSpeeds(0, 0),
                    color: Colors.green,
                    size: 60,
                  ),

                  const SizedBox(height: 8),

                  // Middle row with left, stop, right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDirectionalButton(
                        icon: Icons.keyboard_arrow_left,
                        onPressed: () => _updateMotorSpeeds(-60, 60),
                        onReleased: () => _updateMotorSpeeds(0, 0),
                        color: Colors.blue,
                        size: 60,
                      ),

                      const SizedBox(width: 16),

                      _buildDirectionalButton(
                        icon: Icons.stop,
                        onPressed: () => _updateMotorSpeeds(0, 0),
                        onReleased: () {},
                        color: Colors.red,
                        size: 60,
                      ),

                      const SizedBox(width: 16),

                      _buildDirectionalButton(
                        icon: Icons.keyboard_arrow_right,
                        onPressed: () => _updateMotorSpeeds(60, -60),
                        onReleased: () => _updateMotorSpeeds(0, 0),
                        color: Colors.purple,
                        size: 60,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Backward button
                  _buildDirectionalButton(
                    icon: Icons.keyboard_arrow_down,
                    onPressed: () => _updateMotorSpeeds(-60, -60),
                    onReleased: () => _updateMotorSpeeds(0, 0),
                    color: Colors.orange,
                    size: 60,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Speed Preset Buttons
            const Text(
              'Speed Presets',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSpeedPresetButton(
                    label: 'Slow',
                    speed: 30,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSpeedPresetButton(
                    label: 'Medium',
                    speed: 60,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSpeedPresetButton(
                    label: 'Fast',
                    speed: 90,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionalButton({
    required IconData icon,
    required VoidCallback onPressed,
    required VoidCallback onReleased,
    required Color color,
    required double size,
  }) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: onReleased,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.4),
      ),
    );
  }

  Widget _buildSpeedPresetButton({
    required String label,
    required int speed,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: () {
        // This will be used for future directional movements with the selected speed
        _showSnackBar('Speed preset set to $speed% - Use directional buttons');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            '$speed%',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPoseControl() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.accessibility_new, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Predefined Poses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: poses.map((pose) {
                IconData icon;
                Color color;
                switch (pose) {
                  case 'Home':
                    icon = Icons.home;
                    color = Colors.blue;
                    break;
                  case 'Pick':
                    icon = Icons.pan_tool;
                    color = Colors.green;
                    break;
                  case 'Place':
                    icon = Icons.place;
                    color = Colors.orange;
                    break;
                  case 'Rest':
                    icon = Icons.hotel;
                    color = Colors.purple;
                    break;
                  default:
                    icon = Icons.settings;
                    color = Colors.grey;
                }

                return ElevatedButton.icon(
                  onPressed: () => _setPose(pose),
                  icon: Icon(icon),
                  label: Text(pose),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withOpacity(0.1),
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServoControl() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.precision_manufacturing, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text(
                  'Servo Control',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(
              6,
              (index) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          servoNames[index],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${servoAngles[index].round()}°',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('0°', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: servoAngles[index],
                            min: 0,
                            max: 180,
                            divisions: 36,
                            onChanged: (value) =>
                                _updateServoAngle(index, value),
                          ),
                        ),
                        const Text('180°', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
