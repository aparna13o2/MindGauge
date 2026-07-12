import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _sending = false;

  // Lighting Check Properties
  final ValueNotifier<bool> isLightingGood = ValueNotifier(true);
  bool _isLightingStreamActive = false;
  int _frameCount = 0;
  final int _lightingCheckInterval = 10; // Check luminance every 10 frames
  final double _luminanceThreshold = 40.0; // Adjust this threshold (0-255)
  // API Endpoint Route mapping based on platform
  String get _apiBaseUrl {
    final prodUrl = dotenv.env['PROD_API_URL'] ?? 'https://mind-gauge-api.onrender.com';
    final localUrl = dotenv.env['LOCAL_API_URL'] ?? 'http://127.0.0.1:5000';

    if (kIsWeb) {
      if (kReleaseMode) {
        return prodUrl;
      }
      return localUrl;
    }
    return prodUrl;
  }

  bool get isInitialized => _isInitialized;
  CameraController? get controller =>
      _controller; // Expose controller for Preview widget

  // --- Core Camera Initialization ---
  Future<void> initialize() async {
    try {
      // 1. Request Permissions
      var status = await Permission.camera.request();
      if (!status.isGranted) {
        print("Camera permission denied");
        return;
      }

      // 2. Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        print("No cameras available");
        return;
      }

      // 3. Initialize controller (Use front camera by default)
      CameraDescription frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low, // Lower resolution for faster upload/processing
        enableAudio: false,
      );

      await _controller!.initialize();
      _isInitialized = true;
      print("Camera initialized successfully");
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }

  // --- Lighting Check Methods ---
  void startLightingCheckStream() {
    if (!_isInitialized || _controller == null || _isLightingStreamActive)
      return;

    try {
      _isLightingStreamActive = true;
      _controller!.startImageStream((CameraImage image) {
        _frameCount++;
        if (_frameCount % _lightingCheckInterval == 0) {
          _checkLuminance(image);
        }
      });
      print("Lighting check stream started");
    } catch (e) {
      print("Error starting image stream for lighting: $e");
      _isLightingStreamActive = false;
    }
  }

  Future<void> stopLightingCheckStream() async {
    if (!_isInitialized || _controller == null || !_isLightingStreamActive)
      return;

    try {
      await _controller!.stopImageStream();
      _isLightingStreamActive = false;
      print("Lighting check stream stopped");
    } catch (e) {
      // It might throw if already stopped or taking a picture, catch it safely
      print("Error stopping image stream: $e");
    }
  }

  void _checkLuminance(CameraImage image) {
    if (image.planes.isEmpty) return;

    // The Y plane (index 0) represents luminance (brightness) in YUV formats.
    // iOS and Android typically default to a YUV format for camera streams.
    final Uint8List yPlane = image.planes[0].bytes;

    // Calculate average luminance (very basic sub-sampling for speed)
    int totalLuminance = 0;
    int pixelsSampled = 0;

    // Sample every 10th pixel to keep CPU usage incredibly low
    for (int i = 0; i < yPlane.length; i += 10) {
      totalLuminance += yPlane[i];
      pixelsSampled++;
    }

    if (pixelsSampled == 0) return;

    final double avgLuminance = totalLuminance / pixelsSampled;

    // Update the notifier if the state crosses the threshold
    final bool currentlyGood = avgLuminance >= _luminanceThreshold;
    if (isLightingGood.value != currentlyGood) {
      isLightingGood.value = currentlyGood;
      print(
        "Lighting check: ${currentlyGood ? 'GOOD' : 'POOR'} (Avg Luma: ${avgLuminance.toStringAsFixed(1)})",
      );
    }
  }

  // --- Actions ---
  Future<XFile?> takePicture() async {
    if (!_isInitialized || _controller == null) return null;

    try {
      if (_controller!.value.isTakingPicture) return null; // Prevent overlap

      // Note: On many platforms, you cannot capture a picture while the image stream is active.
      // We must briefly stop the stream, capture, and then restart it.
      bool wasStreaming = _isLightingStreamActive;
      if (wasStreaming) {
        await stopLightingCheckStream();
      }

      XFile image = await _controller!.takePicture();

      if (wasStreaming) {
        startLightingCheckStream();
      }

      return image;
    } catch (e) {
      print("Error taking picture: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> analyzeExpression(XFile imageFile) async {
    if (_sending) return null;
    _sending = true;

    try {
      final bytes = await imageFile.readAsBytes();

      // Compress image significantly before sending to ML API
      List<int> compressedBytes = bytes;
      if (!kIsWeb) {
        try {
          compressedBytes = await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: 480,
            minHeight: 480,
            quality: 70,
          );
        } catch (e) {
          print("Compression failed, falling back to original: $e");
        }
      }

      final String base64Image = base64Encode(compressedBytes);

      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/analyze_face'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'image': base64Image}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Emotion: ${data['dominant_emotion']}");
        return data;
      } else {
        print("API Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error sending image to API: $e");
    } finally {
      _sending = false; // ← THIS IS CRITICAL
    }

    return null;
  }

  Future<void> startVideoRecording() async {
    if (!_isInitialized || _controller == null) return;
    try {
      if (_controller!.value.isRecordingVideo) return;
      await _controller!.startVideoRecording();
      print("Video recording started");
    } catch (e) {
      print("Error starting video recording: $e");
    }
  }

  Future<XFile?> stopVideoRecording() async {
    if (!_isInitialized || _controller == null) return null;
    try {
      if (!_controller!.value.isRecordingVideo) return null;
      XFile video = await _controller!.stopVideoRecording();
      print("Video recording stopped: ${video.path}");
      return video;
    } catch (e) {
      print("Error stopping video recording: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> analyzeVideo(XFile videoFile) async {
    try {
      final bytes = await videoFile.readAsBytes();
      final String base64Video = base64Encode(bytes);

      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/analyze_video'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'video': base64Video}),
          )
          .timeout(
            const Duration(seconds: 15),
          ); // A bit longer for videos if used again

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Video Analysis Dominant Emotion: ${data['dominant_emotion']}");
        return data;
      } else {
        print("Video API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error sending video to API: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCombinedReport(
    List<Map<String, dynamic>> questionnaireResults,
    Map<String, dynamic> visualSentiment,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/combined_report'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'questionnaire_results': questionnaireResults,
              'visual_sentiment': visualSentiment,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print(
          "Combined Report Error: ${response.statusCode} - ${response.body}",
        );
        return null;
      }
    } catch (e) {
      print("Error getting combined report: $e");
      return null;
    }
  }

  Future<void> dispose() async {
    try {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }
    } catch (e) {
      print("Error disposing camera: $e");
    } finally {
      isLightingGood.dispose();
      _isInitialized = false;
      _cameras = null; // Release resources
    }
  }
}
