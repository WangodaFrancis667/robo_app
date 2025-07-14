import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'services/bluetoth_service.dart';

// Import all components
import 'components/bluetooth_section.dart';
import 'components/video_feed_section.dart' as video;
import 'components/control_mode_selector.dart';
import 'components/quick_actions_section.dart';
import 'components/speed_control_section.dart';
import 'components/joystick_control_section.dart';
import 'components/pose_control_section.dart';
import 'components/servo_control_section.dart';

// Import all services
import 'services/video_service.dart';
import 'services/robot_control_service.dart';
import 'services/orientation_service.dart' as orientation;

// Control mode selection
enum ControlMode { driving, armControl }

class RobotControllerApp extends StatelessWidget {
  final Function(bool)? onConnectionStatusChanged;

  const RobotControllerApp({super.key, this.onConnectionStatusChanged});

  @override
  Widget build(BuildContext context) {
    return RobotControllerScreen(
      onConnectionStatusChanged: onConnectionStatusChanged,
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
  // Services
  late VideoService _videoService;

  // Video initialization state
  bool _isVideoInitialized = false;
  bool _isVideoInitializing = false;

  // Flag to pause network operations during critical Bluetooth operations
  bool _pauseNetworkOperations = false;

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
    orientation.OrientationService.switchToPortraitMode();
    _initializeBluetooth();
    // Don't initialize video feed until Bluetooth is connected
    // _initializeVideoFeed();
  }

  @override
  void dispose() {
    _connectionMonitor?.cancel();
    _servoTimer?.cancel();
    connection?.close();
    // Restore all orientations when leaving the screen
    orientation.OrientationService.restoreAllOrientations();
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
    // Don't initialize if we're already initializing, already initialized,
    // or if network operations are paused during critical Bluetooth operations
    if (_isVideoInitialized ||
        _isVideoInitializing ||
        _pauseNetworkOperations) {
      print(
        'Video initialization skipped: ${_isVideoInitialized
            ? 'Already initialized'
            : _isVideoInitializing
            ? 'Already initializing'
            : 'Network operations paused'}',
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isVideoInitializing = true;
      });
    }

