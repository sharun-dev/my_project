import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';
import 'chat_utilities.dart';
import 'services/firestore_service.dart';

class RoleDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> role;

  const RoleDetailsScreen({super.key, required this.role});

  @override
  State<RoleDetailsScreen> createState() => _RoleDetailsScreenState();
}

class _RoleDetailsScreenState extends State<RoleDetailsScreen> {
  List<Map<String, dynamic>> _professionals = [];
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final Map<String, ChewieController?> _chewieControllers = {};
  final Map<String, bool> _expandedStates = {};
  final Set<String> _likedProfessionalIds = {}; // local session likes
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfessionals();
  }

  String _normalizeRoleName(String title) {
    // Convert plural role titles to singular form for Firestore matching
    final roleMap = {
      'Actors': 'Actor',
      'Directors': 'Director',
      'Producers': 'Producer',
      'Screen Writers': 'Screen Writer',
      'Cinematographers': 'Cinematographer',
      'Editors': 'Editor',
      'Sound Designers': 'Sound Designer',
      'Casting Directors': 'Casting Director',
    };

    return roleMap[title] ??
        (title.endsWith('s') ? title.substring(0, title.length - 1) : title);
  }

  Map<String, String> _parsePhysicalAttributes(String attributes) {
    // Parse string like "h=178cm w=91kg" into height and weight
    final result = {'height': 'N/A', 'weight': 'N/A'};

    final parts = attributes.split(' ');
    for (var part in parts) {
      if (part.startsWith('h=')) {
        result['height'] = part.replaceFirst('h=', '');
      } else if (part.startsWith('w=')) {
        result['weight'] = part.replaceFirst('w=', '');
      }
    }

    return result;
  }

  Future<void> _fetchProfessionals() async {
    try {
      // Extract and normalize role name from the title
      final roleTitle = widget.role['title'] ?? 'Actors';
      final normalizedRole = _normalizeRoleName(roleTitle);

      // Try to fetch by normalized role first
      var professionals = await FirestoreService.fetchProfessionalsByRole(
        normalizedRole,
      );

      // If no results, try fetching all and filter on client side
      if (professionals.isEmpty) {
        final allProfessionals = await FirestoreService.fetchAllProfessionals();

        // Filter by role (case-insensitive, also check against the original role title, and handle "Actor(s)" format)
        professionals = allProfessionals.where((prof) {
          final profRole = (prof['role'] as String?)?.trim() ?? '';
          final normalizedProfRole = profRole
              .replaceAll('(s)', '')
              .replaceAll('(S)', '')
              .toLowerCase();
          final normalizedRoleToMatch = normalizedRole.toLowerCase();
          final roleTitleToMatch = roleTitle.toLowerCase();

          return normalizedProfRole == normalizedRoleToMatch ||
              normalizedProfRole == roleTitleToMatch ||
              profRole.toLowerCase().contains(normalizedRoleToMatch) ||
              profRole.toLowerCase().contains(normalizedRole.toLowerCase());
        }).toList();

      }

      if (professionals.isNotEmpty) {
        // Process Firestore data to ensure all required fields exist
        final processedProfessionals = professionals.map((prof) {
          // Helper function to convert string to list
          List<dynamic> _parseStringToList(dynamic value) {
            if (value is List) return value;
            if (value is String) {
              return value
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList();
            }
            return [];
          }

          // Parse previous works - could be string or list
          List<dynamic> previousWorks = [];
          if (prof['previousWorks'] is List) {
            previousWorks = prof['previousWorks'];
          } else if (prof['previousWorks'] is String &&
              (prof['previousWorks'] as String).isNotEmpty) {
            previousWorks = _parseStringToList(prof['previousWorks']);
          }

          // Parse physical attributes (for descriptions like height and weight)
          final physicalAttributes = _parsePhysicalAttributes(
            prof['physicalAttributes'] as String? ?? '',
          );

          return {
            'id': prof['id'] ?? prof['userId'] ?? DateTime.now().toString(),
            'name': prof['fullName'] ?? prof['name'] ?? 'Unknown',
            'role': prof['role'] ?? normalizedRole,
            'experience': prof['experience'] ?? 'N/A',
            'experienceYears': _extractYears(prof['experience'] ?? '0 years'),
            'company': prof['company'] ?? '',
            'age': prof['age'] ?? 'Unknown',
            'location': prof['location'] ?? 'Unknown',
            'awards': prof['awards'] ?? 'No awards listed',
            'rating': prof['rating'] ?? '4.0',
            'projects': prof['projects'] ?? '0+',
            'availability': prof['availability'] ?? 'Not specified',
            'specialization': prof['specialization'] ?? 'General',
            'image':
                prof['image'] ??
                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
            'phone': prof['phone'] ?? '',
            'email': prof['email'] ?? '',
            'languages': prof['languages'] is List
                ? prof['languages']
                : ['English'],
            'skills': prof['skills'] is List ? prof['skills'] : [],
            'height': prof['height'] ?? physicalAttributes['height'] ?? 'N/A',
            'weight': prof['weight'] ?? physicalAttributes['weight'] ?? 'N/A',
            'education': prof['education'] ?? 'N/A',
            'previous_works': previousWorks,
            'videos': prof['videos'] is List ? prof['videos'] : [],
            'bio': prof['bio'] ?? 'Professional profile',
            'short_bio':
                prof['short_bio'] ??
                (prof['bio'] is String
                    ? (prof['bio'] as String).substring(
                        0,
                        min(60, (prof['bio'] as String).length),
                      )
                    : 'Professional'),
            'physicalAttributes': prof['physicalAttributes'] ?? '',
            'socialLinks': prof['socialLinks'] ?? '',
            'portfolioImages': prof['portfolioImages'] is List
                ? prof['portfolioImages']
                : [],
            'portfolioVideos': prof['portfolioVideos'] is List
                ? prof['portfolioVideos']
                : [],
            'moreDetails': prof['moreDetails'] is List
                ? List<Map<String, dynamic>>.from(prof['moreDetails'])
                : [],
            'likes': prof['likes'] is int
                ? prof['likes'] as int
                : int.tryParse(prof['likes']?.toString() ?? '') ?? 0,
            'lastLikedRole': prof['lastLikedRole'] ?? '',
            'likesByRole': prof['likesByRole'] ?? {},
          };
        }).toList();

        setState(() {
          _professionals = processedProfessionals;
          _isLoading = false;
        });
      } else {
        // No professionals found in Firestore
        setState(() {
          _professionals = [];
          _isLoading = false;
        });
      }

      // Initialize video players and expanded states
      _initializeVideoPlayers();
      for (var professional in _professionals) {
        _expandedStates[professional['id']] = false;
      }
    } catch (e) {
      debugPrint('Error fetching professionals: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading professionals: ${e.toString()}';
        _professionals = [];
      });

      // Ensure expanded states are reset even when no professionals are loaded
      _expandedStates.clear();
    }
  }

  int _extractYears(String experience) {
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(experience);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  String _formatAge(dynamic age) {
    if (age == null || age.toString().isEmpty) {
      return 'N/A';
    }
    final ageStr = age.toString().trim();
    // If already has 'years' or 'year' suffix, return as is
    if (ageStr.toLowerCase().contains('year')) {
      return ageStr;
    }
    // Otherwise append ' years'
    return '$ageStr years';
  }

  void _initializeVideoPlayers() async {
    for (var professional in _professionals) {
      final videosList = professional['videos'] as List? ?? [];
      if (videosList.isEmpty) continue;

      for (var video in videosList) {
        try {
          final videoUrl = video['url'] as String?;
          if (videoUrl == null || videoUrl.isEmpty) continue;

          final videoPlayerController = VideoPlayerController.network(videoUrl);
          await videoPlayerController.initialize();

          if (mounted) {
            setState(() {
              _chewieControllers[videoUrl] = ChewieController(
                videoPlayerController: videoPlayerController,
                autoPlay: false,
                looping: false,
                allowFullScreen: true,
                allowMuting: true,
                showControls: true,
                materialProgressColors: ChewieProgressColors(
                  playedColor: const Color(0xFF9D4EDD),
                  handleColor: const Color(0xFFE0AAFF),
                  backgroundColor: Colors.white.withOpacity(0.3),
                  bufferedColor: Colors.white.withOpacity(0.2),
                ),
              );
            });
          }
        } catch (e) {
          debugPrint('Error initializing video: $e');
        }
      }
    }
  }

  Future<void> _onLikePressed(Map<String, dynamic> professional) async {
    final professionalId = professional['id'] as String?;
    final role = professional['role'] as String? ?? '';
    if (professionalId == null || professionalId.isEmpty) return;

    if (_likedProfessionalIds.contains(professionalId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already liked this user this session.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      await FirestoreService.incrementProfessionalLikes(professionalId, role);
      setState(() {
        _likedProfessionalIds.add(professionalId);
        professional['likes'] = (professional['likes'] as int? ?? 0) + 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profession got a like!'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Like failed: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _chewieControllers.values) {
      controller?.dispose();
    }
    super.dispose();
  }

  bool _matchesExperienceFilter(
    Map<String, dynamic> professional,
    String filter,
  ) {
    if (filter == 'All') return true;

    final experienceYears = professional['experienceYears'] as int? ?? 0;

    switch (filter) {
      case '1-3 years':
        return experienceYears >= 1 && experienceYears <= 3;
      case '3-5 years':
        return experienceYears >= 3 && experienceYears <= 5;
      case '5+ years':
        return experienceYears >= 5;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.role['title'],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D4EDD)),
          ),
        ),
      );
    }

    final filteredProfessionals = _professionals.where((professional) {
      final name = professional['name']?.toLowerCase() ?? '';
      final role = professional['role']?.toLowerCase() ?? '';
      final specialization =
          professional['specialization']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      final matchesSearch =
          name.contains(query) ||
          role.contains(query) ||
          specialization.contains(query);
      final matchesFilter = _matchesExperienceFilter(
        professional,
        _selectedFilter,
      );
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.role['title'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          _buildSearchFilterBar(),
          Expanded(
            child: filteredProfessionals.isEmpty
                ? _buildNoResults()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filteredProfessionals.length,
                    itemBuilder: (context, index) {
                      final professional = filteredProfessionals[index];
                      return _buildProfessionalCard(professional);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedFilter == 'All'
                ? 'No professionals found'
                : 'No professionals with $_selectedFilter experience',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Try changing your search or filter criteria',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _selectedFilter = 'All';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9D4EDD),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color.fromARGB(255, 7, 7, 7).withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.search, color: Color(0xFF9D4EDD), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 5, 5, 5),
                        fontSize: 16,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search professionals...',
                        hintStyle: TextStyle(
                          color: Color(0xFF8080A0),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color.fromARGB(255, 7, 7, 7).withOpacity(0.1),
              ),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(
                Icons.filter_list,
                color: Color(0xFF9D4EDD),
                size: 24,
              ),
              color: const Color(0xFF1E1B2E),
              onSelected: (value) => setState(() => _selectedFilter = value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'All',
                  child: Text(
                    'All Experience',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const PopupMenuItem(
                  value: '1-3 years',
                  child: Text(
                    '1-3 years',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const PopupMenuItem(
                  value: '3-5 years',
                  child: Text(
                    '3-5 years',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const PopupMenuItem(
                  value: '5+ years',
                  child: Text(
                    '5+ years',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalCard(Map<String, dynamic> professional) {
    final isExpanded = _expandedStates[professional['id']] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2B55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info Section (Always visible)
          _buildBasicInfoSection(professional),

          // Expanded Details Section
          if (isExpanded) _buildExpandedDetails(professional),

          // Read More/Less Button
          _buildReadMoreButton(professional, isExpanded),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(Map<String, dynamic> professional) {
    final name = professional['name'] as String? ?? 'Unknown';
    final role = professional['role'] as String? ?? 'Professional';
    final experience = professional['experience'] as String? ?? 'N/A';
    final location = professional['location'] as String? ?? 'Unknown';
    final specialization =
        professional['specialization'] as String? ?? 'General';
    final image =
        professional['image'] as String? ??
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200';
    final bio = professional['bio'] as String? ?? 'Professional profile';
    final shortBio = professional['short_bio'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top full-width cover image
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(image),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.45), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: const TextStyle(
                      color: Color(0xFFE0AAFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startChat(professional),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9D4EDD),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _onLikePressed(professional),
                  icon: Icon(
                    Icons.thumb_up,
                    color: _likedProfessionalIds.contains(professional['id'])
                        ? Colors.greenAccent
                        : Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    'Like ${(professional['likes'] as int? ?? 0)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2B55),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF3D3B65)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name and options row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      professional['name'] != null &&
                              professional['name'].toString().isNotEmpty
                          ? professional['name']
                          : 'Unknown Name',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: const Color(0xFF1E1B2E),
                    onSelected: (value) {
                      if (value == 'report') {
                        _showReportDialog(professional);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'report',
                        child: Text(
                          'Report',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Stats row
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _buildStatItem(
                    Icons.thumb_up,
                    '${professional['likes'] ?? 0} likes',
                    const Color(0xFF6EE7B7),
                  ),
                  _buildStatItem(
                    Icons.work,
                    experience,
                    const Color(0xFFE0AAFF),
                  ),
                  _buildStatItem(
                    Icons.location_on,
                    location,
                    const Color(0xFF9D4EDD),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Specialization and short bio
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2B55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.psychology,
                      color: Color(0xFFE0AAFF),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Specializes in: $specialization',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                shortBio.isNotEmpty
                    ? shortBio
                    : (bio.length > 80 ? '${bio.substring(0, 80)}...' : bio),
                style: const TextStyle(
                  color: Color(0xFFC0C0E0),
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              if (professional['moreDetails'] != null &&
                  (professional['moreDetails'] as List).isNotEmpty)
                _buildMoreDetailsSection(professional),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  final List<String> _detailSectionOrder = [
    'bio',
    'awards',
    'company',
    'availability',
    'languages',
    'previous_works',
    'socialLinks',
    'physical',
    'skills',
    'education_availability',
    'portfolio_images',
    'portfolio_videos',
    'more_details',
    'performance_video',
  ];

  Widget _buildExpandedDetails(Map<String, dynamic> professional) {
    final skills = professional['skills'] as List? ?? [];
    final languages = professional['languages'] as List? ?? [];
    final previousWorks = professional['previous_works'] as List? ?? [];
    final awards = professional['awards'] as String? ?? 'No awards listed';
    final socialLinks = professional['socialLinks'] as String? ?? '';
    final bio = professional['bio'] as String? ?? '';

    // Roles that should not display height, weight, phone, and email
    // Note: Actors/Actor roles are excluded from this list so they SHOW physical attributes
    const Set<String> rolesToHideDetails = {
      'Directors',
      'Director',
      'Producers',
      'Producer',
      'Screen Writers',
      'Screen Writer',
      'Cinematographers',
      'Cinematographer',
      'Editors',
      'Editor',
      'Sound Designers',
      'Sound Designer',
      'Casting Directors',
      'Casting Director',
    };

    final role = professional['role'] as String? ?? '';
    final shouldHideDetails = rolesToHideDetails.contains(role);

    Widget? bioSection() {
      if (bio.isEmpty) return null;
      return _buildDetailSection('About', Icons.person, [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2B55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3D3B65)),
          ),
          child: Text(
            bio,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
          ),
        ),
      ]);
    }

    Widget? awardsSection() {
      if (awards.isEmpty || awards == 'No awards listed') return null;
      return _buildDetailSection('Awards & Recognition', Icons.emoji_events, [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2B55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3D3B65)),
          ),
          child: Text(
            awards,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
        ),
      ]);
    }

    Widget? companySection() {
      final company = professional['company'] as String?;
      if (company == null || company.isEmpty) return null;
      return _buildDetailSection('Company', Icons.business, [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2B55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3D3B65)),
          ),
          child: Text(
            company,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ]);
    }

    Widget? availabilitySection() {
      final availability = professional['availability'] as String?;
      if (availability == null || availability.isEmpty) return null;
      return _buildDetailSection('Availability', Icons.schedule, [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2B55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3D3B65)),
          ),
          child: Text(
            availability,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ]);
    }

    Widget? languagesSection() {
      if (languages.isEmpty) return null;
      return _buildDetailSection('Languages', Icons.language, [
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: languages.map<Widget>((language) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A162E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF7B2CBF).withOpacity(0.5),
                ),
              ),
              child: Text(
                language.toString(),
                style: const TextStyle(
                  color: Color(0xFFC77DFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ]);
    }

    Widget? previousWorksSection() {
      if (previousWorks.isEmpty) return null;
      return _buildDetailSection('Previous Works', Icons.movie, [
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: previousWorks.map<Widget>((work) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, color: Color(0xFF9D4EDD), size: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      work.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ]);
    }

    Widget? socialLinksSection() {
      if (socialLinks.isEmpty) return null;
      return _buildDetailSection('Social Links', Icons.link, [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2B55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3D3B65)),
          ),
          child: Row(
            children: [
              const Icon(Icons.person, color: Color(0xFFE0AAFF), size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  socialLinks,
                  style: const TextStyle(
                    color: Color(0xFF9D4EDD),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ]);
    }

    Widget? contactSection() {
      return null;
    }

    Widget? physicalSection() {
      if (shouldHideDetails) return null;
      return _buildDetailSection('Physical Attributes', Icons.person, [
        const SizedBox(height: 12),
        Row(
          children: [
            _buildAttributeCard(
              'Height',
              professional['height'] as String? ?? 'N/A',
              Icons.height,
            ),
            const SizedBox(width: 12),
            _buildAttributeCard(
              'Weight',
              professional['weight'] as String? ?? 'N/A',
              Icons.monitor_weight,
            ),
            const SizedBox(width: 12),
            _buildAttributeCard(
              'Age',
              _formatAge(professional['age']),
              Icons.cake,
            ),
          ],
        ),
      ]);
    }

    Widget? skillsSection() {
      if (skills.isEmpty) return null;
      return _buildDetailSection('Skills', Icons.psychology, [
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: skills.map<Widget>((skill) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2B55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF9D4EDD).withOpacity(0.5),
                ),
              ),
              child: Text(
                skill.toString(),
                style: const TextStyle(
                  color: Color(0xFFE0AAFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ]);
    }

    Widget? educationAvailabilitySection() {
      return Column(
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: _buildInfoCard(
                  'Education',
                  professional['education'] as String? ?? 'N/A',
                  Icons.school,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: _buildInfoCard(
                  'Availability',
                  professional['availability'] as String? ?? 'Not specified',
                  Icons.calendar_today,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final sections = {
      'bio': bioSection(),
      'awards': awardsSection(),
      'company': companySection(),
      'availability': availabilitySection(),
      'languages': languagesSection(),
      'previous_works': previousWorksSection(),
      'socialLinks': socialLinksSection(),
      'contact': contactSection(),
      'physical': physicalSection(),
      'skills': skillsSection(),
      'education_availability': educationAvailabilitySection(),
      'portfolio_images': _buildPortfolioImagesSection(professional),
      'portfolio_videos': _buildPortfolioVideosSection(professional),
      'more_details': _buildMoreDetailsSection(professional),
      'performance_video': (professional['videos'] as List? ?? []).isNotEmpty
          ? _buildVideoSection(professional)
          : null,
    };

    final children = <Widget>[
      const Divider(color: Color(0xFF2D2B55), height: 24),
    ];
    for (var key in _detailSectionOrder) {
      final section = sections[key];
      if (section == null) continue;
      children.add(section);
      children.add(const SizedBox(height: 24));
    }
    if (children.isNotEmpty) children.removeLast();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildPortfolioImagesSection(Map<String, dynamic> professional) {
    final portfolioImages = professional['portfolioImages'] as List? ?? [];

    if (portfolioImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.photo_library, color: Color(0xFFE0AAFF), size: 22),
            SizedBox(width: 12),
            Text(
              'Portfolio Images',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: portfolioImages.length,
            itemBuilder: (context, index) {
              final image = portfolioImages[index] as Map<String, dynamic>;
              final mediaUrl = _getFileUrl(image);

              return GestureDetector(
                onTap: () {
                  if (mediaUrl.isNotEmpty) {
                    _showImageFullScreen(mediaUrl);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2B55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3D3B65)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: mediaUrl.toLowerCase().startsWith('http')
                        ? Image.network(
                            mediaUrl,
                            width: 100,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Color(0xFF9D4EDD),
                                  size: 28,
                                ),
                              );
                            },
                          )
                        : mediaUrl.isNotEmpty && File(mediaUrl).existsSync()
                        ? Image.file(
                            File(mediaUrl),
                            width: 100,
                            height: 120,
                            fit: BoxFit.cover,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.image,
                                color: Color(0xFF9D4EDD),
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  image['name'] ?? 'Image',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPortfolioVideosSection(Map<String, dynamic> professional) {
    final portfolioVideos = professional['portfolioVideos'] as List? ?? [];

    if (portfolioVideos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.video_library, color: Color(0xFFE0AAFF), size: 22),
            SizedBox(width: 12),
            Text(
              'Portfolio Videos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: portfolioVideos.length,
            itemBuilder: (context, index) {
              final video = portfolioVideos[index] as Map<String, dynamic>;
              final mediaUrl = _getFileUrl(video);

              return GestureDetector(
                onTap: () {
                  if (mediaUrl.isNotEmpty) {
                    _openVideoPlayer(mediaUrl);
                  }
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2B55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3D3B65)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: _isVideoUrl(mediaUrl)
                            ? Container(
                                color: Colors.black45,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.videocam,
                                  color: Colors.white70,
                                  size: 36,
                                ),
                              )
                            : mediaUrl.toLowerCase().startsWith('http')
                            ? Image.network(
                                mediaUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(color: Colors.black45);
                                },
                              )
                            : mediaUrl.isNotEmpty && File(mediaUrl).existsSync()
                            ? Image.file(File(mediaUrl), fit: BoxFit.cover)
                            : Container(color: const Color(0xFF2D2B55)),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Text(
                          video['name'] ?? 'Video',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMoreDetailsSection(Map<String, dynamic> professional) {
    final moreDetails = professional['moreDetails'] as List? ?? [];

    if (moreDetails.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.description, color: Color(0xFFE0AAFF), size: 22),
            SizedBox(width: 12),
            Text(
              'Additional Documents',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: moreDetails.length,
            itemBuilder: (context, index) {
              final detail = moreDetails[index] as Map<String, dynamic>;
              final fileType =
                  (detail['type'] as String?)?.toUpperCase() ?? 'FILE';
              final fileUrl = _getFileUrl(detail);
              final lowerUrl = fileUrl.toLowerCase();
              final isPdf = fileType == 'PDF' || lowerUrl.endsWith('.pdf');
              final isImage =
                  fileType == 'IMAGE' ||
                  fileType == 'PNG' ||
                  fileType == 'JPG' ||
                  fileType == 'JPEG' ||
                  lowerUrl.endsWith('.png') ||
                  lowerUrl.endsWith('.jpg') ||
                  lowerUrl.endsWith('.jpeg') ||
                  lowerUrl.endsWith('.gif') ||
                  lowerUrl.endsWith('.webp');

              return GestureDetector(
                onTap: () async {
                  if (isImage && fileUrl.isNotEmpty) {
                    _showImageFullScreen(fileUrl);
                  } else if (fileUrl.isNotEmpty &&
                      await canLaunchUrl(Uri.parse(fileUrl))) {
                    await launchUrl(Uri.parse(fileUrl));
                  }
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2B55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3D3B65)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: isImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: fileUrl.startsWith('http')
                                    ? Image.network(
                                        fileUrl,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color: Color(0xFF9D4EDD),
                                                  size: 32,
                                                ),
                                              );
                                            },
                                      )
                                    : File(fileUrl).existsSync()
                                    ? Image.file(
                                        File(fileUrl),
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.image,
                                          color: Color(0xFF9D4EDD),
                                          size: 32,
                                        ),
                                      ),
                              )
                            : isPdf
                            ? const Icon(
                                Icons.picture_as_pdf,
                                color: Colors.red,
                                size: 40,
                              )
                            : const Icon(
                                Icons.insert_drive_file,
                                color: Color(0xFF9D4EDD),
                                size: 40,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        detail['name'] ?? 'Document',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fileType,
                        style: const TextStyle(
                          color: Color(0xFF9D4EDD),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDetailSection(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFE0AAFF), size: 22),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...children,
      ],
    );
  }


  Widget _buildAttributeCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2B55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3D3B65)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFE0AAFF), size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2B55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3D3B65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFE0AAFF), size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFC0C0E0),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getFileUrl(Map<String, dynamic> file) {
    final dynamic maybeUrl = file['url'];
    if (maybeUrl is String && maybeUrl.isNotEmpty) return maybeUrl;

    final dynamic maybePath = file['path'];
    if (maybePath is String && maybePath.isNotEmpty) return maybePath;

    return '';
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.contains('video');
  }

  Future<void> _showImageFullScreen(String imageUrl) async {
    if (!mounted) return;

    // Check if it's a local file and doesn't exist
    if (!imageUrl.toLowerCase().startsWith('http') && !File(imageUrl).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image file not found. It may have been deleted.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              child: imageUrl.toLowerCase().startsWith('http')
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 50,
                          ),
                        );
                      },
                    )
                  : Image.file(
                      File(imageUrl),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 50,
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openVideoPlayer(String url) async {
    try {
      final controller = url.toLowerCase().startsWith('http')
          ? VideoPlayerController.network(url)
          : VideoPlayerController.file(File(url));
      await controller.initialize();

      final chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF9D4EDD),
          handleColor: Colors.white,
          backgroundColor: Colors.white30,
          bufferedColor: Colors.white54,
        ),
      );

      if (!mounted) {
        controller.dispose();
        chewieController.dispose();
        return;
      }

      await showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.black,
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Chewie(controller: chewieController),
            ),
          );
        },
      );

      await chewieController.pause();
      controller.dispose();
      chewieController.dispose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load video: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showReportDialog(Map<String, dynamic> professional) async {
    final reportController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          title: Text(
            'Report "${professional['name'] ?? 'Professional'}"',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            height: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Describe the issue in detail:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: reportController,
                    maxLines: null,
                    expands: true,
                    cursorColor: const Color(0xFF9D4EDD),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF2D2B55),
                      hintText: 'Enter report details...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF9D4EDD)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () async {
                final message = reportController.text.trim();
                if (message.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter report details.'),
                    ),
                  );
                  return;
                }
                try {
                  await FirestoreService.submitReport(
                    message: message,
                    reportedId: professional['id'],
                    reportType: 'user',
                  );
                  Navigator.of(context).pop();
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
              child: const Text(
                'Submit',
                style: TextStyle(color: Color(0xFF9D4EDD)),
              ),
            ),
          ],
        );
      },
    );

    reportController.dispose();
  }

  Widget _buildVideoSection(Map<String, dynamic> professional) {
    final videosList = professional['videos'] as List? ?? [];
    if (videosList.isEmpty) {
      return const SizedBox.shrink();
    }

    final video = videosList[0] as Map<String, dynamic>;
    final videoUrl = video['url'] as String?;
    if (videoUrl == null) {
      return const SizedBox.shrink();
    }

    final chewieController = _chewieControllers[videoUrl];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.video_library, color: Color(0xFFE0AAFF), size: 22),
            SizedBox(width: 12),
            Text(
              'Performance Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2D2B55)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                chewieController != null
                    ? Chewie(controller: chewieController)
                    : Container(
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: Color(0xFF9D4EDD),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Loading video...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      video['title'] ?? 'Performance Video',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadMoreButton(
    Map<String, dynamic> professional,
    bool isExpanded,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151522),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: const Color(0xFF2D2B55)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _expandedStates[professional['id']] = !isExpanded;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D4EDD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isExpanded ? 'SHOW LESS' : 'VIEW FULL PROFILE',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _startChat(professional),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
            child: const Icon(Icons.chat, size: 22),
          ),
        ],
      ),
    );
  }



  void _startChat(Map<String, dynamic> professional) {
    if (!ChatUtilities.isValidProfessional(professional)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot start chat with this professional'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final safeProfessional = ChatUtilities.safeProfessionalData(professional);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(professional: safeProfessional),
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;
}
