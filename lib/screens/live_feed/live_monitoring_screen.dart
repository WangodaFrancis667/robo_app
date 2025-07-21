import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// The screen responsible for displaying live camera stream and robot controls.
class LiveMonitoringScreen extends StatefulWidget {
  const LiveMonitoringScreen({super.key});

  @override
  State<LiveMonitoringScreen> createState() => _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends State<LiveMonitoringScreen> {
  // Replace with your Raspberry Pi's IP address
  final String _raspberryPiIP =
      '192.168.137.4'; //'192.168.1.8'; // Change this to your Pi's IP

  // Robot control URL (if your robot control is also on the Pi)
  String get controlUrl => 'http://$_raspberryPiIP:5000/control';

  // Camera stream URL - this matches the Python server endpoint
  String get streamUrl => 'http://$_raspberryPiIP:8080/my_mac_camera';

  // Bluetooth connection variables
  BluetoothConnection? bluetoothConnection;
  bool isBluetoothConnected = false;
  bool _isBluetoothEnabled = false;
  bool _isConnecting = false;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  Timer? _autoConnectTimer;
  StreamSubscription<Uint8List>? _bluetoothSubscription;

  // State variables for robot status and controls
  bool isEmergencyStop = false;
  String robotStatus = 'Active';
  String currentTask = 'Scanning for weeds';

  // State variables for UI feedback
  bool _isLoadingStream = false;
  String _errorMessage = '';
  bool _isStreamActive = false;

  // Key for rebuilding the MJPEG widget
  Key _mjpegKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 Initializing Live Monitoring Screen...');

    // Test connectivity and start streaming
    _testAndStartStreaming();

    // Initialize Bluetooth connection with auto-discovery
    _initializeBluetooth();
  }

  @override
  void dispose() {
    debugPrint(
      '🔌 Disposing Live Monitoring Screen - Cleaning up Bluetooth...',
    );

    // Cancel all timers first to prevent new connection attempts
    _autoConnectTimer?.cancel();
    _autoConnectTimer = null;

    // Cancel Bluetooth subscription
    _bluetoothSubscription?.cancel();
    _bluetoothSubscription = null;

    // Close Bluetooth connection properly
    if (bluetoothConnection != null) {
      try {
        if (isBluetoothConnected) {
          bluetoothConnection!.close();
          debugPrint('✅ Bluetooth connection closed properly');
        }
        bluetoothConnection!.dispose();
        bluetoothConnection = null;
      } catch (e) {
        debugPrint('Error closing Bluetooth connection: $e');
      }
    }

    // Reset connection state
    isBluetoothConnected = false;
    _isConnecting = false;

    super.dispose();
  }

  /// Initialize Bluetooth connection with auto-discovery
  Future<void> _initializeBluetooth() async {
    // Check if widget is still mounted
    if (!mounted) return;

    // Prevent multiple initialization attempts
    if (_isConnecting || isBluetoothConnected) {
      debugPrint(
        'Bluetooth already connecting/connected, skipping initialization',
      );
      return;
    }

    try {
      // Check if Bluetooth is available
      bool? isAvailable = await FlutterBluetoothSerial.instance.isAvailable;
      if (isAvailable != true) {
        debugPrint('Bluetooth is not available');
        return;
      }

      // Check if Bluetooth is enabled
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;

      if (!mounted) return;

      setState(() {
        _isBluetoothEnabled = isEnabled ?? false;
      });

      if (_isBluetoothEnabled) {
        await _getBondedDevices();
        if (mounted && !_isConnecting && !isBluetoothConnected) {
          _startAutoConnect();
        }
      } else {
        // Try to enable Bluetooth
        try {
          await FlutterBluetoothSerial.instance.requestEnable();
          if (mounted) {
            _initializeBluetooth();
          }
        } catch (e) {
          debugPrint('Bluetooth permission denied: $e');
        }
      }
    } catch (e) {
      debugPrint('Error initializing Bluetooth: $e');
    }
  }

  /// Get paired/bonded devices
  Future<void> _getBondedDevices() async {
    try {
      List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial
          .instance
          .getBondedDevices();
      setState(() {
        _devices = bondedDevices;
      });
      debugPrint('Found ${_devices.length} paired devices');
    } catch (e) {
      debugPrint('Error getting paired devices: $e');
    }
  }

