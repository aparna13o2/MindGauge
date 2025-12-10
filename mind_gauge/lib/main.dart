import 'package:flutter/material.dart';
import 'dart:math';
import 'package:mind_gauge/services/api_service.dart';

// --- MOCK SERVICE LAYER AND DATA STRUCTURES ---
class UserProfile {
 final String email;
 final String name;
 final String userId;

 UserProfile({required this.email, required this.name, required this.userId});
}

class MockAuthService {
 Future<UserProfile?> login(String email, String password) async {
  // Mock successful login for any input
  await Future.delayed(const Duration(milliseconds: 800));
  if (email.isNotEmpty && password.isNotEmpty) {
   return UserProfile(email: email, name: "Basith", userId: "user-1234");
  }
  return null;
 }

 Future<bool> register(String email, String name, String age, String password, String location) async {
  // Mock successful registration
  await Future.delayed(const Duration(milliseconds: 1000));
  return true;
 }
}

// Data structure for the static domain metadata
class DomainMetadata {
 final String domainName;
 final int thresholdScore; // 1 for Slight/Greater, 2 for Mild/Greater
 final String level2Measure;

 const DomainMetadata(this.domainName, this.thresholdScore, this.level2Measure);
}
// NEW: Abstract class defining common questionnaire data fields
abstract class BaseQuestionnaireData {
  final String domain;
  final String questionNumber;
  final String questionText;
  double score;

  BaseQuestionnaireData({
    required this.domain, 
    required this.questionNumber, 
    required this.questionText, 
    required this.score,
  });}

// QuestionnaireData (Around line 51):
// OLD: QuestionnaireData(super.domain, super.questionNumber, super.questionText) : super(score: 0.0);
// NEW:
class QuestionnaireData extends BaseQuestionnaireData {
 QuestionnaireData(String domain, String questionNumber, String questionText) : super(
    domain: domain, 
    questionNumber: questionNumber, 
    questionText: questionText, 
    score: 0.0
  );
}

// Level2QuestionnaireData (Around line 56):
// OLD: Level2QuestionnaireData(super.domain, super.questionNumber, super.questionText) : super(score: 0.0);
// NEW:
class Level2QuestionnaireData extends BaseQuestionnaireData {
  Level2QuestionnaireData(String domain, String questionNumber, String questionText) : super(
    domain: domain, 
    questionNumber: questionNumber, 
    questionText: questionText, 
    score: 0.0
  );
}

// Data structure to hold the results of the questionnaire after scoring.
class DomainScore {
 final String domain;
 final String domainName; // Added: Full name of the domain
 final int highestScore;
 final int thresholdScore; // Added: The required score for follow-up (1 or 2)
 final String level2Measure; // Added: Name of the associated Level 2 Measure

 DomainScore(this.domain, this.domainName, this.highestScore, this.thresholdScore, this.level2Measure);

 String get severity {
    switch (highestScore) {
      case 4:
        return "Severe";
      case 3:
        return "Moderate";
      case 2:
        return "Mild";
      case 1:
        return "Slight";
      default:
        return "None";
    }
  }

 @override
 String toString() {
    return "${domainName}: ${severity} (Score: $highestScore). Follow-up needed: ${level2Measure}";
 }
}

