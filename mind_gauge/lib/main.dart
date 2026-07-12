import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'ui_components.dart';
import 'services.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';

// --- CONFIGURATION ---
// Global instance of FirebaseAuth
final FirebaseAuth _auth = FirebaseAuth.instance;
// const String _apiBaseUrl = 'http://172.16.7.248:5000'; // Define API URL if needed later

// --- SERVICE LAYER AND DATA STRUCTURES ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
        scaffoldBackgroundColor: Colors.transparent, // Let background wrapper show through
        useMaterial3: true,
      ),
      builder: (context, child) {
        return GlobalBackgroundWrapper(child: child!);
      },
      home: const SplashScreen(),
    );
  }
}

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
    _wakeUpRender();
    _navigate();
  }

  void _wakeUpRender() {
    try {
      // Fire-and-forget request to wake up Render's free tier
      http.get(Uri.parse('https://mind-gauge-api.onrender.com/test'))
          .timeout(const Duration(seconds: 5))
          .catchError((_) => http.Response('Error', 500));
    } catch (_) {
      // Ignore any errors, this is just a ping
    }
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }

    final profile = UserProfile.fromDatabase(doc.data()!, user);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainDashboard(userProfile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(75),
              child: Image.asset(
                'assets/mind_gauge_logo.jpg',
                width: 150,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.psychology_outlined,
                    size: 150,
                    color: AppColors.primary,
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            const Text('MINDGAUGE', style: kTitleStyle),
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  void _navigateToRegister(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(75),
                child: Image.asset(
                  'assets/mind_gauge_logo.jpg',
                  width: 150,
                  height: 150,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.psychology_outlined,
                      size: 150,
                      color: AppColors.primary,
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text('MINDGAUGE', style: kTitleStyle),
              const SizedBox(height: 5),
              const Text(
                'Measure your Mental Health Status',
                style: kSubtitleStyle,
              ),
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

// 4. REGISTER SCREEN
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final FocusNode _locationFocusNode = FocusNode();
  DateTime? _selectedBirthDate;
  bool _isLoading = false;

  static const List<String> _indianCities = [
    'Mumbai',
    'Delhi',
    'Bangalore',
    'Hyderabad',
    'Ahmedabad',
    'Chennai',
    'Kolkata',
    'Surat',
    'Pune',
    'Jaipur',
    'Lucknow',
    'Kanpur',
    'Nagpur',
    'Indore',
    'Thane',
    'Bhopal',
    'Visakhapatnam',
    'Pimpri-Chinchwad',
    'Patna',
    'Vadodara',
    'Ghaziabad',
    'Ludhiana',
    'Agra',
    'Nashik',
    'Faridabad',
    'Meerut',
    'Rajkot',
    'Kalyan-Dombivli',
    'Vasai-Virar',
    'Varanasi',
    'Srinagar',
    'Aurangabad',
    'Dhanbad',
    'Amritsar',
    'Navi Mumbai',
    'Allahabad',
    'Ranchi',
    'Howrah',
    'Coimbatore',
    'Jabalpur',
    'Gwalior',
    'Vijayawada',
    'Jodhpur',
    'Madurai',
    'Raipur',
    'Kota',
    'Guwahati',
    'Chandigarh',
    'Solapur',
    'Hubli-Dharwad',
    'Bareilly',
    'Moradabad',
    'Mysore',
    'Gurgaon',
    'Aligarh',
    'Jalandhar',
    'Tiruchirappalli',
    'Bhubaneswar',
    'Salem',
    'Mira-Bhayandar',
    'Thiruvananthapuram',
    'Bhiwandi',
    'Saharanpur',
    'Guntur',
    'Amravati',
    'Bikaner',
    'Noida',
    'Jamshedpur',
    'Bhilai',
    'Cuttack',
    'Firozabad',
    'Kochi',
    'Nellore',
    'Bhavnagar',
    'Dehradun',
    'Durgapur',
    'Asansol',
    'Rourkela',
    'Nanded',
    'Kolhapur',
    'Ajmer',
    'Akola',
    'Gulbarga',
    'Jamnagar',
    'Ujjain',
    'Loni',
    'Siliguri',
    'Jhansi',
    'Ulhasnagar',
    'Nellore',
    'Jammu',
    'Sangli-Miraj & Kupwad',
    'Belgaum',
    'Mangalore',
    'Ambattur',
    'Tirunelveli',
    'Malegaon',
    'Gaya',
    'Jalgaon',
    'Udaipur',
    'Maheshtala',
    'Davangere',
    'Kozhikode',
    'Kurnool',
    'Rajpur Sonarpur',
    'Rajahmundry',
    'Bokaro',
    'South Dumdum',
    'Bellary',
    'Patiala',
    'Gopalpur',
    'Agartala',
    'Bhagalpur',
    'Muzaffarnagar',
    'Bhatpara',
    'Panihati',
    'Latur',
    'Dhule',
    'Rohtak',
    'Korba',
    'Bhilwara',
    'Brahmapur',
    'Muzaffarpur',
    'Ahmednagar',
    'Mathura',
    'Kollam',
    'Avadi',
    'Kadapa',
    'Kamarhati',
    'Sambalpur',
    'Bilaspur',
    'Shahjahanpur',
    'Satara',
    'Bijapur',
    'Rampur',
    'Shimoga',
    'Chandrapur',
    'Junagadh',
    'Thrissur',
    'Alwar',
    'Bardhaman',
    'Kulti',
    'Kakinada',
    'Nizamabad',
    'Parbhani',
    'Tumkur',
    'Khammam',
    'Uzhavarkarai',
    'Bihar Sharif',
    'Panipat',
    'Darbhanga',
    'Bally',
    'Aizawl',
    'Dewas',
    'Ichalkaranji',
    'Karnal',
    'Bathinda',
    'Jalna',
    'Eluru',
    'Barasat',
    'Kirari Suleman Nagar',
    'Purnia',
    'Satna',
    'Mau',
    'Sonipat',
    'Farrukhabad',
    'Sagar',
    'Rourkela',
    'Durg',
    'Imphal',
    'Ratlam',
    'Hapur',
    'Arrah',
    'Anantapur',
    'Karimnagar',
    'Etawah',
    'Ambernath',
    'Bharatpur',
    'Begusarai',
    'New Delhi',
    'Gandhidham',
    'Baranagar',
    'Tiruppur',
    'Puducherry',
    'Gandhinagar',
    'Mirzapur',
    'Anantapur',
    'Ramagundam',
    'Haridwar',
    'Navsari',
    'Vijayanagaram',
    'Haldia',
    'Khandwa',
    'Nagercoil',
    'Kannur',
    'Roorkee',
    'Kumbakonam',
    'Bagalkot',
    'Bhimavaram',
    'Palakkad',
    'Alappuzha',
    'Kottayam',
    'Malappuram',
    'Kasargod',
    'Pathanamthitta',
    'Idukki',
    'Wayanad',
    'Shimla',
    'Dharamshala',
    'Mandi',
    'Solan',
    'Hamirpur',
    'Una',
    'Chamba',
    'Kullu',
    'Bilaspur',
    'Sirmour',
    'Kangra',
    'Kinnaur',
    'Lahaul & Spiti',
    'Gangtok',
    'Namchi',
    'Gyalshing',
    'Mangan',
    'Shillong',
    'Tura',
    'Jowai',
    'Nongpoh',
    'Williamnagar',
    'Kohima',
    'Dimapur',
    'Mokokchung',
    'Tuensang',
    'Wokha',
    'Zunheboto',
    'Mon',
    'Phek',
    'Longleng',
    'Kiphire',
    'Peren',
    'Itanagar',
    'Naharlagun',
    'Pasighat',
    'Roing',
    'Tezu',
    'Ziro',
    'Bomdila',
    'Tawang',
    'Daporijo',
    'Khonsa',
    'Changlang',
    'Anini',
    'Yingkiong',
    'Port Blair',
    'Kavaratti',
    'Daman',
    'Diu',
    'Silvassa',
    'Panaji',
    'Vasco da Gama',
    'Margao',
    'Mapusa',
    'Ponda',
    'Bicholim',
    'Curchorem',
    'Pernem',
    'Canacona',
    'Valpoi',
    'Quepem',
    'Sanguem',
    'Sanquelim',
    'Leh',
    'Kargil',
  ];

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedBirthDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your birthdate.')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProfile = await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text,
        birthDate: _selectedBirthDate!,
        location: _locationController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registration successful! Welcome, ${userProfile.name}. Please log in.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } on String catch (errorCode) {
      setState(() {
        _isLoading = false;
      });

      String message = 'Registration failed. Please try again.';
      if (errorCode == 'email-already-in-use') {
        message = 'The email address is already in use.';
      } else if (errorCode == 'weak-password') {
        message = 'The password must be at least 6 characters.';
      } else if (errorCode == 'invalid-email') {
        message = 'The email address is not valid.';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      }
    }
  }

  // FIX: Added dispose method
  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _locationController.dispose();
    _locationFocusNode.dispose();
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
                const SizedBox(height: 20),
                Center(
                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(65),
                  child: Image.asset(
                    'assets/mind_gauge_logo.jpg',
                    width: 130,
                    height: 130,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.psychology_outlined,
                        size: 130,
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
                    if (value!.isEmpty) return 'Email is required';
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                CustomTextField(
                  label: 'Name',
                  controller: _nameController,
                  validator: (value) =>
                      value!.isEmpty ? 'Name is required' : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Birthdate',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.primary,
                                    onPrimary: Colors.white,
                                    onSurface: AppColors.secondary,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            setState(() => _selectedBirthDate = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedBirthDate != null
                                    ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
                                    : 'Select Birthdate',
                                style: TextStyle(
                                  color: _selectedBirthDate != null
                                      ? AppColors.text
                                      : Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today,
                                color: AppColors.secondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CustomTextField(
                  label: 'Password',
                  isPassword: true,
                  controller: _passwordController,
                  validator: (value) => value!.length < 6
                      ? 'Password must be at least 6 chars'
                      : null,
                ),

                // --- CITY AUTOCOMPLETE ---
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      RawAutocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return _indianCities.where((String option) {
                            return option.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                          });
                        },
                        textEditingController: _locationController,
                        focusNode: _locationFocusNode,
                        onSelected: (String selection) {
                          _locationController.text = selection;
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                style: const TextStyle(color: AppColors.text),
                                validator: (value) =>
                                    (value == null || value.isEmpty)
                                    ? 'Location is required'
                                    : null,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                      color: AppColors.danger,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                width:
                                    MediaQuery.of(context).size.width -
                                    60, // Match padding
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                        final String option = options.elementAt(
                                          index,
                                        );
                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(
                                              option,
                                              style: const TextStyle(
                                                color: AppColors.text,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
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
