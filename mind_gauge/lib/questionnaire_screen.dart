import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';

import 'models.dart';
import 'services.dart';
import 'ui_components.dart';
import 'services/camera_service.dart';
import 'assessment_result_screen.dart';

class QuestionnaireScreen extends StatefulWidget {
  final UserProfile userProfile;
  const QuestionnaireScreen({super.key, required this.userProfile});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  // FIX: Use late initialization and MockService to fetch age-based questions
  late final List<QuestionnaireData> _questions;
  final MockQuestionnaireService _service = MockQuestionnaireService();
  bool _isLoading = false;

  // Camera & Emotion Analysis
  final CameraService _cameraService = CameraService();
  String _currentEmotion = "";
  final List<Map<String, dynamic>> _expressionHistory = [];

  @override
  void initState() {
    super.initState();
    _questions = MockQuestionnaireService.getLevel1Questions(
      widget.userProfile.age,
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _cameraService.initialize();
    if (mounted) {
      setState(() {});
      // Start web analysis right after camera is initialized.
      _cameraService.startWebAnalysis((result) {
        if (mounted) {
          setState(() {
            _currentEmotion =
                "${result['dominant_emotion']} (${(result['score'] * 100).toStringAsFixed(1)}%)";
          });
          print("Detected Emotion from timer: $_currentEmotion");
          _expressionHistory.add(result);
        }
      });
    }
  }

  @override
  void dispose() {
    _cameraService.stopWebAnalysis();
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _captureAndAnalyze() async {
    if (!_cameraService.isInitialized) return;

    // Optional: Throttle or limit frequency if needed
    final image = await _cameraService.takePicture();
    if (image != null) {
      final result = await _cameraService.analyzeExpression(image);
      if (result != null && mounted) {
        setState(() {
          _currentEmotion =
              "${result['dominant_emotion']} (${(result['score'] * 100).toStringAsFixed(1)}%)";
        });
        print("Detected Emotion: $_currentEmotion");
        _expressionHistory.add(result);
      }
    }
  }

  void _handleSubmit() async {
    setState(() {
      _isLoading = true;
    });

    // 1. Aggregate Visual Sentiment from snapshots
    Map<String, dynamic>? visualSentiment;

    if (_expressionHistory.isNotEmpty) {
      Map<String, double> profile = {};
      int count = _expressionHistory.length;

      for (var result in _expressionHistory) {
        Map<String, dynamic> details = result['details'] ?? {};
        details.forEach((key, value) {
          profile[key] = (profile[key] ?? 0) + (value as num).toDouble();
        });
      }

      profile.forEach((key, value) {
        profile[key] = value / count;
      });

      String dominant = profile.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      visualSentiment = {
        'dominant_emotion': dominant,
        'visual_sentiment_profile': profile,
        'overall_score': profile[dominant],
      };
    }

    // 2. Prepare 13 Domain Scores for the Gatekeeper model
    final List<int> thirteenDomainScores = [
      _getHighestScoreForDomain("I"), // Depression
      _getHighestScoreForDomain("II"), // Anger
      _getHighestScoreForDomain("III"), // Mania
      _getHighestScoreForDomain("IV"), // Anxiety
      _getHighestScoreForDomain("V"), // Somatic
      _getHighestScoreForDomain("VIII"), // Sleep
      _getHighestScoreForDomain("X"), // Repetitive Thoughts
      _getHighestScoreForDomain("XIII"), // Substance Use
      _getHighestScoreForDomain("VI"), // Suicidal
      _getHighestScoreForDomain("VII"), // Psychosis
      _getHighestScoreForDomain("IX"), // Memory
      _getHighestScoreForDomain("XI"), // Dissociation
      _getHighestScoreForDomain("XII"), // Personality Functioning
    ];

    // 3. Call Global Level 1 Diagnostic Model
    String? overallStatus = await getMLDiagnosis(
      "level1",
      thirteenDomainScores,
      widget.userProfile.age,
    );

    // 4. Identify domains requiring categorical severity analysis
    final List<DomainScore> categoricalResults = await _service
        .submitQuestionnaire(_questions, widget.userProfile.age);
    final List<int> rawScores = _questions.map((q) => q.score.round()).toList();

    // 5. Fetch specific severity labels from ML categorical models
    final List<Map<String, dynamic>> serializedResults = [];
    for (var res in categoricalResults) {
      try {
        String? categoricalSeverity = await getMLDiagnosis(
          res.domainName,
          rawScores,
          widget.userProfile.age,
        );
        res.mlDiagnosis = categoricalSeverity ?? "Clinical Review Required";
        serializedResults.add({
          'domainName': res.domainName,
          'highestScore': res.highestScore,
          'mlDiagnosis': res.mlDiagnosis,
        });
      } catch (e) {
        res.mlDiagnosis = "Analysis Unavailable";
      }
    }

    // 6. Get Combined Holistic Report
    Map<String, dynamic>? combinedReport;
    if (visualSentiment != null) {
      combinedReport = await _cameraService.getCombinedReport(
        serializedResults,
        visualSentiment,
      );
    }

    // 7. Save everything to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseUserService().saveAssessmentResults(
        user.uid,
        categoricalResults,
        overallStatus,
      );
    }

    setState(() {
      _isLoading = false;
    });
    if (!mounted) return;

    // 8. Turn off the camera completely
    _cameraService.stopWebAnalysis();
    await _cameraService.dispose();

    // 9. Navigate to Results
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AssessmentResultScreen(
          results: categoricalResults,
          userProfile: widget.userProfile,
          overallStatus: overallStatus,
          combinedReport: combinedReport,
        ),
      ),
    );
  }

  // Helper to find the maximum score for a given domain ID (e.g., "I", "VII")
  int _getHighestScoreForDomain(String domainId) {
    final domainQuestions = _questions.where((q) => q.domain == domainId);
    if (domainQuestions.isEmpty) return 0;
    return domainQuestions
        .map((q) => q.score.round())
        .reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Level 1 Symptom Check-In'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_currentEmotion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  _currentEmotion,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Safe Camera Preview (Small debug view)
            if (_cameraService.isInitialized &&
                _cameraService.controller != null)
              SizedBox(
                height: 1,
                width: 1,
                child: CameraPreview(
                  _cameraService.controller!,
                ), // Hidden but active
              ),

            // --- Lighting Check Warning Banner ---
            ValueListenableBuilder<bool>(
              valueListenable: _cameraService.isLightingGood,
              builder: (context, isGood, child) {
                if (isGood) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Colors.orange.shade800,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "It looks a bit dark. Please move to a brighter area for better accuracy.",
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            Text(
              'Questionnaire Version: ${MockQuestionnaireService.mapAgeToQuestionnaire(widget.userProfile.age).toString().split('.').last}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Rate how much or how often you have been bothered by each problem during the past TWO (2) WEEKS.',
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Response Scale:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text('1 - None/Not at all'),
                  Text('2 - Slight (Rare, less than a day or two)'),
                  Text('3 - Mild (Several days)'),
                  Text('4 - Moderate (More than half the days)'),
                  Text('5 - Severe (Nearly every day)'),
                ],
              ),
            ),
            ..._questions.asMap().entries.map(
              (entry) => QuestionnaireItem(
                data: entry.value,
                index: entry.key + 1,
                onInteraction: _captureAndAnalyze, // Bind callback
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: AppColors.primary)
                  : StyledButton(
                      text: 'SUBMIT ASSESSMENT',
                      onPressed: _handleSubmit,
                    ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

// 6. QUESTIONNAIRE WIDGET & SCREEN
class QuestionnaireItem extends StatefulWidget {
  final BaseQuestionnaireData data;
  final int index;
  final VoidCallback? onInteraction; // New callback

  const QuestionnaireItem({
    super.key,
    required this.data,
    required this.index,
    this.onInteraction,
  });

  @override
  State<QuestionnaireItem> createState() => _QuestionnaireItemState();
}

class _QuestionnaireItemState extends State<QuestionnaireItem> {
  int get sliderValue => widget.data.score.round();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.data.questionNumber}. ${widget.data.questionText}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: AppColors.secondary),
                onPressed: () {
                  if (widget.data.score > 1) {
                    setState(() {
                      widget.data.score--;
                    });
                    widget.onInteraction?.call(); // Trigger capture
                  }
                },
              ),
              Expanded(
                child: Slider(
                  value: widget.data.score,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: sliderValue.toString(),
                  onChanged: (double value) {
                    setState(() {
                      widget.data.score = value;
                    });
                  },
                  onChangeEnd: (double value) {
                    widget.onInteraction?.call(); // Trigger capture
                  },
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.primary.withOpacity(0.3),
                ),
              ),
              Text(
                sliderValue.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.secondary),
                onPressed: () {
                  if (widget.data.score < 5) {
                    setState(() {
                      widget.data.score++;
                    });
                    widget.onInteraction?.call(); // Trigger capture
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
