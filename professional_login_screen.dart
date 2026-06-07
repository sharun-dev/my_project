import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'professional_home_screen.dart';
import 'producer_home_screen.dart';
import 'production_screen.dart';

class ProfessionalLoginScreen extends StatefulWidget {
  const ProfessionalLoginScreen({super.key});

  @override
  State<ProfessionalLoginScreen> createState() => _ProfessionalLoginScreenState();
}

class _ProfessionalLoginScreenState extends State<ProfessionalLoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;
  late AnimationController _logoAnimationController;
  late Animation<double> _logoProgressAnimation;

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
    _logoProgressAnimation = CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _logoAnimationController.dispose();
    super.dispose();
  }

  Future<void> _attemptProfessionalLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      String email = _emailCtrl.text.trim();
      String password = _passCtrl.text;

      // Sign in with Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      // Fetch professional profile from Firestore
      DocumentSnapshot professionalDoc = await _firestore
          .collection('profession')
          .doc(userCredential.user!.uid)
          .get();

      if (!mounted) return;

      if (!professionalDoc.exists) {
        _showErrorSnackBar('Professional profile not found. Please complete your profile.');
        return;
      }

      Map<String, dynamic> profileData = professionalDoc.data() as Map<String, dynamic>;
      String status = (profileData['status'] as String?)?.toLowerCase() ?? 'pending';

      if (status == 'pending') {
        _showErrorSnackBar('Your account is pending admin approval');
        await _auth.signOut();
        return;
      }

      if (status == 'rejected') {
        final reason = (profileData['rejectionReason'] as String?)?.trim();
        _showErrorSnackBar(
          reason != null && reason.isNotEmpty
              ? 'Account rejected: $reason'
              : 'Your account has been rejected',
        );
        await _auth.signOut();
        return;
      }

      String role = profileData['role'] ?? 'Professional';

      // Create user data from Firestore
      Map<String, dynamic> userData = {
        'id': userCredential.user!.uid,
        'name': profileData['name'] ?? '',
        'email': email,
        'role': role,
        'location': profileData['location'] ?? '',
        'bio': profileData['bio'] ?? '',
        'experience': profileData['experience'] ?? '',
        'skills': profileData['skills'] ?? [],
        'specialization': profileData['specialization'] ?? '',
        'previousWorks': profileData['previousWorks'] ?? '',
        'fullName': profileData['fullName'] ?? profileData['name'] ?? '',
        'awards': profileData['awards'] ?? '',
        'physicalAttributes': profileData['physicalAttributes'] ?? '',
        'socialLinks': profileData['socialLinks'] ?? '',
        'company': profileData['company'] ?? '',
        'previousProjects': profileData['previousProjects'] ?? [],
      };

      // Navigate based on role sets
      final roleNormalized = role.trim().toLowerCase();

      final producerRoles = {
        'producer',
        'director',
        'casting director',
      };

      final professionalRoles = {
        'actor',
        'actors',
        'cinematographer',
        'cinimatographer', // tolerate common misspelling
        'editor',
        'sound designer',
        'screen writer',
        'screenwriter',
      };

      if (producerRoles.contains(roleNormalized)) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProducerHomeScreen(role: role, userData: userData, uid: userCredential.user!.uid),
          ),
        );
      } else if (professionalRoles.contains(roleNormalized)) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfessionalHomeScreen(role: role, userData: userData, uid: userCredential.user!.uid),
          ),
        );
      } else if (roleNormalized == 'production house') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProductionScreen(uid: userCredential.user!.uid),
          ),
        );
      } else {
        // Fallback to ProfessionalHomeScreen for any other roles
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfessionalHomeScreen(role: role, userData: userData, uid: userCredential.user!.uid),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = 'Login failed';

      if (e.code == 'user-not-found') {
        errorMessage = 'No account found with this email. Please register first.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password. Please try again.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Too many login attempts. Please try again later.';
      }

      _showErrorSnackBar(errorMessage);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('An error occurred: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your email';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(v.trim())) return 'Please enter a valid email';
    return null;
  }

  String? _passValidator(String? v) {
    if (v == null || v.isEmpty) return 'Please enter your password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const purpleA = Color(0xFF9D4EDD);
    const purpleB = Color(0xFF7B2CBF);
    const accent = Color(0xFFE0AAFF);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F1B),
              Color(0xFF1E1B2E),
              Color(0xFF2D1B3E),
              Color(0xFF3C1B4E),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Section
                  _buildHeader(),
                  const SizedBox(height: 40),

                  // Login Form Card
                  _buildLoginForm(purpleA, purpleB, accent),
                  const SizedBox(height: 24),

                  // Back to User Login
                  _buildBackToUserLogin(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: AnimatedBuilder(
            animation: _logoProgressAnimation,
            builder: (context, child) {
              final progress = _logoProgressAnimation.value;
              final radius = 35.0 * (1 - progress);
              final angle = 2 * pi * progress * 1.5;
              final offset = Offset(cos(angle), sin(angle)) * radius;

              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: offset,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.8),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        image: const DecorationImage(
                          image: AssetImage('lib/assets/logos.jpeg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            child: const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 30),
        
        // Welcome Text
        const Text(
          'Professional Login',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        
        // Subtitle
        const Text(
          'Sign in as Actor, Director, Producer or Crew',
          style: TextStyle(
            color: Color(0xFFBFA3E6),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        
        // Decorative Line
        Container(
          height: 3,
          width: 60,
          margin: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE0AAFF),
                Color(0xFF9D4EDD),
              ],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(Color purpleA, Color purpleB, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B12).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Email Field
            _buildTextField(
              controller: _emailCtrl,
              validator: _emailValidator,
              hintText: 'Professional Gmail',
              prefixIcon: Icons.alternate_email_rounded,
              accent: accent,
            ),
            const SizedBox(height: 20),

            // Password Field
            _buildPasswordField(accent),
            const SizedBox(height: 24),

            // Login Button
            _buildLoginButton(purpleA, purpleB),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String? Function(String?) validator,
    required String hintText,
    required IconData prefixIcon,
    required Color accent,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        prefixIcon: Icon(prefixIcon, color: accent, size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent.withOpacity(0.8), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.6)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.8)),
        ),
      ),
    );
  }

  Widget _buildPasswordField(Color accent) {
    return TextFormField(
      controller: _passCtrl,
      validator: _passValidator,
      obscureText: _obscure,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: accent, size: 22),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: Colors.white.withOpacity(0.6),
            size: 22,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent.withOpacity(0.8), width: 2),
        ),
      ),
    );
  }

  Widget _buildLoginButton(Color purpleA, Color purpleB) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: purpleA.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _attemptProfessionalLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: purpleA,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 24,
          child: Center(
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'SIGN IN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackToUserLogin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Back to ',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'User Login',
            style: TextStyle(
              color: Color(0xFFE0AAFF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