class MockQuestionnaireService {
 // Static map containing all threshold data for each domain.
 static const Map<String, DomainMetadata> _domainThresholds = {
  // Domain I-V, VIII-XII use a Mild or greater threshold (score >= 2)
  "I": DomainMetadata("Depression", 2, "LEVEL 2-Depression-Adult (PROMIS Emotional Distress-Depression-Short Form)"),
  "II": DomainMetadata("Anger", 2, "LEVEL 2-Anger-Adult (PROMIS Emotional Distress-Anger-Short Form)"),
  "III": DomainMetadata("Mania", 2, "LEVEL 2-Mania-Adult (Altman Self-Rating Mania Scale)"),
  "IV": DomainMetadata("Anxiety", 2, "LEVEL 2-Anxiety-Adult (PROMIS Emotional Distress-Anxiety-Short Form)"),
  "V": DomainMetadata("Somatic Symptoms", 2, "LEVEL 2-Somatic Symptom-Adult (Patient Health Questionnaire 15 Somatic Symptom Severity [PHQ-15])"),

  // Domains VI, VII, XIII use a Slight or greater threshold (score >= 1)
  "VI": DomainMetadata("Suicidal Ideation", 1, "None"),
  "VII": DomainMetadata("Psychosis", 1, "None"),
  
  // Domains VIII-XII use a Mild or greater threshold (score >= 2)
  "VIII": DomainMetadata("Sleep Problems", 2, "LEVEL 2-Sleep Disturbance - Adult (PROMIS-Sleep Disturbance-Short Form)"),
  "IX": DomainMetadata("Memory", 2, "None"),
  "X": DomainMetadata("Repetitive Thoughts and Behaviors", 2, "LEVEL 2-Repetitive Thoughts and Behaviors-Adult (adapted from the Florida Obsessive-Compulsive Inventory [FOCI] Severity Scale [Part B])"),
  "XI": DomainMetadata("Dissociation", 2, "None"),
  "XII": DomainMetadata("Personality Functioning", 2, "None"),
  
  // Domain XIII uses a Slight or greater threshold (score >= 1)
  "XIII": DomainMetadata("Substance Use", 1, "LEVEL 2-Substance Abuse-Adult (adapted from the NIDA-modified ASSIST)"),
 };

// The getInitialQuestions method is omitted for brevity but remains unchanged.
 static List<QuestionnaireData> getInitialQuestions() {
  return [
   // Domain I: Depression (Qn 1-2)
   QuestionnaireData("I", "1", "Little interest or pleasure in doing things?"),
   QuestionnaireData("I", "2", "Feeling down, depressed, or hopeless?"),

   // Domain II: Anger (Qn 3)
   QuestionnaireData("II", "3", "Feeling more irritated, grouchy, or angry than usual?"),

   // Domain III: Mania (Qn 4-5)
   QuestionnaireData("III", "4", "Sleeping less than usual, but still have a lot of energy?"),
   QuestionnaireData("III", "5", "Starting lots more projects than usual or doing more risky things than usual?"),

   // Domain IV: Anxiety (Qn 6-8)
   QuestionnaireData("IV", "6", "Feeling nervous, anxious, frightened, worried, or on edge?"),
   QuestionnaireData("IV", "7", "Feeling panic or being frightened?"),
   QuestionnaireData("IV", "8", "Avoiding situations that make you anxious?"),

   // Domain V: Somatic Symptoms (Qn 9-10)
   QuestionnaireData("V", "9", "Unexplained aches and pains (e.g., head, back, joints, abdomen, legs)?"),
   QuestionnaireData("V", "10", "Feeling that your illnesses are not being taken seriously enough?"),

   // Domain VI: Suicidal Ideation (Qn 11)
   QuestionnaireData("VI", "11", "Thoughts of actually hurting yourself?"),

   // Domain VII: Psychosis (Qn 12-13)
   QuestionnaireData("VII", "12", "Hearing things other people couldn't hear, such as voices even when no one was around?"),
   QuestionnaireData("VII", "13", "Feeling that someone could hear your thoughts, or that you could hear what another person was thinking?"),

   // Domain VIII: Sleep Problems (Qn 14)
   QuestionnaireData("VIII", "14", "Problems with sleep that affected your sleep quality over all?"),

   // Domain IX: Memory (Qn 15)
   QuestionnaireData("IX", "15", "Problems with memory (e.g., learning new information) or with location (e.g., finding your way home)?"),

   // Domain X: Repetitive Thoughts and Behaviors (Qn 16-17)
   QuestionnaireData("X", "16", "Unpleasant thoughts, urges, or images that repeatedly enter your mind?"),
   QuestionnaireData("X", "17", "Feeling driven to perform certain behaviors or mental acts over and over again?"),

   // Domain XI: Dissociation (Qn 18)
   QuestionnaireData("XI", "18", "Feeling detached or distant from yourself, your body, your physical surroundings, or your memories?"),

   // Domain XII: Personality Functioning (Qn 19-20)
   QuestionnaireData("XII", "19", "Not knowing who you really are or what you want out of life?"),
   QuestionnaireData("XII", "20", "Not feeling close to other people or enjoying your relationships with them?"),

   // Domain XIII: Substance Use (Qn 21-23)
   QuestionnaireData("XIII", "21", "Drinking at least 4 drinks of any kind of alcohol in a single day?"),
   QuestionnaireData("XIII", "22", "Smoking any cigarettes, a cigar, or pipe, or using snuff or chewing tobacco?"),
   QuestionnaireData("XIII", "23", "Using any of the following medicines on your own, that is, without a doctor's prescription, in greater amounts or longer than prescribed [e.g., painkillers (like Vicodin), stimulants (like Ritalin or Adderall), sedatives or tranquilizers (like sleeping pills or Valium), or drugs like marijuana, cocaine or crack, club drugs (like ecstasy), hallucinogens (like LSD), heroin, inhalants or solvents (like glue), or methamphetamine (like speed)]?"),
  ];
 }


