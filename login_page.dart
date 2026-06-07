import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_home_screen.dart';
import 'register_page.dart';
import 'professional_login_screen.dart';
import 'admin_screen.dart';
import 'professional_home_screen.dart';
import 'producer_home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
 
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;
  late AnimationController _borderAnimationController;
  late Animation<Color?> _borderColorAnimation;
  late AnimationController _logoAnimationController;
  late Animation<double> _logoProgressAnimation;

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    _borderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _borderColorAnimation = ColorTween(
      begin: const Color(0xFF9D4EDD),
      end: const Color(0xFF7B2CBF),
    ).animate(
      CurvedAnimation(
        parent: _borderAnimationController,
        curve: Curves.easeInOut,
      ),
    );

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
    _borderAnimationController.dispose();
    _logoAnimationController.dispose();
    super.dispose();
  }

  Future<void> _attemptLogin() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;

      final currentUser = _auth.currentUser!;
      final isAdmin = currentUser.email?.toLowerCase() == 'sigs@gmail.com';

      if (isAdmin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        );
        return;
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final profDoc = await _firestore
          .collection('profession')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final status = (data['status'] as String?)?.toLowerCase() ?? 'pending';

        if (status == 'verified') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const UserHomeScreen()),
          );
          return;
        }

        if (status == 'pending') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account is pending admin approval'),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (status == 'rejected') {
          final reason = (data['rejectionReason'] as String?)?.trim();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                reason != null && reason.isNotEmpty
                    ? 'Account rejected: $reason'
                    : 'Your account has been rejected',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been rejected'),
              backgroundColor: Colors.red,
            ),
          );
        }

        await _auth.signOut();
        return;
      }

      if (profDoc.exists) {
        final data = profDoc.data()!;
        final status = (data['status'] as String?)?.toLowerCase() ?? 'pending';

        if (status == 'verified') {
          final role = data['role'] ?? '';
          final userData = {
            'id': currentUser.uid,
            'name': data['name'] ?? data['username'] ?? 'Professional',
            'email': data['email'] ?? currentUser.email ?? '',
            'phone': data['phone'] ?? '',
            'location': data['location'] ?? '',
            'socialMedia': data['socialMedia'] ?? '',
            'role': role,
          };

          if (['Producer', 'Director', 'Casting Director'].contains(role)) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ProducerHomeScreen(
                  role: role,
                  userData: userData,
                  uid: currentUser.uid,
                ),
              ),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ProfessionalHomeScreen(
                  role: role,
                  userData: userData,
                  uid: currentUser.uid,
                ),
              ),
            );
          }
          return;
        }

        if (status == 'pending') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account is pending admin approval'),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (status == 'rejected') {
          final reason = (data['rejectionReason'] as String?)?.trim();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                reason != null && reason.isNotEmpty
                    ? 'Account rejected: $reason'
                    : 'Your account has been rejected',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been rejected'),
              backgroundColor: Colors.red,
            ),
          );
        }

        await _auth.signOut();
        return;
      }

      // If user has no structured profile data, deny access until admin configures it
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No account record found. Please contact admin.'),
          backgroundColor: Colors.red,
        ),
      );
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = 'Login failed';

      if (e.code == 'user-not-found') {
        errorMessage = 'No account found with this email';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled';
      } else {
        errorMessage = e.message ?? 'An error occurred';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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

  void _navigateToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  void _navigateToProfessionalLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfessionalLoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    const purpleA = Color(0xFF9D4EDD);
    const purpleB = Color(0xFF7B2CBF);
    const accent = Color(0xFFE0AAFF);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('lib/assets/cover.jpeg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black54,
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Section
                  _buildHeader(),
                  const SizedBox(height: 40),

                  // Login Form Card
                  _buildLoginForm(purpleA, purpleB, accent),
                  const SizedBox(height: 24),

                  // Register Section
                  _buildRegisterSection(),
                  const SizedBox(height: 24),

                  // Professional Login Section
                  _buildProfessionalLoginSection(),
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
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: _logoProgressAnimation,
            builder: (context, child) {
              final progress = _logoProgressAnimation.value;
              final radius = 50.0 * (1 - progress);
              final angle = 2 * pi * progress * 1.5;
              final offset = Offset(cos(angle), sin(angle)) * radius;

              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: offset,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.8),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
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
        const SizedBox(height: 40),

        // Welcome Text
        const Text(
          'Welcome Back',
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
          'Sign in to continue to FilmSphere',
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
              colors: [Color(0xFFE0AAFF), Color(0xFF9D4EDD)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(Color purpleA, Color purpleB, Color accent) {
    return AnimatedBuilder(
      animation: _borderColorAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B12).withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _borderColorAnimation.value ?? const Color(0xFF9D4EDD),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (_borderColorAnimation.value ?? purpleB).withOpacity(0.35),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: (_borderColorAnimation.value ?? purpleB).withOpacity(0.18),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Email Field
            _buildTextField(
              controller: _emailCtrl,
              validator: _emailValidator,
              hintText: 'Email Address',
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
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 16,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        prefixIcon: Icon(prefixIcon, color: accent, size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          // ignore: deprecated_member_use
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
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 16,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
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
        onPressed: _loading ? null : _attemptLogin,
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
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
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

  Widget _buildRegisterSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        GestureDetector(
          onTap: _navigateToRegister,
          child: const Text(
            'Create one',
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

  Widget _buildProfessionalLoginSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Professional Login : ',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        GestureDetector(
          onTap: _navigateToProfessionalLogin,
          child: const Text(
            'Click here',
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