  /// Start automatic connection to HC-05 or robot devices
  void _startAutoConnect() {
    // Check if widget is still mounted and not already connecting
    if (!mounted || _isConnecting || isBluetoothConnected) {
      debugPrint(
        'Skipping auto-connect: mounted=$mounted, connecting=$_isConnecting, connected=$isBluetoothConnected',
      );
      return;
    }

    // Look for HC-05 or robot-related devices
    List<BluetoothDevice> robotDevices = _devices
        .where(
          (device) =>
              device.name?.toLowerCase().contains('hc-05') == true ||
              device.name?.toLowerCase().contains('hc-06') == true ||
              device.name?.toLowerCase().contains('robot') == true ||
              device.name?.toLowerCase().contains('arduino') == true ||
              device.name?.toLowerCase().contains('esp') == true,
        )
        .toList();

    if (robotDevices.isNotEmpty) {
      _selectedDevice = robotDevices.first;
      debugPrint('Auto-connecting to: ${_selectedDevice!.name}');
      _connectToBluetooth();
    } else {
      debugPrint('No HC-05/robot devices found automatically');
      // Try to connect to the first available device if any
      if (_devices.isNotEmpty) {
        _selectedDevice = _devices.first;
        debugPrint(
          'Attempting to connect to first available device: ${_selectedDevice!.name}',
        );
        _connectToBluetooth();
      }
    }
  }

