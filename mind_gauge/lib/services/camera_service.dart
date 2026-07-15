import 'dart:async';
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
    final prodUrl = dotenv.env['PROD_API_URL'] ?? 'https://mindgaugebackend.onrender.com';
    return prodUrl; // Always use production backend to avoid localhost connection errors on web
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

  // --- Web Analysis Methods ---
  Timer? _analysisTimer;
  bool _isProcessing = false;

  void startWebAnalysis(Function(Map<String, dynamic>)? onAnalysisResult) {
    if (!_isInitialized || _controller == null) return;
    
    // Take a snapshot every 3 seconds instead of streaming continuous frames
    _analysisTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isProcessing || !_controller!.value.isInitialized) return;

      try {
        _isProcessing = true;
        
        // 1. Take a snapshot (Works perfectly on Web!)
        if (_controller!.value.isTakingPicture) return;
        final XFile file = await _controller!.takePicture();
        
        // 2 & 3. Send to your live Render backend
        final result = await analyzeExpression(file);
        if (result != null && onAnalysisResult != null) {
          onAnalysisResult(result);
        }
      } catch (e) {
        print("Error during snapshot analysis: $e");
      } finally {
        _isProcessing = false;
      }
    });
    print("Web analysis timer started");
  }

  void stopWebAnalysis() {
    _analysisTimer?.cancel();
    _analysisTimer = null;
    print("Web analysis timer stopped");
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

      XFile image = await _controller!.takePicture();

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
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': 'mindgauge-secure-api-key-2024'
            },
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
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': 'mindgauge-secure-api-key-2024'
            },
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
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': 'mindgauge-secure-api-key-2024'
            },
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
