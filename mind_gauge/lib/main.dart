import 'package:flutter/material.dart';
import 'dart:math';

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

// QuestionnaireData (Level 1)
class QuestionnaireData extends BaseQuestionnaireData {
QuestionnaireData(String domain, String questionNumber, String questionText) : super(
  domain: domain, 
  questionNumber: questionNumber, 
  questionText: questionText, 
  score: 0.0
 );
}

// Level2QuestionnaireData (Level 2)
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
  "Depression": [
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
  "Anger": [
   // Level 2 questions for Anger
   Level2QuestionnaireData("II", "A1", "In the past seven days were you irritated more than people knew?"),
   Level2QuestionnaireData("II", "A2", "In the past seven days, have you felt angry?"),
   Level2QuestionnaireData("II", "A3", " In the past seven days, have you felt like you were ready to explode?"),
   Level2QuestionnaireData("II", "A4", "In the past seven days, were you grouchy?"),
   Level2QuestionnaireData("II", "A5", "In the past seven days, have you felt annoyed?"),
   
  ],
  "Anxiety": [
   Level2QuestionnaireData("IV", "AN1", "In the past seven days, have you felt fearful?"),
   Level2QuestionnaireData("IV", "AN2", "In the past seven days, have you felt anxious?"),
   Level2QuestionnaireData("IV", "AN3", "In the past seven days, have you felt worried?"),
   Level2QuestionnaireData("IV", "AN4", "In the past seven days, have you found it hard to focus on anything other than my anxiety?"),
   Level2QuestionnaireData("IV", "AN5", "In the past seven days, have you felt nervous?"),
   Level2QuestionnaireData("IV", "AN6", "In the past seven days, have you felt uneasy?"),
   Level2QuestionnaireData("IV", "AN7", "In the past seven days, have you felt tense?"),

  ],
  "Somatic Symptoms": [
   Level2QuestionnaireData("V", "S1", "During the past 7 days, how much have you been bothered by Stomach Pain?"),
   Level2QuestionnaireData("V", "S2", "During the past 7 days, how much have you been bothered by Back Pain?"),
   Level2QuestionnaireData("V", "S3", "During the past 7 days, how much have you been bothered by Pain in your arms,legs,or joints(knees,hips,etc.)?"),
   Level2QuestionnaireData("V", "S4", "During the past 7 days, how much have you been bothered by Menstrual cramps or other problems with your periods(WOMEN ONLY)?"),
   Level2QuestionnaireData("V", "S5", "During the past 7 days, how much have you been bothered by Headaches?"),
   Level2QuestionnaireData("V", "S6", " During the past 7 days, how much have you been bothered by Chest Pain?"),
   Level2QuestionnaireData("V", "S7", "During the past 7 days, how much have you been bothered by Dizziness?"),
   Level2QuestionnaireData("V", "S8", "During the past 7 days, how much have you been bothered by Fainting Spells?"),
   Level2QuestionnaireData("V", "S9", "During the past 7 days, how much have you been bothered by Feeling your heart pound or race?"),
   Level2QuestionnaireData("V", "S10", " During the past 7 days, how much have you been bothered by Shortness of breath?"),
   Level2QuestionnaireData("V", "S11", "During the past 7 days, how much have you been bothered by pain or problems during sexual intercourse?"),
   Level2QuestionnaireData("V", "S12", "During the past 7 days, how much have you been bothered by constipation,loose bowels or diarrhea?"),
   Level2QuestionnaireData("V", "S13", " During the past 7 days, how much have you been bothered by Nausea,gas or indigestion?"),
   Level2QuestionnaireData("V", "S14", "During the past 7 days, how much have you been bothered by feeling tired or having low energy?"),
   Level2QuestionnaireData("V", "S15", "During the past 7 days, how much have you been bothered by trouble sleeping?"),

  ],
  "Sleep Problems": [ // Domain VIII, mapped to the correct key "Sleep Problems"
   Level2QuestionnaireData("VIII", "SD1", "In the past seven days, was your sleep restless?"),
   Level2QuestionnaireData("VIII", "SD2", "In the past seven days, were you satisfied with your sleep?"),
   Level2QuestionnaireData("VIII", "SD3", "In the past seven days, was your sleep refreshing?"),
   Level2QuestionnaireData("VIII", "SD4", "In the past seven days, have you had difficulty falling asleep?"),
   Level2QuestionnaireData("VIII", "SD5", "In the past seven days, have you had trouble staying asleep?"),
   Level2QuestionnaireData("VIII", "SD6", "In the past seven days, have you had trouble sleeping"),
   Level2QuestionnaireData("VIII", "SD7", "In the past seven days, have you got enough sleep?"),
   Level2QuestionnaireData("VIII", "SD8", " In the past seven days, how was your sleep quality?"),
   

  ],
  "Repetitive Thoughts and Behaviors": [ // Domain X, corrected key name
   Level2QuestionnaireData("X", "R1", "On average, how much time is occupied by unwanted thoughts or behaviours each day?"),
   Level2QuestionnaireData("X", "R2", " How much distress do these thoughts or behaviours cause you?"),
   Level2QuestionnaireData("X", "R3", "How hard is it for you to control these thoughts or behaviours?"),
   Level2QuestionnaireData("X", "R4", "How much do these thoughts or behaviours cause you to avoid doing anything , going any place, or being with anyone?"),
   Level2QuestionnaireData("X", "R5", "How much do these thoughts or behaviours interfere with school,work,or your social or family life?"),
  ],

  "Substance Use": [ // Domain XIII, corrected key name
   Level2QuestionnaireData("XIII", "SU1", "During the past TWO WEEKS, about how often did you use Painkillers(like Vicodin) ON YOUR OWN, that is, without a doctor’s prescription, in greater amounts or longer than prescribed?"),
   Level2QuestionnaireData("XIII", "SU2", "During the past TWO WEEKS, about how often did you use Stimulants(like Ritalin,Adderall) ON YOUR OWN, that is, without a doctor’s prescription, in greater amounts or longer than prescribed?"),
   Level2QuestionnaireData("XIII", "SU3", "During the past TWO WEEKS, about how often did you use Sedatives or tranquilizers (like sleeping pills or Valium) ON YOUR OWN, that is, without a doctor’s prescription, in greater amounts or longer than prescribed?"),
   Level2QuestionnaireData("XIII", "SU4", "During the past TWO WEEKS, about how often did you use Marijuana?"),
   Level2QuestionnaireData("XIII", "SU5", "During the past TWO WEEKS, about how often did you use Cocaine or crack?"),
   Level2QuestionnaireData("XIII", "SU6", "During the past TWO WEEKS, about how often did you use Club drugs (like ecstasy)?"),
   Level2QuestionnaireData("XIII", "SU7", "During the past TWO WEEKS, about how often did you use Hallucinogens (like LSD)?"),
   Level2QuestionnaireData("XIII", "SU8", "During the past TWO WEEKS, about how often did you use Heroin?"),
   Level2QuestionnaireData("XIII", "SU9", "During the past TWO WEEKS, about how often did you use Inhalants or solvents (like glue)?"),
   Level2QuestionnaireData("XIII", "SU10", "During the past TWO WEEKS, about how often did you use Methamphetamine (like speed)"),
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
 child: ConstrainedBox( // NEW: Use ConstrainedBox to ensure a minimum width
    constraints: const BoxConstraints(minWidth: 280),
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
  child: FittedBox( // NEW: Wrap in FittedBox
    fit: BoxFit.scaleDown, // Scale down only if needed
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    ),
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
final String? Function(String?)? validator; 
const CustomTextField({
 super.key,
 required this.label,
 this.isPassword = false,
 this.controller,
 this.validator,
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
   validator: validator,
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
 if (mounted) {
  Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (context) => const AuthScreen()),
  );
 }
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
final GlobalKey<FormState> _formKey = GlobalKey<FormState>(); 
final MockAuthService _authService = MockAuthService();
final TextEditingController _emailController = TextEditingController();
final TextEditingController _passwordController = TextEditingController();
bool _isLoading = false;

void _handleLogin() async {
 if (!_formKey.currentState!.validate()) {
  return; 
 }
 setState(() { _isLoading = true; });

 final user = await _authService.login(
 _emailController.text,
 _passwordController.text,
 );

 setState(() { _isLoading = false; });

 if (user != null) {
 if (mounted) {
  // Navigate to Questionnaire
  Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (context) => const MainDashboard()),
  );
 }
 } else {
 if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Login failed. Check credentials.')),
  );
 }
 }
}

