import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'services/cloudinary_uploader.dart';

class LiveSessionCreateScreen extends StatefulWidget {
  const LiveSessionCreateScreen({super.key});

  @override
  State<LiveSessionCreateScreen> createState() =>
      _LiveSessionCreateScreenState();
}

class _LiveSessionCreateScreenState extends State<LiveSessionCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  String _privacy = 'Public';
  DateTime? _scheduledDateTime;
  File? _thumbnailFile;
  String? _thumbnailUrl;
  File? _videoFile;
  String? _videoUrl;
  bool _enableChat = true;
  bool _isMonetized = false;
  bool _isLoading = false;

  final List<String> _privacyOptions = ['Public', 'Private', 'Unlisted'];
  final List<String> _categories = [
    'Film Production',
    'Audition Tips',
    'Industry News',
    'Networking',
    'Q&A Session',
    'Workshop',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickThumbnail() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _thumbnailFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking thumbnail: $e')));
    }
  }

  Future<void> _pickVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _videoFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking video: $e')));
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _scheduledDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createLiveSession() async {
    if (!_formKey.currentState!.validate()) return;

    if (_scheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload thumbnail if selected
      if (_thumbnailFile != null) {
        final uploadResult = await CloudinaryUploader().uploadImage(
          _thumbnailFile!,
          (progress) {},
        );
        _thumbnailUrl = uploadResult.url;
      }

      // Upload video if selected
      if (_videoFile != null) {
        final uploadResult = await CloudinaryUploader().uploadVideo(
          _videoFile!,
          (progress) {},
        );
        _videoUrl = uploadResult.url;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final scheduledDate = _scheduledDateTime!;
      final sessionData = {
        'eventName': _titleController.text.trim(),
        'about': _descriptionController.text.trim(),
        'eventType': 'Live Session',
        'category': _categoryController.text.trim().isEmpty
            ? 'Live Session'
            : _categoryController.text.trim(),
        'tags': _tagsController.text
            .trim()
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
        'privacy': _privacy,
        'scheduledDateTime': Timestamp.fromDate(scheduledDate),
        'date': DateFormat('dd MMM yyyy').format(scheduledDate),
        'time': DateFormat('hh:mm a').format(scheduledDate),
        'posterUrl': _thumbnailUrl ?? '',
        'thumbnailUrl': _thumbnailUrl ?? '',
        'posterVideoUrl': _videoUrl ?? '',
        'videoUrl': _videoUrl ?? '',
        'enableChat': _enableChat,
        'isMonetized': _isMonetized,
        'creatorId': currentUser.uid,
        'status': 'scheduled',
        'viewers': [],
        'likedBy': [],
        'createdAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('events').add(sessionData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live session created successfully!')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating live session: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1B),
        elevation: 0,
        title: const Text(
          'Create Live Session',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // Thumbnail Section
                    _buildThumbnailSection(),

                    const SizedBox(height: 24),

                    // Video Section
                    _buildVideoSection(),

                    const SizedBox(height: 24),

                    // Basic Info Section
                    _buildBasicInfoSection(),

                    const SizedBox(height: 24),

                    // Schedule Section
                    _buildScheduleSection(),

                    const SizedBox(height: 24),

                    // Settings Section
                    _buildSettingsSection(),

                    const SizedBox(height: 32),

                    // Create Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _createLiveSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D4EDD),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'CREATE LIVE SESSION',
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
    );
  }

  Widget _buildThumbnailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thumbnail',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickThumbnail,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF9D4EDD).withOpacity(0.3),
              ),
            ),
            child: _thumbnailFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _thumbnailFile!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add thumbnail',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Video Preview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickVideo,
          child: Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF9D4EDD).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.video_call,
                      color: Colors.white.withOpacity(0.8),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Tap to add a preview video',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_videoFile != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _videoFile!.path.split('/').last,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Basic Information',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Session Title *'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Title is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Description'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _categoryController.text.isEmpty
              ? null
              : _categoryController.text,
          dropdownColor: const Color(0xFF1E1B2E),
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Category'),
          items: _categories.map((category) {
            return DropdownMenuItem(value: category, child: Text(category));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _categoryController.text = value ?? '';
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tagsController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Tags (comma separated)'),
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Schedule',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _selectDateTime,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF9D4EDD).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF9D4EDD)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _scheduledDateTime != null
                        ? DateFormat(
                            'yyyy-MM-dd HH:mm',
                          ).format(_scheduledDateTime!)
                        : 'Select date and time *',
                    style: TextStyle(
                      color: _scheduledDateTime != null
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _privacy,
          dropdownColor: const Color(0xFF1E1B2E),
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Privacy'),
          items: _privacyOptions.map((option) {
            return DropdownMenuItem(value: option, child: Text(option));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _privacy = value!;
            });
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text(
            'Enable Chat',
            style: TextStyle(color: Colors.white),
          ),
          value: _enableChat,
          onChanged: (value) {
            setState(() {
              _enableChat = value;
            });
          },
          activeColor: const Color(0xFF9D4EDD),
        ),
        SwitchListTile(
          title: const Text(
            'Monetize Session',
            style: TextStyle(color: Colors.white),
          ),
          value: _isMonetized,
          onChanged: (value) {
            setState(() {
              _isMonetized = value;
            });
          },
          activeColor: const Color(0xFF9D4EDD),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF1E1B2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF9D4EDD), width: 2),
      ),
    );
  }
}