 // Submits the responses and returns a summary of domains requiring further inquiry.
 Future<List<DomainScore>> submitQuestionnaire(List<QuestionnaireData> responses) async {
  // Mimic API delay
  await Future.delayed(const Duration(seconds: 1));

  // 1. Group responses by domain and find the highest score (integer) for each domain.
  final Map<String, int> domainHighestScores = {};

  for (var item in responses) {
   final domain = item.domain;
   // Use the rounded integer score as per DSM-5-TR scoring instructions
   final score = item.score.round(); 
   
   // Update the highest score found so far for this domain.
   domainHighestScores[domain] = 
     (domainHighestScores[domain] == null || score > domainHighestScores[domain]!)
     ? score
     : domainHighestScores[domain]!;
  }
  
  // 2. Determine which domains meet the threshold for 'further inquiry' 
  // using the central metadata map.
  final List<DomainScore> results = [];

  domainHighestScores.forEach((domain, highestScore) {
   final metadata = _domainThresholds[domain];
   if (metadata == null) return; // Skip if domain key is invalid

   // Use the threshold score directly from the metadata.
   bool requiresFollowUp = highestScore >= metadata.thresholdScore;

   // Only include domains that meet the clinical threshold for follow-up
   if (requiresFollowUp) {
    results.add(DomainScore(
     domain,
     metadata.domainName,
     highestScore,
     metadata.thresholdScore,
     metadata.level2Measure,
    ));
   }
  });

  // Sort the results by highest score for easy review
  results.sort((a, b) => b.highestScore.compareTo(a.highestScore));

  // Return the list of domains requiring further inquiry.
  return results;
 }
  static final Map<String, List<Level2QuestionnaireData>> _level2Questions = {
    "Depression":  [
      // Level 2 questions for Depression (using the new class)
      Level2QuestionnaireData("I", "D1", "I felt depressed."),
      Level2QuestionnaireData("I", "D2", "I felt worthless."),
      Level2QuestionnaireData("I", "D3", "I felt sad."),
      Level2QuestionnaireData("I", "D4", "I felt hopeless."),
      Level2QuestionnaireData("I", "D5", "I felt like a failure."),
      Level2QuestionnaireData("I", "D6", "I felt that I have no future."),
      Level2QuestionnaireData("I", "D7", "I felt helpless."),
      Level2QuestionnaireData("I", "D8", "I felt discouraged."),
    ],
    "Anger":  [
      // Level 2 questions for Depression (using the new class)
      Level2QuestionnaireData("II", "A1", "In the past seven days were you irritated more than people knew?"),
      Level2QuestionnaireData("II", "A2", "In the past seven days, have you felt angry?"),
      Level2QuestionnaireData("II", "A3", " In the past seven days, have you felt like you were ready to explode?"),
      Level2QuestionnaireData("II", "A4", "In the past seven days, were you grouchy?"),
      Level2QuestionnaireData("II", "A5", "In the past seven days, have you felt annoyed?"),
      
    ],
 };
}

