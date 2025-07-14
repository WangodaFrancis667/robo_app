import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    as mobile;
import 'package:permission_handler/permission_handler.dart';

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
        // For Android 12+ (API 31+)
        permissions = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.locationWhenInUse,
        ].request();
      } else {
        // For iOS
        permissions = await [
          Permission.bluetooth,
          Permission.locationWhenInUse,
        ].request();
      }

      bool allGranted = permissions.values.every(
        (status) => status == PermissionStatus.granted,
      );

      if (!allGranted) {
        print('⚠️ Some Bluetooth permissions were not granted');
        print('Permissions status: $permissions');
      }

      return allGranted;
    } catch (e) {
      print('❌ Error requesting Bluetooth permissions: $e');
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
        final devices = await mobile.FlutterBluetoothSerial.instance
            .getBondedDevices();
        print('📱 Found ${devices.length} bonded devices');

        return devices.map((d) => MobileBluetoothDevice(d)).toList();
      } catch (e) {
        print('❌ Error getting Bluetooth devices: $e');
        throw Exception('Failed to get Bluetooth devices: $e');
      }
    } else if (isWindows) {
      // Mock devices for Windows demo
      return [
        WindowsBluetoothDevice('ESP32_Robot_Demo', '00:11:22:33:44:55'),
        WindowsBluetoothDevice('Arduino_Mega', '00:11:22:33:44:56'),
        WindowsBluetoothDevice('Test_Device', '00:11:22:33:44:57'),
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
    const int maxRetries = 3;
    const Duration baseDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
          '🔗 Connecting to ${device.name} (${device.address}) - Attempt $attempt/$maxRetries',
        );

        // Close any existing connections first
        try {
          final existingConnection = await mobile.BluetoothConnection.toAddress(
            device.address,
          ).timeout(Duration(seconds: 1));
          await existingConnection.close();
          await Future.delayed(Duration(milliseconds: 500));
        } catch (_) {
          // No existing connection, continue
        }

        // Attempt connection with timeout
        final connection = await mobile.BluetoothConnection.toAddress(
          device.address,
        ).timeout(Duration(seconds: 15));

        // Verify connection is stable
        await Future.delayed(Duration(milliseconds: 1000));

        if (connection.isConnected) {
          print('✅ Successfully connected to ${device.name}');
          return MobileBluetoothConnection(connection);
        } else {
          await connection.close();
          throw Exception('Connection established but not stable');
        }
      } catch (e) {
        print('❌ Connection attempt $attempt failed: $e');

        if (attempt < maxRetries) {
          final delay = Duration(seconds: baseDelay.inSeconds * attempt);
          print('⏱️ Waiting ${delay.inSeconds}s before retry...');
          await Future.delayed(delay);
        } else {
          throw Exception('Failed to connect after $maxRetries attempts: $e');
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
