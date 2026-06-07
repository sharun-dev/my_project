import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'services/cloudinary_uploader.dart';
import 'services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  /// If [userId] is provided the screen will load that user's profile.
  ///
  /// When viewing another user's profile both the "Edit Profile" and
  /// "Logout" buttons are hidden. Passing `null` (the default) shows the
  /// currently authenticated user's profile and allows editing.
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Map<String, dynamic> _userProfile = {
    'name': '',
    'email': '',
    'phone': '',
    'location': '',
    'age': '',
    'gender': '',
    'experience': '',
    'specialization': '',
    'bio': '',
    'role': '', // user professional role (e.g. Producer, Actor)
    'stats': {
      'auditions': '0',
      'success': '0',
      'rejected': '0',
      'rating': '0.0',
    },
    'skills': [],
    'languages': [],
    'education': '',
  };

  bool _isEditing = false;
  bool _isLoading = true;
  bool _notFound = false; // true when lookup returns no document

  /// if we're looking at somebody else's profile, we won't allow editing
  /// or logging out from here.
  bool get _isOwnProfile {
    final current = _auth.currentUser?.uid;
    return widget.userId == null || widget.userId == current;
  }

  File? _selectedImage;
  String _profileImageUrl = '';
  bool _isUploadingImage = false;
  double _uploadProgress = 0.0;
  final ImagePicker _imagePicker = ImagePicker();
  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;

  // User applications data
  List<Map<String, dynamic>> _userApplications = [];

  // Editable fields controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _skillController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();

  List<String> _editableSkills = [];
  List<String> _editableLanguages = [];

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    _fetchUserData();
    _fetchUserApplications();
  }

  Future<void> _fetchUserData() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // decide which userId to load (self or the one passed in)
        final uidToLoad = widget.userId ?? currentUser.uid;
        if (uidToLoad.toString().isEmpty) {
          // nothing sensible to load
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid profile ID'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.pop(context);
          }
          return;
        }
        print(
          'ProfileScreen: loading data for uid=$uidToLoad own=${_isOwnProfile.toString()}',
        );
        final userDoc = await _firestore
            .collection('users')
            .doc(uidToLoad)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;

          // hide edit/logout when viewing someone else's profile
          if (!_isOwnProfile) {
            _isEditing = false;
          }

          // Debug: Print fetched data
          print('Fetched user data: $data');
          print('Skills from Firestore: ${data['skills']}');
          print('Languages from Firestore: ${data['languages']}');

          setState(() {
            _userProfile['name'] = data['username'] ?? '';
            _userProfile['email'] = data['email'] ?? '';
            _userProfile['phone'] = data['phone'] ?? '';
            _userProfile['location'] = data['location'] ?? '';
            _userProfile['age'] = data['age'] ?? '';
            _userProfile['gender'] = data['gender'] ?? '';
            _userProfile['experience'] = data['experience'] ?? '';
            _userProfile['specialization'] = data['specialization'] ?? '';
            _userProfile['bio'] = data['bio'] ?? '';
            _userProfile['education'] = data['education'] ?? '';
            _userProfile['role'] = data['role'] ?? '';
            _profileImageUrl = (data['image'] as String?) ?? '';

            // Handle skills - ensure it's a list
            if (data['skills'] != null && data['skills'] is List) {
              _userProfile['skills'] = List<String>.from(data['skills']);
              _editableSkills = List<String>.from(_userProfile['skills']);
            } else {
              _userProfile['skills'] = [];
              _editableSkills = [];
            }

            // Handle languages - ensure it's a list
            if (data['languages'] != null && data['languages'] is List) {
              _userProfile['languages'] = List<String>.from(data['languages']);
              _editableLanguages = List<String>.from(_userProfile['languages']);
            } else {
              _userProfile['languages'] = [];
              _editableLanguages = [];
            }

            if (data['stats'] != null) {
              _userProfile['stats'] = Map<String, dynamic>.from(data['stats']);
            }

            print(
              'After processing - Skills: $_editableSkills, Languages: $_editableLanguages',
            );

            _initializeControllers();
            _isLoading = false;
          });
        } else {
          // no such user exists - mark notFound and show message
          print('ProfileScreen: no document for uid=$uidToLoad');
          if (mounted) {
            setState(() {
              _notFound = true;
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _isLoading = false;
        _editableSkills = [];
        _editableLanguages = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeControllers() {
    _nameController.text = _userProfile['name'];
    _emailController.text = _userProfile['email'];
    _phoneController.text = _userProfile['phone'];
    _locationController.text = _userProfile['location'];
    _ageController.text = _userProfile['age'];
    _genderController.text = _userProfile['gender'];
    _experienceController.text = _userProfile['experience'];
    _specializationController.text = _userProfile['specialization'];
    _bioController.text = _userProfile['bio'];
    _educationController.text = _userProfile['education'];
  }

  Future<void> _uploadProfilePhoto() async {
    if (!_isOwnProfile) return;

    final XFile? pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1500,
      maxHeight: 1500,
      imageQuality: 85,
    );

    if (pickedImage == null) return;

    final file = File(pickedImage.path);
    setState(() {
      _isUploadingImage = true;
      _uploadProgress = 0.0;
    });

    try {
      final uploadResult = await CloudinaryUploader().uploadImage(file, (
        progress,
      ) {
        setState(() {
          _uploadProgress = progress;
        });
      });

      final uploadedUrl = uploadResult.url;

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).set({
          'image': uploadedUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if ((_userProfile['role'] as String?)?.isNotEmpty == true) {
          await _firestore.collection('profession').doc(currentUser.uid).set({
            'image': uploadedUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      setState(() {
        _selectedImage = file;
        _profileImageUrl = uploadedUrl;
        _userProfile['image'] = uploadedUrl;
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image uploaded successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image upload failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _addSkill() {
    if (_skillController.text.trim().isNotEmpty) {
      setState(() {
        final skill = _skillController.text.trim();
        _editableSkills.add(skill);
        print('Added skill: $skill, Total skills: $_editableSkills');
        _skillController.clear();
      });
    }
  }

  void _removeSkill(int index) {
    setState(() {
      final removed = _editableSkills.removeAt(index);
      print('Removed skill: $removed, Remaining skills: $_editableSkills');
    });
  }

  void _addLanguage() {
    if (_languageController.text.trim().isNotEmpty) {
      setState(() {
        final language = _languageController.text.trim();
        _editableLanguages.add(language);
        print(
          'Added language: $language, Total languages: $_editableLanguages',
        );
        _languageController.clear();
      });
    }
  }

  void _removeLanguage(int index) {
    setState(() {
      final removed = _editableLanguages.removeAt(index);
      print(
        'Removed language: $removed, Remaining languages: $_editableLanguages',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1B),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF9D4EDD)),
        ),
      );
    }

    if (_notFound) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Profile', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Text(
            'Profile not found',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildPersonalInfo(),
            const SizedBox(height: 24),
            if (_isOwnProfile && _userProfile['role'] != 'Producer') ...[
              _buildApplicationsSection(),
              const SizedBox(height: 24),
            ],
            _buildSkillsSection(),
            const SizedBox(height: 24),
            _buildAdditionalInfo(),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _isOwnProfile ? _uploadProfilePhoto : null,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        color: Colors.grey[700],
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                            : _profileImageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_profileImageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImage == null && _profileImageUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              color: Colors.white.withOpacity(0.5),
                              size: 40,
                            )
                          : null,
                    ),
                    if (_isUploadingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: _uploadProgress,
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    if (_isOwnProfile)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0F1B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isEditing
                        ? TextField(
                            controller: _nameController,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Full Name',
                              hintStyle: TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                            ),
                          )
                        : Text(
                            _nameController.text.isEmpty
                                ? 'Add Name'
                                : _nameController.text,
                            style: TextStyle(
                              color: _nameController.text.isEmpty
                                  ? Colors.white54
                                  : Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                    const SizedBox(height: 12),
                    // Specialization Field
                    Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: const Text(
                            'Specialization',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _isEditing
                              ? TextField(
                                  controller: _specializationController,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Colors.white30,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  _specializationController.text.isEmpty
                                      ? 'Add Specialization'
                                      : _specializationController.text,
                                  style: TextStyle(
                                    color:
                                        _specializationController.text.isEmpty
                                        ? Colors.white54
                                        : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Experience Field
                    Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: const Text(
                            'Experience',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _isEditing
                              ? TextField(
                                  controller: _experienceController,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Colors.white30,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  _experienceController.text.isEmpty
                                      ? 'Add Experience'
                                      : _experienceController.text,
                                  style: TextStyle(
                                    color: _experienceController.text.isEmpty
                                        ? Colors.white54
                                        : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
          if (_isOwnProfile)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GestureDetector(
                onTap: _uploadProfilePhoto,
                child: Text(
                  _profileImageUrl.isEmpty && _selectedImage == null
                      ? 'Add profile photo'
                      : 'Change profile photo',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
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
              Icon(Icons.person, color: Color(0xFFE0AAFF), size: 20),
              SizedBox(width: 8),
              Text(
                'Personal Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Email', _emailController, Icons.email),
          _buildInfoRow('Phone', _phoneController, Icons.phone),
          _buildInfoRow('Location', _locationController, Icons.location_on),
          _buildInfoRow('Age', _ageController, Icons.cake),
          _buildInfoRow('Gender', _genderController, Icons.transgender),
          const SizedBox(height: 12),
          const Text(
            'About Me',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _isEditing
              ? TextField(
                  controller: _bioController,
                  maxLines: 3,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tell us about yourself...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF9D4EDD)),
                    ),
                  ),
                )
              : Text(
                  _bioController.text.isEmpty
                      ? 'Add your bio...'
                      : _bioController.text,
                  style: TextStyle(
                    color: _bioController.text.isEmpty
                        ? Colors.white.withOpacity(0.4)
                        : Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.6), size: 16),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: _isEditing
                ? TextField(
                    controller: controller,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    keyboardType: label == 'Phone' ? TextInputType.phone : TextInputType.text,
                    inputFormatters: label == 'Phone' ? [FilteringTextInputFormatter.digitsOnly] : null,
                    maxLength: label == 'Phone' ? 10 : null,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFF9D4EDD)),
                      ),
                    ),
                  )
                : Text(
                    controller.text.isEmpty ? '-' : controller.text,
                    style: TextStyle(
                      color: controller.text.isEmpty
                          ? Colors.white.withOpacity(0.4)
                          : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsSection() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.playlist_add_check,
                    color: Color(0xFFE0AAFF),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Applied Auditions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              // Refresh button
              GestureDetector(
                onTap: () {
                  _fetchUserApplications();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Refreshing applications...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Color(0xFFE0AAFF),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Total: ${_userApplications.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (_userApplications.isEmpty)
            Text(
              'You haven\'t applied to any auditions yet.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            )
          else
            Column(
              children: _userApplications.map((app) {
                final audition = app['audition'] as Map<String, dynamic>;
                final title = audition['title'] ?? 'Untitled';
                final status = app['status'] ?? 'Pending';

                // Determine status color and icon
                Color statusColor = Colors.orange;
                IconData statusIcon = Icons.schedule;

                if (status == 'Accepted') {
                  statusColor = Colors.green;
                  statusIcon = Icons.check_circle;
                } else if (status == 'Rejected') {
                  statusColor = Colors.red;
                  statusIcon = Icons.cancel;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: statusColor, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (audition['production'] != null)
                        Text(
                          'Production: ${audition['production']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      if (audition['role'] != null)
                        Text(
                          'Role: ${audition['role']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      if (audition['type'] != null)
                        Text(
                          'Type: ${audition['type']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
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
              Icon(Icons.psychology, color: Color(0xFFE0AAFF), size: 20),
              SizedBox(width: 8),
              Text(
                'Skills & Talents',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skillController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Add a skill...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF9D4EDD)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFFE0AAFF)),
                  onPressed: _addSkill,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_editableSkills.isEmpty)
            Text(
              'No skills added yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _editableSkills.asMap().entries.map<Widget>((entry) {
                final index = entry.key;
                final skill = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D4EDD).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF9D4EDD).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        skill,
                        style: const TextStyle(
                          color: Color(0xFFE0AAFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_isEditing) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeSkill(index),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
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
              Icon(Icons.language, color: Color(0xFFE0AAFF), size: 20),
              SizedBox(width: 8),
              Text(
                'Languages & Education',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Languages:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (_isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _languageController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Add a language...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF9D4EDD)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFFE0AAFF)),
                  onPressed: _addLanguage,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (_editableLanguages.isEmpty)
            Text(
              'No languages added yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _editableLanguages.asMap().entries.map<Widget>((entry) {
                final index = entry.key;
                final language = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B2CBF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF7B2CBF).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        language,
                        style: const TextStyle(
                          color: Color(0xFFE0AAFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_isEditing) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeLanguage(index),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          const Text(
            'Education:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _isEditing
              ? TextField(
                  controller: _educationController,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your education...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF9D4EDD)),
                    ),
                  ),
                )
              : Text(
                  _educationController.text.isEmpty
                      ? 'Add your education...'
                      : _educationController.text,
                  style: TextStyle(
                    color: _educationController.text.isEmpty
                        ? Colors.white.withOpacity(0.4)
                        : Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // When viewing someone else's profile we hide both buttons
    if (!_isOwnProfile) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _toggleEditMode,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE0AAFF),
              side: const BorderSide(color: Color(0xFF7B2CBF)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isEditing ? Icons.close : Icons.edit, size: 16),
                const SizedBox(width: 8),
                Text(_isEditing ? 'Cancel Edit' : 'Edit Profile'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isEditing ? _saveProfile : _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isEditing
                  ? Colors.green
                  : const Color(0xFF9D4EDD),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isEditing ? Icons.save : Icons.logout, size: 16),
                const SizedBox(width: 8),
                Text(_isEditing ? 'Save Changes' : 'Logout'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _toggleEditMode() {
    if (!_isOwnProfile) return;
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Reset to original values when canceling edit
        _initializeControllers();
        // Reset lists to the current saved state
        _editableSkills = List<String>.from(_userProfile['skills'] ?? []);
        _editableLanguages = List<String>.from(_userProfile['languages'] ?? []);
        _selectedImage = null;

        print('Edit cancelled - Skills reset to: $_editableSkills');
        print('Edit cancelled - Languages reset to: $_editableLanguages');
      } else {
        print('Edit mode enabled - Current skills: $_editableSkills');
        print('Edit mode enabled - Current languages: $_editableLanguages');
      }
    });
  }

  void _saveProfile() async {
    // Validation
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (!RegExp(r'^[^@]+@gmail\.com$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Gmail address (e.g., example@gmail.com)'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (phone.length != 10 || int.tryParse(phone) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must be exactly 10 digits'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Prepare profile data
        final profileData = {
          'username': _nameController.text.trim(),
          'email': email,
          'phone': phone,
          'location': _locationController.text.trim(),
          'age': _ageController.text.trim(),
          'gender': _genderController.text.trim(),
          'experience': _experienceController.text.trim(),
          'specialization': _specializationController.text.trim(),
          'bio': _bioController.text.trim(),
          'education': _educationController.text.trim(),
          'image': _profileImageUrl,
          'skills': _editableSkills.toList(), // Ensure it's a proper list
          'languages': _editableLanguages.toList(), // Ensure it's a proper list
          'updatedAt': FieldValue.serverTimestamp(),
        };

        print('Saving profile with skills: $_editableSkills');
        print('Saving profile with languages: $_editableLanguages');
        print('Profile data to save: $profileData');

        // Update Firestore using set with merge to ensure all fields are properly stored
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .set(profileData, SetOptions(merge: true));

        if ((_userProfile['role'] as String?)?.isNotEmpty == true) {
          await _firestore
              .collection('profession')
              .doc(currentUser.uid)
              .set(profileData, SetOptions(merge: true));
        }

        print('Successfully saved to Firestore');

        // Update local profile data after successful save
        setState(() {
          _userProfile['name'] = _nameController.text;
          _userProfile['email'] = _emailController.text;
          _userProfile['phone'] = _phoneController.text;
          _userProfile['location'] = _locationController.text;
          _userProfile['age'] = _ageController.text;
          _userProfile['gender'] = _genderController.text;
          _userProfile['experience'] = _experienceController.text;
          _userProfile['specialization'] = _specializationController.text;
          _userProfile['bio'] = _bioController.text;
          _userProfile['education'] = _educationController.text;
          _userProfile['skills'] = List<String>.from(_editableSkills);
          _userProfile['languages'] = List<String>.from(_editableLanguages);

          _isEditing = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseException catch (e) {
      print('Firebase error saving profile: ${e.code} - ${e.message}');
      if (!mounted) return;
      String errorMessage = 'Error saving profile';
      if (e.code == 'permission-denied') {
        errorMessage = 'Permission denied. Please try again.';
      } else if (e.code == 'unavailable') {
        errorMessage = 'Service unavailable. Please check your connection.';
      } else {
        errorMessage = 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error saving profile: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Load all audition applications made by current user and preload audition details.
  ///
  /// When we're viewing another user's profile there's no need to query for
  /// applications since they belong to the signed‑in user only.
  Future<void> _fetchUserApplications() async {
    if (!_isOwnProfile) return;
    try {
      final apps = await FirestoreService.fetchApplicationsByUser();
      final enriched = <Map<String, dynamic>>[];
      for (var app in apps) {
        final audition = await FirestoreService.fetchAuditionById(
          app['auditionId'],
        );
        enriched.add({...app, 'audition': audition ?? {}});
      }
      if (mounted) {
        setState(() {
          _userApplications = enriched;
          // update stats audit count
          _userProfile['stats']['auditions'] = '${_userApplications.length}';
        });
      }
    } catch (e) {
      print('Error fetching user applications: $e');
    }
  }

  void _logout() {
    if (!_isOwnProfile) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _experienceController.dispose();
    _specializationController.dispose();
    _bioController.dispose();
    _educationController.dispose();
    _skillController.dispose();
    _languageController.dispose();
    super.dispose();
  }
}

/// Screen to show details for an audition the user has applied to
class AppliedAuditionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> application;

  const AppliedAuditionDetailScreen({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    final audition = application['audition'] as Map<String, dynamic>;
    final status = application['status'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          audition['title'] ?? 'Audition Details',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (audition['image'] != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(audition['image']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              audition['title'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: $status',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (audition['description'] != null)
              Text(
                audition['description'],
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            const SizedBox(height: 16),
            // display auditon-specific metadata
            if (audition['production'] != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.business_center,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Production: ${audition['production']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (audition['date'] != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Deadline: ${audition['date']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (audition['type'] != null) ...[
              Row(
                children: [
                  const Icon(Icons.category, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Type: ${audition['type']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (audition['role'] != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Role: ${audition['role']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (audition['roleDetails'] != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.list, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Role Details: ${audition['roleDetails']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (audition['shootDate'] != null) ...[
              Row(
                children: [
                  const Icon(Icons.date_range, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Shoot Date: ${audition['shootDate']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // preserve previous calendar/time info if still present
            if (audition['auditionDate'] != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Audition Date: ${audition['auditionDate']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ],
            if (audition['auditionTime'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Audition Time: ${audition['auditionTime']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Your Application',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildApplicationDetails(application),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationDetails(Map<String, dynamic> app) {
    // show some fields from application data
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (app['name'] != null)
          Text(
            'Name: ${app['name']}',
            style: const TextStyle(color: Colors.white70),
          ),
        if (app['address'] != null)
          Text(
            'Address: ${app['address']}',
            style: const TextStyle(color: Colors.white70),
          ),
        if (app['phone'] != null)
          Text(
            'Phone: ${app['phone']}',
            style: const TextStyle(color: Colors.white70),
          ),
        if (app['age'] != null)
          Text(
            'Age: ${app['age']}',
            style: const TextStyle(color: Colors.white70),
          ),
        if (app['gender'] != null)
          Text(
            'Gender: ${app['gender']}',
            style: const TextStyle(color: Colors.white70),
          ),
        if (app['role'] != null)
          Text(
            'Role applied for: ${app['role']}',
            style: const TextStyle(color: Colors.white70),
          ),
        // add more fields as needed
      ],
    );
  }
}
