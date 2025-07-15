import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class RobotSensorDashboard extends StatefulWidget {
  final BluetoothConnection? bluetoothConnection;
  final bool isConnected;
  final String? deviceName;
  final bool standaloneMode;

  const RobotSensorDashboard({
    super.key,
    this.bluetoothConnection,
    this.isConnected = false,
    this.deviceName,
    this.standaloneMode = false,
  });

  @override
  State<RobotSensorDashboard> createState() => _RobotSensorDashboardState();
}

class _RobotSensorDashboardState extends State<RobotSensorDashboard> {
  Timer? _statusRequestTimer;
  Timer? _simulationTimer;
  StreamSubscription<Uint8List>? _bluetoothSubscription;
  String _incomingData = '';

  // Standalone Bluetooth variables
  BluetoothConnection? _ownConnection;
  bool _isBluetoothEnabled = false;
  bool _isConnecting = false;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  Timer? _autoConnectTimer;

  // System Status Data matching Arduino system_status.h
  Map<String, dynamic> systemData = {
    'uptime': 0,
    'isReady': false,
    'emergencyStop': false,
    'debugMode': false,
    'freeMemory': 0,
    'loopFrequency': 0.0,
    'globalSpeedMultiplier': 60,
    'timeSinceLastCommand': 0,
    'averageLoopTime': 0,
    'systemHealthy': true,
  };

  // Sensor Data
  Map<String, dynamic> sensorData = {
    'leftDistance': 0,
    'rightDistance': 0,
    'frontDistance': 0,
    'batteryVoltage': 12.0,
    'temperature': 25,
    'collisionAvoidanceActive': true,
  };

  // Motor Status
  Map<String, dynamic> motorData = {
    'leftMotorSpeed': 0,
    'rightMotorSpeed': 0,
    'motorsEnabled': true,
    'motorDiagnostics': true,
  };