@override
void dispose() {
 _emailController.dispose();
 _passwordController.dispose();
 super.dispose();
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
  child: Form(
   key: _formKey,
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
     validator: (value) { // NEW: Email validator
      if (value == null || value.isEmpty) {
       return 'Email is required.';
      }
      if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
       return 'Please enter a valid email address.';
      }
      return null;
     },
    ),
    CustomTextField(
     label: 'Password',
     isPassword: true,
     controller: _passwordController,
     validator: (value) { // NEW: Password validator
      if (value == null || value.isEmpty) {
       return 'Password is required.';
      }
      if (value.length < 6) {
       return 'Password must be at least 6 characters.';
      }
      return null;
     },
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
final GlobalKey<FormState> _formKey = GlobalKey<FormState>(); // NEW
final MockAuthService _authService = MockAuthService();
final TextEditingController _emailController = TextEditingController();
final TextEditingController _nameController = TextEditingController();
final TextEditingController _ageController = TextEditingController();
final TextEditingController _passwordController = TextEditingController();
final TextEditingController _locationController = TextEditingController();
bool _isLoading = false;

void _handleRegister() async {
 if (!_formKey.currentState!.validate()) {
  return; 
 }
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
void dispose() {
 _emailController.dispose();
 _nameController.dispose();
 _ageController.dispose();
 _passwordController.dispose();
 _locationController.dispose();
 super.dispose();
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
  child: Form(
   key: _formKey,
   child: Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
    const Center(child: Text('MINDGAUGE', style: kTitleStyle)),
    const SizedBox(height: 30),
    CustomTextField(
     label: 'E-mail id',
     controller: _emailController,
     validator: (value) { // NEW: Email validator
      if (value == null || value.isEmpty) {
       return 'Email is required.';
      }
      if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
       return 'Please enter a valid email address.';
      }
      return null;
     },
    ),
    CustomTextField(
     label: 'Name', 
     controller: _nameController,
     validator: (value) => value == null || value.isEmpty ? 'Name is required.' : null,
    ),
    CustomTextField(
     label: 'Age', 
     controller: _ageController,
     validator: (value) => value == null || int.tryParse(value) == null ? 'Please enter a valid age.' : null,
    ),
    CustomTextField(
     label: 'Password', 
     isPassword: true, 
     controller: _passwordController,
     validator: (value) { // NEW: Password validator
      if (value == null || value.isEmpty) {
       return 'Password is required.';
      }
      if (value.length < 6) {
       return 'Password must be at least 6 characters.';
      }
      return null;
     },
    ),
    CustomTextField(
     label: 'Location', 
     controller: _locationController,
     validator: (value) => value == null || value.isEmpty ? 'Location is required.' : null,
    ),
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
 ),
 );
}
}

