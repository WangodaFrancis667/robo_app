import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Helper class for server validation
class _ServerValidationResult {
  final bool isValid;
  final String contentType;
  final bool isStreamContent;

  _ServerValidationResult({
    required this.isValid,
    required this.contentType,
    required this.isStreamContent,
  });
}

class VideoService {
  static const String _defaultRaspberryPiIP = '192.168.137.4';
  static const int _defaultPort = 8080;
  static const String _defaultEndpoint = 'my_mac_camera';

  final String raspberryPiIP;
  final int port;
  final String endpoint;

  // Video state management
  bool _isLoadingStream = false;
  String _errorMessage = '';
  bool _isStreamActive = false;
  Key _mjpegKey = UniqueKey();
  bool _isBluetoothPriority = false; // New flag for Bluetooth priority mode

  // Getters for state
  bool get isLoadingStream => _isLoadingStream;
  String get errorMessage => _errorMessage;
  bool get isStreamActive => _isStreamActive;
  Key get mjpegKey => _mjpegKey;

  VideoService({
    this.raspberryPiIP = _defaultRaspberryPiIP,
    this.port = _defaultPort,
    this.endpoint = _defaultEndpoint,
  });

  /// Get the complete stream URL
  String get streamUrl => 'http://$raspberryPiIP:$port/$endpoint';

  /// Set Bluetooth priority mode - when true, video operations are more conservative
  void setBluetoothPriorityMode(bool enabled) {
    _isBluetoothPriority = enabled;
    print(
      '🎥 Video service Bluetooth priority mode: ${enabled ? "ENABLED" : "DISABLED"}',
    );
  }

  /// Initialize video feed ONLY after Bluetooth is connected
  Future<VideoState> initializeVideoFeedAfterBluetooth() async {
    print('🎥 Initializing video feed after Bluetooth connection...');
    print('📍 Stream URL: $streamUrl');

    // Wait a moment to ensure Bluetooth connection is stable
    await Future.delayed(const Duration(seconds: 2));

    _isLoadingStream = true;
    _errorMessage = '';

    try {
      // Use conservative approach when Bluetooth is connected
      print('🔍 Testing video connectivity (Bluetooth priority mode)...');
      bool serverRunning = await _testConnectivityBluetoothSafe();

      if (serverRunning) {
        print('✅ Video server is accessible');
        _isLoadingStream = false;
        _isStreamActive = true;
        _errorMessage = '';
      } else {
        print('❌ Video server is not accessible');
        _isLoadingStream = false;
        _isStreamActive = false;
        _errorMessage =
            'Camera server not available.\n\n'
            'The robot is connected via Bluetooth, but the camera server\n'
            'at $streamUrl is not responding.\n\n'
            'This is normal if:\n'
            '• Camera server is on a different device\n'
            '• Camera server is not running\n'
            '• Network configuration is different';
      }
    } catch (e) {
      print('🚨 Video initialization error: $e');
      _isLoadingStream = false;
      _isStreamActive = false;
      _errorMessage = 'Video initialization failed: $e';
    }

    return VideoState(
      isLoading: _isLoadingStream,
      isActive: _isStreamActive,
      errorMessage: _errorMessage,
    );
  }

  /// Conservative connectivity test that won't interfere with Bluetooth
  Future<bool> _testConnectivityBluetoothSafe() async {
    try {
      print('🔍 Testing video connectivity (Bluetooth-safe mode)...');

      final client = http.Client();
      try {
        // Use shorter timeout to avoid interfering with Bluetooth
        final response = await client
            .get(Uri.parse(streamUrl))
            .timeout(const Duration(seconds: 3));

        print('📡 Video server response: ${response.statusCode}');
        return response.statusCode == 200;
      } finally {
        client.close();
      }
    } catch (e) {
      print('⚠️ Video connectivity test failed (this is normal): $e');
      return false;
    }
  }

  /// Quick refresh without aggressive network operations
  Future<VideoState> quickRefreshStream() async {
    print('🔄 Quick video stream refresh...');

    _mjpegKey = UniqueKey();

    // Don't do extensive network testing during refresh if Bluetooth is active
    if (_isBluetoothPriority) {
      _errorMessage = '';
      return VideoState(
        isLoading: false,
        isActive: _isStreamActive,
        errorMessage: '',
      );
    }

    // Do a quick test
    bool serverRunning = await _testConnectivityBluetoothSafe();
    _isStreamActive = serverRunning;
    _errorMessage = serverRunning ? '' : 'Camera server not responding';

    return VideoState(
      isLoading: false,
      isActive: _isStreamActive,
      errorMessage: _errorMessage,
    );
  }

