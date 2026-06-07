import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'audition_form_screen.dart';
import 'role_details_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'all_auditions_screen.dart';
import 'services/cloudinary_uploader.dart';
import 'services/firestore_service.dart';

const String termsText = '''
Last Updated: [Insert Date]

Welcome to Filmisphere. These Terms and Conditions ("Terms") govern your use of the Filmisphere mobile application and services.

By accessing or using Filmisphere, you agree to be bound by these Terms. If you do not agree, please do not use the app.

1. About Filmisphere

Filmisphere is a platform designed for professionals in the film industry, including actors, directors, producers, casting agents, and other creatives to:

Create and manage profiles
Upload portfolios (images, videos, resumes)
Discover and post auditions
Apply for roles
Communicate with other users
2. User Eligibility
You must be at least 18 years old to use this app.
By using the app, you confirm that the information you provide is accurate and truthful.
3. User Accounts
You are responsible for maintaining the confidentiality of your account.
You agree not to share your login credentials.
Filmisphere reserves the right to suspend or terminate accounts that violate these Terms.
4. User Content

Users may upload content including photos, videos, and professional information.

By uploading content, you:

Confirm that you own or have the rights to use the content
Grant Filmisphere a non-exclusive, worldwide, royalty-free license to display and distribute your content within the platform
Agree not to upload unlawful, offensive, or misleading content

Filmisphere does not claim ownership of your content.

5. Auditions and Job Listings
Users may post auditions or job opportunities.
Filmisphere does not guarantee the authenticity, accuracy, or outcome of any audition or job listing.
Users are responsible for verifying opportunities before applying.
6. Communication Between Users
Users may communicate through the app.
You agree not to:
Harass, abuse, or harm others
Send spam or fraudulent messages
Share inappropriate or illegal content

Filmisphere may monitor or restrict communication for safety purposes.

7. Prohibited Activities

You agree NOT to:

Use the platform for illegal purposes
Impersonate another person or entity
Upload harmful or malicious files
Attempt to hack, disrupt, or damage the platform
8. Privacy

Your use of the app is also governed by our Privacy Policy. Please review it to understand how we collect and use your data.

9. Intellectual Property
All app content, design, and branding belong to Filmisphere.
You may not copy, modify, or distribute any part of the app without permission.
10. Limitation of Liability

Filmisphere is a networking platform only. We are not responsible for:

Any disputes between users
Job outcomes or casting decisions
Loss or damage resulting from use of the platform

Use the app at your own risk.

11. Termination

We reserve the right to suspend or terminate your account if:

You violate these Terms
You engage in harmful or illegal activity
12. Changes to Terms

Filmisphere may update these Terms at any time. Continued use of the app means you accept the updated Terms.

13. Governing Law

These Terms shall be governed by the laws of [Your Country/State].

14. Contact Us

If you have any questions about these Terms, please contact us at:

Email: [your-email@example.com]

By using Filmisphere, you agree to these Terms and Conditions.
''';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _currentAuditionIndex = 0;
  final PageController _pageController = PageController();
  int _unreadChatCount = 0;
  final int _auditionsInitialTab = 0;
  final Map<String, int> _professionalCounts = {};

  AnimationController? _textAnimationController;
  Animation<double> get _textAnimation =>
      _textAnimationController ?? AlwaysStoppedAnimation<double>(0.0);
  List<Map<String, dynamic>> _auditionEvents = [];
  String _profileImageUrl = '';
  bool _isAutoScrolling = false;
  Timer? _autoScrollTimer;
  final TextEditingController _reportController = TextEditingController();

  // Premium Roles Data
  List<Map<String, dynamic>> get _roles => [
    {
      'title': 'Actors',
      'icon': Icons.theater_comedy,
      'count': (_professionalCounts['Actors'] ?? 0).toString(),
      'color': const Color(0xFF9D4EDD),
      'borderColor': const Color(0xFF9D4EDD),
      'description': 'Film & Theater Artists',
    },
    {
      'title': 'Directors',
      'icon': Icons.movie_creation,
      'count': (_professionalCounts['Directors'] ?? 0).toString(),
      'color': const Color(0xFF7B2CBF),
      'borderColor': const Color(0xFF7B2CBF),
      'description': 'Creative Visionaries',
    },
    {
      'title': 'Producers',
      'icon': Icons.business_center,
      'count': (_professionalCounts['Producers'] ?? 0).toString(),
      'color': const Color(0xFF9D4EDD),
      'borderColor': const Color(0xFF9D4EDD),
      'description': 'Project Handlers',
    },
    {
      'title': 'Screen Writers',
      'icon': Icons.edit_note,
      'count': (_professionalCounts['Screen Writers'] ?? 0).toString(),
      'color': const Color(0xFF9D4EDD),
      'borderColor': const Color(0xFF9D4EDD),
      'description': 'Story Crafters',
    },
    {
      'title': 'Cinematographers',
      'icon': Icons.camera_roll,
      'count': (_professionalCounts['Cinematographers'] ?? 0).toString(),
      'color': const Color(0xFF7B2CBF),
      'borderColor': const Color(0xFF7B2CBF),
      'description': 'Visual Artists',
    },
    {
      'title': 'Editors',
      'icon': Icons.video_settings,
      'count': (_professionalCounts['Editors'] ?? 0).toString(),
      'color': const Color(0xFF9D4EDD),
      'borderColor': const Color(0xFF9D4EDD),
      'description': 'Post Production Experts',
    },
    {
      'title': 'Sound Designers',
      'icon': Icons.graphic_eq,
      'count': (_professionalCounts['Sound Designers'] ?? 0).toString(),
      'color': const Color(0xFF9D4EDD),
      'borderColor': const Color(0xFF9D4EDD),
      'description': 'Audio Specialists',
    },
    {
      'title': 'Casting Directors',
      'icon': Icons.people_alt,
      'count': (_professionalCounts['Casting Directors'] ?? 0).toString(),
      'color': const Color(0xFF7B2CBF),
      'borderColor': const Color(0xFF7B2CBF),
      'description': 'Talent Scouts',
    },
  ];

  @override
  void initState() {
    super.initState();
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _fetchProfessionalCounts();
    _fetchAuditions();
    _fetchProfileImage();
    _fetchUnreadChatCount();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (_auditionEvents.isEmpty) {
      _isAutoScrolling = false;
      return;
    }

    _isAutoScrolling = true;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _auditionEvents.isEmpty) {
        _autoScrollTimer?.cancel();
        _isAutoScrolling = false;
        return;
      }
      setState(() {
        _currentAuditionIndex =
            (_currentAuditionIndex + 1) % _auditionEvents.length;
      });
    });
  }

  void _goToPreviousAudition() {
    if (_auditionEvents.isEmpty) return;
    setState(() {
      _currentAuditionIndex =
          (_currentAuditionIndex - 1 + _auditionEvents.length) %
          _auditionEvents.length;
    });
    _startAutoScroll();
  }

  void _goToNextAudition() {
    if (_auditionEvents.isEmpty) return;
    setState(() {
      _currentAuditionIndex =
          (_currentAuditionIndex + 1) % _auditionEvents.length;
    });
    _startAutoScroll();
  }

  String _mapRoleToKey(String role) {
    final normalized = role.toLowerCase().trim();
    if (normalized.contains('actor')) return 'Actors';
    if (normalized.contains('director')) return 'Directors';
    if (normalized.contains('producer')) return 'Producers';
    if (normalized.contains('screen writer')) return 'Screen Writers';
    if (normalized.contains('cinematographer')) return 'Cinematographers';
    if (normalized.contains('editor')) return 'Editors';
    if (normalized.contains('sound designer')) return 'Sound Designers';
    if (normalized.contains('casting director')) return 'Casting Directors';
    return 'Others';
  }

  Future<void> _fetchProfessionalCounts() async {
    try {
      final allProfessionals = await FirestoreService.fetchAllProfessionals();
      final counts = <String, int>{
        'Actors': 0,
        'Directors': 0,
        'Producers': 0,
        'Screen Writers': 0,
        'Cinematographers': 0,
        'Editors': 0,
        'Sound Designers': 0,
        'Casting Directors': 0,
      };

      for (var prof in allProfessionals) {
        final roleString = (prof['role'] as String?)?.trim() ?? '';
        final key = _mapRoleToKey(roleString);
        if (counts.containsKey(key)) {
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _professionalCounts.clear();
          _professionalCounts.addAll(counts);
        });
      }
    } catch (e) {
      debugPrint('Error fetching professional counts: $e');
      if (mounted) {
        setState(() {
          // leave existing counts as-is if fetch fails
        });
      }
    }
  }

  Future<void> _fetchAuditions() async {
    try {
      final auditions = await FirestoreService.fetchAllAuditions();
      if (mounted) {
        setState(() {
          _auditionEvents = auditions
              .where((event) => event.isNotEmpty)
              .toList();
          if (_auditionEvents.isNotEmpty &&
              _currentAuditionIndex >= _auditionEvents.length) {
            _currentAuditionIndex = 0;
          }
        });
        if (_auditionEvents.isNotEmpty && !_isAutoScrolling) {
          _startAutoScroll();
        }
      }
    } catch (e) {
      debugPrint('Error fetching auditions: $e');
      if (mounted) {
        setState(() {
          _auditionEvents = [];
          _currentAuditionIndex = 0;
        });
      }
    }
  }

  Future<void> _fetchProfileImage() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (mounted) {
          setState(() {
            _profileImageUrl = (userDoc.data()?['image'] as String?) ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile image: $e');
    }
  }

  Future<void> _fetchUnreadChatCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      int totalUnread = 0;
      for (final doc in chatsSnapshot.docs) {
        final unreadCount =
            ((doc.data()['unreadCount']
                        as Map<String, dynamic>?)?[currentUser.uid]
                    as num?)
                ?.toInt() ??
            0;
        totalUnread += unreadCount;
      }

      if (mounted) {
        setState(() {
          _unreadChatCount = totalUnread;
        });
      }
    } catch (e) {
      debugPrint('Error fetching unread chat count: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _textAnimationController?.dispose();
    _reportController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  String _getCountForRole(String roleTitle) {
    // For Director, Producer, and Casting Director, use Firebase counts
    if (_professionalCounts.containsKey(roleTitle)) {
      return '${_professionalCounts[roleTitle] ?? 0}';
    }

    // For other roles, return default hardcoded value
    final role = _roles.firstWhere(
      (r) => r['title'] == roleTitle,
      orElse: () => {'count': '0'},
    );
    return '${role['count']}';
  }

  ImageProvider _getAuditionImageProvider(Map<String, dynamic> event) {
    final String? imageValue = (event['coverImage'] ?? event['image'])
        ?.toString();

    if (imageValue != null && imageValue.isNotEmpty) {
      if (imageValue.toLowerCase().startsWith('http')) {
        return CachedNetworkImageProvider(imageValue);
      }
      try {
        return FileImage(File(imageValue));
      } catch (_) {
        // fallback
      }
    }

    return const CachedNetworkImageProvider(
      'https://images.unsplash.com/photo-1489599809505-7ed0ab7a6b58?w=400',
    );
  }

  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPremiumHeader(),
          const SizedBox(height: 24),
          _buildAuditionBanner(),

          const SizedBox(height: 24),
          _buildRolesGrid(),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return SizedBox(
      height: 120,
      child: Stack(
        children: [
          // Left side: Welcome Back and Film Sphere
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome Back,',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: _textAnimation,
                  builder: (context, child) {
                    final double value = _textAnimation.value;
                    final gradient = LinearGradient(
                      colors: const [
                        Color(0xFFE0AAFF),
                        Color(0xFF7B2CBF),
                        Color(0xFF42A5F5),
                        Color(0xFF00C853),
                        Color(0xFFFFC107),
                        Color(0xFFFF5252),
                      ],
                      stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                      begin: Alignment(-1 + 2 * value, 0),
                      end: Alignment(1 + 2 * value, 0),
                    );

                    return ShaderMask(
                      shaderCallback: (rect) => gradient.createShader(rect),
                      blendMode: BlendMode.srcIn,
                      child: child,
                    );
                  },
                  child: const Text(
                    'Film Sphere',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right side: Round profile image
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _onItemTapped(4),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF9D4EDD), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(
                        255,
                        13,
                        12,
                        13,
                      ).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _profileImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _profileImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFF9D4EDD),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF9D4EDD),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF9D4EDD),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                ),
              ),
            ),
          ),
          // Menu button under profile circle (right side)
          Positioned(
            top: 80,
            right: -18,

            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'report') {
                  _showReportDialog();
                } else if (value == 'terms') {
                  _showTermsDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Report about app'),
                ),
                const PopupMenuItem(
                  value: 'terms',
                  child: Text('Terms and Conditions'),
                ),
              ],
              icon: const Icon(Icons.more_vert, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditionBanner() {
    if (_auditionEvents.isEmpty ||
        _currentAuditionIndex >= _auditionEvents.length) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🎬 Featured Auditions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AllAuditionsScreen(auditionEvents: _auditionEvents),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: Color(0xFF9D4EDD),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF9D4EDD),
                      size: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF9D4EDD).withOpacity(0.3),
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.audiotrack, color: Color(0xFF9D4EDD), size: 48),
                  SizedBox(height: 16),
                  Text(
                    'No auditions available',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    'Check back later!',
                    style: TextStyle(color: Color(0xFFB0B0D0), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final event = _auditionEvents[_currentAuditionIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🎬 Featured Auditions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AllAuditionsScreen(auditionEvents: _auditionEvents),
                  ),
                );
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF9D4EDD),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Stack(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuditionFormScreen(auditionEvent: event),
                  ),
                );
              },
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                if (details.primaryVelocity! < 0) {
                  _goToNextAudition();
                } else if (details.primaryVelocity! > 0) {
                  _goToPreviousAudition();
                }
              },
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: _getAuditionImageProvider(event),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'URGENT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          event['title']?.toString() ?? 'Untitled Audition',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.business_center,
                              color: Colors.white.withOpacity(0.9),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              event['production']?.toString() ??
                                  'Unknown Production',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.location_on,
                              color: Colors.white.withOpacity(0.9),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              event['location']?.toString() ??
                                  'Unknown Location',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.currency_rupee,
                              color: Colors.white.withOpacity(0.9),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event['budget']?.toString() ?? 'TBD',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.calendar_today,
                              color: Colors.white.withOpacity(0.9),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Apply by ${event['date']?.toString() ?? 'TBD'}',
                              style: const TextStyle(
                                color: Color(0xFFFFD166),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_auditionEvents.length, (index) {
            final isActive = index == _currentAuditionIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 16 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF9D4EDD) : Colors.white30,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRolesGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = 2;
    final crossAxisSpacing = screenWidth * 0.02;
    final mainAxisSpacing = screenWidth * 0.02;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🎭 Explore Roles',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: 1.0,
          ),
          itemCount: _roles.length,
          itemBuilder: (context, index) {
            final role = _roles[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoleDetailsScreen(role: role),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: role['borderColor'].withOpacity(0.8),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: role['color'].withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: role['color'].withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(role['icon'], color: role['color'], size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      role['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role['description'],
                      style: const TextStyle(
                        color: Color(0xFFB0B0D0),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: role['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getCountForRole(role['title']),
                        style: TextStyle(
                          color: role['color'],
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report about app'),
        content: TextField(
          controller: _reportController,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Enter your report'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final message = _reportController.text.trim();
              if (message.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter report details.')),
                );
                return;
              }
              try {
                await FirestoreService.submitReport(
                  message: message,
                  reportType: 'app',
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report submitted successfully.'),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to submit report: $e')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms and Conditions'),
        content: SingleChildScrollView(child: Text(termsText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          _buildHomeScreen(),
          AuditionsScreen(
            key: ValueKey(_auditionsInitialTab),
            initialTab: _auditionsInitialTab,
          ),
          const ChatScreen(professional: {}),
          const LiveEventsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          border: const Border(top: BorderSide(color: Color(0xFF2D2B55))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            backgroundColor: const Color(0xFF1E1B2E),
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            selectedItemColor: const Color(0xFFE0AAFF),
            unselectedItemColor: const Color(0xFF8080A0),
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            iconSize: 22,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            elevation: 0,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.audiotrack_rounded),
                label: 'Auditions',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    const Icon(Icons.chat_rounded),
                    if (_unreadChatCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B6B),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            _unreadChatCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Chat',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.event_rounded),
                label: 'Live Events',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuditionsScreen extends StatefulWidget {
  final int initialTab;
  const AuditionsScreen({super.key, this.initialTab = 0});

  @override
  State<AuditionsScreen> createState() => _AuditionsScreenState();
}

class _AuditionsScreenState extends State<AuditionsScreen> {
  late int _selectedTab;
  List<Map<String, dynamic>> _allAuditions = [];
  List<Map<String, dynamic>> _userApplications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab > 0 ? widget.initialTab - 1 : 0;
    _fetchAuditionsAndApplications();
  }

  Future<void> _fetchAuditionsAndApplications() async {
    try {
      final result = await FirestoreService.fetchAuditionsWithUserStatus();

      setState(() {
        _allAuditions = List<Map<String, dynamic>>.from(
          result['auditions'] ?? [],
        );
        _userApplications = List<Map<String, dynamic>>.from(
          result['applications'] ?? [],
        );
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching auditions: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading auditions: $e')));
      }
    }
  }

  @override
  void didUpdateWidget(covariant AuditionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        _selectedTab = widget.initialTab > 0 ? widget.initialTab - 1 : 0;
      });
    }
  }

  List<Map<String, dynamic>> get _selectedAuditions {
    return _allAuditions.where((audition) {
      return _userApplications.any(
        (app) =>
            app['auditionId'] == audition['id'] && app['status'] == 'Accepted',
      );
    }).toList();
  }

  List<Map<String, dynamic>> get _rejectedAuditions {
    return _allAuditions.where((audition) {
      return _userApplications.any(
        (app) =>
            app['auditionId'] == audition['id'] && app['status'] == 'Rejected',
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1B),
        elevation: 0,
        title: const Text(
          'My Auditions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAuditionsAndApplications,
              backgroundColor: const Color(0xFF1E1B2E),
              color: const Color(0xFF9D4EDD),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTabButtons(),
                    const SizedBox(height: 24),
                    _buildContent(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTabButtons() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2B55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabButton('Selected', 0, Icons.check_circle)),
          Expanded(child: _buildTabButton('Rejected', 1, Icons.cancel)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index, IconData icon) {
    bool isSelected = _selectedTab == index;
    Color activeColor = const Color(0xFF9D4EDD);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: const Color(0xFFE0AAFF), width: 1)
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFFB0B0D0),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFB0B0D0),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildSelectedContent();
      case 1:
        return _buildRejectedContent();
      default:
        return _buildSelectedContent();
    }
  }

  Widget _buildSelectedContent() {
    if (_selectedAuditions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Selected Auditions Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep applying to auditions for your chance to shine!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF66BB6A).withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.celebration, color: Colors.white, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Congratulations!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have been selected for ${_selectedAuditions.length} project${_selectedAuditions.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ..._selectedAuditions.map((audition) {
          // Find the corresponding accepted application
          final acceptedApp = _userApplications.firstWhere(
            (app) =>
                app['auditionId'] == audition['id'] &&
                app['status'] == 'Accepted',
            orElse: () => {},
          );
          return _buildSelectedCard(audition, acceptedApp);
        }),
      ],
    );
  }

  Widget _buildRejectedContent() {
    if (_rejectedAuditions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Rejected Auditions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All your auditions are still pending review',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '❌ Rejected Auditions (${_rejectedAuditions.length})',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Learn from feedback and keep improving',
          style: TextStyle(color: Color(0xFFB0B0D0), fontSize: 14),
        ),
        const SizedBox(height: 16),
        ..._rejectedAuditions.map((audition) {
          // Find the corresponding application to get rejection details
          final rejectedApp = _userApplications.firstWhere(
            (app) =>
                app['auditionId'] == audition['id'] &&
                app['status'] == 'Rejected',
            orElse: () => {},
          );
          return _buildRejectedCard(audition, rejectedApp);
        }),
      ],
    );
  }

  Widget _buildSelectedCard(
    Map<String, dynamic> audition,
    Map<String, dynamic> application,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9D4EDD).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D4EDD).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF9D4EDD),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audition['title'] ?? 'Untitled Audition',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${audition['production'] ?? 'Unknown'} • ${audition['type'] ?? 'Audition'}',
                        style: const TextStyle(
                          color: Color(0xFFB0B0D0),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        audition['location'] ?? 'Location TBA',
                        style: const TextStyle(
                          color: Color(0xFF9D4EDD),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.celebration,
                  color: Color(0xFF9D4EDD),
                  size: 24,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2B55).withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Acceptance Message Section
                if (application.isNotEmpty &&
                    application['acceptanceMessage'] != null &&
                    application['acceptanceMessage'].toString().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF66BB6A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF66BB6A).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.message,
                              color: Color(0xFF66BB6A),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Acceptance Message',
                              style: TextStyle(
                                color: Color(0xFF66BB6A),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          application['acceptanceMessage'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  children: [
                    _buildProjectDetail(
                      'Posted',
                      audition['date'] ?? 'TBA',
                      Icons.calendar_today,
                      const Color(0xFF9D4EDD),
                    ),
                    _buildProjectDetail(
                      'Budget',
                      audition['budget'] ?? 'TBD',
                      Icons.currency_rupee,
                      const Color(0xFF9D4EDD),
                    ),
                    _buildProjectDetail(
                      'Status',
                      'Accepted',
                      Icons.verified,
                      const Color(0xFF66BB6A),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Production', audition['production'] ?? 'N/A'),
                const SizedBox(height: 8),
                _buildDetailRow('Deadline', audition['date'] ?? 'N/A'),
                const SizedBox(height: 8),
                _buildDetailRow('Type', audition['type'] ?? 'N/A'),
                const SizedBox(height: 8),
                _buildDetailRow('Role', audition['role'] ?? 'N/A'),
                const SizedBox(height: 8),
                _buildDetailRow('Shoot Date', audition['shootDate'] ?? 'N/A'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedCard(
    Map<String, dynamic> audition,
    Map<String, dynamic> application,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2B55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D4EDD).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.cancel,
                    color: Color(0xFF9D4EDD),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audition['title'] ?? 'Untitled Audition',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${audition['production'] ?? 'Unknown'} • ${audition['type'] ?? 'Audition'}',
                        style: const TextStyle(
                          color: Color(0xFFB0B0D0),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        audition['location'] ?? 'Location TBA',
                        style: const TextStyle(
                          color: Color(0xFF9D4EDD),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Application Status: Rejected',
                        style: const TextStyle(
                          color: Color(0xFF8080A0),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2B55).withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Production', audition['production'] ?? 'N/A'),
                const SizedBox(height: 8),
                _buildDetailRow('Deadline', audition['date'] ?? 'N/A'),
                const SizedBox(height: 8),
                _buildDetailRow('Type', audition['type'] ?? 'N/A'),
                const SizedBox(height: 8),
                _buildDetailRow('Role', audition['role'] ?? 'N/A'),
                const SizedBox(height: 8),
                _buildDetailRow('Shoot Date', audition['shootDate'] ?? 'N/A'),

                // Rejection Reason (if available)
                if (application.isNotEmpty &&
                    application['rejectionReason'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEF5350).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rejection Reason',
                          style: TextStyle(
                            color: Color(0xFFEF5350),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          application['rejectionReason'] ?? 'N/A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        // Rejection Comment (if provided)
                        if ((application['rejectionComment'] as String?)
                                ?.isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Feedback:',
                            style: TextStyle(
                              color: Color(0xFFB0B0D0),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            application['rejectionComment'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectDetail(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFB0B0D0), fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFFB0B0D0),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class LiveEventsScreen extends StatefulWidget {
  const LiveEventsScreen({super.key});

  @override
  State<LiveEventsScreen> createState() => _LiveEventsScreenState();
}

class _LiveEventsScreenState extends State<LiveEventsScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  bool _isLiveSession(Map<String, dynamic> event) {
    final eventType = (event['eventType'] ?? event['type'] ?? event['category'])
        ?.toString()
        .toLowerCase()
        .trim();
    return eventType == 'session' ||
        eventType == 'live session' ||
        eventType == 'live_session' ||
        eventType == 'session event' ||
        eventType == 'sessions';
  }

  List<Map<String, dynamic>> get _liveEventsList {
    return _events.where((event) => !_isLiveSession(event)).toList();
  }

  List<Map<String, dynamic>> get _liveSessionsList {
    return _events.where(_isLiveSession).toList();
  }

  Future<void> _fetchEvents() async {
    try {
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .get();
      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('Session')
          .get();

      final allEvents = [
        ...eventsSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}),
        ...sessionsSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}),
      ];

      allEvents.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }
        return 0;
      });

      if (mounted) {
        setState(() {
          _events = allEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleLike(String eventId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId);
    final eventDoc = await eventRef.get();
    final likedBy = List<String>.from(eventDoc.data()?['likedBy'] ?? []);

    if (likedBy.contains(currentUser.uid)) {
      likedBy.remove(currentUser.uid);
    } else {
      likedBy.add(currentUser.uid);
    }

    await eventRef.update({'likedBy': likedBy});

    if (mounted) {
      setState(() {
        final index = _events.indexWhere((e) => e['id'] == eventId);
        if (index != -1) {
          _events[index]['likedBy'] = likedBy;
        }
      });
    }
  }

  void _showReportDialog(String eventId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Event'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Reason for reporting'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null && controller.text.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('eventReports')
                    .add({
                      'eventId': eventId,
                      'userId': currentUser.uid,
                      'reason': controller.text,
                      'timestamp': Timestamp.now(),
                    });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted')),
                  );
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    const labels = ['Live Event', 'Live Session'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.3)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF9D4EDD)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final events = _selectedTabIndex == 0 ? _liveEventsList : _liveSessionsList;
    if (events.isEmpty) {
      return _buildEmptyState(
        _selectedTabIndex == 0
            ? 'No Live Events Found'
            : 'No Live Sessions Found',
        _selectedTabIndex == 0
            ? 'No live events are available at this time. Check back later.'
            : 'No live session items are available yet. Try again later.',
        _selectedTabIndex == 0 ? Icons.event_available_rounded : Icons.live_tv,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final currentUser = FirebaseAuth.instance.currentUser;
        final isLiked =
            (event['likedBy'] as List<dynamic>?)?.contains(currentUser?.uid) ??
            false;
        final likeCount = (event['likedBy'] as List<dynamic>?)?.length ?? 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventDetailScreen(event: event),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF9D4EDD).withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event['posterVideoUrl'] != null &&
                    event['posterVideoUrl'].toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: SizedBox(
                      height: 150,
                      child: VideoPlayerWidget(
                        videoUrl: event['posterVideoUrl'],
                      ),
                    ),
                  )
                else if (event['posterUrl'] != null &&
                    event['posterUrl'].toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: event['posterUrl'],
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 150,
                        color: const Color(0xFF9D4EDD),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 150,
                        color: const Color(0xFF9D4EDD),
                        child: const Icon(
                          Icons.image,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['eventName'] ?? 'Untitled Event',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$likeCount likes',
                            style: const TextStyle(
                              color: Color(0xFFB0B0D0),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1B),
        elevation: 0,
        title: const Text(
          'Live Events',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTabBar(),
                Expanded(child: _buildEventList()),
              ],
            ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  Timer? _loopTimer;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    await _videoPlayerController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: true,
      showControls: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
    );

    // Set initial volume to 0 (muted)
    _videoPlayerController.setVolume(0.0);

    // Set up timer to loop every 6 seconds
    _loopTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_videoPlayerController.value.isPlaying) {
        _videoPlayerController.seekTo(Duration.zero);
      }
    });

    if (mounted) {
      setState(() {});
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoPlayerController.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _chewieController?.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black,
      ),
      child: Stack(
        children: [
          if (_chewieController != null &&
              _chewieController!.videoPlayerController.value.isInitialized)
            Chewie(controller: _chewieController!)
          else
            const Center(child: CircularProgressIndicator()),
          // Mute/Unmute button overlay
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _commentController;
  late TabController _tabController;
  String? _replyingToCommentId;
  String? _replyingToCommentAuthor;
  File? _selectedCommentAttachment;
  String? _selectedCommentAttachmentName;
  String? _selectedCommentAttachmentUrl;
  String? _selectedCommentAttachmentType;
  bool _isAboutExpanded = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Fetch the actual user name or production name from Firestore
  Future<String> _fetchUserName(String userId) async {
    try {
      // First, try to get user name from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final name =
            userDoc.data()?['name'] ??
            userDoc.data()?['username'] ??
            userDoc.data()?['displayName'];
        if (name != null && name.toString().isNotEmpty && name != 'Anonymous') {
          return name.toString();
        }
      }

      // If not found, try to get production name from profession collection
      final profDoc = await FirebaseFirestore.instance
          .collection('profession')
          .doc(userId)
          .get();

      if (profDoc.exists) {
        final name = profDoc.data()?['name'];
        if (name != null && name.toString().isNotEmpty) {
          return name.toString();
        }
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
    return 'Unknown User';
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty &&
        _selectedCommentAttachment == null)
      return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userName = userData.data()?['name'] ?? currentUser.email ?? 'User';
      final userImage = userData.data()?['image'] ?? '';

      if (_selectedCommentAttachment != null &&
          _selectedCommentAttachmentUrl == null) {
        await _uploadCommentAttachment();
      }

      final commentData = {
        'userId': currentUser.uid,
        'userName': userName,
        'userImage': userImage,
        'text': _commentController.text.trim(),
        'attachmentUrl': _selectedCommentAttachmentUrl ?? '',
        'attachmentType': _selectedCommentAttachmentType ?? '',
        'attachmentName': _selectedCommentAttachmentName ?? '',
        'timestamp': Timestamp.now(),
        'likedBy': [],
      };

      if (_replyingToCommentId != null) {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.event['id'])
            .collection('comments')
            .doc(_replyingToCommentId)
            .collection('replies')
            .add(commentData);
      } else {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.event['id'])
            .collection('comments')
            .add(commentData);
      }

      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToCommentAuthor = null;
        _selectedCommentAttachment = null;
        _selectedCommentAttachmentName = null;
        _selectedCommentAttachmentUrl = null;
        _selectedCommentAttachmentType = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding comment: $e')));
    }
  }

  Future<void> _toggleCommentLike(
    String commentId,
    List<dynamic> likedBy, {
    String? replyId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final newLikedBy = List<String>.from(likedBy);
      if (newLikedBy.contains(currentUser.uid)) {
        newLikedBy.remove(currentUser.uid);
      } else {
        newLikedBy.add(currentUser.uid);
      }

      if (replyId != null) {
        // Update reply like
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.event['id'])
            .collection('comments')
            .doc(commentId)
            .collection('replies')
            .doc(replyId)
            .update({'likedBy': newLikedBy});
      } else {
        // Update comment like
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.event['id'])
            .collection('comments')
            .doc(commentId)
            .update({'likedBy': newLikedBy});
      }

      setState(() {});
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Delete all replies first
      final repliesSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event['id'])
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .get();

      for (var doc in repliesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the comment
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event['id'])
          .collection('comments')
          .doc(commentId)
          .delete();

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting comment: $e')));
    }
  }

  Future<void> _deleteReply(String commentId, String replyId) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event['id'])
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId)
          .delete();

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting reply: $e')));
    }
  }

  bool _isCreatorUser(String userId) {
    final creatorId = widget.event['creatorId']?.toString() ?? '';
    return creatorId.isNotEmpty && creatorId == userId;
  }

  bool _isLiveSession() {
    final eventType = (widget.event['eventType'] ?? widget.event['type'] ?? widget.event['category'])
        ?.toString()
        .toLowerCase()
        .trim();
    return eventType == 'session' ||
        eventType == 'live session' ||
        eventType == 'live_session' ||
        eventType == 'session event' ||
        eventType == 'sessions';
  }

  Future<void> _showUserProfileDialog(String userId) async {
    if (userId.isEmpty) return;

    try {
      final usersDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final professionDoc = await FirebaseFirestore.instance.collection('profession').doc(userId).get();
      final userData = {...(professionDoc.data() ?? {}), ...(usersDoc.data() ?? {})};

      final userName = userData['name'] ?? userData['username'] ?? userData['displayName'] ?? userData['fullName'] ?? 'Unknown';
      final userImage = userData['image'] ?? userData['photoUrl'] ?? userData['photoURL'] ?? userData['profileImage'] ?? userData['avatar'] ?? userData['userImage'] ?? '';
      final role = userData['role'] ?? userData['profession'] ?? userData['userRole'] ?? userData['type'] ?? '';
      final company = userData['company'] ?? userData['organization'] ?? userData['companyName'] ?? '';
      final email = userData['email'] ?? userData['emailAddress'] ?? userData['contactEmail'] ?? '';
      final specialization = userData['specialization'] ?? userData['speciality'] ?? '';
      final bio = userData['bio'] ?? userData['about'] ?? '';

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          title: Text(
            userName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userImage.toString().isNotEmpty)
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(userImage),
                      backgroundColor: const Color(0xFF9D4EDD),
                    ),
                  ),
                if (userImage.toString().isNotEmpty) const SizedBox(height: 16),
                if (role.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Role: $role', style: const TextStyle(color: Colors.white70)),
                  ),
                if (company.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Company: $company', style: const TextStyle(color: Colors.white70)),
                  ),
                if (email.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Email: $email', style: const TextStyle(color: Colors.white70)),
                  ),
                if (specialization.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Specialization: $specialization', style: const TextStyle(color: Colors.white70)),
                  ),
                if (bio.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Bio: $bio', style: const TextStyle(color: Colors.white70)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    }
  }
Future<void> _pickCommentAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'mp4',
          'mov',
          'pdf',
          'doc',
          'docx',
          'txt',
        ],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedCommentAttachment = File(result.files.single.path!);
          _selectedCommentAttachmentName = result.files.single.name;
          _selectedCommentAttachmentUrl = null;
          _selectedCommentAttachmentType = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting attachment: $e')));
    }
  }

  Future<void> _pickImageAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedCommentAttachment = File(result.files.single.path!);
          _selectedCommentAttachmentName = result.files.single.name;
          _selectedCommentAttachmentUrl = null;
          _selectedCommentAttachmentType = 'image';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
    }
  }

  Future<void> _pickVideoAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: ['mp4', 'mov'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedCommentAttachment = File(result.files.single.path!);
          _selectedCommentAttachmentName = result.files.single.name;
          _selectedCommentAttachmentUrl = null;
          _selectedCommentAttachmentType = 'video';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting video: $e')));
    }
  }

  Future<void> _uploadCommentAttachment() async {
    if (_selectedCommentAttachment == null) return;

    final selectedFile = _selectedCommentAttachment!;
    final fileName = selectedFile.path.toLowerCase();
    String resourceType = _selectedCommentAttachmentType ?? 'raw';
    if (_selectedCommentAttachmentType == null) {
      if (fileName.endsWith('.jpg') ||
          fileName.endsWith('.jpeg') ||
          fileName.endsWith('.png')) {
        resourceType = 'image';
      } else if (fileName.endsWith('.mp4') || fileName.endsWith('.mov')) {
        resourceType = 'video';
      }
    }

    final uploadResult = await CloudinaryUploader().uploadMedia(
      selectedFile,
      resourceType,
      (progress) {},
    );

    setState(() {
      _selectedCommentAttachmentUrl = uploadResult.url;
      _selectedCommentAttachmentType = uploadResult.resourceType;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1B),
        elevation: 0,
        title: Text(
          widget.event['eventName'] ?? 'Event Details',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Media Section
                  if (widget.event['posterVideoUrl'] != null &&
                      widget.event['posterVideoUrl'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: VideoPlayerWidget(
                        videoUrl: widget.event['posterVideoUrl'],
                      ),
                    )
                  else if (widget.event['posterUrl'] != null &&
                      widget.event['posterUrl'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: widget.event['posterUrl'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: const Color(0xFF9D4EDD),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: const Color(0xFF9D4EDD),
                          child: const Icon(
                            Icons.image,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Event Details
                  Text(
                    widget.event['eventName'] ?? 'Untitled Event',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Like Button
                  _buildLikeSection(),
                  const SizedBox(height: 16),

                  // Date and Time
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF9D4EDD),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.event['date'] ?? 'Date TBA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Color(0xFF9D4EDD),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.event['time'] ?? 'Time TBA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color.fromARGB(255, 177, 48, 177),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.event['location'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Duration
                  if (widget.event['duration'] != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.timer,
                          color: Color(0xFF9D4EDD),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.event['duration'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Booking Link
                  if (widget.event['bookingLink'] != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.link,
                          color: Color(0xFF9D4EDD),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              String url =
                                  widget.event['bookingLink'] as String;
                              if (!url.startsWith('http://') &&
                                  !url.startsWith('https://')) {
                                url = 'https://$url';
                              }
                              try {
                                await launchUrl(Uri.parse(url));
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Could not launch booking link: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              'Booking: ${widget.event['bookingLink']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Ticket Rate
                  if (widget.event['ticketRate'] != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.currency_rupee,
                          color: Color(0xFF9D4EDD),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ticket: ${widget.event['ticketRate']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // About
                  if (widget.event['about'] != null &&
                      widget.event['about'].isNotEmpty) ...[
                    const Text(
                      'About',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final aboutText = widget.event['about'] as String;
                        final isLongText = aboutText.length > 100;
                        final displayText = _isAboutExpanded || !isLongText
                            ? aboutText
                            : '${aboutText.substring(0, 100)}...';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayText,
                              style: const TextStyle(
                                color: Color(0xFFB0B0D0),
                                fontSize: 14,
                              ),
                            ),
                            if (isLongText) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isAboutExpanded = !_isAboutExpanded;
                                  });
                                },
                                child: Text(
                                  _isAboutExpanded ? 'View Less' : 'View More',
                                  style: const TextStyle(
                                    color: Color(0xFF9D4EDD),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Tab Bar for Selected Candidates and Comments
                  _buildCommentsTabs(),
                ],
              ),
            ),
          ),
          // Comment Input Box
          _buildCommentInputBox(),
        ],
      ),
    );
  }

  Widget _buildLikeSection() {
    final likedBy =
        (widget.event['likedBy'] as List<dynamic>?)?.cast<String>() ?? [];
    final currentUser = FirebaseAuth.instance.currentUser;
    final isLiked = likedBy.contains(currentUser?.uid);

    return GestureDetector(
      onTap: () async {
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to like events')),
          );
          return;
        }

        final newLikedBy = List<String>.from(likedBy);
        if (newLikedBy.contains(currentUser.uid)) {
          newLikedBy.remove(currentUser.uid);
        } else {
          newLikedBy.add(currentUser.uid);
        }

        try {
          await FirebaseFirestore.instance
              .collection('events')
              .doc(widget.event['id'])
              .update({'likedBy': newLikedBy});

          setState(() {
            widget.event['likedBy'] = newLikedBy;
          });
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              '${likedBy.length} Likes',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event['id'])
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No comments yet. Be the first to comment!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: snapshot.data!.docs.map((commentDoc) {
              final comment = commentDoc.data() as Map<String, dynamic>;
              return _buildCommentThread(commentDoc.id, comment);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSelectedSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event['id'])
          .collection('selected')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No selected candidates yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: snapshot.data!.docs.map((selectedDoc) {
              final selected = selectedDoc.data() as Map<String, dynamic>;
              return _buildSelectedCommentThread(selectedDoc.id, selected);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCommentsTabs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B2E),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFF9D4EDD).withOpacity(0.2),
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: const Color(0xFF9D4EDD),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Comments'),
              Tab(text: 'Selected Candidates'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Comments Tab
              _buildCommentsSection(),
              // Selected Candidates Tab
              _buildSelectedSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedCommentThread(String commentId, Map<String, dynamic> comment) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = comment['userId'] == currentUser?.uid;
    final likedBy =
        (comment['likedBy'] as List<dynamic>?)?.cast<String>() ?? [];
    final isLiked = likedBy.contains(currentUser?.uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2845),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9D4EDD).withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info and comment text
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _showUserProfileDialog(comment['userId'] ?? ''),
                    child: comment['userImage'] != null &&
                            comment['userImage'].toString().isNotEmpty
                        ? CircleAvatar(
                            radius: 16,
                            backgroundImage: CachedNetworkImageProvider(
                              comment['userImage'],
                            ),
                          )
                        : const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFF9D4EDD),
                            child: Icon(Icons.person, color: Colors.white, size: 16),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _showUserProfileDialog(comment['userId'] ?? ''),
                          child: FutureBuilder<String>(
                            future: _fetchUserName(comment['userId'] ?? ''),
                            builder: (context, snapshot) {
                              final displayName =
                                  snapshot.data ??
                                  (comment['userName'] ?? 'User');
                              return Row(
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (_isCreatorUser(comment['userId'] ?? '')) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF9D4EDD),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Creator',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment['text'] ?? '',
                          style: const TextStyle(
                            color: Color(0xFFB0B0D0),
                            fontSize: 13,
                          ),
                        ),
                        if (comment['attachmentUrl'] != null &&
                            comment['attachmentUrl'].toString().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildCommentAttachmentPreview(
                            comment['attachmentUrl'],
                            comment['attachmentType'],
                            comment['attachmentName'],
                          ),
                        ],
                        // Selected badge
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF66BB6A).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF66BB6A),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Color(0xFF66BB6A),
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Selected by Producer',
                                style: TextStyle(
                                  color: Color(0xFF66BB6A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isOwner)
                    PopupMenuButton(
                      color: const Color(0xFF1E1B2E),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () => _deleteComment(commentId),
                        ),
                      ],
                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Like button
        Row(
          children: [
            GestureDetector(
              onTap: () => _toggleCommentLike(commentId, likedBy),
              child: Row(
                children: [
                  Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    likedBy.length.toString(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCommentThread(String commentId, Map<String, dynamic> comment) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = comment['userId'] == currentUser?.uid;
    final likedBy =
        (comment['likedBy'] as List<dynamic>?)?.cast<String>() ?? [];
    final isLiked = likedBy.contains(currentUser?.uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info and comment text
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _showUserProfileDialog(comment['userId'] ?? ''),
                    child: comment['userImage'] != null &&
                            comment['userImage'].toString().isNotEmpty
                        ? CircleAvatar(
                            radius: 16,
                            backgroundImage: CachedNetworkImageProvider(
                              comment['userImage'],
                            ),
                          )
                        : const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFF9D4EDD),
                            child: Icon(Icons.person, color: Colors.white, size: 16),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _showUserProfileDialog(comment['userId'] ?? ''),
                          child: FutureBuilder<String>(
                            future: _fetchUserName(comment['userId'] ?? ''),
                            builder: (context, snapshot) {
                              final displayName =
                                  snapshot.data ??
                                  (comment['userName'] ?? 'User');
                              return Row(
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (_isCreatorUser(comment['userId'] ?? '')) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF9D4EDD),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Creator',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment['text'] ?? '',
                          style: const TextStyle(
                            color: Color(0xFFB0B0D0),
                            fontSize: 13,
                          ),
                        ),
                        if (comment['attachmentUrl'] != null &&
                            comment['attachmentUrl'].toString().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildCommentAttachmentPreview(
                            comment['attachmentUrl'],
                            comment['attachmentType'],
                            comment['attachmentName'],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isOwner)
                    PopupMenuButton(
                      color: const Color(0xFF1E1B2E),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () => _deleteComment(commentId),
                        ),
                      ],
                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Like and Reply buttons
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleCommentLike(commentId, likedBy),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          likedBy.length.toString(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyingToCommentId = commentId;
                        _replyingToCommentAuthor =
                            comment['userName'] ?? 'User';
                      });
                      FocusScope.of(context).requestFocus(FocusNode());
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.reply, color: Colors.white70, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Reply',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Replies
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .doc(widget.event['id'])
              .collection('comments')
              .doc(commentId)
              .collection('replies')
              .orderBy('timestamp', descending: false)
              .snapshots(),
          builder: (context, replySnapshot) {
            if (!replySnapshot.hasData || replySnapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: replySnapshot.data!.docs.map((replyDoc) {
                  final reply = replyDoc.data() as Map<String, dynamic>;
                  final replyIsOwner = reply['userId'] == currentUser?.uid;
                  final replyLikedBy =
                      (reply['likedBy'] as List<dynamic>?)?.cast<String>() ??
                      [];
                  final replyIsLiked = replyLikedBy.contains(currentUser?.uid);

                  return Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171727),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF9D4EDD).withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (reply['userImage'] != null &&
                                reply['userImage'].toString().isNotEmpty)
                              CircleAvatar(
                                radius: 14,
                                backgroundImage: CachedNetworkImageProvider(
                                  reply['userImage'],
                                ),
                              )
                            else
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(0xFF9D4EDD),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FutureBuilder<String>(
                                    future: _fetchUserName(
                                      reply['userId'] ?? '',
                                    ),
                                    builder: (context, snapshot) {
                                      final replyAuthorName =
                                          snapshot.data ??
                                          (reply['userName'] ?? 'User');
                                      return GestureDetector(
                                        onTap: () => _showUserProfileDialog(reply['userId'] ?? ''),
                                        child: Row(
                                          children: [
                                            Text(
                                              replyAuthorName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (_isCreatorUser(reply['userId'] ?? '')) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF9D4EDD),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'Creator',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.reply,
                                              color: Color(0xFF9D4EDD),
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _replyingToCommentAuthor ?? 'User',
                                              style: const TextStyle(
                                                color: Color(0xFF9D4EDD),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    reply['text'] ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFFB0B0D0),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (reply['attachmentUrl'] != null &&
                                      reply['attachmentUrl']
                                          .toString()
                                          .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        right: 8,
                                      ),
                                      child: _buildCommentAttachmentPreview(
                                        reply['attachmentUrl'],
                                        reply['attachmentType'],
                                        reply['attachmentName'],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (replyIsOwner)
                              GestureDetector(
                                onTap: () =>
                                    _deleteReply(commentId, replyDoc.id),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleCommentLike(
                                commentId,
                                replyLikedBy,
                                replyId: replyDoc.id,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    replyIsLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: replyIsLiked
                                        ? Colors.red
                                        : Colors.white70,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    replyLikedBy.length.toString(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildCommentInputBox() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        border: Border(
          top: BorderSide(color: const Color(0xFF9D4EDD).withOpacity(0.2)),
        ),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToCommentId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    'Replying to $_replyingToCommentAuthor',
                    style: const TextStyle(
                      color: Color(0xFF9D4EDD),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyingToCommentId = null;
                        _replyingToCommentAuthor = null;
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          if (_selectedCommentAttachmentName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2741),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF9D4EDD).withOpacity(0.4),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.attach_file,
                      color: Color(0xFF9D4EDD),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedCommentAttachmentName ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCommentAttachment = null;
                          _selectedCommentAttachmentName = null;
                          _selectedCommentAttachmentUrl = null;
                          _selectedCommentAttachmentType = null;
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: _replyingToCommentId != null
                        ? 'Write a reply...'
                        : 'Add a comment...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFF9D4EDD),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: const Color(0xFF9D4EDD).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFF9D4EDD),
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_isLiveSession()) ...[
                IconButton(
                  onPressed: _pickImageAttachment,
                  icon: const Icon(Icons.image, color: Color(0xFF9D4EDD)),
                  tooltip: 'Attach Image',
                ),
                IconButton(
                  onPressed: _pickVideoAttachment,
                  icon: const Icon(Icons.videocam, color: Color(0xFF9D4EDD)),
                  tooltip: 'Attach Video',
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: _addComment,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF9D4EDD),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentAttachmentPreview(
    String attachmentUrl,
    String attachmentType,
    String attachmentName,
  ) {
    final fileName = attachmentName.isNotEmpty
        ? attachmentName
        : Uri.parse(attachmentUrl).pathSegments.last;

    if (attachmentType == 'image') {
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(attachmentUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            attachmentUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 140,
                color: const Color(0xFF171727),
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 140,
                color: const Color(0xFF171727),
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54),
                ),
              );
            },
          ),
        ),
      );
    }

    final icon = attachmentType == 'video'
        ? Icons.videocam
        : Icons.insert_drive_file;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(attachmentUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2741),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF9D4EDD), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}
