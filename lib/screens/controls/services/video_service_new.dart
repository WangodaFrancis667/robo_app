import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
    _isLoadingStream = true;
    _errorMessage = '';

    try {
      bool serverRunning = await testConnectivity();

      if (serverRunning) {
        _isLoadingStream = false;
        _isStreamActive = true;
        _errorMessage = '';
      } else { 
        _isLoadingStream = false;
        _isStreamActive = false;
        _errorMessage = 'Camera server not available';
      }
    } catch (e) {
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
      print('Video connectivity test failed: $e');
      return false;
    }
  }

  /// Test alternative connectivity method
  Future<bool> testAlternativeConnectivity() async {
    try {
      final client = http.Client();
      try {
        final baseUrl = 'http://$raspberryPiIP:$port';
        final response = await client
            .get(Uri.parse(baseUrl))
            .timeout(const Duration(seconds: 5));
        return response.statusCode == 200 ||
            response.statusCode == 404; // 404 might indicate server is running
      } finally {
        client.close();
      }
    } catch (e) {
      print('Alternative video connectivity test failed: $e');
      return false;
    }
  }

  /// Create video service with custom configuration
  static VideoService createCustom({
    required String ip,
    int port = _defaultPort,
    String endpoint = _defaultEndpoint,
  }) {
    return VideoService(raspberryPiIP: ip, port: port, endpoint: endpoint);
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