    try {
      print(
        '🎥 Starting video initialization (Bluetooth connected: $isConnected)',
      );

      // Use a simpler initialization approach when Bluetooth is active
      // This avoids the more aggressive network scanning that might interfere with Bluetooth
      if (isConnected) {
        // When Bluetooth is connected, we prioritize a quick, direct connection attempt
        await _videoService.initializeVideoFeed();
      } else {
        // Only use direct connection when not in discovery mode
        await _videoService.initializeVideoFeed();
      }

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoInitializing = false;
        });
        print('✅ Video initialization successful');
      }
    } catch (e) {
      print('❌ Video initialization error: $e');
      if (mounted) {
        setState(() {
          _isVideoInitializing = false;
        });
      }
      // Don't set _isVideoInitialized = true on error

      // If video fails after Bluetooth is connected, retry once with a delay
      // but only if Bluetooth is still connected and we're not in a paused state
      if (isConnected && mounted && !_pauseNetworkOperations) {
        print('📅 Scheduling video retry in 3 seconds');
        Future.delayed(const Duration(seconds: 3), () {
          if (!_isVideoInitialized &&
              !_isVideoInitializing &&
              mounted &&
              isConnected &&
              !_pauseNetworkOperations) {
            print('🔄 Retrying video initialization');
            _refreshVideoStream();
          }
        });
      }
    }
  }

  Future<void> _refreshVideoStream() async {
    // Don't attempt refresh if network operations are paused
    if (_pauseNetworkOperations) {
      print('⚠️ Video refresh skipped: Network operations paused');
      return;
    }

    print('🔄 Refreshing video stream');

    // Show user feedback
    if (mounted) {
      _showSnackBar('Refreshing video connection...');
    }

    if (mounted) {
      setState(() {
        _isVideoInitialized = false;
        _isVideoInitializing = true; // Mark as initializing first
      });
    }

    try {
      // First refresh the stream key
      _videoService.refreshVideoStream();

      // Short delay to allow stream to reset
      await Future.delayed(const Duration(milliseconds: 500));

      // Then initialize the feed
      await _initializeVideoFeed();

      // Provide feedback on success
      if (mounted) {
        _showSnackBar('Video connection refreshed');
      }
    } catch (e) {
      print('❌ Error refreshing video stream: $e');

      if (mounted) {
        setState(() {
          _isVideoInitializing = false;
        });
        _showSnackBar('Failed to refresh video: $e');
      }
    }
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

    BluetoothConnection? tempConnection;
    bool connectionSuccess = false;
    int maxAttempts = 3;
    int currentAttempt = 0;

    while (!connectionSuccess && currentAttempt < maxAttempts) {
      try {
        currentAttempt++;
        _showSnackBar(
          'Connecting to ${device.name}... (Attempt $currentAttempt of $maxAttempts)',
        );

        // Clear any existing connection
        if (connection != null) {
          await connection!.close().catchError(
            (e) => print('Error closing existing connection: $e'),
          );
          connection = null;
        }

        // Ensure all network operations are paused during Bluetooth connection
        // This helps prevent interference
        _pauseNetworkOperations = true;

        // Connect to the device with extended timeout for HC modules
        tempConnection = await CrossPlatformBluetoothService.connectToDevice(
          device,
        ).timeout(const Duration(seconds: 40));

        setState(() {
          isConnected = true;
          isConnecting = false;
          connection = tempConnection;
        });

        // Allow network operations to resume
        _pauseNetworkOperations = false;

        // Notify parent about connection status change
        if (widget.onConnectionStatusChanged != null) {
          widget.onConnectionStatusChanged!(true);
        }

        _showSnackBar('Connected to ${device.name}');

        // Switch to landscape mode for robot control
        orientation.OrientationService.switchToLandscapeMode();

        // Set initial configuration with proper delays for HC modules
        await Future.delayed(
          const Duration(milliseconds: 1500),
        ); // Longer delay for HC modules
        _sendCommand(
          RobotControlService.globalSpeedCommand(globalSpeedMultiplier),
        );
        await Future.delayed(
          const Duration(milliseconds: 800),
        ); // Increased delay
        _sendCommand(RobotControlService.debugCommand(motorDiagnostics));

        // Start monitoring connection
        _startConnectionMonitoring();

        // Initialize video feed AFTER Bluetooth connection is fully established
        // But do it with a delay to ensure Bluetooth has stabilized
        _showSnackBar('Bluetooth connection established successfully');

        // Use Future.delayed to ensure Bluetooth operations are fully complete before starting camera
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && isConnected) {
            _showSnackBar('Now initializing camera connection...');
            _initializeVideoFeed()
                .then((_) {
                  if (mounted && isConnected) {
                    _showSnackBar('Camera connection initialized');
                  }
                })
                .catchError((error) {
                  if (mounted && isConnected) {
                    _showSnackBar('Camera initialization error: $error');
                    // Try once more after a longer delay
                    Future.delayed(const Duration(seconds: 5), () {
                      if (mounted && isConnected && !_isVideoInitialized) {
                        _showSnackBar('Retrying camera connection...');
                        _refreshVideoStream();
                      }
                    });
                  }
                });
          }
        });

        // Connection was successful
        connectionSuccess = true;
      } catch (e) {
        print('Failed to connect on attempt $currentAttempt: $e');

        // Close any partial connection
        if (tempConnection != null) {
          try {
            await tempConnection.close();
          } catch (closeError) {
            print('Error closing failed connection: $closeError');
          }
          tempConnection = null;
        }

        // Only show failure message if we've exhausted all attempts
        if (currentAttempt >= maxAttempts) {
          setState(() {
            isConnecting = false;
          });

          _showSnackBar('Failed to connect: $e');

          // Show detailed error for complex error messages
          if (e.toString().length > 100) {
            Future.delayed(Duration(milliseconds: 500), () {
              _showDetailedErrorDialog('Connection Failed', e.toString());
            });
          }

          // Reset Bluetooth and try to re-initialize if needed
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !isConnected) {
              _initializeBluetooth();
            }
          });
        } else {
          // Wait before retry
          await Future.delayed(const Duration(seconds: 2));
          _showSnackBar('Retrying connection...');
        }
      }
    }

    // Allow network operations regardless of connection outcome
    _pauseNetworkOperations = false;
  }

  Timer? _connectionMonitor;
  int _failedPingCount = 0;
  static const int _maxPingFailures = 3;

  void _startConnectionMonitoring() {
    _failedPingCount = 0;
    _connectionMonitor?.cancel();
    // Reduced frequency for HC modules - they are more sensitive
    _connectionMonitor = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (connection != null && isConnected) {
        // Send a ping command to check if connection is still alive
        try {
          // Check if we should pause ping during network operations
          if (!_pauseNetworkOperations) {
            _sendCommand('STATUS'); // Use STATUS instead of PING for HC modules
            // Reset failed count on successful ping
            if (_failedPingCount > 0) {
              print(
                '✅ Connection restored after $_failedPingCount failed pings',
              );
              _failedPingCount = 0;
            }
          }
        } catch (e) {
          _failedPingCount++;
          print(
            '⚠️ Connection monitoring ping failed ($_failedPingCount/$_maxPingFailures): $e',
          );

          // Only disconnect after multiple consecutive failures
          if (_failedPingCount >= _maxPingFailures) {
            print(
              '❌ Connection lost after $_maxPingFailures consecutive failed pings',
            );
            _handleConnectionLost();
            timer.cancel();
          }
        }
      } else {
        print('❌ Connection monitor stopping - connection no longer valid');
        timer.cancel();
      }
    });
  }

  void _handleConnectionLost() {
    if (mounted) {
      // Avoid network operations during reconnection attempts
      _pauseNetworkOperations = true;

      setState(() {
        isConnected = false;

        // Try to properly close the connection
        if (connection != null) {
          try {
            connection!.close().catchError(
              (e) => print('Error closing connection: $e'),
            );
          } catch (_) {}
          connection = null;
        }

        // Reset video state when connection is lost
        _isVideoInitialized = false;
        _isVideoInitializing = false;
      });

      // Notify parent about connection status change
      if (widget.onConnectionStatusChanged != null) {
        widget.onConnectionStatusChanged!(false);
      }

      _showSnackBar('Connection lost to robot');

      // Switch back to portrait mode when connection is lost
      orientation.OrientationService.switchToPortraitMode();

      // Store the device to potentially reconnect
      final lostDevice = selectedDevice;

      // If we have a device to reconnect to, try to reconnect after a delay
      if (lostDevice != null) {
        print('📱 Planning reconnection attempt to ${lostDevice.name}');

        // Delay before trying to reconnect
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted &&
              !isConnected &&
              !isConnecting &&
              selectedDevice == null) {
            print('🔄 Attempting to reconnect to ${lostDevice.name}');
            _showSnackBar('Attempting to reconnect to ${lostDevice.name}...');
            _connectToDevice(lostDevice);
          } else {
            print(
              '⚠️ Reconnection cancelled - state changed or already connecting',
            );
          }
        });
      }

      // Allow network operations to resume after a delay
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) {
          _pauseNetworkOperations = false;
        }
      });
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
        // Reset video state when disconnecting
        _isVideoInitialized = false;
        _isVideoInitializing = false;
      });

      // Notify parent about connection status change
      if (widget.onConnectionStatusChanged != null) {
        widget.onConnectionStatusChanged!(false);
      }

      _showSnackBar('Disconnected');
      // Switch back to portrait mode when manually disconnecting
      orientation.OrientationService.switchToPortraitMode();
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
    _sendCommand(RobotControlService.debugCommand(motorDiagnostics));
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
          title: const Text('HC Module Connection Tips'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'If you\'re having trouble connecting to your HC module:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text('1. Check HC module power (LED should blink)'),
                SizedBox(height: 8),
                Text('2. Pair device in Android Bluetooth settings first'),
                SizedBox(height: 8),
                Text('3. Ensure Arduino code is uploaded and running'),
                SizedBox(height: 8),
                Text('4. Verify HC module wiring (TX/RX not swapped)'),
                SizedBox(height: 8),
                Text('5. Check baud rate is 9600 in Arduino code'),
                SizedBox(height: 8),
                Text('6. Try power cycling the HC module'),
                SizedBox(height: 12),
                Text(
                  'HC Module Setup:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• VCC to 5V (or 3.3V for some modules)'),
                SizedBox(height: 4),
                Text('• GND to Arduino GND'),
                SizedBox(height: 4),
                Text('• HC TX to Arduino Pin 2 (RX)'),
                SizedBox(height: 4),
                Text('• HC RX to Arduino Pin 3 (TX)'),
                SizedBox(height: 12),
                Text(
                  'Troubleshooting:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• LED blinking = searching for connection'),
                SizedBox(height: 4),
                Text('• LED solid = paired but not connected'),
                SizedBox(height: 4),
                Text('• No LED = power or wiring issue'),
                SizedBox(height: 4),
                Text('• Default PIN: 1234 or 0000'),
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
        content: Text(
          'Connected to camera server at ${server.ip}:${server.port}',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildVideoFeedWidget() {
    if (!_isVideoInitialized && !_isVideoInitializing) {
      // Show waiting state before video initialization
      return Container(
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
            // Waiting content
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.hourglass_empty,
                        size: 48,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Waiting for Bluetooth Connection',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Camera will initialize after robot connection',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
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

    // Return the actual video feed section
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
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (isConnected) ...[
            // Show device address as a chip in the actions
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Text(
                selectedDevice?.address ?? 'Unknown',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _getStatus,
              tooltip: 'Get Status',
            ),
          ],
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
              onCameraServerDiscovered: _onCameraServerDiscovered,
            )
          : Row(
              children: [
                // Left side - Video Feed
                Expanded(flex: 1, child: _buildVideoFeedWidget()),

                // Right side - Controls
                Expanded(
                  flex: 1,
                  child: Container(
                    constraints: const BoxConstraints.expand(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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

  // Enhanced error handling with detailed dialog
  void _showDetailedErrorDialog(String title, String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Error Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(errorMessage, style: TextStyle(fontSize: 12)),
                SizedBox(height: 16),
                Text(
                  'Troubleshooting Tips:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '• Ensure device is paired in Android Bluetooth settings\n'
                  '• Check if HC module LED is blinking (searching)\n'
                  '• Verify Arduino code is uploaded and running\n'
                  '• Try moving closer to the device\n'
                  '• Power cycle the HC module\n'
                  '• Grant all Bluetooth permissions',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initializeBluetooth();
              },
              child: Text('Refresh Devices'),
            ),
          ],
        );
      },
    );
  }
}