  // Servo Status
  Map<String, dynamic> servoData = {
    'servo0': 90,
    'servo1': 90,
    'servo2': 90,
    'servo3': 90,
    'servo4': 90,
    'servo5': 90,
    'servoEnabled': true,
  };

  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  String _lastError = '';
  int _statusRequestCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.standaloneMode) {
      _initializeStandaloneBluetooth();
    } else {
      _checkConnection();
    }
    _startDataCollection();
  }

  @override
  void dispose() {
    // Clean up timers and subscriptions
    _statusRequestTimer?.cancel();
    _simulationTimer?.cancel();
    _bluetoothSubscription?.cancel();
    _autoConnectTimer?.cancel();

    // Only dispose our own connection in standalone mode
    if (widget.standaloneMode && _ownConnection != null) {
      _ownConnection?.dispose();
    }
    super.dispose();
  }

  void _checkConnection() {
    setState(() {
      if (widget.standaloneMode) {
        _isConnected = _ownConnection != null;
        _connectionStatus = _isConnected
            ? 'Connected via Bluetooth to ${_selectedDevice?.name ?? "Device"}'
            : 'Disconnected - Standalone Mode';
      } else {
        _isConnected = widget.isConnected && widget.bluetoothConnection != null;
        _connectionStatus = _isConnected
            ? 'Connected via Bluetooth to ${widget.deviceName ?? "Device"}'
            : 'Disconnected';
      }
    });
  }

  // Standalone Bluetooth initialization
  void _initializeStandaloneBluetooth() async {
    try {
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      setState(() {
        _isBluetoothEnabled = isEnabled ?? false;
        _connectionStatus = _isBluetoothEnabled
            ? 'Bluetooth enabled - Searching for devices...'
            : 'Bluetooth disabled';
      });

      if (_isBluetoothEnabled) {
        await _getBondedDevices();
        _startAutoConnect();
      } else {
        // Try to enable Bluetooth
        try {
          await FlutterBluetoothSerial.instance.requestEnable();
          _initializeStandaloneBluetooth();
        } catch (e) {
          setState(() {
            _connectionStatus = 'Please enable Bluetooth manually';
            _lastError = 'Bluetooth permission denied';
          });
        }
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error initializing Bluetooth: $e';
        _lastError = 'Bluetooth initialization failed';
      });
    }
  }

  Future<void> _getBondedDevices() async {
    try {
      List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial
          .instance
          .getBondedDevices();
      setState(() {
        _devices = bondedDevices;
        _connectionStatus = 'Found ${_devices.length} paired devices';
      });
    } catch (e) {
      setState(() {
        _lastError = 'Error getting paired devices: $e';
      });
    }
  }

  void _startAutoConnect() {
    // Look for HC-05 or robot-related devices
    List<BluetoothDevice> robotDevices = _devices
        .where(
          (device) =>
              device.name?.toLowerCase().contains('hc-05') == true ||
              device.name?.toLowerCase().contains('robot') == true ||
              device.name?.toLowerCase().contains('arduino') == true ||
              device.name?.toLowerCase().contains('esp') == true,
        )
        .toList();

    if (robotDevices.isNotEmpty) {
      _selectedDevice = robotDevices.first;
      _connectToStandaloneDevice(_selectedDevice!);
    } else if (_devices.isNotEmpty) {
      // Show available devices for manual selection
      setState(() {
        _connectionStatus =
            'No robot devices found automatically. Manual selection available.';
      });
    } else {
      setState(() {
        _connectionStatus =
            'No paired devices found. Please pair your HC-05 module first.';
      });
    }
  }

  void _connectToStandaloneDevice(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _selectedDevice = device;
      _connectionStatus = 'Connecting to ${device.name}...';
      _lastError = '';
    });

    try {
      _ownConnection = await BluetoothConnection.toAddress(device.address);
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _connectionStatus = 'Connected to ${device.name}';
      });

      // Restart data collection with new connection
      _restartDataCollection();

      // Start auto-reconnect monitoring
      _startAutoReconnect();
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _connectionStatus = 'Failed to connect to ${device.name}';
        _lastError = 'Connection failed: $e';
      });

      // Retry connection in 5 seconds
      _autoConnectTimer?.cancel();
      _autoConnectTimer = Timer(const Duration(seconds: 5), () {
        if (!_isConnected && widget.standaloneMode) {
          _connectToStandaloneDevice(device);
        }
      });
    }
  }

  void _startAutoReconnect() {
    _autoConnectTimer?.cancel();
    _autoConnectTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (widget.standaloneMode && !_isConnected && _selectedDevice != null) {
        print('Auto-reconnecting to ${_selectedDevice!.name}...');
        _connectToStandaloneDevice(_selectedDevice!);
      } else if (_isConnected) {
        // Test connection with a ping
        _requestSystemStatus();
      }
    });
  }

  void _disconnectStandalone() async {
    if (_ownConnection != null) {
      try {
        await _ownConnection!.close();
        setState(() {
          _isConnected = false;
          _ownConnection = null;
          _connectionStatus = 'Disconnected';
        });
        _autoConnectTimer?.cancel();
      } catch (e) {
        print('Error disconnecting: $e');
      }
    }
  }

  void _restartDataCollection() {
    _statusRequestTimer?.cancel();
    _bluetoothSubscription?.cancel();
    _startDataCollection();
  }

  void _startDataCollection() {
    BluetoothConnection? activeConnection = widget.standaloneMode
        ? _ownConnection
        : widget.bluetoothConnection;

    if (_isConnected && activeConnection != null) {
      // Listen to incoming Bluetooth data
      _bluetoothSubscription = activeConnection.input?.listen(
        _handleIncomingData,
        onError: (error) {
          setState(() {
            _lastError = 'Data stream error: $error';
          });

          // Handle connection loss in standalone mode
          if (widget.standaloneMode) {
            setState(() {
              _isConnected = false;
              _connectionStatus = 'Connection lost - Attempting reconnect...';
            });
            _startAutoReconnect();
          }
        },
      );

      // Request status from Arduino every 3 seconds
      _statusRequestTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _requestSystemStatus();
      });
    } else {
      // Simulate data for demonstration
      _startSimulation();
    }
  }

  void _handleIncomingData(Uint8List data) {
    try {
      String newData = utf8.decode(data);
      _incomingData += newData;

      // Process complete lines (ending with \n)
      while (_incomingData.contains('\n')) {
        int lineEnd = _incomingData.indexOf('\n');
        String line = _incomingData.substring(0, lineEnd);
        _incomingData = _incomingData.substring(lineEnd + 1);

        // Only parse lines that look like status responses
        if (line.contains('|') &&
            (line.contains('Uptime:') || line.contains('STATUS:'))) {
          _parseArduinoResponse(line);
        }
      }
    } catch (e) {
      setState(() {
        _lastError = 'Data parsing error: $e';
      });
    }
  }

  void _requestSystemStatus() {
    BluetoothConnection? activeConnection = widget.standaloneMode
        ? _ownConnection
        : widget.bluetoothConnection;

    if (activeConnection != null && _isConnected) {
      try {
        // Use different command for standalone mode to avoid conflicts
        _statusRequestCount++;
        String command = widget.standaloneMode
            ? 'STATUS_SENSOR_$_statusRequestCount\n'
            : 'STATUS_DASHBOARD_$_statusRequestCount\n';

        activeConnection.output.add(utf8.encode(command));

        // Clear any old errors
        if (_lastError.isNotEmpty) {
          setState(() {
            _lastError = '';
          });
        }
      } catch (e) {
        setState(() {
          _lastError = 'Communication error: $e';
        });

        // Handle connection loss in standalone mode
        if (widget.standaloneMode) {
          setState(() {
            _isConnected = false;
            _connectionStatus = 'Communication error - Reconnecting...';
          });
          _startAutoReconnect();
        }
      }
    }
  }

  void _parseArduinoResponse(String response) {
    // Parse the Arduino status response
    // Format: "Uptime:12345|Ready:YES|Emergency:OK|Memory:1234|Loop:150.5Hz"
    try {
      Map<String, String> values = {};
      List<String> pairs = response.trim().split('|');

      for (String pair in pairs) {
        List<String> keyValue = pair.split(':');
        if (keyValue.length == 2) {
          values[keyValue[0].trim()] = keyValue[1].trim();
        }
      }

      setState(() {
        // Update system data
        systemData['uptime'] =
            int.tryParse(values['Uptime'] ?? '0') ?? systemData['uptime'];
        systemData['isReady'] = values['Ready'] == 'YES';
        systemData['emergencyStop'] = values['Emergency'] == 'ACTIVE';
        systemData['freeMemory'] =
            int.tryParse(values['Memory'] ?? '0') ?? systemData['freeMemory'];

        String loopStr = values['Loop'] ?? '0Hz';
        systemData['loopFrequency'] =
            double.tryParse(loopStr.replaceAll('Hz', '')) ??
            systemData['loopFrequency'];

        // Update additional fields if present
        if (values.containsKey('Speed')) {
          systemData['globalSpeedMultiplier'] =
              int.tryParse(values['Speed'] ?? '60') ??
              systemData['globalSpeedMultiplier'];
        }

        if (values.containsKey('Debug')) {
          systemData['debugMode'] = values['Debug'] == 'ON';
        }

        // Update sensor data if present
        if (values.containsKey('LeftDist')) {
          sensorData['leftDistance'] =
              int.tryParse(values['LeftDist'] ?? '0') ??
              sensorData['leftDistance'];
        }
        if (values.containsKey('RightDist')) {
          sensorData['rightDistance'] =
              int.tryParse(values['RightDist'] ?? '0') ??
              sensorData['rightDistance'];
        }
        if (values.containsKey('FrontDist')) {
          sensorData['frontDistance'] =
              int.tryParse(values['FrontDist'] ?? '0') ??
              sensorData['frontDistance'];
        }

        // Update motor data if present
        if (values.containsKey('LeftMotor')) {
          motorData['leftMotorSpeed'] =
              int.tryParse(values['LeftMotor'] ?? '0') ??
              motorData['leftMotorSpeed'];
        }
        if (values.containsKey('RightMotor')) {
          motorData['rightMotorSpeed'] =
              int.tryParse(values['RightMotor'] ?? '0') ??
              motorData['rightMotorSpeed'];
        }

        _lastError = '';
      });
    } catch (e) {
      setState(() {
        _lastError = 'Parse error: $e';
      });
    }
  }

  void _startSimulation() {
    // Simulate realistic data when not connected
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final random = Random();

          // System data simulation
          systemData['uptime'] = systemData['uptime'] + 1000;
          systemData['loopFrequency'] = 145.0 + (random.nextDouble() * 10);
          systemData['freeMemory'] = 1800 + random.nextInt(200);
          systemData['timeSinceLastCommand'] = random.nextInt(5000);
          systemData['averageLoopTime'] = 5 + random.nextInt(3);

          // Sensor data simulation
          sensorData['leftDistance'] = 20 + random.nextInt(180);
          sensorData['rightDistance'] = 20 + random.nextInt(180);
          sensorData['frontDistance'] = 30 + random.nextInt(170);
          sensorData['batteryVoltage'] = 11.5 + (random.nextDouble() * 1.0);
          sensorData['temperature'] = 25 + random.nextInt(15);

          // Motor data simulation
          motorData['leftMotorSpeed'] = random.nextInt(201) - 100;
          motorData['rightMotorSpeed'] = random.nextInt(201) - 100;
        });
      }
    });
  }

  String _formatUptime(int milliseconds) {
    int seconds = milliseconds ~/ 1000;
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    seconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(bool isGood) {
    return isGood ? Colors.green : Colors.red;
  }

  Color _getDistanceColor(int distance) {
    if (distance < 30) return Colors.red;
    if (distance < 60) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.standaloneMode
              ? '🤖 Sensor Dashboard'
              : '🤖 Robot System Status',
        ),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          if (widget.standaloneMode && !_isConnected) ...[
            IconButton(
              icon: const Icon(Icons.bluetooth_searching),
              onPressed: _initializeStandaloneBluetooth,
              tooltip: 'Search & Connect',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_isConnected) {
                _requestSystemStatus();
              } else if (widget.standaloneMode) {
                _initializeStandaloneBluetooth();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_isConnected) {
            _requestSystemStatus();
          } else if (widget.standaloneMode) {
            _initializeStandaloneBluetooth();
          }
          await Future.delayed(const Duration(seconds: 1));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Connection Status
            _buildConnectionStatusCard(),
            const SizedBox(height: 16),

            // System Status
            _buildSystemStatusCard(),
            const SizedBox(height: 16),

            // Performance Metrics
            _buildPerformanceCard(),
            const SizedBox(height: 16),

            // Distance Sensors
            _buildDistanceSensorsCard(),
            const SizedBox(height: 16),

            // Motor Status
            _buildMotorStatusCard(),
            const SizedBox(height: 16),

            // Servo Status
            _buildServoStatusCard(),
            const SizedBox(height: 16),

            // Safety & Diagnostics
            _buildSafetyCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: _isConnected ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.standaloneMode
                        ? 'Standalone Connection'
                        : 'Shared Connection',
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isConnected) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.standaloneMode ? 'AUTO' : 'LIVE',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connectionStatus,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),

            // Show device selection in standalone mode when not connected
            if (widget.standaloneMode &&
                !_isConnected &&
                _devices.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Available Devices:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButton<BluetoothDevice>(
                hint: const Text('Select Device'),
                value: _selectedDevice,
                isExpanded: true,
                items: _devices.map((device) {
                  return DropdownMenuItem(
                    value: device,
                    child: Text(
                      device.name ?? 'Unknown Device (${device.address})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (device) {
                  if (device != null) {
                    _connectToStandaloneDevice(device);
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isConnecting
                          ? null
                          : () {
                              if (_selectedDevice != null) {
                                _connectToStandaloneDevice(_selectedDevice!);
                              }
                            },
                      child: _isConnecting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Connecting...'),
                              ],
                            )
                          : const Text('Connect'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _getBondedDevices,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Devices',
                  ),
                ],
              ),
            ],

            // Show disconnect button in standalone mode when connected
            if (widget.standaloneMode && _isConnected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.bluetooth_connected, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connected to ${_selectedDevice?.name ?? 'Device'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _disconnectStandalone,
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
            ],

            if (_lastError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastError,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.computer,
                  color: systemData['isReady'] ? Colors.green : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'System Status',
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatusTile(
                    'System Ready',
                    systemData['isReady'] ? 'YES' : 'NO',
                    systemData['isReady'] ? Colors.green : Colors.red,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatusTile(
                    'Emergency Stop',
                    systemData['emergencyStop'] ? 'ACTIVE' : 'OK',
                    systemData['emergencyStop'] ? Colors.red : Colors.green,
                    Icons.emergency,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ListTile(
              leading: const Icon(Icons.timer, color: Colors.blue),
              title: const Text('Uptime'),
              trailing: Text(_formatUptime(systemData['uptime'])),
              contentPadding: EdgeInsets.zero,
            ),

            ListTile(
              leading: const Icon(Icons.speed, color: Colors.orange),
              title: const Text('Global Speed'),
              trailing: Text('${systemData['globalSpeedMultiplier']}%'),
              contentPadding: EdgeInsets.zero,
            ),

            ListTile(
              leading: Icon(
                Icons.bug_report,
                color: systemData['debugMode'] ? Colors.orange : Colors.grey,
              ),
              title: const Text('Debug Mode'),
              trailing: Text(systemData['debugMode'] ? 'ON' : 'OFF'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.purple, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Performance Metrics',
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Loop Frequency',
                    '${systemData['loopFrequency'].toStringAsFixed(1)} Hz',
                    Icons.refresh,
                    systemData['loopFrequency'] > 100
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricTile(
                    'Free Memory',
                    '${systemData['freeMemory']} bytes',
                    Icons.memory,
                    systemData['freeMemory'] > 1000 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.blue),
              title: const Text('Average Loop Time'),
              trailing: Text('${systemData['averageLoopTime']} ms'),
              contentPadding: EdgeInsets.zero,
            ),

            ListTile(
              leading: const Icon(Icons.access_time, color: Colors.green),
              title: const Text('Last Command'),
              trailing: Text('${systemData['timeSinceLastCommand']} ms ago'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceSensorsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.radar, color: Colors.blue, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Distance Sensors (HC-SR04)',
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildDistanceIndicator(
                    'Rear',
                    sensorData['leftDistance'],
                    Icons.arrow_forward_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDistanceIndicator(
                    'Front',
                    sensorData['frontDistance'],
                    Icons.arrow_upward,
                  ),
                ),
                //const SizedBox(width: 8),
                //Expanded(
                //  child: _buildDistanceIndicator(
                //    'Right',
                //    sensorData['rightDistance'],
                //    Icons.arrow_forward,
                //  ),
                //),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Icon(
                  sensorData['collisionAvoidanceActive']
                      ? Icons.shield
                      : Icons.shield_outlined,
                  color: sensorData['collisionAvoidanceActive']
                      ? Colors.green
                      : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Collision Avoidance: ${sensorData['collisionAvoidanceActive'] ? 'ACTIVE' : 'DISABLED'}',
                    style: TextStyle(
                      color: sensorData['collisionAvoidanceActive']
                          ? Colors.green
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotorStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: motorData['motorsEnabled'] ? Colors.blue : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Motor Controller',
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildMotorSpeedIndicator(
                    'Left Motor',
                    motorData['leftMotorSpeed'],
                    Icons.arrow_back,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMotorSpeedIndicator(
                    'Right Motor',
                    motorData['rightMotorSpeed'],
                    Icons.arrow_forward,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Icon(
                  motorData['motorsEnabled'] ? Icons.power : Icons.power_off,
                  color: motorData['motorsEnabled'] ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Motors: ${motorData['motorsEnabled'] ? 'ENABLED' : 'DISABLED'}',
                    style: TextStyle(
                      color: motorData['motorsEnabled']
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServoStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.precision_manufacturing,
                  color: servoData['servoEnabled'] ? Colors.green : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '6-Servo Arm Status',
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Fixed GridView - removed Expanded widget that was causing the layout error
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.8, // Adjusted for better text fit
              crossAxisSpacing: 6, // Reduced spacing
              mainAxisSpacing: 6, // Reduced spacing
              children: [
                _buildServoTile('Base', servoData['servo0']),
                _buildServoTile('Shoulder', servoData['servo1']),
                _buildServoTile('Elbow', servoData['servo2']),
                _buildServoTile('Wrist P', servoData['servo3']),
                _buildServoTile('Wrist R', servoData['servo4']),
                _buildServoTile('Gripper', servoData['servo5']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: Colors.orange, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Safety & Diagnostics',
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: Icon(
                Icons.battery_full,
                color: sensorData['batteryVoltage'] > 11.0
                    ? Colors.green
                    : Colors.red,
              ),
              title: const Text('Battery Voltage'),
              trailing: Text(
                '${sensorData['batteryVoltage'].toStringAsFixed(1)}V',
              ),
              contentPadding: EdgeInsets.zero,
            ),

            ListTile(
              leading: Icon(
                Icons.thermostat,
                color: sensorData['temperature'] < 60
                    ? Colors.green
                    : Colors.red,
              ),
              title: const Text('System Temperature'),
              trailing: Text('${sensorData['temperature']}°C'),
              contentPadding: EdgeInsets.zero,
            ),

            ListTile(
              leading: Icon(
                Icons.health_and_safety,
                color: systemData['systemHealthy'] ? Colors.green : Colors.red,
              ),
              title: const Text('System Health'),
              trailing: Text(
                systemData['systemHealthy'] ? 'HEALTHY' : 'WARNING',
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(10), // Slightly reduced padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Added to prevent overflow
        children: [
          Icon(icon, color: color, size: 22), // Slightly smaller icon
          const SizedBox(height: 6), // Reduced spacing
          Flexible(
            // Wrap text with Flexible
            child: Text(
              title,
              style: TextStyle(fontSize: 11, color: color),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            // Use FittedBox to scale down if needed
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13, // Slightly smaller
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10), // Slightly reduced padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Added to prevent overflow
        children: [
          Icon(icon, color: color, size: 22), // Slightly smaller icon
          const SizedBox(height: 6), // Reduced spacing
          Flexible(
            // Wrap text with Flexible
            child: Text(
              title,
              style: TextStyle(fontSize: 11, color: color),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            // Use FittedBox to scale down if needed
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13, // Slightly smaller
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceIndicator(String label, int distance, IconData icon) {
    Color color = _getDistanceColor(distance);

    return Container(
      padding: const EdgeInsets.all(10), // Slightly reduced padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Added to prevent overflow
        children: [
          Icon(icon, color: color, size: 22), // Slightly smaller icon
          const SizedBox(height: 6), // Reduced spacing
          Flexible(
            // Wrap text with Flexible
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: color),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            // Use FittedBox to scale down if needed
            child: Text(
              '${distance}cm',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotorSpeedIndicator(String label, int speed, IconData icon) {
    Color color = speed == 0
        ? Colors.grey
        : (speed > 0 ? Colors.green : Colors.blue);

    return Container(
      padding: const EdgeInsets.all(10), // Slightly reduced padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Added to prevent overflow
        children: [
          Icon(icon, color: color, size: 22), // Slightly smaller icon
          const SizedBox(height: 6), // Reduced spacing
          Flexible(
            // Wrap text with Flexible
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: color),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            // Use FittedBox to scale down if needed
            child: Text(
              '$speed',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServoTile(String label, int angle) {
    return Container(
      padding: const EdgeInsets.all(6), // Reduced padding for better fit
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // Added to prevent overflow
        children: [
          Flexible(
            // Wrap text with Flexible
            child: FittedBox(
              // Use FittedBox to scale down if needed
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.blue),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(height: 2), // Reduced spacing
          FittedBox(
            // Use FittedBox for angle text too
            child: Text(
              '$angle°',
              style: const TextStyle(
                fontSize: 12, // Slightly smaller
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