// 5. MAIN DASHBOARD (Temporary placeholder screen after login/register)
// 5. MAIN DASHBOARD
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final MockSentimentService _sentimentService = MockSentimentService();
  DateTime _focusedDay = DateTime(2025, 10, 13); // Start on Oct 13, 2025 as per image
  DateTime _selectedDay = DateTime(2025, 10, 13);
  List<JournalEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    setState(() {
      _entries = _sentimentService.getAllEntries();
    });
  }
  
  // Navigation for the floating journal button
  void _openJournalingScreen(DateTime date) async {
    final entry = await Navigator.of(context).push<JournalEntry>(
      MaterialPageRoute(
        builder: (context) => JournalingScreen(
          date: date,
          initialEntry: _sentimentService.getEntry(date),
        ),
      ),
    );

    if (entry != null) {
      _sentimentService.saveEntry(entry);
      _loadEntries(); // Refresh data after saving
      setState(() {
        _selectedDay = entry.date;
        _focusedDay = entry.date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Find the journal entry for the currently selected day
    final JournalEntry? currentEntry = _sentimentService.getEntry(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MINDGAUGE'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.secondary,
        elevation: 0,
        actions: const [
          // This is the hamburger menu that opens the custom drawer
          CustomDrawerButton(), 
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CALENDAR SECTION ---
            const Text(
              'CALENDAR',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 10),
            SentimentCalendar(
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              journalEntries: _entries,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay; 
                });
              },
            ),

            // --- JOURNAL SNIPPET SECTION ---
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Journal',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    const SizedBox(width: 8),
                    // Icon that matches the screenshot
                    Icon(Icons.calendar_month, color: AppColors.secondary.withOpacity(0.7)), 
                  ],
                ),
                Text(
                  '${_selectedDay.day}/${_selectedDay.month}',
                  style: const TextStyle(fontSize: 16, color: AppColors.text),
                ),
              ],
            ),
            const SizedBox(height: 10),
            JournalSnippetCard(
              entry: currentEntry,
              selectedDate: _selectedDay,
              onTap: () => _openJournalingScreen(_selectedDay),
            ),
            const SizedBox(height: 30), // Reduce space before this button
            Center(
              child: StyledButton(
                text: 'Start Symptom Check-In', // Clear button label
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const QuestionnaireScreen()),
                   );
                },
                color: AppColors.primary,
                shadowColor: AppColors.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openJournalingScreen(DateTime.now()), // Journal for today
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
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
 // Use an empty list as a default if the domain is not found
 late final List<Level2QuestionnaireData> _questions; 
 
 @override
 void initState() {
  super.initState();
  // Correctly access the Level 2 questions map using the domainName string key
  _questions = MockQuestionnaireService._level2Questions[widget.domainScore.domainName] ?? [];  
  
  if (_questions.isEmpty) {
   // Show a message if no questions are found.
   WidgetsBinding.instance.addPostFrameCallback((_) {
    ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(content: Text("Error: No Level 2 questions found for ${widget.domainScore.domainName}.")),
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

      // Display the Level 2 Questionnaire items using the shared widget
      ..._questions.asMap().entries.map((entry) =>
        QuestionnaireItem(data: entry.value, index: entry.key + 1)),
      
      const SizedBox(height: 40),
      Center(
       child: StyledButton(
        text: 'SUBMIT LEVEL 2 ASSESSMENT',
        onPressed: () {
         // In a real app, this is where Level 2 scoring/API submission would occur.
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Level 2 Submission Mocked for ${widget.domainScore.domainName}.')),
         );
         // Navigate back to the results screen after submission
         Navigator.of(context).pop();
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
// --- NEW DATA STRUCTURES FOR JOURNALING/SENTIMENT ---

class SentimentResult {
  final String emoji;
  final double score; // e.g., -1.0 (very negative) to 1.0 (very positive)
  final String description;

  const SentimentResult(this.emoji, this.score, this.description);
}

class JournalEntry {
  final DateTime date;
  final String text;
  final SentimentResult sentiment;

  JournalEntry({
    required this.date,
    required this.text,
    required this.sentiment,
  });
}

// --- MOCK SERVICE LAYER FOR JOURNALING/SENTIMENT ---

class MockSentimentService {
  // Simple deterministic way to mock sentiment analysis
  SentimentResult analyze(String text) {
    if (text.isEmpty) {
      return const SentimentResult("⚪", 0.0, "No entry");
    }
    
    // Simple mock logic based on text length and keyword
    final lengthFactor = min(text.length / 100, 1.0);
    final isNegative = text.toLowerCase().contains('down') || text.toLowerCase().contains('overwhelming') || text.toLowerCase().contains('sad');
    final isPositive = text.toLowerCase().contains('happy') || text.toLowerCase().contains('great') || text.toLowerCase().contains('fun');

    if (isNegative) {
      return const SentimentResult("😞", -0.7, "Feeling low");
    } else if (isPositive) {
      return const SentimentResult("😊", 0.8, "Positive mood");
    }
    
    // Random sentiment for other cases (to show variety in the calendar)
    final randomScore = Random().nextDouble() * 2 - 1; // Range -1.0 to 1.0
    if (randomScore > 0.6) return const SentimentResult("😄", 0.9, "Very happy");
    if (randomScore > 0.2) return const SentimentResult("🙂", 0.4, "Content");
    if (randomScore > -0.2) return const SentimentResult("😐", 0.0, "Neutral");
    if (randomScore > -0.6) return const SentimentResult("😟", -0.4, "A bit worried");
    return const SentimentResult("😢", -0.8, "Feeling sad");
  }

  // Mock function to retrieve a specific entry
  JournalEntry? getEntry(DateTime date) {
    // Mock Data based on the provided calendar image
    final mockEntries = _getMockData();
    try {
      return mockEntries.firstWhere(
          (e) => e.date.year == date.year && e.date.month == date.month && e.date.day == date.day);
    } catch (e) {
      return null;
    }
  }

  // Mock persistence: In a real app, this would be a database or shared preferences.
  final List<JournalEntry> _persistedEntries = _getMockData(); 

  // Function to save an entry
  void saveEntry(JournalEntry entry) {
    // Remove existing entry for the same day (to allow updating)
    _persistedEntries.removeWhere((e) => e.date.isSameDay(entry.date));
    _persistedEntries.add(entry);
    _persistedEntries.sort((a, b) => b.date.compareTo(a.date)); // Sort by newest first
  }

  // Function to get all entries (for the main dashboard view)
  List<JournalEntry> getAllEntries() {
    return List.unmodifiable(_persistedEntries);
  }

  // Mock data to match the screenshot for October 2025
  static List<JournalEntry> _getMockData() {
    return [
      JournalEntry(
          date: DateTime(2025, 10, 2),
          text: "I felt zero motivation. Stayed inside all day, the hours just melting into one another. The feeling of 'can't start' was overwhelming.",
          sentiment: const SentimentResult("😞", -0.7, "Feeling low")),
      JournalEntry(
          date: DateTime(2025, 10, 3),
          text: "Had a small win today by cleaning my room. Felt good to accomplish something. Happy to see the sun.",
          sentiment: const SentimentResult("😊", 0.8, "Positive mood")),
      JournalEntry(
          date: DateTime(2025, 10, 4),
          text: "Very neutral day. Just worked and watched TV. No strong feelings either way.",
          sentiment: const SentimentResult("😐", 0.0, "Neutral")),
      JournalEntry(
          date: DateTime(2025, 10, 7),
          text: "Anxiety was high today. Worried about an upcoming presentation.",
          sentiment: const SentimentResult("😟", -0.4, "A bit worried")),
      JournalEntry(
          date: DateTime(2025, 10, 13),
          text: "An important day. Met with a new professional.",
          sentiment: const SentimentResult("🙂", 0.4, "Content")),
    ];
  }
}

// Extension to help compare DateTime objects by date only
extension DateOnlyCompare on DateTime {
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}
// --- NEW WIDGETS FOR DASHBOARD ---

class SentimentCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final List<JournalEntry> journalEntries;
  final Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;

  const SentimentCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.journalEntries,
    required this.onDaySelected,
  });

  // Simplified custom logic to match the look of the screenshot
  // A real calendar package (like table_calendar) would be used here.
  @override
  Widget build(BuildContext context) {
    // Current date is 2025/10/13
    final now = DateTime(2025, 10, 1);
    final daysInMonth = 31;
    final firstDayOfWeek = 3; // October 1, 2025 is a Wednesday (3rd day: 1-Sun, 2-Mon, 3-Tue, 4-Wed)

    // Simplified list of week day names
    const List<String> weekDays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    // Map to quickly look up emojis for the current month
    final Map<int, String> emojiMap = {
      for (var entry in journalEntries.where((e) => e.date.month == focusedDay.month)) entry.date.day: entry.sentiment.emoji
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          // Month Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'October, ${focusedDay.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Row(
                  children: [
                    Icon(Icons.arrow_drop_up, color: AppColors.secondary, size: 24),
                    Icon(Icons.arrow_drop_down, color: AppColors.secondary, size: 24),
                  ],
                ),
              ],
            ),
          ),
          const Divider(thickness: 1, height: 10),
          
          // Weekday Headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays
                .map((day) => Expanded(
                      child: Center(
                        child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                      ),
                    ))
                .toList(),
          ),
          
          // Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4.0,
              crossAxisSpacing: 4.0,
            ),
            itemCount: daysInMonth + firstDayOfWeek, // Days in October + padding for start day
            itemBuilder: (context, index) {
              if (index < firstDayOfWeek) {
                return Container(); // Padding for days before the 1st
              }

              final dayOfMonth = index - firstDayOfWeek + 1;
              final date = DateTime(focusedDay.year, focusedDay.month, dayOfMonth);
              final isSelected = date.isSameDay(selectedDay);
              final emoji = emojiMap[dayOfMonth] ?? '';
              
              return GestureDetector(
                onTap: () => onDaySelected(date, focusedDay),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isSelected ? AppColors.primary : Colors.transparent,
                      child: Text(
                        '$dayOfMonth',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.text,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (emoji.isNotEmpty)
                      SizedBox( // Use a SizedBox to give the FittedBox a specific area
                        height: 14,
                        width: 25, // Give it a little horizontal breathing room
                        child: FittedBox(
                          fit: BoxFit.scaleDown, // Scale down only if needed
                          child: Text(emoji, style: const TextStyle(fontSize: 14)),
                        ),
                      ),                  
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class JournalSnippetCard extends StatelessWidget {
  final JournalEntry? entry;
  final DateTime selectedDate;
  final VoidCallback onTap;

  const JournalSnippetCard({
    super.key,
    required this.entry,
    required this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasEntry = entry != null;
    
    // Default text if no entry exists
    final String snippetText = hasEntry
        ? entry!.text
        : selectedDate.isSameDay(DateTime.now())
            ? 'Tap to write your thoughts for today.'
            : 'No journal entry for this date.';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(15),
          border: hasEntry ? Border.all(color: AppColors.secondary.withOpacity(0.3)) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasEntry)
              Text(
                'Sentiment: ${entry!.sentiment.emoji} ${entry!.sentiment.description}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: entry!.sentiment.score < 0 ? AppColors.danger : AppColors.primary,
                ),
              ),
            if (hasEntry) const SizedBox(height: 8),
            Text(
              snippetText,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                color: hasEntry ? AppColors.text : AppColors.secondary.withOpacity(0.7),
                fontStyle: hasEntry ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// --- NEW SCREEN FOR JOURNAL ENTRY ---

class JournalingScreen extends StatefulWidget {
  final DateTime date;
  final JournalEntry? initialEntry;

  const JournalingScreen({
    super.key,
    required this.date,
    this.initialEntry,
  });

  @override
  State<JournalingScreen> createState() => _JournalingScreenState();
}

class _JournalingScreenState extends State<JournalingScreen> {
  late final TextEditingController _controller;
  final MockSentimentService _sentimentService = MockSentimentService();
  SentimentResult _currentSentiment = const SentimentResult("⚪", 0.0, "Analyzing...");

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEntry?.text ?? '');
    if (widget.initialEntry != null) {
      _currentSentiment = widget.initialEntry!.sentiment;
    } 
  }



// REMOVED: _analyzeSentiment function. The analysis is now done only in _saveJournal.

void _saveJournal() {
  if (_controller.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Journal entry cannot be empty.')),
    );
    return;
  }

  // NEW: Simulate calling the backend service to get the analysis result
  final analyzedSentiment = _sentimentService.analyze(_controller.text.trim());

  final newEntry = JournalEntry(
    date: widget.date.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0), // Normalize date
    text: _controller.text.trim(),
    sentiment: analyzedSentiment, // Use the result from the "backend" service
  );

  Navigator.of(context).pop(newEntry); // Return the entry to the dashboard
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Journal for ${widget.date.day}/${widget.date.month}/${widget.date.year}'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    'Sentiment: ${_currentSentiment.emoji}',
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _currentSentiment.description,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TextFormField(
                controller: _controller,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: "Write down your thoughts and feelings...",
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: StyledButton(
                text: 'Save Journal Entry',
                onPressed: _saveJournal,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// --- CUSTOM OVERLAY MENU WIDGET (REPLACES HAMBURGER) ---

class CustomDrawerButton extends StatefulWidget {
  const CustomDrawerButton({super.key});

  @override
  State<CustomDrawerButton> createState() => _CustomDrawerButtonState();
}

class _CustomDrawerButtonState extends State<CustomDrawerButton> {
  OverlayEntry? _overlayEntry;

  void _showOverlay(BuildContext context) {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      return;
    }

    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + button.size.height + 5,
        right: 15,
        child: Material(
          color: Colors.transparent,
          child: Container(
            // NEW: Explicitly set the width here to prevent infinite constraints
            width: 200, // You can adjust this width based on your desired look
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column( 
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DrawerButton(text: 'DETECTED ISSUE', color: AppColors.secondary, onTap: _hideOverlay),
                _DrawerButton(text: 'RISK TRENDS', color: AppColors.secondary.withOpacity(0.9), onTap: _hideOverlay),
                _DrawerButton(text: 'RECOMMENDATIONS', color: AppColors.secondary.withOpacity(0.8), onTap: _hideOverlay),
                _DrawerButton(text: 'PROFESSIONALS', color: AppColors.secondary.withOpacity(0.7), onTap: _hideOverlay),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu, color: AppColors.secondary),
      onPressed: () => _showOverlay(context),
    );
  }
}

class _DrawerButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _DrawerButton({required this.text, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onTap();
        // Add navigation logic here
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$text tapped!')));
      },
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }
}