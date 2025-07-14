import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    as mobile;
import 'package:permission_handler/permission_handler.dart';
import 'hc_bluetooth_helper.dart';

// Abstract interfaces for cross-platform compatibility
abstract class BluetoothDevice {
  String get name;
  String get address;
  bool get isConnected;
}

abstract class BluetoothConnection {
  Stream<Uint8List>? get input;
  bool get isConnected;
  void write(List<int> data);
  Future<void> close();
}

// Mobile implementations
class MobileBluetoothDevice extends BluetoothDevice {
  final mobile.BluetoothDevice _device;

  MobileBluetoothDevice(this._device);

  @override
  String get name => _device.name ?? 'Unknown Device';

  @override
  String get address => _device.address;

  @override
  bool get isConnected => _device.isConnected;

  mobile.BluetoothDevice get mobileDevice => _device;
}

class MobileBluetoothConnection extends BluetoothConnection {
  final mobile.BluetoothConnection _connection;
  late StreamSubscription<Uint8List> _dataSubscription;
  final StreamController<Uint8List> _dataController =
      StreamController<Uint8List>.broadcast();
  bool _isConnected = true;

  MobileBluetoothConnection(this._connection) {
    // Listen to incoming data and relay it through our controller
    _dataSubscription = _connection.input!.listen(
      (data) {
        if (!_dataController.isClosed) {
          _dataController.add(data);
        }
      },
      onError: (error) {
        print('📡 Bluetooth connection error: $error');
        _isConnected = false;
        if (!_dataController.isClosed) {
          _dataController.addError(error);
        }
      },
      onDone: () {
        print('📡 Bluetooth connection closed');
        _isConnected = false;
        if (!_dataController.isClosed) {
          _dataController.close();
        }
      },
    );
  }

  @override
  Stream<Uint8List>? get input => _dataController.stream;

  @override
  bool get isConnected => _isConnected && _connection.isConnected;

  @override
  void write(List<int> data) {
    if (isConnected) {
      try {
        _connection.output.add(Uint8List.fromList(data));
      } catch (e) {
        print('📡 Error writing to Bluetooth: $e');
        _isConnected = false;
        rethrow;
      }
    } else {
      throw StateError('Bluetooth connection is not active');
    }
  }

  @override
  Future<void> close() async {
    _isConnected = false;
    try {
      await _dataSubscription.cancel();
      if (!_dataController.isClosed) {
        await _dataController.close();
      }
      await _connection.close();
    } catch (e) {
      print('📡 Error closing Bluetooth connection: $e');
    }
  }
}

// Windows implementations (simplified for demo)
class WindowsBluetoothDevice extends BluetoothDevice {
  final String _name;
  final String _address;

  WindowsBluetoothDevice(this._name, this._address);

  @override
  String get name => _name;

  @override
  String get address => _address;

  @override
  bool get isConnected => false; // Simplified for demo
}

class WindowsBluetoothConnection extends BluetoothConnection {
  final StreamController<Uint8List> _inputController =
      StreamController<Uint8List>.broadcast();
  bool _isConnected = false;

  WindowsBluetoothConnection(String address) {
    _initializeConnection(address);
  }

  @override
  Stream<Uint8List>? get input => _inputController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  void write(List<int> data) {
    final command = utf8.decode(data);
    print('Windows Bluetooth TX: $command');
    // Simulate response for demo
    if (command.trim() == 'PING') {
      Timer(Duration(milliseconds: 100), () {
        if (!_inputController.isClosed) {
          _inputController.add(Uint8List.fromList(utf8.encode('PONG\n')));
        }
      });
    }
  }

  Future<void> _initializeConnection(String address) async {
    try {
      print('🔗 Simulating Windows Bluetooth connection to $address');
      await Future.delayed(Duration(seconds: 1));
      _isConnected = true;

      // Simulate periodic data
      Timer.periodic(Duration(seconds: 10), (timer) {
        if (_inputController.isClosed) {
          timer.cancel();
          return;
        }
        _inputController.add(Uint8List.fromList(utf8.encode('STATUS:OK\n')));
      });
    } catch (e) {
      print('❌ Windows Bluetooth connection error: $e');
      _isConnected = false;
    }
  }

  @override
  Future<void> close() async {
    _isConnected = false;
    if (!_inputController.isClosed) {
      await _inputController.close();
    }
  }
}

