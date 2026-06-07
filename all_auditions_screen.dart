
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'audition_form_screen.dart';

class AllAuditionsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> auditionEvents;

  const AllAuditionsScreen({super.key, required this.auditionEvents});

  @override
  State<AllAuditionsScreen> createState() => _AllAuditionsScreenState();
}

class _AllAuditionsScreenState extends State<AllAuditionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'All Auditions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.auditionEvents.length,
        itemBuilder: (context, index) {
          final event = widget.auditionEvents[index];
          return _buildAuditionCard(event);
        },
      ),
    );
  }

  Widget _buildAuditionCard(Map<String, dynamic> event) {
    return GestureDetector(
      onTap: () {
        _showAuditionDetailsModal(event);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: (event['image'] ?? event['coverImage']) != null
                ? (event['image'] ?? event['coverImage']).toString().startsWith('http')
                    ? CachedNetworkImageProvider((event['image'] ?? event['coverImage']).toString())
                    : FileImage(File((event['image'] ?? event['coverImage']).toString())) as ImageProvider
                : const CachedNetworkImageProvider('https://images.unsplash.com/photo-1489599809505-7ed0ab7a6b58?w=400'),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
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
                Colors.black.withOpacity(0.9),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D4EDD),
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
                  event['title'] ?? 'Untitled Audition',
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
                    Icon(Icons.business_center, color: Colors.white.withOpacity(0.8), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      event['production'] ?? 'Unknown Production',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on, color: Colors.white.withOpacity(0.8), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      event['location'] ?? 'Unknown Location',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.currency_rupee, color: Colors.white.withOpacity(0.8), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      event['budget'] ?? 'TBD',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.8), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Apply by ${event['date'] ?? 'TBD'}',
                      style: const TextStyle(color: Color(0xFFE0AAFF), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAuditionDetailsModal(Map<String, dynamic> audition) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AuditionDetailsView(audition: audition),
    );
  }
}

class _AuditionDetailsView extends StatefulWidget {
  final Map<String, dynamic> audition;

  const _AuditionDetailsView({required this.audition});

  @override
  State<_AuditionDetailsView> createState() => _AuditionDetailsViewState();
}

class _AuditionDetailsViewState extends State<_AuditionDetailsView> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    final videoUrl = widget.audition['videoUrl'] ?? widget.audition['video'];
    if (videoUrl != null && videoUrl.toString().isNotEmpty) {
      _videoController = VideoPlayerController.network(videoUrl.toString())
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.95,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F1B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Audition Details',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image
                    _buildCoverImage(),
                    const SizedBox(height: 20),
                    // Quick Info
                    _buildQuickInfo(),
                    const SizedBox(height: 20),
                    // Title and Type
                    _buildTitleSection(),
                    const SizedBox(height: 20),
                    // All Details
                    _buildAllDetails(),
                    const SizedBox(height: 20),
                    // Role Description
                    _buildRoleDescription(),
                    const SizedBox(height: 20),
                    // Project Description
                    _buildProjectDescription(),
                    const SizedBox(height: 20),
                    // Video Section
                    if (_videoController != null) ...[
                      _buildVideoSection(),
                      const SizedBox(height: 20),
                    ],
                    // Apply Button
                    _buildApplyButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    final coverImage = widget.audition['coverImage'] ?? widget.audition['image'];
    if (coverImage == null) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 220,
        color: const Color(0xFF1E1B2E),
        child: coverImage.toString().startsWith('http')
            ? Image.network(
                coverImage.toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              )
            : Image.file(
                File(coverImage.toString()),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1E1B2E),
      child: const Center(
        child: Icon(Icons.image, color: Colors.white, size: 48),
      ),
    );
  }

  Widget _buildQuickInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Info',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickInfoItem(
                Icons.business,
                'Production',
                widget.audition['production'] ?? 'N/A',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickInfoItem(
                Icons.location_on,
                'Location',
                widget.audition['location'] ?? 'N/A',
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
                widget.audition['shootDate'] ?? 'N/A',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickInfoItem(
                Icons.currency_rupee,
                'Budget',
                widget.audition['budget'] ?? 'N/A',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickInfoItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
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
                style: const TextStyle(
                  color: Colors.white,
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

  Widget _buildTitleSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.audition['title'] ?? 'Untitled',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Role: ${widget.audition['role'] ?? 'N/A'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (widget.audition['type'] != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF9D4EDD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.audition['type'].toString().toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAllDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audition Details',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Age Range', widget.audition['ageRange']),
          _buildDetailRow('Gender', widget.audition['gender']),
          _buildDetailRow('Skills', widget.audition['lookSkills']),
          _buildDetailRow('Shoot Location', widget.audition['shootLocation']),
          _buildDetailRow('Address', widget.audition['address']),
          _buildDetailRow('Application Deadline', widget.audition['applyLastDate'] ?? widget.audition['date']),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleDescription() {
    final roleDetails = widget.audition['roleDetails'];
    if (roleDetails == null || roleDetails.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF9D4EDD).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description, color: Color(0xFFE0AAFF), size: 20),
              const SizedBox(width: 12),
              const Text(
                'Role Description',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            roleDetails.toString(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectDescription() {
    final projectDesc = widget.audition['coverImageDescription'];
    if (projectDesc == null || projectDesc.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF9D4EDD).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.movie, color: Color(0xFFE0AAFF), size: 20),
              const SizedBox(width: 12),
              const Text(
                'Project Description',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            projectDesc.toString(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Preview Video',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: Stack(
                children: [
                  VideoPlayer(_videoController!),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _videoController!.value.isPlaying
                              ? _videoController!.pause()
                              : _videoController!.play();
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF9D4EDD).withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Icon(
                          _videoController!.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyButton() {
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
        onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AuditionFormScreen(auditionEvent: widget.audition),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9D4EDD),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'APPLY NOW',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
