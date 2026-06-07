import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'services/cloudinary_uploader.dart';
import 'services/firestore_service.dart';

class AuditionFormScreen extends StatefulWidget {
  final Map<String, dynamic> auditionEvent;

  const AuditionFormScreen({super.key, required this.auditionEvent});

  @override
  State<AuditionFormScreen> createState() => _AuditionFormScreenState();
}

class _AuditionFormScreenState extends State<AuditionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _aboutMeCtrl = TextEditingController();

  String? _selectedGender;
  String? _selectedRole;
  bool _loading = false;
  File? _selectedImage;
  double _imageUploadProgress = 0.0;
 
 
 
 
 
 
 
  File? _selectedVideo;
  double _videoUploadProgress = 0.0;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _roles = [
    'Lead Actor',
    'Supporting Actor',
    'Character Actor',
    'Child Artist',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _placeCtrl.dispose();
    _skillsCtrl.dispose();
    _aboutMeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final applicationData = {
        'name': _nameCtrl.text,
        'address': _addressCtrl.text,
        'phone': _phoneCtrl.text,
        'age': _ageCtrl.text,
        'height': _heightCtrl.text,
        'weight': _weightCtrl.text,
        'place': _placeCtrl.text,
        'skills': _skillsCtrl.text,
        'aboutMe': _aboutMeCtrl.text,
        'gender': _selectedGender,
        'role': _selectedRole,
      };

      if (_selectedImage != null) {
        final photoUrl = await _uploadImageToCloudinary(_selectedImage!);
        if (photoUrl != null) {
          applicationData['photoUrl'] = photoUrl;
        }
      }



























      if (_selectedVideo != null) {
        final videoUrl = await _uploadVideoToCloudinary(_selectedVideo!);
        if (videoUrl != null) {
          applicationData['videoUrl'] = videoUrl;
        }
      }






      await FirestoreService.saveAuditionApplication(
        widget.auditionEvent['id'],
        applicationData,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting application: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedImage = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedVideo = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking video: $e')));
    }
  }

  Future<String?> _uploadImageToCloudinary(File image) async {
    try {
      final result = await CloudinaryUploader().uploadImage(image, (progress) {
        setState(() {
          _imageUploadProgress = progress;
        });
      });
      return result.url;
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }










































  Future<String?> _uploadVideoToCloudinary(File video) async {
    try {
      final result = await CloudinaryUploader().uploadVideo(video, (progress) {
        setState(() {
          _videoUploadProgress = progress;
        });
      });
      return result.url;
    } catch (e) {
      throw Exception('Video upload failed: $e');
    }
  }
















  String? _phoneValidator(String? value) {
    if (value?.isEmpty ?? true) return 'Please enter Phone Number';
    final phoneRegex = RegExp(r'^\d{10,}$');
    if (!phoneRegex.hasMatch(value!)) {
      return 'Phone number must be numeric and at least 10 digits';
    }
    return null;
  }

  String? _ageValidator(String? value) {
    if (value?.isEmpty ?? true) return 'Please enter Age';
    final ageRegex = RegExp(r'^\d+$');
    if (!ageRegex.hasMatch(value!)) {
      return 'Age must be numeric';
    }
    return null;
  }

  String? _heightValidator(String? value) {
    if (value?.isEmpty ?? true) return 'Please enter Height';
    final heightRegex = RegExp(r'^\d+(\.\d+)?\s*(cm|ft|m|meter|foot|feet)?$');
    if (!heightRegex.hasMatch(value!.toLowerCase())) {
      return 'Height must be digits with units (e.g., 170cm, 5.6ft, 1.7m)';
    }
    return null;
  }

  String? _weightValidator(String? value) {
    if (value?.isEmpty ?? true) return 'Please enter Weight';
    final weightRegex = RegExp(r'^\d+(\.\d+)?\s*(kg|kilogram)?$');
    if (!weightRegex.hasMatch(value!.toLowerCase())) {
      return 'Weight must be digits with kg (e.g., 65kg)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.auditionEvent['title'],
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAuditionInfoCard(),
              const SizedBox(height: 24),
              const Text(
                'Personal Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _nameCtrl,
                'Full Name',
                Icons.person,
                TextInputType.name,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _addressCtrl,
                'Address',
                Icons.location_on,
                TextInputType.streetAddress,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _phoneCtrl,
                'Phone Number',
                Icons.phone,
                TextInputType.phone,
                validator: _phoneValidator,
              ),
              const SizedBox(height: 16),
              _buildGenderDropdown(),
              const SizedBox(height: 16),
              _buildPhysicalDetailsRow(),
              const SizedBox(height: 16),
              _buildTextField(
                _placeCtrl,
                'Current Place',
                Icons.place,
                TextInputType.text,
              ),
              const SizedBox(height: 16),
              _buildRoleDropdown(),
              const SizedBox(height: 16),
              _buildImagePicker(),
              const SizedBox(height: 16),
              _buildVideoPicker(),
              const SizedBox(height: 24),
              const Text(
                'Professional Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _buildSkillsField(),
              const SizedBox(height: 16),
              _buildAboutMeField(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuditionInfoCard() {
    final coverImage = widget.auditionEvent['coverImage'] ?? widget.auditionEvent['image'];
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9D4EDD).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Image
          if (coverImage != null && coverImage.toString().isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Image.network(
                coverImage.toString(),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.white.withOpacity(0.05),
                    child: const Center(
                      child: Icon(Icons.image_not_supported, color: Colors.white54),
                    ),
                  );
                },
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Type
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.auditionEvent['title'] ?? 'Audition',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (widget.auditionEvent['role'] != null)
                            Text(
                              widget.auditionEvent['role'],
                              style: const TextStyle(
                                color: Color(0xFFE0AAFF),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.auditionEvent['type'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9D4EDD).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.5)),
                        ),
                        child: Text(
                          widget.auditionEvent['type'],
                          style: const TextStyle(
                            color: Color(0xFFE0AAFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Quick Info Row
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickInfoItem(
                        Icons.business,
                        'Production',
                        widget.auditionEvent['production'] ?? 'N/A',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickInfoItem(
                        Icons.location_on,
                        'Location',
                        widget.auditionEvent['location'] ?? 'N/A',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickInfoItem(
                        Icons.calendar_today,
                        'Shoot Date',
                        widget.auditionEvent['shootDate'] ?? 'N/A',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickInfoItem(
                        Icons.currency_rupee,
                        'Budget',
                        widget.auditionEvent['budget'] ?? 'TBD',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Divider
                Container(height: 1, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 16),
                
                // Detailed Information
                const Text(
                  'Audition Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                
                _buildInfoRow('Age Range', widget.auditionEvent['ageRange']),
                _buildInfoRow('Gender Required', widget.auditionEvent['gender']),
                _buildInfoRow('Character Type', widget.auditionEvent['lookSkills']),
                _buildInfoRow('Address', widget.auditionEvent['address']),
                _buildInfoRow('Shoot Location', widget.auditionEvent['shootLocation']),
                _buildInfoRow('Apply By Date', widget.auditionEvent['applyLastDate']),
                
                // Role Details
                if (widget.auditionEvent['roleDetails'] != null &&
                    (widget.auditionEvent['roleDetails'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Role Description',
                          style: TextStyle(
                            color: Color(0xFFE0AAFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.auditionEvent['roleDetails'] ?? '',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Cover Image Description
                if (widget.auditionEvent['coverImageDescription'] != null &&
                    (widget.auditionEvent['coverImageDescription'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Project Description',
                          style: TextStyle(
                            color: Color(0xFFE0AAFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.auditionEvent['coverImageDescription'] ?? '',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
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

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFFE0AAFF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFFE0AAFF)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    TextInputType type, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        prefixIcon: Icon(icon, color: const Color(0xFFE0AAFF)),
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
          borderSide: const BorderSide(color: Color(0xFF9D4EDD), width: 2),
        ),
      ),
      validator: validator ?? (value) => value?.isEmpty ?? true ? 'Please enter $hint' : null,
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGender,
      decoration: _inputDecoration('Gender', Icons.transgender),
      items: _genders.map((String gender) {
        return DropdownMenuItem<String>(
          value: gender,
          child: Text(gender, style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: (String? value) {
        setState(() {
          _selectedGender = value;
        });
      },
      validator: (value) => value == null ? 'Please select gender' : null,
      dropdownColor: const Color(0xFF1E1B2E),
    );
  }

  Widget _buildPhysicalDetailsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            _ageCtrl,
            'Age',
            Icons.cake,
            TextInputType.number,
            validator: _ageValidator,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTextField(
            _heightCtrl,
            'Height (cm)',
            Icons.height,
            TextInputType.number,
            validator: _heightValidator,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTextField(
            _weightCtrl,
            'Weight (kg)',
            Icons.monitor_weight,
            TextInputType.number,
            validator: _weightValidator,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      decoration: _inputDecoration('Select Role', Icons.work),
      items: _roles.map((String role) {
        return DropdownMenuItem<String>(
          value: role,
          child: Text(role, style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: (String? value) {
        setState(() {
          _selectedRole = value;
        });
      },
      validator: (value) => value == null ? 'Please select a role' : null,
      dropdownColor: const Color(0xFF1E1B2E),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Your Photograph',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Pick Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D4EDD),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            if (_selectedImage != null)
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
        if (_selectedImage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              value: _imageUploadProgress,
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF9D4EDD),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Your Reel / Video',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library),
              label: const Text('Pick Video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A60C8),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            if (_selectedVideo != null)
              Flexible(
                child: Text(
                  _selectedVideo!.path.split('/').last,
                  style: const TextStyle(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        if (_selectedVideo != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              value: _videoUploadProgress,
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF6A60C8),
              ),
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      prefixIcon: Icon(icon, color: const Color(0xFFE0AAFF)),
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
        borderSide: const BorderSide(color: Color(0xFF9D4EDD), width: 2),
      ),
    );
  }

  Widget _buildSkillsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Skills and Experience',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _skillsCtrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Describe your skills and experience.',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
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
              borderSide: const BorderSide(color: Color(0xFF9D4EDD), width: 2),
            ),
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? 'Please describe your skills' : null,
        ),
      ],
    );
  }

  Widget _buildAboutMeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About Me',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _aboutMeCtrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tell us about yourself...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
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
              borderSide: const BorderSide(color: Color(0xFF9D4EDD), width: 2),
            ),
          ),
          validator: (value) => value?.isEmpty ?? true
              ? 'Please provide information about yourself'
              : null,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9D4EDD).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _submitApplication,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9D4EDD),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'SUBMIT APPLICATION',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