// Main cross-platform service
class CrossPlatformBluetoothService {
  static bool get isWindows => Platform.isWindows;
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  // Permission handling
  static Future<bool> requestPermissions() async {
    if (!isMobile) return true;

    try {
      Map<Permission, PermissionStatus> permissions;

      // Different permission sets for different Android versions
      if (Platform.isAndroid) {
        // For Android 12+ (API 31+) - Request new Bluetooth permissions
        permissions = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.locationWhenInUse,
        ].request();

        // Check if any critical permissions are denied
        bool bluetoothConnectGranted =
            permissions[Permission.bluetoothConnect] ==
            PermissionStatus.granted;
        bool locationGranted =
            permissions[Permission.locationWhenInUse] ==
            PermissionStatus.granted;

        if (!bluetoothConnectGranted) {
          print(
            '❌ Bluetooth Connect permission is required for HC module connection',
          );
          return false;
        }

        if (!locationGranted) {
          print(
            '⚠️ Location permission helps with Bluetooth discovery but is not critical',
          );
        }

        // Check for legacy permissions on older Android versions
        if (!bluetoothConnectGranted) {
          final legacyPermissions = await [
            Permission.bluetooth,
            Permission.locationWhenInUse,
          ].request();

          bluetoothConnectGranted =
              legacyPermissions[Permission.bluetooth] ==
              PermissionStatus.granted;
        }

        return bluetoothConnectGranted;
      } else {
        // For iOS
        permissions = await [
          Permission.bluetooth,
          Permission.locationWhenInUse,
        ].request();

        bool allGranted = permissions.values.every(
          (status) => status == PermissionStatus.granted,
        );

        if (!allGranted) {
          print('⚠️ Some Bluetooth permissions were not granted');
          print('Permissions status: $permissions');
        }

        return allGranted;
      }
    } catch (e) {
      print('❌ Error requesting Bluetooth permissions: $e');
      print(
        'This might be due to Android version compatibility. Try manually enabling Bluetooth permissions in Settings.',
      );
      return false;
    }
  }

  // Bluetooth state management
  static Future<bool> isBluetoothEnabled() async {
    if (isMobile) {
      try {
        return await mobile.FlutterBluetoothSerial.instance.isEnabled ?? false;
      } catch (e) {
        print('❌ Error checking Bluetooth status: $e');
        return false;
      }
    } else if (isWindows) {
      return true; // Simplified for Windows
    }
    return false;
  }

  static Future<void> enableBluetooth() async {
    if (isMobile) {
      try {
        await mobile.FlutterBluetoothSerial.instance.requestEnable();
      } catch (e) {
        throw Exception('Failed to enable Bluetooth: $e');
      }
    } else if (isWindows) {
      throw Exception('Please enable Bluetooth in Windows Settings');
    }
  }

  // Device discovery
  static Future<List<BluetoothDevice>> getDevices() async {
    if (isMobile) {
      try {
        print('🔍 Getting bonded Bluetooth devices...');

        // First check if Bluetooth is enabled
        bool isEnabled = await isBluetoothEnabled();
        if (!isEnabled) {
          throw Exception(
            'Bluetooth is not enabled. Please enable Bluetooth and try again.',
          );
        }

        final devices = await mobile.FlutterBluetoothSerial.instance
            .getBondedDevices()
            .timeout(Duration(seconds: 10)); // Add timeout

        print('📱 Found ${devices.length} bonded devices');

        // Filter for devices that might be HC modules or robots
        final filteredDevices = devices.where((device) {
          final name = device.name?.toLowerCase() ?? '';
          final address = device.address.toLowerCase();

          // Look for common HC module names and robot-related names
          bool isLikelyRobotDevice =
              name.contains('hc-') ||
              name.contains('arduino') ||
              name.contains('esp32') ||
              name.contains('robot') ||
              name.contains('bt') ||
              address.startsWith('98:d3') || // Common HC-05 MAC prefix
              address.startsWith('00:18:e4'); // Another common HC MAC prefix

          return isLikelyRobotDevice ||
              name.isNotEmpty; // Include all named devices as fallback
        }).toList();

        print('🤖 Found ${filteredDevices.length} potential robot devices');
        return filteredDevices.map((d) => MobileBluetoothDevice(d)).toList();
      } catch (e) {
        print('❌ Error getting Bluetooth devices: $e');
        if (e.toString().contains('timeout')) {
          throw Exception(
            'Bluetooth device discovery timed out. Please try again or check if Bluetooth is working properly.',
          );
        }
        throw Exception('Failed to get Bluetooth devices: $e');
      }
    } else if (isWindows) {
      // Mock devices for Windows demo
      return [
        WindowsBluetoothDevice('HC-05 Robot', '98:D3:31:FB:4A:C1'),
        WindowsBluetoothDevice('HC-06 Controller', '98:D3:31:FB:4A:C2'),
        WindowsBluetoothDevice('ESP32_Robot', '24:0A:C4:12:34:56'),
        WindowsBluetoothDevice('Arduino_Robot', '00:18:E4:12:34:56'),
      ];
    }
    return [];
  }

  // Connection management
  static Future<BluetoothConnection> connectToDevice(
    BluetoothDevice device,
  ) async {
    if (isMobile && device is MobileBluetoothDevice) {
      return await _connectToMobileDevice(device);
    } else if (isWindows && device is WindowsBluetoothDevice) {
      return WindowsBluetoothConnection(device.address);
    }
    throw Exception('Unsupported platform or device type');
  }

  static Future<BluetoothConnection> _connectToMobileDevice(
    MobileBluetoothDevice device,
  ) async {
    // Check if device is likely an HC module and use specialized connection
    if (HCBluetoothHelper.isLikelyHCModule(device.name)) {
      print('🔍 Using HC-optimized connection for ${device.name}');
      return await HCBluetoothHelper.connectToHCDevice(device);
    }

    // Fallback to standard connection for other devices
    const int maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
          '🔗 Connecting to ${device.name} (${device.address}) - Attempt $attempt/$maxRetries',
        );

        // Clear any existing connections with shorter timeout
        try {
          await mobile.BluetoothConnection.toAddress(device.address)
              .timeout(Duration(milliseconds: 500))
              .then((conn) => conn.close())
              .catchError((_) => null);
        } catch (_) {
          // No existing connection or connection failed, continue
        }

        // Wait between attempts
        if (attempt > 1) {
          await Future.delayed(Duration(milliseconds: 1000));
        }

        // Attempt connection with reasonable timeout
        final connection = await mobile.BluetoothConnection.toAddress(
          device.address,
        ).timeout(Duration(seconds: 15));

        // Minimal stability check
        await Future.delayed(Duration(milliseconds: 200));

        if (connection.isConnected) {
          print('✅ Successfully connected to ${device.name}');

          // Additional stability check
          await Future.delayed(Duration(milliseconds: 300));
          if (connection.isConnected) {
            return MobileBluetoothConnection(connection);
          } else {
            await connection.close().catchError((_) => null);
            throw Exception('Connection became unstable');
          }
        } else {
          await connection.close().catchError((_) => null);
          throw Exception('Connection established but not active');
        }
      } catch (e) {
        print('❌ Connection attempt $attempt failed: $e');

        if (attempt < maxRetries) {
          final delay = Duration(milliseconds: 1000 + (attempt * 500));
          print('⏱️ Waiting ${delay.inMilliseconds}ms before retry...');
          await Future.delayed(delay);
        } else {
          throw Exception(
            'Failed to connect after $maxRetries attempts. Please check: 1) Device is powered on, 2) Bluetooth is enabled, 3) Device is paired in Android settings. Error: $e',
          );
        }
      }
    }

    throw Exception('Connection failed unexpectedly');
  }

  // Utility methods
  static Future<bool> isDeviceConnected(BluetoothDevice device) async {
    if (isMobile && device is MobileBluetoothDevice) {
      return device.mobileDevice.isConnected;
    }
    return false;
  }

  static Future<void> unpairDevice(BluetoothDevice device) async {
    if (isMobile && device is MobileBluetoothDevice) {
      // Note: Unpairing is not directly supported by flutter_bluetooth_serial
      // This would typically require platform-specific code
      throw UnimplementedError('Unpairing is not supported by this library');
    }
  }

  // Diagnostic methods
  static Future<Map<String, dynamic>> getDiagnosticInfo() async {
    final info = <String, dynamic>{};

    try {
      info['platform'] = Platform.operatingSystem;
      info['isBluetoothSupported'] = isMobile || isWindows;

      if (isMobile) {
        info['isBluetoothEnabled'] = await isBluetoothEnabled();
        info['bluetoothState'] =
            await mobile.FlutterBluetoothSerial.instance.state;
        info['deviceCount'] = (await getDevices()).length;
      }

      info['timestamp'] = DateTime.now().toIso8601String();
    } catch (e) {
      info['error'] = e.toString();
    }

    return info;
  }
}

// Connection state management helper
class BluetoothConnectionState {
  final bool isConnected;
  final bool isConnecting;
  final BluetoothDevice? connectedDevice;
  final String? errorMessage;
  final DateTime lastUpdate;

  const BluetoothConnectionState({
    this.isConnected = false,
    this.isConnecting = false,
    this.connectedDevice,
    this.errorMessage,
    required this.lastUpdate,
  });

  BluetoothConnectionState copyWith({
    bool? isConnected,
    bool? isConnecting,
    BluetoothDevice? connectedDevice,
    String? errorMessage,
    DateTime? lastUpdate,
  }) {
    return BluetoothConnectionState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      errorMessage: errorMessage ?? this.errorMessage,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  @override
  String toString() {
    return 'BluetoothConnectionState(isConnected: $isConnected, isConnecting: $isConnecting, device: ${connectedDevice?.name})';
  }
}