  /// Original initialization method for when Bluetooth is NOT connected
  Future<VideoState> initializeVideoFeed() async {
    print('🎥 Initializing video feed (no Bluetooth constraint)...');
    print('📍 Stream URL: $streamUrl');

    _isLoadingStream = true;
    _errorMessage = '';

    try {
      // Test direct connectivity first
      print('🔍 Testing direct stream connectivity...');
      bool serverRunning = await testConnectivity();

      if (!serverRunning) {
        print('⚠️ Direct stream failed, testing base server...');
        serverRunning = await testAlternativeConnectivity();
      }

      if (serverRunning) {
        print('✅ Video server is accessible');
        _isLoadingStream = false;
        _isStreamActive = true;
        _errorMessage = '';
      } else {
        print('❌ Video server is not accessible');
        _isLoadingStream = false;
        _isStreamActive = false;
        _errorMessage =
            'Camera server not available at $streamUrl\n\n'
            'Troubleshooting:\n'
            '1. Check if camera server is running\n'
            '2. Verify IP address: $raspberryPiIP\n'
            '3. Check network connection\n'
            '4. Ensure port $port is open';
      }
    } catch (e) {
      print('🚨 Video initialization error: $e');
      _isLoadingStream = false;
      _isStreamActive = false;
      _errorMessage = 'Failed to initialize video feed: $e';
    }

    return VideoState(
      isLoading: _isLoadingStream,
      isActive: _isStreamActive,
      errorMessage: _errorMessage,
    );
  }

  /// Test connectivity to the video server
  Future<bool> testConnectivity() async {
    const maxAttempts = 2;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        print('🔍 Testing video connectivity (attempt $attempt/$maxAttempts)');

        final client = http.Client();
        try {
          final response = await client
              .get(Uri.parse(streamUrl))
              .timeout(const Duration(seconds: 5));

          print('📡 Video server response: ${response.statusCode}');

          if (response.statusCode == 200) {
            print('✅ Video server is accessible');
            return true;
          } else {
            print('⚠️ Video server returned status: ${response.statusCode}');
          }
        } finally {
          client.close();
        }
      } catch (e) {
        print('❌ Video connectivity test error: $e');
      }

      if (attempt < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    return false;
  }

