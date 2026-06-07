// ignore_for_file: unused_element

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_project/user_home_screen.dart';

import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_utilities.dart';
import 'professional_profile_screen.dart';
import 'professional_chat_screen.dart';
import 'audition_create_screen.dart';
import 'live_session.dart';
import 'services/firestore_service.dart';
import 'services/cloudinary_uploader.dart';

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

class ProducerHomeScreen extends StatefulWidget {
  final String role;
  final Map<String, dynamic> userData;
  final String uid;

  const ProducerHomeScreen({
    super.key,
    required this.role,
    required this.userData,
    required this.uid,
  });

  @override
  State<ProducerHomeScreen> createState() => _ProducerHomeScreenState();
}

class _ProducerHomeScreenState extends State<ProducerHomeScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _createdAuditions = [];
  Stream<List<Map<String, dynamic>>>? _chatsStream;
  bool _isLoadingApplications = true;
  bool _isLoadingAuditions = true;
  String _applicationsFilter = 'All';
  final Set<String> _expandedApplications = {};
  bool _isProfileExpanded = false;

  // Live Sessions
  List<Map<String, dynamic>> _liveSessions = [];
  bool _isLoadingLiveSessions = true;

  // Rejection reasons
  final List<String> _rejectionReasons = [
    'Not a good fit for this role',
    'Skills do not match requirements',
    'Experience level insufficient',
    'Failed to meet character specifications',
    'Better candidates available',
    'Does not match production timeline',
    'Scheduling conflicts',
    'Other',
  ];
  String? _selectedRejectionReason;
  final TextEditingController _rejectionCommentCtrl = TextEditingController();

  // Profile fields
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _projectsController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _awardsController = TextEditingController();
  final TextEditingController _socialLinksController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _availabilityController = TextEditingController();
  final TextEditingController _languagesController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _reportController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _moreDetails = [];
  bool _isUploadingMoreDetails = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _fetchProfile();
    _initializeChatsStream();
    _fetchAuditions();
    _fetchApplications();
    _fetchLiveSessions();
  }

  void _initializeData() {
    _bioController.text = widget.userData['bio'] ?? '';
    _experienceController.text = widget.userData['experience'] ?? '';
    _companyController.text = widget.userData['company'] ?? '';
    _projectsController.text =
        widget.userData['previousProjects']?.join(', ') ?? '';
    _fullNameController.text = widget.userData['fullName'] ?? '';
    _awardsController.text = widget.userData['awards'] ?? '';
    _socialLinksController.text = widget.userData['socialLinks'] ?? '';
    _locationController.text = widget.userData['location'] ?? '';
    _educationController.text = widget.userData['education'] ?? '';
    _availabilityController.text =
        widget.userData['availability'] ?? 'Available';
    _languagesController.text =
        (widget.userData['languages'] as List?)?.join(', ') ?? '';
    _specializationController.text = widget.userData['specialization'] ?? '';
    _ratingController.text = widget.userData['rating']?.toString() ?? '';
  }

  void _initializeChatsStream() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.uid.isNotEmpty) {
      _chatsStream = FirestoreService.getUserChats();
    } else {
      _chatsStream = Stream.value([]);
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && mounted) {
          setState(() {
            _chatsStream = FirestoreService.getUserChats();
          });
        }
      });
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await FirestoreService.fetchProfessionalById(widget.uid);
      if (profile != null) {
        setState(() {
          _moreDetails = List<Map<String, dynamic>>.from(
            profile['moreDetails'] ?? [],
          );
        });
      }
    } catch (e) {
      print('Error fetching profile: $e');
    }
  }

  Future<void> _fetchAuditions() async {
    try {
      final auditions = await FirestoreService.fetchAuditionsByProducer(
        widget.uid,
      );
      setState(() {
        _createdAuditions = auditions;
        _isLoadingAuditions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAuditions = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching auditions: $e')));
    }
  }

  Future<void> _deleteAudition(String auditionId) async {
    try {
      await FirestoreService.deleteAudition(auditionId);
      await _fetchAuditions();
      await _fetchApplications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audition deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting audition: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editAudition(Map<String, dynamic> audition) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AuditionCreateScreen(initialAuditionData: audition),
      ),
    );
    if (result != null) {
      // Refresh the auditions list
      await _fetchAuditions();
      await _fetchApplications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audition updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _fetchApplications() async {
    try {
      final applications = await FirestoreService.fetchApplicationsForProducer(
        widget.uid,
      );
      setState(() {
        _applications = applications;
        _isLoadingApplications = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingApplications = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching applications: $e')),
      );
    }
  }

  Future<void> _fetchLiveSessions() async {
    try {
      final sessions = await FirestoreService.fetchLiveSessionsByCreator(widget.uid);
      setState(() {
        _liveSessions = sessions;
        _isLoadingLiveSessions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLiveSessions = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching live sessions: $e')),
      );
    }
  }

  Future<void> _refreshCreatedContent() async {
    await Future.wait([
      _fetchAuditions(),
      _fetchLiveSessions(),
    ]);
  }

  @override
  void dispose() {
    _bioController.dispose();
    _experienceController.dispose();
    _companyController.dispose();
    _projectsController.dispose();
    _fullNameController.dispose();
    _awardsController.dispose();
    _socialLinksController.dispose();
    _locationController.dispose();
    _educationController.dispose();
    _availabilityController.dispose();
    _languagesController.dispose();
    _specializationController.dispose();
    _ratingController.dispose();
    _rejectionCommentCtrl.dispose();
    _reportController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedApplications.contains(id)) {
        _expandedApplications.remove(id);
      } else {
        _expandedApplications.add(id);
      }
    });
  }

  Future<void> _uploadMoreDetails() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result != null) {
        setState(() {
          _isUploadingMoreDetails = true;
        });

        for (var file in result.files) {
          if (file.path != null) {
            final isPdf = file.name.toLowerCase().endsWith('.pdf');
            final resourceType = isPdf ? 'raw' : 'image';
            final uploadResult = await CloudinaryUploader().uploadMedia(
              File(file.path!),
              resourceType,
              null,
            );

            final uploadedItem = {
              'name': file.name,
              'url': uploadResult.url,
              'type': isPdf ? 'PDF' : 'IMAGE',
            };

            _moreDetails.add(uploadedItem);
          }
        }

        // Persist the exact Cloudinary URLs to Firestore under professional profile
        await FirestoreService.saveProfessionalProfile(
          role: widget.role,
          profileData: {'moreDetails': _moreDetails},
        );

        setState(() {
          _isUploadingMoreDetails = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('More details uploaded and saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingMoreDetails = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Calculate total counts from applications
  int _getTotalApplications() {
    return _applications.length;
  }

  int _getAcceptedApplications() {
    return _applications.where((app) => app['status'] == 'Accepted').length;
  }

  int _getRejectedApplications() {
    return _applications.where((app) => app['status'] == 'Rejected').length;
  }

  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildQuickStats(),
          const SizedBox(height: 24),
          _buildAuditionCreation(),
          const SizedBox(height: 24),
          _buildProfileDetails(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    // Minimal header: left label and only a small round avatar with the user name
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9D4EDD), Color(0xFF7B2CBF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9D4EDD).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left top label
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Welcome back',
                        style: TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Filmsphere',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9D4EDD).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE0AAFF).withOpacity(0.5),
                          ),
                        ),
                        child: const Text(
                          'Home',
                          style: TextStyle(
                            color: Color(0xFFE0AAFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.topRight,
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'report') {
                  _showReportDialog();
                } else if (value == 'terms') {
                  _showTermsDialog();
                } else if (value == 'logout') {
                  _logout();
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
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Text(
                    'Logout',
                    style: TextStyle(color: Color(0xFFEF5350)),
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final totalApplications = _getTotalApplications();
    final acceptedApplications = _getAcceptedApplications();
    final rejectedApplications = _getRejectedApplications();

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _navigateToApplications('All'),
            child: _buildStatCard(
              totalApplications.toString(),
              'Applications',
              Icons.assignment,
              const Color(0xFF9D4EDD),
              totalApplications,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _navigateToApplications('Accepted'),
            child: _buildStatCard(
              acceptedApplications.toString(),
              'Accepted',
              Icons.check_circle,
              const Color(0xFF66BB6A),
              acceptedApplications,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _navigateToApplications('Rejected'),
            child: _buildStatCard(
              rejectedApplications.toString(),
              'Rejected',
              Icons.cancel,
              const Color(0xFFEF5350),
              rejectedApplications,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    int count,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (count > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count ${count == 1 ? 'item' : 'items'}',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToApplications(String filter) {
    setState(() {
      _applicationsFilter = filter;
      _currentIndex = 1; // Switch to applications tab
    });
  }

  Widget _buildCreatedAuditionsCarousel() {
    if (_isLoadingAuditions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_createdAuditions.isEmpty) {
      return const SizedBox.shrink();
    }

    // For home screen, show only the first audition in carousel mode, rest in grid if View More is clicked
    final bool showViewMore = _createdAuditions.length > 1;
    final bool isExpanded = _expandedApplications.contains(
      'auditions_carousel',
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.movie, color: Color(0xFFE0AAFF), size: 20),
              SizedBox(width: 8),
              Text(
                'Created Auditions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isExpanded)
            // Carousel view - show first audition
            _buildCarouselAuditionCard(_createdAuditions[0], 0)
          else
            // Grid view - show all auditions
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _createdAuditions.length,
              itemBuilder: (context, index) {
                return _buildGridAuditionCard(_createdAuditions[index], index);
              },
            ),
          if (showViewMore) ...[
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () => _toggleExpanded('auditions_carousel'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D4EDD).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF9D4EDD).withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    isExpanded ? 'Show Less' : 'View More',
                    style: const TextStyle(
                      color: Color(0xFFE0AAFF),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCarouselAuditionCard(Map<String, dynamic> audition, int index) {
    final String title =
        audition['title'] ?? audition['projectName'] ?? 'Untitled';
    final String role = audition['role'] ?? audition['profession'] ?? '';
    final String desc = audition['description'] ?? audition['details'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            role,
            style: const TextStyle(
              color: Color(0xFFE0AAFF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGridAuditionCard(Map<String, dynamic> audition, int index) {
    final String title =
        audition['title'] ?? audition['projectName'] ?? 'Untitled';
    final String role = audition['role'] ?? audition['profession'] ?? '';

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = 1); // Go to Auditions tab
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: const TextStyle(
                    color: Color(0xFFE0AAFF),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF9D4EDD).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'View Details',
                style: TextStyle(
                  color: Color(0xFFE0AAFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditionUpdatesSection() {
    // Get all applications with their audition info
    final requestedApps = _applications
        .where(
          (app) => app['status'] != 'Accepted' && app['status'] != 'Rejected',
        )
        .toList();
    final acceptedApps = _applications
        .where((app) => app['status'] == 'Accepted')
        .toList();
    final rejectedApps = _applications
        .where((app) => app['status'] == 'Rejected')
        .toList();

    if (_applications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: Color(0xFFE0AAFF),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Audition Updates',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Status chips in a row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip(
                  'Requested',
                  requestedApps.length,
                  const Color(0xFF9D4EDD),
                ),
                const SizedBox(width: 12),
                _buildStatusChip(
                  'Accepted',
                  acceptedApps.length,
                  const Color(0xFF66BB6A),
                ),
                const SizedBox(width: 12),
                _buildStatusChip(
                  'Rejected',
                  rejectedApps.length,
                  const Color(0xFFEF5350),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Recent updates
          const Text(
            'Recent Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (requestedApps.isNotEmpty)
            _buildUpdateItem(requestedApps.first, 'requested')
          else if (acceptedApps.isNotEmpty)
            _buildUpdateItem(acceptedApps.first, 'accepted')
          else if (rejectedApps.isNotEmpty)
            _buildUpdateItem(rejectedApps.first, 'rejected')
          else
            Center(
              child: Text(
                'No updates yet',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF9D4EDD).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF9D4EDD).withOpacity(0.5),
                  ),
                ),
                child: const Text(
                  'View All Auditions',
                  style: TextStyle(
                    color: Color(0xFFE0AAFF),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateItem(Map<String, dynamic> application, String status) {
    final String name = application['name'] ?? 'Unknown';
    final String auditionTitle =
        application['auditionTitle'] ?? 'Unknown Audition';

    Color statusColor;
    String statusText;

    switch (status) {
      case 'accepted':
        statusColor = const Color(0xFF66BB6A);
        statusText = 'Accepted';
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF5350);
        statusText = 'Rejected';
        break;
      default:
        statusColor = const Color(0xFF9D4EDD);
        statusText = 'Requested';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(
              application['applicantImage'] ?? 'https://via.placeholder.com/40',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  auditionTitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }





































  Widget _buildLiveSessionsSection() {
    if (_isLoadingLiveSessions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_liveSessions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Sessions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _liveSessions.length,
              itemBuilder: (context, index) {
                return _buildLiveSessionCard(_liveSessions[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditionCreation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle, color: Color(0xFFE0AAFF), size: 20),
              SizedBox(width: 8),
              Text(
                'Create New Audition',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Create audition calls and manage applications from talented artists',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9D4EDD).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                _createNewAudition();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D4EDD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'CREATE AUDITION',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (_canCreateLiveSession) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: OutlinedButton(
                onPressed: _createLiveSession,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF9D4EDD)),
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF1E1B2E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.live_tv, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'CREATE LIVE SESSION',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveSessionCardTappable(Map<String, dynamic> session) {
    final title = session['eventName'] ?? 'Untitled';
    final description = session['about'] ?? '';
    final date = session['date'] ?? '';
    final time = session['time'] ?? '';
    final thumbnail = session['thumbnailUrl'] ?? '';

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumbnail.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    thumbnail,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$date • $time',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.comment, size: 16, color: const Color(0xFF9D4EDD)),
                        const SizedBox(width: 6),
                        const Text('View Comments', style: TextStyle(color: Color(0xFF9D4EDD), fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteLiveSession(session['id']),
          ),
        ),
      ],
    );
  }

  void _showSessionDetailScreen(Map<String, dynamic> session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(session: session, creatorId: widget.uid),
      ),
    );
  }

  Widget _buildLiveSessionCard(Map<String, dynamic> session) {
    final title = session['eventName'] ?? 'Untitled';
    final description = session['about'] ?? '';
    final date = session['date'] ?? '';
    final time = session['time'] ?? '';
    final thumbnail = session['thumbnailUrl'] ?? '';

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thumbnail.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                thumbnail,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 215, 211, 211),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$date $time',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showCommentsDialog(session['id']),
                        icon: const Icon(Icons.comment, size: 16),
                        label: const Text('Selection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D4EDD),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _deleteLiveSession(session['id']),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentsDialog(String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Text('Selection', style: TextStyle(color: Color.fromARGB(255, 10, 8, 8))),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreService.getComments(sessionId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final comments = snapshot.data!;
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return _buildCommentItem(sessionId, comment);
                      },
                    ),
                  ),
                  _buildAddCommentField(sessionId),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }





































  Widget _buildCommentItem(String sessionId, Map<String, dynamic> comment) {
    final commentId = comment['id'];
    final userId = comment['userId'];
    final text = _getCommentText(comment);
    final timestamp = comment['timestamp'] as Timestamp?;
    final isOwn = userId == FirebaseAuth.instance.currentUser?.uid;

    final userName = comment['userName'] ?? 'User';
    final userImage = comment['userImage'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (userImage != null && userImage.toString().isNotEmpty)
                CircleAvatar(
                  radius: 12,
                  backgroundImage: CachedNetworkImageProvider(userImage),
                )
              else
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: Color(0xFF9D4EDD),
                  child: Icon(Icons.person, color: Colors.white, size: 14),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  userName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              if (isOwn)
                IconButton(
                  onPressed: () => _deleteComment(sessionId, commentId),
                  icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(color: Color.fromARGB(255, 15, 13, 13)),
          ),
          if (comment['attachmentUrl'] != null &&
              comment['attachmentUrl'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildCommentAttachmentPreview(
              context,
              comment['attachmentUrl'],
              comment['attachmentType'],
              comment['attachmentName'],
            ),
          ],
          Text(
            timestamp != null ? _formatTimestamp(timestamp) : '',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }


























  Widget _buildAddCommentField(String sessionId) {
    final controller = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Color.fromARGB(255, 8, 5, 5)),
            decoration: const InputDecoration(
              hintText: 'Add comment...',
              hintStyle: TextStyle(color: Color.fromARGB(179, 11, 9, 9)),
            ),
          ),
        ),
        IconButton(
          onPressed: () async {
            if (controller.text.trim().isNotEmpty) {
              final commentData = await _buildCommentPayload(controller.text.trim());
              await FirebaseFirestore.instance
                  .collection('events')
                  .doc(sessionId)
                  .collection('comments')
                  .add(commentData);
              controller.clear();
            }
          },
          icon: const Icon(Icons.send, color: Color(0xFF9D4EDD)),
        ),
      ],
    );
  }

  Future<void> _deleteComment(String sessionId, String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(sessionId)
          .collection('comments')
          .doc(commentId)
          .delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting comment: $e')),
      );
    }
  }

  Future<void> _deleteLiveSession(String sessionId) async {
    try {
      await FirestoreService.deleteLiveSession(sessionId);
      await _fetchLiveSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live session deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting live session: $e')),
      );
    }
  }

  Widget _buildProfileDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.business, color: Color(0xFFE0AAFF), size: 20),
              SizedBox(width: 8),
              Text(
                'Company & Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Always visible fields
          _buildFormField('Full Name', _fullNameController),
          const SizedBox(height: 16),
          _buildFormField(
            'Location',
            _locationController,
            hint: 'City, Country or Region',
          ),
          const SizedBox(height: 16),
          _buildFormField('Company Name', _companyController),
          const SizedBox(height: 16),
          _buildFormField(
            'Experience',
            _experienceController,
            hint: 'e.g., 8 years in film production',
          ),

          // Expandable section
          if (_isProfileExpanded) ...[
            const SizedBox(height: 16),
            _buildFormField(
              'Education',
              _educationController,
              hint: 'e.g., BA, MA',
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Specialization',
              _specializationController,
              hint: 'e.g., acting, directing',
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Languages',
              _languagesController,
              hint: 'Comma separated: Hindi, English, Tamil',
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Availability',
              _availabilityController,
              hint: 'Available/Not Available',
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Previous Projects',
              _projectsController,
              maxLines: 3,
              hint: 'List your notable projects',
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Awards',
              _awardsController,
              maxLines: 2,
              hint: 'List awards or recognitions',
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Social Media Links',
              _socialLinksController,
              maxLines: 2,
              hint: 'Instagram, Twitter, TikTok links',
            ),
            const SizedBox(height: 16),
            // More Details upload (PDF / Images)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'More Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_moreDetails.length} files',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_moreDetails.isNotEmpty) ...[
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _moreDetails.length,
                      itemBuilder: (context, index) {
                        final file = _moreDetails[index];
                        final isPdf =
                            file['name']?.toLowerCase().endsWith('.pdf') ??
                            false;
                        final isImage = file['type'] == 'IMAGE';
                        return GestureDetector(
                          onTap: isImage
                              ? () => _showImageDialog(file['url'])
                              : null,
                          child: Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Icon(
                                    isPdf ? Icons.picture_as_pdf : Icons.image,
                                    color: const Color(0xFFE0AAFF),
                                    size: 32,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _moreDetails.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  right: 4,
                                  child: Text(
                                    file['name'] ?? 'Document',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _isUploadingMoreDetails
                    ? const Center(child: CircularProgressIndicator())
                    : GestureDetector(
                        onTap: _uploadMoreDetails,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF7B2CBF).withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.attach_file,
                                color: Color(0xFFE0AAFF),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Upload More Details (PDF / Images)',
                                style: TextStyle(
                                  color: Color(0xFFE0AAFF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Bio',
              _bioController,
              maxLines: 4,
              hint: 'Tell about your work and vision',
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isProfileExpanded = false;
                  });
                },
                icon: const Icon(Icons.expand_less, color: Color(0xFF9D4EDD)),
                label: const Text(
                  'View Less',
                  style: TextStyle(color: Color(0xFF9D4EDD), fontSize: 16),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isProfileExpanded = true;
                  });
                },
                icon: const Icon(Icons.expand_more, color: Color(0xFF9D4EDD)),
                label: const Text(
                  'View More Details',
                  style: TextStyle(color: Color(0xFF9D4EDD), fontSize: 16),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          // Save Profile Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfileToFirebase,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D4EDD),
                disabledBackgroundColor: const Color(
                  0xFF9D4EDD,
                ).withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String hint = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint.isNotEmpty ? hint : 'Enter your $label',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF9D4EDD), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  bool get _canCreateLiveSession {
    final roleLower = widget.role.toLowerCase().trim();
    return roleLower == 'casting director' ||
        roleLower == 'director' ||
        roleLower == 'producer';
  }

  void _createLiveSession() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LiveSessionCreateScreen()),
    ).then((result) {
      if (result == true) {
        _refreshCreatedContent();
      }
    });
  }

  void _createNewAudition() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuditionCreateScreen()),
    ).then((result) async {
      if (result != null) {
        try {
          await FirestoreService.saveAudition(result);
          _fetchAuditions(); // Refresh the list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audition created successfully!')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating audition: $e')),
          );
        }
      }
    });
  }

  Widget _buildApplicationsScreen() {
    if (_isLoadingApplications) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Map<String, dynamic>> filteredApplications = _applications;
    if (_applicationsFilter != 'All') {
      filteredApplications = _applications
          .where((app) => app['status'] == _applicationsFilter)
          .toList();
    }

    if (filteredApplications.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Applications - $_applicationsFilter',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'No $_applicationsFilter applications',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Applications - $_applicationsFilter',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredApplications.length,
        itemBuilder: (context, index) {
          final application = filteredApplications[index];
          return _buildApplicationCard(application);
        },
      ),
    );
  }

  Widget _buildCreatedAuditionsScreen() {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Created Content',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFF9D4EDD),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Created Auditions'),
              Tab(text: 'Created Live Sessions'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _refreshCreatedContent,
              child: _createdAuditions.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [
                        SizedBox(height: 48),
                        Center(
                          child: Text(
                            'No auditions created yet',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _createdAuditions.length,
                      itemBuilder: (context, index) {
                        final audition = _createdAuditions[index];
                        return _buildAuditionCard(audition, index);
                      },
                    ),
            ),
            RefreshIndicator(
              onRefresh: _refreshCreatedContent,
              child: _isLoadingLiveSessions
                  ? const Center(child: CircularProgressIndicator())
                  : _liveSessions.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(16),
                          children: const [
                            SizedBox(height: 48),
                            Center(
                              child: Text(
                                'No live sessions created yet',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _liveSessions.length,
                          itemBuilder: (context, index) {
                            final session = _liveSessions[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: GestureDetector(
                                onTap: () => _showSessionDetailScreen(session),
                                child: _buildLiveSessionCardTappable(session),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    final stream = _chatsStream ?? Stream.value([]);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          color: const Color(0xFF1E1B2E),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search chats...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFE0AAFF)),
              filled: true,
              fillColor: const Color(0xFF0F0F1B),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color(0xFF9D4EDD),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading chats: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final chatData = snapshot.data ?? [];
              final chats = chatData.cast<Map<String, dynamic>>();
              if (chats.isEmpty) {
                return const Center(
                  child: Text(
                    'No chats yet',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return _buildProducerChatItem(chat, _searchController.text);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProducerChatItem(Map<String, dynamic> chat, String searchQuery) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final participants = ChatUtilities.extractChatParticipantIds(
      chat['participants'],
    );
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    return Container(
      key: ValueKey(chat['id'] ?? otherUserId),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: otherUserId.isNotEmpty
            ? FirestoreService.getUserData(otherUserId)
            : Future.value(null),
        builder: (context, snapshot) {
          final userData = snapshot.data ?? {};
          final name = userData['name'] ?? userData['username'] ?? 'Unknown';
          if (searchQuery.isNotEmpty &&
              !name.toLowerCase().contains(searchQuery.toLowerCase())) {
            return const SizedBox.shrink();
          }
          final imageUrl =
              userData['image'] ?? 'https://via.placeholder.com/100';
          final lastMessage = chat['lastMessage'] ?? '';
          final lastMessageTime = chat['lastMessageTime'];
          final timeString = lastMessageTime != null
              ? _formatTimestamp(lastMessageTime)
              : '';

          int unreadCount = 0;
          final unreadMap = chat['unreadCount'];
          if (unreadMap is Map<String, dynamic>) {
            final value = unreadMap[currentUserId];
            if (value is int) {
              unreadCount = value;
            } else if (value is num) {
              unreadCount = value.toInt();
            }
          }

          return ListTile(
            key: ValueKey(chat['id'] ?? otherUserId),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(imageUrl),
              backgroundColor: Colors.grey.shade800,
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              lastMessage.toString(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeString,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9D4EDD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () async {
              if (otherUserId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to open chat')),
                );
                return;
              }

              try {
                String chatId = chat['id']?.toString() ?? '';
                if (chatId.isEmpty) {
                  // Fallback: create/get chat id for user-to-user conversation
                  chatId = await FirestoreService.createOrGetChat(otherUserId);
                }

                if (chatId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to open chat, missing id'),
                    ),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfessionalChatScreen(
                      chatId: chatId,
                      professional: userData.isNotEmpty
                          ? userData
                          : {
                              'id': otherUserId,
                              'name': name,
                              'image': imageUrl,
                            },
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error opening chat: $e')),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildAuditionCard(Map<String, dynamic> audition, int index) {
    final String auditionId = audition['id'] ?? '$index';
    final bool isExpanded = _expandedApplications.contains(auditionId);
    final String title =
        audition['title'] ?? audition['projectName'] ?? 'Untitled';
    final String role = audition['role'] ?? audition['profession'] ?? '';
    final String desc = audition['description'] ?? audition['details'] ?? '';
    final String location = audition['location'] ?? 'Unknown';
    final String budget = audition['budget'] ?? 'TBD';

    // Filter applications for this audition
    final auditionApps = _applications
        .where(
          (app) =>
              app['auditionId'] == auditionId || app['auditionTitle'] == title,
        )
        .toList();

    final requestedApps = auditionApps
        .where(
          (app) => app['status'] != 'Accepted' && app['status'] != 'Rejected',
        )
        .toList();
    final acceptedApps = auditionApps
        .where((app) => app['status'] == 'Accepted')
        .toList();
    final rejectedApps = auditionApps
        .where((app) => app['status'] == 'Rejected')
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audition Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Audition Cover Image
                if (audition['image'] != null &&
                    audition['image'].isNotEmpty) ...[
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(audition['image']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Title and Actions Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role,
                            style: const TextStyle(
                              color: Color(0xFFE0AAFF),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Like Button
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Added to favorites!')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.favorite_border,
                          color: Color(0xFFE0AAFF),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Description
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      desc,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // Location and Budget
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.currency_rupee,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          budget,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Edit and Delete Buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _editAudition(audition),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9D4EDD).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF9D4EDD).withOpacity(0.5),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.edit,
                                size: 14,
                                color: Color(0xFFE0AAFF),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  color: Color(0xFFE0AAFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _deleteAudition(auditionId);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF5350).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFEF5350).withOpacity(0.5),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete,
                                size: 14,
                                color: Color(0xFFEF5350),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Color(0xFFEF5350),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _toggleExpanded(auditionId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isExpanded ? 'Show Less' : 'View More',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Divider
          Container(height: 1, color: Colors.white.withOpacity(0.1)),
          // Applications Section (shown only if expanded)
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Application Status Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusChip(
                          'Requested',
                          requestedApps.length,
                          const Color(0xFF9D4EDD),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Accepted',
                          acceptedApps.length,
                          const Color(0xFF66BB6A),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Rejected',
                          rejectedApps.length,
                          const Color(0xFFEF5350),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Requested Applications
                  if (requestedApps.isNotEmpty) ...[
                    const Text(
                      'Requested',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: requestedApps.length,
                      itemBuilder: (context, idx) =>
                          _buildApplicantCard(requestedApps[idx], 'Requested'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Accepted Applications
                  if (acceptedApps.isNotEmpty) ...[
                    const Text(
                      'Accepted',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: acceptedApps.length,
                      itemBuilder: (context, idx) =>
                          _buildApplicantCard(acceptedApps[idx], 'Accepted'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Rejected Applications
                  if (rejectedApps.isNotEmpty) ...[
                    const Text(
                      'Rejected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rejectedApps.length,
                      itemBuilder: (context, idx) =>
                          _buildApplicantCard(rejectedApps[idx], 'Rejected'),
                    ),
                  ],
                  if (auditionApps.isEmpty)
                    Center(
                      child: Text(
                        'No applications yet',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantCard(Map<String, dynamic> application, String status) {
    final String name = application['name'] ?? 'Unknown';
    final String role = application['role'] ?? 'Unknown Role';
    final String skills = application['skills'] ?? 'N/A';

    return GestureDetector(
      onTap: () => _showApplicantDetails(application),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(
                application['photoUrl'] ?? 'https://via.placeholder.com/48',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    role,
                    style: const TextStyle(
                      color: Color(0xFFE0AAFF),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Skills: $skills',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (status == 'Requested') ...[
              GestureDetector(
                onTap: () => _acceptApplication(application),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF66BB6A).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF66BB6A),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _rejectApplication(application),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF5350).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.cancel,
                    color: Color(0xFFEF5350),
                    size: 20,
                  ),
                ),
              ),
            ] else if (status == 'Accepted') ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF66BB6A).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF66BB6A).withOpacity(0.5),
                  ),
                ),
                child: const Text(
                  'Accepted',
                  style: TextStyle(
                    color: Color(0xFF66BB6A),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFEF5350).withOpacity(0.5),
                  ),
                ),
                child: const Text(
                  'Rejected',
                  style: TextStyle(
                    color: Color(0xFFEF5350),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showApplicantDetails(Map<String, dynamic> application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: Text(
          application['name'] ?? 'Applicant Details',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo
              if (application['photoUrl'] != null &&
                  application['photoUrl'].toString().isNotEmpty)
                Center(
                  child: GestureDetector(
                    onTap: () => _showImageDialog(application['photoUrl']),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(application['photoUrl']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Video
              if (application['videoUrl'] != null &&
                  application['videoUrl'].toString().isNotEmpty)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _showVideoDialog(application['videoUrl']),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A60C8),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _detailItem('Role', application['role'] ?? 'N/A'),
              _detailItem('Gender', application['gender'] ?? 'N/A'),
              _detailItem('Age', application['age'] ?? 'N/A'),
              _detailItem('Height', application['height'] ?? 'N/A'),
              _detailItem('Weight', application['weight'] ?? 'N/A'),
              _detailItem('Phone', application['phone'] ?? 'N/A'),
              _detailItem('Address', application['address'] ?? 'N/A'),
              _detailItem('Current Place', application['place'] ?? 'N/A'),
              _detailItem('Skills', application['skills'] ?? 'N/A'),
              _detailItem('About Me', application['aboutMe'] ?? 'N/A'),
              _detailItem('Status', application['status'] ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFE0AAFF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    Color statusColor;
    IconData statusIcon;

    switch (application['status']) {
      case 'Accepted':
        statusColor = const Color(0xFF66BB6A);
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = const Color(0xFFEF5350);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFF9D4EDD);
        statusIcon = Icons.access_time;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and status
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(statusIcon, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    application['status'] ?? 'Applied',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (application['photoUrl'] != null &&
                (application['photoUrl'] as String).isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  application['photoUrl'],
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      alignment: Alignment.center,
                      color: Colors.white12,
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        color: const Color(0xFF9D4EDD),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      alignment: Alignment.center,
                      color: Colors.white10,
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (application['videoUrl'] != null &&
                (application['videoUrl'] as String).isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showVideoDialog(application['videoUrl']),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Play Submitted Reel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A60C8),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_expandedApplications.contains(application['id'])) ...[
              // Personal Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        color: Color(0xFFE0AAFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDetailRow('Gender', application['gender'] ?? 'N/A'),
                    _buildDetailRow(
                      'Age',
                      '${application['age'] ?? 'N/A'} years',
                    ),
                    _buildDetailRow(
                      'Height',
                      '${application['height'] ?? 'N/A'} cm',
                    ),
                    _buildDetailRow(
                      'Weight',
                      '${application['weight'] ?? 'N/A'} kg',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Contact Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        color: Color(0xFFE0AAFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDetailRow('Phone', application['phone'] ?? 'N/A'),
                    _buildDetailRow('Address', application['address'] ?? 'N/A'),
                    _buildDetailRow('Place', application['place'] ?? 'N/A'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Professional Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Professional Information',
                      style: TextStyle(
                        color: Color(0xFFE0AAFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      'Skills & Experience',
                      application['skills'] ?? 'N/A',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'About Me',
                      application['aboutMe'] ?? 'N/A',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Submission Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Submission Details',
                      style: TextStyle(
                        color: Color(0xFFE0AAFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      'Submitted',
                      _formatTimestamp(application['submittedAt']),
                    ),
                    if (application['updatedAt'] != null)
                      _buildDetailRow(
                        'Last Updated',
                        _formatTimestamp(application['updatedAt']),
                      ),
                    _buildDetailRow(
                      'Audition',
                      application['auditionId'] ?? 'N/A',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons - Show only if application is in Applied status
              if (application['status'] == 'Applied')
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptApplication(application),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF66BB6A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _rejectApplication(application),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF5350),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                )
              else
                // Status Display - Show when application is Accepted or Rejected
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: application['status'] == 'Accepted'
                        ? const Color(0xFF66BB6A).withOpacity(0.1)
                        : const Color(0xFFEF5350).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: application['status'] == 'Accepted'
                          ? const Color(0xFF66BB6A)
                          : const Color(0xFFEF5350),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        application['status'] == 'Accepted'
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: application['status'] == 'Accepted'
                            ? const Color(0xFF66BB6A)
                            : const Color(0xFFEF5350),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Application ${application['status']}',
                            style: TextStyle(
                              color: application['status'] == 'Accepted'
                                  ? const Color(0xFF66BB6A)
                                  : const Color(0xFFEF5350),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _formatTimestamp(application['updatedAt']),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _toggleExpanded(application['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9D4EDD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('View Less'),
                ),
              ),
            ] else ...[
              _buildDetailRow('Role', application['role'] ?? 'Not specified'),
              _buildDetailRow(
                'Specialization',
                application['specialization'] ?? 'N/A',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _toggleExpanded(application['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9D4EDD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('View More'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVideoDialog(String videoUrl) async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.network(videoUrl);
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1B2E),
            title: const Text(
              'Submitted Video',
              style: TextStyle(color: Colors.white),
            ),
            content: AspectRatio(
              aspectRatio: controller!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(controller),
                  VideoProgressIndicator(controller, allowScrubbing: true),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cannot play video: $e')));
    } finally {
      if (controller != null) {
        await controller.pause();
        await controller.dispose();
      }
    }
  }

  void _acceptApplication(Map<String, dynamic> application) async {
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          title: const Text(
            'Accept Application',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Why are you selecting this applicant?',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter your message...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF9D4EDD),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final message = messageController.text.trim();
                if (message.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a message'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop(); // Close dialog

                try {
                  // Update application status with message
                  await FirestoreService.updateApplicationStatus(
                    application['id'],
                    'Accepted',
                    message: message,
                  );
                  setState(() {
                    application['status'] = 'Accepted';
                    application['acceptanceMessage'] = message;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Application accepted'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Navigate to applicant's profile screen
                  final applicantUid =
                      application['userId'] ?? application['applicantId'];
                  if (applicantUid != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfessionalProfileScreen(
                          professionalId: applicantUid,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF66BB6A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
  }

  void _rejectApplication(Map<String, dynamic> application) {
    _showRejectionDialog(application);
  }

  void _showRejectionDialog(Map<String, dynamic> application) {
    _selectedRejectionReason = null;
    _rejectionCommentCtrl.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: const Color(0xFF1E1B2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reject Application',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Rejection Reason Dropdown
                    const Text(
                      'Select Reason *',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF7B2CBF).withOpacity(0.3),
                        ),
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        underline: Container(),
                        value: _selectedRejectionReason,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        dropdownColor: const Color(0xFF1E1B2E),
                        style: const TextStyle(color: Colors.white),
                        hint: Text(
                          'Choose a reason',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        items: _rejectionReasons.map((String reason) {
                          return DropdownMenuItem<String>(
                            value: reason,
                            child: Text(reason),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setStateDialog(() {
                            _selectedRejectionReason = newValue;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Optional Comment Box
                    const Text(
                      'Additional Comments (Optional)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _rejectionCommentCtrl,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            'Add feedback or suggestions for the candidate...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF9D4EDD),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF7B2CBF)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _selectedRejectionReason == null
                                ? null
                                : () => _submitRejection(application, context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF5350),
                              disabledBackgroundColor: const Color(
                                0xFFEF5350,
                              ).withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Send Rejection',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitRejection(
    Map<String, dynamic> application,
    BuildContext dialogContext,
  ) async {
    try {
      await FirestoreService.updateApplicationStatusWithReason(
        application['id'],
        'Rejected',
        _selectedRejectionReason ?? '',
        _rejectionCommentCtrl.text,
      );

      if (mounted) {
        Navigator.pop(dialogContext);
        setState(() {
          application['status'] = 'Rejected';
          application['rejectionReason'] = _selectedRejectionReason;
          application['rejectionComment'] = _rejectionCommentCtrl.text;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application rejected successfully'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _saveProfileToFirebase() async {
    if (_fullNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Prepare the professional profile data
      final profileData = {
        'fullName': _fullNameController.text,
        'bio': _bioController.text,
        'experience': _experienceController.text,
        'company': _companyController.text,
        'previousWorks': _projectsController.text,
        'awards': _awardsController.text,
        'socialLinks': _socialLinksController.text,
        'location': _locationController.text,
        'education': _educationController.text,
        'availability': _availabilityController.text,
        'languages': _languagesController.text
            .split(',')
            .map((lang) => lang.trim())
            .where((lang) => lang.isNotEmpty)
            .toList(),
        'specialization': _specializationController.text,
        'rating': _ratingController.text,
        'image': widget.userData['image'] ?? 'no',
        'moreDetails': _moreDetails,
      };

      await FirestoreService.saveProfessionalProfile(
        role: widget.role,
        profileData: profileData,
      );

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
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

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFEF5350)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      body: _currentIndex == 0
          ? _buildHomeScreen()
          : _currentIndex == 1
          ? _buildCreatedAuditionsScreen()
          : _currentIndex == 2
          ? _buildChatTab()
          : ProfessionalProfileScreen(professionalId: widget.uid),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            selectedItemColor: const Color(0xFFE0AAFF),
            unselectedItemColor: Colors.white.withOpacity(0.5),
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            iconSize: 22,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.audiotrack_rounded),
                label: 'Auditions',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_rounded),
                label: 'Chats',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        content: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Text(
            'Failed to load image',
            style: TextStyle(color: Color.fromARGB(255, 214, 210, 210)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

Future<void> _showImageDialog(BuildContext context, String imageUrl) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.black,
      content: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Text(
          'Failed to load image',
          style: TextStyle(color: Color.fromARGB(255, 214, 210, 210)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

Future<void> _showVideoDialog(BuildContext context, String videoUrl) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.black,
      content: AspectRatio(
        aspectRatio: 16 / 9,
        child: VideoPlayerWidget(videoUrl: videoUrl),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

String _getCommentText(Map<String, dynamic> comment) {
  return (comment['text'] ?? comment['comment'] ?? '').toString();
}

Widget _buildCommentAttachmentPreview(
  BuildContext context,
  String? attachmentUrl,
  String? attachmentType,
  String? attachmentName,
) {
  if (attachmentUrl == null || attachmentUrl.isEmpty) {
    return const SizedBox.shrink();
  }

  final type = attachmentType?.toLowerCase() ?? '';
  if (type.contains('image')) {
    return GestureDetector(
      onTap: () => _showImageDialog(context, attachmentUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: attachmentUrl,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 180,
            color: const Color(0xFF33334A),
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            height: 180,
            color: const Color(0xFF33334A),
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }

  if (type.contains('video')) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: ElevatedButton.icon(
        onPressed: () => _showVideoDialog(context, attachmentUrl),
        icon: const Icon(Icons.play_arrow),
        label: Text(
          attachmentName != null && attachmentName.isNotEmpty ? attachmentName : 'View video',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9D4EDD),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.2)),
      ),
      child: Text(
        attachmentName != null && attachmentName.isNotEmpty
            ? 'Attachment: $attachmentName'
            : 'Attachment available',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    ),
  );
}

class SessionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  final String creatorId;

  const SessionDetailScreen({super.key, required this.session, required this.creatorId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late TextEditingController _commentController;
  String? _replyingToCommentId;
  String? _replyingToAuthor;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<String> _fetchUserName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      return userDoc.data()?['name'] ?? userDoc.data()?['username'] ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final sessionId = widget.session['id'];
    if (sessionId == null || sessionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Invalid session ID'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final commentData = await _buildCommentPayload(_commentController.text.trim());

      if (_replyingToCommentId != null) {
        // Add as reply
        await FirebaseFirestore.instance
            .collection('events')
            .doc(sessionId)
            .collection('comments')
            .doc(_replyingToCommentId)
            .collection('replies')
            .add(commentData);
      } else {
        // Add as top-level comment
        await FirebaseFirestore.instance
            .collection('events')
            .doc(sessionId)
            .collection('comments')
            .add(commentData);
      }

      _commentController.clear();
      if (mounted) {
        setState(() {
          _replyingToCommentId = null;
          _replyingToAuthor = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error posting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectComment(String commentId, Map<String, dynamic> comment) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.session['id'])
          .collection('selected')
          .doc(commentId)
          .set(comment);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment selected'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting comment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deselectComment(String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.session['id'])
          .collection('selected')
          .doc(commentId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deselected'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deselecting comment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showCommenterProfile(String userId) async {
    if (userId.isEmpty) return;

    try {
      final userData = await FirestoreService.getUserData(userId);
      if (!mounted) return;

      if (userData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile not found.')),
        );
        return;
      }

      if (userData['type'] == 'professional') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfessionalProfileScreen(
              professionalId: userId,
            ),
          ),
        );
        return;
      }

      final userName = userData['displayName'] ?? userData['name'] ?? userData['username'] ?? userData['fullName'] ?? 'Unknown User';
      final userImage = userData['image'] ?? userData['photoUrl'] ?? userData['photoURL'] ?? userData['profileImage'] ?? userData['avatar'] ?? userData['userImage'] ?? '';
      final location = userData['location'] ?? userData['city'] ?? userData['address'] ?? '';
      final experience = userData['experience'] ?? userData['yearsExperience'] ?? '';
      final specialization = userData['specialization'] ?? userData['speciality'] ?? '';
      final bio = userData['bio'] ?? userData['about'] ?? userData['description'] ?? '';
      final email = userData['email'] ?? '';
      final phone = userData['phone'] ?? userData['phoneNumber'] ?? userData['contact'] ?? '';
      final availability = userData['availability'] ?? '';
      final education = userData['education'] ?? '';
      final awards = userData['awards'] ?? '';
      final socialLinks = userData['socialLinks'] ?? userData['links'] ?? '';
      final moreDetails = userData['moreDetails'];

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
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
                  if (location.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Location: $location', style: const TextStyle(color: Colors.white70)),
                    ),
                  if (experience.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Experience: $experience', style: const TextStyle(color: Colors.white70)),
                    ),
                  if (specialization.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Specialization: $specialization', style: const TextStyle(color: Colors.white70)),
                    ),
                  if (availability.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Availability: $availability', style: const TextStyle(color: Colors.white70)),
                    ),
                  if (education.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Education: $education', style: const TextStyle(color: Colors.white70)),
                    ),
                  if (awards.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Awards: $awards', style: const TextStyle(color: Colors.white70)),
                    ),
                  if (socialLinks.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Social: $socialLinks', style: const TextStyle(color: Colors.white70)),
                    ),
                  if (email.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Email: $email', style: const TextStyle(color: Colors.white70)),
                    ),
                  if (phone.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Phone: $phone', style: const TextStyle(color: Colors.white70)),
                    ),
                  if (bio.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Bio: $bio', style: const TextStyle(color: Colors.white70)),
                    ),
                  if (moreDetails is List && moreDetails.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Portfolio / Documents:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...moreDetails.map<Widget>((item) {
                            final title = item['title'] ?? item['name'] ?? item['fileName'] ?? 'Attachment';
                            final url = item['url'] ?? item['link'] ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Text(
                                '$title${url.toString().isNotEmpty ? ' — $url' : ''}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load profile: $e')),
      );
    }
  }

  Widget _buildCommentsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.session['id'])
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No comments yet', style: TextStyle(color: Colors.white70));
        }
        return ListView(
          shrinkWrap: true,
          children: snapshot.data!.docs.map((comment) {
            return _buildCommentThread(comment.id, comment.data() as Map<String, dynamic>);
          }).toList(),
        );
      },
    );
  }

  Widget _buildSelectedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.session['id'])
          .collection('selected')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No selected participants yet', style: TextStyle(color: Colors.white70));
        }
        return ListView(
          shrinkWrap: true,
          children: snapshot.data!.docs.map((doc) {
            final comment = doc.data() as Map<String, dynamic>;
            return _buildSelectedCommentThread(doc.id, comment);
          }).toList(),
        );
      },
    );
  }

  Widget _buildSelectedCommentThread(String commentId, Map<String, dynamic> comment) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final sessionId = widget.session['id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String>(
                  future: _fetchUserName(comment['userId']),
                  builder: (context, snapshot) {
                    final userName = snapshot.data ?? 'Unknown';
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => _showCommenterProfile(comment['userId']),
                          child: Row(
                            children: [
                              if (comment['userImage'] != null && comment['userImage'].toString().isNotEmpty)
                                CircleAvatar(
                                  radius: 12,
                                  backgroundImage: CachedNetworkImageProvider(comment['userImage']),
                                )
                              else
                                const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Color(0xFF9D4EDD),
                                  child: Icon(Icons.person, color: Colors.white, size: 14),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                userName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (widget.creatorId == currentUser?.uid)
                          GestureDetector(
                            onTap: () => _deselectComment(commentId),
                            child: const Icon(Icons.close, color: Colors.red, size: 16),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  _getCommentText(comment),
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                ),
                if (comment['attachmentUrl'] != null &&
                    comment['attachmentUrl'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildCommentAttachmentPreview(
                    context,
                    comment['attachmentUrl'],
                    comment['attachmentType'],
                    comment['attachmentName'],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatTime(comment['timestamp']),
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Replies Section if any
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .doc(sessionId)
                .collection('comments')
                .doc(commentId)
                .collection('replies')
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.01),
                  border: Border(left: BorderSide(color: const Color(0xFF9D4EDD).withOpacity(0.3), width: 2)),
                ),
                margin: const EdgeInsets.all(12),
                child: Column(
                  children: snapshot.data!.docs.map((reply) {
                    return _buildReplyItem(reply.id, reply.data() as Map<String, dynamic>, commentId);
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.session['eventName'] ?? 'Untitled';
    final description = widget.session['about'] ?? '';
    final date = widget.session['date'] ?? '';
    final time = widget.session['time'] ?? '';
    final thumbnail = widget.session['thumbnailUrl'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Session Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session Header
                  if (thumbnail.isNotEmpty)
                    Image.network(
                      thumbnail,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$date • $time',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Comments & Selected',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              TabBar(
                                labelColor: Colors.white,
                                unselectedLabelColor: Colors.white70,
                                indicatorColor: const Color(0xFF9D4EDD),
                                tabs: const [
                                  Tab(text: 'Comments'),
                                  Tab(text: 'Selected'),
                                ],
                              ),
                              SizedBox(
                                height: 400, // adjust height as needed
                                child: TabBarView(
                                  children: [
                                    _buildCommentsTab(),
                                    _buildSelectedTab(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Comment Input at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1B),
              border: Border(top: BorderSide(color: Colors.white12, width: 1)),
            ),
            child: Column(
              children: [
                if (_replyingToCommentId != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B2E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Replying to $_replyingToAuthor',
                              style: const TextStyle(color: Color(0xFF9D4EDD), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _replyingToCommentId = null),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText: _replyingToCommentId != null ? 'Write a reply...' : 'Write a comment...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          maxLines: null,
                        ),
                      ),
                      IconButton(
                        onPressed: _postComment,
                        icon: const Icon(Icons.send, color: Color(0xFF9D4EDD)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentThread(String commentId, Map<String, dynamic> comment) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = comment['userId'] == currentUser?.uid;
    final sessionId = widget.session['id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String>(
                  future: _fetchUserName(comment['userId']),
                  builder: (context, snapshot) {
                    final userName = snapshot.data ?? 'Unknown';
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => _showCommenterProfile(comment['userId']),
                          child: Row(
                            children: [
                              if (comment['userImage'] != null && comment['userImage'].toString().isNotEmpty)
                                CircleAvatar(
                                  radius: 12,
                                  backgroundImage: CachedNetworkImageProvider(comment['userImage']),
                                )
                              else
                                const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Color(0xFF9D4EDD),
                                  child: Icon(Icons.person, color: Colors.white, size: 14),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                userName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (isOwner)
                          GestureDetector(
                            onTap: () async {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('events')
                                    .doc(sessionId)
                                    .collection('comments')
                                    .doc(commentId)
                                    .delete();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error deleting comment: $e')),
                                  );
                                }
                              }
                            },
                            child: const Icon(Icons.close, color: Colors.red, size: 16),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  _getCommentText(comment),
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                ),
                if (comment['attachmentUrl'] != null &&
                    comment['attachmentUrl'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildCommentAttachmentPreview(
                    context,
                    comment['attachmentUrl'],
                    comment['attachmentType'],
                    comment['attachmentName'],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatTime(comment['timestamp']),
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () async {
                        final userName = await _fetchUserName(comment['userId']);
                        if (mounted) {
                          setState(() {
                            _replyingToCommentId = commentId;
                            _replyingToAuthor = userName;
                          });
                          _commentController.clear();
                        }
                      },
                      child: const Text(
                        'Reply',
                        style: TextStyle(color: Color(0xFF9D4EDD), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (widget.creatorId == currentUser?.uid) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _selectComment(commentId, comment),
                        child: const Text(
                          'Select',
                          style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Replies Section
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .doc(sessionId)
                .collection('comments')
                .doc(commentId)
                .collection('replies')
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.01),
                  border: Border(left: BorderSide(color: const Color(0xFF9D4EDD).withOpacity(0.3), width: 2)),
                ),
                margin: const EdgeInsets.all(12),
                child: Column(
                  children: snapshot.data!.docs.map((reply) {
                    return _buildReplyItem(reply.id, reply.data() as Map<String, dynamic>, commentId);
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(String replyId, Map<String, dynamic> reply, String commentId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = reply['userId'] == currentUser?.uid;
    final sessionId = widget.session['id'] ?? '';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String>(
            future: _fetchUserName(reply['userId']),
            builder: (context, snapshot) {
              final userName = snapshot.data ?? 'Unknown';
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _showCommenterProfile(reply['userId']),
                    child: Row(
                      children: [
                        if (reply['userImage'] != null && reply['userImage'].toString().isNotEmpty)
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: CachedNetworkImageProvider(reply['userImage']),
                          )
                        else
                          const CircleAvatar(
                            radius: 10,
                            backgroundColor: Color(0xFF9D4EDD),
                            child: Icon(Icons.person, color: Colors.white, size: 12),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          userName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (isOwner)
                    GestureDetector(
                      onTap: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('events')
                              .doc(sessionId)
                              .collection('comments')
                              .doc(commentId)
                              .collection('replies')
                              .doc(replyId)
                              .delete();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error deleting reply: $e')),
                            );
                          }
                        }
                      },
                      child: const Icon(Icons.close, color: Colors.red, size: 14),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            _getCommentText(reply),
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
          ),
          if (reply['attachmentUrl'] != null && reply['attachmentUrl'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildCommentAttachmentPreview(
              context,
              reply['attachmentUrl'],
              reply['attachmentType'],
              reply['attachmentName'],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _formatTime(reply['timestamp']),
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}

Future<Map<String, dynamic>> _buildCommentPayload(String text) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    throw Exception('User not authenticated');
  }

  final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
  final userName = userDoc.data()?['name'] ?? userDoc.data()?['username'] ?? currentUser.email ?? 'User';
  final userImage = userDoc.data()?['image'] ?? '';

  return {
    'userId': currentUser.uid,
    'userName': userName,
    'userImage': userImage,
    'text': text,
    'comment': text,
    'timestamp': Timestamp.now(),
    'likedBy': [],
  };
}

_buildCreatedAuditionsTab() {
}

extension on Object? {
  void operator [](String other) {}
}
