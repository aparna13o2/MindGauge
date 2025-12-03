import 'package:flutter/material.dart';
import 'dart:math';

// --- MOCK SERVICE LAYER AND DATA STRUCTURES ---
// In a real Flutter app, this data would come from your Flask/Firestore backend.
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

class QuestionnaireData {
  final String questionText;
  double score;
  QuestionnaireData(this.questionText, {this.score = 0.0});
}

class MockQuestionnaireService {
  static List<QuestionnaireData> getInitialQuestions() {
    return [
      QuestionnaireData("Qn 1. Little interest or pleasure in doing things?"),
      QuestionnaireData("Qn 2. Feeling down, depressed, or hopeless?"),
      QuestionnaireData("Qn 3. Feeling more irritated, grouchy, or angry than usual?"),
      QuestionnaireData("Qn 4. Sleeping less than usual, but still have a lot of energy?"),
      QuestionnaireData("Qn 5. Starting lots more projects than usual or doing more risky things than usual?"),
      QuestionnaireData("Qn 6. Feeling nervous, anxious, frightened, worried, or on edge?"),
      QuestionnaireData("Qn 7. Feeling panic or being frightened?"),
      QuestionnaireData("Qn 8. Avoiding situations that make you anxious?"),
      QuestionnaireData("Qn 9. Unexplained aches and pains (e.g., head, back, joints, abdomen, legs)?"),
      QuestionnaireData("Qn 10.Feeling that your illnesses are not being taken seriously enough?"),
      QuestionnaireData("Qn 11.Thoughts of actually hurting yourself?"),
      QuestionnaireData("Qn 12.Feeling that your illnesses are not being taken seriously enough?"),
      QuestionnaireData("Qn 13.Feeling that someone could hear your thoughts, or that you could hear what another person was thinking?"),
      QuestionnaireData("Qn 14. Problems with sleep that affected your sleep quality over all?"),
      QuestionnaireData("Qn 15.Problems with memory (e.g., learning new information) or with location (e.g., finding your way home)?"),
      QuestionnaireData("Qn 16.Unpleasant thoughts, urges, or images that repeatedly enter your mind?"),
      QuestionnaireData("Qn 17.Feeling driven to perform certain behaviors or mental acts over and over again?"),
      QuestionnaireData("Qn 18.Feeling detached or distant from yourself, your body, your physical surroundings, or your memories?"),
      QuestionnaireData("Qn 19. Not knowing who you really are or what you want out of life?"),
      QuestionnaireData("Qn 20.Not feeling close to other people or enjoying your relationships with them?"),
      QuestionnaireData("Qn 21. Drinking at least 4 drinks of any kind of alcohol in a single day?"),
      QuestionnaireData("Qn 22.Smoking any cigarettes, a cigar, or pipe, or using snuff or chewing tobacco?"),
      QuestionnaireData("Qn 23. Using any of the following medicines on your own, that is, without a doctor's prescription, in greater amounts or longer than prescribed [e.g., painkillers (like Vicodin), stimulants (like Ritalin or Adderall), sedatives or tranquilizers (like sleeping pills or Valium), or drugs like marijuana, cocaine or crack, club drugs (like ecstasy), hallucinogens (like LSD), heroin, inhalants or solvents (like glue), or methamphetamine (like speed)]?"),



    ];
  }

  Future<String> submitQuestionnaire(List<QuestionnaireData> responses) async {
    // Mock AI analysis and return a result
    await Future.delayed(const Duration(seconds: 2));
    final totalScore = responses.fold(0.0, (sum, item) => sum + item.score);
    if (totalScore > 15) return "SEVERE DEPRESSION";
    if (totalScore > 10) return "MODERATE ANXIETY";
    return "MILD STRESS";
  }
}

// --- CONSTANTS & STYLES ---

class AppColors {
  static const Color primary = Color(0xFF00C8C8); // Bright Cyan
  static const Color secondary = Color(0xFF007A7A); // Darker Teal
  static const Color background = Color(0xFFF7FFF7); // Off-White/Minty Background
  static const Color cardColor = Color(0xFFEEF7E8); // Light Green Card
  static const Color text = Color(0xFF2C3E50); // Dark text
  static const Color buttonShadow = Color(0xAA00C8C8);
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
  final MockAuthService _authService = MockAuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
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
                  MaterialPageRoute(builder: (context) => QuestionnaireScreen()),
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
class QuestionnaireItem extends StatefulWidget {
  final QuestionnaireData data;
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
            widget.data.questionText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.people_alt, color: AppColors.secondary),
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
              const Icon(Icons.cloud_queue, color: AppColors.secondary),
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
  String? _result;

  void _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _result = null;
    });

    final result = await _service.submitQuestionnaire(_questions);

    setState(() {
      _isLoading = false;
      _result = result;
    });

    if (mounted) {
      _showResultDialog(result);
    }
  }

  void _showResultDialog(String result) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Assessment Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your recent check-in suggests symptoms of:'),
              const SizedBox(height: 10),
              Text(
                result,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 15),
              const Text('This is a mock result. In the real app, this would be determined by the AI model.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questionnaire'),
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
                  Text('Response Scale:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                  Text('0 - None, not at all'),
                  Text('1 - Slight, rare, less than a day or two'),
                  Text('2 - Mild, several days'),
                  Text('3 - Moderate, more than half the days'),
                  Text('4 - Severe, nearly every day'),
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
                      text: 'SUBMIT',
                      onPressed: _handleSubmit,
                    ),
            ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Center(
                  child: Text('Mock Result: $_result', style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                ),
              ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
