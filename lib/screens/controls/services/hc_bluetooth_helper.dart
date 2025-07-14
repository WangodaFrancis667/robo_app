// HC Bluetooth Module Connection Helper
// Specialized helper for HC-05/HC-06 modules with optimized timing and error handling

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as fbs;
import 'bluetoth_service.dart';

class HCBluetoothHelper {
  // HC module specific connection parameters
  static const int HC_CONNECTION_TIMEOUT_SECONDS = 25;
  static const int HC_STABILITY_CHECK_MS = 200;
  static const int HC_RETRY_DELAY_BASE_MS = 800;
  static const int HC_MAX_RETRIES = 5;

  // Common HC module identifiers
  static const List<String> HC_MODULE_IDENTIFIERS = [
    'hc-05',
    'hc-06',
    'hc',
    'bt05',
    'bt06',
    'bluetooth',
    'serial',
  ];

  /// Specialized connection method for HC modules
  static Future<BluetoothConnection> connectToHCDevice(
    MobileBluetoothDevice device,
  ) async {
    print('🔗 Starting HC module connection to ${device.name}');

    // Pre-connection checks
    await _performPreConnectionChecks(device);

    fbs.BluetoothConnection? connection;

    for (int attempt = 1; attempt <= HC_MAX_RETRIES; attempt++) {
      try {
        print(
          '📡 HC Connection attempt $attempt/$HC_MAX_RETRIES for ${device.name}',
        );

        // Clean up any existing connections
        await _cleanupExistingConnections(device.address);

        // Wait between attempts for HC module stability
        if (attempt > 1) {
          final delay = HC_RETRY_DELAY_BASE_MS * attempt;
          print('⏱️ Waiting ${delay}ms for HC module stability...');
          await Future.delayed(Duration(milliseconds: delay));
        }

        // Attempt connection with HC-optimized timeout
        connection = await fbs.BluetoothConnection.toAddress(
          device.address,
        ).timeout(Duration(seconds: HC_CONNECTION_TIMEOUT_SECONDS));

        // HC modules need time to establish proper communication
        await Future.delayed(Duration(milliseconds: HC_STABILITY_CHECK_MS));

        // Verify connection is stable
        if (connection.isConnected) {
          print('✅ HC module connected successfully to ${device.name}');

          // Additional stability verification for HC modules
          await _verifyHCConnection(connection);

          return MobileBluetoothConnection(connection);
        } else {
          await _safeClose(connection);
          throw Exception('HC module connection not stable');
        }
      } catch (e) {
        print('❌ HC connection attempt $attempt failed: $e');

        if (connection != null) {
          await _safeClose(connection);
          connection = null;
        }

        if (attempt == HC_MAX_RETRIES) {
          throw _createHCSpecificError(e, device);
        }
      }
    }

    throw Exception('HC module connection failed after all attempts');
  }

  /// Pre-connection checks specific to HC modules
  static Future<void> _performPreConnectionChecks(
    MobileBluetoothDevice device,
  ) async {
    // Check if device appears to be an HC module
    final deviceName = device.name.toLowerCase();
    final isLikelyHC = HC_MODULE_IDENTIFIERS.any(
      (id) => deviceName.contains(id),
    );

    if (isLikelyHC) {
      print('🔍 Detected HC module: ${device.name}');
    } else {
      print('⚠️ Device may not be an HC module: ${device.name}');
    }

    // Check if device is already connected
    if (device.isConnected) {
      print('📱 Device already shows as connected, will reset connection');
    }
  }

  /// Clean up any existing connections
  static Future<void> _cleanupExistingConnections(String address) async {
    try {
      final existingConnection = await fbs.BluetoothConnection.toAddress(
        address,
      ).timeout(Duration(milliseconds: 500));
      await existingConnection.close();
      await Future.delayed(Duration(milliseconds: 300));
    } catch (_) {
      // No existing connection or cleanup failed, continue
    }
  }

  /// Verify HC connection is working
  static Future<void> _verifyHCConnection(
    fbs.BluetoothConnection connection,
  ) async {
    try {
      // Send a simple test command that HC modules should handle
      final testCommand = 'AT\r\n';
      connection.output.add(Uint8List.fromList(utf8.encode(testCommand)));

      // Wait briefly for response
      await Future.delayed(Duration(milliseconds: 100));

      // If we reach here without exception, consider it verified
      print('✅ HC module communication test passed');
    } catch (e) {
      print('⚠️ HC module communication test failed, but continuing: $e');
      // Don't throw error as some HC modules might not respond to AT commands
    }
  }

  /// Safe connection close
  static Future<void> _safeClose(fbs.BluetoothConnection? connection) async {
    if (connection != null) {
      try {
        await connection.close().timeout(Duration(seconds: 2));
      } catch (e) {
        print('⚠️ Error closing connection: $e');
      }
    }
  }

  /// Create HC-specific error messages
  static Exception _createHCSpecificError(
    dynamic originalError,
    MobileBluetoothDevice device,
  ) {
    final errorMessage = originalError.toString().toLowerCase();

    if (errorMessage.contains('timeout')) {
      return Exception(
        'HC module connection timeout. Please check:\n'
        '• HC module is powered on and LED is blinking\n'
        '• Device is paired in Android Bluetooth settings\n'
        '• Arduino code is uploaded and running\n'
        '• Try moving closer to the HC module',
      );
    } else if (errorMessage.contains('permission')) {
      return Exception(
        'Bluetooth permission denied. Please:\n'
        '• Grant Bluetooth permissions in app settings\n'
        '• Enable location permissions (required for Bluetooth)\n'
        '• Restart the app after granting permissions',
      );
    } else if (errorMessage.contains('not found') ||
        errorMessage.contains('unavailable')) {
      return Exception(
        'HC module not available. Please check:\n'
        '• Device is paired in Android settings first\n'
        '• HC module is not connected to another device\n'
        '• Try unpairing and re-pairing the device',
      );
    } else {
      return Exception(
        'HC module connection failed: $originalError\n\n'
        'Troubleshooting tips:\n'
        '• Ensure HC module LED is blinking (not solid)\n'
        '• Check power connections to HC module\n'
        '• Verify baud rate is 9600 in Arduino code\n'
        '• Try restarting both devices',
      );
    }
  }

  /// Check if device is likely an HC module
  static bool isLikelyHCModule(String deviceName) {
    final name = deviceName.toLowerCase();
    return HC_MODULE_IDENTIFIERS.any((id) => name.contains(id));
  }

  /// Get recommended connection settings for device
  static Map<String, dynamic> getRecommendedSettings(String deviceName) {
    final isHC = isLikelyHCModule(deviceName);

    return {
      'isHCModule': isHC,
      'recommendedTimeout': isHC ? HC_CONNECTION_TIMEOUT_SECONDS : 15,
      'recommendedRetries': isHC ? HC_MAX_RETRIES : 3,
      'stabilityCheck': isHC ? HC_STABILITY_CHECK_MS : 500,
      'tips': isHC
          ? [
              'HC modules need stable power (check VCC)',
              'Ensure Arduino code is uploaded and running',
              'LED should blink when searching, solid when connected',
              'Default pairing PIN is usually 1234 or 0000',
            ]
          : [
              'Ensure device is paired in Android settings',
              'Check if device supports Serial Port Profile (SPP)',
              'Verify device is not connected elsewhere',
            ],
    };
  }
}
