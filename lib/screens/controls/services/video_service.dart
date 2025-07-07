import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VideoService {
  static const String _defaultRaspberryPiIP = '192.168.137.4'; //'192.168.1.8';
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

  /// Initialize video feed with state management
  Future<VideoState> initializeVideoFeed() async {
    print('🎥 Initializing video feed...');
    print('📍 Stream URL: $streamUrl');

    _isLoadingStream = true;
    _errorMessage = '';

    try {
      // First test direct connectivity to the stream
      print('🔍 Testing direct stream connectivity...');
      bool serverRunning = await testConnectivity();

      if (!serverRunning) {
        print('⚠️  Direct stream failed, testing base server...');
        // If direct stream fails, test base server
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
      _errorMessage =
          'Failed to initialize video feed: $e\n\n'
          'Please check:\n'
          '- Network connectivity\n'
          '- Camera server status\n'
          '- IP address configuration';
    }

    return VideoState(
      isLoading: _isLoadingStream,
      isActive: _isStreamActive,
      errorMessage: _errorMessage,
    );
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

  /// Test connectivity to the video server
  Future<bool> testConnectivity() async {
    try {
      print('🔍 Testing video connectivity to: $streamUrl');
      final client = http.Client();
      try {
        final response = await client
            .get(Uri.parse(streamUrl))
            .timeout(const Duration(seconds: 8));

        print('📡 Video server response: ${response.statusCode}');

        if (response.statusCode == 200) {
          print('✅ Video server is accessible');
          return true;
        } else {
          print('⚠️  Video server returned status: ${response.statusCode}');
          return false;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Video connectivity test failed: $e');
      return false;
    }
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
            .timeout(const Duration(seconds: 8));

        print('📡 Base server response: ${response.statusCode}');

        bool serverRunning =
            response.statusCode == 200 ||
            response.statusCode == 404 ||
            response.statusCode == 302;

        if (serverRunning) {
          print('✅ Base server is running');
        } else {
          print('❌ Base server not accessible');
        }

        return serverRunning;
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Alternative video connectivity test failed: $e');
      return false;
    }
  }

  /// Get network diagnostic information
  Future<NetworkDiagnostics> getNetworkDiagnostics() async {
    print('🔍 Running network diagnostics...');

    final diagnostics = NetworkDiagnostics();

    // Test base server connectivity
    try {
      final baseUrl = 'http://$raspberryPiIP:$port';
      final client = http.Client();
      final response = await client
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));

      diagnostics.baseServerAccessible = response.statusCode < 500;
      diagnostics.baseServerStatus = response.statusCode;
      client.close();
    } catch (e) {
      diagnostics.baseServerAccessible = false;
      diagnostics.baseServerError = e.toString();
    }

    // Test stream endpoint
    try {
      final client = http.Client();
      final response = await client
          .get(Uri.parse(streamUrl))
          .timeout(const Duration(seconds: 5));

      diagnostics.streamEndpointAccessible = response.statusCode == 200;
      diagnostics.streamEndpointStatus = response.statusCode;
      client.close();
    } catch (e) {
      diagnostics.streamEndpointAccessible = false;
      diagnostics.streamEndpointError = e.toString();
    }

    return diagnostics;
  }

  /// Test multiple common IP addresses for the camera server
  Future<List<String>> scanForCameraServer() async {
    print('🔍 Scanning for camera server...');

    final List<String> foundServers = [];

    // Common IP patterns for local networks
    final List<String> ipPatterns = [
      '192.168.1.8', // Current default
      '192.168.0.8', // Alternative subnet
      '192.168.1.100', // Alternative IP
      '192.168.0.100', // Alternative IP
      '10.0.0.8', // Alternative private network
      '172.16.0.8', // Alternative private network
    ];

    for (final ip in ipPatterns) {
      try {
        final testUrl = 'http://$ip:$port/$endpoint';
        final client = http.Client();
        final response = await client
            .get(Uri.parse(testUrl))
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          foundServers.add(ip);
          print('✅ Found camera server at: $ip');
        }

        client.close();
      } catch (e) {
        // Server not found at this IP, continue scanning
      }
    }

    return foundServers;
  }

  /// Auto-discover camera servers on the network
  Future<List<CameraServer>> autoDiscoverCameraServers() async {
    print('🚀 Auto-discovering camera servers...');

    final List<CameraServer> foundServers = [];

    // Get local network base
    List<String> networkBases;
    try {
      networkBases = await _getLocalNetworkRanges();
      if (networkBases.isEmpty) {
        networkBases = ['192.168.1', '192.168.0', '10.0.0', '172.16.0'];
      }
    } catch (e) {
      print('⚠️  Could not determine local network: $e');
      networkBases = [
        '192.168.1',
        '192.168.0',
        '192.168.137.0',
        '192.168.137.4',
        '192.168.137.1',
        '10.0.0',
        '172.16.0',
      ];
    }

    // Step 1: Find active hosts
    final List<String> activeHosts = [];
    for (final networkBase in networkBases) {
      final hosts = await _pingSweep(networkBase);
      activeHosts.addAll(hosts);
    }

    if (activeHosts.isEmpty) {
      print('❌ No active hosts found on the network');
      return foundServers;
    }

    print('✅ Found ${activeHosts.length} active hosts');

    // Step 2: Identify potential Raspberry Pi devices
    final List<RaspberryPiDevice> piDevices = await _scanForRaspberryPiDevices(
      activeHosts,
    );

    // Step 3: Scan Pi devices for camera servers
    final List<CameraServer> piCameraServers = await _scanRaspberryPiForCameras(
      piDevices,
    );
    foundServers.addAll(piCameraServers);

    // Step 4: If no Pi devices found, scan all active hosts
    if (piDevices.isEmpty) {
      print(
        '⚠️  No Raspberry Pi devices detected, scanning all active hosts...',
      );
      final List<CameraServer> allHostCameras = await _scanAllHostsForCameras(
        activeHosts,
      );
      foundServers.addAll(allHostCameras);
    }

    // Sort by confidence (Pi devices first, then by other factors)
    foundServers.sort((a, b) => b.confidence.compareTo(a.confidence));

    return foundServers;
  }

  /// Ping sweep to find active hosts
  Future<List<String>> _pingSweep(String networkBase) async {
    print('🔍 Ping sweep: $networkBase.1-254');
    final List<String> activeHosts = [];

    // Common host numbers to scan first (more likely to be servers)
    final List<int> priorityHosts = [
      1,
      8,
      100,
      101,
      102,
      103,
      104,
      105,
      200,
      201,
      202,
    ];
    final List<int> allHosts = List.generate(254, (index) => index + 1);

    // Combine priority hosts with all hosts, removing duplicates
    final Set<int> hostSet = {...priorityHosts, ...allHosts};
    final List<int> hostsToScan = hostSet.toList();

    final List<Future<String?>> futures = [];

    for (final hostNum in hostsToScan.take(50)) {
      // Limit to 50 hosts for performance
      futures.add(_testHostConnectivity('$networkBase.$hostNum'));
    }

    final results = await Future.wait(futures);

    for (final result in results) {
      if (result != null) {
        activeHosts.add(result);
        print('   ✅ Host alive: $result');
      }
    }

    return activeHosts;
  }

  /// Test if a host is active
  Future<String?> _testHostConnectivity(String ip) async {
    try {
      final client = http.Client();
      // Quick test with short timeout
      await client
          .get(Uri.parse('http://$ip'))
          .timeout(const Duration(seconds: 1));

      client.close();
      return ip; // Host is responsive
    } catch (e) {
      return null; // Host is not responsive
    }
  }

  /// Scan active hosts for Raspberry Pi devices
  Future<List<RaspberryPiDevice>> _scanForRaspberryPiDevices(
    List<String> activeHosts,
  ) async {
    print('🔍 Scanning for Raspberry Pi devices...');
    final List<RaspberryPiDevice> piDevices = [];

    final List<Future<RaspberryPiDevice?>> futures = [];

    for (final ip in activeHosts) {
      futures.add(_checkRaspberryPiDevice(ip));
    }

    final results = await Future.wait(futures);

    for (final result in results) {
      if (result != null) {
        piDevices.add(result);
        print(
          '   🍓 Potential Raspberry Pi: ${result.ip} (${result.indicators.join(", ")})',
        );
      }
    }

    return piDevices;
  }

  /// Check if a host is likely a Raspberry Pi
  Future<RaspberryPiDevice?> _checkRaspberryPiDevice(String ip) async {
    final List<String> indicators = [];

    // Common Raspberry Pi ports
    final Map<int, String> testPorts = {
      22: 'SSH',
      80: 'HTTP',
      8080: 'Camera',
      5900: 'VNC',
    };

    // Test each port
    for (final entry in testPorts.entries) {
      if (await _testPortConnectivity(ip, entry.key)) {
        indicators.add(entry.value);
      }
    }

    if (indicators.isNotEmpty) {
      return RaspberryPiDevice(
        ip: ip,
        indicators: indicators,
        confidence: indicators.length,
      );
    }

    return null;
  }

  /// Test if a specific port is open
  Future<bool> _testPortConnectivity(String ip, int port) async {
    try {
      final client = http.Client();
      await client
          .get(Uri.parse('http://$ip:$port'))
          .timeout(const Duration(seconds: 2));

      client.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Scan Raspberry Pi devices for camera servers
  Future<List<CameraServer>> _scanRaspberryPiForCameras(
    List<RaspberryPiDevice> piDevices,
  ) async {
    print('🔍 Scanning Raspberry Pi devices for camera servers...');
    final List<CameraServer> cameraServers = [];

    final List<int> cameraPorts = [8080, 8081, 8000, 5000, 80];
    final List<String> cameraEndpoints = [
      'my_mac_camera',
      'video',
      'stream',
      'camera',
      'mjpeg',
      'feed',
      'cam',
      'webcam',
    ];

    for (final piDevice in piDevices) {
      print('   🔍 Scanning ${piDevice.ip} for camera servers...');

      for (final port in cameraPorts) {
        for (final endpoint in cameraEndpoints) {
          final testUrl = 'http://${piDevice.ip}:$port/$endpoint';

          try {
            final client = http.Client();
            final response = await client
                .get(Uri.parse(testUrl))
                .timeout(const Duration(seconds: 3));

            if (response.statusCode == 200) {
              final contentType = response.headers['content-type'] ?? '';

              // Check if this looks like a video stream
              if (contentType.contains('image') ||
                  contentType.contains('video') ||
                  contentType.contains('stream') ||
                  contentType.contains('mjpeg')) {
                cameraServers.add(
                  CameraServer(
                    ip: piDevice.ip,
                    port: port,
                    endpoint: endpoint,
                    url: testUrl,
                    contentType: contentType,
                    confidence: piDevice.confidence + 10, // Bonus for Pi device
                    isPiDevice: true,
                  ),
                );

                print(
                  '   📹 Found camera server: $testUrl (Type: $contentType)',
                );
              }
            }

            client.close();
          } catch (e) {
            // Server not found at this configuration, continue
          }
        }
      }
    }

    return cameraServers;
  }

  /// Scan all hosts for camera servers (fallback)
  Future<List<CameraServer>> _scanAllHostsForCameras(
    List<String> activeHosts,
  ) async {
    final List<CameraServer> cameraServers = [];

    final List<int> cameraPorts = [8080, 8081, 8000, 5000];
    final List<String> cameraEndpoints = [
      'my_mac_camera',
      'video',
      'stream',
      'camera',
    ];

    for (final ip in activeHosts) {
      for (final port in cameraPorts) {
        for (final endpoint in cameraEndpoints) {
          final testUrl = 'http://$ip:$port/$endpoint';

          try {
            final client = http.Client();
            final response = await client
                .get(Uri.parse(testUrl))
                .timeout(const Duration(seconds: 2));

            if (response.statusCode == 200) {
              final contentType = response.headers['content-type'] ?? '';

              if (contentType.contains('image') ||
                  contentType.contains('video') ||
                  contentType.contains('stream') ||
                  contentType.contains('mjpeg')) {
                cameraServers.add(
                  CameraServer(
                    ip: ip,
                    port: port,
                    endpoint: endpoint,
                    url: testUrl,
                    contentType: contentType,
                    confidence: 1, // Lower confidence for non-Pi devices
                    isPiDevice: false,
                  ),
                );

                print(
                  '   📹 Found camera server: $testUrl (Type: $contentType)',
                );
              }
            }

            client.close();
          } catch (e) {
            // Server not found, continue
          }
        }
      }
    }

    return cameraServers;
  }

  /// Get local network ranges for scanning
  Future<List<String>> _getLocalNetworkRanges() async {
    final List<String> networks = [];

    try {
      // This is a simplified approach - in a real app you might want to use
      // a more sophisticated network discovery library
      final client = http.Client();

      // Try to determine local network by testing common gateways
      final List<String> commonGateways = [
        '192.168.1.1',
        '192.168.0.1',
        '10.0.0.1',
        '172.16.0.1',
      ];

      for (final gateway in commonGateways) {
        try {
          final response = await client
              .get(Uri.parse('http://$gateway'))
              .timeout(const Duration(seconds: 2));

          if (response.statusCode < 500) {
            // Gateway is accessible, add this network range
            final baseParts = gateway.split('.');
            final networkBase =
                '${baseParts[0]}.${baseParts[1]}.${baseParts[2]}';
            networks.add(networkBase);
            print('✅ Detected network: $networkBase.x');
          }
        } catch (e) {
          // Gateway not accessible, continue
        }
      }

      client.close();
    } catch (e) {
      print('⚠️  Network detection failed: $e');
    }

    return networks;
  }

  /// Create video service with custom configuration
  static VideoService createCustom({
    required String ip,
    int port = _defaultPort,
    String endpoint = _defaultEndpoint,
  }) {
    return VideoService(raspberryPiIP: ip, port: port, endpoint: endpoint);
  }

  /// Update video service configuration with discovered server
  VideoService updateWithDiscoveredServer(String discoveredUrl) {
    try {
      final uri = Uri.parse(discoveredUrl);
      final host = uri.host;
      final port = uri.port;
      final endpoint = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : _defaultEndpoint;

      print('🔄 Updating video service configuration:');
      print('   Host: $host');
      print('   Port: $port');
      print('   Endpoint: $endpoint');

      return VideoService(raspberryPiIP: host, port: port, endpoint: endpoint);
    } catch (e) {
      print('❌ Failed to parse discovered URL: $e');
      return this;
    }
  }

  /// Initialize video feed with auto-discovery fallback
  Future<VideoState> initializeVideoFeedWithDiscovery() async {
    print('🎥 Initializing video feed with auto-discovery...');

    // Always try auto-discovery first to handle network changes
    print('🔍 Starting auto-discovery for network changes...');

    final discoveryResult = await performAutoDiscovery();

    if (discoveryResult.isSuccessful && discoveryResult.bestServer != null) {
      print('✅ Auto-discovery successful');

      // Update configuration with discovered server
      final bestServer = discoveryResult.bestServer!;
      print('🎯 Using discovered server: ${bestServer.url}');

      // Test the discovered server
      try {
        final client = http.Client();
        final response = await client
            .get(Uri.parse(bestServer.url))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          print('✅ Discovered server is working: ${bestServer.url}');

          // Update state and return success
          _isLoadingStream = false;
          _isStreamActive = true;
          _errorMessage = '';

          client.close();
          return VideoState(isLoading: false, isActive: true, errorMessage: '');
        }

        client.close();
      } catch (e) {
        print('❌ Discovered server failed: $e');
      }
    }

    // If auto-discovery fails, try the configured server as fallback
    print('⚠️  Auto-discovery failed, trying configured server...');
    final initialState = await initializeVideoFeed();

    if (initialState.isActive) {
      print('✅ Configured video server is working');
      return initialState;
    }

    // All attempts failed
    print('❌ Auto-discovery failed to find working camera servers');
    final errorMsg = discoveryResult.errorMessage ?? 'No camera servers found';

    return VideoState(
      isLoading: false,
      isActive: false,
      errorMessage:
          'Auto-discovery failed: $errorMsg\n\n'
          'Attempted:\n'
          '• Configured server: $streamUrl\n'
          '• Auto-discovery: ${discoveryResult.cameraServers.length} servers found\n\n'
          'Please ensure camera server is running and accessible.',
    );
  }

  /// Perform auto-discovery and return structured result
  Future<DiscoveryResult> performAutoDiscovery() async {
    try {
      final cameraServers = await autoDiscoverCameraServers();

      if (cameraServers.isEmpty) {
        return DiscoveryResult(
          cameraServers: [],
          isSuccessful: false,
          errorMessage: 'No camera servers found on the network',
        );
      }

      // Find the best server (highest confidence)
      final bestServer = cameraServers.reduce(
        (a, b) => a.confidence > b.confidence ? a : b,
      );

      return DiscoveryResult(
        cameraServers: cameraServers,
        isSuccessful: true,
        bestServer: bestServer,
      );
    } catch (e) {
      return DiscoveryResult(
        cameraServers: [],
        isSuccessful: false,
        errorMessage: 'Auto-discovery failed: $e',
      );
    }
  }

  /// Create video service with discovered camera server
  VideoService createFromDiscoveredServer(CameraServer server) {
    print('🔄 Creating video service from discovered server: ${server.url}');

    return VideoService(
      raspberryPiIP: server.ip,
      port: server.port,
      endpoint: server.endpoint,
    );
  }

  /// Diagnostic method to test network connectivity
  Future<Map<String, dynamic>> runNetworkDiagnostics() async {
    print('🔍 Running network diagnostics...');

    final diagnostics = <String, dynamic>{};

    try {
      // Test internet connectivity
      final client = http.Client();
      final response = await client
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));

      diagnostics['internet'] = response.statusCode == 200;
      client.close();
    } catch (e) {
      diagnostics['internet'] = false;
      diagnostics['internetError'] = e.toString();
    }

    // Test configured camera server
    try {
      final client = http.Client();
      final response = await client
          .get(Uri.parse(streamUrl))
          .timeout(const Duration(seconds: 5));

      diagnostics['configuredServer'] = response.statusCode == 200;
      client.close();
    } catch (e) {
      diagnostics['configuredServer'] = false;
      diagnostics['configuredServerError'] = e.toString();
    }

    // Test auto-discovery
    try {
      final discoveryResult = await performAutoDiscovery();
      diagnostics['autoDiscovery'] = discoveryResult.isSuccessful;
      diagnostics['discoveredServers'] = discoveryResult.cameraServers.length;

      if (discoveryResult.bestServer != null) {
        diagnostics['bestServer'] = discoveryResult.bestServer!.url;
      }
    } catch (e) {
      diagnostics['autoDiscovery'] = false;
      diagnostics['autoDiscoveryError'] = e.toString();
    }

    print('📊 Network diagnostics completed: $diagnostics');
    return diagnostics;
  }
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
}

