import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';


import 'services/cloudinary_uploader.dart';
import 'services/firestore_service.dart';

class AuditionCreateScreen extends StatefulWidget {
  final Map<String, dynamic>? initialAuditionData;

  const AuditionCreateScreen({super.key, this.initialAuditionData});

  @override
  State<AuditionCreateScreen> createState() => _AuditionCreateScreenState();
}

class _AuditionCreateScreenState extends State<AuditionCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productionNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _deadlineCtrl = TextEditingController();
  final _projectNameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _ageRangeCtrl = TextEditingController();
  final _lookSkillsCtrl = TextEditingController();
  final _shootDateCtrl = TextEditingController();
  final _shootLocationCtrl = TextEditingController();
  final _salaryBudgetCtrl = TextEditingController();
  final _applyLastDateCtrl = TextEditingController();
  final _roleDetailsCtrl = TextEditingController();
  final _coverImageDescCtrl = TextEditingController();

  String? _selectedType;
  String? _selectedGender;
  File? _selectedCoverImage;

  final List<String> _types = ['Film', 'Ad', 'Web Series', 'TV Serial', 'Other'];
  final List<String> _genders = ['Male', 'Female', 'Any'];

  @override
  void initState() {
    super.initState();
    if (widget.initialAuditionData != null) {
      _initializeFields(widget.initialAuditionData!);
    }
  }

  void _initializeFields(Map<String, dynamic> data) {
    _productionNameCtrl.text = data['production'] ?? '';
    _addressCtrl.text = data['address'] ?? '';
    _locationCtrl.text = data['location'] ?? '';
    _deadlineCtrl.text = data['date'] ?? '';
    _projectNameCtrl.text = data['title'] ?? '';
    _roleCtrl.text = data['role'] ?? '';
    _ageRangeCtrl.text = data['ageRange'] ?? '';
    _lookSkillsCtrl.text = data['lookSkills'] ?? '';
    _shootDateCtrl.text = data['shootDate'] ?? '';
    _shootLocationCtrl.text = data['shootLocation'] ?? '';
    _salaryBudgetCtrl.text = data['budget'] ?? '';
    _applyLastDateCtrl.text = data['applyLastDate'] ?? '';
    _roleDetailsCtrl.text = data['roleDetails'] ?? '';
    _coverImageDescCtrl.text = data['coverImageDescription'] ?? '';
    _selectedType = data['type'];
    _selectedGender = data['gender'];
    // For cover image, if there's a URL, we can't load it back to File, so leave it as is
  }

  @override
  void dispose() {
    _productionNameCtrl.dispose();
    _addressCtrl.dispose();
    _locationCtrl.dispose();
    _deadlineCtrl.dispose();
    _projectNameCtrl.dispose();
    _roleCtrl.dispose();
    _ageRangeCtrl.dispose();
    _lookSkillsCtrl.dispose();
    _shootDateCtrl.dispose();
    _shootLocationCtrl.dispose();
    _salaryBudgetCtrl.dispose();
    _applyLastDateCtrl.dispose();
    _roleDetailsCtrl.dispose();
    _coverImageDescCtrl.dispose();
    super.dispose();
  }

  void _submitAudition() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      String? coverImageUrl;
      if (_selectedCoverImage != null && _selectedCoverImage!.existsSync()) {
        final uploadResult = await CloudinaryUploader().uploadImage(
          _selectedCoverImage!,
          (progress) {},
        );
        coverImageUrl = uploadResult.url;
      } else if (widget.initialAuditionData != null) {
        // Keep existing cover image if not changed
        coverImageUrl = widget.initialAuditionData!['coverImage'] ?? widget.initialAuditionData!['image'];
      }

      final auditionData = {
        'production': _productionNameCtrl.text,
        'address': _addressCtrl.text,
        'location': _locationCtrl.text,
        'date': _deadlineCtrl.text,
        'title': _projectNameCtrl.text,
        'type': _selectedType,
        'role': _roleCtrl.text,
        'ageRange': _ageRangeCtrl.text,
        'gender': _selectedGender,
        'lookSkills': _lookSkillsCtrl.text,
        'shootDate': _shootDateCtrl.text,
        'shootLocation': _shootLocationCtrl.text,
        'budget': _salaryBudgetCtrl.text,
        'applyLastDate': _applyLastDateCtrl.text,
        'roleDetails': _roleDetailsCtrl.text,
        'coverImage': coverImageUrl,
        'image': coverImageUrl,
        'coverImageDescription': _coverImageDescCtrl.text,
      };

      if (widget.initialAuditionData != null) {
        // Update existing audition
        await FirestoreService.updateAudition(widget.initialAuditionData!['id'], auditionData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audition updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Create new audition
        await FirestoreService.saveAudition(auditionData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audition created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context, auditionData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ${widget.initialAuditionData != null ? 'updating' : 'creating'} audition: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.initialAuditionData != null ? 'Edit Audition' : 'Create New Audition',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
              const Text(
                'Production Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(_productionNameCtrl, 'Production Name', Icons.business),
              const SizedBox(height: 16),
              _buildTextField(_addressCtrl, 'Address', Icons.location_on),
              const SizedBox(height: 16),
              _buildTextField(_locationCtrl, 'Location', Icons.place),
              const SizedBox(height: 16),
              _buildTextField(_deadlineCtrl, 'Deadline', Icons.calendar_today),
              const SizedBox(height: 24),
              _buildCoverImageSection(),
              const SizedBox(height: 24),
              const Text(
                'Project Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(_projectNameCtrl, 'Project Name', Icons.movie),
              const SizedBox(height: 16),
              _buildDropdown(
                _selectedType,
                'Type (Film/Ad/Web Series)',
                _types,
                (value) {
                  setState(() => _selectedType = value);
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(_roleCtrl, 'Role', Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(_ageRangeCtrl, 'Age Range (e.g., 25-35)', Icons.cake),
              const SizedBox(height: 16),
              _buildDropdown(
                _selectedGender,
                'Gender',
                _genders,
                (value) {
                  setState(() => _selectedGender = value);
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(_lookSkillsCtrl, 'Look / Skills Required', Icons.star),
              const SizedBox(height: 24),
              const Text(
                'Shoot & Payment Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(_shootDateCtrl, 'Shoot Date', Icons.date_range),
              const SizedBox(height: 16),
              _buildTextField(_shootLocationCtrl, 'Shoot Location', Icons.location_on_outlined),
              const SizedBox(height: 16),
              _buildTextField(_salaryBudgetCtrl, 'Salary / Budget (Optional)', Icons.money),
              const SizedBox(height: 16),
              _buildTextField(_applyLastDateCtrl, 'Apply Last Date', Icons.access_time),
              const SizedBox(height: 24),
              const Text(
                'Role Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _buildRichTextField(
                _roleDetailsCtrl,
                'Role Details (Rich Text)',
              ),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
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
      validator: (value) => value?.isEmpty ?? true ? 'Please enter $hint' : null,
    );
  }

  Widget _buildRichTextField(
    TextEditingController controller,
    String hint,
  ) {
    return TextFormField(
      controller: controller,
      maxLines: 5,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
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
      validator: (value) => value?.isEmpty ?? true ? 'Please enter role details' : null,
    );
  }

  Widget _buildDropdown(
    String? selectedValue,
    String hint,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: selectedValue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        prefixIcon: const Icon(Icons.category, color: Color(0xFFE0AAFF)),
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
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Please select $hint' : null,
      dropdownColor: const Color(0xFF1E1B2E),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildCoverImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cover Image',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              border: Border.all(
                color: const Color(0xFF9D4EDD).withOpacity(0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _selectedCoverImage != null && _selectedCoverImage!.existsSync()
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _selectedCoverImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : _selectedCoverImage != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Image file not found',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        color: const Color(0xFFE0AAFF),
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap to add cover image',
                        style: TextStyle(
                          color: Color(0xFFE0AAFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PNG, JPG, or JPEG',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (_selectedCoverImage != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedCoverImage!.path.split('/').last,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCoverImage = null;
                  });
                },
                child: const Icon(
                  Icons.close,
                  color: Colors.red,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _buildTextField(
          _coverImageDescCtrl,
          'Cover Image Description',
          Icons.description,
        ),
      ],
    );
  }

  Future<void> _pickCoverImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedCoverImage = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        onPressed: _submitAudition,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9D4EDD),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          widget.initialAuditionData != null ? 'UPDATE AUDITION' : 'CREATE AUDITION',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