// --- CONSTANTS & STYLES ---

class AppColors {
 static const Color primary = Color(0xFF00C8C8); // Bright Cyan
 static const Color secondary = Color(0xFF007A7A); // Darker Teal
 static const Color background = Color(0xFFF7FFF7); // Off-White/Minty Background
 static const Color cardColor = Color(0xFFEEF7E8); // Light Green Card
 static const Color text = Color(0xFF2C3E50); // Dark text
 static const Color buttonShadow = Color(0xAA00C8C8);
 static const Color warning = Color(0xFFFF9800); // Amber for warnings/mild
 static const Color danger = Color(0xFFE53935); // Red for severe
}

const TextStyle kTitleStyle = TextStyle(
 color: AppColors.secondary,
 fontSize: 32,
 fontWeight: FontWeight.w900,
 letterSpacing: 1.5,
);

const TextStyle kSubtitleStyle = TextStyle(
 color: AppColors.primary,
 fontSize: 16,
 fontWeight: FontWeight.w500,
 letterSpacing: 0.5,
);

// --- MAIN APP WIDGET ---

void main() {
 runApp(const MindGaugeApp());
}

class MindGaugeApp extends StatelessWidget {
 const MindGaugeApp({super.key});

 @override
 Widget build(BuildContext context) {
  return MaterialApp(
   debugShowCheckedModeBanner: false,
   title: 'MindGauge',
   theme: ThemeData(
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSwatch(
     primarySwatch: MaterialColor(AppColors.primary.value, {
      50: AppColors.primary.withOpacity(0.1),
      100: AppColors.primary.withOpacity(0.2),
      200: AppColors.primary.withOpacity(0.3),
      300: AppColors.primary.withOpacity(0.4),
      400: AppColors.primary.withOpacity(0.5),
      500: AppColors.primary.withOpacity(0.6),
      600: AppColors.primary.withOpacity(0.7),
      700: AppColors.primary.withOpacity(0.8),
      800: AppColors.primary.withOpacity(0.9),
      900: AppColors.primary.withOpacity(1.0),
     }),
    ).copyWith(secondary: AppColors.secondary),
    fontFamily: 'Inter',
    useMaterial3: true,
   ),
   home: const SplashScreen(),
  );
 }
}

// --- WIDGETS ---

class StyledButton extends StatelessWidget {
 final String text;
 final VoidCallback onPressed;
 final Color color;
 final Color shadowColor;

 const StyledButton({
  super.key,
  required this.text,
  required this.onPressed,
  this.color = AppColors.primary,
  this.shadowColor = AppColors.buttonShadow,
 });

 @override
 Widget build(BuildContext context) {
  return Container(
   width: 280,
   height: 50,
   decoration: BoxDecoration(
    boxShadow: [
     BoxShadow(
      color: shadowColor,
      blurRadius: 10,
      spreadRadius: 2,
      offset: const Offset(0, 4),
     ),
    ],
    borderRadius: BorderRadius.circular(25),
   ),
   child: ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
     backgroundColor: color,
     foregroundColor: Colors.white,
     shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(25),
     ),
     padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
     elevation: 0, // Remove default elevation
    ),
    child: Text(
     text,
     style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
     ),
    ),
   ),
  );
 }
}

class CustomTextField extends StatelessWidget {
 final String label;
 final bool isPassword;
 final TextEditingController? controller;

 const CustomTextField({
  super.key,
  required this.label,
  this.isPassword = false,
  this.controller,
 });

