import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'services.dart';
import 'ui_components.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (user != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainDashboard(userProfile: user),
          ),
        );
      } else {
        // This would catch a user who logged in via Firebase Auth but whose
        // profile details (name, age) are missing from the mock database.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed: Profile data missing.')),
        );
      }
    } on String catch (errorCode) {
      setState(() {
        _isLoading = false;
      });
      String message = 'Login failed.';
      if (errorCode == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (errorCode == 'wrong-password') {
        message = 'Wrong password provided.';
      } else {
        message = 'Firebase Error: $errorCode';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  // FIX: Added dispose method
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
          // FIX: Wrapped Column in Form for validation
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(65),
                    child: Image.asset(
                      'assets/mind_gauge_logo.jpg',
                      width: 130,
                      height: 130,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.psychology_outlined,
                          size: 80,
                          color: AppColors.primary,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(child: Text('MINDGAUGE', style: kTitleStyle)),
                const SizedBox(height: 5),
                const Center(
                  child: Text(
                    'Measure your Mental Health Status',
                    style: kSubtitleStyle,
                  ),
                ),
                const SizedBox(height: 40),
                CustomTextField(
                  label: 'E-mail id',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
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
                  validator: (value) {
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
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
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
