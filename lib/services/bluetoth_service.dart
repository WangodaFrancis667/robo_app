import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    as mobile;
import 'package:permission_handler/permission_handler.dart';

abstract class BluetoothDevice {
  String get name;
  String get address;
}

abstract class BluetoothConnection {
  Stream<Uint8List>? get input;
  void write(List<int> data);
  Future<void> close();
}

class MobileBluetoothDevice extends BluetoothDevice {
  final mobile.BluetoothDevice _device;

  MobileBluetoothDevice(this._device);

  @override
  String get name => _device.name ?? 'Unknown';

  @override
  String get address => _device.address;
}

class WindowsBluetoothDevice extends BluetoothDevice {
  final String _name;
  final String _address;

  WindowsBluetoothDevice(this._name, this._address);

  @override
  String get name => _name;

  @override
  String get address => _address;
}

class MobileBluetoothConnection extends BluetoothConnection {
  final mobile.BluetoothConnection _connection;

  MobileBluetoothConnection(this._connection);

  @override
  Stream<Uint8List>? get input => _connection.input;

  @override
  void write(List<int> data) {
    _connection.output.add(Uint8List.fromList(data));
  }

  @override
  Future<void> close() => _connection.close();
}

class WindowsBluetoothConnection extends BluetoothConnection {
  final StreamController<Uint8List> _inputController =
      StreamController<Uint8List>();
  final StreamController<String> _outputController = StreamController<String>();
  Process? _process;

  WindowsBluetoothConnection(String address);

  @override
  Stream<Uint8List>? get input => _inputController.stream;

  @override
  void write(List<int> data) {
    final command = utf8.decode(data);
    _outputController.sink.add(command);
    print('Windows Bluetooth TX: $command');
  }

  Future<void> _initialize(String address) async {
    try {
      // For demo purposes, we'll simulate a connection
      // In a real implementation, you'd use Windows Bluetooth APIs or PowerShell
      print('Simulating Windows Bluetooth connection to $address');

      // Simulate receiving some data
      Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_inputController.isClosed) {
          timer.cancel();
          return;
        }
        // Simulate receiving status data
        final data = utf8.encode('STATUS:OK\n');
        _inputController.add(Uint8List.fromList(data));
      });
    } catch (e) {
      print('Error initializing Windows Bluetooth connection: $e');
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    try {
      _process?.kill();
      await _inputController.close();
      await _outputController.close();
    } catch (e) {
      print('Error closing Windows Bluetooth connection: $e');
    }
  }
}

class CrossPlatformBluetoothService {
  static bool get isWindows => Platform.isWindows;
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static Future<bool> requestPermissions() async {
    if (isMobile) {
      Map<Permission, PermissionStatus> permissions = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();

      return permissions.values.every(
        (status) => status == PermissionStatus.granted,
      );
    } else if (isWindows) {
      // Windows doesn't require runtime permissions for Bluetooth
      return true;
    }
    return false;
  }

  static Future<bool> isBluetoothEnabled() async {
    if (isMobile) {
      return await mobile.FlutterBluetoothSerial.instance.isEnabled ?? false;
    } else if (isWindows) {
      // For Windows, we'll assume Bluetooth is available
      // In a real implementation, you'd check Windows Bluetooth status
      return true;
    }
    return false;
  }

  static Future<void> enableBluetooth() async {
    if (isMobile) {
      await mobile.FlutterBluetoothSerial.instance.requestEnable();
    } else if (isWindows) {
      // On Windows, show a message to enable Bluetooth manually
      throw Exception('Please enable Bluetooth in Windows Settings');
    }
  }

  static Future<List<BluetoothDevice>> getDevices() async {
    if (isMobile) {
      final devices = await mobile.FlutterBluetoothSerial.instance
          .getBondedDevices();
      return devices.map((d) => MobileBluetoothDevice(d)).toList();
    } else if (isWindows) {
      // For Windows, return some mock devices for demonstration
      // In a real implementation, you'd use Windows Bluetooth APIs
      return [
        WindowsBluetoothDevice('ESP32_Robot_Demo', '00:00:00:00:00:01'),
        WindowsBluetoothDevice('Arduino_Bot', '00:00:00:00:00:02'),
        WindowsBluetoothDevice('Test_Device', '00:00:00:00:00:03'),
      ];
    }
    return [];
  }

  static Future<BluetoothConnection> connectToDevice(
    BluetoothDevice device,
  ) async {
    if (isMobile && device is MobileBluetoothDevice) {
      try {
        // Try to connect with retry logic
        mobile.BluetoothConnection? connection;
        int retries = 3;

        for (int i = 0; i < retries; i++) {
          try {
            print(
              'Attempting connection to ${device.name} (attempt ${i + 1}/$retries)',
            );

            // Add a small delay between attempts
            if (i > 0) {
              await Future.delayed(Duration(seconds: 2));
            }

            connection = await mobile.BluetoothConnection.toAddress(
              device._device.address,
            );

            // Wait a moment to ensure connection is stable
            await Future.delayed(Duration(milliseconds: 500));

            // Test the connection by checking if it's still active
            if (connection.isConnected) {
              print('Successfully connected to ${device.name}');
              return MobileBluetoothConnection(connection);
            } else {
              print('Connection failed - not connected');
              await connection.close();
              connection = null;
            }
          } catch (e) {
            print('Connection attempt ${i + 1} failed: $e');
            if (connection != null) {
              try {
                await connection.close();
              } catch (_) {}
              connection = null;
            }

            if (i == retries - 1) {
              rethrow; // Re-throw on final attempt
            }
          }
        }

        throw Exception('Failed to connect after $retries attempts');
      } catch (e) {
        throw Exception('Bluetooth connection failed: $e');
      }
    } else if (isWindows && device is WindowsBluetoothDevice) {
      final connection = WindowsBluetoothConnection(device.address);
      await connection._initialize(device.address);
      return connection;
    }
    throw Exception('Unsupported platform or device type');
  }
}