  /// Test alternative connectivity method
  Future<bool> testAlternativeConnectivity() async {
    try {
      print('🔍 Testing alternative connectivity to base URL...');

      final client = http.Client();
      try {
        final baseUrl = 'http://$raspberryPiIP:$port';
        print('📡 Testing base URL: $baseUrl');

        final response = await client
            .get(Uri.parse(baseUrl))
            .timeout(const Duration(seconds: 4));

        print('📡 Base server response: ${response.statusCode}');

        bool serverRunning =
            response.statusCode == 200 ||
            response.statusCode == 404 ||
            response.statusCode == 302;

        if (serverRunning) {
          print('✅ Base server is running');
          return true;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Alternative connectivity test error: $e');
    }

    return false;
  }

  /// Create video service with custom configuration
  static VideoService createCustom({
    required String ip,
    int port = _defaultPort,
    String endpoint = _defaultEndpoint,
  }) {
    return VideoService(raspberryPiIP: ip, port: port, endpoint: endpoint);
  }

  /// Create video service from discovered camera server
  VideoService createFromDiscoveredServer(CameraServer server) {
    print('🔄 Creating video service from discovered server: ${server.url}');

    return VideoService(
      raspberryPiIP: server.ip,
      port: server.port,
      endpoint: server.endpoint,
    );
  }

  /// Get basic diagnostic information without intensive network operations
  Future<Map<String, dynamic>> getBasicDiagnostics() async {
    final diagnostics = <String, dynamic>{};

    try {
      diagnostics['streamUrl'] = streamUrl;
      diagnostics['isBluetoothPriority'] = _isBluetoothPriority;
      diagnostics['isStreamActive'] = _isStreamActive;
      diagnostics['errorMessage'] = _errorMessage;

      // Only do network test if not in Bluetooth priority mode
      if (!_isBluetoothPriority) {
        final client = http.Client();
        try {
          final response = await client
              .get(Uri.parse(streamUrl))
              .timeout(const Duration(seconds: 2));
          diagnostics['serverReachable'] = response.statusCode == 200;
          diagnostics['serverStatus'] = response.statusCode;
        } catch (e) {
          diagnostics['serverReachable'] = false;
          diagnostics['serverError'] = e.toString();
        } finally {
          client.close();
        }
      } else {
        diagnostics['serverReachable'] = 'Skipped (Bluetooth priority)';
      }

      diagnostics['timestamp'] = DateTime.now().toIso8601String();
    } catch (e) {
      diagnostics['error'] = e.toString();
    }

    return diagnostics;
  }

  /// Refresh video stream
  VideoState refreshVideoStream() {
    _mjpegKey = UniqueKey();
    _errorMessage = '';
    // Return current state for immediate UI update,
    // actual connectivity will be tested with initializeVideoFeed
    return VideoState(
      isLoading: false,
      isActive: _isStreamActive,
      errorMessage: '',
    );
  }

  /// Initialize video feed with auto-discovery fallback
  /// This is a simplified version of initializeVideoFeedWithDiscovery that just calls
  /// the standard initializeVideoFeed method for compatibility
  Future<VideoState> initializeVideoFeedWithDiscovery() async {
    print(
      '🔍 Initializing video feed with auto-discovery (compatibility mode)...',
    );
    // Just use the regular initialization for simplicity
    return await initializeVideoFeed();
  }

  /// Perform auto-discovery to find camera servers on the network
  Future<DiscoveryResult> performAutoDiscovery() async {
    print('🔍 Starting auto-discovery for camera servers...');
    _isLoadingStream = true;

    try {
      // Simulated discovery for common addresses
      List<String> commonIPs = [
        raspberryPiIP, // Try the current IP first
        '192.168.137.4',
        '192.168.137.1',
        '192.168.0.1',
        '192.168.1.1',
        '192.168.1.100',
        '192.168.1.101',
        '192.168.1.102',
        '10.0.0.1',
        '10.0.0.2',
        '127.0.0.1', // Localhost
      ];

      List<int> commonPorts = [8080, 8000, 5000, 80];
      List<String> commonEndpoints = [
        'my_mac_camera',
        'video',
        'stream',
        'mjpeg',
        'camera',
      ];

      List<CameraServer> discoveredServers = [];
      CameraServer? bestServer;
      int highestConfidence = 0; // Try current configuration first
      String currentUrl = 'http://$raspberryPiIP:$port/$endpoint';

      // Check if current configuration is valid
      final currentServerValidation = await _testServerConnectivity(currentUrl);
      if (currentServerValidation.isValid) {
        final updatedCurrentServer = CameraServer(
          ip: raspberryPiIP,
          port: port,
          endpoint: endpoint,
          url: currentUrl,
          confidence: 10,
          isPiDevice: true,
          contentType: currentServerValidation.contentType,
        );
        discoveredServers.add(updatedCurrentServer);
        bestServer = updatedCurrentServer;
        highestConfidence = updatedCurrentServer.confidence;
      }

      // Quick scan for other potential servers
      for (var ip in commonIPs) {
        if (ip == raspberryPiIP) continue; // Skip already tested IP

        // Test if host is reachable
        bool hostReachable = await _isHostReachable(ip);
        if (!hostReachable) continue;

        // If host is reachable, try common port/endpoint combinations
        for (var serverPort in commonPorts) {
          for (var serverEndpoint in commonEndpoints) {
            final url = 'http://$ip:$serverPort/$serverEndpoint';

            // Check if the device is likely a Raspberry Pi
            bool isProbablyPi =
                ip.startsWith('192.168.1.') || ip.startsWith('192.168.137.');

            // Base confidence level
            int serverConfidence = isProbablyPi ? 8 : 5;

            final serverValidation = await _testServerConnectivity(url);
            if (serverValidation.isValid) {
              final server = CameraServer(
                ip: ip,
                port: serverPort,
                endpoint: serverEndpoint,
                url: url,
                confidence:
                    serverConfidence +
                    (serverValidation.isStreamContent ? 2 : 0),
                isPiDevice: isProbablyPi,
                contentType: serverValidation.contentType,
              );

              discoveredServers.add(server);

              // Update best server if confidence is higher
              if (server.confidence > highestConfidence) {
                highestConfidence = server.confidence;
                bestServer = server;
              }
            }
          }
        }
      }

      _isLoadingStream = false;

      // Return discovery result
      return DiscoveryResult(
        cameraServers: discoveredServers,
        isSuccessful: discoveredServers.isNotEmpty,
        bestServer: bestServer,
        errorMessage: discoveredServers.isEmpty
            ? 'No camera servers found'
            : null,
      );
    } catch (e) {
      print('❌ Auto-discovery error: $e');
      _isLoadingStream = false;
      return DiscoveryResult(
        cameraServers: [],
        isSuccessful: false,
        errorMessage: 'Error during discovery: $e',
      );
    }
  }

  /// Test if a host is reachable
  Future<bool> _isHostReachable(String ip) async {
    try {
      final client = http.Client();
      try {
        await client
            .get(Uri.parse('http://$ip'))
            .timeout(const Duration(seconds: 1));
        return true;
      } catch (_) {
        // Try another common port if initial attempt fails
        try {
          await client
              .get(Uri.parse('http://$ip:8080'))
              .timeout(const Duration(milliseconds: 800));
          return true;
        } catch (_) {
          return false;
        }
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Test if a URL is a valid camera server
  /// Returns a validation result with content type information
  Future<_ServerValidationResult> _testServerConnectivity(String url) async {
    try {
      final client = http.Client();
      try {
        final response = await client
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          String contentType = response.headers['content-type'] ?? '';
          bool isStreamContent =
              contentType.contains('image') ||
              contentType.contains('video') ||
              contentType.contains('stream') ||
              contentType.contains('mjpeg');

          return _ServerValidationResult(
            isValid: true,
            contentType: contentType,
            isStreamContent: isStreamContent,
          );
        }
        return _ServerValidationResult(
          isValid: false,
          contentType: 'unknown',
          isStreamContent: false,
        );
      } finally {
        client.close();
      }
    } catch (_) {
      return _ServerValidationResult(
        isValid: false,
        contentType: 'unknown',
        isStreamContent: false,
      );
    }
  }

  // End of VideoService class
}

/// Video state data class
class VideoState {
  final bool isLoading;
  final bool isActive;
  final String errorMessage;

  const VideoState({
    required this.isLoading,
    required this.isActive,
    required this.errorMessage,
  });

  @override
  String toString() {
    return 'VideoState(isLoading: $isLoading, isActive: $isActive, error: "$errorMessage")';
  }
}

/// Camera server data class for discovery
class CameraServer {
  final String ip;
  final int port;
  final String endpoint;
  final String url;
  final String contentType;
  final int confidence;
  final bool isPiDevice;

  const CameraServer({
    required this.ip,
    required this.port,
    required this.endpoint,
    required this.url,
    required this.contentType,
    required this.confidence,
    required this.isPiDevice,
  });

  @override
  String toString() {
    return 'CameraServer(ip: $ip, port: $port, endpoint: $endpoint, confidence: $confidence)';
  }
}

/// Video service factory for different scenarios
class VideoServiceFactory {
  /// Create video service for Bluetooth-first scenario
  static VideoService createForBluetoothMode({
    String ip = '192.168.137.4',
    int port = 8080,
    String endpoint = 'my_mac_camera',
  }) {
    final service = VideoService(
      raspberryPiIP: ip,
      port: port,
      endpoint: endpoint,
    );
    service.setBluetoothPriorityMode(true);
    return service;
  }

  /// Create video service for standalone mode
  static VideoService createForStandaloneMode({
    String ip = '192.168.137.4',
    int port = 8080,
    String endpoint = 'my_mac_camera',
  }) {
    final service = VideoService(
      raspberryPiIP: ip,
      port: port,
      endpoint: endpoint,
    );
    service.setBluetoothPriorityMode(false);
    return service;
  }
}

/// Discovery result data class
class DiscoveryResult {
  final List<CameraServer> cameraServers;
  final bool isSuccessful;
  final CameraServer? bestServer;
  final String? errorMessage;

  const DiscoveryResult({
    required this.cameraServers,
    required this.isSuccessful,
    this.bestServer,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'DiscoveryResult(successful: $isSuccessful, servers: $cameraServers, bestServer: $bestServer, error: $errorMessage)';
  }
}
