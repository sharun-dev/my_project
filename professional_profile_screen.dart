import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/cloudinary_uploader.dart';

class ProfessionalProfileScreen extends StatefulWidget {
  // Optional: pass a specific document id from the `profession` collection.
  final String? professionalId;
  const ProfessionalProfileScreen({super.key, this.professionalId});

  @override
  State<ProfessionalProfileScreen> createState() =>
      _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen> {
  Map<String, dynamic>? _professionalProfile;
  bool _isLoading = true;
  String? _error;
  bool _isEditing = false;
  String? _docId;

  File? _selectedImage;
  String _profileImageUrl = '';
  bool _isUploadingImage = false;
  double _uploadProgress = 0.0;

  // Editable fields controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();

  // Helper to avoid repeating null checks after data is loaded
  Map<String, dynamic> get p => _professionalProfile!;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final col = FirebaseFirestore.instance.collection('profession');
      final effectiveId = (widget.professionalId?.isNotEmpty == true)
          ? widget.professionalId
          : FirebaseAuth.instance.currentUser?.uid;

      if (effectiveId != null && effectiveId.isNotEmpty) {
        final doc = await col.doc(effectiveId).get();
        if (doc.exists) {
          _professionalProfile = doc.data();
          _docId = doc.id;
          _profileImageUrl = (_professionalProfile?['image'] as String?) ?? '';
          _initializeControllers();
        } else {
          _error = 'Profile not found for id: $effectiveId';
        }
      } else {
        // fallback: fetch first document in collection
        final snapshot = await col.limit(1).get();
        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          _professionalProfile = doc.data() as Map<String, dynamic>?;
          _docId = doc.id;
          _profileImageUrl = (_professionalProfile?['image'] as String?) ?? '';
          _initializeControllers();
        } else {
          _error = 'No profiles available';
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1B),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1B2E),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D4EDD),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B2E),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Professional Profile',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              _buildProfessionalHeader(),
              const SizedBox(height: 24),
              _buildProfessionalInfo(),
              const SizedBox(height: 24),
              _buildActionButtons(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalHeader() {
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
          // Profile Picture and Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _uploadProfilePhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                            : (_profileImageUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(_profileImageUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null),
                        color: Colors.grey[700],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child:
                          (_selectedImage == null && _profileImageUrl.isEmpty)
                          ? Icon(
                              Icons.person,
                              size: 44,
                              color: Colors.white.withOpacity(0.7),
                            )
                          : null,
                    ),
                    if (_isUploadingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: _uploadProgress,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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
                              color: Color.fromARGB(255, 15, 14, 14),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Full Name',
                              hintStyle: TextStyle(
                                color: const Color.fromARGB(179, 20, 19, 19),
                              ),
                              border: InputBorder.none,
                            ),
                          )
                        : Text(
                            p['name'] ?? '',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 4, 4, 4),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                    const SizedBox(height: 6),
                    _isEditing
                        ? TextField(
                            controller: _roleController,
                            style: const TextStyle(
                              color: Color.fromARGB(179, 16, 15, 15),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Professional Role',
                              hintStyle: TextStyle(
                                color: const Color.fromARGB(137, 10, 9, 9),
                              ),
                              border: InputBorder.none,
                            ),
                          )
                        : Text(
                            p['role'] ?? '',
                            style: const TextStyle(
                              color: Color.fromARGB(179, 234, 230, 230),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    const SizedBox(height: 4),
                    // Removed ID display
                    const SizedBox(height: 8),
                    // Company
                    Row(
                      children: [
                        Icon(
                          Icons.business,
                          color: const Color.fromARGB(153, 231, 229, 229),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _isEditing
                              ? TextField(
                                  controller: _companyController,
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 24, 22, 22),
                                    fontSize: 14,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Company',
                                    hintStyle: TextStyle(
                                      color: Color.fromARGB(137, 9, 9, 9),
                                    ),
                                    border: InputBorder.none,
                                  ),
                                )
                              : Text(
                                  p['company'] ?? '',
                                  style: const TextStyle(
                                    color: Color.fromARGB(179, 11, 11, 11),
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.white60,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _isEditing
                              ? TextField(
                                  controller: _locationController,
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 12, 12, 12),
                                    fontSize: 14,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Location',
                                    hintStyle: TextStyle(
                                      color: Color.fromARGB(137, 17, 15, 15),
                                    ),
                                    border: InputBorder.none,
                                  ),
                                )
                              : Text(
                                  p['location'] ?? '',
                                  style: const TextStyle(
                                    color: Color.fromARGB(179, 18, 18, 18),
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _uploadProfilePhoto,
            child: Text(
              'Upload profile image',
              style: TextStyle(
                color: _profileImageUrl.isNotEmpty || _selectedImage != null
                    ? const Color(0xFF9D4EDD)
                    : const Color(0xFFE0AAFF),
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.info, color: Color(0xFFE0AAFF), size: 20),
              SizedBox(width: 8),
              Text(
                'Professional Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Specialization
          _buildInfoRow(
            'Specialization',
            _specializationController,
            Icons.psychology,
          ),
          const SizedBox(height: 12),

          // Email
          _buildInfoRow('Email', _emailController, Icons.email),
          const SizedBox(height: 12),

          // Phone
          _buildInfoRow('Phone', _phoneController, Icons.phone),
          const SizedBox(height: 12),

          // Education
          _buildInfoRow('Education', _educationController, Icons.school),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white60, size: 16),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: _isEditing
              ? TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 8, 8, 8),
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
                        color: Colors.white54.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF9D4EDD)),
                    ),
                  ),
                )
              : Text(
                  controller.text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _toggleEditMode,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE0AAFF),
                  side: const BorderSide(color: Color(0xFF7B2CBF)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isEditing ? Icons.close : Icons.edit, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _isEditing ? 'Cancel' : 'Edit Profile',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _isEditing
                  ? ElevatedButton.icon(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9D4EDD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save', style: TextStyle(fontSize: 14)),
                    )
                  : ElevatedButton.icon(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE74C3C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout', style: TextStyle(fontSize: 14)),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  void _initializeControllers() {
    _nameController.text = _professionalProfile?['name'] ?? '';
    _roleController.text = _professionalProfile?['role'] ?? '';
    _companyController.text = _professionalProfile?['company'] ?? '';
    _locationController.text = _professionalProfile?['location'] ?? '';
    _specializationController.text =
        _professionalProfile?['specialization'] ?? '';
    _emailController.text = _professionalProfile?['email'] ?? '';
    _phoneController.text = _professionalProfile?['phone'] ?? '';
    _educationController.text = _professionalProfile?['education'] ?? '';
  }

  Future<void> _uploadProfilePhoto() async {
    if (_docId == null) return;

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1500,
      maxHeight: 1500,
      imageQuality: 85,
    );

    if (file == null) return;

    setState(() {
      _isUploadingImage = true;
      _uploadProgress = 0.0;
    });

    try {
      final uploadResult = await CloudinaryUploader().uploadImage(
        File(file.path),
        (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      final uploadedUrl = uploadResult.url;

      await FirebaseFirestore.instance.collection('profession').doc(_docId).set(
        {'image': uploadedUrl, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      setState(() {
        _selectedImage = File(file.path);
        _profileImageUrl = uploadedUrl;
        if (_professionalProfile != null) {
          _professionalProfile!['image'] = uploadedUrl;
        }
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

  void _toggleEditMode() {
    setState(() {
      if (_isEditing) {
        // Cancel edit - reset to original values
        _initializeControllers();
      }
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveProfile() async {
    if (_docId == null) return;

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
      final data = {
        'name': _nameController.text,
        'role': _roleController.text,
        'company': _companyController.text,
        'location': _locationController.text,
        'specialization': _specializationController.text,
        'email': email,
        'phone': phone,
        'education': _educationController.text,
        'image': _profileImageUrl,
      };

      await FirebaseFirestore.instance
          .collection('profession')
          .doc(_docId)
          .update(data);

      _professionalProfile?.addAll(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        setState(() {
          _isEditing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFE0AAFF)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Add your logout logic here
              // Example: await FirebaseAuth.instance.signOut();
              // Then navigate to login page
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged out successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
                // Navigate to login page - adjust route as needed
                Navigator.of(context).pop();
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFE74C3C)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _specializationController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _educationController.dispose();
    super.dispose();
  }
}
