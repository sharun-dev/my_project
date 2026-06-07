import 'dart:math';
import 'package:flutter/material.dart';
import 'login_page.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _particleAnimation;
  late final Animation<double> _rotationAnimation;
  late final Animation<double> _textRevealAnimation;
  late final Animation<double> _filmReelAnimation;
  late final Animation<double> _buttonScaleAnimation;
  late final AnimationController _borderController;
  late final Animation<double> _borderRotationAnimation;
  late final Animation<double> _textGlowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _particleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _textRevealAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _filmReelAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _borderRotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(CurvedAnimation(parent: _borderController, curve: Curves.linear));

    _textGlowAnimation = Tween<double>(
      begin: 0.25,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _borderController, curve: Curves.easeInOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _borderController.dispose();
    super.dispose();
  }

  void _navigateToNextPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image asset
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/cover.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Optional gradient overlay for cinematic mood
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x330F0F1B),
                  Color(0x331E1B2E),
                  Color(0x332D1B3E),
                ],
              ),
            ),
          ),

          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9D4EDD), Color(0xFF7B2CBF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x299D4EDD),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'lib/assets/logos.jpeg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        const Text(
                          'FILM SPHERE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Talent meets Opportunity',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _navigateToNextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9D4EDD),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 6,
                            ),
                            child: const Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Floating film frames
          ...List.generate(6, (index) {
            return Positioned(
              top: 100 + index * 120,
              left: index.isEven ? -50 : null,
              right: index.isOdd ? -50 : null,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _controller.value * (index.isEven ? 0.5 : -0.3),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        20 * sin((_controller.value * 2 + index).toDouble()),
                      ),
                      child: Opacity(opacity: 0.1, child: child),
                    ),
                  );
                },
                child: Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF9D4EDD).withOpacity(0.4),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFE0AAFF).withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),

          // Cinematic light beams
          ...List.generate(4, (index) {
            return Positioned(
              top: 200 + index * 150,
              left: 0,
              child: AnimatedBuilder(
                animation: _particleAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      0,
                      50 *
                          sin(
                            (_particleAnimation.value * 3 + index).toDouble(),
                          ),
                    ),
                    child: Opacity(
                      opacity:
                          0.05 +
                          0.05 *
                              sin(
                                (_particleAnimation.value * 2 + index)
                                    .toDouble(),
                              ),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF9D4EDD).withOpacity(0.3),
                        const Color(0xFF7B2CBF).withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilmReels() {
    return Stack(
      children: [
        // Left film reel
        Positioned(
          left: -60,
          top: MediaQuery.of(context).size.height * 0.3,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 4 * 3.14159,
                child: child,
              );
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF9D4EDD).withOpacity(0.4),
                  width: 3,
                ),
              ),
              child: CustomPaint(painter: _FilmReelPainter()),
            ),
          ),
        ),

        // Right film reel
        Positioned(
          right: -60,
          top: MediaQuery.of(context).size.height * 0.6,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: -_controller.value * 4 * 3.14159,
                child: child,
              );
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF7B2CBF).withOpacity(0.4),
                  width: 3,
                ),
              ),
              child: CustomPaint(painter: _FilmReelPainter()),
            ),
          ),
        ),

        // Moving film strip
        Positioned(
          top: MediaQuery.of(context).size.height * 0.5,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _filmReelAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-100 + 200 * _filmReelAnimation.value, 0),
                child: child,
              );
            },
            child: Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                border: Border.all(
                  color: const Color(0xFF9D4EDD).withOpacity(0.5),
                ),
              ),
              child: Row(
                children: List.generate(8, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFE0AAFF).withOpacity(0.3),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
            ),
          ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Premium indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9D4EDD), Color(0xFF7B2CBF)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9D4EDD).withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.star_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'PREMIUM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Cinematic indicator
          const Text(
            'CINEMATIC EDITION',
            style: TextStyle(
              color: Color(0xFFE0AAFF),
              fontSize: 12,
              fontWeight: FontWeight.w300,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentralContent() {
    return Column(
      children: [
        // Main sphere logo with film elements
        _buildFilmSphereLogo(),

        const SizedBox(height: 40),

        // App name with cinematic typography
        _buildAppName(),

        const SizedBox(height: 20),

        // Description
        _buildDescription(),
      ],
    );
  }

  Widget _buildFilmSphereLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow
        AnimatedBuilder(
          animation: _particleAnimation,
          builder: (context, child) {
            return Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9D4EDD).withOpacity(
                      0.3 + 0.2 * sin(_particleAnimation.value * 6.283),
                    ),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            );
          },
        ),

        // Rotating film ring
        AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF9D4EDD).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: CustomPaint(painter: _FilmStripRingPainter()),
          ),
        ),

        // Main sphere
        ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF9D4EDD),
                    Color(0xFF7B2CBF),
                    Color(0xFF5A189A),
                  ],
                  stops: [0.1, 0.6, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9D4EDD).withOpacity(0.6),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(painter: _FilmSphereLogoPainter()),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppName() {
    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedBuilder(
        animation: Listenable.merge([_textRevealAnimation, _textGlowAnimation]),
        builder: (context, child) {
          final glow = _textGlowAnimation.value;
          return Column(
            children: [
              // Main title
              Text(
                'FILM SPHERE',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  color: Colors.white.withOpacity(0.95 + 0.05 * glow),
                  shadows: [
                    Shadow(
                      color: const Color(0xFF9D4EDD).withOpacity(0.3 + glow * 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 0),
                    ),
                    Shadow(
                      color: const Color(0xFF7B2CBF).withOpacity(0.15 + glow * 0.3),
                      blurRadius: 40,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Animated underline
              Container(
                height: 3,
                width: 120 * _textRevealAnimation.value,
                decoration: BoxDecoration(
                  gradient: SweepGradient(
                    colors: const [Color(0xFFE0AAFF), Color(0xFF9D4EDD), Color(0xFFE0AAFF)],
                    stops: const [0.0, 0.5, 1.0],
                    transform: GradientRotation(_borderRotationAnimation.value),
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9D4EDD).withOpacity(0.45 + glow * 0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDescription() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: const Text(
        'The premier digital ecosystem connecting cinematic talent with global opportunities in the film industry.',
        style: TextStyle(
          color: Color(0xFFE0AAFF),
          fontSize: 16,
          height: 1.6,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActionSection() {
    return Column(
      children: [
        // Main CTA button
        ScaleTransition(
          scale: _buttonScaleAnimation,
          child: AnimatedBuilder(
            animation: _borderRotationAnimation,
            builder: (context, child) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  gradient: SweepGradient(
                    colors: const [
                      Color(0xFF9D4EDD),
                      Color(0xFF7B2CBF),
                      Color(0xFF9D4EDD),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    transform: GradientRotation(_borderRotationAnimation.value),
                  ),
                ),
                child: child,
              );
            },
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9D4EDD).withOpacity(0.35),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _navigateToNextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D4EDD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 32,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'ENTER STUDIO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedBuilder(
                      animation: _borderRotationAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFFFFF).withOpacity(
                                0.6 + 0.3 * (_textGlowAnimation.value),
                              ),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9D4EDD)
                                    .withOpacity(0.25 + 0.2 * _textGlowAnimation.value),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: const Icon(Icons.arrow_forward_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Trust indicators
        FadeTransition(
          opacity: _fadeAnimation,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: Color(0xFFE0AAFF),
                size: 14,
              ),
              SizedBox(width: 8),
              Text(
                'Secure • Professional • Industry-Standard',
                style: TextStyle(
                  color: Color(0xFFE0AAFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilmReelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF9D4EDD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw reel holes
    const int holes = 8;
    final holeRadius = size.width * 0.08;
    for (int i = 0; i < holes; i++) {
      final angle = 2 * pi * i / holes;
      final dx = center.dx + cos(angle) * size.width * 0.3;
      final dy = center.dy + sin(angle) * size.width * 0.3;
      canvas.drawCircle(Offset(dx, dy), holeRadius, paint);
    }

    // Center circle
    canvas.drawCircle(center, size.width * 0.1, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FilmStripRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFE0AAFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw film strip segments around the ring
    const int segments = 12;
    for (int i = 0; i < segments; i++) {
      final angle = 2 * pi * i / segments;
      final dx = center.dx + cos(angle) * size.width * 0.4;
      final dy = center.dy + sin(angle) * size.width * 0.4;

      final rect = Rect.fromCenter(center: Offset(dx, dy), width: 8, height: 4);

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FilmSphereLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw sphere outline
    canvas.drawCircle(center, size.width * 0.4, paint);

    // Draw film strip wrapping around sphere
    final filmPath = Path();
    filmPath.moveTo(center.dx - size.width * 0.4, center.dy);
    filmPath.quadraticBezierTo(
      center.dx - size.width * 0.2,
      center.dy - size.height * 0.3,
      center.dx,
      center.dy - size.height * 0.4,
    );
    filmPath.quadraticBezierTo(
      center.dx + size.width * 0.2,
      center.dy - size.height * 0.3,
      center.dx + size.width * 0.4,
      center.dy,
    );
    filmPath.quadraticBezierTo(
      center.dx + size.width * 0.2,
      center.dy + size.height * 0.3,
      center.dx,
      center.dy + size.height * 0.4,
    );
    filmPath.quadraticBezierTo(
      center.dx - size.width * 0.2,
      center.dy + size.height * 0.3,
      center.dx - size.width * 0.4,
      center.dy,
    );

    canvas.drawPath(filmPath, paint);

    // Add film frames along the path
    for (double t = 0.1; t < 0.9; t += 0.2) {
      final tangent = filmPath.computeMetrics().first.getTangentForOffset(
        t * filmPath.computeMetrics().first.length,
      );
      if (tangent != null) {
        final frameRect = Rect.fromCenter(
          center: tangent.position,
          width: 6,
          height: 3,
        );
        canvas.drawRect(
          frameRect,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
