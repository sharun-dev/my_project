
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/cloudinary_uploader.dart';


class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _userNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _socialMediaCtrl = TextEditingController();

  bool _isProfessional = false;
  bool _obscure = true;
  bool _confirmObscure = true;
  bool _loading = false;
  String? _selectedRole;
  String? _idProofFileName;
  String? _idProofUrl;
  PlatformFile? _idProofFile;
  // Production House specific documents
  String? _businessIdentityFileName;
  String? _businessIdentityUrl;
  PlatformFile? _businessIdentityFile;
  String? _gstCertificateFileName;
  String? _gstCertificateUrl;
  PlatformFile? _gstCertificateFile;
  String? _certificateOfIncorporationFileName;
  String? _certificateOfIncorporationUrl;
  PlatformFile? _certificateOfIncorporationFile;
  String? _businessAddressFileName;
  String? _businessAddressUrl;
  PlatformFile? _businessAddressFile;
  String? _authorityProofFileName;
  String? _authorityProofUrl;
  String? _authorizedSignatoryFileName;
  String? _authorizedSignatoryUrl;
  PlatformFile? _authorizedSignatoryFile;
  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;

  // List of professional roles
  final List<String> _roles = [
    'Producer',
    'Director',
    'Screen Writer',
    'Cinematographer',
    'Editor',
    'Sound Designer',
    'Actor(s)',
    'Casting Director',
    'Production House',
  ];

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
  }

  @override
  void dispose() {
    _userNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _locationCtrl.dispose();
    _socialMediaCtrl.dispose();
    super.dispose();
  }

  void _attemptRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate passwords match
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate professional fields if applicable
    if (_isProfessional && _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a professional role'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Create user account with Firebase
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );

      // Update user display name
      await userCredential.user?.updateDisplayName(_userNameCtrl.text.trim());

      // Store user details in Firestore
      await _storeUserInFirestore(userCredential.user!.uid);

      if (!mounted) return;

      // After registration, require admin approval before entering the app.
      await _auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful. Awaiting admin approval.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = 'Registration failed';

      if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak (min 6 characters)';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Email is already registered';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
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

  Future<void> _storeUserInFirestore(String uid) async {
    try {
      final userDoc = {
        'uid': uid,
        'username': _userNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'accountType': _isProfessional ? 'professional' : 'regular',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add professional specific fields if applicable
      if (_isProfessional) {
        userDoc['role'] = _selectedRole ?? '';
        userDoc['location'] = _locationCtrl.text.trim();
        userDoc['socialMedia'] = _socialMediaCtrl.text.trim();
        userDoc['idProofFileName'] = _idProofFileName ?? '';
        userDoc['idProofUrl'] = _idProofUrl ?? '';
        userDoc['idProofStatus'] = _idProofFile != null
            ? 'submitted'
            : 'not_submitted';
      }

      // Create user document in 'users' collection
      await _firestore.collection('users').doc(uid).set(userDoc);

      // If the user is a professional, also create/update a document
      // in the 'profession' collection for professional-specific lookup.
      if (_isProfessional) {
        final profDoc = {
          'uid': uid,
          'name': _userNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'role': _selectedRole ?? '',
          'location': _locationCtrl.text.trim(),
          'socialMedia': _socialMediaCtrl.text.trim(),
          'idProofFileName': _idProofFileName ?? '',
          'idProofUrl': _idProofUrl ?? '',
          'idProofStatus': _idProofFile != null ? 'submitted' : 'not_submitted',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Add Production House specific fields
        if (_selectedRole == 'Production House') {
          profDoc['businessIdentityFileName'] = _businessIdentityFileName ?? '';
          profDoc['businessIdentityUrl'] = _businessIdentityUrl ?? '';
          profDoc['gstCertificateFileName'] = _gstCertificateFileName ?? '';
          profDoc['gstCertificateUrl'] = _gstCertificateUrl ?? '';
          profDoc['certificateOfIncorporationFileName'] = _certificateOfIncorporationFileName ?? '';
          profDoc['certificateOfIncorporationUrl'] = _certificateOfIncorporationUrl ?? '';
          profDoc['businessAddressFileName'] = _businessAddressFileName ?? '';
          profDoc['businessAddressUrl'] = _businessAddressUrl ?? '';
          profDoc['authorityProofFileName'] = _authorityProofFileName ?? '';
          profDoc['authorityProofUrl'] = _authorityProofUrl ?? '';
          profDoc['authorizedSignatoryFileName'] = _authorizedSignatoryFileName ?? '';
          profDoc['authorizedSignatoryUrl'] = _authorizedSignatoryUrl ?? '';
        }

        await _firestore.collection('profession').doc(uid).set(profDoc);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User details saved successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving user details: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }


  // File picker for ID proof (kept but not required)
  Future<void> _uploadIdProof() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        String? uploadedUrl;

        try {
          final ext = result.files.single.extension?.toLowerCase() ?? '';
          if (['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'].contains(ext)) {
            final uploadResult = await CloudinaryUploader().uploadImage(file, (progress) {});
            uploadedUrl = uploadResult.url;
          } else {
            final uploadResult = await CloudinaryUploader().uploadRaw(file, (progress) {});
            uploadedUrl = uploadResult.url;
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload ID proof: $e'),
              backgroundColor: Colors.red,
            ),
          );
          uploadedUrl = null;
        }

        setState(() {
          _idProofFile = result.files.single;
          _idProofFileName = result.files.single.name;
          _idProofUrl = uploadedUrl;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File selected: $_idProofFileName'),
            backgroundColor: const Color(0xFF7B2CBF),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadBusinessIdentity() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        String? uploadedUrl;

        try {
          final ext = result.files.single.extension?.toLowerCase() ?? '';
          if (['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'].contains(ext)) {
            final uploadResult = await CloudinaryUploader().uploadImage(file, (progress) {});
            uploadedUrl = uploadResult.url;
          } else {
            final uploadResult = await CloudinaryUploader().uploadRaw(file, (progress) {});
            uploadedUrl = uploadResult.url;
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload Business Identity: $e'),
              backgroundColor: Colors.red,
            ),
          );
          uploadedUrl = null;
        }

        setState(() {
          _businessIdentityFile = result.files.single;
          _businessIdentityFileName = result.files.single.name;
          _businessIdentityUrl = uploadedUrl;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File selected: $_businessIdentityFileName'),
            backgroundColor: const Color(0xFF7B2CBF),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadGstCertificate() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        String? uploadedUrl;

        try {
          final ext = result.files.single.extension?.toLowerCase() ?? '';
          if (['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'].contains(ext)) {
            final uploadResult = await CloudinaryUploader().uploadImage(file, (progress) {});
            uploadedUrl = uploadResult.url;
          } else {
            final uploadResult = await CloudinaryUploader().uploadRaw(file, (progress) {});
            uploadedUrl = uploadResult.url;
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload GST Certificate: $e'),
              backgroundColor: Colors.red,
            ),
          );
          uploadedUrl = null;
        }

        setState(() {
          _gstCertificateFile = result.files.single;
          _gstCertificateFileName = result.files.single.name;
          _gstCertificateUrl = uploadedUrl;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File selected: $_gstCertificateFileName'),
            backgroundColor: const Color(0xFF7B2CBF),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadCertificateOfIncorporation() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        String? uploadedUrl;

        try {
          final ext = result.files.single.extension?.toLowerCase() ?? '';
          if (['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'].contains(ext)) {
            final uploadResult = await CloudinaryUploader().uploadImage(file, (progress) {});
            uploadedUrl = uploadResult.url;
          } else {
            final uploadResult = await CloudinaryUploader().uploadRaw(file, (progress) {});
            uploadedUrl = uploadResult.url;
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload Certificate of Incorporation: $e'),
              backgroundColor: Colors.red,
            ),
          );
          uploadedUrl = null;
        }

        setState(() {
          _certificateOfIncorporationFile = result.files.single;
          _certificateOfIncorporationFileName = result.files.single.name;
          _certificateOfIncorporationUrl = uploadedUrl;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File selected: $_certificateOfIncorporationFileName'),
            backgroundColor: const Color(0xFF7B2CBF),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadBusinessAddress() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        String? uploadedUrl;

        try {
          final ext = result.files.single.extension?.toLowerCase() ?? '';
          if (['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'].contains(ext)) {
            final uploadResult = await CloudinaryUploader().uploadImage(file, (progress) {});
            uploadedUrl = uploadResult.url;
          } else {
            final uploadResult = await CloudinaryUploader().uploadRaw(file, (progress) {});
            uploadedUrl = uploadResult.url;
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload Business Address: $e'),
              backgroundColor: Colors.red,
            ),
          );
          uploadedUrl = null;
        }

        setState(() {
          _businessAddressFile = result.files.single;
          _businessAddressFileName = result.files.single.name;
          _businessAddressUrl = uploadedUrl;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File selected: $_businessAddressFileName'),
            backgroundColor: const Color(0xFF7B2CBF),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadAuthorityProof() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        String? uploadedUrl;

        try {
          final ext = result.files.single.extension?.toLowerCase() ?? '';
          if (['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'].contains(ext)) {
            final uploadResult = await CloudinaryUploader().uploadImage(file, (progress) {});
            uploadedUrl = uploadResult.url;
          } else {
            final uploadResult = await CloudinaryUploader().uploadRaw(file, (progress) {});
            uploadedUrl = uploadResult.url;
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload Authority Proof: $e'),
              backgroundColor: Colors.red,
            ),
          );
          uploadedUrl = null;
        }

        setState(() {
          _authorityProofFileName = result.files.single.name;
          _authorityProofUrl = uploadedUrl;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File selected: $_authorityProofFileName'),
            backgroundColor: const Color(0xFF7B2CBF),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadAuthorizedSignatory() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        String? uploadedUrl;

        try {
          final ext = result.files.single.extension?.toLowerCase() ?? '';
          if (['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'].contains(ext)) {
            final uploadResult = await CloudinaryUploader().uploadImage(file, (progress) {});
            uploadedUrl = uploadResult.url;
          } else {
            final uploadResult = await CloudinaryUploader().uploadRaw(file, (progress) {});
            uploadedUrl = uploadResult.url;
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload Authorized Signatory: $e'),
              backgroundColor: Colors.red,
            ),
          );
          uploadedUrl = null;
        }

        setState(() {
          _authorizedSignatoryFile = result.files.single;
          _authorizedSignatoryFileName = result.files.single.name;
          _authorizedSignatoryUrl = uploadedUrl;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File selected: $_authorizedSignatoryFileName'),
            backgroundColor: const Color(0xFF7B2CBF),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const purpleA = Color(0xFF9D4EDD);
    const purpleB = Color(0xFF7B2CBF);
    const accent = Color(0xFFE0AAFF);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/assets/cover.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Back Button
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Header Section
                  _buildHeader(),
                  const SizedBox(height: 20),

                  // User Type Selection - Made Smaller
                  _buildUserTypeSelector(),
                  const SizedBox(height: 20),

                  // Registration Form with Animation
                  _buildRegistrationForm(purpleA, purpleB, accent),
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
        // Registration Icon
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Color.fromRGBO(157, 77, 221, 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color.fromRGBO(157, 77, 221, 0.3),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'lib/assets/logos.jpeg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Title
        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle
        const Text(
          'Join FilmSphere community',
          style: TextStyle(
            color: Color(0xFFBFA3E6),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),

        // Decorative Line
        Container(
          height: 2,
          width: 60,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE0AAFF), Color(0xFF9D4EDD)],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  Widget _buildUserTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Color.fromRGBO(11, 11, 18, 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color.fromRGBO(123, 44, 191, 0.2)),
      ),
      child: Row(
        children: [
          // User Type
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isProfessional = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: !_isProfessional
                      ? Color.fromRGBO(157, 77, 221, 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: !_isProfessional
                        ? const Color(0xFF9D4EDD)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      color: !_isProfessional
                          ? const Color(0xFFE0AAFF)
                          : Colors.white54,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'User',
                      style: TextStyle(
                        color: !_isProfessional
                            ? const Color(0xFFE0AAFF)
                            : Colors.white54,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Professional Type
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isProfessional = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: _isProfessional
                      ? Color.fromRGBO(157, 77, 221, 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isProfessional
                        ? const Color(0xFF9D4EDD)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.work_rounded,
                      color: _isProfessional
                          ? const Color(0xFFE0AAFF)
                          : Colors.white54,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Professional',
                      style: TextStyle(
                        color: _isProfessional
                            ? const Color(0xFFE0AAFF)
                            : Colors.white54,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm(Color purpleA, Color purpleB, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color.fromRGBO(11, 11, 18, 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color.fromRGBO(123, 44, 191, 0.3)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Color.fromRGBO(123, 44, 191, 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Common Fields
            _buildTextFormField(
              controller: _userNameCtrl,
              hintText: 'Username',
              prefixIcon: Icons.person_outline_rounded,
              accent: accent,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Username is required';
                }
                if (value.trim().length < 3) {
                  return 'Username must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildTextFormField(
              controller: _emailCtrl,
              hintText: 'Email Address',
              prefixIcon: Icons.alternate_email_rounded,
              accent: accent,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                final emailRegex = RegExp(r'^[^@]+@gmail\.com$');
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'Please enter a valid Gmail address (e.g., example@gmail.com)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildTextFormField(
              controller: _phoneCtrl,
              hintText: 'Phone Number',
              prefixIcon: Icons.phone_rounded,
              accent: accent,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Phone number is required';
                }
                if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                  return 'Phone number must be exactly 10 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password Field
            _buildPasswordFormField(
              accent,
              'Password',
              _passwordCtrl,
              _obscure,
              () {
                setState(() => _obscure = !_obscure);
              },
              (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                // Check for common weak passwords
                final weakPasswords = [
                  '123456', '123456789', 'qwerty', 'password', '12345', '12345678',
                  '111111', '1234567', 'abc123', 'password1', '123123', 'admin',
                  'letmein', 'welcome', 'monkey', '1234567890', 'iloveyou', 'princess',
                  'rockyou', '123456789', 'qwerty123', '1q2w3e4r', 'baseball', 'dragon',
                  'football', 'master', 'jordan', 'harley', 'ranger', 'iowa', 'pepper',
                  'jennifer', 'hunter', 'jordan23', 'tigger', 'rover', 'sunshine',
                  'trustno1', 'superman', 'michael', 'mustang', 'batman', 'andrew',
                  'charlie', 'matthew', 'joshua', 'daniel', 'christopher', 'anthony',
                  'nicholas', 'jacob', 'jessica', 'ashley', 'biteme', 'summer', 'flower',
                  'taylor', 'melissa', 'whatever', 'mickey', 'shadow', 'cheese', 'buster'
                ];
                if (weakPasswords.contains(value.toLowerCase())) {
                  return 'This password is too common. Please choose a stronger password.';
                }
                // Check for at least one digit
                if (!RegExp(r'[0-9]').hasMatch(value)) {
                  return 'Password must contain at least one number';
                }
                // Check for at least one special character
                if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                  return 'Password must contain at least one special character';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirm Password Field
            _buildPasswordFormField(
              accent,
              'Confirm Password',
              _confirmPasswordCtrl,
              _confirmObscure,
              () {
                setState(() => _confirmObscure = !_confirmObscure);
              },
              (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Professional Specific Fields with Animation
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1.0,
                    child: child,
                  ),
                );
              },
              child: _isProfessional
                  ? _buildProfessionalFields(accent)
                  : const SizedBox.shrink(),
            ),

            // Register Button
            _buildRegisterButton(purpleA, purpleB),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalFields(Color accent) {
    List<Widget> children = [
      _buildTextField(
        controller: _locationCtrl,
        hintText: 'Location/Place',
        prefixIcon: Icons.location_on_rounded,
        accent: accent,
      ),
      const SizedBox(height: 16),

      // Role Dropdown with White Text
      _buildRoleDropdown(accent),
      const SizedBox(height: 16),

      // Social Media
      _buildTextField(
        controller: _socialMediaCtrl,
        hintText: 'Social Media Profile',
        prefixIcon: Icons.link_rounded,
        accent: accent,
      ),
      const SizedBox(height: 16),

      // ID Proof Upload with file picker (optional)
      _buildIdProofUpload(),
      const SizedBox(height: 16),

      // Production House specific documents
    ];

    if (_selectedRole == 'Production House') {
      children.add(_buildBusinessIdentityUpload());
      children.add(const SizedBox(height: 16));
      children.add(_buildGstCertificateUpload());
      children.add(const SizedBox(height: 16));
      children.add(_buildCertificateOfIncorporationUpload());
      children.add(const SizedBox(height: 16));
      children.add(_buildBusinessAddressUpload());
      children.add(const SizedBox(height: 16));
      children.add(_buildAuthorizedSignatoryUpload());
      children.add(const SizedBox(height: 16));
    }

    return Column(
      key: const ValueKey('professional_fields'),
      children: children,
    );
  }

  Widget _buildRoleDropdown(Color accent) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      dropdownColor: const Color(0xFF1E1B2E),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
      ), // White text (non-const context)
      decoration: InputDecoration(
        hintText: 'Select Role',
        hintStyle: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
        ), // White hint text
        filled: true,
        fillColor: Color.fromRGBO(255, 255, 255, 0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        prefixIcon: Icon(Icons.work_history_rounded, color: accent, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent.withOpacity(0.8), width: 2),
        ),
      ),
      items: _roles.map((String role) {
        return DropdownMenuItem<String>(
          value: role,
          child: Text(
            role,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ), // White text for items
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedRole = newValue;
        });
      },
    );
  }

  Widget _buildIdProofUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ID Proof (Government ID) - Optional',
          style: TextStyle(
            color: Colors.white, // Changed to white
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _uploadIdProof,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Color.fromRGBO(255, 255, 255, 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _idProofFile != null
                    ? const Color(0xFF9D4EDD)
                    : Color.fromRGBO(123, 44, 191, 0.3),
                width: _idProofFile != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _idProofFile != null
                      ? Icons.check_circle_rounded
                      : Icons.upload_rounded,
                  color: _idProofFile != null
                      ? Colors.green
                      : const Color(0xFFE0AAFF),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _idProofFile != null
                            ? 'File Selected'
                            : 'Tap to upload ID Proof',
                        style: const TextStyle(
                          color: Colors.white, // Changed to white
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_idProofFileName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _idProofFileName!,
                          style: TextStyle(
                            color: Color.fromRGBO(255, 255, 255, 0.7),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
                ),
                if (_idProofFile != null)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _idProofFile = null;
                        _idProofFileName = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Supported: PDF, JPG, PNG, DOC (Max 10MB)',
          style: TextStyle(
            color: Color.fromRGBO(255, 255, 255, 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessIdentityUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business Identity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _uploadBusinessIdentity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Color.fromRGBO(255, 255, 255, 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _businessIdentityFile != null
                    ? const Color(0xFF9D4EDD)
                    : Color.fromRGBO(123, 44, 191, 0.3),
                width: _businessIdentityFile != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _businessIdentityFile != null
                      ? Icons.check_circle_rounded
                      : Icons.upload_rounded,
                  color: _businessIdentityFile != null
                      ? Colors.green
                      : const Color(0xFFE0AAFF),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _businessIdentityFile != null
                            ? 'File Selected'
                            : 'Tap to upload Business Identity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _businessIdentityFileName ?? '',
                        style: TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.7),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'GST Registration Certificate or Certificate of Incorporation',
          style: TextStyle(
            color: Color.fromRGBO(255, 255, 255, 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildGstCertificateUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GST Certificate',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _uploadGstCertificate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Color.fromRGBO(255, 255, 255, 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _gstCertificateFile != null
                    ? const Color(0xFF9D4EDD)
                    : Color.fromRGBO(123, 44, 191, 0.3),
                width: _gstCertificateFile != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _gstCertificateFile != null
                      ? Icons.check_circle_rounded
                      : Icons.upload_rounded,
                  color: _gstCertificateFile != null
                      ? Colors.green
                      : const Color(0xFFE0AAFF),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _gstCertificateFile != null
                            ? 'File Selected'
                            : 'Tap to upload GST Certificate',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_gstCertificateFileName != null) const SizedBox(height: 4),
                      if (_gstCertificateFileName != null) Text(
                        _gstCertificateFileName!,
                        style: TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.7),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: _gstCertificateFile != null ? Colors.red : Colors.transparent,
                    size: 18,
                  ),
                  onPressed: _gstCertificateFile != null ? () {
                    setState(() {
                      _gstCertificateFile = null;
                      _gstCertificateFileName = null;
                      _gstCertificateUrl = null;
                    });
                  } : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'GST Registration Certificate',
          style: TextStyle(
            color: Color.fromRGBO(255, 255, 255, 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildCertificateOfIncorporationUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Certificate of Incorporation',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _uploadCertificateOfIncorporation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Color.fromRGBO(255, 255, 255, 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _certificateOfIncorporationFile != null
                    ? const Color(0xFF9D4EDD)
                    : Color.fromRGBO(123, 44, 191, 0.3),
                width: _certificateOfIncorporationFile != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _certificateOfIncorporationFile != null
                      ? Icons.check_circle_rounded
                      : Icons.upload_rounded,
                  color: _certificateOfIncorporationFile != null
                      ? Colors.green
                      : const Color(0xFFE0AAFF),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _certificateOfIncorporationFile != null
                            ? 'File Selected'
                            : 'Tap to upload Certificate of Incorporation',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_certificateOfIncorporationFileName != null) const SizedBox(height: 4),
                      if (_certificateOfIncorporationFileName != null) Text(
                        _certificateOfIncorporationFileName!,
                        style: TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.7),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: _certificateOfIncorporationFile != null ? Colors.red : Colors.transparent,
                    size: 18,
                  ),
                  onPressed: _certificateOfIncorporationFile != null ? () {
                    setState(() {
                      _certificateOfIncorporationFile = null;
                      _certificateOfIncorporationFileName = null;
                      _certificateOfIncorporationUrl = null;
                    });
                  } : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Certificate of Incorporation (COI)',
          style: TextStyle(
            color: Color.fromRGBO(255, 255, 255, 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessAddressUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business Address',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _uploadBusinessAddress,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Color.fromRGBO(255, 255, 255, 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _businessAddressFile != null
                    ? const Color(0xFF9D4EDD)
                    : Color.fromRGBO(123, 44, 191, 0.3),
                width: _businessAddressFile != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _businessAddressFile != null
                      ? Icons.check_circle_rounded
                      : Icons.upload_rounded,
                  color: _businessAddressFile != null
                      ? Colors.green
                      : const Color(0xFFE0AAFF),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _businessAddressFile != null
                            ? 'File Selected'
                            : 'Tap to upload Business Address',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_businessAddressFileName != null) const SizedBox(height: 4),
                      if (_businessAddressFileName != null) Text(
                        _businessAddressFileName!,
                        style: TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.7),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: _businessAddressFile != null ? Colors.red : Colors.transparent,
                    size: 18,
                  ),
                  onPressed: _businessAddressFile != null ? () {
                    setState(() {
                      _businessAddressFile = null;
                      _businessAddressFileName = null;
                      _businessAddressUrl = null;
                    });
                  } : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Utility Bill (Electricity/Water) or Rental Agreement',
          style: TextStyle(
            color: Color.fromRGBO(255, 255, 255, 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorizedSignatoryUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Authorized Signatory',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _uploadAuthorizedSignatory,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Color.fromRGBO(255, 255, 255, 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _authorizedSignatoryFile != null
                    ? const Color(0xFF9D4EDD)
                    : Color.fromRGBO(123, 44, 191, 0.3),
                width: _authorizedSignatoryFile != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _authorizedSignatoryFile != null
                      ? Icons.check_circle_rounded
                      : Icons.upload_rounded,
                  color: _authorizedSignatoryFile != null
                      ? Colors.green
                      : const Color(0xFFE0AAFF),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _authorizedSignatoryFile != null
                            ? 'File Selected'
                            : 'Tap to upload Authorized Signatory',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_authorizedSignatoryFileName != null) const SizedBox(height: 4),
                      if (_authorizedSignatoryFileName != null) Text(
                        _authorizedSignatoryFileName!,
                        style: TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.7),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: _authorizedSignatoryFile != null ? Colors.red : Colors.transparent,
                    size: 18,
                  ),
                  onPressed: _authorizedSignatoryFile != null ? () {
                    setState(() {
                      _authorizedSignatoryFile = null;
                      _authorizedSignatoryFileName = null;
                      _authorizedSignatoryUrl = null;
                    });
                  } : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Aadhaar Card/PAN Card of the Owner',
          style: TextStyle(
            color: Color.fromRGBO(255, 255, 255, 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required Color accent,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
          horizontal: 16,
          vertical: 14,
        ),
        prefixIcon: Icon(prefixIcon, color: accent, size: 20),
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

  Widget _buildRegisterButton(Color purpleA, Color purpleB) {
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
        onPressed: _loading ? null : _attemptRegistration,
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
          height: 22,
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
                      Icon(Icons.person_add_alt_1_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'CREATE ACCOUNT',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required Color accent,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
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
          horizontal: 16,
          vertical: 14,
        ),
        prefixIcon: Icon(prefixIcon, color: accent, size: 20),
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

  Widget _buildPasswordFormField(
    Color accent,
    String hintText,
    TextEditingController controller,
    bool obscure,
    VoidCallback onToggle,
    String? Function(String?)? validator,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
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
          horizontal: 16,
          vertical: 14,
        ),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: accent, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: Colors.white.withOpacity(0.6),
            size: 20,
          ),
          onPressed: onToggle,
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
}