 @override
 Widget build(BuildContext context) {
  return Padding(
   padding: const EdgeInsets.symmetric(vertical: 10.0),
   child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
     Text(
      label,
      style: const TextStyle(
       color: AppColors.secondary,
       fontSize: 16,
       fontWeight: FontWeight.w600,
      ),
     ),
     const SizedBox(height: 5),
     TextFormField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
       filled: true,
       fillColor: Colors.white,
       contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
       border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
       ),
       focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
       ),
      ),
     ),
    ],
   ),
  );
 }
}


// --- SCREENS ---

// 1. SPLASH SCREEN
class SplashScreen extends StatefulWidget {
 const SplashScreen({super.key});

 @override
 State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
 @override
 void initState() {
  super.initState();
  // Simulate any initial loading or checking auth status
  Future.delayed(const Duration(seconds: 3), () {
   Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (context) => const AuthScreen()),
   );
  });
 }

 @override
 Widget build(BuildContext context) {
  return Scaffold(
   body: Center(
    child: Column(
     mainAxisAlignment: MainAxisAlignment.center,
     children: [
      // Placeholder for the brain/heart logo from Figma
      Image.asset(
       'assets/mindgauge_logo.png', // Placeholder image path (you'll need to add your asset)
       width: 150,
       height: 150,
       errorBuilder: (context, error, stackTrace) {
        // Fallback icon if the asset is not loaded
        return const Icon(
         Icons.psychology_outlined,
         size: 150,
         color: AppColors.primary,
        );
       },
      ),
      const SizedBox(height: 30),
      const Text(
       'MINDGAUGE',
       style: kTitleStyle,
      ),
      const SizedBox(height: 10),
      const Text(
       'Measure your Mental Health Status',
       style: kSubtitleStyle,
      ),
     ],
    ),
   ),
  );
 }
}


// 2. AUTH SCREEN (REGISTER/LOGIN CHOICE)
class AuthScreen extends StatelessWidget {
 const AuthScreen({super.key});

 void _navigateToLogin(BuildContext context) {
  Navigator.of(context).push(
   MaterialPageRoute(builder: (context) => const LoginScreen()),
  );
 }

 void _navigateToRegister(BuildContext context) {
  Navigator.of(context).push(
   MaterialPageRoute(builder: (context) => const RegisterScreen()),
  );
 }

 @override
 Widget build(BuildContext context) {
  return Scaffold(
   appBar: AppBar(
    backgroundColor: AppColors.background,
    elevation: 0,
   ),
   body: Center(
    child: Padding(
     padding: const EdgeInsets.all(24.0),
     child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
       // Logo/Title as per Figma
       const Icon(Icons.psychology_outlined, size: 100, color: AppColors.primary),
       const SizedBox(height: 20),
       const Text('MINDGAUGE', style: kTitleStyle),
       const SizedBox(height: 5),
       const Text('Measure your Mental Health Status', style: kSubtitleStyle),
       const Spacer(),
       StyledButton(
        text: 'REGISTER',
        onPressed: () => _navigateToRegister(context),
       ),
       const SizedBox(height: 25),
       StyledButton(
        text: 'LOGIN',
        onPressed: () => _navigateToLogin(context),
        color: AppColors.secondary,
        shadowColor: AppColors.secondary.withOpacity(0.7),
       ),
       const Spacer(flex: 2),
      ],
     ),
    ),
   ),
  );
 }
}

// 3. LOGIN SCREEN
class LoginScreen extends StatefulWidget {
 const LoginScreen({super.key});

