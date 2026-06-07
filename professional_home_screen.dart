import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'professional_chat_screen.dart';
import 'audition_form_screen.dart';
import 'all_auditions_screen.dart';

import 'profile_screen.dart';
import 'services/firestore_service.dart';
import 'services/cloudinary_uploader.dart';

const String termsText = '''
Last Updated: [Insert Date]

Welcome to Filmsphere. These Terms and Conditions ("Terms") govern your use of the Filmsphere mobile application and services.

By accessing or using Filmsphere, you agree to be bound by these Terms. If you do not agree, please do not use the app.

1. About Filmsphere

Filmsphere is a platform designed for professionals in the film industry, including actors, directors, producers, casting agents, and other creatives to:

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

Filmsphere is a networking platform only. We are not responsible for:

Any disputes between users
Job outcomes or casting decisions
Loss or damage resulting from use of the platform

Use the app at your own risk.

11. Termination

We reserve the right to suspend or terminate your account if:

You violate these Terms
You engage in harmful or illegal activity
12. Changes to Terms

Filmiphere may update these Terms at any time. Continued use of the app means you accept the updated Terms.

13. Governing Law

These Terms shall be governed by the laws of [Your Country/State].

14. Contact Us

If you have any questions about these Terms, please contact us at:

Email: [your-email@example.com]

By using Filmisphere, you agree to these Terms and Conditions.
''';

class ProfessionalHomeScreen extends StatefulWidget {
  final String role;
  final Map<String, dynamic> userData;
  final String uid; // Firebase Auth UID for the logged in professional

  const ProfessionalHomeScreen({
    super.key,
    required this.role,
    required this.userData,
    required this.uid,
  });

  @override
  State<ProfessionalHomeScreen> createState() => _ProfessionalHomeScreenState();
}

class _ProfessionalHomeScreenState extends State<ProfessionalHomeScreen> {
  int _currentIndex = 0;
  final List<PlatformFile> _portfolioImages = [];
  final List<PlatformFile> _portfolioVideos = [];
  final List<PlatformFile> _moreDetailsFiles = [];
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _previousWorksController =
      TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _awardsController = TextEditingController();
  final TextEditingController _physicalAttributesController =
      TextEditingController();
  final TextEditingController _socialLinksController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _languagesController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _projectsController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _reportController = TextEditingController();
  String _availability = 'Available';
  bool _profileComplete = false;
  bool _isLoading = true;
  bool _isEditing = true; // Start in edit mode by default
  bool _isDetailsExpanded = false; // For expanding details section