  /// Connect to selected Bluetooth device
  Future<void> _connectToBluetooth() async {
    if (_selectedDevice == null) {
      debugPrint('No device selected for connection');
      return;
    }

    // Prevent multiple simultaneous connection attempts
    if (_isConnecting) {
      debugPrint('Already connecting to Bluetooth device, skipping...');
      return;
    }

    // Check if widget is still mounted
    if (!mounted) {
      debugPrint('Widget disposed, skipping Bluetooth connection');
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      debugPrint(
        'Attempting to connect to Bluetooth device: ${_selectedDevice!.name}',
      );

      BluetoothConnection connection = await BluetoothConnection.toAddress(
        _selectedDevice!.address,
      );

      // Check if widget is still mounted before updating state
      if (!mounted) {
        debugPrint('Widget disposed during connection, closing connection');
        connection.dispose();
        return;
      }

      setState(() {
        bluetoothConnection = connection;
        isBluetoothConnected = true;
        _isConnecting = false;
      });

      debugPrint('✅ Connected to Bluetooth device: ${_selectedDevice!.name}');

      // Listen for data from the device
      _bluetoothSubscription = bluetoothConnection!.input!.listen(
        (data) {
          if (mounted) {
            String message = String.fromCharCodes(data);
            debugPrint('Received from robot: $message');

            // Check for power command responses
            if (message.contains('POWER_ON') || message.contains('OK_PON')) {
              debugPrint('🟢 Power ON command confirmed by robot');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Robot Power ON confirmed'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            } else if (message.contains('POWER_OFF') ||
                message.contains('OK_POFF')) {
              debugPrint('🔴 Power OFF command confirmed by robot');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Robot Power OFF confirmed'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            }
          }
        },
        onError: (error) {
          debugPrint('Bluetooth data error: $error');
          if (mounted) {
            setState(() {
              isBluetoothConnected = false;
              bluetoothConnection = null;
              _isConnecting = false;
            });
          }
        },
        onDone: () {
          debugPrint('Bluetooth connection closed');
          if (mounted) {
            setState(() {
              isBluetoothConnected = false;
              bluetoothConnection = null;
              _isConnecting = false;
            });

            // Start auto-reconnect only if widget is still mounted
            _startAutoReconnect();
          }
        },
      );

      // Start auto-reconnect monitoring
      _startAutoReconnect();
    } catch (e) {
      debugPrint('Error connecting to Bluetooth: $e');

      if (mounted) {
        setState(() {
          isBluetoothConnected = false;
          bluetoothConnection = null;
          _isConnecting = false;
        });

        // Retry connection in 5 seconds only if widget is still mounted
        _autoConnectTimer?.cancel();
        _autoConnectTimer = Timer(const Duration(seconds: 5), () {
          if (mounted &&
              !isBluetoothConnected &&
              _selectedDevice != null &&
              !_isConnecting) {
            _connectToBluetooth();
          }
        });
      }
    }
  }

  /// Start auto-reconnect monitoring
  void _startAutoReconnect() {
    _autoConnectTimer?.cancel();
    _autoConnectTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      // Check if widget is still mounted before attempting reconnection
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Only reconnect if not already connected and not currently connecting
      if (!isBluetoothConnected && !_isConnecting && _selectedDevice != null) {
        debugPrint('Auto-reconnecting to ${_selectedDevice!.name}...');
        _connectToBluetooth();
      }
    });
  }

  /// Send command to robot via Bluetooth
  Future<void> _sendBluetoothCommand(String command) async {
    if (!isBluetoothConnected || bluetoothConnection == null) {
      debugPrint('Bluetooth not connected, cannot send command: $command');

      // Show snackbar to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth not connected to robot'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Add newline terminator for Arduino serial communication
      String commandWithTerminator = '$command\n';
      debugPrint('Sending Bluetooth command: $commandWithTerminator');
      bluetoothConnection!.output.add(
        Uint8List.fromList(commandWithTerminator.codeUnits),
      );
      await bluetoothConnection!.output.allSent;
      debugPrint('✅ Command sent successfully: $command');
    } catch (e) {
      debugPrint('Error sending Bluetooth command: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send command: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Refresh the MJPEG stream
  void _refreshStream() {
    setState(() {
      _mjpegKey = UniqueKey(); // This will force rebuild of the Mjpeg widget
      _errorMessage = '';
    });
  }

  /// Test connectivity and start streaming
  Future<void> _testAndStartStreaming() async {
    // Check if widget is still mounted before starting
    if (!mounted) return;

    setState(() {
      _isLoadingStream = true;
      _errorMessage = '';
    });

    debugPrint('🚀 Testing connectivity to camera server...');

    // Test if the camera server is running
    bool serverRunning = await _testConnectivity(streamUrl);

    if (!serverRunning) {
      debugPrint(
        'Primary connectivity test failed, trying alternative method...',
      );
      serverRunning = await _testConnectivityAlternative(
        'http://$_raspberryPiIP:8080',
      );
    }

    // Check if widget is still mounted before updating state
    if (!mounted) return;

    if (serverRunning) {
      debugPrint('✅ Server is reachable, stream ready');
      if (mounted) {
        setState(() {
          _isLoadingStream = false;
          _isStreamActive = true;
          _errorMessage = '';
        });
      }
    } else {
      debugPrint(
        '❌ Server not reachable, attempting to start remote camera...',
      );
      // Try to start the camera on the server
      await _startRemoteCamera();

      // Wait a bit for the camera to start
      await Future.delayed(const Duration(seconds: 3));

      // Check if widget is still mounted before continuing
      if (!mounted) return;

      // Try again
      bool retryResult = await _testConnectivity(streamUrl);

      // Check if widget is still mounted before final state update
      if (!mounted) return;

      if (retryResult) {
        debugPrint('✅ Camera started successfully');
        if (mounted) {
          setState(() {
            _isLoadingStream = false;
            _isStreamActive = true;
            _errorMessage = '';
          });
        }
      } else {
        debugPrint('❌ Unable to establish connection after retry');
        if (mounted) {
          setState(() {
            _isLoadingStream = false;
            _isStreamActive = false;
            _errorMessage =
                'Unable to connect to camera server.\n'
                'Please verify:\n'
                '• Camera server is running on Raspberry Pi\n'
                '• IP address $_raspberryPiIP is correct\n'
                '• Port 8080 is accessible\n'
                '• Both devices are on same network';
          });
        }
      }
    }
  }

  /// Test basic connectivity to the server
  Future<bool> _testConnectivity(String url) async {
    try {
      debugPrint('Testing basic connectivity to: $url');

      final client = http.Client();
      try {
        final response = await client
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));

        debugPrint('Test response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          debugPrint('✅ Successfully connected to camera server');
          return true;
        } else {
          debugPrint('❌ Server responded with status: ${response.statusCode}');
          return false;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('❌ Connectivity test failed: $e');
      return false;
    }
  }

  /// Alternative connectivity test using different endpoints
  Future<bool> _testConnectivityAlternative(String baseUrl) async {
    try {
      debugPrint('Testing alternative connectivity to base URL: $baseUrl');

      final endpoints = [
        '$baseUrl/',
        '$baseUrl/my_mac_camera', // Test the actual stream endpoint
        '$baseUrl/health',
        '$baseUrl/camera/status',
      ];

      for (String endpoint in endpoints) {
        try {
          debugPrint('Trying endpoint: $endpoint');
          final client = http.Client();

          try {
            final response = await client
                .get(Uri.parse(endpoint))
                .timeout(const Duration(seconds: 8));

            debugPrint('Response status for $endpoint: ${response.statusCode}');
            debugPrint('Content-Type: ${response.headers['content-type']}');

            if (response.statusCode == 200) {
              debugPrint('✅ Successfully connected to: $endpoint');

              // If this is the camera endpoint, check if it's actually streaming
              if (endpoint.contains('/my_mac_camera')) {
                final contentType = response.headers['content-type'];
                if (contentType != null &&
                    contentType.contains('multipart/x-mixed-replace')) {
                  debugPrint('✅ MJPEG stream endpoint confirmed working');
                  return true;
                } else {
                  debugPrint(
                    '⚠️ Endpoint exists but may not be streaming MJPEG',
                  );
                }
              }
              return true;
            }
          } finally {
            client.close();
          }
        } catch (e) {
          debugPrint('Failed to connect to $endpoint: $e');
          continue;
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Alternative connectivity test failed: $e');
      return false;
    }
  }

  /// Start the camera remotely
  Future<void> _startRemoteCamera() async {
    try {
      final response = await http
          .post(
            Uri.parse('http://$_raspberryPiIP:8080/camera/start'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('Camera started remotely');
      } else {
        debugPrint('Failed to start remote camera: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error starting remote camera: $e');
    }
  }

  /// Get camera status
  Future<Map<String, dynamic>?> getCameraStatus() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_raspberryPiIP:8080/camera/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Error getting camera status: $e');
    }
    return null;
  }

  /// Get connection status text for UI display
  String _getConnectionStatusText() {
    if (_isConnecting) {
      String deviceName = _selectedDevice?.name ?? 'HC-05';
      return 'Connecting to $deviceName...';
    } else if (isBluetoothConnected) {
      String deviceName = _selectedDevice?.name ?? 'Unknown Device';
      return 'Connected to $deviceName';
    } else {
      return 'Not Connected - Power control disabled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.videocam, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Live Monitoring',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[800],
        elevation: 4,
        shadowColor: Colors.green[300],
        actions: [
          // Refresh Stream Button
          // Container(
          //   margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          //   child: IconButton(
          //     onPressed: _refreshStream,
          //     icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
          //     tooltip: 'Refresh Stream',
          //     style: IconButton.styleFrom(
          //       backgroundColor: Colors.white.withOpacity(0.15),
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(8),
          //       ),
          //     ),
          //   ),
          // ),
          // Bluetooth status indicator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnecting
                        ? Colors.orange
                        : (isBluetoothConnected
                              ? Colors.lightGreen
                              : Colors.grey[400]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (isBluetoothConnected || _isConnecting)
                        BoxShadow(
                          color: _isConnecting
                              ? Colors.orange
                              : Colors.lightGreen,
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnecting
                      ? 'BT•••'
                      : (isBluetoothConnected ? 'BT✓' : 'BT✗'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Robot status indicator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: robotStatus == 'Active'
                  ? Colors.green[400]?.withOpacity(0.9)
                  : (robotStatus == 'Power Off'
                        ? Colors.red[400]?.withOpacity(0.9)
                        : Colors.orange[400]?.withOpacity(0.9)),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: robotStatus == 'Active'
                      ? Colors.green.withOpacity(0.3)
                      : (robotStatus == 'Power Off'
                            ? Colors.red.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3)),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  robotStatus == 'Active'
                      ? Icons.power
                      : (robotStatus == 'Power Off'
                            ? Icons.power_off
                            : Icons.warning),
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  robotStatus,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live video feed
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: _buildVideoWidget(),
                ),
              ),
            ),
          ),

          // Status Cards
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Connection Status Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _isConnecting
                                ? Colors.orange[50]!
                                : (isBluetoothConnected
                                      ? Colors.green[50]!
                                      : Colors.blue[50]!),
                            _isConnecting
                                ? Colors.orange[100]!
                                : (isBluetoothConnected
                                      ? Colors.green[100]!
                                      : Colors.blue[100]!),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isConnecting
                                      ? Colors.orange
                                      : (isBluetoothConnected
                                            ? Colors.green
                                            : Colors.blue),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _isConnecting
                                      ? Icons.bluetooth_searching
                                      : (isBluetoothConnected
                                            ? Icons.bluetooth_connected
                                            : Icons.bluetooth_disabled),
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bluetooth Connection',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getConnectionStatusText(),
                                      style: TextStyle(
                                        color: _isConnecting
                                            ? Colors.orange[700]
                                            : (isBluetoothConnected
                                                  ? Colors.green[700]
                                                  : Colors.blue[700]),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isConnecting)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.orange,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (!isBluetoothConnected && !_isConnecting) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Tap "Connect" below to enable robot power control',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Power Control Section
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.grey[50]!, Colors.grey[100]!],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.power_settings_new,
                                color: Colors.grey[700],
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Robot Power Control',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Power ON/OFF Button
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 42,
                                  child: ElevatedButton(
                                    onPressed: () => _toggleEmergencyStop(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isEmergencyStop
                                          ? Colors.green[600]
                                          : Colors.red[600],
                                      foregroundColor: Colors.white,
                                      elevation: 6,
                                      shadowColor: isEmergencyStop
                                          ? Colors.green[300]
                                          : Colors.red[300],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isEmergencyStop
                                              ? Icons.power_settings_new
                                              : Icons.power_off,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              isEmergencyStop
                                                  ? 'POWER ON'
                                                  : 'POWER OFF',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Bluetooth Connection Button
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 42,
                                  child: ElevatedButton(
                                    onPressed: _isConnecting
                                        ? null
                                        : (isBluetoothConnected
                                              ? null
                                              : () async {
                                                  if (_selectedDevice != null &&
                                                      !_isConnecting) {
                                                    await _connectToBluetooth();
                                                  } else if (!_isConnecting) {
                                                    await _initializeBluetooth();
                                                  }
                                                }),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isConnecting
                                          ? Colors.orange[400]
                                          : (isBluetoothConnected
                                                ? Colors.blue[600]
                                                : Colors.orange[600]),
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      shadowColor: _isConnecting
                                          ? Colors.orange[300]
                                          : (isBluetoothConnected
                                                ? Colors.blue[300]
                                                : Colors.orange[300]),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isConnecting
                                              ? Icons.bluetooth_searching
                                              : (isBluetoothConnected
                                                    ? Icons.bluetooth_connected
                                                    : Icons.bluetooth),
                                          size: 16,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _isConnecting
                                              ? 'Connecting'
                                              : (isBluetoothConnected
                                                    ? 'Connected'
                                                    : 'Connect'),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildVideoWidget() {
    if (_isLoadingStream) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white54),
          const SizedBox(height: 16),
          const Icon(Icons.videocam, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'Connecting to Live Camera Feed...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          Text(
            streamUrl,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'Camera Connection Failed',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _testAndStartStreaming,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    if (_isStreamActive) {
      debugPrint('🎥 Attempting to display MJPEG stream: $streamUrl');
      return Mjpeg(
        key: _mjpegKey,
        isLive: true,
        stream: streamUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        loading: (context) => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white54),
              SizedBox(height: 10),
              Text(
                'Loading video stream...',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
        error: (context, error, stack) {
          debugPrint('🚨 MJPEG Stream Error: $error');
          debugPrint('Stack trace: $stack');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.red, size: 80),
                const SizedBox(height: 16),
                const Text(
                  'Stream Error',
                  style: TextStyle(color: Colors.red, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'URL: $streamUrl',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _refreshStream,
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
        },
        timeout: const Duration(seconds: 15), // Increased timeout
      );
    }

    // Default state
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.videocam, size: 64, color: Colors.white54),
        const SizedBox(height: 16),
        const Text(
          'Live Camera Feed',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        Text(
          streamUrl,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _testAndStartStreaming,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Stream'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  void _toggleEmergencyStop() async {
    setState(() {
      isEmergencyStop = !isEmergencyStop;
      robotStatus = isEmergencyStop ? 'Power Off' : 'Active';
      currentTask = isEmergencyStop ? 'Power Cut Off' : 'Scanning for weeds';
    });

    // Send Bluetooth power control command to robot
    String bluetoothCommand = isEmergencyStop ? 'POFF' : 'PON';
    await _sendBluetoothCommand(bluetoothCommand);

    // Also send HTTP control command as backup
    try {
      final response = await http.post(
        Uri.parse(controlUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': isEmergencyStop ? 'power_off' : 'power_on',
          'bluetooth_command': bluetoothCommand,
        }),
      );
      if (response.statusCode == 200) {
        debugPrint('HTTP control command sent successfully: ${response.body}');
      } else {
        debugPrint(
          'Failed to send HTTP control command: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      debugPrint('Error sending HTTP control command: $e');
    }

    // Show feedback to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEmergencyStop
                ? '🔴 Robot Power Cut Off'
                : '🟢 Robot Power Restored',
          ),
          backgroundColor: isEmergencyStop ? Colors.red : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