 @override
 State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
 final ApiService _authService = ApiService();
 final TextEditingController _emailController = TextEditingController();
 final TextEditingController _passwordController = TextEditingController();
 bool _isLoading = false;

void _handleLogin() async {
  setState(() { _isLoading = true; });

  final result = await _authService.login(
    _emailController.text,
    _passwordController.text,
  );

  setState(() { _isLoading = false; });

  if (result != null && result["status"] == "success") {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainDashboard()),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login failed')),
    );
  }
}


 @override
 Widget build(BuildContext context) {
  return Scaffold(
   appBar: AppBar(
    title: const Text('Login'),
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.secondary,
    elevation: 0,
   ),
   body: Padding(
    padding: const EdgeInsets.all(30.0),
    child: SingleChildScrollView(
     child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
       const SizedBox(height: 20),
       const Center(
        child: Icon(Icons.psychology_outlined, size: 80, color: AppColors.primary),
       ),
       const SizedBox(height: 20),
       const Center(child: Text('MINDGAUGE', style: kTitleStyle)),
       const SizedBox(height: 5),
       const Center(child: Text('Measure your Mental Health Status', style: kSubtitleStyle)),
       const SizedBox(height: 40),
       CustomTextField(
        label: 'E-mail id',
        controller: _emailController,
       ),
       CustomTextField(
        label: 'Password',
        isPassword: true,
        controller: _passwordController,
       ),
       const SizedBox(height: 50),
       _isLoading
         ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
         : Center(
           child: StyledButton(
            text: 'LOGIN',
            onPressed: _handleLogin,
           ),
          ),
      ],
     ),
    ),
   ),
  );
 }
}

// 4. REGISTER SCREEN
class RegisterScreen extends StatefulWidget {
 const RegisterScreen({super.key});

 @override
 State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
 final MockAuthService _authService = MockAuthService();
 final TextEditingController _emailController = TextEditingController();
 final TextEditingController _nameController = TextEditingController();
 final TextEditingController _ageController = TextEditingController();
 final TextEditingController _passwordController = TextEditingController();
 final TextEditingController _locationController = TextEditingController();
 bool _isLoading = false;

 void _handleRegister() async {
  setState(() { _isLoading = true; });

  final success = await _authService.register(
  _emailController.text,
  _nameController.text,
  _ageController.text,
  _passwordController.text,
  _locationController.text,
);


  setState(() { _isLoading = false; });

  if (success) {
   if (mounted) {
    // Show success and navigate to login
    ScaffoldMessenger.of(context).showSnackBar(
     const SnackBar(content: Text('Registration successful! Please log in.')),
    );
    Navigator.of(context).pop(); // Go back to login screen
   }
  } else {
   if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
     const SnackBar(content: Text('Registration failed. Try again.')),
    );
   }
  }
 }

 @override
 Widget build(BuildContext context) {
  return Scaffold(
   appBar: AppBar(
    title: const Text('Register'),
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.secondary,
    elevation: 0,
   ),
   body: Padding(
    padding: const EdgeInsets.all(30.0),
    child: SingleChildScrollView(
     child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
       const Center(child: Text('MINDGAUGE', style: kTitleStyle)),
       const SizedBox(height: 30),
       CustomTextField(label: 'E-mail id', controller: _emailController),
       CustomTextField(label: 'Name', controller: _nameController),
       CustomTextField(label: 'Age', controller: _ageController),
       CustomTextField(label: 'Password', isPassword: true, controller: _passwordController),
       CustomTextField(label: 'Location', controller: _locationController),
       const SizedBox(height: 50),
       _isLoading
         ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
         : Center(
           child: StyledButton(
            text: 'REGISTER',
            onPressed: _handleRegister,
           ),
          ),
      ],
     ),
    ),
   ),
  );
 }
}

// 5. MAIN DASHBOARD (Temporary placeholder screen after login/register)
class MainDashboard extends StatelessWidget {
 const MainDashboard({super.key});

 @override
 Widget build(BuildContext context) {
  return Scaffold(
   appBar: AppBar(
    title: const Text('MindGauge Dashboard'),
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
   ),
   body: Center(
    child: Column(
     mainAxisAlignment: MainAxisAlignment.center,
     children: [
      const Text(
       'Welcome, User!',
       style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 20),
      StyledButton(
       text: 'Start Questionnaire',
       onPressed: () {
        Navigator.of(context).push(
         MaterialPageRoute(builder: (context) => const QuestionnaireScreen()),
        );
       },
      ),
      const SizedBox(height: 20),
      const Text(
       'This is the main navigation hub.',
       style: TextStyle(color: AppColors.secondary),
      ),
     ],
    ),
   ),
  );
 }
}