  // Auditions data, same as UserHomeScreen
  List<Map<String, dynamic>> _auditionEvents = [];
  int _currentAuditionIndex = 0;
  bool _isLoadingAuditions = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _fetchAuditions();
  }

  Future<void> _initializeData() async {
    try {
      // Fetch latest profile data from Firebase
      final firebaseData = await FirestoreService.fetchProfessionalById(
        widget.uid,
      );

      if (firebaseData != null) {
        setState(() {});
        _loadProfileDataFromFirebase(firebaseData);
      } else {
        // Fallback to passed userData if no Firebase data exists
        _loadProfileDataFromWidget();
      }
    } catch (e) {
      print('Error fetching profile from Firebase: $e');
      // Fallback to widget userData on error
      _loadProfileDataFromWidget();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAuditions() async {
    print('Starting to fetch auditions...');
    try {
      final auditions = await FirestoreService.fetchAllAuditions();
      print('Fetched ${auditions.length} auditions');
      print('Auditions data: $auditions');
      if (mounted) {
        setState(() {
          _auditionEvents = auditions;
          _isLoadingAuditions = false;
          if (_currentAuditionIndex >= _auditionEvents.length) {
            _currentAuditionIndex = 0;
          }
        });
        print(
          'State updated: _isLoadingAuditions = $_isLoadingAuditions, _auditionEvents.length = ${_auditionEvents.length}',
        );
      }
    } catch (e) {
      print('Error fetching auditions: $e');
      // For debugging, add some test data if fetch fails
      if (mounted) {
        setState(() {
          _auditionEvents = [
            {
              'id': 'test1',
              'title': 'Test Audition 1',
              'description':
                  'This is a test audition to verify the UI is working',
              'role': 'Actor',
              'production': 'Test Production',
              'image':
                  'https://images.unsplash.com/photo-1489599809505-7ed0ab7a6b58?w=400',
            },
            {
              'id': 'test2',
              'title': 'Test Audition 2',
              'description': 'Another test audition for UI testing',
              'role': 'Director',
              'production': 'Another Production',
              'image':
                  'https://images.unsplash.com/photo-1489599809505-7ed0ab7a6b58?w=400',
            },
          ];
          _isLoadingAuditions = false;
          _currentAuditionIndex = 0;
        });
      }
    }
  }

  void _goToPreviousAudition() {
    if (_auditionEvents.isEmpty) return;
    setState(() {
      _currentAuditionIndex =
          (_currentAuditionIndex - 1 + _auditionEvents.length) %
          _auditionEvents.length;
    });
  }

  void _goToNextAudition() {
    if (_auditionEvents.isEmpty) return;
    setState(() {
      _currentAuditionIndex =
          (_currentAuditionIndex + 1) % _auditionEvents.length;
    });
  }

  ImageProvider _getAuditionImageProvider(Map<String, dynamic> event) {
    final image = (event['image'] ?? event['coverImage'] ?? '').toString();
    if (image.isEmpty) {
      return const NetworkImage(
        'https://images.unsplash.com/photo-1489599809505-7ed0ab7a6b58?w=400',
      );
    }
    if (image.startsWith('http')) {
      return NetworkImage(image);
    }
    return FileImage(File(image));
  }

  void _loadProfileDataFromWidget() {
    _bioController.text = widget.userData['bio'] ?? '';
    _experienceController.text = widget.userData['experience'] ?? '';
    _skillsController.text = widget.userData['skills']?.join(', ') ?? '';
    _specializationController.text = widget.userData['specialization'] ?? '';
    _previousWorksController.text = widget.userData['previousWorks'] ?? '';
    _fullNameController.text = widget.userData['fullName'] ?? '';
    _locationController.text = widget.userData['location'] ?? '';
    _awardsController.text = widget.userData['awards'] ?? '';
    _physicalAttributesController.text =
        widget.userData['physicalAttributes'] ?? '';
    _socialLinksController.text = widget.userData['socialLinks'] ?? '';
    _educationController.text = widget.userData['education'] ?? '';
    _languagesController.text = widget.userData['languages'] ?? '';
    _phoneController.text = widget.userData['phone'] ?? '';
    _emailController.text = widget.userData['email'] ?? '';
    _ageController.text = widget.userData['age'] ?? '';
    _heightController.text = widget.userData['height'] ?? '';
    _weightController.text = widget.userData['weight'] ?? '';
    _projectsController.text = widget.userData['projects'] ?? '0+';
    _imageUrlController.text = widget.userData['image'] ?? '';
    _availability = widget.userData['availability'] ?? 'Available';
  }

  void _loadProfileDataFromFirebase(Map<String, dynamic> data) {
    _bioController.text = data['bio'] ?? '';
    _experienceController.text = data['experience'] ?? '';
    _skillsController.text = (data['skills'] is List)
        ? (data['skills'] as List).join(', ')
        : data['skills'] ?? '';
    _specializationController.text = data['specialization'] ?? '';
    _previousWorksController.text = data['previousWorks'] ?? '';
    _fullNameController.text = data['fullName'] ?? '';
    _locationController.text = data['location'] ?? '';
    _awardsController.text = data['awards'] ?? '';
    _physicalAttributesController.text = data['physicalAttributes'] ?? '';
    _socialLinksController.text = data['socialLinks'] ?? '';
    _educationController.text = data['education'] ?? '';
    _languagesController.text = (data['languages'] is List)
        ? (data['languages'] as List).join(', ')
        : data['languages'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _emailController.text = data['email'] ?? '';
    _ageController.text = data['age'] ?? '';
    _heightController.text = data['height'] ?? '';
    _weightController.text = data['weight'] ?? '';
    _projectsController.text = data['projects'] ?? '0+';
    _imageUrlController.text = data['image'] ?? '';
    _availability = data['availability'] ?? 'Available';

    // Check if profile is complete
    if (_isProfileComplete(data)) {
      setState(() {
        _profileComplete = true;
      });
    }
  }

  bool _isProfileComplete(Map<String, dynamic> data) {
    return (data['bio'] as String?)?.isNotEmpty == true &&
        (data['experience'] as String?)?.isNotEmpty == true &&
        (data['fullName'] as String?)?.isNotEmpty == true;
  }

  bool _isActorRole() {
    final roleStr = widget.role.toLowerCase();
    return roleStr == 'actor' ||
        roleStr == 'actors' ||
        roleStr == 'actor(s)' ||
        roleStr.contains('actor');
  }

  @override
  void dispose() {
    _bioController.dispose();
    _experienceController.dispose();
    _skillsController.dispose();
    _specializationController.dispose();
    _previousWorksController.dispose();
    _fullNameController.dispose();
    _locationController.dispose();
    _awardsController.dispose();
    _physicalAttributesController.dispose();
    _socialLinksController.dispose();
    _educationController.dispose();
    _languagesController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _projectsController.dispose();
    _imageUrlController.dispose();
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _uploadPortfolioImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _portfolioImages.addAll(result.files);
        });
      }
    } catch (e) {
      _showError('Error uploading images: $e');
    }
  }

  Future<void> _uploadPortfolioVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _portfolioVideos.addAll(result.files);
        });
      }
    } catch (e) {
      _showError('Error uploading videos: $e');
    }
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
          _moreDetailsFiles.addAll(result.files);
        });
      }
    } catch (e) {
      _showError('Error uploading files: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _uploadPortfolioImages() async {
    final uploadedImages = <Map<String, dynamic>>[];
    for (final file in _portfolioImages) {
      if (file.path == null || !File(file.path!).existsSync()) {
        print('File ${file.name} no longer exists, skipping upload');
        continue;
      }
      try {
        final result = await CloudinaryUploader().uploadImage(
          File(file.path!),
          (progress) {},
        );
        uploadedImages.add({
          'name': file.name,
          'size': file.size,
          'type': 'image',
          'url': result.url,
        });
      } catch (e) {
        print('Error uploading image ${file.name}: $e');
        // Keep the local path as fallback
        uploadedImages.add({
          'name': file.name,
          'size': file.size,
          'type': 'image',
          'url': file.path ?? '',
        });
      }
    }
    return uploadedImages;
  }

  Future<List<Map<String, dynamic>>> _uploadPortfolioVideos() async {
    final uploadedVideos = <Map<String, dynamic>>[];
    for (final file in _portfolioVideos) {
      if (file.path == null || !File(file.path!).existsSync()) {
        print('File ${file.name} no longer exists, skipping upload');
        continue;
      }
      try {
        final result = await CloudinaryUploader().uploadVideo(
          File(file.path!),
          (progress) {},
        );
        uploadedVideos.add({
          'name': file.name,
          'size': file.size,
          'type': 'video',
          'url': result.url,
        });
      } catch (e) {
        print('Error uploading video ${file.name}: $e');
        // Keep the local path as fallback
        uploadedVideos.add({
          'name': file.name,
          'size': file.size,
          'type': 'video',
          'url': file.path ?? '',
        });
      }
    }
    return uploadedVideos;
  }

  Future<List<Map<String, dynamic>>> _uploadMoreDetailsFiles() async {
    final uploadedFiles = <Map<String, dynamic>>[];
    for (final file in _moreDetailsFiles) {
      if (file.path == null || !File(file.path!).existsSync()) {
        print('File ${file.name} no longer exists, skipping upload');
        continue;
      }
      try {
        final isPdf = file.name.toLowerCase().endsWith('.pdf');
        final resourceType = isPdf ? 'raw' : 'image';
        final result = await CloudinaryUploader().uploadMedia(
          File(file.path!),
          resourceType,
          null,
        );
        uploadedFiles.add({
          'name': file.name,
          'size': file.size,
          'type': isPdf ? 'PDF' : 'IMAGE',
          'url': result.url,
        });
      } catch (e) {
        print('Error uploading ${file.name}: $e');
        // Keep the local path as fallback
        uploadedFiles.add({
          'name': file.name,
          'size': file.size,
          'type': file.extension?.toUpperCase() == 'PDF' ? 'PDF' : 'IMAGE',
          'url': file.path ?? '',
        });
      }
    }
    return uploadedFiles;
  }

  Future<void> _saveProfile() async {
    if (_bioController.text.isEmpty || _experienceController.text.isEmpty) {
      _showError('Please fill all required fields');
      return;
    }

    try {
      // Upload portfolio images and videos
      final portfolioImages = await _uploadPortfolioImages();
      final portfolioVideos = await _uploadPortfolioVideos();
      final moreDetails = await _uploadMoreDetailsFiles();

      final profileData = {
        'fullName': _fullNameController.text,
        'location': _locationController.text,
        'bio': _bioController.text,
        'experience': _experienceController.text,
        'skills': _skillsController.text
            .split(',')
            .map((skill) => skill.trim())
            .where((skill) => skill.isNotEmpty)
            .toList(),
        'specialization': _specializationController.text,
        'previousWorks': _previousWorksController.text,
        'awards': _awardsController.text,
        'physicalAttributes': _physicalAttributesController.text,
        'socialLinks': _socialLinksController.text,
        'education': _educationController.text,
        'languages': _languagesController.text
            .split(',')
            .map((lang) => lang.trim())
            .where((lang) => lang.isNotEmpty)
            .toList(),
        'availability': _availability,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'age': _ageController.text,
        'height': _heightController.text,
        'weight': _weightController.text,
        'projects': _projectsController.text,
        'image': _imageUrlController.text,
        'portfolioImages': portfolioImages,
        'portfolioVideos': portfolioVideos,
        'moreDetails': moreDetails,
      };

      await FirestoreService.saveProfessionalProfile(
        role: widget.role,
        profileData: profileData,
      );

      setState(() {
        _profileComplete = _isProfileComplete(profileData);
        _isEditing = false; // Disable editing after saving
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Profile saved successfully!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF7B2CBF),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _showError('Error saving profile: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildHomeScreen() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D4EDD)),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading profile...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildRoleBioDisplay(),
          const SizedBox(height: 24),
          _buildAuditionBanner(),
          const SizedBox(height: 24),
          _buildCompletionStatus(),
          const SizedBox(height: 24),
          _buildPortfolioSection(),
          const SizedBox(height: 24),
          _buildDetailsForm(),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildAuditionsScreen() {
    if (_isLoadingAuditions) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D4EDD)),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading auditions...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_auditionEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No auditions available',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new opportunities',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B2E),
        elevation: 0,
        title: const Text(
          'Featured Auditions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAuditions,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _auditionEvents.length,
        itemBuilder: (context, index) {
          final audition = _auditionEvents[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Audition image
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    image: DecorationImage(
                      image: _getAuditionImageProvider(audition),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Audition details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audition['title'] ?? 'Untitled Audition',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        audition['description'] ?? 'No description available',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),

                      // Role and production details
                      Row(
                        children: [
                          Icon(
                            Icons.movie,
                            size: 16,
                            color: const Color(0xFF9D4EDD),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Role: ${audition['role'] ?? 'Not specified'}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(
                            Icons.business,
                            size: 16,
                            color: const Color(0xFF9D4EDD),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Production: ${audition['production'] ?? 'Not specified'}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Apply button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AuditionFormScreen(auditionEvent: audition),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9D4EDD),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Apply Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
              const Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Welcome back',
                        style: TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Filmsphere',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Small round avatar with user name beneath it
              GestureDetector(
                onTap: () {
                  _onItemTapped(3); // Navigate to Profile tab
                },
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                        color: Colors.grey.shade800,
                      ),
                      child: ClipOval(
                        child: _imageUrlController.text.isNotEmpty
                            ? Image.network(
                                _imageUrlController.text,
                                fit: BoxFit.cover,
                                width: 80,
                                height: 80,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.network(
                                    widget.userData['image'] ??
                                        'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
                                    fit: BoxFit.cover,
                                  );
                                },
                              )
                            : (widget.userData['image'] != null
                                  ? Image.network(
                                      widget.userData['image'],
                                      fit: BoxFit.cover,
                                      width: 80,
                                      height: 80,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 40,
                                            );
                                          },
                                    )
                                  : const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 40,
                                    )),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.userData['name'] ?? 'Professional',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
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

  Widget _buildRoleBioDisplay() {
    final roleTitle = widget.role;
    final bio = _bioController.text;
    final experience = _experienceController.text;
    final specialization = _specializationController.text;
    final projects = _projectsController.text.isNotEmpty
        ? _projectsController.text
        : '0+';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9D4EDD).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role and Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9D4EDD), Color(0xFF7B2CBF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  roleTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (bio.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Profile Active',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Bio Section
          if (bio.isNotEmpty) ...[
            const Text(
              'About',
              style: TextStyle(
                color: Color(0xFFE0AAFF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bio,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
          ],

          // Experience and Specialization
          Row(
            children: [
              Expanded(
                child: _buildRoleBioDetail(
                  'Experience',
                  experience.isNotEmpty ? experience : 'Not specified',
                  Icons.work_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRoleBioDetail(
                  'Specialty',
                  specialization.isNotEmpty ? specialization : 'Not specified',
                  Icons.star_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Projects
          Row(
            children: [
              Expanded(
                child: _buildRoleBioDetail(
                  'Projects',
                  projects,
                  Icons.folder_open_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }





































































  Widget _buildAuditionBanner() {
    if (_isLoadingAuditions) {
      return Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '🎬 Featured Auditions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D4EDD)),
            ),
          ],
        ),
      );
    }

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
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
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
                          event['location']?.toString() ?? 'Unknown Location',
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

  Widget _buildRoleBioDetail(
    String label,
    String value,
    IconData icon, {
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor ?? const Color(0xFF9D4EDD), size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            _profileComplete ? Icons.verified : Icons.info,
            color: _profileComplete ? Colors.green : const Color(0xFFE0AAFF),
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profileComplete
                      ? 'Profile Complete!'
                      : 'Complete Your Profile',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profileComplete
                      ? 'Your profile is visible to casting directors'
                      : 'Add your portfolio and details to get discovered',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioSection() {
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
              Icon(Icons.photo_library, color: Color(0xFFE0AAFF), size: 20),
              SizedBox(width: 8),
              Text(
                'Portfolio Gallery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Images Section
          _buildUploadSection(
            'Portfolio Images',
            _portfolioImages,
            _uploadPortfolioImage,
            Icons.add_photo_alternate,
            readOnly: !_isEditing,
          ),
          const SizedBox(height: 20),

          // Videos Section
          _buildUploadSection(
            'Portfolio Videos',
            _portfolioVideos,
            _uploadPortfolioVideo,
            Icons.video_library,
            readOnly: !_isEditing,
          ),

          const SizedBox(height: 20),
          // More Details Section (PDF / Images)
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
                    '${_moreDetailsFiles.length} files',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_moreDetailsFiles.isNotEmpty) ...[
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _moreDetailsFiles.length,
                    itemBuilder: (context, index) {
                      final file = _moreDetailsFiles[index];
                      final isPdf = file.extension?.toLowerCase() == 'pdf';
                      return Container(
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
                            if (_isEditing)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _moreDetailsFiles.removeAt(index);
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
                                file.name,
                                style: TextStyle(
                                  color: _isEditing
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.7),
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_isEditing)
                GestureDetector(
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
        ],
      ),
    );
  }

  Widget _buildUploadSection(
    String title,
    List<PlatformFile> files,
    VoidCallback onUpload,
    IconData icon, {
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${files.length} files',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // File List
        if (files.isNotEmpty) ...[
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Stack(
                    children: [
                      // Asset preview for image/video files
                      Center(child: _buildFilePreview(files[index], icon)),
                      if (!readOnly)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                files.removeAt(index);
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
                          files[index].name,
                          style: TextStyle(
                            color: readOnly
                                ? Colors.white.withOpacity(0.7)
                                : Colors.white,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Upload Button
        if (!readOnly)
          GestureDetector(
            onTap: onUpload,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: const Color(0xFFE0AAFF), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Upload $title',
                    style: const TextStyle(
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
    );
  }

  Widget _buildFilePreview(PlatformFile file, IconData fallbackIcon) {
    final extension = file.extension?.toLowerCase() ?? '';
    final imageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'];
    final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'];

    if (file.path != null &&
        File(file.path!).existsSync() &&
        imageExtensions.contains(extension)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(file.path!),
          width: 100,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(fallbackIcon, color: const Color(0xFFE0AAFF), size: 32);
          },
        ),
      );
    }

    if (file.path != null && videoExtensions.contains(extension)) {
      return Container(
        width: 100,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Icon(Icons.videocam, color: Color(0xFFE0AAFF), size: 32),
        ),
      );
    }

    return Icon(fallbackIcon, color: const Color(0xFFE0AAFF), size: 32);
  }

  Widget _buildDetailsForm() {
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
              Icon(Icons.edit_document, color: Color(0xFFE0AAFF), size: 20),
              SizedBox(width: 8),
              Text(
                'Professional Details',
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
          _buildFormField(
            'Full name',
            _fullNameController,
            readOnly: !_isEditing,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            'Location',
            _locationController,
            hint: 'City, Country or Region',
            readOnly: !_isEditing,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            'Phone',
            _phoneController,
            hint: 'e.g., +91 98765 43210',
            readOnly: !_isEditing,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            'Email',
            _emailController,
            hint: 'your.email@example.com',
            readOnly: !_isEditing,
          ),

          // Expandable section
          if (_isDetailsExpanded) ...[
            const SizedBox(height: 16),
            // Age, Height, Weight fields - only for Actors
            if (_isActorRole()) ...[
              _buildFormField(
                'Age',
                _ageController,
                hint: 'e.g., 28',
                readOnly: !_isEditing,
              ),
              const SizedBox(height: 16),
              _buildFormField(
                'Height',
                _heightController,
                hint: 'e.g., 6\'0" or 180 cm',
                readOnly: !_isEditing,
              ),
              const SizedBox(height: 16),
              _buildFormField(
                'Weight',
                _weightController,
                hint: 'e.g., 75 kg or 165 lbs',
                readOnly: !_isEditing,
              ),
              const SizedBox(height: 16),
            ],
            _buildFormField(
              'Bio',
              _bioController,
              maxLines: 3,
              readOnly: !_isEditing,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Experience',
              _experienceController,
              hint: 'e.g., 5 years in film industry',
              readOnly: !_isEditing,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Skills',
              _skillsController,
              hint: 'Separate skills with commas',
              readOnly: !_isEditing,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Specialization',
              _specializationController,
              hint: 'Your specific expertise area',
              readOnly: !_isEditing,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Previous Works',
              _previousWorksController,
              maxLines: 3,
              hint: 'List previous works or notable credits',
              readOnly: !_isEditing,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Awards',
              _awardsController,
              maxLines: 2,
              hint: 'List awards or recognitions',
              readOnly: !_isEditing,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Projects',
              _projectsController,
              hint: 'e.g., 25+ (optional)',
              readOnly: !_isEditing,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Physical Attributes',
              _physicalAttributesController,
              maxLines: 2,
              hint: 'Eye color, complexion, etc.',
              readOnly: !_isEditing,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Social Media Links',
              _socialLinksController,
              maxLines: 2,
              hint: 'Instagram, Twitter, TikTok links',
              readOnly: !_isEditing,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Education',
              _educationController,
              maxLines: 2,
              hint: 'Your educational background',
              readOnly: !_isEditing,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Languages',
              _languagesController,
              hint: 'Languages you speak (separate with commas)',
              readOnly: !_isEditing,
            ),
            const SizedBox(height: 16),
            _buildAvailabilitySection(),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isDetailsExpanded = false;
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
                    _isDetailsExpanded = true;
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
        ],
      ),
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String hint = '',
    bool readOnly = false,
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
          readOnly: readOnly,
          style: TextStyle(
            color: readOnly ? Colors.white.withOpacity(0.7) : Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hint.isNotEmpty ? hint : 'Enter your $label',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: readOnly
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.08),
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

  Widget _buildAvailabilitySection() {
    final availabilityOptions = [
      'Available',
      'Not Available',
      'Available with Notice',
      'Currently Shooting',
      'Open for Auditions',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Availability',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isEditing
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.3)),
          ),
          child: Column(
            children: availabilityOptions.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Radio<String>(
                      value: option,
                      groupValue: _availability,
                      onChanged: _isEditing
                          ? (value) {
                              setState(() {
                                _availability = value ?? 'Available';
                              });
                            }
                          : null,
                      activeColor: const Color(0xFF9D4EDD),
                      fillColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return const Color(0xFF9D4EDD);
                        }
                        return _isEditing
                            ? Colors.white.withOpacity(0.5)
                            : Colors.white.withOpacity(0.3);
                      }),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      option,
                      style: TextStyle(
                        color: _isEditing
                            ? Colors.white
                            : Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              // Preview profile
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE0AAFF),
              side: const BorderSide(color: Color(0xFF7B2CBF)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.remove_red_eye, size: 16),
                SizedBox(width: 8),
                Text('Preview Profile'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _isEditing
              ? ElevatedButton(
                  onPressed: _saveProfile,
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
                      Icon(Icons.save, size: 16),
                      SizedBox(width: 8),
                      Text('Save Profile'),
                    ],
                  ),
                )
              : ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit Profile'),
                    ],
                  ),
                ),
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

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeScreen(),
          _buildAuditionsScreen(),
          const ProfessionalChatScreen(),
          ProfileScreen(userId: widget.uid),
        ],
      ),
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
                icon: Icon(Icons.movie_rounded),
                label: 'Auditions',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_rounded),
                label: 'Chat',
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
}