/// Network diagnostics data class
class NetworkDiagnostics {
  bool baseServerAccessible = false;
  int? baseServerStatus;
  String? baseServerError;

  bool streamEndpointAccessible = false;
  int? streamEndpointStatus;
  String? streamEndpointError;

  String getDiagnosticSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Network Diagnostics:');
    buffer.writeln(
      'Base Server: ${baseServerAccessible ? "✅" : "❌"} (Status: $baseServerStatus)',
    );
    if (baseServerError != null) {
      buffer.writeln('Base Error: $baseServerError');
    }
    buffer.writeln(
      'Stream Endpoint: ${streamEndpointAccessible ? "✅" : "❌"} (Status: $streamEndpointStatus)',
    );
    if (streamEndpointError != null) {
      buffer.writeln('Stream Error: $streamEndpointError');
    }
    return buffer.toString();
  }
}

/// Camera server data class
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
    return 'CameraServer(ip: $ip, port: $port, endpoint: $endpoint, confidence: $confidence, isPiDevice: $isPiDevice)';
  }
}

/// Raspberry Pi device data class
class RaspberryPiDevice {
  final String ip;
  final List<String> indicators;
  final int confidence;

  const RaspberryPiDevice({
    required this.ip,
    required this.indicators,
    required this.confidence,
  });

  @override
  String toString() {
    return 'RaspberryPiDevice(ip: $ip, indicators: $indicators, confidence: $confidence)';
  }
}

/// Discovery result data class
class DiscoveryResult {
  final List<CameraServer> cameraServers;
  final bool isSuccessful;
  final String? errorMessage;
  final CameraServer? bestServer;

  const DiscoveryResult({
    required this.cameraServers,
    required this.isSuccessful,
    this.errorMessage,
    this.bestServer,
  });
}