// 6. QUESTIONNAIRE WIDGET & SCREEN
// MODIFIED: Accepts the abstract BaseQuestionnaireData type
class QuestionnaireItem extends StatefulWidget {
 final BaseQuestionnaireData data; 
 final int index;
 const QuestionnaireItem({super.key, required this.data, required this.index});

 @override
 State<QuestionnaireItem> createState() => _QuestionnaireItemState();
}

class _QuestionnaireItemState extends State<QuestionnaireItem> {
 // Map slider value (0.0 to 4.0) to integer (0 to 4) for display
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
      // Display Question Number and Text
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
       const Icon(Icons.remove, color: AppColors.secondary),
       Expanded(
        child: Slider(
         value: widget.data.score,
         min: 0,
         max: 4,
         divisions: 4,
         label: sliderValue.toString(),
         onChanged: (double value) {
          setState(() {
           widget.data.score = value;
          });
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
       const Icon(Icons.add, color: AppColors.secondary),
      ],
     ),
    ],
   ),
  );
 }
}

class QuestionnaireScreen extends StatefulWidget {
 const QuestionnaireScreen({super.key});

 @override
 State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
 final List<QuestionnaireData> _questions = MockQuestionnaireService.getInitialQuestions();
 final MockQuestionnaireService _service = MockQuestionnaireService();
 bool _isLoading = false;

 void _handleSubmit() async {
  setState(() {
   _isLoading = true;
  });

  // 1. Get the list of domains that require follow-up
  final List<DomainScore> results = await _service.submitQuestionnaire(_questions);

  setState(() {
   _isLoading = false;
  });

  if (mounted) {
      // 2. Navigate to the new result screen
   Navigator.of(context).push(
    MaterialPageRoute(builder: (context) => AssessmentResultScreen(results: results)),
   );
  }
 }

 @override
 Widget build(BuildContext context) {
  return Scaffold(
   appBar: AppBar(
    title: const Text('Level 1 Symptom Check-In'),
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    actions: [
     IconButton(
      icon: const Icon(Icons.menu),
      onPressed: () {
       // Mock Drawer menu action
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu tapped: Detected Issue, Trends, etc.')),
       );
      },
     ),
    ],
   ),
   body: SingleChildScrollView(
    padding: const EdgeInsets.all(20.0),
    child: Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
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
         Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
         Text('Rate how much or how often you have been bothered by each problem during the past TWO (2) WEEKS.'),
         SizedBox(height: 10),
         Text('Response Scale:', style: TextStyle(fontWeight: FontWeight.bold)),
         SizedBox(height: 5),
         Text('0 - None/Not at all'),
         Text('1 - Slight (Rare, less than a day or two)'),
         Text('2 - Mild (Several days)'),
         Text('3 - Moderate (More than half the days)'),
         Text('4 - Severe (Nearly every day)'),
        ],
       ),
      ),
      ..._questions.asMap().entries.map((entry) =>
        QuestionnaireItem(data: entry.value, index: entry.key + 1)),
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


// 7. ASSESSMENT RESULT SCREEN (New Screen)

class AssessmentResultScreen extends StatelessWidget {
  final List<DomainScore> results;
  const AssessmentResultScreen({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    final bool needsFollowUp = results.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Results'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Heading and Summary ---
            Text(
              needsFollowUp 
                ? '⚠️ Further Assessment Recommended' 
                : '✅ Level 1 Check-In Complete',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: needsFollowUp ? AppColors.danger : AppColors.secondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              needsFollowUp 
                ? 'Your responses indicate symptoms in the areas below that meet the threshold for clinical follow-up using a **Level 2 Cross-Cutting Symptom Measure**.'
                : 'Your responses did not meet the clinical threshold for requiring further Level 2 assessment at this time.',
              style: const TextStyle(fontSize: 16, color: AppColors.text),
            ),
            
            const Divider(height: 40, thickness: 1, color: AppColors.secondary),

            // --- Results/Action Boxes ---
            if (needsFollowUp) ...[
              const Text(
                'Take These Follow-Up Questionnaires:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
              ),
              const SizedBox(height: 15),
              ...results.map((score) => DomainResultCard(score: score)).toList(),
            ] else 
              // Encouragement/Next Step if no issues were flagged
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.sentiment_satisfied_alt, size: 80, color: AppColors.primary),
                    const SizedBox(height: 20),
                    Text(
                      'All clear! Check in again when clinically indicated.',
                      style: kSubtitleStyle.copyWith(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    StyledButton(
                      text: 'Return to Dashboard',
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 8. WIDGET for Domain Result
class DomainResultCard extends StatelessWidget {
  final DomainScore score;
  const DomainResultCard({super.key, required this.score});

  Color _getSeverityColor(int score) {
    if (score >= 3) return AppColors.danger;
    if (score == 2 || score == 1) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _getSeverityColor(score.highestScore);
    final isLevel2Available = score.level2Measure != 'None';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: severityColor.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: severityColor),
              const SizedBox(width: 8),
              Text(
                '${score.domainName} (${score.severity})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: severityColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '• ${score.domainName}: Highest Score ${score.highestScore} (Threshold >= ${score.thresholdScore})',
            style: const TextStyle(color: AppColors.text, fontSize: 14),
          ),
          const SizedBox(height: 10),
          if (isLevel2Available) 
            StyledButton(
              text: 'TAKE ${score.domain} LEVEL 2 MEASURE',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => Level2QuestionnaireScreen(domainScore: score),
                  ),
                );
              },
              color: AppColors.secondary,
              shadowColor: AppColors.secondary.withOpacity(0.5),
            )
          else 
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No dedicated Level 2 measure is available for ${score.domainName}. Consult a clinician.',
                style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.text.withOpacity(0.7)),
              ),
            ),
        ],
      ),
    );
  }
}
// NEW SCREEN FOR LEVEL2 QUESTIONNAIRE:
// UPDATED SCREEN: Now displays the actual Level 2 Questionnaire
class Level2QuestionnaireScreen extends StatefulWidget {
  final DomainScore domainScore;
  const Level2QuestionnaireScreen({super.key, required this.domainScore});

  @override
  State<Level2QuestionnaireScreen> createState() => _Level2QuestionnaireScreenState();
}

class _Level2QuestionnaireScreenState extends State<Level2QuestionnaireScreen> {
  // Fetch the questions specific to this domain
  late final List<Level2QuestionnaireData> _questions;  
  @override
  void initState() {
    super.initState();
    // Use the domainName (e.g., "Depression") to fetch the corresponding questions
    _questions = MockQuestionnaireService._level2Questions[widget.domainScore.domainName] as List<Level2QuestionnaireData>? ?? [];    
    if (_questions.isEmpty) {
      // Handle case where no Level 2 measure is defined in the mock data
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: No Level 2 questions found for this domain.")),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.domainScore.domainName} Level 2'), backgroundColor: AppColors.secondary),
        body: const Center(child: Text("Level 2 Questionnaire not available (Mock Data Error).")),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.domainScore.domainName} Level 2 Assessment'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Follow-up: ${widget.domainScore.level2Measure}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 10),
            Text(
              'Your Level 1 score was ${widget.domainScore.highestScore} (${widget.domainScore.severity}). Please complete this focused Level 2 measure:',
              style: const TextStyle(fontSize: 16),
            ),
            const Divider(height: 30),

            // Display the Level 2 Questionnaire items
            ..._questions.asMap().entries.map((entry) =>
                QuestionnaireItem(data: entry.value, index: entry.key + 1)),
            
            const SizedBox(height: 40),
            Center(
              child: StyledButton(
                text: 'SUBMIT LEVEL 2 ASSESSMENT',
                onPressed: () {
                  // TODO: Implement Level 2 Scoring and Result Display
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Level 2 Submission Mocked. Implement scoring logic here.')),
                  );
                },
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}